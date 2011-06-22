-module(oacd_hop_rabbit).

-behaviour(gen_server).

-include_lib("amqp_client/include/amqp_client.hrl").
-include_lib("OpenACD/include/log.hrl").
-include_lib("OpenACD/include/call.hrl").
-include_lib("OpenACD/include/agent.hrl").
-include_lib("OpenACD/include/cpx_cdr_pb.hrl").

-export([
	init/1,
	handle_call/3,
	handle_cast/2,
	handle_info/2,
	terminate/2,
	code_change/3
]).

%% api
-export([
	start_link/1
]).

-record(state, {
	last_id = 0,
	ack_queue = dict:new(),
	cpx :: 'undefined' | pid(),
	rabbit_conn,
	rabbit_chan
}).

%% ========================================================================
%% API
%% ========================================================================

start_link(Opts) ->
	gen_server:start_link(?MODULE, Opts, []).

%% ========================================================================
%% INIT
%% ========================================================================

init(Opts) ->
	ConnectionRec = proplists:get_value(connection, Opts, #amqp_params_network{}),
	{ok, RabbitConn} = amqp_connection:start(ConnectionRec),
	{ok, RabbitChan} = amqp_connection:open_channel(RabbitConn),
	Exchange = #'exchange.declare'{exchange = <<"OpenACD">>},
	#'exchange.declare_ok'{} = amqp_channel:call(RabbitChan, Exchange),
	Queue = #'queue.declare'{queue =  <<"OpenACD.all">>},
	#'queue.declare_ok'{} = amqp_channel:call(RabbitChan, Queue),
	Binding = #'queue.bind'{queue = <<"OpenACD.all">>, exchange = <<"OpenACD">>, routing_key = <<"all">>},
	#'queue.bind_ok'{} = amqp_channel:call(RabbitChan, Binding),
	CpxMon = case whereis(cpx_monitor) of
		undefined ->
			?WARNING("cpx_monitor not found, checking in 10 seconds", []),
			Self = self(),
			erlang:send_after(10000, Self, {check, cpx_monitor});
		Pid when is_pid(Pid) ->
			cpx_monitor:subscribe(fun cpx_msg_filter/1),
			Pid
	end,
	{ok, #state{cpx = CpxMon, rabbit_conn = RabbitConn, rabbit_chan = RabbitChan}}.

%% ========================================================================
%% HANDLE_CALL
%% ========================================================================

handle_call(Msg, _From, State) ->
	{reply, {error, Msg}, State}.

%% ========================================================================
%% HANDLE_CAST
%% ========================================================================

handle_cast(_Msg, State) ->
	{noreply, State}.

%% ========================================================================
%% HANDLE_INFO
%% ========================================================================

handle_info({cpx_monitor_event, {info, _Time, {agent_state, Astate}}}, State) ->
	?DEBUG("Sending astate", []),
	NewState = send(Astate, State),
	{noreply, NewState};
handle_info({cpx_monitor_event, {info, _Time, {cdr_raw, CdrRaw}}}, State) ->
	?DEBUG("Sending cdr raw", []),
	NewState = send(CdrRaw, State),
	{noreply, NewState};
handle_info({cpx_monitor_event, {info, _Time, {cdr_rec, CdrRec}}}, State) ->
	?DEBUG("Sending cdr rec", []),
	NewState = send(CdrRec, State),
	{noreply, NewState};

handle_info({check, cpx_monitor}, #state{cpx = Pid} = State) when is_pid(Pid) ->
	{noreply, State};
handle_info({check, cpx_monitor}, State) ->
	CpxMon = case whereis(cpx_monitor) of
		undefined ->
			?WARNING("cpx_monitor not found, checking in 10 seconds", []),
			Self = self(),
			erlang:send_after(10000, Self, {check, cpx_monitor});
		Pid when is_pid(Pid) ->
			cpx_monitor:subscribe(),
			Pid
	end,
	{noreply, State#state{cpx = CpxMon}};

handle_info(Msg, State) ->
	?INFO("unhandled message ~p", [Msg]),
	{noreply, State}.

%% ========================================================================
%% TERMINATE
%% ========================================================================

terminate(_,_) -> ok.

%% ========================================================================
%% CODE_CHANGE
%% ========================================================================

code_change(_, _, State) ->
	{ok, State}.

%% ========================================================================
%% INTERNAL
%% ========================================================================

cpx_msg_filter({info, _, {agent_state, _}}) ->
	true;
cpx_msg_filter({info, _, {cdr_rec, _}}) ->
	true;
cpx_msg_filter({info, _, {cdr_raw, _}}) ->
	true;
cpx_msg_filter(M) ->
	?DEBUG("filtering out message ~p", [M]),
	false.

send(Astate, State) when is_record(Astate, agent_state) ->
	NewId = next_id(State#state.last_id),
	Send = #cdrdumpmessage{
		message_id = NewId,
		message_hint = 'AGENT_STATE',
		agent_state_change = agent_state_to_protobuf(Astate)
	},
	NewDict = dict:store(NewId, Send, State#state.ack_queue),
	try_send(Send, State#state{last_id = NewId, ack_queue = NewDict});
send(CdrRaw, State) when is_record(CdrRaw, cdr_raw) ->
	NewId = next_id(State#state.last_id),
	Send = #cdrdumpmessage{
		message_id = NewId,
		message_hint = 'CDR_RAW',
		cdr_raw = cdr_raw_to_protobuf(CdrRaw)
	},
	NewDict = dict:store(NewId, Send, State#state.ack_queue),
	try_send(Send, State#state{last_id = NewId, ack_queue = NewDict});
send(CdrRec, State) when is_record(CdrRec, cdr_rec) ->
	NewId = next_id(State#state.last_id),
	Send = #cdrdumpmessage{
		message_id = NewId,
		message_hint = 'CDR_REC',
		cdr_rec = cdr_rec_to_protobuf(CdrRec)
	},
	NewDict = dict:store(NewId, Send, State#state.ack_queue),
	try_send(Send, State#state{last_id = NewId, ack_queue = NewDict}).



try_send(Send, #state{rabbit_chan = Chan} = State) ->
	Bin = cpx_cdr_pb:encode(Send),
	Msg = #amqp_msg{payload = Bin},
	Publish = #'basic.publish'{exchange = <<"OpenACD">>, routing_key = <<"key">>},
	amqp_channel:cast(Chan, Publish, Msg),
	State.
%	Bin = protobuf_util:bin_to_netstring(cpx_cdr_pb:encode(Send)),
%	case gen_tcp:send(Socket, Bin) of
%		ok ->
%			State;
%		{error, Else} ->
%			State#state{socket = undefined}
%	end.



next_id(LastId) when LastId > 999998 ->
	1;
next_id(LastId) ->
	LastId + 1.

agent_state_to_protobuf(AgentState) ->
	Base = #agentstatechange{
		agent_id = AgentState#agent_state.id,
		agent_login = AgentState#agent_state.agent,
		is_login = case AgentState#agent_state.state of
			login -> true;
			_ -> false
		end,
		is_logout = case AgentState#agent_state.state of
			logout -> true;
			_ -> false
		end,
		new_state = protobuf_util:statename_to_enum(AgentState#agent_state.state),
		old_state = protobuf_util:statename_to_enum(AgentState#agent_state.oldstate),
		start_time = AgentState#agent_state.start,
		stop_time = AgentState#agent_state.ended,
		profile = AgentState#agent_state.profile
	},
	case AgentState#agent_state.oldstate of
		idle ->
			Base;
		precall ->
			Base#agentstatechange{
				client_record = protobuf_util:client_to_protobuf(AgentState#agent_state.statedata)
			};
		released ->
			Base#agentstatechange{
				released = protobuf_util:release_to_protobuf(AgentState#agent_state.statedata)
			};
		warm_transfer ->
			Base#agentstatechange{
				call_record = protobuf_util:call_to_protobuf(element(2, AgentState#agent_state.statedata)),
				dialed_number = protobuf_util:call_to_protobuf(AgentState#agent_state.statedata)
			};
		_ when is_record(AgentState#agent_state.statedata, call) ->
			Base#agentstatechange{
				call_record = protobuf_util:call_to_protobuf(AgentState#agent_state.statedata)
			};
		_ ->
			Base
	end.

cdr_rec_to_protobuf(Cdr) when is_record(Cdr, cdr_rec) ->
	Summary = summary_to_protobuf(Cdr#cdr_rec.summary),
	Raws = [cdr_raw_to_protobuf(X) || X <- Cdr#cdr_rec.transactions],
	Call = protobuf_util:call_to_protobuf(Cdr#cdr_rec.media),
	#cpxcdrrecord{
		call_record = Call,
		details = Summary,
		raw_transactions = Raws
	}.
cdr_raw_to_protobuf(Cdr) when is_record(Cdr, cdr_raw) ->
	Base = #cpxcdrraw{
		call_id = Cdr#cdr_raw.id,
		transaction = cdr_transaction_to_enum(Cdr#cdr_raw.transaction),
		start_time = Cdr#cdr_raw.start,
		stop_time = Cdr#cdr_raw.start,
		terminates = case Cdr#cdr_raw.terminates of
			infoevent ->
				'INFOEVENT';
			_ ->
				[cdr_transaction_to_enum(X) || X <- Cdr#cdr_raw.terminates]
		end
	},
	case Cdr#cdr_raw.transaction of
		cdrinit -> Base;
		inivr -> Base#cpxcdrraw{ dnis = Cdr#cdr_raw.eventdata};
		dialoutgoing -> Base#cpxcdrraw{number_dialed = Cdr#cdr_raw.eventdata};
		inqueue -> Base#cpxcdrraw{queue = Cdr#cdr_raw.eventdata};
		ringing -> Base#cpxcdrraw{agent = Cdr#cdr_raw.eventdata};
		ringout -> Base#cpxcdrraw{agent = Cdr#cdr_raw.eventdata};
		precall -> Base#cpxcdrraw{client = Cdr#cdr_raw.eventdata};
		oncall -> Base#cpxcdrraw{agent = Cdr#cdr_raw.eventdata};
		agent_transfer -> Base#cpxcdrraw{
			agent = element(1, Cdr#cdr_raw.eventdata),
			agent_transfer_recipient = element(2, Cdr#cdr_raw.eventdata)
		};
		queue_transfer -> Base#cpxcdrraw{queue = Cdr#cdr_raw.eventdata};
		transfer -> Base#cpxcdrraw{
			transfer_to = Cdr#cdr_raw.eventdata
		};
		warmxfer_begin -> Base#cpxcdrraw{
			transfer_to = element(2, Cdr#cdr_raw.eventdata),
			agent = element(1, Cdr#cdr_raw.eventdata)
		};
		warmxfer_cancel -> Base#cpxcdrraw{agent = element(1, Cdr#cdr_raw.eventdata)};
		warmxfer_fail -> Base#cpxcdrraw{agent = Cdr#cdr_raw.eventdata};
		warmxfer_complete -> Base#cpxcdrraw{agent = Cdr#cdr_raw.eventdata};
		wrapup -> Base#cpxcdrraw{agent = Cdr#cdr_raw.eventdata};
		endwrapup -> Base#cpxcdrraw{agent = Cdr#cdr_raw.eventdata};
		abandonqueue -> Base#cpxcdrraw{queue = Cdr#cdr_raw.eventdata};
		abandonivr -> Base;
		voicemail -> Base#cpxcdrraw{queue = Cdr#cdr_raw.eventdata};
		hangup -> Base#cpxcdrraw{hangup_by = case Cdr#cdr_raw.eventdata of
			agent -> 
				"agent";
			_ ->
				Cdr#cdr_raw.eventdata
		end};
		undefined -> Base;
		cdrend -> Base;
		_ -> Base
	end.

summary_to_protobuf(Summary) ->
	summary_to_protobuf(Summary, #cpxcdrsummary{}).

summary_to_protobuf([], Acc) ->
	Acc;
summary_to_protobuf([{wrapup, {Total, Specifics}} | Tail], Acc) ->
	NewAcc = Acc#cpxcdrsummary{
		wrapup = Total,
		wrapup_breakdown = make_cpxcdrkeytime(Specifics)
	},
	summary_to_protobuf(Tail, NewAcc);
summary_to_protobuf([{warmxfer_fail, {Total, Specifics}} | Tail], Acc) ->
	NewAcc = Acc#cpxcdrsummary{
		warmxfer_fail = Total,
		warmxfer_fail_breakdown = make_cpxcdrkeytime(Specifics)
	},
	summary_to_protobuf(Tail, NewAcc);
summary_to_protobuf([{warmxfer_begin, {Total, Specifics}} | Tail], Acc) ->
	NewAcc = Acc#cpxcdrsummary{
		warmxfer_begin = Total,
		warmxfer_begin_breakdown = make_cpxcdrkeytime(Specifics)
	},
	summary_to_protobuf(Tail, NewAcc);
summary_to_protobuf([{oncall, {Total, Specifics}} | Tail], Acc) ->
	NewAcc = Acc#cpxcdrsummary{
		oncall = Total,
		oncall_breakdown = make_cpxcdrkeytime(Specifics)
	},
	summary_to_protobuf(Tail, NewAcc);
summary_to_protobuf([{ringing, {Total, Specifics}} | Tail], Acc) ->
	NewAcc = Acc#cpxcdrsummary{
		ringing = Total,
		ringing_breakdown = make_cpxcdrkeytime(Specifics)
	},
	summary_to_protobuf(Tail, NewAcc);
summary_to_protobuf([{inqueue, {Total, Specifics}} | Tail], Acc) ->
	NewAcc = Acc#cpxcdrsummary{
		inqueue = Total,
		inqueue_breakdown = make_cpxcdrkeytime(Specifics)
	},
	summary_to_protobuf(Tail, NewAcc);
summary_to_protobuf([Head | Tail], Acc) ->
	summary_to_protobuf(Tail, Acc).

make_cpxcdrkeytime(Proplist) ->
	[#cpxcdrkeytime{ key = Key, value = Value } 
		|| {Key, Value} <- Proplist].
	

cdr_transaction_to_enum(T) ->
	list_to_atom(string:to_upper(atom_to_list(T))).

%% ========================================================================
%% TEST
%% ========================================================================
