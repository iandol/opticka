---
title: Opticka Stimuli
---

# Configuring Stimuli

Opticka uses many different stimulus classes that are collected together using a `metaStimulus` class. The order of the stimulus in the list defines the z-index at which it is drawn (higher number gets drawn on top of lower number). Stimuli collected into a `metaStimulus` can then be controlled as a single object. In this code for example:

```matlab
d = dotsStimulus('XPosition', 5, 'mask', true); %coherent dots
f = fixationCrossStimulus('alpha', 0.5); %fixation cross
stims = metaStimulus();
stims{1} = d; 
stims{2} = f;
```

We have two stimuli, and by default `draw(stims)` will draw **both** the coherent dots **and** the fixation cross in one single command. You can then do things like hide/show one or all stimuli:

```matlab
hide(stims); % hide all stims
show(stims, 2); % set the 2nd stimulus (fixationCross) to be shown.
draw(stims); %now only 2nd stimulus will actually be drawn
```

These commands can be run via the [stateInfo file](uihelpstate.html). The GUI allows you to add and order stimuli into this metaStimulus manager.

# Adding & Editing Stimuli

You can start by selecting a stimulus type from the "Stimulus" menu. You should now see a stimulus panel with individual properties on the right. For example `fixationCross` has a `colour` property which defines the disc colour and `colour2` which defines the cross colour. For each stimulus in the list you can edit all these properties. When you are happy with the settings, you <kbd>Add</kbd> it to the stimulus list. The GUI panel on the right updates as you select different stimuli in the stimulus list. You can continue to edit all properties by selecting the stimulus in the list and editing the values.

To move stimuli up or down the list (affecting in what order the stimuli are drawn) use the <kbd>↑</kbd> and <kbd>↓</kbd> icons.

# Previewing Stimuli

* <kbd>▷</kbd> Run a single stimulus in an onscreen window to preview how it will look.
* <kbd>▷⚡️</kbd> Benchmark run a single stimulus. See command window for FPS.
* <kbd>▶︎</kbd> Run all stimuli in an onscreen window to preview how they will look.
* <kbd>▶︎⚡️</kbd> Benchmark all stimuli. See command window for FPS.

# Common Base Properties

All stimulus classes inherit from `baseStimulus`, which provides a shared set of properties. These can all be used as task variables (`nVar` names):

| Property | Default | Description |
|----------|---------|-------------|
| `xPosition` | 0 | X position in visual degrees |
| `yPosition` | 0 | Y position in visual degrees |
| `size` | 4 | Size in visual degrees |
| `colour` | [1 1 1 1] | RGB(A) colour, 0–1 range |
| `alpha` | 1 | Opacity, 0–1 |
| `angle` | 0 | Orientation in degrees (0–360) |
| `speed` | 0 | Speed in degrees/second |
| `startPosition` | 0 | Pre-offset for moving stimuli (degrees) |
| `delayTime` | 0 | Delay before display relative to onset (seconds) |
| `offTime` | Inf | Time to turn off relative to onset (seconds) |
| `isVisible` | true | Whether to draw |

### The `*Out` Dynamic Property System

During `setup()`, each public property (e.g. `size`) is cloned into a transient dynamic property (`sizeOut`). The `*Out` version holds the **runtime**, pixel-converted value. When task variables are applied, they write to the `*Out` properties. On `reset()`, these dynamic properties are removed.

This means:

- In the GUI and state info files, you set `size`, `angle`, etc. — these are the *design-time* values
- At runtime, `sizeOut`, `angleOut`, etc. hold the *actual* values being used (which may differ due to task variable changes)
- When using `edit(stims, N, property, value)` during a task, use the `*Out` version: `edit(stims, 3, 'sizeOut', 2)`

### The `xyPosition` Magic Variable

When defining task variables, you can use the special name `xyPosition` which allows you to pass both X and Y positions in a single variable value. The value should be a cell array of `[x, y]` pairs:

```matlab
task.nVar(1).name = 'xyPosition';
task.nVar(1).values = {[5 0], [0 5], [-5 0], [0 -5]};
task.nVar(1).stimulus = 1;
```

This sets both `xPositionOut` and `yPositionOut` from a single variable. You can also use the [Equidistant Points button](uihelpvars.html) to generate these values automatically.

# Stimulus Types

Opticka provides the following stimulus classes. Each has unique properties beyond the common base properties listed above. Key distinguishing properties are listed for each type.

| Stimulus Class | Type | Description | Key Properties |
|----------------|------|-------------|----------------|
| `gratingStimulus` | sinusoid / square | Drifting sinusoidal or square-wave grating (procedural shader) | `sf`, `tf`, `phase`, `contrast`, `mask`, `sigma` |
| `gaborStimulus` | procedural | Gabor patch with Gaussian envelope (procedural shader) | `sf`, `tf`, `phase`, `contrast`, `spatialConstant` |
| `colourGratingStimulus` | sinusoid / square | Two-colour grating (procedural shader) | `sf`, `tf`, `contrast`, `colour2`, `baseColour`, `visibleRate` |
| `checkerboardStimulus` | checkerboard | Checkerboard pattern (GLSL shader) | `sf`, `tf`, `contrast`, `colour2`, `baseColour` |
| `polarGratingStimulus` | radial / circular / spiral | Polar (radial/circular/spiral) grating | `sf`, `tf`, `contrast`, `colour2`, `spiralFactor`, `arcValue`, `centerMask` |
| `polarBoardStimulus` | checkerboard | Polar checkerboard (procedural shader) | `sf`, `sf2`, `tf`, `contrast`, `arcValue`, `centerMask` |
| `imageStimulus` | picture | Display images (single or directory) | `filePath`, `selection`, `contrast`, `crop`, `circularMask` |
| `movieStimulus` | movie | Play video files (PTB OpenMovie) | `filePath`, `selection`, `loopStrategy`, `mask`, `circularMask` |
| `dotsStimulus` | simple | Variable-coherence random dot kinetogram | `coherence`, `density`, `dotSize`, `colourType`, `kill`, `mask` |
| `ndotsStimulus` | simple | Alternative limited-lifetime coherence dots | `coherence`, `density`, `directionWeights`, `drunkenWalk`, `interleaving` |
| `barStimulus` | solid / checkerboard / random | Drifting bar stimulus (for RF mapping) | `barWidth`, `barHeight`, `contrast`, `sf`, `visibleRate` |
| `spotStimulus` | simple / flash | Simple disc/spot (gluDisk) | `contrast`, `flashColour`, `flashTime` |
| `discStimulus` | simple / flash | Procedural smoothed disc with edge smoothing | `contrast`, `sigma`, `smoothMethod`, `flashTime` |
| `fixationCrossStimulus` | simple / pulse / flash | Fixation cross with optional background disk | `colour2`, `lineWidth`, `showDisk`, `pulseFrequency`, `pulseRange` |
| `dotlineStimulus` | circle / square | Lines made of dots | `itemSize`, `itemDistance`, `phase`, `direction`, `colour2` |
| `logGaborStimulus` | image / logGabor | Log-Gabor filtered noise or image | `sf`, `sfSigma`, `angleSigma`, `seed`, `contrast` |
| `revcorStimulus` | trinary / binary | Reverse correlation (white noise) stimulus | `pixelScale`, `frameTime`, `trialLength` |
| `targetInducerStimulus` | sinusoid / square | Gabor-like target with flanking inducer gratings | `sf`, `tf`, `inducerHeight`, `inducerContrast`, `phaseOffset` |
| `apparentMotionStimulus` | solid / random | Apparent motion stimulus (bar flashes) | `barWidth`, `nBars`, `barSpacing`, `timing`, `direction` |
| `aprilTagStimulus` | aprilTag | Binary checkerboard / AprilTag-style stimulus | `rows`, `columns`, `patternMatrix`, `randomisePattern` |

### Grating Family Properties

The grating stimuli (`gratingStimulus`, `gaborStimulus`, `colourGratingStimulus`, `checkerboardStimulus`, `polarGratingStimulus`, `polarBoardStimulus`) share these common properties:

| Property | Default | Description |
|----------|---------|-------------|
| `sf` | 1 | Spatial frequency (cycles/degree) |
| `tf` | 1 | Temporal frequency (Hz) |
| `phase` | 0 | Grating phase |
| `contrast` | 0.5 | Contrast, 0–1 |
| `direction` | 0 | Object motion direction (degrees) |
| `reverseDirection` / `driftDirection` | false | Reverse drift direction |
| `phaseReverseTime` | 0 | Phase reversal interval (seconds); 0 = no reversal |
| `phaseOfReverse` | 180 | Phase offset for reversal |
| `rotateTexture` | true | Rotate texture vs. patch |
| `correctPhase` | false | Phase relative to centre |

### Dots Stimulus Properties

| Property | Default | Description |
|----------|---------|-------------|
| `coherence` | 0.5 | Motion coherence, 0–1 |
| `density` | 100 | Dots per degree² |
| `dotSize` | 0.05 | Dot width (degrees) |
| `kill` | 0 | Limited-lifetime kill fraction |
| `colourType` | 'randomBW' | Dot colouring mode: `simple`, `random`, `randomN`, `randomBW`, `randomNBW`, `binary` |

# Accessing Individual Stimuli

Use cell indexing on the `metaStimulus` object to access individual stimulus objects directly:

```matlab
stims{1}          % first stimulus object
stims{2}.angleOut % runtime angle of second stimulus
stims{3}.filePath % image path of third stimulus
stims.n           % number of stimuli in the group
```

You can call methods on individual stimuli too:

```matlab
stims{1}.resetTicks()          % reset frame counters
stims{3}.randomiseSelection    % randomise image selection for imageStimulus
```
