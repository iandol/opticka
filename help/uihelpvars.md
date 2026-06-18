---
title: Independant Variables in Opticka
---

# Configuring Variables

Opticka uses the taskSequence class to specify one or more variable names and values [`nVar`] that can be randomised using balanced blocked repetition and applied to one or multiple stimuli during a task. The taskSequence class can also specify independent trial level [`trialVar`] and block level [`blockVar`] randomisation values. In addition, you can add a staircase (needs Palamedes toolbox), to run alongside the taskSequence (see the `Saccadic Countermanding` core protocol for an example of using a staircase).

## nVar Structure

Each independent variable (`nVar`) has the following fields:

| Field | Description |
|-------|-------------|
| `.name` | The stimulus property name (e.g. `'angle'`, `'size'`, `'sf'`) |
| `.values` | Array of values for this variable. Can be numeric or cell arrays for complex types. |
| `.stimulus` | [optional] Index (or array of indices) of which stimulus/stimuli to apply this variable to |
| `.modifier` | [optional] modifier string applied to other stimuli (see [Variables](uihelpvars.html)) |

### Value types

Values can be:

- **Numeric arrays**: `[-25 0 25]` — each value is one condition
- **Cell arrays**: `{[1 0 0], [0 1 0]}` — for RGB colours, `{[5 0], [0 5], [-5 0]}` — for `xyPosition` values etc.

`randomiseTask(task)` will generate the randomisation table like so (3 angles × 2 colours per block = **6** conditions; 2 blocks = **12** total trials):

Angle     Colour       Index       IdxAngle     IdxColour    Trial Factor     Block Factor
-----     ------       --------    ---------    ---------    -------------    -------------
-25       1 0  0       1           1            1            'none'           'none'
  0       1 0  0       3           2            1            'none'           'none'
 25       0 1  0       6           3            2            'none'           'none'
 25       1 0  0       5           3            1            'none'           'none'
-25       0 1  0       2           1            2            'none'           'none'
  0       0 1  0       4           2            2            'none'           'none'
-25       0 1  0       2           1            2            'none'           'none'
  0       0 1  0       4           2            2            'none'           'none'
-25       1 0  0       1           1            1            'none'           'none'
 25       0 1  0       6           3            2            'none'           'none'
  0       1 0  0       3           2            1            'none'           'none'
 25       1 0  0       5           3            1            'none'           'none'

Opticka's task function can then use this table to assign variables on each trial to the defined stimuli and generate strobed words to send to external equipment. See core protocols like `OrientationTuning.mat` to get a working example of this in action.

# Block and Trial level independent factors

You can set [Block Values] and [Trial Values] in the UI and assign probabilities. These are assigned independently of any variables. So for example setting trial values: `{'a','b'}` trial probabilities: `{0.3 0.7}` would randomly assign either `a` or `b` in a 30:70 probability to each trial. Block factors have the same assignation, but applies over the blocks. So for example say we have a variable with two values (-10 or +10 degrees) and 5 repeat blocks. The trials are randomised. Separately we assign `{'a','b'}` to trials and `{'x','y'}` to get an experiment table of 5 blocks that may look like this:

 Var 	 Idx 	 TrialV 	 BlockV 
-----	-----	-------		--------
10		2		b			y
-10		1		b			y
10		2		a			x
-10		1		b			x
10		2		a			x
-10		1		b			x
10		2		a			x
-10		1		b			x
10		2		a			y
-10		1		a			y

### Using trial/block factors in state files

Trial and block factors can drive state machine behaviour. For example, to randomly interleave stimulus and catch trials:

```matlab
task.trialVar.values = {'stimulus', 'catch'};
task.trialVar.probability = [0.8 0.2];
```

Then use `@()updateNextState(me, 'trial')` in the transition function to set the next state based on the current trial's factor value.

Trial- and Block-factors can be used to drive state machine functions if you need it (`Saccadic_Doublestep.mat` is an example protocol).

Here is a second example:

```matlab
task.blockVar.values={'A','B'};
task.blockVar.probability = [0.6 0.4];
```

For each block we assign either `A` or `B` with a 60:40% probability. Trial-level factors are specified in the same way, but for each trial independently of the blocks.

```matlab
task.trialVar.values={'Y','Z'};
task.trialVar.probability = [0.5 0.5];
```

Angle     Colour       Index       IdxAngle     IdxColour    Trial Factor     Block Factor
-----     ------       --------    ---------    ---------    -------------    -------------
-25       1 0  0       1           1            1            Z                A
  0       1 0  0       3           2            1            Y                A
 25       0 1  0       6           3            2            Y                A
 25       1 0  0       5           3            1            Y                A
-25       0 1  0       2           1            2            Z                A
  0       0 1  0       4           2            2            Y                A
-25       0 1  0       2           1            2            Y                B
  0       0 1  0       4           2            2            Z                B
-25       1 0  0       1           1            1            Z                B
 25       0 1  0       6           3            2            Y                B
  0       1 0  0       3           2            1            Y                B
 25       1 0  0       5           3            1            Y                B


# Staircase Procedures

Opticka can run a Palamedes staircase alongside the task sequence. This allows you to adaptively vary a stimulus parameter (e.g. contrast threshold) based on the subject's performance. The staircase is configured in the task sequence and accessed via `task.staircase`.

Example usage in a `userFunctions.m`:

```matlab
function setDelayTimeWithStaircase(me, stim, duration)
	% use the staircase to adjust a delay time
	me.stims{stim}.delayTime = duration;
end
```

See the `Saccadic Countermanding` core protocol for a full working example of staircase integration.

# Variable modifiers

Variables can have modifiers, best explained by example:

1. Name = `angle`
2. Values = `[-90 0 90]`
3. Affects = `1`
4. Modifier = `2; 90`

In this case, angle is varied -90° 0° 90° for stimulus 1. Stimulus 2 has the modifier 90 applied, so for example if stimulus 1 = `-90°` then stimulus 2 = `-90° + 90° = 0°`.

Modifiers can also be string commands:

1. `2; 'shift(2)'` - shift +2 places in the Value list. For example say for stimulus 1 `Values = [-90 -45 0 45 90 135 180]` and for this trial the fourth value `45` is randomly selected. For stimulus 2 we then shift two places to fetch the sixth value `135`. Shift wraps from end to start (e.g. if seventh value `180` was selected for stimulus 1 then second value `-45` would be selected for stimulus 2), and you can use negative values (`-1` would select the third place `0` for example).
1. `2; 'invert'` — take the current value and invert it, so if the current value is `+10°` then invert will make stimulus 2 `-10°`.
1. `2; 'xvar(10, 0.5)'` — For `xyPosition` variables you can add a variable x position. In this case whatever the X position is, `xvar(10)` will add or subtract (50% probability) 10°. So for example if X position is `0°` then the modifier could result in `+10°` or `-10°` with a 50% probability. Change `0.5` to change the probability.
1. `2; 'yvar(10, 0.5)'` — Same as `xvar` but for Y axis.
1. `2; 'xoffset(5)'` — For `xyPosition` add a fixed X position offset, so in this case add 5° to whatever value the X axis position is.
1. `2; 'yoffset(5)'` — For `xyPosition` add a fixed Y position offset, so in this case add 5° for stimulus 2 to whatever value the Y axis position is of stimulus 1.

### Modifier summary table

| Modifier | Syntax | Description |
|----------|--------|-------------|
| Numeric offset | `2; 90` | Add a fixed value |
| Shift | `2; 'shift(N)'` | Move N places in the value list (wraps) |
| Invert | `2; 'invert'` | Negate the current value |
| X variable | `2; 'xvar(d, p)'` | Add/subtract `d` on X axis with probability `p` |
| Y variable | `2; 'yvar(d, p)'` | Add/subtract `d` on Y axis with probability `p` |
| X offset | `2; 'xoffset(d)'` | Add fixed `d` on X axis |
| Y offset | `2; 'yoffset(d)'` | Add fixed `d` on Y axis |

# stimulusTable vs. nVar

There are two ways to randomise stimulus properties:

### nVar (task variables)

Used for **independent variables** that define your experimental conditions. These are logged in the task sequence data, contribute to the randomisation table, and each unique combination generates a trial. Use nVar when you need balanced, repeated measures of specific conditions.

### stimulusTable (non-task randomisation)

Used for properties you want to randomise **without** creating task conditions. The randomisation is not logged as a task variable, and does not affect the trial count. This is useful for:

- Training protocols where stimulus properties vary but aren't analysed
- Properties that should vary randomly but are not experimental manipulations
- Reducing predictability without adding experimental conditions

Set `stims.stimulusTable` in the state info file, then call `@()randomise(stims)` in the exit function (before `@()update(stims)`).

Example from Chen et al., 2020 Science — the Saccade-to-Phosphene task randomises target size and colour, but these are not task variables:

```matlab
stims.stimulusTable = { ...
    'sizeOut',  {[1], [2], [3], [4]}; ...
    'colourOut', {[1 0 0 1], [0 1 0 1], [0 0 1 1]} ...
};
stims.choice = 'random';
```

# controlTable (Arrow-Key Adjustment)

The `controlTable` allows live adjustment of stimulus properties using arrow keys during the experiment. This is useful for fine-tuning parameters during testing or training.

```matlab
stims.controlTable = { ...
    'sizeOut',  1,  0.5; ...   % up/down by 0.5 degrees
    'sfOut',    2,  0.1; ...   % up/down by 0.1 c/deg
    'contrastOut', 1, 0.1 ...  % up/down by 0.1
};
stims.tableChoice = 1;  % which stimulus to control
```

The first column is the property name, the second is the stimulus index, and the third is the step size. Use the `override` state (available in all state info files) to enter keyboard control mode.

# stimulusSets

`stimulusSets` defines pre-configured groups of stimuli that can be shown together using `showSet(stims, N)`:

```matlab
stims.stimulusSets = { ...
    2, ...          % set 1: show only stimulus 2 (fixation)
    [1 2], ...      % set 2: show stimuli 1 & 2
    [1 2 3] ...     % set 3: show all stimuli
};
stims.setChoice = 1;  % default set
```

Then in the state file:

```matlab
@()showSet(stims, 2)  % show stimuli 1 & 2
@()showSet(stims, 3)  % show all stimuli
```

This is particularly useful in protocols like DMTS where different stimulus subsets are shown at different phases of the trial.


## Log or Linear interpolation buttons

You can enter 3 values, `start | end | steps`, and press the <kbd>log</kbd> or the <kbd>lin</kbd> buttons to interpolate a log or linear range, for example `1 2 5` would get converted to `1 1.1892 1.4142 1.6818 2` when pressing the <kbd>log</kbd> button.

## Equidistant Points button

This small tool allows you to specify the number of points, distance from center and additional rotation to calculate the correct X and Y positions. For example if you specified 8 points with 12° from the center the tool would calculate `{[12 0], [8.49 8.49], [0 12], [-8.49 8.49], [-12 0], [-8.49 -8.49], [0 -12], [8.49 -8.49]}` for the `xyPosition` values.

This is particularly useful for creating evenly-spaced target positions around a circle, commonly used in saccade and attention paradigms. The rotation parameter allows you to offset the starting angle from 0° (rightward).

# Randomisation Algorithms

The randomisation algorithm is set via the **Random Algorithm** dropdown in the GUI. Available options include:

| Algorithm | Description |
|-----------|-------------|
| `'twister'` | Mersenne Twister (default, recommended) |
| `'simdTwister'` | SIMD-oriented Fast Mersenne Twister |
| `'combRecursive'` | Combined Multiple Recursive |
| `'multCombRecursive'` | Multiplicative Combined Recursive |
| `'v5normal'` | Legacy MATLAB 5.0 normal generator |

The choice of algorithm affects the stream of random numbers used for trial randomisation. For most experiments, the default Mersenne Twister is sufficient.
