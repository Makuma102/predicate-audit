"""LIBERO backend (UNTESTED scaffold).

Written against the public LIBERO API from memory; it has not been run,
because LIBERO, MuJoCo rendering and policy checkpoints are not part of the
base environment. Expect to fix details when first running it in week 1.

Key design point: the rollout does NOT stop at the first success. It keeps
stepping for `extra_steps` after the first hit and records `check_success()`
at every step, so graders in `predaudit.grading` can be applied offline.
"""
from __future__ import annotations

import os

import numpy as np

from . import Episode


class LiberoBackend:
    def __init__(self, suite: str = "libero_10", max_steps: int = 600,
                 extra_steps: int = 100, post_success: str = "policy"):
        try:
            from libero.libero import benchmark, get_libero_path
            from libero.libero.envs import OffScreenRenderEnv
        except ImportError as e:  # pragma: no cover
            raise ImportError(
                "LIBERO is not installed. See README, 'Running on LIBERO'."
            ) from e
        if post_success not in ("policy", "release"):
            raise ValueError("post_success must be 'policy' or 'release'")
        self._env_cls = OffScreenRenderEnv
        self._bddl_root = get_libero_path("bddl_files")
        self.suite = benchmark.get_benchmark_dict()[suite]()
        self.max_steps, self.extra_steps = max_steps, extra_steps
        self.post_success = post_success

    def tasks(self):
        return [self.suite.get_task(i).name for i in range(self.suite.n_tasks)]

    def rollout(self, task: str, policy, seed: int) -> Episode:
        """`policy` is a callable obs -> 7-D action with a `.name` attribute."""
        idx = self.tasks().index(task)
        t = self.suite.get_task(idx)
        env = self._env_cls(
            bddl_file_name=os.path.join(self._bddl_root, t.problem_folder, t.bddl_file),
            camera_heights=128, camera_widths=128)
        env.seed(seed)
        env.reset()
        inits = self.suite.get_task_init_states(idx)
        obs = env.set_init_state(inits[seed % len(inits)])
        trace, first, step = [], None, 0
        while step < self.max_steps and (first is None or step < first + self.extra_steps):
            if first is not None and self.post_success == "release":
                # scripted protocol: open gripper and retreat upward
                action = np.array([0, 0, 0.3, 0, 0, 0, -1.0])
            else:
                action = policy(obs)
            obs, _, _, _ = env.step(action)
            ok = bool(env.check_success())
            trace.append(ok)
            if ok and first is None:
                first = step
            step += 1
        env.close()
        return Episode(task, getattr(policy, "name", "policy"), seed,
                       np.array(trace, dtype=bool))
