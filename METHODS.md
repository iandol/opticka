# Behavioural Task Methods and Parameters [work-in-progress]

The state machine can run cell arrays of anonymous functions/methods as states are entered and exited. These method calls control the logic and flow of experiments. In addition, it is preferable to use methods to evaluate properties as this occurs during the run rather than on load. 

For those unfamiliar with object-oriented design, a *CLASS* (e.g. `stateMachine`) is created as a variable *OBJECT* (named `sM` in this case, it is an *instance* of the class). ALL Opticka classes are **handle classes**; this means if we set `sM2 = sM` — both of these instances point to the same object. Below we list the class name and the object name. As experiments are run **within** the `runExperiment` class `runTask()` method, this object refers to *itself* as `me`, and so methods that belong to `runExperiment` can be called by using `myMethod(me)` (or you can also use `me.myMethod()`, both forms are equivalent). Other object instances are given short names, for example the `screenManager` class is instantiated as `s`, so to call a method from screenManager we use `myOtherMethod(s)`. You will see below the object names that are available as we run the experiment from `runExperiment`.  

In some cases `runExperiment` manages the other classes with similar methods, for example `updateTask(me)` will manage the call to `updateTask(task)`, this is often so that runExperiment can co-ordinate among the objects and maintain some state in runExperiment directly. If this is not required then we just call the methods for each object directly, e.g. `drawBackground(s)`.  

We highlight the main classes and methods that are most useful when building a particular paradigm. See the CoreProtocols state info files for examples of their use.  

---------------------------------------

## runExperiment ("me" in the state file)

### var = getTaskIndex(me)

It returns the current trial variable number by calling `task.outIndex(task.totalRuns)`. A trial variable number is unique to a particular task condition (see the `taskSequence()` class which builds these randomised sequences).

### updateFixationTarget(me, useTask, varargin) / updateExclusionZones(me, useTask, radius)

To manage several stimuli together, we use the `metaStimulus` class (`stims` object name). You can set the `metaStimulus.fixationChoice` parameter (one or more stimuli) to specify which stimuli to collect the X and Y positions from to send to the eyetracker. `updateFixationTarget(me)` (calling `getFixationPositions(stims)` internally) iterates through each selected stimulus and returns the X and Y positions assigned to `me.lastXPosition` and `me.lastYPosition`. Having these values we can now assign them using `updateFixationValues(eT)`. 

`updateExclusionZones()` does the same using `metaStimulus.exclusionChoice` to recover the X and Y positions to set up exclusion zones around specified stimuli.

### needEyeSample(me, value)

On each frame we can check the current eye position (called via `getSample(eT)`). This method allows us to turn this ON (`true`) or OFF (`false`).

### enableFlip(me) / disableFlip(me)

Enable or disable the PTB screen flip.

### updateConditionalFixationTarget(me, stimulus, variable, value, varargin)

Say you have 4 stimuli each with a different angle changed on every trial by the task object, and want the stimulus matching `angle = 90` to be used as the fixation target. This method finds which stimulus is set to which particular variable value and assigns the fixation target to the X and Y position of that stimulus.

-----------------------------------

## Task Manager ("task" in the state file)

### resetRun(task)

If the subject fails to respond correctly, this method randomises the next trial **within** the block, minimising the possibility the subject just guesses. If you are at the last trial of a block then this will not do anything.

------------------------------------

## Eyetracker ("eT" in the state file)

### updateFixationValues(eT, X, Y, inittime, fixtime, radius, strict)

This method allows us to update  the `eT.fixation` structure property; we pass in the various parameters that define the fixation window:

* `X` = X position in degrees relative to screen centre [0, 0]. `+X` is to the left.
* `Y` = Y position in degrees relative to screen centre [0, 0]. `+Y` is upwards.
* `inittime` = How long the subject is allowed to search before their eye enters the window.
* `fixtime` = How long the subject must keep their eyes within the fixation window.
* `radius` = if this is a single value, this is the circular radius around `X,Y`. If it is 2 values it defines the width × height of  rectangle around `X,Y`.
* `strict` = if strict is `true` then do not allow a subject to leave a fixation window once they enter. If `false` then a subject may enter, leave and re-enter without failure (but must still keep the eye inside the window for the required time).

Note that this command implicitly calls `resetFixation(eT)` as any previous fixation becomes invalid.

### resetFixation(eT, removeHistory) / resetFixationTime(eT) / resetFixationHistory(eT) / resetExclusionZone(eT) / resetFixInit(eT)

`resetFixation`: resets all fixation counters that track how long a fixation was held for. Pass `removeHistory` == true also calls `resetFixationHistory(eT)` to remove the local log of previous eye positions (used for plotting to a MATLAB figure on every trial). `resetFixationTime`: only reset the fixation window timers. `resetExclusionZone`: resets (removes) the exclusion zones. `resetFixInit`: fix init is a timer that stops a saccade away from a position to occur too quickly. This reset removes this check.

### resetOffset(eT)

Reset the drift offset back to `X = 0; Y = 0` — see `driftOffset(eT)` for the method that sets this value.


### updateFixationValues(eT,x,y,inittime,fixtime,radius,strict) / updateExclusionZones(eT,x,y,radius)

These methods allows you to change any of the parameters of the fixation window[s] or the exclusion zone[s]. The fixation window[s] can be circular or square, the exclusion zone[a] are square.

### getSample(eT)

This simply gets the current X, Y, pupil data from the eyetracker (or if in dummy mode from the mouse position). This is saved in `eT.x` `eT.y` `eT.pupil` and logged to `eT.xAll` `eT.yAll` `eT.pupilAll`. NORMALLY you do not need to call this is it is called by runExperiment for you on every frame, depending on whether `needEyeSample(me)` method was set to `true` or `false`.


-------------------------------

## Screen Manager ("s" in the state file)

### drawBackground(s)

Draws the s.backgroundColour to screen.

--------------------------------------

## MetaStimulus ("stims" in the state file)

This class manages groups of stimuli as a single object. Each stimulus can be shown or hidden and metaStimulus can also managed masking stimuli if needed.

# show(stims, [index])

Show enables a particular stimulus to be drawn to the screen. Without `[index]` all stimuli are shown. You can specify sets of stimuli, e.g. `show(stims, [2 4])` to show the second and fourth stimuli.

# hide(stims, [index])

The reverse of `show()`.

### showSet(stims, n)

`stims.stimulusSets` is an array of 'sets' of stimuli, for example `{3, [1 3], [1 2 3]}` and calling e.g. `showSet(stims, 3)`, would first hide all the stims (`hide(stims)`), then run `show(stims, [1 2 3])`. This just makes it a bit easy to manage stimulus sets.

### edit(stims,stimulus,variable,value)

Allows you to modify any parameter of a stimulus during the trial, e.g. `edit(stims,3,'sizeOut',2);` sets the size of stimulus 3 to 2°.

### draw(stims)

Calls the `draw()` method on each of the managed stimuli. Not if you've used `show()` or `hide()` or `showSet()` then some stmuli may not be displayed. This should be called on every frame update, by setting it to run in the `withinFcn` array.

### animate(stims)

Calls the `animate()` method for each stimulus, which runs any required per-frame updates (for drifting gratings, moving dots, flashing spots etc.). This should be called after `draw()` for every frame update within a `withinFcn` cell array.

### update(stims)

For trial based designs, we may change a variable (like size, or spatial frequency), and `update()` ensures the stimulus recalculate for this new variable. This is usually run in a correct/incorrect `exitFcn` block after first calling `updateVariables(me)`. Note some variables (like phase for gratings) do not require an `update()` but are applied immediately; however this depends on their implementation in PTB.