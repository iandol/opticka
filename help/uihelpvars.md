# Configuring Variables

Opticka uses the taskSequence class to specify one or more variable names and values [`nVar`] that can be randomised using balanced blocked repetition and applied to one or multiple stimuli during a task. The taskSequence class can also specify independent trial level [`trialVar`] and block level [`blockVar`] randomisation values. In addition, you can add a staircase (needs Palamedes toolbox), to run alongside the taskSequence (see the `Saccadic Countermanding` core protocol for an example of using a staircase).

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
1. `2; 'xoffset(5)'` — For `xyPosition` add a fixed X position offset, so in this case add 5° for stimulus 2 to whatever value the X axis position is of stimulus 1.
1. `2; 'yoffset(5)'` — For `xyPosition` add a fixed Y position offset, so in this case add 5° for stimulus 2 to whatever value the Y axis position is of stimulus 1.

# Block and Trial level independent factors

You can set [Block Values] and [Trial Values] in the UI and assign probabilities. These are assigned independently of any variables. So for example setting trial values: `{'a','b'}` trial probabilities: `{0.3 0.7}` would randomly assign either `a` or `b` in a 30:70 proability to each trial. Block factors have the same assignation, but applies over the blocks. So for example say we have a variable with two values (-10 or +10 degrees) and 5 repeat blocks. The trials are randomised. Separately we assign `{'a','b'}` to trials and `{'x','y'}` to get an experiment table of 5 blocks that may look like thislike this:

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

## Log or Linear interpolation buttons

You can enter 3 values, `start | end | steps`, and press the <kbd>log</kbd> or the <kbd>lin</kbd> buttons to interpolate a log or linear range, for example `1 2 5` would get converted to `1 1.1892 1.4142 1.6818 2` when pressing the <kbd>log</kbd> button.

## Equidistant Points button

This small tool allows you to specify the number of points, distance from center and additional rotation to calculate the correct X and Y positions. For example if you specified 8 points with 12° from the center the tool would calculate `{[12 0], [8.49 8.49], [0 12], [-8.49 8.49], [-12 0], [-8.49 -8.49], [0 -12], [8.49 -8.49]}` for the `xyPosition` values.