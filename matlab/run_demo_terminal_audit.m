function summary = run_demo_terminal_audit(suite, opts)
%RUN_DEMO_TERMINAL_AUDIT Real-data screening of how LIBERO demonstrations end.
%   summary = run_demo_terminal_audit("libero_goal") runs
%   predaudit.demoTerminalAudit on every file in matlab/data/<suite>/ and
%   writes to results/demo_terminal_audit/<suite>/:
%     episodes.csv  one row per (demonstration, goal object)
%     tasks.csv     per task: number of accepted demonstrations, how many
%                   end with the goal object still moving, how many end
%                   with the gripper not open, each with an exact
%                   (Clopper-Pearson) 95% interval
%     config.json   thresholds used
%
%   Get the data first with download_libero_suite(suite). Tasks whose goal
%   object has no free joint (drawers, stove knobs) get NaN in the motion
%   columns.

    arguments
        suite (1,1) string
        opts.DataDir (1,1) string = ""
        opts.LinTol (1,1) double = 0.01
        opts.AngTol (1,1) double = 0.10
        opts.Window (1,1) double = 10
        opts.ReleaseFrac (1,1) double = 0.90
    end
    here = fileparts(mfilename('fullpath'));
    addpath(here);
    if opts.DataDir == ""
        opts.DataDir = fullfile(here, "data", suite);
    end
    listing = dir(fullfile(opts.DataDir, "*.hdf5"));
    if isempty(listing)
        error('run_demo_terminal_audit:noData', ...
            'No .hdf5 files in %s. Run download_libero_suite("%s") first.', ...
            opts.DataDir, suite);
    end
    outDir = fullfile(here, "..", "results", "demo_terminal_audit", suite);
    if ~isfolder(outDir)
        mkdir(outDir);
    end

    episodes = table();
    task = strings(0, 1); nDemos = []; nMoving = []; nHeld = []; nFree = [];
    for i = 1:numel(listing)
        f = fullfile(listing(i).folder, listing(i).name);
        fprintf('%s\n', listing(i).name);
        T = predaudit.demoTerminalAudit(f, LinTol=opts.LinTol, AngTol=opts.AngTol, ...
            Window=opts.Window, ReleaseFrac=opts.ReleaseFrac);
        T.task = repmat(erase(string(listing(i).name), "_demo.hdf5"), height(T), 1);
        episodes = [episodes; T]; %#ok<AGROW>

        % One verdict per demonstration: moving if any goal object moves.
        [g, demo] = findgroups(T.demo);
        free = splitapply(@any, T.hasFreeJoint, g);
        moving = splitapply(@(a, h) any(h & ~a), T.atRest, T.hasFreeJoint, g);
        held = splitapply(@(r) ~all(r), T.released, g);
        task(end + 1, 1) = T.task(1); %#ok<AGROW>
        nDemos(end + 1, 1) = numel(demo); %#ok<AGROW>
        nFree(end + 1, 1) = sum(free); %#ok<AGROW>
        nMoving(end + 1, 1) = sum(moving); %#ok<AGROW>
        nHeld(end + 1, 1) = sum(held); %#ok<AGROW>
    end

    nT = numel(task);
    movingRate = nan(nT, 1); movingLo = nan(nT, 1); movingHi = nan(nT, 1);
    heldRate = nan(nT, 1); heldLo = nan(nT, 1); heldHi = nan(nT, 1);
    for i = 1:nT
        if nFree(i) > 0
            [movingLo(i), movingHi(i), movingRate(i)] = ...
                predaudit.clopperPearson(nMoving(i), nFree(i));
        end
        [heldLo(i), heldHi(i), heldRate(i)] = predaudit.clopperPearson(nHeld(i), nDemos(i));
    end
    summary = table(task, nDemos, nFree, nMoving, movingRate, movingLo, movingHi, ...
        nHeld, heldRate, heldLo, heldHi);

    writetable(episodes, fullfile(outDir, "episodes.csv"));
    writetable(summary, fullfile(outDir, "tasks.csv"));
    cfg = struct('suite', suite, 'linTol', opts.LinTol, 'angTol', opts.AngTol, ...
        'window', opts.Window, 'releaseFrac', opts.ReleaseFrac, ...
        'matlabRelease', version('-release'), 'date', string(datetime('now')));
    fid = fopen(fullfile(outDir, "config.json"), 'w');
    fwrite(fid, jsonencode(cfg, PrettyPrint=true));
    fclose(fid);
    disp(summary);
    fprintf('Written to %s\n', outDir);
end
