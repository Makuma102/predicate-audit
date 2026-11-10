# predicate-audit

Code for the paper project **"How wrong are built-in success predicates? A
human-verified error model for simulated manipulation benchmarks."**

Simulated manipulation benchmarks (LIBERO, RoboCasa, RoboTwin, SimplerEnv)
decide success with hand-written predicates such as `In(object, container)`.
This project measures how often those verdicts disagree with human judgment
(false successes and false failures), per predicate type, task and policy,
and compares that error with sampling confidence intervals and published
gaps.

All analysis is in **MATLAB** (base MATLAB only, no toolbox). The single
Python file in `sim_shim/` is a rollout logger, needed because LIBERO and
MuJoCo have no MATLAB interface.

## Status

| Part | State |
|---|---|
| Statistics and graders (`matlab/+predaudit`) | Run in MATLAB R2019b; 23 of 23 unit tests pass. Expected values in the tests were computed independently |
| Real-data screening on the official LIBERO demonstrations | Runs end to end. The MuJoCo state layout recovered from the model matches the logged state width (1 + 41 + 37 = 79 on `libero_goal`) |
| Extended rollouts with policies | Logger drafted in `sim_shim/`, untested |
| Human labels | Not started |

The earlier toy simulator and its outputs were removed. Result files are
written to `results/` and are not committed.

## Requirements

MATLAB R2019b or newer. No toolbox.

## Run

```matlab
cd matlab
run_tests                                             % unit tests
download_libero_suite("libero_goal", fullfile(pwd, "data", "libero_goal"), 'DryRun', true)
download_libero_suite("libero_goal")                  % roughly 6 to 7 GB, official files
run_demo_terminal_audit("libero_goal")                % writes results/demo_terminal_audit/libero_goal/
build_libero_taxonomy                                 % writes results/taxonomy/ (40 tasks, from the task files)
```

`run_demo_terminal_audit` reads the logged MuJoCo state of every official
demonstration and reports, per task, how many accepted demonstrations have
the goal object moving in the final 10 steps or at the last logged state,
and how many end with the gripper not fully open, with exact 95% intervals.
Every demonstration was accepted by the built-in predicate, so this is a
first real-data look at how much an at-rest or a release requirement would
change verdicts. It is a screening measurement, not a human-verified
false-success rate. The released files do not embed the task definition, so
the reader fetches each task's BDDL file from the LIBERO repository once
and caches it next to the data.

## Layout

| Path | Purpose |
|---|---|
| `matlab/+predaudit/wilsonInterval.m`, `clopperPearson.m` | Binomial intervals (score and exact) |
| `matlab/+predaudit/confusionRates.m` | Counts, false-success and false-failure rates with both intervals |
| `matlab/+predaudit/stratifiedRatio.m` | Population rate from the stratified label sample (combined ratio estimator, finite-population correction) |
| `matlab/+predaudit/cohenKappa.m` | Inter-annotator agreement with a bootstrap interval |
| `matlab/+predaudit/mcnemarExact.m` | Paired exact test between two graders on the same episodes |
| `matlab/+predaudit/logisticFit.m` | Logistic regression by IRLS with Wald errors |
| `matlab/+predaudit/topKConcentration.m`, `noiseFloor.m` | Concentration of discrepancies; predicate bias vs sampling half-width |
| `matlab/+predaudit/firstHit.m`, `endOfEpisode.m`, `persistWindow.m` | Graders over a per-step predicate trace |
| `matlab/+predaudit/readLiberoFile.m`, `mjcfJointLayout.m`, `parseBddlGoal.m`, `demoTerminalAudit.m` | Reading official LIBERO HDF5 files and recovering object motion from the MuJoCo state |
| `matlab/download_libero_suite.m`, `run_demo_terminal_audit.m` | Data download and the real-data screening run |
| `matlab/build_libero_taxonomy.m` | Static table of goal predicates for the 40 LIBERO tasks, parsed from the official task files |
| `matlab/tests/` | Unit tests |
| `sim_shim/libero_logger.py` | Extended-rollout logger (untested draft) |
| `results/` | Run outputs (git-ignored) |

## What LIBERO's checker does

Read from the LIBERO source (`envs/predicates/base_predicates.py`,
`envs/object_states/base_object_states.py`, `envs/bddl_base_domain.py`):

- `step()` returns `done = _check_success()` on every step, so an
  evaluation loop that stops at `done` uses the first step on which the
  predicate is true.
- `In(a, b)`: `b` is in contact with `a` and `a` is inside `b`'s
  containment box. No velocity, release or persistence condition.
- `On(a, b)` for a plain object `b`: contact, xy distance below 0.03 m and
  `b`'s origin not above `a`'s. No velocity, release or persistence
  condition.
- The demonstration collection script accepts a demonstration only after
  the predicate has held for 10 consecutive steps.

## Roadmap

1. Run the tests and the demonstration screening in MATLAB.
2. Static taxonomy of checker code per task.
3. Kill-test: persistence re-grading of extended rollouts on flagged tasks with one strong and one weak policy.
4. About 2,000 human labels, two annotators, written rubric, Cohen's kappa.
5. Per-predicate-type confusion matrices, concentration, noise-floor comparison.
6. Release of the strict grader and the labelled episode set.
