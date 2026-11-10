function out = topKConcentration(taskId, discrepant, k)
%TOPKCONCENTRATION Share of grader-vs-reference discrepancies from the top-k tasks.
%   out = predaudit.topKConcentration(taskId, discrepant) takes one task id
%   and one logical flag per episode (true where grader and reference
%   disagree) and returns, for k = 1, 3, 5, the fraction of all
%   discrepancies that come from the k tasks with the most discrepancies.
%   out.uniformShare is k / (number of tasks), the value expected if the
%   discrepancies were spread evenly, for comparison (RQ2).
%   out = predaudit.topKConcentration(taskId, discrepant, k) uses the given k.

    arguments
        taskId {mustBeVector}
        discrepant {mustBeVector}
        k (1,:) double {mustBePositive, mustBeInteger} = [1 3 5]
    end
    taskId = taskId(:);
    discrepant = logical(discrepant(:));
    if numel(taskId) ~= numel(discrepant)
        error('predaudit:topKConcentration:lengthMismatch', ...
            'taskId and discrepant must have one element per episode.');
    end
    [g, ids] = findgroups(taskId);
    counts = accumarray(g, double(discrepant));
    [sorted, order] = sort(counts, 'descend');
    total = sum(counts);
    nTasks = numel(counts);
    out.k = k;
    out.share = nan(size(k));
    if total > 0
        cs = cumsum(sorted);
        out.share = cs(min(k, nTasks)).' / total;
    end
    out.uniformShare = min(k, nTasks) / nTasks;
    out.totalDiscrepancies = total;
    out.perTask = table(ids(order), sorted, 'VariableNames', {'task', 'discrepancies'});
end
