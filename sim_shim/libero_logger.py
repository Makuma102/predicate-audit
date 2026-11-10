"""Extended-rollout logger for LIBERO (UNTESTED draft).

This is the only Python in the project, and it exists because LIBERO,
robosuite and MuJoCo have no MATLAB interface. It does no analysis: it runs
episodes past the first success and writes one HDF5 file per episode, which
the MATLAB code grades offline.

It has not been run yet. Expect to fix details on first use.

Log layout (read in MATLAB with h5read / h5readatt):
    /predicate   T      uint8   env._check_success() after every step
    /states      T x D  float64 flattened MuJoCo state [time, qpos, qvel]
    /actions     T x 7  float64
    /gripper     T x 2  float64 finger joint positions
    attrs: task, policy, seed, post_success, first_hit (-1 if none),
           model_file (MJCF text), bddl_file_content
"""
from __future__ import annotations

import os

import h5py
import numpy as np


def rollout(suite_name: str, task_index: int, policy, seed: int, out_path: str,
            max_steps: int = 600, extra_steps: int = 100,
            post_success: str = "policy") -> None:
    """`policy` is a callable obs -> 7-D action with a `.name` attribute."""
    from libero.libero import benchmark, get_libero_path
    from libero.libero.envs import OffScreenRenderEnv

    if post_success not in ("policy", "release"):
        raise ValueError("post_success must be 'policy' or 'release'")
    suite = benchmark.get_benchmark_dict()[suite_name]()
    task = suite.get_task(task_index)
    bddl = os.path.join(get_libero_path("bddl_files"), task.problem_folder, task.bddl_file)
    env = OffScreenRenderEnv(bddl_file_name=bddl, camera_heights=128, camera_widths=128)
    env.seed(seed)
    env.reset()
    inits = suite.get_task_init_states(task_index)
    obs = env.set_init_state(inits[seed % len(inits)])

    predicate, states, actions, gripper = [], [], [], []
    first, step = -1, 0
    while step < max_steps and (first < 0 or step < first + extra_steps):
        if first >= 0 and post_success == "release":
            action = np.array([0, 0, 0.3, 0, 0, 0, -1.0])  # open gripper, retreat upward
        else:
            action = np.asarray(policy(obs), dtype=float)
        obs, _, _, _ = env.step(action)
        ok = bool(env.check_success())
        predicate.append(ok)
        states.append(env.sim.get_state().flatten())
        actions.append(action)
        gripper.append(obs["robot0_gripper_qpos"])
        if ok and first < 0:
            first = step
        step += 1

    with h5py.File(out_path, "w") as f:
        f.create_dataset("predicate", data=np.asarray(predicate, dtype=np.uint8))
        f.create_dataset("states", data=np.stack(states))
        f.create_dataset("actions", data=np.stack(actions))
        f.create_dataset("gripper", data=np.stack(gripper))
        f.attrs["task"] = task.name
        f.attrs["policy"] = getattr(policy, "name", "policy")
        f.attrs["seed"] = seed
        f.attrs["post_success"] = post_success
        f.attrs["first_hit"] = first
        f.attrs["model_file"] = env.sim.model.get_xml()
        f.attrs["bddl_file_content"] = open(bddl, "r").read()
    env.close()
