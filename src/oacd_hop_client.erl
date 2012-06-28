%% The contents of this file are subject to the Mozilla Public License
%% Version 1.1 (the "License"); you may not use this file except in
%% compliance with the License. You may obtain a copy of the License at
%% http://www.mozilla.org/MPL/
%%
%% Software distributed under the License is distributed on an "AS IS"
%% basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See the
%% License for the specific language governing rights and limitations
%% under the License.
%%
%% The Original Code is oacd_hop.
%%
%% The Initial Developer of the Original Code is Micah Warren.
%% Portions created by the Initial Developers are Copyright (C) 2010-2011
%% kgb. All Rights Reserved.
%%
%% Contributor(s):
%%
%% Micah Warren <micahw at lordnull dot com>

%% @doc a simple client for testing the rabbit queue.  It consumes what is
%% put in the queue, optionally spewing to the console.

-module(oacd_hop_client).
-behavior(gen_server).
-include_lib("amqp_client/include/amqp_client.hrl").
% gen_server
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
	terminate/2, code_change/3]).
% api
-export([start/0, start_link/0, start/1, start_link/1, stop/0]).

-record(state, {
	output = verbose :: 'verbose' | 'quiet',
	rabbit_conn,
	rabbit_chan,
	amqp_params,
	consumer_tag
}).

%% ========================================================================
%% API
%% ========================================================================

start() ->
	Options = application:get_all_env(oacd_hop),
	start(Options).

start(Options) ->
	gen_server:start({local, ?MODULE}, ?MODULE, Options, []).

start_link() ->
	Options = appliation:get_all_env(oacd_hop),
	start_link(Options).

start_link(Options) ->
	gen_server:start_link({local, ?MODULE}, ?MODULE, Options, []).

stop() ->
	gen_server:cast(?MODULE, stop).

%% ========================================================================
%% INIT
%% ========================================================================

init(Options) ->
	Verbosity = case proplists:get_value(quiet, Options) of
		true -> quiet;
		_ -> verbose
	end,
	ConnectParams = oacd_hop_rabbit:build_amqp_params(Options),
	case oacd_hop_rabbit:connect(ConnectParams) of
		{ok, {Conn, Chan}} ->
			Exchange = #'exchange.declare'{exchange = <<"OpenACD">>, type = <<"fanout">>},
			#'exchange.declare_ok'{} = amqp_channel:call(Chan, Exchange),
			Queue = #'queue.declare'{},
			#'queue.declare_ok'{queue = QueueName} = amqp_channel:call(Chan, Queue),
			Binding = #'queue.bind'{queue = QueueName, exchange = <<"OpenACD">>, routing_key = <<"all">>},
			#'queue.bind_ok'{} = amqp_channel:call(Chan, Binding),
			Sub = #'basic.consume'{queue = QueueName},
			#'basic.consume_ok'{consumer_tag = Tag} = amqp_channel:call(Chan, Sub),
			State = #state{output = Verbosity, rabbit_conn = Conn,
				rabbit_chan = Chan, amqp_params = ConnectParams, consumer_tag = Tag},
			{ok, State};
		Else ->
			Else
	end.

%% ========================================================================
%% handle_call
%% ========================================================================

handle_call(_Msg, _From, State) ->
	{reply, {error, invalid}, State}.

%% ========================================================================
%% handle_cast
%% ========================================================================

handle_cast(stop, State) ->
	{stop, normal, State};

handle_cast(_Msg, State) ->
	{noreply, State}.

%% ========================================================================
%% handle_info
%% ========================================================================

handle_info(#'basic.consume_ok'{}, State) ->
	{noreply, State};

handle_info(#'basic.cancel_ok'{}, State) ->
	{stop, normal, State};

handle_info({#'basic.deliver'{delivery_tag = Tag}, Content}, State) ->
	amqp_channel:cast(State#state.rabbit_chan, #'basic.ack'{delivery_tag = Tag}),
	case State#state.output of
		verbose ->
			io:format("Message for you sir!\n\t~p", [Content]);
		_ ->
			ok
	end,
	{noreply, State};

handle_info(_Msg, State) ->
	{noreply, State}.

%% ========================================================================
%% teminate
%% ========================================================================

terminate(_Cuase, _State) -> ok.

%% ========================================================================
%% code_change
%% ========================================================================

code_change(_OldVsn, State, _Extra) ->
	{ok, State}.

%% ========================================================================
%% Internal
%% ========================================================================
