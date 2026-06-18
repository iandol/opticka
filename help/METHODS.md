---
title: State Machine Methods Reference
---

> See also docs for the [stateInfo file](uihelpstate.html).

# Useful Task Methods

The state machine (`stateMachine` class) defines states and the connections between them. The state machine can run cell arrays of methods (`@()` anonymous functions) when states are entered (run once), within (repeated on every screen redraw) and exited (run once). In addition there are ways to transition *out* of a state if some condition is met. For example if we are in `[STATE 1]` and the eyetracker tells us the subject has fixated for the correct time, then transition functions can jump us to another state to e.g. show a stimulus.


```{.smaller}
╔════════════════════════════════════════════════════════════════════════════════════════════════╗
║                  ┌─────────┐                                       ┌─────────┐                 ║
║                  │ STATE 1 │                                       │ STATE 2 │                 ║
║       ┌──────────┴─────────┴───────────┐                ┌──────────┴─────────┴──────────┐      ║
║  ┌────┴────┐      ┌────────┐      ┌────┴───┐       ┌────┴────┐      ┌────────┐     ┌────┴───┐  ║
╚═▶│  ENTER  │─────▶│ WITHIN │─────▶│  EXIT  │══════▶│  ENTER  │─────▶│ WITHIN │────▶│  EXIT  │══╣
   └────┬────┘      └────────┘      └────┬───┘       └────┬────┘      └────────┘     └────┬───┘  ║
        │          ┌──────────┐          │                │          ┌──────────┐         │      ║
        └──────────┤TRANSITION├──────────┘                └──────────┤TRANSITION├─────────┘      ║
                   └─────╦────┘                                      └──────────┘                ║
                         ║                  ┌─────────┐                                          ║
                         ║                  │ STATE 3 │                                          ║
                         ║       ┌──────────┴─────────┴───────────┐                              ║
                         ║  ┌────┴────┐      ┌────────┐      ┌────┴───┐                          ║
                         ╚═▶│  ENTER  │─────▶│ WITHIN │─────▶│  EXIT  │══════════════════════════╝
                            └────┬────┘      └────────┘      └────┬───┘
                                 │          ┌──────────┐          │
                                 └──────────┤TRANSITION├──────────┘
                                            └──────────┘
```

These various methods control the logic and flow of experiments. This document lists the most important ones used in flexible behavioural task design. It is better for methods to evaluate properties (properties are the variables managed by the class object). Because of this we choose to create methods that alter the properties of each class. For example, `show(stims)` is a method that allows the stimulus manager to show all stimuli in the list; it does this by setting each stimulus' `isVisible` property to `true`. `hide(stims)` hides all stimuli by setting `isVisible` property to `false`, or you could just hide the 3rd stimulus in the list: `hide(stims, 3)`.

For those unfamiliar with object-oriented design, a *CLASS* (e.g. `stateMachine`) is initiated as an *OBJECT* variable (named `sM` during the experiment run, it is an *instance* of the class). **ALL** Opticka classes are [**handle classes**](https://www.mathworks.com/help/matlab/handle-classes.html); this means if we assign `sM2 = sM` — **both** of these named instances point to the **same** object.

As experiments are run **_inside_** the `runExperiment.runTask()` method, this class refers to *itself* as `me`, so methods that *belong* to `runExperiment` can be called by using `me.myMethod()` or `myMethod(me)` (both forms are equivalent to MATLAB). Other important object instances, for example the `screenManager` class is called via `s`, so to call the method `drawSpot` from our `screenManager` instance `s`, we can use `drawSpot(s)` (or `s.drawSpot()`). You will see below the object names that are available as we run the experiment from `runExperiment`. The `runExperiment` object `me` keeps most of the objects as properties: so `s` is actually also stored in the property `me.screen`, `sM` is stored in the property `me.stateMachine` etc.

### Available Object Instances

| Object | Class | Description |
|--------|-------|-------------|
| `me` | `runExperiment` | Principal experiment runner |
| `s` | `screenManager` | PTB screen management |
| `sM` | `stateMachine` | State machine controller |
| `task` | `taskSequence` | Trial/block randomisation |
| `stims` | `metaStimulus` | Stimulus group manager |
| `eT` | `eyetrackerCore` subclass | Eye tracker interface |
| `io` | `ioManager` | Digital I/O (strobe/TTL) |
| `rM` | `rewardManager` | Reward delivery |
| `bR` | `behaviouralRecord` | Behavioural performance plot |
| `aM` | `audioManager` | Audio playback |
| `tL` | `timeLogger` | Frame timing and event logging |
| `uF` | `userFunctions` | Custom user functions |

### Similar named methods?

In some cases `runExperiment` manages an object with similar named methods. For example `runExperiment.updateTask()` will manage the call to `taskSequence.updateTask()`, this is often so that runExperiment can *co-ordinate* among objects and maintain state (when information needs to be shared between objects). If this is not required then we just call the object methods directly, e.g. `drawBackground(s)` uses `screenManager` to run the PTB Screen() functions to draw a background colour (the property `s.backgroundColour`) to the screen. See `DefaultStateInfo.m` and other CoreProtocols state info files for examples of their use.

### User Functions Files

If you want to write your own functions to be called by the `stateMachine`, then you can add them to a `userFunctions.m` file, [see the docs](uihelpfunctions.html) for details.

---------------------------------------

# Common State Function Patterns

The following table shows the typical function arrays used in each standard state across most CoreProtocols. Use this as a reference when building your own state info files.

### prefix — Pre-trial setup

| Phase | Typical Functions |
|-------|-------------------|
| **Entry** | `needFlip(me,true,N)`, `needEyeSample(me,true)`, `hide(stims)`, `resetAll(eT)`, `updateFixationValues(eT,fixX,fixY,[],fixTime)`, `getStimulusPositions(stims)`, `trackerTrialStart(eT,getTaskIndex(me))`, `trackerMessage(eT,['UUID ' UUID(sM)])` |
| **Within** | `drawPhotoDiodeSquare(s,[0 0 0])` |
| **Transition** | — (time-based, moves to `fixate` after state time) |
| **Exit** | `logRun(me,'INITFIX')`, `trackerMessage(eT,'MSG:Start Fix')` |

### fixate — Fixation acquisition

| Phase | Typical Functions |
|-------|-------------------|
| **Entry** | `show(stims,2)` (show fixation stimulus only) |
| **Within** | `draw(stims)`, `drawPhotoDiodeSquare(s,[0 0 0])` |
| **Transition** | `testSearchHoldFixation(eT,'stimulus','breakfix')` |
| **Exit** | `updateFixationValues(eT,[],[],[],stimFixTime)`, `show(stims)`, `trackerMessage(eT,'END_FIX')` |

### stimulus — Stimulus presentation

| Phase | Typical Functions |
|-------|-------------------|
| **Entry** | `doSyncTime(me)`, `doStrobe(me,true)` |
| **Within** | `draw(stims)`, `drawPhotoDiodeSquare(s,[1 1 1])`, `animate(stims)` |
| **Transition** | `testHoldFixation(eT,'correct','incorrect')` |
| **Exit** | `setStrobeValue(me,255)`, `doStrobe(me,true)` |

### correct — Correct response / reward

| Phase | Typical Functions |
|-------|-------------------|
| **Entry** | `trackerTrialEnd(eT,tS.CORRECT)`, `needEyeSample(me,false)`, `hide(stims)`, `giveReward(rM)`, `beep(aM,tS.correctSound)`, `logRun(me,'CORRECT')` |
| **Within** | `drawPhotoDiodeSquare(s,[0 0 0])` |
| **Exit** | `updatePlot(bR,me)`, `updateTask(me,tS.CORRECT)`, `updateVariables(me)`, `update(stims)`, `getStimulusPositions(stims)`, `resetAll(eT)`, `plot(bR,1)`, `checkTaskEnded(me)` |

### incorrect / breakfix — Error feedback

| Phase | Typical Functions |
|-------|-------------------|
| **Entry** | `trackerTrialEnd(eT,tS.INCORRECT)`, `needEyeSample(me,false)`, `hide(stims)`, `beep(aM,tS.errorSound)`, `logRun(me,'INCORRECT')` |
| **Within** | `drawPhotoDiodeSquare(s,[0 0 0])` |
| **Exit** | If `tS.includeErrors`: `updatePlot(bR,me)`, `updateTask(me,tS.INCORRECT)`, `updateVariables(me)`, `update(stims)`, `resetAll(eT)`, `plot(bR,1)`, `checkTaskEnded(me)`. Otherwise: `resetRun(task)` instead of `updateTask`. |

### pause / calibrate / drift — Utility states

| Phase | Typical Functions |
|-------|-------------------|
| **Entry (pause)** | `hide(stims)`, `drawBackground(s)`, `drawTextNow(s,'PAUSED')`, `setOffline(eT)`, `stopRecording(eT,true)`, `needFlip(me,false,0)`, `needEyeSample(me,false)` |
| **Exit (pause)** | `startRecording(eT,true)` |
| **Entry (calibrate)** | `drawBackground(s)`, `stopRecording(eT)`, `setOffline(eT)`, `trackerSetup(eT)` |
| **Entry (drift)** | `drawBackground(s)`, `stopRecording(eT)`, `setOffline(eT)`, `driftCorrection(eT)` |

---------------------------------------

# List of Methods

We highlight the main classes and methods that are most useful when building your paradigm:

## runExperiment ("me" in the state file)

The principal class object that runs the experiment. It coordinates all other manager objects and maintains the experimental state.

- `enableFlip(me)` || `disableFlip(me)`
	Enable or disable the PTB screen flip during the update loop.

- `needFlip(me, tf, flipType)`
	Set whether the screen flips during the update loop. `tf` is `true`/`false`. `flipType` controls the flip mode: `0` = no flip, `1` = auto-flip, `N` > 1 = flip every Nth frame. Usually called in pause entry (`needFlip(me,false,0)`) and prefix entry (`needFlip(me,true,1)`).

- `needEyeSample(me, value)`
	On each frame we can check the current eye position (called via `getSample(eT)` of the eye tracker object). This method allows us to turn this ON (`true`) or OFF (`false`).

- `needFlipTracker(me, value)`
	Enable or disable the eyetracker display window flip synchronisation. Typically set to `false` during correct/incorrect states where we don't need to update the tracker display.

- `var = getTaskIndex(me)`
	Returns the current trial's variable number by calling `task.outIndex(task.totalRuns)`. A trial variable number is unique to a particular task condition (see the `taskSequence` class which builds these randomised sequences).

- `updateFixationTarget(me, useTask, varargin)`
	To manage several stimuli together, we use the `metaStimulus` class (object name: `stims`). If you set the `metaStimulus.fixationChoice` parameter you can specify from which stimuli to collect the X and Y positions from. `updateFixationTarget(me)` (calling `getFixationPositions(stims)` internally) iterates through each selected stimulus and returns the X and Y positions assigned to `me.lastXPosition` and `me.lastYPosition`. Having these values we can now assign them using `updateFixationValues(eT)`. Optional arguments: `fixInit`, `fixTime`, `radius`, `strict` — if provided these are passed through to `updateFixationValues`.

- `updateExclusionZones(me, useTask, radius)`
	Does the same as `updateFixationTarget` but using `metaStimulus.exclusionChoice` to recover the X and Y positions to set up exclusion zones around specified stimuli. `useTask` controls whether to use task-variable-driven positions.

- `updateConditionalFixationTarget(me, stimulus, variable, value, varargin)`
	Say you have 4 stimuli each with a different angle changed on every trial by the task object, and want the stimulus matching `angle = 90` to be used as the fixation target. This method finds which stimulus is set to a particular variable value and assigns the fixation target X and Y position to that stimulus.

- `updateNextState(me, type)`
	It is possible to force the stateMachine to jump to a transition to a named state by editing `stateMachine.tempNextState`. This method takes the current taskSequence `trialVar` or `blockVar` and sets the next state name to the value contained for the current trial. So for example you can set `trialVar` to `{'stimulus','catch'}` which randomises each trial with either 'stimulus' or 'catch', then use `@()updateNextState(me,'trial')` to choose this value as the temporary next state name.

- `doSyncTime(me)`
	Synchronises the experiment timer with the PTB VBL timestamp. Called at the start of the stimulus state to ensure precise timing of stimulus onset.

- `doStrobe(me, tf)`
	Send or clear a strobe word to the digital I/O hardware. `tf` = `true` sends the current strobe value, `tf` = `false` clears it. Typically called at stimulus entry (`doStrobe(me,true)`) and stimulus exit (`doStrobe(me,true)` with a different value).

- `setStrobeValue(me, value)`
	Sets the strobe code value that will be sent on the next `doStrobe(me,true)` call. For example `setStrobeValue(me,255)` sets the "stimulus off" code. The value sent at stimulus onset is typically the task condition index.

- `logRun(me, message)`
	Logs a message string into the experiment's run log. Common messages: `'INITFIX'`, `'CORRECT'`, `'INCORRECT'`, `'BREAK_FIX'`. These are stored in the `me.runLog` property.

- `updateVariables(me, excludeList, includeList, useTaskFlag)`
	Applies the current trial's task variables to the stimuli. Called after `updateTask()` in the exit function to set up the next trial's stimulus parameters. Optional: `excludeList` and `includeList` to filter which variables are applied, `useTaskFlag` to override whether to use the task sequence.

- `updateTask(me, responseCode)`
	Updates the task sequence with a response code (e.g. `tS.CORRECT`, `tS.INCORRECT`, `tS.BREAKFIX`). This calls `taskSequence.updateTask()` internally, passing the current eyetracker and stimulus info.

- `checkTaskEnded(me)`
	Checks whether the task sequence has completed all blocks. If so, transitions to the `finished` state. Usually called at the end of correct/incorrect/breakfix exit functions when `tS.useTask` is true.

- `keyOverride(me)`
	Enables keyboard override mode where pressing arrow keys can manually transition states. Used in the `override` debug state.

-----------------------------------

## stateMachine ("sM" in the state file)

The state machine controller that manages the current state, timing, and transitions between states.

- `UUID(sM)`
	Returns the unique identifier for this state machine run. Useful for logging: `trackerMessage(eT, ['UUID ' UUID(sM)])`.

- `sM.skipExitStates`
	A cell array of `{fromState, toStatePattern}` pairs. When transitioning from `fromState` to a state matching `toStatePattern`, the exit functions of `fromState` are *skipped*. Commonly set to `{'correct','prefix'; 'incorrect','prefix'; 'breakfix','prefix'}` so that exit functions (which update the task) are not run when the task ends and loops back.

- `sM.tempNextState`
	A temporary override for the next state name. Set by `updateNextState(me,type)` or manually to dynamically choose the next state. For example, in the SaccadePhosphene protocol, `sM.tempNextState` is used in transition functions: `testSearchHoldFixation(eT, sM.tempNextState, 'incorrect')`.

- `sM.currentUUID`
	The UUID of the currently executing state. Can be used for tagging: `addTag(stims{1}, sM.currentUUID)`.

- `sM.verbose`
	Set to `true` to enable verbose logging of state transitions (useful for debugging, typically commented out in production state files).

-----------------------------------

## Task sequence manager ("task" in the state file)

- `updateTask(me, thisResponse, runTime, info)`
	You can update the task by calling this method. `thisResponse` is the response to the trial (correct, incorrect etc. as you've defined), the runTime is the current time, and info is any other information (often the info given by `runExperiment`). In general, it is better to call `runExperiment.updateTask` which generates the `info` for you using the current information from the eyetracker and stimuli.

- `resetRun(task)`
	If the subject fails to respond correctly, this method randomises the next trial within the block, minimising the possibility the subject just guesses. If you are at the last trial of a block then this will not do anything.

- `rewindRun(task)`
	This method rewinds back one trial, allowing you to replay that run again.

- `task.nBlocks`
	The number of repeat blocks. Can be checked in state files: `if tS.useTask || task.nBlocks > 0`.

- `task.totalRuns`
	The current trial index (1-based). Useful in `userFunctions` for reading current conditions.

- `task.outValues`
	A cell array of the actual values for the current trial. Access as `task.outValues{task.totalRuns, variableIndex}`.

- `task.nVar(idx).name` / `task.nVar(idx).values` / `task.nVar(idx).stimulus` / `task.nVar(idx).modifier`
	Access the independent variable definitions. `.name` is the property name (e.g. `'angle'`), `.values` is the array of values, `.stimulus` is the stimulus index(es) it applies to, `.modifier` is an optional modifier string.

- `task.staircase`
	Access to the Palamedes staircase object (if a staircase is configured). Used in `userFunctions` methods like `setDelayTimeWithStaircase()`.

------------------------------------

## The eye tracker ("eT" in the state file)

Opticka provides a unified eye tracker API through `eyetrackerCore` subclasses (`eyelinkManager`, `tobiiManager`, `iRecManager`). All share the same methods. In dummy mode (`eT.isDummy = true`), the mouse position simulates the eye.

### Fixation window management

- `updateFixationValues(eT, X, Y, inittime, fixtime, radius, strict)`
	This method allows us to update the `eT.fixation` structure property; we pass in the various parameters that define the fixation window:
	* `X` = X position in degrees relative to screen centre [0, 0]. `+X` is to the left.
	* `Y` = Y position in degrees relative to screen centre [0, 0]. `+Y` is upwards.
	* `inittime` = How long the subject is allowed to search before their eye enters the window.
	* `fixtime` = How long the subject must keep their eyes within the fixation window.
	* `radius` = if this is a single value, this is the circular radius around `X,Y`. If it is 2 values it defines the width × height of a rectangle around `X,Y`.
	* `strict` = if strict is `true` then do not allow a subject to leave a fixation window once they enter. If `false` then a subject may enter, leave and re-enter without failure (but must still keep the eye inside the window for the required time).

	Note that this command implicitly calls `resetFixation(eT)` as any previous fixation becomes invalid.

- `updateExclusionZones(eT, x, y, radius)`
	Sets up exclusion zones at the given X,Y positions with the given radius. Exclusion zones are areas where the subject must *not* look. If the eye enters an exclusion zone, the `testSearchHoldFixation` or `testHoldFixation` methods will return the fail state.

- `resetFixation(eT, removeHistory)` || `resetFixationHistory(eT)` || `resetFixationTime(eT)` || `resetExclusionZone(eT)` || `resetFixInit(eT)`
	* `resetFixation` resets all fixation counters that track how long a fixation was held for. Pass `removeHistory` == true also calls `resetFixationHistory(eT)` to remove the temporary log of recent eye positions (this is useful for online plotting of the recent eye position for the last trial etc.)
	* `resetFixationTime` only reset the fixation window timers.
	* `resetExclusionZone`: resets (removes) the exclusion zones.
	* `resetFixInit`: *fixInit* is a timer that stops a saccade *away* from a screen position to occur too quickly (default = 100ms). This method removes this test.

- `resetAll(eT)`
	Convenience method that calls `resetFixation(eT,true)`, `resetExclusionZone(eT)`, and `resetFixInit(eT)`. The most commonly used reset — called in prefix entry and correct/incorrect exit functions.

- `resetOffset(eT)`
	Reset the drift offset back to `X = 0; Y = 0` — see `driftOffset(eT)` for the method that sets this value.

### Fixation testing (transition functions)

- `testSearchHoldFixation(eT, successState, failState)`
	Tests whether the subject has acquired and held fixation. Returns `successState` if fixation is held for the required duration, `failState` if the search time expires without fixation, or `''` (empty) if still searching/holding. This is the standard transition function for the `fixate` state.

- `testHoldFixation(eT, successState, failState)`
	Tests whether the subject maintains fixation (assumes fixation was already acquired). Returns `successState` if the subject is still fixating, `failState` if the eye leaves the fixation window, or `''` if still holding. This is the standard transition function for the `stimulus` state.

### Eye sample acquisition

- `getSample(eT)`
	Gets the current X, Y, pupil data from the eyetracker (or if in dummy mode from the mouse position). This is saved in `eT.x`, `eT.y`, `eT.pupil` and logged to `eT.xAll`, `eT.yAll`, `eT.pupilAll`. NORMALLY you do not need to call this as it is called by `runExperiment` for you on every frame, depending on whether `needEyeSample(me)` was set to `true` or `false`.

### Tracker communication

- `trackerMessage(eT, message)`
	Sends a message string to the eye tracker's recording file. Used for logging trial events: `trackerMessage(eT, 'MSG:Start Fix')`. For Eyelink, this writes to the EDF file.

- `trackerTrialStart(eT, index)`
	Informs the tracker that a new trial is starting, with the given trial index. For Eyelink, this starts a new recording segment.

- `trackerTrialEnd(eT, code)`
	Informs the tracker that the trial has ended with the given result code (e.g. `tS.CORRECT`, `tS.INCORRECT`). For Eyelink, this ends the recording segment and logs the result.

- `statusMessage(eT, text)`
	Sends a status message to the tracker display. Similar to `trackerMessage` but may be displayed on the tracker's operator console.

### Tracker display drawing

- `trackerDrawStatus(eT, text, positions, flag, flipFlag)`
	Draws a status message and stimulus position markers on the eyetracker's operator display. `positions` is typically `stims.stimulusPositions`. `flag` controls whether to draw, `flipFlag` controls whether to flip the tracker display.

- `trackerClearScreen(eT)`
	Clears the eyetracker's operator display.

- `trackerDrawText(eT, text)`
	Draws text on the eyetracker's operator display.

- `trackerDrawFixation(eT)`
	Draws a fixation cross or circle on the eyetracker's operator display at the current fixation position.

- `trackerDrawStimuli(eT, positions)` || `trackerDrawStimuli(eT)`
	Draws stimulus position markers on the eyetracker's operator display. If `positions` is provided, draws at those locations; otherwise uses `stims.stimulusPositions`.

- `trackerDrawEyePosition(eT)`
	Draws the current eye position on the eyetracker's operator display. Useful for providing fixation feedback during training.

### Recording control

- `startRecording(eT, alsoCalibration)`
	Starts the eyetracker recording. `alsoCalibration` = `true` also starts the calibration mode recording. Called when exiting the pause state.

- `stopRecording(eT, alsoCalibration)`
	Stops the eyetracker recording. Called when entering the pause or calibrate state.

- `setOffline(eT)`
	Puts the eyetracker into offline mode. Called before calibration, drift correction, or when pausing.

- `trackerSetup(eT)`
	Runs the eyetracker's calibration/setup routine. Called in the calibrate state entry.

- `driftCorrection(eT)`
	Runs the eyetracker's drift correction procedure. Called in the drift state entry.

- `driftOffset(eT)`
	Runs the eyetracker's drift offset procedure. Called in the offset state entry. This corrects for small systematic offsets in the eye position reading.

--------------------------------------

## metaStimulus ("stims" in the state file)

This class manages groups of stimuli as a single object. Each stimulus can be shown or hidden and metaStimulus can also manage masking stimuli if needed.

- `show(stims, [index])`
	Show enables a particular stimulus to be drawn to the screen. Without `[index]` all stimuli are shown. You can specify sets of stimuli, e.g. `show(stims, [2 4])` to show the second and fourth stimuli.

- `hide(stims, [index])`
	The reverse of `show()`. If `index` is empty, hide all stimuli. You can specify sets of stimuli, e.g. `hide(stims, [2 4])` to hide the second and fourth stimuli.

- `showSet(stims, n)`
	`stims.stimulusSets` is an array of 'sets' of stimuli, for example `{3, [1 3], [1 2 3]}` and calling e.g. `showSet(stims, 3)`, would first hide all the stims (`hide(stims)`), then run `show(stims, [1 2 3])`. This just makes it a bit easier to manage pre-specified stimulus sets.

- `edit(stims, stimulus, variable, value)`
	Allows you to modify any parameter of a stimulus during the trial, e.g. `edit(stims, 3, 'sizeOut', 2);` sets the size of stimulus 3 to 2°. Note: use the `*Out` version of the property name for runtime changes.

- `draw(stims)`
	Calls the `draw()` method on each of the managed stimuli. Note if you've used `show()` or `hide()` or `showSet()` then some stimuli may not be displayed. This should be called on every frame update, by setting it to run in the `withinFcn` array.

- `animate(stims)`
	Calls the `animate()` method for each stimulus, which runs any required per-frame updates (for drifting gratings, moving dots, flashing spots etc.). This should be called after `draw()` for every frame update within a `withinFcn` cell array.

- `update(stims)`
	For trial based designs, we may change a variable (like size, or spatial frequency), and `update()` ensures the stimulus recalculates for this new variable. This is usually run in a correct/incorrect `exitFcn` block after first calling `updateVariables(me)`. Note some variables (like phase for gratings) do not require an `update()` but are applied immediately; however this depends on their implementation in PTB. `update` can cost a bit of time depending on the stimulus type, so it is not recommended to call it on every frame, but only when necessary.

- `randomise(stims)`
	Randomises stimulus properties according to `stims.stimulusTable`. This is useful for randomising variables that are *not* task variables, e.g. during training. Call `@()randomise(stims)` before `@()update(stims)` in the exit function.

- `getStimulusPositions(stims, tf)`
	Retrieves the X and Y positions of all stimuli and stores them in `stims.stimulusPositions`. Typically called in prefix entry and correct exit functions. The optional `tf` argument controls whether to include hidden stimuli.

- `getFixationPositions(stims)`
	Returns the X and Y positions from stimuli selected by `stims.fixationChoice`. Called internally by `updateFixationTarget(me)`.

- `getExclusionPositions(stims)`
	Returns the X and Y positions from stimuli selected by `stims.exclusionChoice`. Called internally by `updateExclusionZones(me)`.

- `addTag(stims{N}, tag)`
	Adds a tag string to the stimulus frame log. Example: `addTag(stims{1}, sM.currentUUID)`.

### Accessing individual stimuli

Use cell indexing to access the underlying stimulus objects directly:

```matlab
stims{1}.angleOut    % read the runtime angle of stimulus 1
stims{2}.filePath    % read the image path of stimulus 2
stims{3}.resetTicks  % reset frame counters for stimulus 3
```

### Key properties

| Property | Description |
|----------|-------------|
| `stims.choice` | Which stimulus index to use for randomisation (default: random) |
| `stims.stimulusTable` | Randomisation table for non-task variables |
| `stims.controlTable` | Arrow-key control table for live variable adjustment |
| `stims.tableChoice` | Which control table entry to use |
| `stims.stimulusSets` | Cell array of stimulus index sets for `showSet()` |
| `stims.setChoice` | Default set index for `showSet()` |
| `stims.fixationChoice` | Which stimuli return fixation positions |
| `stims.exclusionChoice` | Which stimuli return exclusion positions |
| `stims.n` | Number of stimuli in the group |

-------------------------------

## Screen Manager ("s" in the state file)

- `drawBackground(s)`
	Draws the `s.backgroundColour` to screen.

- `drawPhotoDiodeSquare(s, colour)`
	Draws a small square in the corner of the screen used by a photodiode to verify stimulus timing. `colour` is RGB, e.g. `[0 0 0]` for off, `[1 1 1]` for on. Typically `[0 0 0]` during fixation/ITI and `[1 1 1]` during stimulus presentation.

- `drawTextNow(s, text)` || `drawText(s, text)`
	Draws text to the screen. `drawTextNow` draws and flips immediately. `drawText` draws to the buffer (requires a subsequent flip). Used in pause/override states to display status messages.

- `drawGrid(s)`
	Draws a 1-degree grid overlay on the screen. Activated by the `showgrid` state.

- `drawScreenCenter(s)`
	Draws a crosshair at the screen centre. Useful for calibration and alignment.

- `flashScreen(s, duration)`
	Flashes the entire screen white for `duration` seconds. Used in the `flash` state for photodiode calibration.

- `drawTimedSpot(s, size, colour, delay, reset)`
	Draws a spot that appears after `delay` seconds. Useful for delayed stimulus onset within a single state. `reset` = `true` resets the timer.

- `finishDrawing(s)`
	Forces a screen flip without the normal frame timing. Used when you need to ensure a draw is visible immediately, e.g. after `drawTimedSpot`.

- `drawMousePosition(s, tf)` || `mousePosition(s, tf)`
	`drawMousePosition` draws the current mouse position as a cursor on screen. `mousePosition` enables or disables mouse position tracking. Used in the RFLocaliser protocol for mouse-driven experiments.

-------------------------------

## IO Manager ("io" in the state file)

The `ioManager` class provides a unified interface for digital I/O hardware (strobe words, TTL pulses). In the default configuration it is a dummy that simply logs values. Real hardware subclasses (`plusplusManager`, `labJack`, `dPixxManager`, `arduinoManager`) provide actual implementations.

- `sendTTL(io, value)`
	Sends a TTL pulse with the given value on the configured output line.

- `sendStrobe(io, value)`
	Immediately sends a strobe word (multi-bit digital code) with the given value. The value is stored in `io.sendValue`.

- `prepareStrobe(io, value)`
	Prepares a strobe value for the next trigger event. Does not send immediately.

- `rstart(io)` || `rstop(io)`
	Start/stop a recording event on the external hardware. For devices like DataPixx that support hardware recording triggers.

- `startFixation(io)` || `correct(io)` || `incorrect(io)` || `breakFixation(io)`
	Sends named event markers to the external hardware. These are convenience methods that send pre-defined strobe codes for common experimental events.

- `pauseRecording(io)` || `resumeRecording(io)`
	Pause/resume an ongoing hardware recording.

- `timedTTL(io, pin, duration)`
	Sends a TTL pulse of `duration` milliseconds on the specified `pin`.

- `io.verbose`
	Set to `true` to enable verbose logging of all I/O operations.

-------------------------------

## Behavioural Record ("bR" in the state file)

The `behaviouralRecord` class creates a live performance plot showing success rates, response times, eye positions, and pupil size.

- `updatePlot(bR, me)`
	Updates the behavioural data from the `runExperiment` object. Reads the state machine for correct/incorrect state names and the eye tracker for fixation timing. Stores response, RT, radius, eye position, pupil data per trial tick.

- `plot(bR, drawNow)`
	Renders all plot axes with current data: response timeline, running success average, stacked bar of hit/miss/break percentages, RT histograms, eye position scatter, pupil trace. `drawNow` (default `true`) calls `drawnow`. Increments the internal tick counter.

- `bR.correctStateName`
	The name of the state considered "correct" (default: `'correct'`). Set this in the state info file: `bR.correctStateName = 'correct'`.

- `bR.breakStateName`
	The name(s) of states considered "break/incorrect" (default: `["breakfix","incorrect"]`). Set this in the state info file: `bR.breakStateName = ["breakfix","incorrect"]`.

- `reset(bR)`
	Resets all trial data (tick, trials, response, rt, radius, time, inittime, xAll, yAll, comment).

-------------------------------

## Audio Manager ("aM" in the state file)

The `audioManager` class manages audio playback via PsychPortAudio. It supports WAV file playback and generated beep tones with click-suppression ramping.

- `beep(aM, freq, durationSec, fVolume)`
	Generates and plays a sine beep tone. `freq` can be a numeric frequency in Hz or one of `'high'` / `'med'` / `'low'`. Defaults: 1000 Hz, 0.15 s, 0.5 volume. Also accepts a vector `[freq, duration, volume]`. Uses cached sound vectors with linear ramp to suppress clicks. Examples:
	* `beep(aM, tS.correctSound)` — play the configured correct sound
	* `beep(aM, tS.errorSound)` — play the configured error sound
	* `beep(aM, [800, 0.2, 0.7])` — 800 Hz for 0.2s at 70% volume

- `play(aM, when)`
	Plays the loaded sample buffer. Optional `when` for scheduled start time.

- `stop(aM)`
	Stops audio playback immediately.

- `volume(aM, value)`
	Sets the playback volume (0–1).

-------------------------------

## Reward Manager ("rM" in the state file)

The `rewardManager` class provides reward delivery. In the default configuration it is a stub. Actual reward delivery is typically handled via the IO manager or a hardware subclass.

- `giveReward(rM)`
	Delivers a reward. In practice, this often calls `timedTTL` on the IO hardware to open a solenoid for the configured reward duration.

- `timedTTL(rM, pin, duration)`
	Sends a TTL pulse of `duration` milliseconds on the specified `pin`. Used for reward solenoid control. Note: in some older protocols, this is called on `lJ` (a LabJack object) instead of `rM`.

-------------------------------

## Time Logger ("tL" in the state file)

The `timeLogger` class logs frame timing (VBL, show, flip, miss, stimTime) and timestamped event annotations with optional HED tags.

- `addMessage(tL, tick, startTime, exitTime, message, timeType, HED)`
	Appends a timestamped message to the event log. Arguments:
	* `tick` — frame tick number
	* `startTime` — event onset time
	* `exitTime` — event offset time
	* `message` — description string
	* `timeType` — timestamp source label
	* `HED` — HED annotation tag (default: `"Experimental-note"`)

- `plot(tL)`
	Plots timing summaries: raw frame times, frame-to-frame deltas, timing offsets, missed frames, and the message log.

- `messageTable(tL)`
	Exports the message log as a sorted MATLAB table with columns: Onset, Exit, Duration, Tick, StimulusOn, Message, TimeType, HED.

-------------------------------

## Touch Manager ("tM" in the state file)

The `touchManager` class manages touch screen input, providing a similar API to the eye tracker for touch-based experiments. It wraps PTB's `TouchQueue*` functions and supports dummy mode (mouse simulation).

### Touch window management

- `updateWindow(tM, X, Y, radius, doNegation, negationBuffer, strict, init, hold, release)`
	Updates touch window parameters. All arguments optional; only provided ones are changed. Supports multiple windows via array inputs. Parameters:
	* `X`, `Y` — window centre in degrees
	* `radius` — window radius in degrees
	* `init` — search/initiation time (seconds)
	* `hold` — required hold duration (seconds)
	* `release` — required release duration (`NaN` = no release required)
	* `strict` — if `true`, cannot leave window once entered
	* `doNegation` — if `true`, touch outside the window fails the trial
	* `negationBuffer` — area around window to check for negation touches

- `resetWindow(tM, N)`
	Resets `N` touch window parameters to defaults. Default N=1.

- `reset(tM, softReset)`
	Resets all touch state data (positions, events, hold tracking). `softReset=true` preserves `lastPressed` and event flags.

### Touch testing (transition functions)

- `[out, held, heldtime, release, releasing, searching, failed, touch, negation] = testHold(tM, yesString, noString)`
	Returns `yesString` if the touch hold duration is met, `noString` if negation/failed/not held and not searching, empty string otherwise. This is the touch equivalent of `testSearchHoldFixation` / `testHoldFixation`.

- `[out, ...] = testHoldRelease(tM, yesString, noString)`
	Like `testHold` but requires `wasHeld && release` for the yes condition. The subject must hold and then release within the window.

### Touch event processing

- `getEvent(tM)`
	Core event processing: reads latest event(s) from the touch queue (or mouse in dummy mode), processes NEW/MOVE/RELEASE types, updates position. Returns the last processed event struct.

- `isTouch(tM, getEvt)`
	Simple check: is a touch active? Optionally calls `getEvent()` first.

- `checkTouchWindows(tM, windows, getEvt)`
	Gets latest event and checks if touch is within defined window(s).

-------------------------------

## Communication (brief reference)

Opticka provides two network communication classes for remote control and telemetry:

### dataConnection (TCP/UDP)

A PNET-based TCP/UDP socket manager. Key methods: `open()`, `close()`, `read()`, `write()`, `readVar()`, `writeVar()`, `checkData()`, `sendCommand()` (supports `ping`, `echo`, `put`, `eval`, `get`, `close` commands). Supports auto-server mode for remote evaluation.

### jzmqConnection (ZeroMQ)

A JeroMQ-based ZeroMQ connection supporting REQ/REP, PUB/SUB, PUSH/PULL socket types with JSON serialisation. Key methods: `open()`, `close()`, `poll()`, `sendCommand()`, `receiveCommand()`, `sendObject()`, `receiveObject()`, `sendViaProxy()`.

-------------------------------

# FAQ

-----------

* **Question:** My subject gave an incorrect answer, but I don't want to keep repeating the same stimulus.
* **Answer:** Use `resetRun(task)` which chooses another run in the same block and swaps it. Note if we are on the last trial of a block, we cannot swap as we want to preserve repeats per block.

------------

* **Question:** I want to randomise some values of the stimuli but not include them as an independent variable.
* **Answer:** The metaStimulus object contains a `stimulusTable` which allows you to make changes to stimuli without them added to the trial structure. This is useful during training, or if you need randomisation tangential to the task. As an example, in Chen et al., 2020 Science their Saccade-to-Phosphene task randomises the size and colour of the target but this is not used as a task variable. In this case set `stimulusTable` and then call `@()randomise(stims);` in the state machine functions (normally just before you call `@()update(stims);`). This will give randomised size and colour without adding any independent variables.

------------

* **Question:** I need the fixation window to move to match a stimulus position that changes on each trial.
* **Answer:** Set `stims.fixationChoice` to the index of the stimulus that serves as the fixation target. Then call `updateFixationTarget(me)` in the prefix entry function. This reads the stimulus position and updates the eyetracker's fixation window automatically.

------------

* **Question:** I want different trial types (e.g. stimulus vs. catch) randomly interleaved.
* **Answer:** Use `task.trialVar` with the state names as values, e.g. `task.trialVar.values = {'stimulus','catch'}`. Then in the transition function for fixate, use `@()updateNextState(me,'trial')` to dynamically set the next state based on the trial variable.

------------

* **Question:** How do I adjust stimulus parameters live during the experiment?
* **Answer:** Use `stims.controlTable` and `stims.tableChoice` to set up arrow-key adjustable variables. Then use the `override` state (available in all state info files) to adjust parameters with arrow keys between trials.

------------

* **Question:** I want to send TTL markers to external recording hardware.
* **Answer:** Use the `io` (ioManager) object. `sendStrobe(io, value)` sends a multi-bit code, `sendTTL(io, value)` sends a single TTL pulse. Call `doStrobe(me, true)` at stimulus onset and `setStrobeValue(me, 255); doStrobe(me, true)` at offset to mark stimulus timing.

------------

* **Question:** How do I run a staircase alongside the task sequence?
* **Answer:** Configure a staircase in the task sequence (requires Palamedes toolbox). Then in your `userFunctions.m`, use `setDelayTimeWithStaircase(me, stim, duration)` to update a stimulus property based on the staircase value. See the Saccadic Countermanding core protocol for an example.

------------

* **Question:** I'm running a touch-screen experiment. How do I replace eye tracker methods?
* **Answer:** Use `touchManager` instead of an eye tracker. The key methods are analogous: `updateWindow(tM, ...)` replaces `updateFixationValues(eT, ...)`, `testHold(tM, ...)` replaces `testSearchHoldFixation(eT, ...)`, and `testHoldRelease(tM, ...)` replaces `testHoldFixation(eT, ...)`.

------------

# Definitions

Class
: A class is a way to combine a set of related variables (properties) and functions (methods) in a unified object. In MATLAB we use `classdef` to build a class.

Object
: A class is a kind of thing, but when we want to use that thing, we *instantiate* it into a 'real' object. So calling `s = screenManager` *instantiates* the `screenManager` class as an object called `s`.

Method
: The name given by MATLAB to a function contained in a class.

Handle class
: A MATLAB class that inherits from `handle`. All instances of a handle class that point to the same object share the same data. If `a = screenManager` and `b = a`, then changing `a.someProperty` also changes `b.someProperty` — they are the *same* object.

Anonymous function
: A function defined inline using `@()`, e.g. `@()draw(stims)`. These are used extensively in state info files because they can be stored in cell arrays and called by the state machine. Note: you cannot directly modify object properties inside anonymous functions — use setter methods instead.

Dynamic property (`*Out`)
: At runtime, each stimulus property (e.g. `size`) gets a dynamic copy (`sizeOut`). The `*Out` version holds the pixel-converted, task-variable-modified value. When using `edit(stims, N, property, value)`, use the `*Out` property name.
