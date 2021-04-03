%%%-------------------------------------------------------------------
%%% @author Jovan S. Dippenaar <jovan@twenty8.enterprises>
%%% @copyright (C) 2021, Twenty8 Enterprises
%%%-------------------------------------------------------------------
-module(emqx_ct_github_ci_helper).
-author("Jovan S. Dippenaar <jovan@twenty8.enterprises>").

%% API
-export([]).

main([ "get-matrix", SuiteStr | Args ]) ->
    ensure_code_paths(),
    Suite = list_to_atom(SuiteStr),
    Matrix = Suite:job_matrix(),
    
    
ensure_code_paths() ->
    erlang:error(not_implemented).
