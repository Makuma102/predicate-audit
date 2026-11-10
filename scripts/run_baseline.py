#!/usr/bin/env python
"""Baseline experiment: persistence re-grading of a built-in success predicate.

This is the week-2 kill-test in miniature. For every episode it records the
full predicate trace of an extended rollout, then compares

  builtin     first-hit verdict (what the benchmark would report)
  strict_N    predicate must hold N consecutive steps, N in --windows

against a reference label, and reports false-success / false-failure rates
with Wilson 95% intervals.

    python scripts/run_baseline.py                      # toy backend, seconds
    python scripts/run_baseline.py --episodes 2000 --out results/toy_2k
"""
from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path

from predaudit import grading
from predaudit.backends import toy
from predaudit.stats import confusion


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--episodes", type=int, default=500, help="episodes per policy and task")
    ap.add_argument("--windows", type=int, nargs="+", default=[10, 30, 100])
    ap.add_argument("--policies", nargs="+", default=list(toy.POLICIES))
    ap.add_argument("--seed", type=int, default=0)
    ap.add_argument("--out", type=Path, default=Path("results/baseline_toy"))
    args = ap.parse_args()

    backend = toy.ToyBackend()
    graders = {"builtin": grading.first_hit}
    for n in args.windows:
        graders[f"strict_N{n}"] = lambda tr, n=n: grading.persistent(tr, n)

    rows = []
    for policy in args.policies:
        for task in backend.tasks():
            for i in range(args.episodes):
                ep = backend.rollout(task, policy, args.seed + i)
                row = {"policy": policy, "task": task, "seed": ep.seed,
                       "reference": int(ep.reference)}
                row.update({g: int(f(ep.trace)) for g, f in graders.items()})
                rows.append(row)

    args.out.mkdir(parents=True, exist_ok=True)
    with open(args.out / "episodes.csv", "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0]))
        w.writeheader()
        w.writerows(rows)

    summary = {"config": {**vars(args), "out": str(args.out), "backend": "toy",
                          "reference_source": "sim_final_state_oracle"},
               "results": {}}
    print(f"{'policy':8} {'grader':12} {'success':>8} {'false-succ (95% CI)':>26} {'false-fail':>11}")
    for policy in args.policies:
        sub = [r for r in rows if r["policy"] == policy]
        ref = [r["reference"] for r in sub]
        summary["results"][policy] = {}
        for g in graders:
            c = confusion([r[g] for r in sub], ref)
            summary["results"][policy][g] = c
            fs, ff = c["false_success_rate"], c["false_failure_rate"]
            fs_s = "n/a" if fs["rate"] is None else \
                f"{fs['rate']:.3f} [{fs['ci95'][0]:.3f}, {fs['ci95'][1]:.3f}]"
            ff_s = "n/a" if ff["rate"] is None else f"{ff['rate']:.3f}"
            print(f"{policy:8} {g:12} {c['success_rate']['rate']:8.3f} {fs_s:>26} {ff_s:>11}")
    with open(args.out / "summary.json", "w") as f:
        json.dump(summary, f, indent=2)
    print(f"\nWrote {args.out}/episodes.csv and summary.json")


if __name__ == "__main__":
    main()
