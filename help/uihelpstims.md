# Configuring Stimuli

Opticka uses many different stimulus classes that are collected together using the metaStimulus class. The order of the stimulus defines the z-index at which it is drawn (higher number gets drawn on top of lower number). Stimuli collected into a metaStimulus can then be controlled as a single object. In code for example:

```matlab
d = dotsStimulus('XPosition', 5, 'mask', true); %coherent dots
f = fixationCrossStimulus('alpha', 0.5); %fixation cross
stims = metaStimulus();
stims{1} = d; 
stims{2} = f;
```

Now, `stims.draw` will draw both the coherent dots and the fixation cross in one single command, and you can do things like hide/show one or all stimuli:

```matlab
hide(stims); % hide all stims
show(stims, 2); % show the second stimulus only
draw(stims);
```

These commands can be set in state info file. The GUI allows you to add and order stimuli into this metaStimulus manager.

# Stimulus editing

Each stimulus class has a set of properties. You can start by selecting a stimulus class from the "Stimulus" menu. You can now see a stimulus panel in idividual options on the right. For example `fixationCross` has a `colour` property which defines the disc colour and `colour2` which defines the cross colour. When you are happy with the settings, you **_Add_** it to the stimulus list. The GUI panel on the right updates as you select different stimuli in the stimulus list. 

