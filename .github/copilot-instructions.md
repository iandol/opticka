# Copilot instructions for Opticka (MATLAB/PTB)

## Big picture
- Opticka is an object-oriented MATLAB framework around Psychtoolbox (PTB) for running experiments.
- Core orchestration is `runExperiment` (runs MOC tasks and state-machine behavioural tasks) and the GUI wrapper `opticka`.
- Most classes inherit `optickaCore` (handle-class base) which sets common paths, IDs, argument parsing, and defaults.

## Key entry points
- Setup MATLAB path: run `addOptickaToPath` (adds repo + optional sibling toolboxes; excludes folders like `.git`, `legacy`, `doc`).
- GUI run: `o = opticka;` (creates GUI and a `runExperiment` instance at `o.r`).
- Script examples:
  - MOC demo: `optickaTest.m`
  - Behaviour/state-machine demo: `optickaBehaviourTest.m`
  - Minimal state machine demo: `sM = stateMachine; runDemo(sM);`

## Architecture & data flow (typical run)
- `runExperiment` owns/coordinates:
  - `screenManager` (`screen`) for opening/configuring PTB screen + degree→pixel transforms.
  - `metaStimulus` (`stimuli`) as a container for multiple stimuli; it forwards `setup/animate/draw/update/reset`.
  - `taskSequence` (`task`) for block/trial variable randomisation (`nVar`, `blockVar`, `trialVar`).
  - `stateMachine` + a `StateInfo.m` file for behavioural tasks.
  - Hardware/IO managers (strobe/reward/eyetracker/control) and optional network via `communication/dataConnection`.

## Project-specific conventions to follow
- **Handle classes + property validation**: many classes are `handle` and rely on property validation/`arguments` blocks.
  - Prefer adding new options as validated properties and add them to each class’s `allowedProperties` list.
- **Stimulus API contract**: stimuli are expected to implement a unified interface used by `metaStimulus`:
  - `setup(screenManager)`, `animate`, `draw`, `update`, `reset`, and often `resetTicks`.
- **`metaStimulus` indexing**: use cell indexing (`stims{1}`) to access underlying stimulus objects.
- **State-machine tasks**:
  - State files (see `DefaultStateInfo.m` and `CoreProtocols/*StateInfo.m`) build cell arrays of anonymous function handles for `ENTRY/WITHIN/TRANSITION/EXIT`.
  - In a state file, these objects are expected to exist: `me` (runExperiment), `tS` (struct), `s` (screenManager), `sM` (stateMachine), `task` (taskSequence), `stims` (metaStimulus), `eT`, `io`, `rM`, `bR`, `uF`.
- **User extensibility for tasks**: to add custom per-task functions, copy `userFunctions.m` alongside a protocol but keep the class name `userFunctions`; reference methods from state files via `uF.<method>`.

## Data locations & naming
- Default save root is created automatically by `optickaCore.setPaths()`:
  - `~/OptickaFiles/SavedData`, `~/OptickaFiles/Protocols`, `~/OptickaFiles/Calibration`.
- ALF-style session folders are created by `optickaCore.getALF()` and used by `runExperiment` when saving.

## External integrations / dependencies
- Requires Psychtoolbox (PTB) and OpenGL; real experiments should avoid `debug=true` because timing fidelity is reduced.
- Networking uses `communication/dataConnection` (PNET-based TCP/UDP) for remote control/telemetry.
- Alyx integration uses `communication/alyxManager` (REST API + secrets via `getSecret/setSecret`).

## When making changes
- Keep behavioural timing-sensitive code minimal and avoid adding per-frame allocations/logging in the display loop.
- Prefer editing/adding example protocols under `CoreProtocols/` (StateInfo + `.mat`) rather than changing core runner logic.

## Formatting rules

- Prefer **tabs** for indentation in code and scripts.
- **Exception:** YAML files (`*.yml`, `*.yaml`) must use **spaces** (2 spaces).
- Keep lines reasonably short (aim ~80 chars when practical).
