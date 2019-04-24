%%%===================================================================
%%% Copyright (c) 2013-2019 EMQ Inc. All rights reserved.
%%%
%%% Licensed under the Apache License, Version 2.0 (the "License");
%%% you may not use this file except in compliance with the License.
%%% You may obtain a copy of the License at
%%%
%%%     http://www.apache.org/licenses/LICENSE-2.0
%%%
%%% Unless required by applicable law or agreed to in writing, software
%%% distributed under the License is distributed on an "AS IS" BASIS,
%%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%%% See the License for the specific language governing permissions and
%%% limitations under the License.
%%%===================================================================

-module(emqx_ct_helpers).

-include_lib("common_test/include/ct.hrl").

-type(special_config_handler() :: fun()).

-type(apps() :: list(atom())).

-export([ start_apps/1
        , start_apps/2
        , stop_apps/1
        , reload/2
        , deps_path/2
        ]).

-export([ ensure_mnesia_stopped/0
        , wait_for/4]).

%%------------------------------------------------------------------------------
%% APIs
%%------------------------------------------------------------------------------

-spec(start_apps(Apps :: apps()) -> ok).
start_apps(Apps) ->
    start_apps(Apps, fun(_) -> ok end).

-spec(start_apps(Apps :: apps(), Handler :: special_config_handler()) -> ok).
start_apps(Apps, Handler) when is_function(Handler) ->
    %% Load all application code to beam vm first
    %% Becasue, minirest, ekka etc.. application will scan these modules
    [application:load(App) || App <- Apps],
    [start_app(App, Handler) || App <- [emqx | Apps]],
    ok.

%% @private
start_app(App, Handler) ->
    start_app(App,
              deps_path(App, filename:join(["priv", atom_to_list(App) ++ ".schema"])),
              deps_path(App, filename:join(["etc", atom_to_list(App) ++ ".conf"])),
              Handler).
%% @private
start_app(App, SchemaFile, ConfigFile, SpecAppConfig) ->
    read_schema_configs(App, SchemaFile, ConfigFile),
    SpecAppConfig(App),
    application:ensure_all_started(App).

%% @private
read_schema_configs(App, SchemaFile, ConfigFile) ->
    ct:pal("Read configs - SchemaFile: ~p, ConfigFile: ~p", [SchemaFile, ConfigFile]),
    Schema = cuttlefish_schema:files([SchemaFile]),
    Conf = conf_parse:file(ConfigFile),
    NewConfig = cuttlefish_generator:map(Schema, Conf),
    Vals = proplists:get_value(App, NewConfig, []),
    [application:set_env(App, Par, Value) || {Par, Value} <- Vals].

-spec(stop_apps(list()) -> ok).
stop_apps(Apps) ->
    [application:stop(App) || App <- Apps ++ [emqx]].

deps_path(App, RelativePath) ->
    %% Note: not lib_dir because etc dir is not sym-link-ed to _build dir
    %% but priv dir is
    Path0 = code:priv_dir(App),
    Path = case file:read_link(Path0) of
               {ok, Resolved} -> Resolved;
               {error, _} -> Path0
           end,
    filename:join([Path, "..", RelativePath]).

-spec(reload(App :: atom(), SpecAppConfig :: special_config_handler()) -> ok).
reload(App, SpecAppConfigHandler) ->
    application:stop(App),
    start_app(App, SpecAppConfigHandler),
    application:start(App).

ensure_mnesia_stopped() ->
    ekka_mnesia:ensure_stopped(),
    ekka_mnesia:delete_schema().

%% Help function to wait for Fun to yield 'true'.
wait_for(Fn, Ln, F, Timeout) ->
    {Pid, Mref} = erlang:spawn_monitor(fun() -> wait_loop(F, catch_call(F)) end),
    wait_for_down(Fn, Ln, Timeout, Pid, Mref, false).

wait_for_down(Fn, Ln, Timeout, Pid, Mref, Kill) ->
    receive
        {'DOWN', Mref, process, Pid, normal} ->
            ok;
        {'DOWN', Mref, process, Pid, {unexpected, Result}} ->
            erlang:error({unexpected, Fn, Ln, Result});
        {'DOWN', Mref, process, Pid, {crashed, {C, E, S}}} ->
            erlang:raise(C, {Fn, Ln, E}, S)
    after
        Timeout ->
            case Kill of
                true ->
                    erlang:demonitor(Mref, [flush]),
                    erlang:exit(Pid, kill),
                    erlang:error({Fn, Ln, timeout});
                false ->
                    Pid ! stop,
                    wait_for_down(Fn, Ln, Timeout, Pid, Mref, true)
            end
    end.

wait_loop(_F, ok) -> exit(normal);
wait_loop(F, LastRes) ->
    receive
        stop -> erlang:exit(LastRes)
    after
        100 ->
            Res = catch_call(F),
            wait_loop(F, Res)
    end.

catch_call(F) ->
    try
        case F() of
            true -> ok;
            Other -> {unexpected, Other}
        end
    catch
        C : E : S ->
            {crashed, {C, E, S}}
    end.
