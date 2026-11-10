function T = demoTerminalAudit(file, opts)
%DEMOTERMINALAUDIT How do accepted LIBERO demonstrations end?
%   T = predaudit.demoTerminalAudit(file) reads every demonstration in one
%   official LIBERO file and measures, from the logged MuJoCo state, the
%   speed of the goal object and the gripper opening at the end of the
%   episode. Every demonstration in these files was accepted by the
%   built-in success predicate (the collection script stops after the
%   predicate has held for 10 consecutive steps), so this shows what
%   fraction of built-in successes would not pass an at-rest or a
%   gripper-released requirement. It is a screening measurement on real
%   data; it is not a human-verified false-success rate.
%
%   Physics used:
%     state row   = [time, qpos (nq), qvel (nv)]
%     free joint  qpos = [x y z, qw qx qy qz], qvel = [v (3), omega (3)]
%     linear speed  = norm(v), angular speed = norm(omega)
%   The joint layout comes from the demo's own MJCF model, and the function
%   stops if 1 + nq + nv does not equal the logged state width.
%
%   Options (name-value):
%     LinTol       at-rest linear speed threshold in m/s      (default 0.01)
%     AngTol       at-rest angular speed threshold in rad/s   (default 0.10)
%     Window       number of final steps examined             (default 10)
%     ReleaseFrac  gripper counts as open when its aperture is at least
%                  this fraction of the episode maximum       (default 0.90)
%   The thresholds are analysis choices; report results for a sweep.
%   "Released" here is an aperture proxy. The real G3 grader needs contact
%   information, which only the simulator can provide.
%
%   Output: one table row per (demonstration, goal object).

    arguments
        file {mustBeTextScalar}
        opts.LinTol (1,1) double {mustBePositive} = 0.01
        opts.AngTol (1,1) double {mustBePositive} = 0.10
        opts.Window (1,1) double {mustBePositive, mustBeInteger} = 10
        opts.ReleaseFrac (1,1) double {mustBeInRange(opts.ReleaseFrac, 0, 1)} = 0.90
    end
    info = predaudit.readLiberoFile(file);
    objects = unique(info.goal.arg1, 'stable');
    rows = cell(0, 1);
    for d = 1:numel(info.demos)
        grp = char(info.demos(d));
        states = h5read(info.file, [grp '/states']).';        % T x D
        actions = h5read(info.file, [grp '/actions']).';      % T x 7
        grip = h5read(info.file, [grp '/obs/gripper_states']).';
        layout = predaudit.mjcfJointLayout( ...
            predaudit.h5text(h5readatt(info.file, grp, 'model_file')));
        D = size(states, 2);
        if D ~= 1 + layout.nq + layout.nv
            error('predaudit:demoTerminalAudit:stateWidth', ...
                ['%s %s: logged state has %d columns but the model gives ', ...
                 '1 + nq + nv = 1 + %d + %d = %d. The joint layout was not ', ...
                 'recovered correctly, so no kinematics are reported.'], ...
                info.file, grp, D, layout.nq, layout.nv, 1 + layout.nq + layout.nv);
        end
        nT = size(states, 1);
        last = max(1, nT - opts.Window + 1):nT;
        aperture = abs(grip(:, 1) - grip(:, end));
        apEnd = aperture(end);
        apMax = max(aperture);
        released = apEnd >= opts.ReleaseFrac * apMax;
        J = layout.joints;
        for o = 1:numel(objects)
            obj = objects(o);
            isObj = J.type == "free" & ...
                (J.body == obj | startsWith(J.body, obj + "_") | startsWith(J.joint, obj + "_"));
            r = struct('file', string(info.file), 'demo', string(grp), 'object', obj, ...
                'nSteps', nT, 'hasFreeJoint', any(isObj), ...
                'linSpeedEnd', NaN, 'angSpeedEnd', NaN, ...
                'linSpeedMaxWindow', NaN, 'angSpeedMaxWindow', NaN, ...
                'atRest', false, 'apertureEnd', apEnd, 'apertureMax', apMax, ...
                'gripperCommandEnd', actions(end, end), 'released', released);
            if sum(isObj) > 1
                error('predaudit:demoTerminalAudit:ambiguousObject', ...
                    '%s %s: object "%s" matches %d free joints (%s).', info.file, grp, ...
                    obj, sum(isObj), strjoin(J.joint(isObj), ', '));
            end
            if any(isObj)
                v0 = 1 + layout.nq + J.qvelAdr(isObj);        % column of v_x
                lin = vecnorm(states(:, v0:v0 + 2), 2, 2);
                ang = vecnorm(states(:, v0 + 3:v0 + 5), 2, 2);
                r.linSpeedEnd = lin(end);
                r.angSpeedEnd = ang(end);
                r.linSpeedMaxWindow = max(lin(last));
                r.angSpeedMaxWindow = max(ang(last));
                r.atRest = r.linSpeedMaxWindow < opts.LinTol && ...
                           r.angSpeedMaxWindow < opts.AngTol;
            end
            rows{end + 1, 1} = r; %#ok<AGROW>
        end
    end
    T = struct2table([rows{:}].');
end
