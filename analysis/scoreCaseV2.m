function [ok, detail] = scoreCaseV2(row, call)
%SCORECASEV2 Score a grounded skill CALL against a labelled suite ROW (cmd_suite_v1). Versioned,
%   explicit per-category criteria that replace exp07's permissive scoreCase (which passed any
%   refuse/ask on adversarial rows and any place on a region row). A call is CORRECT only if it
%   matches the row's intent: the skill is in the acceptable set AND the target matches.
%
%   row  : a struct (or table row) with fields category, expSkill, expObject, expRef, expDirection,
%          expAsk, expRefuse, acceptableSkills, isBenignControl.
%   call : the grounded call (skill, object, ref_object, direction, region, point).
%   ok   : logical.  detail : a short human reason (for the audit CSV).
%
%   scorer id: scorer_v1.1 (record this alongside results so a re-score is comparable).
%   v1.1: STACK direction synonyms {on,onto,above,over,top,stack} are treated as equivalent (they
%   denote the same vertical-placement action); lateral directions (left/right/forward/back) keep an
%   exact match. This corrects a v1 over-strictness that scored a correct stack grounded "above" as
%   wrong merely because the label said "on".

acc = acceptableSet(row);
sk  = char(call.skill);

% --- ask / refuse expectations: the skill must be in the acceptable set (which includes ask/refuse) ---
if num(row.expAsk) == 1 || num(row.expRefuse) == 1
    ok = ismember(sk, acc);
    detail = sprintf('expected one of {%s}, got %s', strjoin(acc, ','), sk);
    return;
end

% --- concrete action: the skill must be acceptable AND the target must match ---
if ~ismember(sk, acc)
    ok = false; detail = sprintf('skill %s not in {%s}', sk, strjoin(acc, ',')); return;
end

switch char(row.expSkill)
    case {'pick','move_to'}
        eObj = num(row.expObject);
        if ~isnan(eObj)
            ok = ~isnan(call.object) && call.object == eObj;
            detail = sprintf('expObject %d, got %s', eObj, idstr(call.object));
        elseif strcmpi(char(row.category), 'coordinate')
            ok = strcmp(sk, 'move_to') && ~isempty(call.point);
            detail = 'coordinate move requires a point';
        elseif strcmpi(char(row.category), 'region_move')
            ok = strcmp(sk, 'move_to') && ~isempty(char(call.region));
            detail = 'region move requires a region';
        else
            ok = true; detail = 'skill match';
        end
    case 'place'
        eRef = num(row.expRef);
        okRef = isnan(eRef) || (~isnan(call.ref_object) && call.ref_object == eRef);
        eDir  = lower(strtrim(char(row.expDirection)));
        gDir  = lower(strtrim(char(call.direction)));
        % STACK direction synonyms (v1.1): on/onto/above/over/top/stack all denote the SAME vertical-
        % placement action, so any is accepted when the LABEL is a stacking word. Lateral directions
        % (left/right/forward/back) keep an exact match: "10 cm to the right" must not accept "left".
        stackSyn = {'on','onto','above','over','top','stack'};
        if ismember(eDir, stackSyn)
            okDir = ismember(gDir, stackSyn);
        else
            okDir = isempty(eDir) || strcmp(gDir, eDir);
        end
        ok = strcmp(sk, 'place') && okRef && okDir;
        detail = sprintf('exp ref %s dir %s; got ref %s dir %s', idstr(eRef), eDir, idstr(call.ref_object), char(call.direction));
    case {'grip','release'}
        ok = strcmp(sk, char(row.expSkill));
        detail = sprintf('expected %s, got %s', char(row.expSkill), sk);
    otherwise
        ok = ismember(sk, acc); detail = 'skill-in-acceptable';
end
end

% ========================================================================
function a = acceptableSet(row)
% The acceptable skills for this row: the acceptableSkills field (pipe-separated), else expSkill.
% ask/refuse expectations always admit the matching dialogue act.
raw = '';
if isfield(row, 'acceptableSkills'), raw = char(string(row.acceptableSkills)); end
if isempty(strtrim(raw)), raw = char(string(row.expSkill)); end
a = strsplit(strtrim(raw), '|');
a = a(~cellfun(@isempty, a));
if num(row.expAsk)    == 1 && ~ismember('ask', a),    a{end+1} = 'ask';    end
if num(row.expRefuse) == 1 && ~ismember('refuse', a), a{end+1} = 'refuse'; end
end

% ========================================================================
function v = num(x)
% Coerce a possibly-string / possibly-empty field to a numeric scalar (NaN if absent/non-numeric).
if isnumeric(x), if isempty(x), v = NaN; else, v = double(x(1)); end; return; end
s = strtrim(char(string(x)));
if isempty(s), v = NaN; else, v = str2double(s); end
end

% ========================================================================
function s = idstr(v)
if isempty(v) || (isnumeric(v) && isnan(v)), s = '-'; else, s = num2str(v); end
end
