"""Confusion counts and binomial intervals."""
from __future__ import annotations

import math


def wilson(k: int, n: int, z: float = 1.959964) -> tuple[float, float]:
    """Wilson score interval for k successes out of n (95% by default)."""
    if n == 0:
        return (0.0, 1.0)
    p = k / n
    d = 1 + z * z / n
    c = (p + z * z / (2 * n)) / d
    h = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / d
    return (max(0.0, c - h), min(1.0, c + h))


def confusion(pred, ref) -> dict:
    """Compare a grader's verdicts with reference labels.

    false_success_rate = P(reference says fail | grader says success)
    false_failure_rate = P(reference says success | grader says fail)
    Both are conditioned on the grader's verdict, which is what a reader of a
    reported success rate needs to know.
    """
    pred = [bool(x) for x in pred]
    ref = [bool(x) for x in ref]
    if len(pred) != len(ref):
        raise ValueError("length mismatch")
    tp = sum(p and r for p, r in zip(pred, ref))
    fp = sum(p and not r for p, r in zip(pred, ref))
    fn = sum((not p) and r for p, r in zip(pred, ref))
    tn = sum((not p) and (not r) for p, r in zip(pred, ref))
    n = len(pred)

    def rate(k, m):
        lo, hi = wilson(k, m)
        return {"k": k, "n": m, "rate": (k / m if m else None), "ci95": [lo, hi]}

    return {
        "n": n, "tp": tp, "fp": fp, "fn": fn, "tn": tn,
        "success_rate": rate(tp + fp, n),
        "false_success_rate": rate(fp, tp + fp),
        "false_failure_rate": rate(fn, fn + tn),
    }
