"""Graders that turn a per-step predicate trace into an episode verdict.

A trace is a 1-D boolean array: trace[t] is the benchmark's own success
predicate evaluated at step t of an *extended* rollout (one that was not
stopped at the first success).
"""
from __future__ import annotations

import numpy as np


def first_hit(trace) -> bool:
    """Built-in behaviour of first-success benchmarks: any true step counts."""
    return bool(np.any(trace))


def end_of_episode(trace) -> bool:
    """Verdict of benchmarks that only check the final step."""
    trace = np.asarray(trace, dtype=bool)
    return bool(trace.size and trace[-1])


def persistent(trace, window: int, extra=None) -> bool:
    """True if the predicate holds for `window` consecutive steps.

    `extra` is an optional boolean trace of additional per-step conditions
    (object at rest, gripper released, ...) that must hold on the same steps.
    """
    if window < 1:
        raise ValueError("window must be >= 1")
    ok = np.asarray(trace, dtype=bool)
    if extra is not None:
        ok = ok & np.asarray(extra, dtype=bool)
    run = 0
    for v in ok:
        run = run + 1 if v else 0
        if run >= window:
            return True
    return False
