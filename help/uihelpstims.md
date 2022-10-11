# Configuring Stimuli

Opticka uses many different stimulus classes that are collected together using a metaStimulus class. The order of the stimulus in the list defines the z-index at which it is drawn (higher number gets drawn on top of lower number). Stimuli collected into a metaStimulus can then be controlled as a single object. In this code for example:

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
* <kbd>▶︎</kbd> Rull all stimuli in an onscreen window to preview how they will look.
* <kbd>▶︎⚡️</kbd> Benchmark all stimuli. See command window for FPS.



