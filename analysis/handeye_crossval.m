function R = handeye_crossval(heFile)
%HANDEYE_CROSSVAL Held-out accuracy of the hand-eye transform (no robot, no camera).
%   R = HANDEYE_CROSSVAL()        uses results/<cfg.workspace.handeyeFile>.
%   R = HANDEYE_CROSSVAL(heFile)  uses a specific saved calibration (e.g. a run-named snapshot).
%
%   WHY: the residual reported by real_handeye is IN-SAMPLE, i.e. how consistently the rigid
%   transform fits the correspondences it was computed from. That is not predictive accuracy.
%   This re-fits the SAME estimator (Kabsch/SVD, identical to real_handeye's rigidFit) while
%   holding correspondences out, so fit consistency and held-out error can be reported
%   separately, as the paper does.
%
%   Reports: in-sample RMS/max, leave-one-out RMS/max/median, 5-fold RMS/max, and the principal
%   spread of the camera-side point cloud (a cloud that is thin along one axis leaves that axis
%   weakly constrained; ours is thin in depth).
%
%   Reproduces the paper's hand-eye numbers: 6.28 mm in-sample, 6.86 mm leave-one-out,
%   6.73 mm 5-fold, over 20 correspondences.

if nargin < 1 || isempty(heFile)
    cfg = projectConfig();
    heFile = fullfile(cfg.resultsDir, cfg.workspace.handeyeFile);
end
assert(isfile(heFile), 'handeye_crossval:noFile', 'calibration not found: %s', heFile);
S = load(heFile);
assert(isfield(S,'camPts') && isfield(S,'robPts'), 'handeye_crossval:noPts', ...
    '%s has no camPts/robPts; it predates correspondence retention.', heFile);

P = S.camPts; Q = S.robPts; n = size(P,1);
R = struct('file', heFile, 'n', n);
fprintf('hand-eye cross-validation: %s\n  correspondences: %d\n', heFile, n);

[Rr, t, R.inSampleRMS] = rigidFit(P, Q);
R.inSampleMax = max(vecnorm((Rr*P')' + t - Q, 2, 2));
fprintf('  IN-SAMPLE (all %d)        : RMS %.2f mm   max %.2f mm\n', n, 1000*R.inSampleRMS, 1000*R.inSampleMax);

e = zeros(n,1);                                    % leave-one-out
for i = 1:n
    m = true(n,1); m(i) = false;
    [Ri, ti] = rigidFit(P(m,:), Q(m,:));
    e(i) = norm((Ri*P(i,:)')' + ti - Q(i,:));
end
R.looRMS = sqrt(mean(e.^2)); R.looMax = max(e); R.looMedian = median(e);
fprintf('  HELD-OUT leave-one-out   : RMS %.2f mm   max %.2f mm   median %.2f mm\n', ...
    1000*R.looRMS, 1000*R.looMax, 1000*R.looMedian);

rng(1); perm = randperm(n); K = 5; ef = [];    % 5-fold: the fit sees only n-ceil(n/K) points
for k = 1:K
    te = perm(k:K:n); tr = setdiff(1:n, te);
    [Rk, tk] = rigidFit(P(tr,:), Q(tr,:));
    ef = [ef; vecnorm((Rk*P(te,:)')' + tk - Q(te,:), 2, 2)]; %#ok<AGROW>
end
R.foldRMS = sqrt(mean(ef.^2)); R.foldMax = max(ef);
fprintf('  HELD-OUT 5-fold          : RMS %.2f mm   max %.2f mm\n', 1000*R.foldRMS, 1000*R.foldMax);

R.cloudSpread = svd(P - mean(P,1))/sqrt(n);
fprintf('  camera-cloud spread      : %.0f / %.0f / %.0f mm (thin last axis = weakly constrained)\n', ...
    1000*R.cloudSpread(1), 1000*R.cloudSpread(2), 1000*R.cloudSpread(3));
end

% ========================================================================
function [R, t, rmse] = rigidFit(P, Q)
% Kabsch/SVD rigid fit, Q ~= R*P + t. Identical to real_handeye's rigidFit so the in-sample
% number printed here matches the number that calibration reported.
cP = mean(P,1); cQ = mean(Q,1);
H = (P-cP)'*(Q-cQ);
[U,~,V] = svd(H);
D = eye(3); D(3,3) = sign(det(V*U'));
R = V*D*U'; t = (cQ' - R*cP')';
err = (R*P')' + t - Q;
rmse = sqrt(mean(sum(err.^2,2)));
end
