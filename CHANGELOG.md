# Changelog

> [!NOTE]
> Changes which may affect your use of Opticka will be detailed here, starting with V2.16.x

## V2.17.1

### New Features
* **alyxManager** — Major refactor with comprehensive Doxygen-style documentation and MATLAB `arguments()` blocks for all methods. Improved error handling with specific error identifiers and better input validation. Added retry mechanism with exponential backoff for failed operations. New `downloadFiles()` method for retrieving data from S3 buckets.
* **awsManager** — Enhanced with Doxygen-style documentation and `arguments()` blocks. Added retry functionality with exponential backoff for `copyFiles()` operations. Improved reliability with better status reporting and error messages. Added `downloadFiles()` method for S3 downloads with automatic directory creation.
* **jzmqConnection** — Added comprehensive `arguments()` blocks to all methods (except constructor) for better type checking and validation. Improved documentation following Doxygen style guidelines. Enhanced error handling and message logging throughout.
* **DataHash.m** — New utility added for computing cryptographic hashes of MATLAB data structures (534 lines).

### Improvements
* **touchManager** — Significant refactor (585 lines changed) improving touch event handling and integration with physics animations. Better mouse dummy mode support.
* **optickaCore** — Enhanced with improved argument parsing and validation (206 lines changed). Better error handling and logging capabilities.
* **runExperiment** — Refined logging system and experiment flow (250 lines changed). Better integration with Alyx/HED metadata systems.
* **tobiiAnalysis** — Improved data analysis capabilities (213 lines changed) with better integration of Nyström & Holmqvist 2010 cleaning algorithms.
* **metaStimulus** — Code cleanup and improvements (54 lines changed).
* **audioManager** — Enhanced reliability and error handling (69 lines changed).
* **touchData** — Better data handling and validation (91 lines changed).
* **menuN** — UI improvements (22 lines changed).

### Bug Fixes
* **screenManager** — Minor fixes (10 lines changed).
* **imageStimulus** — Bug fixes (4 lines changed).
* **joystickManager** — Minor updates (2 lines).
* **zmqConnection** — Code refinements (55 lines changed).

### Documentation
* All communication classes now follow consistent Doxygen-style documentation
* Added comprehensive inline comments explaining complex operations
* Improved method signatures with MATLAB `arguments()` blocks for better IDE support
* Updated **HEDTagger** documentation (2 lines changed)

### Infrastructure
* Updated `.gitignore` with additional exclusions
* Updated `addOptickaToPath.m` for better path management
* **opticka_ui.mlapp** — UI updates (binary file, 7KB increase)
* Minor updates to core protocols: `PupillaryReflex.m`, `Saccadic_DoubleStep.m`

### Summary
24 files changed, 2240 insertions(+), 1091 deletions(-)  
Major focus on code quality, reliability, and documentation improvements across communication and core infrastructure.

## V2.17.0

* Add support for ØMQ for communication messages (command + serialised MATLAB data packet) across networked PTB instances using the `jzmqConnection` class. This is *much more robust* than raw TCP/UDP used by `pnet` & `dataConnection` and we are using it for communication across [CageLab devices](https://github.com/cogplatform/CageLab). This adds a dependency on <https://github.com/cogplatform/matlab-jzmq>, a MATLAB wrapper for [JeroMQ](https://github.com/zeromq/jeromq). The class explicitly supports a new neuroscience-targetted middleware called [cogmoteGO](https://github.com/Ccccraz/cogmoteGO) with an API designed to manage multiple remote PTB instances and broadcast behavioural data and results back to clients.
* Major update to the opticka UI for Alyx integration. There is an Alyx panel where you can connect to your Alyx instance to retrieve data from the server. Opticka can create a new Alyx session, and will upload the task data as a copy to the Alyx server. The data is sent to an AWS compatible data store linked to the Alyx session. The data is stored in a folder structure that matches the [International Brain Lab ONE Protocol](https://int-brain-lab.github.io/ONE/alf_intro.html) (see "A modular architecture for organizing, processing and sharing neurophysiology data," The International Brain Laboratory et al., 2023 Nat. Methods, [DOI](https://doi.org/10.1038/s41592-022-01742-6)).
* Add **awsManager** to support Alyx's AWS S3 storage. This is used to upload the task data to the AWS compatible data store linked to the Alyx session. This relies on the awscli command line tool to upload the data. You will need to install the AWS CLI and configure it with your AWS credentials. See [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) for more information. We use the cross-platform pixi package manager to install AWS CLI, using `pixi global install awscli` to install it. 
* **HED Tagging** -- we now support HED tagging of the session data. This is used to tag parameters with metadata that can be used for search / analysis. The tags are stored in a TSV file in the same folder as the raw session data. See `tools/HEDTags.m` and `tools/HEDTagger.m`. The HED tags are generated from the task sequence and the task parameters. We want to support better data sharing and Alyx / ONE protocol do not have any task metadata so we chose HED from the EEGLab / BIDS projects. See <https://www.hedtags.org> for details.
* runExperiment -- big improvements to the logging system. Previously task events were stored in several places, but for Alyx / HED we need to centralise the event data. This is used to generate the HED tags and the Alyx session data. 
* Add **joystickManager** — we have built our own HID compatible joystick hardware and this manager interfaces with this hardware.
* labJackT — we now send an 11bit strobed word rather than 8bit word. In theory this is backwards compatible, but you need to update the Lua server code running on the LabJack to use the 11bit word (`t = labJackT; t.initialiseServer`). 0-2047 controls EIO0-8 & CIO0-3.
* Tobii eyetrackers — update Titta interface to support the new adaptive monkey calibration. See Niehorster, D. C., Whitham, W., Lake, B. R., Schapiro, S. J., Andolina, I. M., & Yorzinski, J. L. (2024). Enhancing eye tracking for nonhuman primates and other subjects unable to follow instructions: Adaptive calibration and validation of Tobii eye trackers with the Titta toolbox. Behavior Research Methods, 57(1), 0. https://doi.org/10.3758/s13428-024-02540-y for details.
* **makeReport** — a new method in optickaCore thus available to all opticka objects. Uses the MATLAB report generator to make a PDF report of the data and property values contained in the core opticka classes (runExperiment, taskSequence, stateMachine, behaviouralRecord, tobii/eyelink/irec). Useful when analysing an experiment to get an overview of all experiment parameters for that session.
* **circularMask Shader** — add a simple texture shader that provides a circular mask for any texture stimulus (like an image). This is better than using a separate disc shader. Used in imageStimulus and movieStimulus so you can alpha blend a masked image/movie against a complex background.

## V2.16.1 -- 106 files changed

> [!TIP]
> Please double-check changes in `DefaultStateInfo.m` to see the changes for state machine files, this may inform changes you could add to your own state machine files...


* **BREAKING CHANGE**: we want to support the [International Brain Lab ONE Protocol](https://int-brain-lab.github.io/ONE/alf_intro.html) (see "A modular architecture for organizing, processing and sharing neurophysiology data," The International Brain Laboratory et al., 2023 Nat. Methods, [DOI](https://doi.org/10.1038/s41592-022-01742-6)), and we are now follwoing ALF filenaming for saved files. the root folder is still `OptickaFiles/savedData/` but now we use a folder hierarchy: if the `labName` field is empty we use the shorter  ` / subjectName / YYYY-MM-DD / SessionID-namedetails.mat` otherwise we use `/ labName / subjects / subjectName / YYYY-MM-DD / SessionID-namedetails.mat` -- the opticka `MAT` file will **not** change structure or content (it will remain backwards compatible), but we will add extra metadata files to help data sharing in future releases. We will add an ALYX API call to start a session in a future release.
* **BREAKING CHANGE**: LabJack T4 -- we increased the strobe word from 8 to 11 bits, now on EIO1:8 CIO1:3, this should in theory be backwards compatible as 8bits is still the same lines. Upgrade the LabJack T4 (connected over USB) like this:
```matlab
t = labJackT();
open(t);
initialiseServer(t);
close(t);
```
* Add improved Rigid Body physics engine. We now use [dyn4j](https://dyn4j.org), an open-source Java 2D physics engine. `animationManager` is upgraded (previously it used my own simple physics engine, which couldn't scale to many collisions). Opticka uses degrees, and we do a simple mapping of degrees > meters, so 1deg stimulus is a 1m object.Test it with:  \
```matlab
sM = screenManager();
b = imageStimulus('size',4,'filePath','moon.png',...
    'name','moon');
b.speed = 25; % will define velocity
b.angle = -45; % will define velocity
aM = animationManager(); % our new animation manager
sv = open(sM); % open PTB screen, sv is screen info
setup(b, sM); % initialise stimulus with PTB screen
addScreenBoundaries(aM, sv); % add floor, ceiling and
% walls to rigidbody world based on the screen dimensions sv
addBody(aM, b); % add stimulus as a rigidbody
setup(aM); % initialise the simulation.
for i = 1:60
	draw(b); % draw the stimulus
	flip(sM); % flip the screen
	step(aM); % step the simulation
end
```  
* Improve touchManager to better use the rigid body animations with touch events. You can now finger-drag and "fling" physical objects around the screen.
* add Procedurally generated polar checkerboards: `polarBoardStimulus`, and improved polar gratings to mask with arc segments: `polarGratingStimulus`.
* added new stimulus: `dotlineStimulus` - a line made of dots.
* `pupilCoreStimulus` -- a calibration stimulus for pupil core eyetrackers.
* all stimuli: `updateXY()` method quickly updates the X and Y position without a full stimulus `update()`, used by the update `animationManager`.
* all stimuli: added `szPx` `szD` `xfinalD` and `yFinalD` properties so we have both pixels and degrees values available.
* all stimuli: `szIsPx` property tells us whether the dynamically generated size at each trial is in pixels or degrees.
* add `nirSmartManager` to support nirSmart FNIRS recording system.
* improved the mouse dummy mode for the touchscreen `touchManager`.
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