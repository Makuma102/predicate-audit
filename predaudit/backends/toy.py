"""A dependency-free stand-in for an `In(object, container)` task.

An object is released toward a container spanning [-w, w] and slides to rest
under damping. The predicate `In` is true whenever the object is inside the
boundary, so an object that slides *through* triggers a first-hit success
although it ends up outside. This reproduces the transient-success failure
mode that LIBERO-X Appendix D describes qualitatively, and lets the whole
pipeline run in seconds on a laptop.

The reference label here is the simulator's final resting state. It is an
oracle, not a human label, and numbers from this backend say nothing about
any real benchmark.
"""
from __future__ import annotations

import numpy as np

from . import Episode

# name -> std of release velocity (lower is a better policy)
POLICIES = {"strong": 0.10, "mid": 0.25, "weak": 0.40}


class ToyBackend:
    def __init__(self, half_width: float = 0.2, steps: int = 300,
                 dt: float = 0.05, damping: float = 0.05):
        self.w, self.steps, self.dt, self.damping = half_width, steps, dt, damping

    def tasks(self):
        return ["toy_put_in_bin"]

    def rollout(self, task: str, policy: str, seed: int) -> Episode:
        rng = np.random.default_rng(seed)
        x = rng.normal(-1.0, 0.05)
        v = rng.normal(1.0, POLICIES[policy])
        trace = np.zeros(self.steps, dtype=bool)
        for t in range(self.steps):
            x += v * self.dt
            v *= 1.0 - self.damping
            trace[t] = abs(x) < self.w
        return Episode(task, policy, seed, trace,
                       reference=bool(abs(x) < self.w),
                       reference_source="sim_final_state_oracle")
