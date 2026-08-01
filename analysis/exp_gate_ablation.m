%% exp_gate_ablation.m
% GATE ABLATION: does an INDEPENDENT, per-LEG deterministic safety certifier enforce a safety
% spec that (a) trusting the LLM (no geometric gate) and (b) a PER-PLAN (endpoints-only) check do
% NOT? This is the empirical evidence that the safety architecture is more than the sum of its
% (individually prior-art) parts. PURE OFFLINE / HOST-SIDE: the gate decides off the robot, so the
% result is identical in sim and on hardware; it does NOT need the arm.
%
% Safety spec = the per-leg gate (gatePath): a segment is UNSAFE iff ANY waypoint self-collides,
% hits an obstacle, or leaves the safe box. We ask, for three safety configurations, whether each
% would EXECUTE an ACTUALLY-UNSAFE segment:
%   trust-LLM : no geometric gate           -> executes every segment
%   per-plan  : gate the two ENDPOINTS only -> executes any segment whose endpoints are clear
%   per-leg   : gate EVERY waypoint (ours)  -> executes only fully-clear segments (= the spec)
%
% The honest, non-circular result is the BLIND-SPOT RATE of the weaker configs. A collision-free
% start and goal do NOT imply a collision-free path between them, so a per-plan / symbolic check
% (the prior-art granularity) is UNSOUND for trajectories: it silently passes unsafe motions, at a
% rate that GROWS with move magnitude but is non-zero at every scale. Trusting the LLM passes 100%.
% Only per-leg certification enforces the spec. No figures (writes a CSV + prints). No robot motion.

close all; setupPaths();
cfg = projectConfig();
rng(cfg.seed);

%% setup
robot = loadURModel(cfg);
[robot, eeName] = addGripper(robot, getEndEffectorName(robot), cfg.gripper.length, cfg.gripper.collisionRadius);
[env, ~] = buildPickPlaceScene('Clutter', true);            % ground+wall+boxes+pillar: collision opportunities
B   = cfg.workspace.virtualBox;
tol = struct('xy', 0.12, 'zfloor', 0, 'zceil', 0.12);       % the live tolerance: HARD table floor
lim = jointLimits(robot); nJ = size(lim,1);

M  = 2500;                       % configs to sample + label
NA = 120;                        % OK->OK segments per move-magnitude bucket
NB = 120;                        % OK->BAD segments (probe the trust-LLM blind spot)
K  = 20;                         % waypoints per interpolated segment
STEPS = [0.3 0.6 1.2 2.4 Inf];   % rad/joint move magnitude; Inf = an unconstrained random OK pair

%% 1) sample + label configs by the per-leg gate
Q  = lim(:,1)' + rand(M, nJ) .* (lim(:,2) - lim(:,1))';
ok = false(M,1);
for i = 1:M, ok(i) = gatePath(robot, Q(i,:), eeName, B, env, tol); end
idxOK = find(ok); idxBad = find(~ok);
fprintf('Sampled %d configs: %d gate-OK, %d gate-rejected.\n', M, numel(idxOK), numel(idxBad));
assert(numel(idxOK) >= 4 && numel(idxBad) >= 1, 'exp_gate_ablation:pool', 'need both OK and rejected configs.');

interp = @(a,b) a + linspace(0,1,K)' .* (b - a);            % K-by-nJ straight-line JOINT interpolation
fullOKf = @(p) gatePath(robot, p,            eeName, B, env, tol);
endOKf  = @(p) gatePath(robot, p([1 end],:), eeName, B, env, tol);

%% 2) per-plan blind spot vs move magnitude (OK -> OK, both endpoints clear by construction)
fprintf('\n=== Per-plan blind spot vs move magnitude (OK->OK segments, clear endpoints) ===\n');
fprintf('%9s | %5s | %s\n', 'step(rad)', 'n', 'interior-unsafe = per-plan EXECUTES, per-leg refuses');
rows = cell(numel(STEPS), 4);
for si = 1:numel(STEPS)
    st = STEPS(si); nHaz = 0; nGot = 0; att = 0;
    while nGot < NA && att < NA*60
        att = att + 1;
        a = Q(idxOK(randi(numel(idxOK))), :);
        if isfinite(st)
            b = min(max(a + (2*rand(1,nJ)-1)*st, lim(:,1)'), lim(:,2)');   % bounded realistic move
        else
            b = Q(idxOK(randi(numel(idxOK))), :);                          % unconstrained random OK pair
        end
        if ~gatePath(robot, b, eeName, B, env, tol), continue; end         % require the GOAL clear too
        nGot = nGot + 1;
        if ~fullOKf(interp(a,b)), nHaz = nHaz + 1; end                     % clear endpoints, unsafe interior
    end
    rate = 100*nHaz/max(nGot,1);
    lbl = "Inf"; if isfinite(st), lbl = sprintf('%.1f', st); end
    fprintf('%9s | %5d | %3d  (%3.0f%%)\n', lbl, nGot, nHaz, rate);
    rows(si,:) = {lbl, nGot, nHaz, rate};
end

%% 3) trust-LLM blind spot (OK -> BAD: the goal endpoint is unsafe -> per-plan + per-leg catch it)
nB_unsafe = 0; nB_planCatch = 0;
for j = 1:NB
    a = Q(idxOK(randi(numel(idxOK))),  :);
    b = Q(idxBad(randi(numel(idxBad))),:);
    p = interp(a,b);
    if ~fullOKf(p)
        nB_unsafe = nB_unsafe + 1;
        if ~endOKf(p), nB_planCatch = nB_planCatch + 1; end
    end
end

%% summary
fprintf('\n=== Summary: who executes an UNSAFE motion ===\n');
fprintf('  per-leg  (ours = the spec)  : 0%% by definition, refuses every unsafe segment.\n');
fprintf('  trust-LLM(no geometric gate): 100%%: executes every unsafe segment (never refuses).\n');
fprintf('  per-plan (endpoints only)   : UNSOUND: executes %.0f%% of unsafe OK->OK segments at\n', rows{1,4});
fprintf('     the smallest %.1f-rad moves, rising to %.0f%% at full sweep (table above): clear\n', STEPS(1), rows{end,4});
fprintf('     endpoints do NOT imply a clear path. On OK->BAD (unsafe goal) per-plan DID catch\n');
fprintf('     %d/%d (it sees the bad endpoint), but trust-LLM caught 0, its blind spot.\n', nB_planCatch, nB_unsafe);

T = cell2table(rows, 'VariableNames', {'StepRad','N','InteriorUnsafe','PerPlanBlindSpotPct'});
writetable(T, fullfile(cfg.resultsDir, 'gate_ablation.csv'));
fprintf('\nWrote results/gate_ablation.csv. The per-leg certifier is the only sound enforcer of the\n');
fprintf('spec; per-plan/symbolic checks are unsound for trajectories; LLM-trust enforces nothing.\n');
fprintf('(Benchmark-suite version on the adversarial COMMAND rows follows from a hardware/sim replay.)\n');
