function layout = mjcfJointLayout(xmlText)
%MJCFJOINTLAYOUT Map MuJoCo joints to their slots in qpos and qvel.
%   layout = predaudit.mjcfJointLayout(xmlText) parses a MuJoCo MJCF model
%   (the text stored in the 'model_file' attribute of every LIBERO demo)
%   and returns a struct with
%     joints  table: joint, body, type, qposAdr, qposDim, qvelAdr, qvelDim
%             (addresses are 1-based offsets inside qpos / qvel)
%     nq, nv  total sizes of qpos and qvel
%
%   MuJoCo numbers bodies depth-first in document order and lays out the
%   joints of a body before those of its children. Slot sizes are
%     free 7 / 6 (position 3 + unit quaternion 4 / linear 3 + angular 3),
%     ball 4 / 3, hinge and slide 1 / 1.
%   A joint with no type attribute is treated as a hinge, MuJoCo's default.
%   A type set only through a <default> class is not resolved here; callers
%   compare 1 + nq + nv with the width of the logged state to catch that.

    arguments
        xmlText {mustBeTextScalar}
    end
    tmp = [tempname, '.xml'];
    fid = fopen(tmp, 'w', 'n', 'UTF-8');
    if fid < 0
        error('predaudit:mjcfJointLayout:tempFile', 'Cannot write temporary file %s.', tmp);
    end
    cleaner = onCleanup(@() delete(tmp));
    fwrite(fid, char(xmlText), 'char');
    fclose(fid);
    try
        doc = xmlread(tmp);
    catch err
        error('predaudit:mjcfJointLayout:parse', ...
            'The model text is not valid XML: %s', err.message);
    end
    wbList = doc.getDocumentElement().getElementsByTagName('worldbody');
    if wbList.getLength() == 0
        error('predaudit:mjcfJointLayout:noWorldbody', ...
            'The model has no <worldbody> element.');
    end

    names = {}; bodies = {}; types = {};
    for w = 0:wbList.getLength() - 1
        walk(wbList.item(w), 'world');
    end

    nJ = numel(names);
    qposDim = zeros(nJ, 1); qvelDim = zeros(nJ, 1);
    for i = 1:nJ
        switch types{i}
            case 'free'
                qposDim(i) = 7; qvelDim(i) = 6;
            case 'ball'
                qposDim(i) = 4; qvelDim(i) = 3;
            case {'hinge', 'slide'}
                qposDim(i) = 1; qvelDim(i) = 1;
            otherwise
                error('predaudit:mjcfJointLayout:jointType', ...
                    'Joint "%s" has unknown type "%s".', names{i}, types{i});
        end
    end
    qposAdr = cumsum([1; qposDim(1:end-1)]);
    qvelAdr = cumsum([1; qvelDim(1:end-1)]);
    if nJ == 0
        qposAdr = zeros(0, 1); qvelAdr = zeros(0, 1);
    end
    layout.joints = table(string(names(:)), string(bodies(:)), string(types(:)), ...
        qposAdr, qposDim, qvelAdr, qvelDim, ...
        'VariableNames', {'joint', 'body', 'type', 'qposAdr', 'qposDim', 'qvelAdr', 'qvelDim'});
    layout.nq = sum(qposDim);
    layout.nv = sum(qvelDim);

    function walk(node, bodyName)
        kids = node.getChildNodes();
        childBodies = {};
        for k = 0:kids.getLength() - 1
            c = kids.item(k);
            if c.getNodeType() ~= 1          % 1 = ELEMENT_NODE
                continue
            end
            tag = char(c.getNodeName());
            if strcmp(tag, 'joint') || strcmp(tag, 'freejoint')
                t = char(c.getAttribute('type'));
                if strcmp(tag, 'freejoint')
                    t = 'free';
                elseif isempty(t)
                    t = 'hinge';
                end
                names{end + 1} = char(c.getAttribute('name')); %#ok<AGROW>
                bodies{end + 1} = bodyName; %#ok<AGROW>
                types{end + 1} = t; %#ok<AGROW>
            elseif strcmp(tag, 'body')
                childBodies{end + 1} = c; %#ok<AGROW>
            end
        end
        for k = 1:numel(childBodies)
            walk(childBodies{k}, char(childBodies{k}.getAttribute('name')));
        end
    end
end
