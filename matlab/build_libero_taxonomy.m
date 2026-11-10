function [tasks, counts] = build_libero_taxonomy(suites)
%BUILD_LIBERO_TAXONOMY Static table of goal predicates for every LIBERO task.
%   [tasks, counts] = build_libero_taxonomy() fetches the task definition
%   (.bddl) files of libero_spatial, libero_object, libero_goal and
%   libero_10 from the LIBERO repository (cached in matlab/data/bddl/),
%   parses each goal with predaudit.parseBddlGoal and writes
%     results/taxonomy/libero_tasks.csv       one row per task
%     results/taxonomy/libero_predicates.csv  one row per goal predicate
%     results/taxonomy/libero_counts.csv      tasks and predicates per type
%
%   The checker-behaviour columns are the same for every LIBERO task
%   because they come from the shared environment code, not from the task
%   file: the predicate is evaluated on every step and returned as `done`
%   (first hit), and no predicate has a release, at-rest or persistence
%   condition (envs/bddl_base_domain.py, envs/predicates/base_predicates.py).

    arguments
        suites (1,:) string = ["libero_spatial", "libero_object", "libero_goal", "libero_10"]
    end
    here = fileparts(mfilename('fullpath'));
    addpath(here);
    outDir = fullfile(here, '..', 'results', 'taxonomy');
    if ~isfolder(outDir)
        mkdir(outDir);
    end
    api = "https://api.github.com/repos/Lifelong-Robot-Learning/LIBERO/contents/libero/libero/bddl_files/";
    raw = "https://raw.githubusercontent.com/Lifelong-Robot-Learning/LIBERO/master/libero/libero/bddl_files/";
    wo = weboptions('Timeout', 60, 'ContentType', 'json');

    suiteCol = strings(0, 1); taskCol = strings(0, 1); nPred = zeros(0, 1);
    typesCol = strings(0, 1); goalCol = strings(0, 1);
    pSuite = strings(0, 1); pTask = strings(0, 1); pName = strings(0, 1);
    pArg1 = strings(0, 1); pArg2 = strings(0, 1);
    for s = suites
        cacheDir = fullfile(here, 'data', 'bddl', s);
        if ~isfolder(cacheDir)
            mkdir(cacheDir);
        end
        try
            listing = webread(api + s, wo);
        catch err
            error('build_libero_taxonomy:listing', ...
                'Could not list the task files of %s (%s).', s, err.message);
        end
        if iscell(listing)
            names = string(cellfun(@(c) c.name, listing, 'UniformOutput', false));
        else
            names = string({listing.name});
        end
        names = sort(names(endsWith(names, ".bddl")));
        fprintf('%s: %d tasks\n', s, numel(names));
        for nm = names(:).'
            target = fullfile(cacheDir, nm);
            if ~isfile(target)
                websave(target, raw + s + "/" + nm, weboptions('Timeout', 60));
            end
            g = predaudit.parseBddlGoal(fileread(target));
            suiteCol(end + 1, 1) = s; %#ok<AGROW>
            taskCol(end + 1, 1) = erase(nm, ".bddl"); %#ok<AGROW>
            nPred(end + 1, 1) = height(g); %#ok<AGROW>
            typesCol(end + 1, 1) = strjoin(g.predicate, "+"); %#ok<AGROW>
            goalCol(end + 1, 1) = strjoin(strtrim(g.predicate + " " + g.arg1 + " " + g.arg2), "; "); %#ok<AGROW>
            k = height(g);
            pSuite = [pSuite; repmat(s, k, 1)]; %#ok<AGROW>
            pTask = [pTask; repmat(erase(nm, ".bddl"), k, 1)]; %#ok<AGROW>
            pName = [pName; g.predicate]; %#ok<AGROW>
            pArg1 = [pArg1; g.arg1]; %#ok<AGROW>
            pArg2 = [pArg2; g.arg2]; %#ok<AGROW>
        end
    end
    n = numel(taskCol);
    tasks = table(suiteCol, taskCol, nPred, typesCol, goalCol, nPred > 1, ...
        repmat("every step, first hit ends the episode", n, 1), ...
        repmat("no", n, 1), repmat("none", n, 1), ...
        'VariableNames', {'suite', 'task', 'nGoalPredicates', 'predicateTypes', 'goal', ...
        'composite', 'evaluation', 'releaseRequired', 'persistenceRequired'});
    predicates = table(pSuite, pTask, pName, pArg1, pArg2, ...
        'VariableNames', {'suite', 'task', 'predicate', 'arg1', 'arg2'});

    [g, pType] = findgroups(predicates.predicate);
    nPredicates = accumarray(g, 1);
    nTasks = zeros(numel(pType), 1);
    for i = 1:numel(pType)
        nTasks(i) = numel(unique(predicates.suite(g == i) + "/" + predicates.task(g == i)));
    end
    counts = table(pType, nPredicates, nTasks, ...
        'VariableNames', {'predicate', 'goalPredicates', 'tasksUsingIt'});

    writetable(tasks, fullfile(outDir, 'libero_tasks.csv'));
    writetable(predicates, fullfile(outDir, 'libero_predicates.csv'));
    writetable(counts, fullfile(outDir, 'libero_counts.csv'));
    disp(counts);
    fprintf('%d tasks, %d goal predicates. Written to %s\n', n, height(predicates), outDir);
end
