function info = readLiberoFile(file)
%READLIBEROFILE List the demonstrations and task metadata of a LIBERO file.
%   info = predaudit.readLiberoFile(file) opens one official LIBERO
%   demonstration file (<task>_demo.hdf5) and returns
%     file         the path
%     demos        string column of group paths, e.g. "/data/demo_0"
%     bddl         the BDDL task text. Taken from the 'bddl_file_content'
%                  attribute if present; the released files only have
%                  'bddl_file_name', so the task file is then fetched
%                  once from the LIBERO repository and cached next to
%                  the data file
%     goal         table from predaudit.parseBddlGoal
%
%   File layout (LIBERO scripts/create_dataset.py):
%     /data                attrs: env_name, env_args, problem_info,
%                                 bddl_file_name, num_demos, total, tag
%     /data/demo_i         attrs: model_file (MJCF text), init_state, num_samples
%       actions            T x 7   (last column: gripper command)
%       states             T x (1 + nq + nv) flattened MuJoCo state
%       robot_states, rewards, dones
%       obs/joint_states, obs/gripper_states, obs/ee_states, obs/ee_pos,
%       obs/ee_ori, obs/agentview_rgb, obs/eye_in_hand_rgb
%   rewards and dones are written as zeros with a 1 on the last step, so
%   they do not contain a per-step predicate trace.

    arguments
        file
    end
    file = char(file);
    if ~isfile(file)
        error('predaudit:readLiberoFile:notFound', 'File not found: %s', file);
    end
    try
        g = h5info(file, '/data');
    catch err
        error('predaudit:readLiberoFile:noData', ...
            '%s has no /data group, so it is not a LIBERO demonstration file (%s).', ...
            file, err.message);
    end
    if isempty(g.Groups)
        error('predaudit:readLiberoFile:noDemos', '%s contains no demonstrations.', file);
    end
    info.file = file;
    info.demos = string({g.Groups.Name}).';
    attNames = string({g.Attributes.Name});
    if any(attNames == "bddl_file_content")
        info.bddl = predaudit.h5text(h5readatt(file, '/data', 'bddl_file_content'));
    else
        % The released files carry only bddl_file_name (a path inside the
        % LIBERO repository). Use a copy cached next to the data file, or
        % fetch the task file from the LIBERO repository once.
        if ~any(attNames == "bddl_file_name")
            error('predaudit:readLiberoFile:noBddl', ...
                '%s has neither bddl_file_content nor bddl_file_name. Attributes present: %s', ...
                file, strjoin(attNames, ', '));
        end
        rel = predaudit.h5text(h5readatt(file, '/data', 'bddl_file_name'));
        [folder, ~, ~] = fileparts(file);
        [~, bddlName, bddlExt] = fileparts(rel);
        cached = fullfile(folder, [bddlName bddlExt]);
        if ~isfile(cached)
            url = ['https://raw.githubusercontent.com/Lifelong-Robot-Learning/LIBERO/master/' ...
                strrep(rel, '\', '/')];
            try
                websave(cached, url, weboptions('Timeout', 60));
            catch err
                error('predaudit:readLiberoFile:bddlFetch', ...
                    ['Could not fetch the task definition %s (%s). Put the file ', ...
                     'at %s by hand.'], url, err.message, cached);
            end
        end
        info.bddl = fileread(cached);
    end
    info.goal = predaudit.parseBddlGoal(info.bddl);
end
