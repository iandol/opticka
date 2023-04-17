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

These various methods control the logic and flow of experiments. This document lists the most important ones used in flexible behavioural task design. It is better for methods to evaluate properties (properties are the variables managed by the class object). Because of this we choose to create methods that alter the properties of each class. For example, `show(stims)` is a method that allows the stimulus manager to show all stimuli in the list; it does this by setting each stimulus' `isVisible` property to `true`. `hide(stims)` hides all stimuli bby setting `isVisible` property to `false`, or you could just hide the 3rd stimulus in the list: `hide(stims, 3)`.

For those unfamiliar with object-oriented design, a *CLASS* (e.g. `stateMachine`) is initiated as an *OBJECT* variable (named `sM` during the experiment run, it is an *instance* of the class). **ALL** Opticka classes are [**handle classes**](https://www.mathworks.com/help/matlab/handle-classes.html); this means if we assign `sM2 = sM` — **both** of these named instances point to the **same** object. 

As experiments are run **_inside_** the `runExperiment.runTask()` method, this class refers to *itself* as `me`, so methods that *belong* to `runExperiment` can be called by using `me.myMethod()` or `myMethod(me)` (both forms are equivalent to MATLAB). Other important object instances, for example the `screenManager` class is called via `s`, so to call the method `drawSpot` from our `screenManager` instance `s`, we can use `drawSpot(s)` (or `s.drawSpot()`). You will see below the object names that are available as we run the experiment from `runExperiment`. The `runExperiment` object `me` keeps most of the objects as properties: so `s` is actually also stored in the property `me.screen`, `sM` is stored in the property `me.stateMachine` etc.

### Similar named methods?

In some cases `runExperiment` manages an object with similar named methods. For example `runExperiment.updateTask()` will manage the call to `taskSequence.updateTask()`, this is often so that runExperiment can *co-ordinate* among objects and maintain state (when information needs to be shared between objects). If this is not required then we just call the object methods directly, e.g. `drawBackground(s)` uses `screenManager` to run the PTB Screen() functions to draw a background colour (the property `s.backgroundColour`) to the screen. See `DefaultStateInfo.m` and other CoreProtocols state info files for examples of their use…  

### User Functions Files

If you want to write your own functions to be called by the `stateMachine`, then you can add them to a `userFunctions.m` file, [see the docs](uihelpfunctions.html) for details.

---------------------------------------

# List of Methods

We highlight the main classes and methods that are most useful when building your paradigm:  

## runExperiment ("me" in the state file)

The principal class object that 'runs' the experiment.

- `enableFlip(me)` || `disableFlip(me)`  
	Enable or disable the PTB screen flip during the update loop.  

- `needEyeSample(me, value)`  
	On each frame we can check the current eye position (called via `getSample(eT)`of the eye tracker object). This method allows us to turn this ON (`true`) or OFF (`false`).  

- `var = getTaskIndex(me)`  
	It returns the current trial's variable number by calling `task.outIndex(task.totalRuns)`. A trial variable number is unique to a particular task condition (see the `taskSequence` class which builds these randomised sequences).  

- `updateFixationTarget(me, useTask, varargin)` || `updateExclusionZones(me, useTask, radius)`  
	To manage several stimuli together, we use the `metaStimulus` class (object name: `stims`). If you set the `metaStimulus.fixationChoice` parameter you can specify from which stimuli to collect the X and Y positions from. `updateFixationTarget(me)` (calling `getFixationPositions(stims)` internally) iterates through each selected stimulus and returns the X and Y positions assigned to `me.lastXPosition` and `me.lastYPosition`. Having these values we can now assign them using `updateFixationValues(eT)`. `updateExclusionZones()` does the same using `metaStimulus.exclusionChoice` to recover the X and Y positions to set up exclusion zones around specified stimuli.  

- `updateConditionalFixationTarget(me, stimulus, variable, value, varargin)`  
	Say you have 4 stimuli each with a different angle changed on every trial by the task object, and want the stimulus matching `angle = 90` to be used as the fixation target. This method finds which stimulus is set to a particular variable value and assigns the fixation target X and Y position to that stimulus.  

- `updateNextState(me, type)`  
	It is possible to force the stateMachine to jump to a tranisition to a named state by editing stateMachine.tempNextState. This method takes the current taskSequence trialVar or blockVar and sets the next state name to the value contained for the current trial. So for example you can set trialVar to `{'stimulus','catch'}` which randomises each trial with either 'stimulus' or 'catch', then use `@()updateNextState(me,'trial')` to choose this value as the temporary next state name.  

-----------------------------------

## Task sequence manager ("task" in the state file)

- `updateTask(me, thisResponse, runTime, info)`  
	You can update the task by calling this method. `thisResponse` is the response to the trial (correct, incorrect etc. as you've defined), the runTime is the current time, and info is any other information (often the info given by `runExperiment`). In general, it is better to call `runExperiment.updateTask` which generates the `info` for you using the current information from the eyetracker and stimuli.  

- `resetRun(task)`  
	If the subject fails to respond correctly, this method randomises the next trial within the block, minimising the possibility the subject just guesses. If you are at the last trial of a block then this will not do anything.  

- `rewindRun(task)`  
	This method rewinds back one trial, allowing you to replay that run again.  


------------------------------------

## The eye tracker ("eT" in the state file)

- `updateFixationValues(eT, X, Y, inittime, fixtime, radius, strict)`  
	This method allows us to update  the `eT.fixation` structure property; we pass in the various parameters that define the fixation window:
	* `X` = X position in degrees relative to screen centre [0, 0]. `+X` is to the left.
	* `Y` = Y position in degrees relative to screen centre [0, 0]. `+Y` is upwards.
	* `inittime` = How long the subject is allowed to search before their eye enters the window.
	* `fixtime` = How long the subject must keep their eyes within the fixation window.
	* `radius` = if this is a single value, this is the circular radius around `X,Y`. If it is 2 values it defines the width × height of  rectangle around `X,Y`.
	* `strict` = if strict is `true` then do not allow a subject to leave a fixation window once they enter. If `false` then a subject may enter, leave and re-enter without failure (but must still keep the eye inside the window for the required time).

	Note that this command implicitly calls `resetFixation(eT)` as any previous fixation becomes invalid.

- `resetFixation(eT, removeHistory)` || `resetFixationHistory(eT)` || `resetFixationTime(eT)` || `resetExclusionZone(eT)` || `resetFixInit(eT)`  
	* `resetFixation` resets all fixation counters that track how long a fixation was held for. Pass `removeHistory` == true also calls `resetFixationHistory(eT)` to remove the temporary log of recent eye positions (this is useful for online plotting of the recent eye position for the last trial etc.)
	* `resetFixationTime` only reset the fixation window timers.
	* `resetExclusionZone`: resets (removes) the exclusion zones.
	* `resetFixInit`: *fixInit* is a timer that stops a saccade *away* from a screen position to occur too quickly (default = 100ms). This method removes this test.  

- `resetOffset(eT)`  
	Reset the drift offset back to `X = 0; Y = 0` — see `driftOffset(eT)` for the method that sets this value.
- `updateFixationValues(eT,x,y,inittime,fixtime,radius,strict)` || `updateExclusionZones(eT,x,y,radius)`  \
	These methods allows you to change any of the parameters of the fixation window[s] or the exclusion zone[s]. The fixation window[s] can be circular or square, the exclusion zone[a] are square.  

- `getSample(eT)`  \

	This simply gets the current X, Y, pupil data from the eyetracker (or if in dummy mode from the mouse position). This is saved in `eT.x` `eT.y` `eT.pupil` and logged to `eT.xAll` `eT.yAll` `eT.pupilAll`. NORMALLY you do not need to call this is it is called by runExperiment for you on every frame, depending on whether `needEyeSample(me)` method was set to `true` or `false`.

--------------------------------------

## metaStimulus ("stims" in the state file)

This class manages groups of stimuli as a single object. Each stimulus can be shown or hidden and metaStimulus can also managed masking stimuli if needed.

- `show(stims, [index])`  
	Show enables a particular stimulus to be drawn to the screen. Without `[index]` all stimuli are shown. You can specify sets of stimuli, e.g. `show(stims, [2 4])` to show the second and fourth stimuli.

- `hide(stims, [index])`  
	The reverse of `show()`. if `index` is empty, hide all stimuli. You can specify sets of stimuli, e.g. `hide(stims, [2 4])` to hide the second and fourth stimuli.

- `showSet(stims, n)`  
	`stims.stimulusSets` is an array of 'sets' of stimuli, for example `{3, [1 3], [1 2 3]}` and calling e.g. `showSet(stims, 3)`, would first hide all the stims (`hide(stims)`), then run `show(stims, [1 2 3])`. This just makes it a bit easy to manage pre-specified stimulus sets.

- `edit(stims,stimulus,variable,value)`  
	Allows you to modify any parameter of a stimulus during the trial, e.g. `edit(stims,3,'sizeOut',2);` sets the size of stimulus 3 to 2°.

- `draw(stims)`  
	Calls the `draw()` method on each of the managed stimuli. Note if you've used `show()` or `hide()` or `showSet()` then some stmuli may not be displayed. This should be called on every frame update, by setting it to run in the `withinFcn` array.

- `animate(stims)`  
	Calls the `animate()` method for each stimulus, which runs any required per-frame updates (for drifting gratings, moving dots, flashing spots etc.). This should be called after `draw()` for every frame update within a `withinFcn` cell array.

- `update(stims)`  
	For trial based designs, we may change a variable (like size, or spatial frequency), and `update()` ensures the stimulus recalculate for this new variable. This is usually run in a correct/incorrect `exitFcn` block after first calling `updateVariables(me)`. Note some variables (like phase for gratings) do not require an `update()` but are applied immediately; however this depends on their implementation in PTB. `update` can cost a bit of time depending on the stiulus type, so it is not recommended to call it on every frame, but only when necessary.  

-------------------------------

## Screen Manager ("s" in the state file)

- `drawBackground(s)`  
	Draws the s.backgroundColour to screen.

# FAQ

-----------

* **Question:** My subject gave an incorrect answer, but I don't want to keep repeating the same stimulus.
* **Answer:** Use resetRun(task) which chooses another run in the same block and swaps it. Note if we are on the last trial of a block, we cannot swap as we want to preserve repeats per block.

------------

* **Question:** I want to randomise some values of the stimuli but not include them as an indepedant variable.
* **Answer:** The metaStimulus object contains a stimulusTable which allows you to make changes to stimuli without them added to the trial structure. This is useful during training, or if you need randomisation tangential to the task. As an example, in Chen et al., 2020 Science their Saccade-to-Phosphene task randomises the size and colour of the target but this is not used as a task variable. In this case set stimulusTable and then call `@()randomise(stims);` in the state machine functions (normally just before you call `@()update(stims);`). This will give randomised size and colour without adding any independant variables.

------------

# Definitions

Class
: A class is a way to combine a set of related variables (properties) and functions (methods) in a unified object. In MATLAB we use `classdef` to build a class.

Object
: A class is a kind of thing, but when we want to use that thing, we *instantiate* it into a 'real' object. So calling `s = screenManager` *instantiates* the `screenManager` class as an object called `s`.

Method
: The name given by MATLAB to a function contined in a class.
