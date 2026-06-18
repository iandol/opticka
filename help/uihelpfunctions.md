---
title: User Functions for State Machine Tasks
---

# Adding User Functions

For behavioural tasks, [state-machine files](uihelpstate.html) specify the experimental states (prefix, correct, incorrect etc.) and functions that run on `enter`/`within`/`transition` and `exit` of *each* state. *Most functions* are specified in the built-in classes like `screenManager`, `taskSequence` etc. 

**_BUT_** a user can add any extra functions and store information using a customised `userFunctions.m` file. You should edit the standard `userFunctions.m` and copy it to a folder with your protocol. This custom class will be loaded during the task, called `uF`, and you can call functions as your experiment runs, and store variables in properties etc.

You use the <kbd>Load Functions File…</kbd> to load this file into your protocol; this will be used when you run your task. You can also use the <kbd>Edit Functions File…</kbd> button to open the file in the MATLAB editor.

## How to Use these Functions?

Let's add a new function:

```matlab
function drawSomething(me)
	% use screenManager (me.s) to draw some text to the PTB screen
	me.s.drawText('Hello from UserFunctions')
end
```

**Remember**: `me` refers to itself, in this case `userFunctions`. So `me.s` refers to the `s` property which is automatically set as a handle to `screenManager` the experiment is running under. From the `runExperiment.runTask()`, the userFunctions object is called `uF`.

Lets say we want to run our new `drawSomething()` function during the `fixate` state (on every frame, so we use `withinFcn`). Find the cell array of functions for this state in the `stateInfo.m` file you are using and add our new function to the cell array. Because these cell arrays contain function handles(`@()`), you will need to insert the function name like so: `@()drawSomething(uF)`:

```matlab
%--------------------fix within
fixFcn = {
	@()drawSomething(uF); % our new custom function from our uF object
	@()draw(stims); %draw our stimuli
	@()animate(stims); % animate stimuli for subsequent draw
};
```

This will now run where the `fixFcn` array is, in this case we can see that is `fixate` > `withinFcn`:

```matlab
stateInfoTmp = {
'name'		'next'		'time'	'entryFcn'		'withinFcn'		'transitionFcn'	'exitFcn';
'fixate'	'incorrect'	10		fixEntryFcn		fixFcn			inFixFcn		fixExitFcn;
}
```

### Using Variables (Properties)

When using `@()` function handles, you cannot change class variables (properties) directly. Instead you can use "setter" functions that set the properties. Examples of these kinds of functions from the core classes are `show(stims, 3)`. To see how we do this with our customised userFunctions, lets add a new property to our custom `userFunctions.m` file:

```matlab
	properties % ADD YOUR OWN VARIABLES HERE
		myToggle = false
	end
```

…and then make a new function to set this property:

```matlab
	% Add your functions here!

	function doToggle(me,value)
		me.myToggle = value;
	end
```

You can now add this function in your state file: `@()doToggle(uF, true)` or `@()doToggle(uF, false)`.

This should allow you to add many custom functions, and store information in variables without needing to edit any of the core opticka classes. If you think you need something more advanced then you can open an issue on github to add functions to the core classes or add a new dedicated class.

**IMPORTANT**: please don't store important experimental data in the object itself, as although `uF` will be saved into a MAT file, the current userFunctions.m may not be present when loading on a different machine. You can use the structure `tS` or use your own save data function / file.

# Available Object Handles

The `userFunctions` class automatically receives handles to all the core experiment objects. These are accessible as properties of `me` (the userFunctions instance):

| Property | Object | Description |
|----------|--------|-------------|
| `me.s` | `screenManager` | PTB screen management |
| `me.sM` | `stateMachine` | State machine controller |
| `me.task` | `taskSequence` | Trial randomisation |
| `me.stims` | `metaStimulus` | Stimulus group |
| `me.eT` | `eyetrackerCore` | Eye tracker |
| `me.io` | `ioManager` | Digital I/O |
| `me.rM` | `rewardManager` | Reward delivery |
| `me.bR` | `behaviouralRecord` | Performance plot |
| `me.aM` | `audioManager` | Audio playback |
| `me.tL` | `timeLogger` | Timing logger |

# Advanced Patterns

## Reading Task Variables

You can read the current trial's task variable values from within userFunctions:

```matlab
function logCurrentTrial(me)
	% get the current trial index
	idx = me.task.totalRuns;
	% read the actual values for this trial
	angle = me.task.outValues{idx, 1};
	% log to the time logger
	me.tL.addMessage([], [], [], sprintf('Angle: %.1f', angle));
end
```

Call this in a state entry function: `@()logCurrentTrial(uF)`.

## Modifying Stimuli at Runtime

You can directly access individual stimulus properties via cell indexing:

```matlab
function updateStimulusColour(me, stimIdx, newColour)
	% change the runtime colour of a specific stimulus
	me.stims{stimIdx}.colourOut = newColour;
end
```

Or use the `edit` method on `metaStimulus`:

```matlab
function changeFixationSize(me, newSize)
	edit(me.stims, 2, 'sizeOut', newSize);  % change stimulus 2's size
end
```

## Staircase Integration

The base `userFunctions` class includes built-in methods for working with Palamedes staircases:

- `setDelayTimeWithStaircase(me, stim, duration)` — Updates a stimulus's `delayTime` based on staircase output
- `resetDelayTime(me, stim, value)` — Resets the delay time to a fixed value

Example usage in a state file:

```matlab
% In the correct exit function, update the staircase
if ~isempty(task.staircase)
    @()setDelayTimeWithStaircase(uF, 1, stims{1}.delayTime)
end
```

## Time Logger Integration

You can log custom events with optional HED (Hierarchical Event Descriptors) tags:

```matlab
function logCustomEvent(me, eventName)
	me.tL.addMessage([], [], [], eventName, '', 'Experimental-note');
end
```

Call in state functions: `@()logCustomEvent(uF, 'stimulus_onset')`.

## Subclassing userFunctions

For complex protocols, you can create a subclass of `userFunctions` with a different class name. The DMTS (Delayed Match-to-Sample) protocol demonstrates this pattern with `DMTSFunctions.m`:

```matlab
classdef DMTSFunctions < userFunctions
	properties
		matchIndex = 0
		sampleIdx = 0
	end
	
	methods
		function obj = DMTSFunctions(varargin)
			obj = obj@userFunctions(varargin{:});
		end
		
		function updateStimuliImages(me)
			% custom logic to update stimulus images
			% ...
		end
		
		function updateLocations(me)
			% custom logic to update stimulus positions
			% ...
		end
		
		function updateDelayTime(me)
			% custom logic to set delay duration
			% ...
		end
	end
end
```

Then in the state info file, call these methods: `@()updateStimuliImages(uF)`, `@()updateLocations(uF)`, `@()updateDelayTime(uF)`.

**Note**: When subclassing, the class name must remain `userFunctions` OR you must ensure `runExperiment` loads your custom class. The DMTS protocol achieves this by placing `DMTSFunctions.m` alongside the protocol files.
