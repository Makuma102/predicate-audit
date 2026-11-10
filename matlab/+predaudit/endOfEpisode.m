function tf = endOfEpisode(trace)
%ENDOFEPISODE Verdict of benchmarks that only check the final step.
%   tf = predaudit.endOfEpisode(trace) is false for an empty trace.

    arguments
        trace
    end
    trace = logical(trace(:));
    tf = ~isempty(trace) && trace(end);
end
