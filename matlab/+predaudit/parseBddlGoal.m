function goal = parseBddlGoal(bddlText)
%PARSEBDDLGOAL Extract the goal predicates of a LIBERO task.
%   goal = predaudit.parseBddlGoal(bddlText) reads the BDDL task text (the
%   'bddl_file_content' attribute of a LIBERO dataset file) and returns a
%   table with one row per atomic goal predicate:
%     predicate  e.g. "On", "In", "Open", "Close", "TurnOn"
%     arg1       first argument (the object that has to move, or the
%                articulated part for unary predicates)
%     arg2       second argument, "" for unary predicates
%
%   Example goal: (:goal (And (On akita_black_bowl_1 plate_1)))
%   Meaning in LIBERO's source (base_predicates.py, base_object_states.py):
%     In(a, b)  b is in contact with a AND a is inside b's containment box
%     On(a, b)  for a plain object b: a and b are in contact, their xy
%               distance is below 0.03 m and b's origin is not above a's
%     Open / Close / TurnOn / TurnOff  thresholds on the joint position

    arguments
        bddlText {mustBeTextScalar}
    end
    txt = char(bddlText);
    at = regexpi(txt, '\(\s*:goal', 'once');
    if isempty(at)
        error('predaudit:parseBddlGoal:noGoal', ...
            'No (:goal ...) section found in the BDDL text.');
    end
    tok = regexp(txt(at:end), '\(\s*([A-Za-z]\w*)\s+([\w\-]+)(?:\s+([\w\-]+))?\s*\)', 'tokens');
    n = numel(tok);
    predicate = strings(n, 1); arg1 = strings(n, 1); arg2 = strings(n, 1);
    for i = 1:n
        predicate(i) = tok{i}{1};
        arg1(i) = tok{i}{2};
        if numel(tok{i}) >= 3
            arg2(i) = tok{i}{3};
        end
    end
    goal = table(predicate, arg1, arg2);
    if n == 0
        error('predaudit:parseBddlGoal:empty', ...
            'The goal section contains no atomic predicate.');
    end
end
