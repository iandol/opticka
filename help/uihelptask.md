---
toc: false
---

# Opticka's Two Experiment Modes

1. **Behavioural Task** -- a behavioural task uses a `stateMachine` to construct a series of experiment states and the transitions between them. It uses `StateInfo.m` files and `userFunctions.m` files to specify the states and any customised functions required. It can optionally use `taskSequence`, `metaStimulus`, `eyeTracker`, `IO`, and other manager classes to control stimuli, variables, and hardware interaction.
1. **Method of Constants (MOC) Task** -- a MOC task is a task where no behavioural control is required. It uses `taskSequence` and `metaStimulus` to define a set of stimuli and the variables that will drive unique trials repeated over blocks. 

# Task Parameters

Opticka uses the `taskSequence` class to build the stimulus randomisation. This class takes a series of **independent variables** with values and builds the randomisation into repeated blocks. The GUI does this using the <kbd>Ind. Variable List</kbd> editor, but the underlying code looks like this (`nBlocks` is **Task Options > Repeat Blocks** in the GUI):

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


## Block-Level and Trial-Level Factors

In addition, you can specify independent block and trial factors. For example if we set 

```matlab
task.blockVar.values={'A','B'};
task.blockVar.probability = [0.6 0.4];
```

Then for each block we assign either `A` or `B` with a 60:40% probability. Trial-level factors are specified in the same way, but for each trial independently from the blocks.
	
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

Trial- and Block-factors can be used to drive state machine functions if you need it.