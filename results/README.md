# results/

Experiment outputs land here, one folder per run: `results/<run-name>/`.
Everything in this folder except this file is git-ignored, so commit only
small summaries you deliberately force-add (`git add -f`).

Each run folder written by `scripts/run_baseline.py` contains:

| File | Content |
|---|---|
| `episodes.csv` | One row per episode: policy, task, built-in verdict, strict verdicts per persistence window, reference label |
| `summary.json` | Per policy and grader: success rate, false-success and false-failure rate with Wilson 95% intervals, plus the run config |
