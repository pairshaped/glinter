-module(glinter_ffi).
-export([monotonic_time_ms/0, pmap/2]).

monotonic_time_ms() ->
    erlang:monotonic_time(millisecond).

pmap(Fun, List) ->
    Parent = self(),
    Pids = [spawn_link(fun() ->
        Result = try Fun(Item)
        catch _:Reason -> {error, Reason}
        end,
        Parent ! {self(), Result}
    end) || Item <- List],
    [receive {Pid, Result} -> Result end || Pid <- Pids].
