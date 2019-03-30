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

-module(emqx_ct_http).

-include_lib("common_test/include/ct.hrl").

-export([ request_api/3
        , request_api/4
        , request_api/5
        , get_http_data/1
        , create_default_app/0
        , default_auth_header/0
        , auth_header/2
        ]).

request_api(Method, Url, Auth) ->
    request_api(Method, Url, [], Auth, []).

request_api(Method, Url, QueryParams, Auth) ->
    request_api(Method, Url, QueryParams, Auth, []).

request_api(Method, Url, QueryParams, Auth, Body)->
    request_api(Method, Url, QueryParams, Auth, Body, []).

request_api(Method, Url, QueryParams, Auth, Body, HttpOtps) ->
    NewUrl = case QueryParams of
                 [] ->
                     Url;
                 _ ->
                     Url ++ "?" ++ QueryParams
             end,
    Request = case Body of
                  [] ->
                      {NewUrl, [Auth]};
                  _ ->
                      {NewUrl, [Auth], "application/json", emqx_json:encode(Body)}
              end,
    do_request_api(Method, Request, HttpOtps).

do_request_api(Method, Request, HttpOtps) ->
    ct:pal("Method: ~p, Request: ~p", [Method, Request]),
    case httpc:request(Method, Request, HttpOtps, [{body_format, binary}]) of
        {error, socket_closed_remotely} ->
                {error, socket_closed_remotely};
        {ok, {{"HTTP/1.1", Code, _}, _Headers, Return} } 
            when Code =:= 200 orelse Code =:= 201 ->
            {ok, Return};
        {ok, {Reason, _, _}} ->
            {error, Reason}
    end.

get_http_data(ResponseBody) ->
    proplists:get_value(<<"data">>, emqx_json:decode(ResponseBody)).

auth_header(User, Pass) ->
    Encoded = base64:encode_to_string(lists:append([User,":",Pass])),
    {"Authorization","Basic " ++ Encoded}.

default_auth_header() ->
    AppId = <<"myappid">>,
    AppSecret = emqx_mgmt_auth:get_appsecret(AppId),
    auth_header(erlang:binary_to_list(AppId), erlang:binary_to_list(AppSecret)).

create_default_app() ->
    emqx_mgmt_auth:add_app(<<"myappid">>, <<"test">>).