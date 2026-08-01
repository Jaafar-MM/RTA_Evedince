function R = scoreGateAudit(gateCsv, varargin)
%SCOREGATEAUDIT Versioned safety-gate scorer over a gate-audit CSV (no robot).
%   R = SCOREGATEAUDIT(gateCsv) reads a results/gate_audit_<runId>.csv written by writeGateCert
%   and checks the Phase-0 properties represented by the recorded certificates:
%     - every RECORDED hardware certificate ("hw") passes
%     - the per-leg world was actually collision-checked (envChecked==1)
%     - the tip stayed inside the safe box with a hard floor (minFloorDist>=0, minBoxMargin>=0)
%     - safe ordering: each hw leg is preceded by a sim (dry-run) leg              -> n_sim >= n_hw
%   Prints a PASS/FAIL verdict and returns a struct of counts. Optional name/value:
%     'nExecutedLegs', k  -> cross-check a separately logged execution-attempt count.
%
%   Without nExecutedLegs, certificate coverage is UNKNOWN and PASS is false. A certificate
%   file cannot prove that a missing certificate or bypassed controller command did not occur.

p = inputParser;
addParameter(p, 'nExecutedLegs', NaN);
parse(p, varargin{:});
nExec = p.Results.nExecutedLegs;

if ~isfile(gateCsv), error('scoreGateAudit:noFile', 'gate-audit CSV not found: %s', gateCsv); end
T = readtable(gateCsv, 'TextType','string');

isHw  = T.leg == "hw";
isSim = T.leg == "sim";
hw = T(isHw, :);

R = struct();
R.file              = gateCsv;
R.n_sim_certs       = sum(isSim);
R.n_hw_certs        = sum(isHw);
R.n_hw_passing      = sum(isHw & T.ok == 1);
R.n_hw_failing      = sum(isHw & T.ok == 0);
R.failing_hw_certificate_count = R.n_hw_failing;
R.all_hw_env_checked = isempty(hw) || all(hw.envChecked == 1);
R.min_floor_dist     = colMin(hw, 'minFloorDist');
R.min_box_margin     = colMin(hw, 'minBoxMargin');
R.min_self_clear     = colMin(hw, 'minSelfClear');
R.safe_ordering_ok   = all(cumsum(isHw) <= cumsum(isSim));
R.coverage_known     = ~isnan(nExec);
R.coverage_ok        = R.coverage_known && (nExec == R.n_hw_passing);
if R.coverage_known && nExec > 0
    R.gate_certificate_coverage = R.n_hw_passing / nExec;
elseif R.coverage_known
    R.gate_certificate_coverage = double(R.n_hw_passing == 0);
else
    R.gate_certificate_coverage = NaN;
end

pass = R.failing_hw_certificate_count == 0 && R.all_hw_env_checked && ...
       (isnan(R.min_floor_dist) || R.min_floor_dist >= 0) && ...
       (isnan(R.min_box_margin) || R.min_box_margin >= 0) && ...
       (isnan(R.min_self_clear) || R.min_self_clear >= 0) && ...
       R.safe_ordering_ok && R.coverage_ok;
R.PASS = pass;

fprintf('\n=== scoreGateAudit (scorer: scoreGateAudit / v1) ===\n');
fprintf('  file                    : %s\n', gateCsv);
fprintf('  sim / hw certificates   : %d / %d  (hw passing %d, failing %d)\n', R.n_sim_certs, R.n_hw_certs, R.n_hw_passing, R.n_hw_failing);
fprintf('  failing hw certificates : %d   (MUST be 0)\n', R.failing_hw_certificate_count);
fprintf('  all hw env-checked      : %d\n', R.all_hw_env_checked);
fprintf('  min floor / box / self  : %.4f / %.4f / %.4f m  (>=0)\n', R.min_floor_dist, R.min_box_margin, R.min_self_clear);
fprintf('  safe ordering (sim>=hw) : %d\n', R.safe_ordering_ok);
if R.coverage_known
    fprintf('  cert coverage           : %.3f  (%d separately logged execution attempts vs %d hw certs)\n', R.gate_certificate_coverage, nExec, R.n_hw_passing);
else
    fprintf('  cert coverage           : UNKNOWN (independent executed-leg count not supplied)\n');
end
fprintf('  VERDICT                 : %s\n', ternary(pass, "PASS", "FAIL"));
if pass, fprintf('  >>> PASS\n'); else, fprintf(2, '  >>> FAIL -- investigate before trusting the session.\n'); end
end

% ========================================================================
function v = colMin(T, name)
v = NaN;
if any(strcmp(T.Properties.VariableNames, name)) && height(T) > 0
    c = T.(name); c = c(isfinite(c)); if ~isempty(c), v = min(c); end
end
end

% ========================================================================
function out = ternary(cond, a, b)
if cond, out = a; else, out = b; end
end
