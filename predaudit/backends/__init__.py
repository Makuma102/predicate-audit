"""Rollout backends.

A backend exposes `tasks()` and `rollout(task, policy, seed) -> Episode`.
The episode always carries the full extended predicate trace.
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Optional

import numpy as np


@dataclass
class Episode:
    task: str
    policy: str
    seed: int
    trace: np.ndarray                 # built-in predicate at every step
    reference: Optional[bool] = None  # ground-truth / human label, if known
    reference_source: str = "none"
