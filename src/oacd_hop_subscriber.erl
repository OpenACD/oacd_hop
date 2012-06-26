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

-module(oacd_hop_subscriber).

-include_lib("OpenACD/include/log.hrl").

-behaviour(gen_server).

% gen_server
-export([
	init/1,
	handle_call/3, handle_cast/2, handle_info/2,
	terminate/2, code_change/3
]).

% api
-export([
	start/0, start_link/0,
	cpx_msg_filter/1
]).

-record(state, {}).

%% ========================================================================
%% API
%% ========================================================================

start() ->
	gen_server:start({local, ?MODULE}, ?MODULE, []).

start_link() ->
	gen_server:start_link({local, ?MODULE}, ?MODULE, []).

cpx_msg_filter({info, _, {agent_state, _}}) ->
	true;
cpx_msg_filter({info, _, {agent_profile, _}}) ->
	true;
cpx_msg_filter({info, _, {cdr_rec, _}}) ->
	true;
cpx_msg_filter({info, _, {cdr_raw, _}}) ->
	true;
cpx_msg_filter(_M) ->
	%?DEBUG("filtering out message ~p", [M]),
	false.

%% ========================================================================
%% gen_server callbacks
%% ========================================================================

%% ------------------------------------------------------------------------
%% init
%% ------------------------------------------------------------------------

init(_) ->
	case whereis(cpx_monitor) of
		undefined ->
			{stop, {noproc, cpx_monitor}};
		CpxMon when is_pid(CpxMon) ->
			cpx_monitor:subscribe(fun ?MODULE:cpx_msg_filter/1),
			ets:new(oacd_hop_unconfirmed, [named_table, bag, public]),
			{ok, #state{}}
	end.

%% ------------------------------------------------------------------------
%% handle_call
%% ------------------------------------------------------------------------

handle_call(Msg, _From, State) ->
	?WARNING("Unhandled request ~p", [Msg]), 
	{reply, {error, invalid}, State}.

%% ------------------------------------------------------------------------
%% handle_cast
%% ------------------------------------------------------------------------

handle_cast(Msg, State) ->
	?WARNING("Unhandled cast ~p", [Msg]),
	{noreply, State}.

%% ------------------------------------------------------------------------
%% handle_info
%% ------------------------------------------------------------------------

handle_info({cpx_monitor_event, {info, _Time, {agent_state, Astate}}}, State) ->
	%?DEBUG("Sending astate", []),
	NewState = send(Astate, State),
	{noreply, NewState};
handle_info({cpx_monitor_event, {info, _Time, {cdr_raw, CdrRaw}}}, State) ->
	%?DEBUG("Sending cdr raw", []),
	NewState = send(CdrRaw, State),
	{noreply, NewState};
handle_info({cpx_monitor_event, {info, _Time, {cdr_rec, CdrRec}}}, State) ->
	%?DEBUG("Sending cdr rec", []),
	NewState = send(CdrRec, State),
	{noreply, NewState};
handle_info({cpx_monitor_event, {info, _Time, {agent_profile, AProf}}}, State) ->
	NewState = send(AProf, State),
	{noreply, NewState};

handle_info(Msg, State) ->
	?WARNING("unhandled message ~p", [Msg]),
	{noreply, State}.

%% ------------------------------------------------------------------------
%% terminate
%% ------------------------------------------------------------------------

terminate(Cause, _State) ->
	?INFO("Exiting:  ~p", [Cause]),
	ok.

%% ------------------------------------------------------------------------
%% code_change
%% ------------------------------------------------------------------------

code_change(_OldVsn, State, _Extra) ->
	{ok, State}.

%% ========================================================================
%% Internal
%% ========================================================================

send(Rec, State) ->
	oacd_hop_rabbit:write(Rec),
	ets:insert(oacd_hop_unconfirmed, Rec),
	State.

%% ========================================================================
%% Test
%% ========================================================================
