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
	oacd_hop_sup:start_link().

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
