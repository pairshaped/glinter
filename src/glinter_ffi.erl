-module(glinter_ffi).
-export([monotonic_time_ms/0]).

monotonic_time_ms() ->
    erlang:monotonic_time(millisecond).
