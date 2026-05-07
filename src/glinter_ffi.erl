-module(glinter_ffi).
-export([monotonic_time_ms/0, pmap/2]).

monotonic_time_ms() ->
    erlang:monotonic_time(millisecond).

pmap(Fun, List) ->
    Parent = self(),
    Pids = [
        spawn_link(fun() ->
            try
                Result = Fun(Item),
                Parent ! {self(), {ok, Result}}
            catch
                Class:Reason:Stack ->
                    Parent ! {self(), {error, Class, Reason, Stack}}
            end
        end) || Item <- List
    ],
    [
        receive
            {Pid, {ok, Result}} -> Result;
            {Pid, {error, Class, Reason, Stack}} ->
                erlang:raise(Class, Reason, Stack)
        end || Pid <- Pids
    ].
