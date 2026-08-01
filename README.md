# Evidence package: every number in the paper, and the file it comes from

This folder is **self-contained and analyzer-ready**. It holds the retained artifacts of the four
reported hardware sessions plus the command suites, so a reviewer can regenerate the paper's
hardware numbers without a robot, a camera, or the rest of `results/`.

Nothing here is a summary. Every file is the raw artifact written *during* the session, before any
analysis.

## Verify in three commands

Clone this repository, `cd` into it, and in MATLAB:

```matlab
addpath('analysis')
analyze_hw_bench(fullfile(pwd,'hw_bench_trials.csv'), '20260729_182407_3746')
handeye_crossval(fullfile(pwd,'handeye_20260729_182407_3746.mat'))
```

The first regenerates a full session report (safety, grounding by category, completion, tracking)
and prints a PASS/FAIL safety verdict. The second reproduces the calibration accuracy figures,
6.28 mm in-sample, 6.86 mm leave-one-out and 6.73 mm 5-fold over 20 correspondences.

No robot, camera, or toolbox licence beyond base MATLAB is needed. Both functions derive their
working directory from the path you hand them, which is what lets this flat folder verify on its
own. `analyze_hw_bench` filters `hw_bench_trials.csv` by `run_id`, so the shared CSV is the right
file to pass for any of the four sessions; substitute another run id from the table below.

`analysis/` holds the five offline scorers, copied verbatim from the framework:
`analyze_hw_bench`, `scoreCaseV2` (`scorer_v1.1`), `taxonomy_v1`, `scoreGateAudit` and
`handeye_crossval`. Call them with an explicit path as shown. Called with no argument they fall
back to `projectConfig`, which is lab-specific and is not published here, so the argument is not
optional in a clone.

## The four sessions

All four ran on the physical UR5e on 2026-07-29 with exact-path execution
(`blend_max_m = 0`, `exact_path_execution = true`). They differ in the **wording** of the command
suite, which is the paper's central variable.

| Label | Run id | Suite | Scene | Notes |
|---|---|---|---|---|
| **A** | `20260729_132426_3746` | `benchmark_cmds_v1.csv` | 1 | 16 commands × 5 verbatim repeats (the conventional design) |
| **B** | `20260729_152310_3746` | `benchmark_cmds_v2.csv` | 2 | 80 distinct paraphrases; first session with the controller-safety channel |
| **C** | `20260729_165629_3746` | `benchmark_cmds_v2.csv` | 3 | paraphrased; collinear-run collapse enabled |
| **D** | `20260729_182407_3746` | `benchmark_cmds_v2.csv` | 4 | paraphrased; collapse enabled; first run logging per-leg collapse deviation |

Scene numbering: A used the original layout, and B, C and D used **three different** tabletop
arrangements. The paper pools B, C and D and contrasts them with A.

## Files, and what each one is

| File | What it records | Written by |
|---|---|---|
| `hw_bench_trials.csv` | one row per command: the utterance, the label, what the model grounded, whether it executed, the operator's completion flag, tracking RMS, timing. **Contains all runs**; filter by `run_id` | `logHwTrial` |
| `gate_audit_<run>.csv` | one row per gate decision: pass/fail, waypoint count, and the minimum self / safe-box / floor clearances the gate measured. `leg` is `sim` (dry-run) or `hw` | `writeGateCert`, fail-stops before motion |
| `execution_audit_<run>.csv` | one row per controller send (`attempt`) and per confirmed arrival (`reached`), written **before** the socket write. Independent denominator for certificate coverage. From D onward also carries `nCertified` and `maxCollapseDevDeg` | `executePath` |
| `safety_status_<run>.csv` | the UR controller's **own** safety state sampled after every trial over the Dashboard channel. Independent of the host gate. Absent for A (added after) | `demo13_bench` |
| `hw_bench_manifest_<run>.json` | provenance: model digest, suite hash, calibration digest, code hash, execution-fidelity settings, safe box, seeds | `writeHwManifest`, fail-stops before motion |
| `handeye_<run>.mat` | the exact camera-to-robot transform used, **with** its correspondences (`camPts`, `robPts`), so the fit can be re-derived and cross-validated | `real_handeye`, snapshotted per run |
| `tracks/<run>_t####.mat` | per-leg commanded and achieved joint trajectories, arc-length aligned | `hwRecorder` |
| `suites/benchmark_cmds_v*.csv` | the versioned command suites with their ground-truth labels | authored |
| `safebox.mat` | `BOXub`, the task box the gate actually enforced, together with the twelve taught corner poses (`Q`) and their measured positions (`P`) it was fitted from. `P` and `Q` also serve as a forward-kinematics oracle | `real_mapbox` |
| `tablez.mat` | the twelve taught table-surface points. The runs used `max(P(:,3))` = `-0.010461` m as the table top | `real_tablez` |
| `gate_ablation.csv` | the gate-resolution study: per-bucket counts of segments with clear endpoints but an unsafe sampled interior | `exp_gate_ablation.m` |
| `sim/gate_audit_<run>.csv` | the four simulation sessions' dry-run certificates, 74 each and 296 in total, with no `hw` legs | `writeGateCert` |
| `figdata/unintended_*` | the Session B trial 74 example: the 26 commanded waypoints, the 271 achieved samples, the per-sample margin series, and the margins to the nominal and to the tolerance-expanded box | `export_unintended_motion.m` |

Two definitions differ between scripts and are worth stating before they look like a contradiction.
`tablez.mat` holds twelve measured points, and a summary statistic must be chosen over them. The
benchmark that produced the reported sessions takes the **maximum** (`demo13_bench.m:91`), giving
`-0.010461` m, and that is the value the paper quotes. The separate diagnostics exporter
`export_trial_geometry.m:61` takes the **median** for a context field, giving `-0.014522`; that
value appears only in diagnostics output and governed nothing. Likewise, `figdata` reports the
trial-74 clearance twice: `minAchNominalMM` is the margin to the box itself and `minAchEnforcedMM`
the margin to the box widened by the tolerances, which is why the same trajectory is described as
47 mm and as 162 mm from a boundary.

These files are as written by the run, with one exception: the robot's IP address was replaced by a
placeholder before publication, which invalidates one stored hash. See "One field was redacted, and
it breaks one hash" below before checking provenance.

## Claim-to-file map

Every hardware number in the paper, with the artifact that produces it. "A" and "B+C+D" match the
two columns of Table I.

### Safety

| Paper claim | A | B+C+D | Where it comes from |
|---|---|---|---|
| Gate certificates passed | 70/70 | 241/241 | `gate_audit_*.csv`, rows with `leg=hw`, count `ok=1` |
| Certificates vs. controller sends | 70/70 | 241/241 | `gate_audit` hw rows vs `execution_audit` `attempt` rows |
| Controller safety samples normal | n/a | 246/246 | `safety_status_*.csv`, column `normal` |
| Unintended motions (must-not-move rows) | 0/40 | 14/120 | `hw_bench_trials.csv`: adversarial `category` with `executed=1` |
| Minimum clearances | 26.7 / 122.0 / 17.1 mm | worst box 90.7 mm | `gate_audit_*.csv`: `minFloorDist`, `minBoxMargin`, `minSelfClear` |
| Exact-path execution | true | true | `hw_bench_manifest_*.json`: `blend_max_m`, `exact_path_execution` |
| Collapse departure from the certified polyline | n/a | worst 0.249° | `execution_audit_20260729_182407_3746.csv`: `maxCollapseDevDeg` |

### Grounding

| Paper claim | A | B+C+D | Where |
|---|---|---|---|
| Overall | 72/80 | 163/240 | `analyze_hw_bench`, re-scored offline by `scoreCaseV2` (`scorer_v1.1`) |
| Injection refused | 15/15 | 27/45 | trials: `category=injection`, `grounded_skill=refuse` |
| All 11 categories (Table I) | see report | see report | `analyze_hw_bench` per-category block |

The **live** `grounding_correct` column in the trials CSV is a lighter flag (skill + object + ref
only) retained for transparency; the paper's numbers come from the offline `scoreCaseV2` re-score,
which additionally enforces direction and accepts ask-or-refuse where the label allows. Both are
printed side by side by the analyzer.

### Execution and calibration

| Paper claim | A | B+C+D | Where |
|---|---|---|---|
| Physical completion | 27/32 | 71/77 | trials: `physical_success_flag` (operator label) |
| Semantic + physical | 24/32 | 58/77 | `analyze_hw_bench` intersection |
| Cartesian track RMS | 5.51 mm (n=27) | 4.87–5.83 mm (n=88) | trials: `cart_track_rms_mm`; raw trajectories in `tracks/` |
| Hand-eye, in-sample | 6.28 mm over 20 | same fit | `handeye_crossval` |
| Hand-eye, held-out | 6.86 mm LOO, 6.73 mm 5-fold | same fit | `handeye_crossval` |

### Simulation claims

These come from simulation studies with no hardware artifacts. Regenerate with the named script;
`figures/` holds the plots those scripts produced.

| Claim | Script | Figure |
|---|---|---|
| Endpoints-only gate blind spot rising to 96.7% | `experiments/exp_gate_ablation.m` | stated in prose; the paper's bar chart was cut for length |
| Learned sampler, 28/120 → 98/120 at a 60-iteration budget | `experiments/exp02_learned_sampler.m` | `figures/fig_learned_sampler.png`, `figures/fig_sampler_success.png` |
| Sampler gain is scene-dependent | `experiments/exp03_sampler_study.m` | `figures/fig_sampler_sweep.png` |
| Planner mean times; Bi-RRT:RRT* ratio 27.7 [23.9, 31.2] | `experiments/exp01_planner_benchmark.m`, `exp01_report.m` | `figures/fig_planning_time.png`, `figures/fig_planner_repro.png` |
| Smoothed path lengths differ, so no path-quality equivalence is claimed | `exp01_report.m` | `figures/fig_path_length.png` |

`figures/fig_clearance.png` is also included: it is standard output of the planner benchmark, but
the paper makes no clearance claim, so it is context rather than evidence.

### Figures deliberately NOT curated here

`results/` also contains `fig_bo_convergence.png`, `fig_bo_samples.png`, `fig_servoj_*.png`,
`fig_track_*.png` and `fig_tracking_repeatability.png`. They are retained as raw output, but they
are **not** evidence for this paper, because the claims they illustrate were **withdrawn** as
unsupported: the Bayesian-optimisation control-tuning result was removed because its objective
trace, candidates and seeds were never committed, and the kinematic-metrology and
dynamic-hardware claims were removed for the same reason. The paper makes no
Bayesian-optimisation, servo-tuning, or kinematic-error claim, and these plots should not be
presented as though it did. `docs/SUBMISSION_RECOVERY.md` lists what new evidence each would need
before it could be claimed again.

## What this evidence does and does not establish

Stated here so it is not inferred from the numbers alone.

- Certificates are produced by the **same host software** that planned the motion, so they cannot
  corroborate themselves. That is why `execution_audit` is written separately, before each socket
  write, giving an independent denominator, and why the controller's own safety state is sampled in
  B, C and D.
- **No sensor provides collision ground truth.** "No safety event" means no gate failure, no
  controller safety-state change, and no operator-observed event. It does **not** mean nothing was
  touched: a motion that grazes an object without tripping a protective stop would not appear here.
- The gate checks **sampled** configurations, not continuous time. It is not a contact-safety,
  Performance Level, or SIL argument.
- Rows are **clustered** by intent and by session. Even in the paraphrased sessions, where no
  utterance repeats, five rows share each intent, so a row-level confidence interval understates
  uncertainty. The analyzer detects the suite shape from the data and prints the appropriate caveat.
- The 14 unintended motions in B+C+D were each in-box, collision-checked, and left the controller
  normal. That is not the same as being *physically* safe.

## Regenerating a report file

`analyze_hw_bench` also writes a markdown report next to the CSV you point it at:

```matlab
analyze_hw_bench(fullfile(pwd,'hw_bench_trials.csv'), '20260729_165629_3746')
% -> hw_bench_report.md, written next to the CSV
```

Re-running it months later on the same inputs reproduces the same file: the scorers
(`scoreCaseV2` = `scorer_v1.1`, `taxonomy_v1`, `scoreGateAudit`) are versioned and frozen, the
confidence intervals are seeded (`rng(1)`, 2000 bootstrap resamples), and no step consults a model.

## One field was redacted, and it breaks one hash

The robot's address is the only edit made to these files for publication.

`robot_ip` held the lab UR5e's real address, which is on university routable space. A UR5e listens
for URScript on port 30002 with no authentication, so publishing a live address for it is a physical
safety exposure, not just a privacy one. Every occurrence was replaced with `192.168.0.100`, a
private-range placeholder. This affects `hw_bench_trials.csv` and the four
`hw_bench_manifest_*.json` files, and nothing else: no measurement, label, timestamp, joint value or
clearance was altered.

The consequence has to be stated plainly, because it touches the provenance chain the paper leans
on. Each manifest carries `manifest_hash`, a SHA-256 over its own body, and `logHwTrial` copies that
hash into every trial row. Those hashes were computed **before** the substitution, so they certify
the original content and **will not recompute** over the published files. They are left exactly as
written rather than recomputed, because recomputing them would produce a hash that looks valid while
certifying a file the robot never actually ran under. `code_hash`, the suite hash and the
calibration digest cover inputs that were not touched, so those still verify normally.

A reviewer who needs the byte-exact originals can request them from the authors.

## Figures

`figures/` holds the planner and sampler studies described under "Figures deliberately NOT curated
here", plus:

| File | What it shows |
|---|---|
| `fig1_framework.png` | Fig. 1 of the paper: the authority boundary, and the two routes (language and rule-based fallback) re-entering the same gate chain |
| `real_cell/noQ.png` | the three utterances issued with the language model stopped; only the one matching the fallback parser's pattern is admitted |
| `real_cell/Q1.png`, `Q2.png`, `Q3.png` | the same three utterances with the model running; all three ground and execute |
| `real_cell/Pick_Object9.png`, `PlaceObject9.png` | the digital twin during the pick and the place, recorded live alongside the physical arm |
| `real_cell/MATLAB-Startup_demo13-interactive.png` | session start-up, showing the resolved configuration and the connection handshake |
| `real_cell/dt_real.jpg`, `dt_scene.png`, `Matlab_Sim_Scene.png` | the physical cell and the corresponding twin scene |

Two screen recordings of the physical cell (371 MB and 290 MB) cover longer command sequences than
the stills. Both exceed GitHub's 100 MB per-file limit, so they are deposited on Zenodo and cited
from the paper's Data and Code Availability section rather than committed here.
