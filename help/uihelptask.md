---
toc: false
---

# Task Parameters

Opticka uses the `taskSequence` class to build the stimulus randomisations required. This class takes a series of stimulus **independent variables** with values and builds a randomisation into blocks. The GUI does this using the <kbd>Ind. Variable List</kbd> editor, but the underlying code looks like this (`nBlocks` is **Task Options > Repeat Blocks** in the GUI):

```matlab
% task sequence with 5 blocks
task = taskSequence('nBlocks', 2);

% first variable: 3 angles that will be applied to stimuli 1 & 2
task.nVar(1).name = 'angle';
task.nVar(1).values = [-25 0 25];
task.nVar(1).stimulus = [1 2];

% second variable: 3 colours that will be applied to stimulus 3
task.nVar(2).name = 'colour';
task.nVar(2).values = {[1 0 0], [0 1 0]};
task.nVar(2).stimulus = 3;

randomiseTask(task);
```

This will generate a randomisation table like so (3 angles x 2 colours per block = **6** conditions; 2 block = **12** total trials):

| angle | colour | index | idx1 | idx2 | blockVar | trialVar |
|-------|--------|-------|------|------|----------|----------|
| 0     | 1 0 0  | 3     | 2    | 1    | none     | none     |
| -25   | 0 1 0  | 2     | 1    | 2    | none     | none     |
| -25   | 1 0 0  | 1     | 1    | 1    | none     | none     |
| 25    | 0 1 0  | 6     | 3    | 2    | none     | none     |
| 0     | 0 1 0  | 4     | 2    | 2    | none     | none     |
| 25    | 1 0 0  | 5     | 3    | 1    | none     | none     |
| 25    | 0 1 0  | 6     | 3    | 2    | none     | none     |
| -25   | 1 0 0  | 1     | 1    | 1    | none     | none     |
| 0     | 1 0 0  | 3     | 2    | 1    | none     | none     |
| 25    | 1 0 0  | 5     | 3    | 1    | none     | none     |
| -25   | 0 1 0  | 2     | 1    | 2    | none     | none     |
| 0     | 0 1 0  | 4     | 2    | 2    | none     | none     |

## Block Level and Trial Level Factors


	
