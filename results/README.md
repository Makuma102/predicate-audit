# results/

Experiment outputs land here, one folder per run. Everything in this folder
except this file is git-ignored, so commit only small summaries you
deliberately force-add (`git add -f`).

`matlab/run_demo_terminal_audit.m` writes
`results/demo_terminal_audit/<suite>/`:

| File | Content |
|---|---|
| `episodes.csv` | One row per (demonstration, goal object): final and windowed linear and angular speed, gripper aperture, last gripper command, at-rest and released flags |
| `tasks.csv` | Per task: accepted demonstrations, how many end with the goal object moving, how many end with the gripper not open, exact 95% intervals |
| `config.json` | Thresholds, MATLAB release, date |
