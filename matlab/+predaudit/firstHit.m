function tf = firstHit(trace)
%FIRSTHIT Built-in verdict of first-success benchmarks: any true step counts.
%   tf = predaudit.firstHit(trace). LIBERO behaves this way: its step()
%   returns done = _check_success() on every step, and evaluation loops stop
%   at the first done.

    arguments
        trace {mustBeVector}
    end
    tf = any(logical(trace));
end
