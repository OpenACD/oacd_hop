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

-module(oacd_hop).

-behaviour(application).

%% Application callbacks
-export([start/2, stop/1]).

%% api
-export([
	get_env/1,
	get_env/2,
	get_key/1,
	get_key/2
]).

%% ===================================================================
%% Application callbacks
%% ===================================================================

start(_StartType, _StartArgs) ->
	oacd_hop_sup:start_link(application:get_all_env(oacd_hop)).

stop(_State) ->
	ok.

get_env(Key) ->
	application:get_env(oacd_hop, Key).

get_env(Key, Default) ->
	case application:get_env(oacd_hop, Key) of
		undefined ->
			{ok, Default};
		Else ->
			{ok, Else}
	end.

get_key(Key) ->
	application:get_key(oacd_hop, Key).

get_key(Key, Default) ->
	case application:get_key(oacd_hop, Key) of
		undefined ->
			{ok, Default};
		Else ->
			{ok, Else}
	end.
