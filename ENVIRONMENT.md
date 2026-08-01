# Environment of record

The exact software and hardware that produced the four reported sessions of **2026-07-29**. Every
value here is either recorded in the per-run manifests (`hw_bench_manifest_<runId>.json`) or was
captured from the machine that ran them. Reproducing the *numbers* needs the MATLAB side only;
reproducing the *sessions* needs the hardware.

## Host

| Component | Version of record | Notes |
|---|---|---|
| OS | Windows 11 Pro 10.0.26200 | |
| MATLAB | **26.2.0.3320248 (R2026b) Prerelease Update 2** | recorded per run as `matlab_version` |
| Python | **3.11.9** | path in `cfg.python.exe`; 3.11 is required (see `requirements.txt`) |
| Ollama | **0.32.5** | serves the local model over `http://localhost:11434` |

MATLAB toolboxes present at 26.2. The first two are **required**; the rest are used by
peripheral scripts.

| Toolbox | Required for |
|---|---|
| Robotics System Toolbox | `rigidBodyTree`, `manipulatorRRT`, `inverseKinematics`, collision checking |
| Robotics System Toolbox Support Package for UR Series | `urRTDEClient` (robot state). Hardware and URSim only |
| Statistics and Machine Learning Toolbox | `fitgmdist` (learned sampler), `bayesopt` (control tuning) |
| Computer Vision Toolbox | peripheral visualisation |
| Image Processing Toolbox | peripheral visualisation |
| Optimization Toolbox | peripheral |
| Parallel Computing Toolbox | optional; not required by any reported result |

MATLAB was a **Prerelease** build. Nothing in the framework depends on prerelease features, but
this is the build of record, so a stable release may differ in RNG or timing details. Fixed seeds
reproduce the requested *samples* within a version; they do not make timing bit-reproducible.

## Models

| Role | Model | Digest (as manifested) |
|---|---|---|
| Grounding (reported runs) | `qwen2.5:7b` | `845dbda0ea48…` |
| Cross-model critic (ablation only) | `qwen3:8b` | `500a1f067a9f…` |
| Vision-language (optional path) | `qwen3-vl:8b` | `901cae732162…` |

The grounding digest in every reported manifest is `845dbda0ea48…`, so the model can be verified
rather than assumed. Pull with `ollama pull qwen2.5:7b`.

## Hardware (needed only to re-run sessions, not to re-derive numbers)

| Component | Detail |
|---|---|
| Robot | Universal Robots UR5e, pendant in **Remote** mode |
| Controller channels | URScript `:30002`, RTDE `:30004`, Dashboard `:29999` |
| Simulator | URSim e-Series VM, reachable from the host |
| Camera | Intel RealSense D435i, fixed on-table mount |
| Gripper | OnRobot RG2 driven by URScript over the **UR controller's Tool I/O**. This cell has **no Compute Box**; the Modbus path in the repo is an untested fallback for cells that have one |

## Known environment gaps

Stated so a reviewer does not have to discover them.

- **No controller software version is recorded for the reported runs.** The manifest's `firmware`
  field contains the Dashboard server's error reply (`"could not understand"`) because the query
  used `PolyScope Version` instead of `PolyscopeVersion`. The query is fixed for future runs, but
  the four reported sessions carry no valid version. The paper therefore claims *interface*
  equivalence between URSim and hardware, not version-level identity.
- **One calibration across all four sessions.** The camera and table were undisturbed, so every
  run shares one hand-eye fit (identical digest in all four manifests). Each run preserves and
  hashes its own copy, but this is not a fresh per-session calibration.
- **`pyrealsense2` reports no `__version__`**; the pin comes from `pip`.
- The framework is not containerised and the OS is not pinned.
