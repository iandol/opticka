Opticka Stimulus Generator {#mainpage} [![DOI](https://zenodo.org/badge/4521/iandol/opticka.png)](http://dx.doi.org/10.5281/zenodo.11080)
==========================
Opticka Stimulus Generator is an object oriented framework with optional GUI for the [Psychophysics toolbox (PTB)](http://psychtoolbox.org/wikka.php?wakka=HomePage), allowing randomised interleaved presentation of complex stimuli. It is designed to work on OS X, Windows (currently no digital I/O) or Linux, and interfaces via strobed words (using either a DataPixx [15bit] or a LabJack [11bit]) and ethernet with a Plexon Omniplex for recording neurophysiological data. It shouldn't be difficult to send TTLs and strobed words out to other equipment types.
Behavioural control uses the Eyelink eye tracker and a full behavioural repertoire is available by using a [state-machine](http://144.82.131.18/optickadocs/classstate_machine.html#details) logic. Opticka uses the ethernet interface to the Eyelink thus affording much better control and reliability over using the analog voltages alone. The various classes can be used without the need to run the GUI (see [optickatest.m](http://144.82.131.18/optickadocs/optickatest.html) for an example), and stimuli provide a unified interface (setup, animate, draw, update, reset) to integrate into standard PTB routines. The various object methods take care of all the background geometry and normalization, meaning stimuli are much easier to use than "raw" PTB.  Analysis routines are also present for taking the raw Plexon files (.PLX or .PL2) and Eyelink files (.EDF) and parsing them into a consistent trials and variable structure, then interfacing directly with [Fieldtrip](http://fieldtrip.fcdonders.nl/start) for further spike and LFP analysis.  

![Opticka Screenshot](http://i41.tinypic.com/qrdik1.png)

Quick Documentation
===================
optickatest.m is a self-documenting minimal toy example showing a mini experiment with 10 different stimuli. Read the Matlab-generated HTML for ``optickatest.m`` here: [optickatest.m Report](http://144.82.131.18/optickadocs/optickatest.html).
There is also auto-generated class documentation here: [Opticka Class Docs](http://144.82.131.18/optickadocs/inherits.html), however this is only as good as the comments in the code, which as always could be improved...

Install Instructions
====================
Opticka prefers the latest Psychophysics Toolbox (V3.0.12) and at least Matlab 2010a. It has been tested and is mostly used on 64bit OS X 10.8.x & Matlab 2013a. You can simply download the .ZIP from Github, and add the contents/subdirectories to Matlab path. Or if you have git installed, clone this Github repo and add to Matlab path.

Opticka should currently be working both on OS X, Linux and Windows, though the LabJack control of the Omniplex currently only works under OS X and Linux (only a few days work to make it work under windows, if need be). I'm not really testing under Windows/Linux as much as in OS X. Linux is the preferred OS for PTB according the Mario Kleiner at the moment, but problems with our Eyelink Libraries keep us on OS X for the moment.
Features
=========
 * Values are always given in eye-relevant co-ordinates (degrees etc.) that are internally calculated based on screen geometry/distance
 * No limit on the number of independent variables, and variables can be linked to multiple stimuli.
 * A state machine logic can run behavioural tasks driven by for e.g. eye position or behavioural response.
 * Number of heterogeneous stimuli displayed simultaneously only limited by the GPU / computer power.
 * Display lists are used, so one can easily change drawing order (i.e. what stimulus draws over other stimuli), by changing its order on the list.
 * Object Oriented, allowing stimulus classes to be easily added and code to autodocument using DOxygen.
 * The set of stimuli and variables can be saved into protocol files, to easily run successive protocols quickly.
 * Fairly comprehensive control of the PTB interface to the drawing hardware, like blending mode, bit depth, windowing, verbosity.
 * Colour is defined in floating point format, takes advantage of higher bit depths in newer graphics cards when available. The buffer can be defined from 8-32bits, use full alpha blending within that space and enable a >8bit output using pseudogrey bitstealing techniques.
 * Sub-pixel precision (1/256th pixel) for movement and positioning.
 * TTL output to data acquisition and other devices. Currently uses DataPixx or LabJack to interface to the Plexon Omniplex using strobed words.
 * Can talk to other machines on the network during display using TCP/UDP (used to control a Plexon online display, so one can see PSTHs for each stimulus variable shown in real time).
 * Each stimulus has its own relative X & Y position, and the screen centre can be arbitrarily moved via the GUI. This allows quick setup over particular parts of visual space, i.e. relative to a receptive field without needing to edit lots of other values.
 * Can record stimuli to video files.
 * Manages monitor calibration using ColorCalII or i1Pro from ViewPixx. Calibration sets can be saved and loaded easily via the GUI.
 * Gratings:
       * Per-frame update of properties for arbitrary numbers of grating patches.
       * Rectangular or circular aperture.
       * Cosine or hermite interpolation for filtering grating edges.
       * Square wave gratings
       * Gabors
 * Coherent dot stimuli, coherence expressed from 0-1. Either square or round dots. Colours can be simple, random, random luminance or binary. Kill rates allow random replacement rates for dots. Circularly smoothed masked aperture option.
 * Bars, either solid colour or random noise texture. Bars can be animated, direction can be independent of their angle.
 * Flashing/pulsing spots.
 * Pictures/Images that can drift and rotate.
 * Hand-mapping module - use mouse controlled dynamic bar / texture / colour to handmap receptive fields; includes logging of clicked position and later printout / storage of hand maps. These maps are in screen co-ordinates for quick subsequent stimulus placement.