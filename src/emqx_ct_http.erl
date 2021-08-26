%%--------------------------------------------------------------------
%% Copyright (c) 2019 EMQ Technologies Co., Ltd. All Rights Reserved.
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%%--------------------------------------------------------------------

-module(emqx_ct_http).

-include_lib("common_test/include/ct.hrl").

-export([ request_api/3
        , request_api/4
        , request_api/5
        , get_http_data/1
        , create_default_app/0
        , delete_default_app/0
        , default_auth_header/0
        , auth_header/2
        ]).

-define(DEF_USERNAME, <<"admin">>).
-define(DEF_PASSWORD, <<"public">>).

request_api(Method, Url, Auth) ->
    request_api(Method, Url, [], Auth, []).

request_api(Method, Url, QueryParams, Auth) ->
    request_api(Method, Url, QueryParams, Auth, []).

request_api(Method, Url, QueryParams, Auth, Body) ->
    request_api(Method, Url, QueryParams, Auth, Body, []).

request_api(Method, Url, QueryParams, Auth, Body, HttpOpts) ->
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
    do_request_api(Method, Request, HttpOpts).

do_request_api(Method, Request, HttpOpts) ->
    ct:pal("Method: ~p, Request: ~p", [Method, Request]),
    case httpc:request(Method, Request, HttpOpts, [{body_format, binary}]) of
        {error, socket_closed_remotely} ->
                {error, socket_closed_remotely};
        {ok, {{"HTTP/1.1", Code, _}, _Headers, Return} } 
            when Code =:= 200 orelse Code =:= 201 ->
            {ok, Return};
        {ok, {Reason, _, _}} ->
            {error, Reason}
    end.

get_http_data(ResponseBody) ->
    maps:get(<<"data">>, emqx_json:decode(ResponseBody, [return_maps])).

auth_header(Username, Password) ->
    {ok, Token} = emqx_dashboard_admin:sign_token(Username, Password),
    {"Authorization", "Bearer " ++ binary_to_list(Token)}.

default_auth_header() ->
    auth_header(?DEF_USERNAME, ?DEF_PASSWORD).

create_default_app() ->
    emqx_dashboard_admin:add_user(?DEF_USERNAME, ?DEF_PASSWORD, <<"admin">>).

delete_default_app() ->
    emqx_mgmt_auth:remove_user(?DEF_USERNAME).
