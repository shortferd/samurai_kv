%%%-------------------------------------------------------------------
%% @doc samurai_kv storage worker.
%% @end
%%%-------------------------------------------------------------------

-module(samurai_kv_storage_worker).

-behaviour(gen_server).

-export([start_link/1]).

-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

% -define(SERVER, ?MODULE).

-record(state, {max_keys, max_val_len}).

start_link(Args) ->
    gen_server:start_link(?MODULE, Args,[]). 

init(Args) ->
    MaxKeys = proplists:get_value(max_keys, Args),
    MaxValueLen = proplists:get_value(max_val_len, Args),
    {ok,#state{max_keys = MaxKeys,
               max_val_len = MaxValueLen}}.

handle_call({insert, Key, Value}, _From, #state{max_keys = MaxKeys, max_val_len = MaxValLen}=State) ->
    Reply = case ets:lookup(storage, Key) of
                [] when byte_size(Value) < MaxValLen -> 
                    case ets:info(storage, size) < MaxKeys of
                        true ->
                            ets:insert(storage, {Key, Value}),
                            {ok, <<"Key added">>};
                        false ->
                            {error, <<"Storage size exceeded">>}
                    end;
                _ when byte_size(Value) < MaxValLen ->
                    ets:insert(storage, {Key, Value}),
                    {ok, <<"Key changed">>};
                _ ->
                    {error, <<"Maximal value length exceeded">>}
    end,
    {reply, Reply, State};
handle_call({delete, Key}, _From, State) ->
    ets:delete(storage, Key),
    {reply, {ok,"Key deleted"}, State};
handle_call({get, Key}, _From, State) ->
    Reply = case ets:lookup(storage, Key) of
        [] ->
            {error, <<"Key doesn't exist">>};
        [{Key, Value}] ->
            {ok, Value}
    end,
    {reply, Reply, State};
handle_call(Request, _From, State) ->
    logger:info("Request ~p  from ~p received", [Request,_From]),
    {reply, ok, State}.

handle_cast(Msg, State) ->
    logger:info("Request ~p received", [Msg]),
    {noreply, State}.

handle_info(Info, State) ->
    logger:info("Info ~p received", [Info]),
    {noreply, State}.

terminate(Reason, _) ->
    logger:info("Process ~p terminated with reason ~p", [?MODULE, Reason]),
    ok.