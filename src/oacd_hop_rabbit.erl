-module(oacd_hop_rabbit).

-behaviour(gen_bunny).

-include_lib("amqp_client/include/amqp_client.hrl").
-include_lib("OpenACD/include/call.hrl").
-include_lib("OpenACD/include/agent.hrl").

-export([
	init/1,
	handle_message/2,
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
	cpx :: 'undefined' | pid()
}).

%% ========================================================================
%% API
%% ========================================================================

start_link(Opts) ->
	Connection = proplists:get_value(connection, Opts, {network, #amqp_params{}}),
	DeclareInfo = proplists:get_value(declare_info, Opts, {<<"OpenACD">>, <<"all">>, <<"all">>}),
	gen_bunny:start_link(?MODULE, Connection, DeclareInfo, Opts).

%% ========================================================================
%% INIT
%% ========================================================================

init(Opts) ->
	CpxMon = case whereis(cpx_monitor) of
		undefined ->
			Self = self(),
			erlang:send_after(10000, Self, {check, cpx_monitor});
		Pid when is_pid(Pid) ->
			cpx_monitor:subscribe(),
			Pid
	end,
	{ok, #state{cpx = CpxMon}}.

%% ========================================================================
%% HANDLE_MESSAGE
%% ========================================================================

handle_message(_Msg, State) ->
	{noreply, State}.

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

handle_info({cpx_monitor, M}, State) ->
	io:format("cpx mon:  ~p\n", [M]),
	{noreply, State};
handle_info({check, cpx_monitor}, #state{cpx = Pid} = State) when is_pid(Pid) ->
	{noreply, State};
handle_info({check, cpx_monitor}, State) ->
	CpxMon = case whereis(cpx_monitor) of
		undefined ->
			Self = self(),
			erlang:send_after(10000, Self, {check, cpx_monitor});
		Pid when is_pid(Pid) ->
			cpx_monitor:subscribe(),
			Pid
	end,
	{noreply, State#state{cpx = CpxMon}};
handle_info(Msg, State) ->
	io:format("msg:  ~p\n", [Msg]),
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

%% ========================================================================
%% TEST
%% ========================================================================
