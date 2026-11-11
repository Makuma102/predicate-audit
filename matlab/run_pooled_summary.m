function out = run_pooled_summary(suites, nBoot)
%RUN_POOLED_SUMMARY Pool the extension audit over suites and predicate types.
%   out = run_pooled_summary() grades the extension logs of libero_spatial,
%   libero_object, libero_goal and libero_10 (both protocols), joins each
%   task with its goal-predicate types from build_libero_taxonomy and writes
%   to results/pooled/:
%     by_suite.csv      per suite and protocol
%     by_predicate.csv  per goal-predicate class and protocol
%     overall.csv       all demonstrations per protocol
%     concentration.csv share of lost successes from the top-k tasks
%
%   Every rate has two intervals:
%     exact      Clopper-Pearson, treats demonstrations as independent
%     cluster    percentile bootstrap that resamples whole tasks, because
%                demonstrations of one task share scene, objects and goal
%   The cluster interval is the one to quote for pooled rates. With few
%   tasks in a group (under about 10) it is itself rough.

    arguments
        suites (1,:) string = ["libero_spatial", "libero_object", "libero_goal", "libero_10"]
        nBoot (1,1) double = 5000
    end
    here = fileparts(mfilename('fullpath'));
    addpath(here);
    outDir = fullfile(here, '..', 'results', 'pooled');
    if ~isfolder(outDir)
        mkdir(outDir);
    end
    taxFile = fullfile(here, '..', 'results', 'taxonomy', 'libero_tasks.csv');
    if ~isfile(taxFile)
        build_libero_taxonomy(suites);
    end
    tax = readtable(taxFile, 'TextType', 'string');

    E = table();
    for p = ["release", "hold"]
        for s = suites
            run_extension_audit(s, p);
            f = fullfile(here, '..', 'results', 'extension_audit', s, p, 'episodes.csv');
            T = readtable(f, 'TextType', 'string');
            T.suite = repmat(s, height(T), 1);
            T.protocol = repmat(p, height(T), 1);
            E = [E; T]; %#ok<AGROW>
        end
    end
    % predicate class of the task: sorted unique goal-predicate types
    key = lower(tax.suite + "/" + tax.task);
    cls = strings(height(tax), 1);
    for i = 1:height(tax)
        cls(i) = strjoin(unique(split(tax.predicateTypes(i), "+")), "+");
    end
    [found, loc] = ismember(lower(E.suite + "/" + E.task), key);
    if ~all(found)
        missing = unique(E.task(~found));
        error('run_pooled_summary:taxonomy', ...
            '%d task(s) have no taxonomy row, e.g. %s.', numel(missing), missing(1));
    end
    E.predicateClass = cls(loc);
    E.taskKey = E.suite + "/" + E.task;
    E.failPersist100 = E.g0 == 1 & E.g1_100 == 0;
    E.failPersist30 = E.g0 == 1 & E.g1_30 == 0;
    E.lost = E.lost == 1;
    E.flicker = E.flicker == 1;

    rs = RandStream('mt19937ar', 'Seed', 0);
    out.bySuite = summarise(E, "suite", nBoot, rs);
    out.byPredicate = summarise(E, "predicateClass", nBoot, rs);
    E.all = repmat("all", height(E), 1);
    out.overall = summarise(E, "all", nBoot, rs);

    prot = strings(0, 1); k = []; share = []; uniformShare = []; total = [];
    for p = ["release", "hold"]
        in = E.protocol == p;
        c = predaudit.topKConcentration(E.taskKey(in), E.lost(in), [1 3 5]);
        prot = [prot; repmat(p, 3, 1)]; %#ok<AGROW>
        k = [k; c.k(:)]; share = [share; c.share(:)]; %#ok<AGROW>
        uniformShare = [uniformShare; c.uniformShare(:)]; %#ok<AGROW>
        total = [total; repmat(c.totalDiscrepancies, 3, 1)]; %#ok<AGROW>
    end
    out.concentration = table(prot, k, share, uniformShare, total, ...
        'VariableNames', {'protocol', 'k', 'shareOfLost', 'uniformShare', 'totalLost'});

    writetable(out.bySuite, fullfile(outDir, 'by_suite.csv'));
    writetable(out.byPredicate, fullfile(outDir, 'by_predicate.csv'));
    writetable(out.overall, fullfile(outDir, 'overall.csv'));
    writetable(out.concentration, fullfile(outDir, 'concentration.csv'));
    writetable(E, fullfile(outDir, 'episodes_all.csv'));
    disp(out.overall); disp(out.bySuite); disp(out.byPredicate); disp(out.concentration);
    fprintf('Written to %s\n', outDir);
end

function S = summarise(E, groupVar, nBoot, rs)
    measures = ["lost", "flicker", "failPersist30", "failPersist100"];
    rows = {};
    [g, gName, gProt] = findgroups(E.(groupVar), E.protocol);
    for i = 1:max(g)
        in = (g == i);
        n = sum(in);
        r = struct('group', gName(i), 'protocol', gProt(i), ...
            'nTasks', numel(unique(E.taskKey(in))), 'n', n);
        for m = measures
            x = E.(m)(in);
            kk = sum(x);
            [lo, hi, rate] = predaudit.clopperPearson(kk, n);
            [clo, chi] = clusterBoot(x, E.taskKey(in), nBoot, rs);
            r.(m + "K") = kk;
            r.(m + "Rate") = rate;
            r.(m + "ExactLo") = lo;
            r.(m + "ExactHi") = hi;
            r.(m + "ClusterLo") = clo;
            r.(m + "ClusterHi") = chi;
        end
        rows{end + 1, 1} = r; %#ok<AGROW>
    end
    S = struct2table([rows{:}].');
end

function [lo, hi] = clusterBoot(x, cluster, nBoot, rs)
    % Percentile bootstrap over clusters (tasks): resample tasks with
    % replacement, pool their episodes, recompute the rate.
    [c, ~] = findgroups(cluster);
    nC = max(c);
    ksum = accumarray(c, double(x));
    nsum = accumarray(c, 1);
    if nC < 2
        lo = NaN; hi = NaN;
        return
    end
    idx = randi(rs, nC, nC, nBoot);
    rates = sum(ksum(idx), 1) ./ sum(nsum(idx), 1);
    rates = sort(rates);
    lo = rates(max(1, floor(0.025 * nBoot) + 1));
    hi = rates(min(nBoot, ceil(0.975 * nBoot)));
end
