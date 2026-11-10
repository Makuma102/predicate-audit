function [tf, firstStep] = persistWindow(trace, window, extra)
%PERSISTWINDOW True if the predicate holds for WINDOW consecutive steps.
%   tf = predaudit.persistWindow(trace, window) takes the per-step success
%   predicate of an extended rollout (logical vector, one element per
%   simulator step, not stopped at the first success).
%   tf = predaudit.persistWindow(trace, window, extra) additionally requires
%   the logical vector extra (object at rest, gripper released, ...) to
%   hold on the same steps. This gives graders G1 (trace only), G2 and G3.
%   firstStep is the index at which the window is first completed, or NaN.
%
%   window = 1 reproduces the built-in first-hit behaviour.

    arguments
        trace
        window (1,1) double {mustBePositive, mustBeInteger}
        extra = []
    end
    ok = logical(trace(:));
    if ~isempty(extra)
        extra = logical(extra(:));
        if numel(extra) ~= numel(ok)
            error('predaudit:persistWindow:lengthMismatch', ...
                'trace has %d steps but extra has %d.', numel(ok), numel(extra));
        end
        ok = ok & extra;
    end
    tf = false;
    firstStep = NaN;
    run = 0;
    for t = 1:numel(ok)
        if ok(t)
            run = run + 1;
        else
            run = 0;
        end
        if run >= window
            tf = true;
            firstStep = t;
            return
        end
    end
end
