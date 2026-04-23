# Opticka agent guide (MATLAB/PTB)

This is the **single source of truth** for coding/agent instructions in this repo.
Tool-specific instruction files (Copilot, etc.) should **link here** rather than
duplicating content.

## Online Documentation

- See https://deepwiki.com/iandol/opticka for deepwiki documentation for this repo.
- See https://iandol.github.io/OptickaDocs/index.html for the Class documentation generated using DOxygen.

## Formatting rules
- ALWAYS use camelCase for variable / property / function / method names.
- Comments MUST follow Doxygen conventions. Line comments start with `%>`
- Prefer **tabs** for indentation in all MATLAB code and scripts.
- **Exception:** YAML files (`*.yml`, `*.yaml`) must use **spaces** (2 spaces) for indentation.
- Keep lines reasonably short (aim ~80 chars when practical).

## Big picture
- Opticka is an object-oriented MATLAB framework built around Psychtoolbox (PTB) for
  running cognitive neuroscience experiments.
- Core orchestration is `runExperiment` (runs MOC tasks and state-machine
  behavioural tasks) and the GUI wrapper `opticka`.
- All classes can be used separately, and do not depend on `runExperiment` or the
  GUI for their function.
- Handle classes ensures a singleton pattern, where each manager object is a 
  unique representation that can be passed to other objects. For example an 
  physical eyetracker gets a singular handle object, and this can be passed 
  to other objects so they can use the eyetracker without conflict.
- Most classes inherit `optickaCore` (handle-class base) which sets common
  paths, UUIDs (each object gets a unique ID), argument parsing, and defaults.

## Key entry points
- Setup MATLAB path: run `addOptickaToPath` (adds repo + optional sibling
  toolboxes; excludes folders like `.git`, `legacy`, `doc`).
- GUI run: `o = opticka;` (creates GUI and a `runExperiment` instance at
  `o.r`).
- Script examples (not using GUI):
  - Method of Constants (MOC) demo: `optickaTest.m`
  - Behaviour/state-machine demo: `optickaBehaviourTest.m`
  - Minimal stimulus demo: `im = imageStimulus; run(im);`
  - Minimal state machine demo: `sM = stateMachine; demo(sM);`
  - Minimal eyetracker demo (dummy uses mouse to simulate the eye): 
    `eM =iRecManager('isDummy',true); demo(eM);`
  - Minimal touch screen demo: `tM = touchManager; demo(tM);`

## Standard architecture & data flow (typical run)

Each object can be run independently or managed via `runExperiment` to coordinates the following objects:

- `screenManager` (`screen`) for opening/configuring PTB screen,
  degree↔pixel transforms and as a singleton "container" that holds all
  settings to pass to other classes.
- `metaStimulus` (`stimuli`) as a container for multiple stimuli; it forwards
  `setup/animate/draw/update/reset`. A single draw command for example can 
  "draw" many stimuli.
- `taskSequence` (`task`) for block/trial variable randomisation (`nVar`,
  `blockVar`, `trialVar`).
- `stateMachine` + a `StateInfo.m` file for behavioural tasks.
- `tobiiManager` `eyelinkManager` `iRecManager` provide a unified API
  `eyetrackerCore` for integrating eye trackers, you can swap the eye
  tracker without changing any task code.
- `touchManager` manages touch screen tasks by wrapping the PTB TouchQueue
  functions. Touchscreens only send touch events when there is a change of
  touch state.
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

## Alyx database integration

Opticka integrates with the Alyx data management system (IBL pipeline) for
recording and uploading experimental sessions. Session metadata is stored in
Alyx via REST API, while actual data files are uploaded to an S3-compatible
object store that Alyx links to the session records.

### Core classes
- `alyxManager` — handles Alyx REST API authentication, session registration,
  and metadata CRUD. Secrets stored via `getSecret`/`setSecret` (e.g.
  `alyxManager.setSecret('username','password')`).
- `awsManager` — handles S3-compatible file uploads (multipart + streaming).
  Used by `runExperiment` to upload recorded data files after a session.

### Typical workflow (runExperiment.runTask)
1. **Session creation** — `alyxManager.createSession(subject,date,project)` 
   registers the session in Alyx and returns a session UUID.
2. **Recording** — behavioural data saved locally to ALF-style session folders
   (`optickaCore.getALF`).
3. **File upload** — after recording, `awsManager.uploadSession(sessionPath,
   alyxSessionURL)` pushes files to S3 and associates them with the Alyx
   session record.
4. **Metadata update** — `alyxManager.updateSession(sessionUUID, key, value)`
   can tag sessions (e.g. `{'qc':'pass'}`) or attach probe/chan map info.

### Online documentation
- Alyx REST API reference: https://openalyx.internationalbrainlab.org/docs
- ALF file format: https://int-brain-lab.github.io/ONE/alf_intro.html
- Alyx API docs: https://alyx.readthedocs.io/en/latest/api.html

### Key alyxManager properties for session management
- `baseURL` — Alyx server endpoint (e.g. `https://alyx.example.org`)
- `username` / `token` — authentication credentials (use `setSecret`)
- `subjects` — cached list of registered subjects
- `projects` — cached list of registered projects

### Key awsManager properties for uploads
- `endpoint` — S3-compatible endpoint URL
- `bucket` — target bucket name
- `accessKey` / `secretKey` — credentials (use `setSecret`)

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
