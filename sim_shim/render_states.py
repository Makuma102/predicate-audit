"""Render logged and extended states of a demonstration for visual checks.

Simulator shim only. For each requested demonstration it renders the last
logged state of the official file and selected steps of the extension log
written by replay_demos.py, from a camera aimed at a named object, and
writes one PNG strip per demonstration with the predicate value in the
file name of each frame.

Run with MUJOCO_GL=egl.

Usage:
    python render_states.py --demo-file <task>_demo.hdf5 --ext-file <task>_release.h5 \
        --object black_book_1 --demos 0 1 3 --steps 10 20 100 --out-dir <dir>
"""
from __future__ import annotations

import argparse
import os

import h5py
import mujoco
import numpy as np
from PIL import Image

from replay_demos import localize_model_xml


def set_state(model, data, flat):
    nq, nv = model.nq, model.nv
    if flat.shape[0] != 1 + nq + nv:
        raise ValueError(f"state width {flat.shape[0]} != 1 + {nq} + {nv}")
    data.time = flat[0]
    data.qpos[:] = flat[1:1 + nq]
    data.qvel[:] = flat[1 + nq:]
    mujoco.mj_forward(model, data)


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--demo-file", required=True)
    p.add_argument("--ext-file", required=True)
    p.add_argument("--object", required=True)
    p.add_argument("--demos", type=int, nargs="+", default=[0])
    p.add_argument("--steps", type=int, nargs="+", default=[10, 20, 100])
    p.add_argument("--out-dir", required=True)
    p.add_argument("--azimuths", type=float, nargs="+", default=[135.0, 45.0])
    p.add_argument("--distance", type=float, default=0.55)
    p.add_argument("--elevation", type=float, default=-35.0)
    args = p.parse_args()
    os.makedirs(args.out_dir, exist_ok=True)

    with h5py.File(args.demo_file, "r") as f, h5py.File(args.ext_file, "r") as e:
        for i in args.demos:
            grp = f[f"data/demo_{i}"]
            xml = grp.attrs["model_file"]
            xml = xml.decode() if isinstance(xml, bytes) else xml
            model = mujoco.MjModel.from_xml_string(localize_model_xml(xml))
            data = mujoco.MjData(model)
            body = mujoco.mj_name2id(model, mujoco.mjtObj.mjOBJ_BODY, args.object + "_main")
            if body < 0:
                raise ValueError(f"No body named {args.object}_main in the model")
            renderer = mujoco.Renderer(model, 360, 480)
            states = grp["states"][()]
            ext = e[f"demo_{i}"]
            pred_demo = ext["predicate_demo"][()]
            pred_ext = ext["predicate_ext"][()]
            frames = [("logged_end", states[-1], int(pred_demo[-1]))]
            for k in args.steps:
                frames.append((f"ext_{k:03d}", ext["states_ext"][k - 1], int(pred_ext[k - 1])))
            rows = []
            for az in args.azimuths:
                row = []
                for _, flat, _ in frames:
                    set_state(model, data, flat)
                    cam = mujoco.MjvCamera()
                    cam.type = mujoco.mjtCamera.mjCAMERA_FREE
                    cam.lookat[:] = data.xpos[body]
                    cam.distance = args.distance
                    cam.azimuth = az
                    cam.elevation = args.elevation
                    renderer.update_scene(data, camera=cam)
                    row.append(renderer.render().copy())
                rows.append(np.concatenate(row, axis=1))
            strip = np.concatenate(rows, axis=0)
            tag = "_".join(f"{n}-p{v}" for n, _, v in frames)
            base = os.path.basename(args.demo_file).replace("_demo.hdf5", "")[:40]
            out = os.path.join(args.out_dir, f"{base}_demo{i}_{tag}.png")
            Image.fromarray(strip).save(out)
            z = [float(flat[1 + model.jnt_qposadr[model.body_jntadr[body]] + 2]) for _, flat, _ in frames]
            print(out, "z=", [round(v, 3) for v in z], flush=True)


if __name__ == "__main__":
    main()
