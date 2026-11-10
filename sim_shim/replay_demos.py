"""Replay official LIBERO demonstrations and keep simulating past their end.

Simulator shim only: it produces logs, all grading and statistics are done
in MATLAB (matlab/run_extension_audit.m).

For every demonstration in an official <task>_demo.hdf5 file:

  A. Load each logged MuJoCo state into the simulator and evaluate the
     built-in success predicate on it. This gives the per-step predicate
     trace that the released files do not contain. No dynamics are run, so
     there is no replay divergence.
  B. Diagnostic: replay the logged actions open loop from the first
     logged state, recording the predicate after every action and the
     largest distance between the replayed and the logged state. With a
     MuJoCo or robosuite version other than the one used for recording,
     this replay drifts, so it is not used for grading.
  C. Restart from the exact last logged state (controller pose cache
     refreshed) and simulate EXTRA further control steps under one
     post-success protocol, logging the predicate and the state:
       release  open the gripper and do not move for SETTLE steps, then
                retreat straight up
       hold     zero motion command, gripper command as in the last
                demonstration step

Output: one HDF5 file per input file and protocol,
    /demo_i/predicate_demo    T      uint8   predicate on the logged states
    /demo_i/predicate_replay  T      uint8   predicate after each replayed action
    /demo_i attr replay_divergence   max |replayed - logged state|, time excluded
    /demo_i/predicate_ext   EXTRA  uint8
    /demo_i/states_ext      EXTRA x D float64   [time, qpos, qvel]
    /demo_i/actions_ext     EXTRA x 7 float64
    attrs: source_file, protocol, extra_steps, settle_steps, control_freq

Usage:
    python replay_demos.py --demo-file <task>_demo.hdf5 --out-dir <dir> \
        --protocol release --extra 100
"""
from __future__ import annotations

import argparse
import json
import os

import h5py
import numpy as np


def localize_model_xml(xml_str: str) -> str:
    """Point the mesh and texture paths of a logged model at local files.

    The logged models carry the absolute paths of the machine that recorded
    them (".../robosuite/models/assets/..." and ".../chiliocosm/assets/...").
    """
    import xml.etree.ElementTree as ET

    import robosuite
    from libero.libero import get_libero_path

    robosuite_root = os.path.split(robosuite.__file__)[0]
    libero_assets = get_libero_path("assets")
    root = ET.fromstring(xml_str)
    asset = root.find("asset")
    for elem in asset.findall("mesh") + asset.findall("texture"):
        old = elem.get("file")
        if old is None:
            continue
        parts = old.split("/")
        if "chiliocosm" in parts and "assets" in parts:
            i = len(parts) - 1 - parts[::-1].index("assets")
            new = os.path.normpath(os.path.join(libero_assets, *parts[i + 1:]))
        elif "robosuite" in parts:
            i = len(parts) - 1 - parts[::-1].index("robosuite")
            new = os.path.join(robosuite_root, *parts[i + 1:])
        else:
            continue
        if not os.path.isfile(new):
            raise FileNotFoundError(f"Model asset not found locally: {new} (logged as {old})")
        elem.set("file", new)
    return ET.tostring(root, encoding="utf8").decode("utf8")


def build_env(f: h5py.File):
    from libero.libero import get_libero_path
    from libero.libero.envs import TASK_MAPPING

    env_args = json.loads(f["data"].attrs["env_args"])
    problem_info = json.loads(f["data"].attrs["problem_info"])
    env_kwargs = env_args["env_kwargs"]
    recorded = f["data"].attrs["bddl_file_name"]
    if isinstance(recorded, bytes):
        recorded = recorded.decode()
    relative = recorded.split("bddl_files/")[-1]
    bddl = os.path.join(get_libero_path("bddl_files"), relative)
    if not os.path.isfile(bddl):
        raise FileNotFoundError(f"Task definition not found: {bddl}")
    env_kwargs.update(
        bddl_file_name=bddl,
        has_renderer=False,
        has_offscreen_renderer=False,
        ignore_done=True,
        use_camera_obs=False,
        reward_shaping=True,
        control_freq=20,
    )
    for key in ("camera_depths", "camera_names", "camera_heights", "camera_widths",
                "camera_segmentations"):
        env_kwargs.pop(key, None)
    env = TASK_MAPPING[problem_info["problem_name"]](**env_kwargs)
    return env


def demo_key(name: str) -> int:
    return int(name.split("_")[-1])


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--demo-file", required=True)
    parser.add_argument("--out-dir", required=True)
    parser.add_argument("--protocol", choices=("release", "hold"), default="release")
    parser.add_argument("--extra", type=int, default=100)
    parser.add_argument("--settle", type=int, default=20)
    parser.add_argument("--max-demos", type=int, default=0)
    args = parser.parse_args()

    os.makedirs(args.out_dir, exist_ok=True)
    base = os.path.basename(args.demo_file).replace("_demo.hdf5", "")
    out_path = os.path.join(args.out_dir, f"{base}_{args.protocol}.h5")

    with h5py.File(args.demo_file, "r") as f, h5py.File(out_path, "w") as out:
        env = build_env(f)
        demos = sorted(f["data"].keys(), key=demo_key)
        if args.max_demos > 0:
            demos = demos[: args.max_demos]
        out.attrs["source_file"] = os.path.basename(args.demo_file)
        out.attrs["protocol"] = args.protocol
        out.attrs["extra_steps"] = args.extra
        out.attrs["settle_steps"] = args.settle
        out.attrs["control_freq"] = 20

        for name in demos:
            grp = f["data"][name]
            states = grp["states"][()]
            actions = grp["actions"][()]
            model_xml = grp.attrs["model_file"]
            if isinstance(model_xml, bytes):
                model_xml = model_xml.decode()

            env.reset()
            model_xml = localize_model_xml(model_xml)
            env.reset_from_xml_string(model_xml)
            env.sim.reset()

            # A. predicate on every logged state
            pred_demo = np.zeros(len(states), dtype=np.uint8)
            for t, s in enumerate(states):
                env.sim.set_state_from_flattened(s)
                env.sim.forward()
                env._post_process()
                pred_demo[t] = bool(env._check_success())

            # B. diagnostic only: replay the logged actions open loop from the
            # first logged state and record how far the simulation drifts
            # from the logged one
            env.sim.set_state_from_flattened(states[0])
            env.sim.forward()
            for robot in env.robots:
                robot.controller.update(force=True)
                robot.controller.reset_goal()
            pred_replay = np.zeros(len(actions), dtype=np.uint8)
            divergence = 0.0
            for t, action in enumerate(actions):
                env.step(action)
                pred_replay[t] = bool(env._check_success())
                if t + 1 < len(states):
                    divergence = max(divergence, float(np.linalg.norm(
                        (env.sim.get_state().flatten() - states[t + 1])[1:])))
            # C. extension: restart from the exact last logged state. The
            # controller caches the end-effector pose, so refresh it and
            # reset its goal; otherwise the first command drives the arm
            # toward a stale pose.
            env.sim.set_state_from_flattened(states[-1])
            env.sim.forward()
            for robot in env.robots:
                robot.controller.update(force=True)
                robot.controller.reset_goal()
            pred_ext = np.zeros(args.extra, dtype=np.uint8)
            states_ext = np.zeros((args.extra, states.shape[1]))
            actions_ext = np.zeros((args.extra, 7))
            for k in range(args.extra):
                action = np.zeros(7)
                if args.protocol == "release":
                    action[6] = -1.0
                    if k >= args.settle:
                        action[2] = 0.5
                else:
                    action[6] = actions[-1, 6]
                env.step(action)
                pred_ext[k] = bool(env._check_success())
                states_ext[k] = env.sim.get_state().flatten()
                actions_ext[k] = action

            g = out.create_group(name)
            g.create_dataset("predicate_demo", data=pred_demo)
            g.create_dataset("predicate_replay", data=pred_replay)
            g.attrs["replay_divergence"] = divergence
            g.create_dataset("predicate_ext", data=pred_ext)
            g.create_dataset("states_ext", data=states_ext)
            g.create_dataset("actions_ext", data=actions_ext)
            print(f"{base} {name}: T={len(states)} first_hit={int(np.argmax(pred_demo)) if pred_demo.any() else -1} "
                  f"demo_true={int(pred_demo.sum())} end_true={int(pred_ext[-1])} "
                  f"replay_true={int(pred_replay.sum())} div={divergence:.4f} ext_true={int(pred_ext.sum())}/{args.extra}", flush=True)
        env.close()
    print(f"written {out_path}")


if __name__ == "__main__":
    main()
