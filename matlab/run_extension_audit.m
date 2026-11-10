function summary = run_extension_audit(suite, protocol)
%RUN_EXTENSION_AUDIT Grade extended replays of official LIBERO demonstrations.
%   summary = run_extension_audit("libero_goal", "release") reads the logs
%   written by sim_shim/replay_demos.py in results/extension/<suite>/ and
%   grades every demonstration with the trace graders.
%
%   Each log holds, per demonstration, the built-in predicate evaluated
%   on every logged demonstration state (predicate_demo) and on EXTRA
%   further control steps simulated from the exact last logged state
%   (predicate_ext). The full trace is their concatenation.
%   The logs also contain an open-loop replay of the logged actions. With
%   a MuJoCo version other than the recording one it drifts, so it is only
%   reported (nTrueOpenLoopReplay, openLoopDivergence), never graded.
%
%   Verdicts per demonstration:
%     g0         first hit: the predicate is true on at least one step
%     endExt     the predicate is true on the last simulated step
%     lost       g0 is true but endExt is false: the benchmark would have
%                counted a success that is gone after the extension
%     flicker    the predicate turns false at least once after its first hit
%     g1_N       the predicate holds for N consecutive steps, N = 10, 30, 100
%   The reference here is the simulator's own predicate at the end of the
%   extension, not a human label, so "lost" is a simulator-referenced
%   false-success count for demonstrations, under the stated protocol.
%
%   Writes results/extension_audit/<suite>/<protocol>/episodes.csv and
%   tasks.csv (exact Clopper-Pearson 95% intervals).

    arguments
        suite (1,1) string
        protocol (1,1) string {mustBeMember(protocol, ["release", "hold"])} = "release"
    end
    here = fileparts(mfilename('fullpath'));
    addpath(here);
    inDir = fullfile(here, '..', 'results', 'extension', suite);
    listing = dir(fullfile(inDir, "*_" + protocol + ".h5"));
    if isempty(listing)
        error('run_extension_audit:noLogs', ...
            'No *_%s.h5 logs in %s. Run sim_shim/replay_demos.py first.', protocol, inDir);
    end
    outDir = fullfile(here, '..', 'results', 'extension_audit', suite, protocol);
    if ~isfolder(outDir)
        mkdir(outDir);
    end
    windows = [10 30 100];

    task = strings(0, 1); demo = strings(0, 1);
    divergence = []; nTrueLogged = [];
    nDemoSteps = []; firstHitStep = []; nTrueDemo = []; nTrueExt = []; nExt = [];
    g0 = false(0, 1); endExt = false(0, 1); flicker = false(0, 1);
    g1 = false(0, numel(windows));
    for i = 1:numel(listing)
        f = fullfile(listing(i).folder, listing(i).name);
        name = erase(string(listing(i).name), "_" + protocol + ".h5");
        info = h5info(f);
        for d = 1:numel(info.Groups)
            grp = info.Groups(d).Name;
            pd = logical(h5read(f, [grp '/predicate_demo']));
            pe = logical(h5read(f, [grp '/predicate_ext']));
            pLogged = logical(h5read(f, [grp '/predicate_replay']));
            trace = [pd(:); pe(:)];
            divergence(end + 1, 1) = double(h5readatt(f, grp, 'replay_divergence')); %#ok<AGROW>
            nTrueLogged(end + 1, 1) = sum(pLogged); %#ok<AGROW>
            first = find(trace, 1);
            task(end + 1, 1) = name; %#ok<AGROW>
            demo(end + 1, 1) = string(grp); %#ok<AGROW>
            nDemoSteps(end + 1, 1) = numel(pd); %#ok<AGROW>
            nTrueDemo(end + 1, 1) = sum(pd); %#ok<AGROW>
            nTrueExt(end + 1, 1) = sum(pe); %#ok<AGROW>
            nExt(end + 1, 1) = numel(pe); %#ok<AGROW>
            g0(end + 1, 1) = predaudit.firstHit(trace); %#ok<AGROW>
            endExt(end + 1, 1) = predaudit.endOfEpisode(trace); %#ok<AGROW>
            if isempty(first)
                firstHitStep(end + 1, 1) = NaN; %#ok<AGROW>
                flicker(end + 1, 1) = false; %#ok<AGROW>
            else
                firstHitStep(end + 1, 1) = first; %#ok<AGROW>
                flicker(end + 1, 1) = any(~trace(first:end)); %#ok<AGROW>
            end
            row = false(1, numel(windows));
            for w = 1:numel(windows)
                row(w) = predaudit.persistWindow(trace, windows(w));
            end
            g1(end + 1, :) = row; %#ok<AGROW>
        end
    end
    lost = g0 & ~endExt;
    episodes = table(task, demo, nDemoSteps, firstHitStep, nTrueDemo, nTrueLogged, divergence, nExt, nTrueExt, ...
        g0, endExt, lost, flicker, g1(:, 1), g1(:, 2), g1(:, 3), ...
        'VariableNames', {'task', 'demo', 'nDemoSteps', 'firstHitStep', 'nTrueLogged', ...
        'nTrueOpenLoopReplay', 'openLoopDivergence', 'nExt', 'nTrueExt', 'g0', 'endExt', 'lost', 'flicker', 'g1_10', 'g1_30', 'g1_100'});

    [g, taskName] = findgroups(episodes.task);
    nT = numel(taskName);
    nDemos = accumarray(g, 1);
    nG0 = accumarray(g, double(episodes.g0));
    nLost = accumarray(g, double(episodes.lost));
    nFlicker = accumarray(g, double(episodes.flicker));
    maxDivergence = accumarray(g, episodes.openLoopDivergence, [], @max);
    nFail10 = accumarray(g, double(episodes.g0 & ~episodes.g1_10));
    nFail30 = accumarray(g, double(episodes.g0 & ~episodes.g1_30));
    nFail100 = accumarray(g, double(episodes.g0 & ~episodes.g1_100));
    lostRate = nan(nT, 1); lostLo = nan(nT, 1); lostHi = nan(nT, 1);
    fail100Rate = nan(nT, 1); fail100Lo = nan(nT, 1); fail100Hi = nan(nT, 1);
    for i = 1:nT
        [lostLo(i), lostHi(i), lostRate(i)] = predaudit.clopperPearson(nLost(i), nG0(i));
        [fail100Lo(i), fail100Hi(i), fail100Rate(i)] = ...
            predaudit.clopperPearson(nFail100(i), nG0(i));
    end
    summary = table(taskName, nDemos, maxDivergence, nG0, nLost, lostRate, lostLo, lostHi, nFlicker, ...
        nFail10, nFail30, nFail100, fail100Rate, fail100Lo, fail100Hi, ...
        'VariableNames', {'task', 'nDemos', 'maxOpenLoopDivergence', 'nG0', 'nLost', 'lostRate', 'lostLo', 'lostHi', ...
        'nFlicker', 'nFailPersist10', 'nFailPersist30', 'nFailPersist100', ...
        'failPersist100Rate', 'failPersist100Lo', 'failPersist100Hi'});

    writetable(episodes, fullfile(outDir, 'episodes.csv'));
    writetable(summary, fullfile(outDir, 'tasks.csv'));
    disp(summary);
    fprintf('%s / %s: %d demonstrations, %d first-hit successes, %d lost after the extension.\n', ...
        suite, protocol, height(episodes), sum(episodes.g0), sum(lost));
    fprintf('Written to %s\n', outDir);
end
