# Changelog

Note only changes which may affect your use of Opticka will be detailed here, starting with V2.16.x


## V2.16.1 -- 106 files changed

> [!TIP]
> Please check changes in `DefaultStateInfo.m` to see the changes for state machine files, this may inform changes you could add to your own state machine files...

* add Rigid Body physics engine. We use [dyn4j](https://dyn4j.org), an open-source Java 2D physics engine. `animationManager` is upgraded (previously it used my own simple physics engine, which couldn't scale to many collisions). Opticka uses degrees, and we do a simple mapping of degrees > meters, so 1deg stimulus is a 1m object.Test it with:
```matlab
s = screenManager();
b = imageStimulus('size',4,'filePath','moon.png','name','moon');
b.speed = 25; % will define velocity
b.angle = -45; % will define velocity
a = animationManager();
sv = open(s); % open screen
setup(b, s); % initialise stimulus with open screen
addScreenBoundaries(a, sv); % add floor, ceiling and walls based on the screen
addBody(a, b); % add stimulus as a rigidbody to animationManager
setup(a); % initialise the simulation.
for i = 1:60
	draw(b); % draw the stimulus
	flip(s); % flip the screen
	step(a); % step the simulation
end
```
* add Procedurally generated polar checkerboards: `polarBoardStimulus`, and improved polar gratings to mask with arc segments: `polarGratingStimulus`.
* added new stimulus: `dotlineStimulus` - a line made of dots.
* `pupilCoreStimulus` -- a calibration stimulus for pupil core eyetrackers.
* all stimuli: `updateXY()` method quickly updates the X and Y position without a full stimulus `update()`, used by the update `animationManager`.
* all stimuli: added `szPx` `szD` `xfinalD` and `yFinalD` properties so we have both pixels and degrees values available.
* all stimuli: `szIsPx` property tells us whether the dynamically generated size for each trial is in pixels or degrees.
* add `nirSmartManager` to support nirSmart FNIRS recording system.
* improved the mouse dummy mode for the touchscreen `touchManager`.
* LabJack T4 -- we increased the strobe word from 8 to 11 bits, now on EIO1:8 CIO1:3, this should in theory be backwards compatible as 8bits is still the same lines
* `arduinoManager` can now use a raspberry pi GPIO if no arduino is present.
* Update image and movie stimuli to better handle mutliple images.
* Add a `Test Hardware` menu to opticka GUI. You can use this to test that the reward system / eyetracker / recording markers are working before you do any data collection each day.
* Updates to support the latest Titta toolbox for Tobii eyetrackers.
* `optickaCore.geyKeys()` -- support shift key.
* `runExperiment` -- better handling when no eyetracker is selected for a task that may have eyetracker functions.
* `screenManager` -- update movieRecording settings. You pass `screenManager.movieSettings.record = true` to enable screen recording. Note that the movie is handled automatically, so:
```matlab
s = screenManager();
s.movieSettings.record = true;
s.open(); % this also initialises the video file
for i = 1:3
	s.drawText('Hello World);
	s.flip(); % this also adds the frame to the movie
end
s.close(); % this also closes the video file.
```
* lots of improvements for analysing Tobii and iRec data (see `tobiiAnalysis` and `iRecAnalysis`), in particular we integrate [Nyström, M. & Holmqvist, K. 2010](https://github.com/dcnieho/NystromHolmqvist2010) toolbox to improve data cleaning.
* switch to using string arrays for comment property fields.


### State Machine Changes:

* `@()needFlip(me, false, 0);` -- add a 3rd parameter to control the flip of the eyetracker window. NOTE: the number 0=no-flip, 1=dontclear+dontforce, 2=clear+dontforce, 3=clear+force, 4=clear+force first frame then switch to 1 -- dontclear=leave previous frame onscreen, useful to show eyetrack, dontforce=don't force flip, faster as flip for the tracker is throttled
* `@()trackerTrialStart(eT, getTaskIndex(me));` & `@()trackerTrialEnd(eT, tS.CORRECT)` -- this is a new function that handles the several commands that were used previously to send the trial start/end info to the eyetracker. As we increase the number of supported eyetrackers, it is better to wrap this in a single function. NOTE: we mostly use the Eyelink message structure to define trials, even for other trackers, which simplifies analysis later on.