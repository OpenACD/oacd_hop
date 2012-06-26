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

-module(oacd_hop_nodemon).

-include_lib("OpenACD/include/log.hrl").

-behaviour(gen_leader).

% gen_leader
-export([init/1,
	elected/3, surrendered/3,
	handle_leader_call/4, handle_leader_cast/3,
	from_leader/3,
	handle_call/4, handle_cast/3, handle_DOWN/3, handle_info/2,
	terminate/2,
	code_change/4
]).

% api
-export([start/0, start_link/0]).

-record(state, {ets}).

%% ========================================================================
%% API
%% ========================================================================

start() ->
	Nodes = [node() | nodes()],
	gen_leader:start(?MODULE, Nodes, [], ?MODULE, [], []).

start_link() ->
	Nodes = [node() | nodes()],
	gen_leader:start_link(?MODULE, Nodes, [], ?MODULE, [], []).

%% ========================================================================
%% gen_leader callbacks
%% ========================================================================

%% ------------------------------------------------------------------------
%% Init
%% ------------------------------------------------------------------------

init(_Stuff) ->
	?INFO("Starting", []),
	{ok, #state{}}.

%% ------------------------------------------------------------------------
%% Elected
%% ------------------------------------------------------------------------

elected(State, _Election, _Node) ->
	?INFO("Elected", []),
	oacd_hop_rabbit:begin_writing(),
	{ok, {}, State}.

%% ------------------------------------------------------------------------
%% Surrendered
%% ------------------------------------------------------------------------

surrendered(State, _LeaderMsg, _Election) ->
	?INFO("Surrendered", []),
	oacd_hop_rabbit:stop_writing(),
	{ok, State}.

%% ------------------------------------------------------------------------
%% handle_DOWN
%% ------------------------------------------------------------------------

handle_DOWN(Node, State, Election) ->
	?INFO("~p has gone down.", [Node]),
	{ok, State}.

%% ------------------------------------------------------------------------
%% handle_leader_call
%% ------------------------------------------------------------------------

handle_leader_call(Req, _From, State, _Election) ->
	?WARNING("Unhandled request ~p", [Req]),
	{reply, {error, invalid}, State}.

%% ------------------------------------------------------------------------
%% handle_leader_cast
%% ------------------------------------------------------------------------

handle_leader_cast(Req, State, _Election) ->
	?WARNING("Unhandled cast ~p", [Req]),
	{noreply, State}.

%% ------------------------------------------------------------------------
%% from_leader
%% ------------------------------------------------------------------------

from_leader(_Msg, State, _Election) ->
	{ok, State}.

%% ------------------------------------------------------------------------
%% handle_call
%% ------------------------------------------------------------------------

handle_call(Msg, _From, State, _Election) ->
	?WARNING("Unhandled request ~p", [Msg]),
	{reply, {error, invalid}, State}.

%% ------------------------------------------------------------------------
%% handle_cast
%% ------------------------------------------------------------------------

handle_cast(Msg, State, _Election) ->
	?WARNING("Unhandled cast ~p", [Msg]),
	{noreply, State}.

%% ------------------------------------------------------------------------
%% handle_info
%% ------------------------------------------------------------------------

handle_info(Msg, State) ->
	?WARNING("Unhandled message:  ~p", [Msg]),
	{norply, State}.

%% ------------------------------------------------------------------------
%% terminate
%% ------------------------------------------------------------------------

terminate(Reason, _State) ->
	?INFO("Exit:  ~p", [Reason]),
	ok.

%% ------------------------------------------------------------------------
%% code_change
%% ------------------------------------------------------------------------

code_change(_OldVsn, State, _Election, _Extra) ->
	{ok, State}.

%% ========================================================================
%% Internal
%% ========================================================================

%% ========================================================================
%% Test
%% ========================================================================
