%% The contents of this file are subject to the Mozilla Public License
%% Version 1.1 (the "License"); you may not use this file except in
%% compliance with the License. You may obtain a copy of the License
%% at http://www.mozilla.org/MPL/
%%
%% Software distributed under the License is distributed on an "AS IS"
%% basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
%% the License for the specific language governing rights and
%% limitations under the License.
%%
%% The Original Code is RabbitMQ.
%%
%% The Initial Developer of the Original Code is GoPivotal, Inc.
%% Copyright (c) 2007-2016 Pivotal Software, Inc.  All rights reserved.
%%

-module(rabbit_trust_store_app).
-behaviour(application).
-export([change_SSL_options/0]).
-export([start/2, stop/1]).


-rabbit_boot_step({rabbit_trust_store, [
    {description, "Change necessary SSL options."},
    {mfa, {?MODULE, change_SSL_options, []}},
    %% {cleanup, ...}, {requires, ...},
    {enables, networking}]}).

change_SSL_options() ->
    After = case application:get_env(rabbit, ssl_options) of
        undefined ->
            Before = [],
            edit(Before);
        {ok, Before} when is_list(Before) ->
            edit(Before)
    end,
    ok = application:set_env(rabbit,
        ssl_options, After, [{persistent, true}]).

start(normal, _) ->

    %% The below two are properties, that is, tuple of name/value.
    Path = whitelist_path(),
    Expiry = expiry_time(),

    rabbit_trust_store_sup:start_link([Path, Expiry]).

stop(_) ->
    ok.


%% Ancillary & Constants

edit(Options) ->
    false = lists:keymember(verify_fun, 1, Options),
    %% Only enter those options neccessary for this application.
    lists:keymerge(1, required_options(),
        [{verify_fun, {delegate(), continue}}|Options]).

delegate() -> fun rabbit_trust_store:whitelisted/3.

required_options() ->
    [{verify, verify_peer}, {fail_if_no_peer_cert, true}].

whitelist_path() ->
    Path = case application:get_env(whitelist) of
        undefined ->
            default_directory();
        {ok, V} when is_list(V) ->
            V
    end,
    ok = filelib:ensure_dir(Path),
    {whitelist, Path}.

expiry_time() ->
    case application:get_env(expiry) of
        undefined ->
            {expiry, default_expiry()};
        {ok, Seconds} when is_integer(Seconds), Seconds >= 0 ->
            {expiry, Seconds}
    end.

default_directory() ->
    filename:join([os:getenv("HOME"), "rabbit", "whitelist"]) ++ "/".

default_expiry() ->
    30.
