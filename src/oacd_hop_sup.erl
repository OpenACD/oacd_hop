
-module(oacd_hop_sup).

-behaviour(supervisor).

%% API
-export([start_link/1]).

%% Supervisor callbacks
-export([init/1]).

%% Helper macro for declaring children of supervisor
-define(CHILD(I, Type, Args), {I, {I, start_link, Args}, permanent, 5000, Type, [I]}).

%% ===================================================================
%% API functions
%% ===================================================================

start_link(Options) ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, Options).

%% ===================================================================
%% Supervisor callbacks
%% ===================================================================

init(Options) ->
    {ok, { {one_for_one, 5, 10}, [?CHILD(oacd_hop_rabbit, worker, [Options])]} }.

