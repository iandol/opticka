# Configuring Variables

Opticka uses the taskSequence class to specify one or variable names and values that can be applied to stimuli. The taskSequence class can also specify independent trial level [`trialVar`] and block level [`blockVar`] randomisation values. 

## Variable modifiers

Variables can have modifiers, best explained by example:

1. Name = `angle`
2. Values = `[-90 90]`
3. Affects = `1`
4. Modifier = `2; 90`

In this case, angle is varied -90 and 90 for stimulus 1. Stimulus 2 has the modifier +90 applied, so for example is stimulus 1 = `-90°` then stimulus 2 = `-90° + 90 = 0°`.

