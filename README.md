# predicate-audit

Code for the paper project **"How wrong are built-in success predicates? A
human-verified error model for simulated manipulation benchmarks."**

Simulated manipulation benchmarks (LIBERO, RoboCasa, RoboTwin, SimplerEnv)
decide success with hand-written predicates such as `In(object, container)`.
Many are evaluated at the first step they become true. This project measures
how often those verdicts disagree with human judgment (false successes and
false failures), per predicate type, task and policy, and compares that error
with sampling confidence intervals and published SOTA gaps.

**Status: scaffold.** The grading and statistics code is tested and the
baseline runs end to end on a toy simulator. No real benchmark has been run
yet, and the LIBERO backend is an untested draft.

## Setup

```bash
conda env create -f environment.yml && conda activate predaudit
# or, with plain pip (Python >= 3.9):
pip install -e ".[dev]"
pytest
```

The base install needs only NumPy.

## Baseline experiment

```bash
python scripts/run_baseline.py
```

This rolls out three scripted policies (strong, mid, weak) on a toy
"put the object in the bin" task where the object can slide through the
container. It keeps every rollout running past the first success, then
compares the built-in first-hit verdict with persistence re-grading
(`In` must hold for N consecutive steps, N in {10, 30, 100}) against the
simulator's final resting state. Outputs go to `results/baseline_toy/`
(see [results/README.md](results/README.md)).

The toy numbers only show that the pipeline works. The reference label there
is a simulator oracle, not a human, and nothing about the toy transfers to a
real benchmark.

## Layout

| Path | Purpose |
|---|---|
| `predaudit/grading.py` | Graders over a per-step predicate trace: first-hit, end-of-episode, persistence window with optional extra conditions (at rest, gripper released) |
| `predaudit/stats.py` | Confusion counts, false-success / false-failure rates, Wilson intervals |
| `predaudit/backends/toy.py` | Dependency-free toy simulator used by the baseline |
| `predaudit/backends/libero.py` | Extended-rollout LIBERO backend, both post-success protocols (policy continues, scripted release). **Untested** |
| `scripts/run_baseline.py` | Baseline experiment |
| `results/` | Run outputs (git-ignored) |
| `tests/` | Unit tests |

## Running on LIBERO

Not wired into the baseline script yet. To start on it:

```bash
git clone https://github.com/Lifelong-Robot-Learning/LIBERO && pip install -e LIBERO
```

then drive `predaudit.backends.libero.LiberoBackend` with a policy callable
(`obs -> 7-D action`). It needs a GPU or EGL/OSMesa for offscreen rendering
and released policy checkpoints (OpenVLA-OFT, pi0 via openpi).

## Roadmap

1. Static taxonomy of checker code per task (first-hit vs end-of-episode, release, persistence, predicate type).
2. **Kill-test:** persistence re-grading on 15-20 flagged LIBERO tasks with one strong and one weak policy. Below 1% false success everywhere means shrinking to a workshop note.
3. Extended-rollout harness with state and video logging; add RoboCasa.
4. About 2,000 human labels, two annotators, written rubric, Cohen's kappa.
5. Per-predicate-type confusion matrices and the noise-floor comparison.
6. Release of the strict wrapper and the labelled episode set.
