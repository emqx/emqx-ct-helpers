%%%===================================================================
%%% Copyright (c) 2013-2018 EMQ Inc. All rights reserved.
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

-export([set_config/1,run_setup_steps/1, run_teardown_steps/0, reload/2, ensure_broker_started/0, ensure_broker_stopped/0]).

ensure_broker_started() ->
    {ok, _} = emqx_ct_broker:start_link(),  
    ok.

ensure_broker_stopped() ->
    emqx_ct_broker:stop().

set_config(Config) when is_list(Config) ->
    set_config(Config, []).

set_config([{App, SchemaPath, ConfPath} | ConfigInfo], Acc) ->
    set_config(ConfigInfo, [{App, local_path(SchemaPath), local_path(ConfPath)} | Acc]);
set_config([], Acc) ->
    Acc.
local_path(RelativePath) ->
    filename:join([get_base_dir(), RelativePath]).

get_base_dir() ->
    {file, Here} = code:is_loaded(?MODULE),
    filename:dirname(filename:dirname(Here)).

run_setup_steps(Config)when is_list(Config) ->
    [start_apps(App, {SchemaFile, ConfigFile}) || {App, SchemaFile, ConfigFile} <- Config].

run_teardown_steps() ->
    [application:stop(App) || {_, App} <- erlang:erase()],
    ekka_mnesia:stop().

start_apps(App, {SchemaFile, ConfigFile}) ->
    erlang:erase(),
    erlang:put(App, App),
    read_schema_configs(App, {SchemaFile, ConfigFile}),
    set_special_configs(App),
    application:ensure_all_started(App).

read_schema_configs(App, {SchemaFile, ConfigFile}) ->
    ct:pal("Read configs - SchemaFile: ~p, ConfigFile: ~p", [SchemaFile, ConfigFile]),
    Schema = cuttlefish_schema:files([SchemaFile]),
    Conf = conf_parse:file(ConfigFile),
    NewConfig = cuttlefish_generator:map(Schema, Conf),
    Vals = proplists:get_value(App, NewConfig, []),
    [application:set_env(App, Par, Value) || {Par, Value} <- Vals].

set_special_configs(emqx) ->
    application:set_env(emqx, allow_anonymous, false),
    application:set_env(emqx, enable_acl_cache, false);
set_special_configs(_App) ->
    ok.

reload(APP, {Par, Vals}) when is_atom(APP), is_list(Vals) ->
    application:stop(APP),
    {ok, TupleVals} = application:get_env(APP, Par),
    NewVals =
    lists:filtermap(fun({K, V}) ->
        case lists:keymember(K, 1, Vals) of
        false ->{true, {K, V}};
        _ -> false
        end
    end, TupleVals),
    application:set_env(APP, Par, lists:append(NewVals, Vals)),
    application:start(APP).