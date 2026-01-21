# Opticka agent guide (MATLAB/PTB)

This is the **single source of truth** for coding/agent instructions in this repo.
Tool-specific instruction files (Copilot, etc.) should **link here** rather than
duplicating content.

## Formatting rules
- ALWAYS use camelCase for variable / property / function / method names.
- Comments MUST follow Doxygen conventions. Line comments start with `%>`
- Prefer **tabs** for indentation in all MATLAB code and scripts.
- **Exception:** YAML files (`*.yml`, `*.yaml`) must use **spaces** (2 spaces) for indentation.
- Keep lines reasonably short (aim ~80 chars when practical).

## Big picture
- Opticka is an object-oriented MATLAB framework around Psychtoolbox (PTB) for
  running experiments.
- Core orchestration is `runExperiment` (runs MOC tasks and state-machine
  behavioural tasks) and the GUI wrapper `opticka`.
- All classes can be used separately, and do not depend on runExperiment or the
  GUI for their function.
- Most classes inherit `optickaCore` (handle-class base) which sets common
  paths, IDs, argument parsing, and defaults.

## Key entry points
- Setup MATLAB path: run `addOptickaToPath` (adds repo + optional sibling
  toolboxes; excludes folders like `.git`, `legacy`, `doc`).
- GUI run: `o = opticka;` (creates GUI and a `runExperiment` instance at `o.r`).
- Script examples:
  - Method of Constants (MOC) demo: `optickaTest.m`
  - Behaviour/state-machine demo: `optickaBehaviourTest.m`
  - Minimal stimulus demo: `im = imageStimulus; run(im);`
  - Minimal state machine demo: `sM = stateMachine; runDemo(sM);`
  - Minimal touch screen demo: `tM = touchManager; demo(tM);`

## Standard architecture & data flow (typical run)
- `runExperiment` coordinates:
  - `screenManager` (`screen`) for opening/configuring PTB screen + degree→pixel
    transforms.
  - `metaStimulus` (`stimuli`) as a container for multiple stimuli; it forwards
    `setup/animate/draw/update/reset`.
  - `taskSequence` (`task`) for block/trial variable randomisation (`nVar`,
    `blockVar`, `trialVar`).
  - `stateMachine` + a `StateInfo.m` file for behavioural tasks.
  - Hardware/IO managers (strobe/reward/eyetracker/control) and optional network
    via `communication/jzmqConnection` (ZeroMQ, more robust) or
    `communication/dataConnection` (TCP/UDP).

## Project-specific conventions to follow
- **Handle classes + property validation**
  - Most classes are `handle` and rely on property validation/`arguments` blocks.
  - Prefer adding new public options as validated properties and add them to each
    class’s `allowedProperties` list.
- **Stimulus API contract**
  - New stimulus classes are expected to implement the unified interface used by
    `baseStimulus` and `metaStimulus`: `setup(screenManager)`, `animate`, `draw`, `update`, `reset`.
- **`metaStimulus` indexing**
  - Use cell indexing (`stims{1}`) to access underlying stimulus objects.
- **State-machine tasks**
  - State files (see `DefaultStateInfo.m` and `CoreProtocols/*StateInfo.m`) build
    cell arrays of anonymous function handles for `ENTRY/WITHIN/TRANSITION/EXIT`.
  - In a state file, these manager objects are expected to exist:
    `me` (runExperiment), `tS` (struct), `s` (screenManager), `sM` (stateMachine),
    `task` (taskSequence), `stims` (metaStimulus), `eT`, `io`, `rM`, `bR`, `uF`.
- **User extensibility for tasks**
  - To add custom per-task functions, copy `userFunctions.m` alongside a protocol
    but keep the class name `userFunctions`; reference methods within state files
    via `uF.<method>`.

## Data locations & naming
- Default save root is created automatically by `optickaCore.setPaths()`:
  - `~/OptickaFiles/SavedData`, `~/OptickaFiles/Protocols`,
    `~/OptickaFiles/Calibration`.
- ALF-style session folders are created by `optickaCore.getALF()` and used by
  `runExperiment` when saving by default.

## External integrations / dependencies
- Requires Psychtoolbox (PTB) and OpenGL; real experiments should avoid
  `debug=true` because timing fidelity is reduced.
- Networking uses `communication/jzmqConnection` (ZeroMQ) and 
  `communication/dataConnection` (PNET-based TCP/UDP) for remote control/telemetry.
- Alyx integration uses `communication/alyxManager` (REST API + secrets via
  `getSecret/setSecret`).

## When making changes
- Keep behavioural timing-sensitive code minimal and avoid adding per-frame
  allocations/logging in the display loop.
- Prefer editing/adding example protocols under `CoreProtocols/` (StateInfo +
  `.mat`) and custom functions in `userFunctions` rather than changing core runner logic.

## Tooling notes
- If a tool supports a “project instructions” file (Copilot, Gemini CLI, OpenCode,
  etc.), keep that file **minimal** and link to this document.
- If you add more tool-specific wrappers, do not fork/duplicate the rules above;
  only include tool quirks and a pointer back to `AGENTS.md`.
