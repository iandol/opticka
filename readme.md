Opticka Stimulus Generator			{#mainpage}
==========================
Opticka Stimulus Generator is an object oriented GUI driven framework for the [Psychophysics toolbox (PTB)](http://psychtoolbox.org/wikka.php?wakka=HomePage), allowing randomised interleaved presentation of stimuli. It is designed to work on OS X, Windows (currently no digital I/O) or Linux, and interfaces via strobed words and ethernet with a Plexon Omniplex for recording neurophysiological data.  
The various classes can also be used without the need to run the GUI (see [runtest.m](http://144.82.131.18/optickadocs/runtest.html) for an example), and stimuli provide a unified interface (setup, animate, draw, update, reset) to integrate into standard PTB routines. The various object methods take care of all the background geometry and normalization, meaning stimuli are much easier to use than "raw" PTB.
![screenshot](http://i49.tinypic.com/5yhwcp.png)
Quick Documentation
===================
runtest.m is a self-documenting minimal toy example showing mini experiment with 10 different stimuli. Read the Matlab-generated HTML for runtest.m here: [runtest.m Report](http://144.82.131.18/optickadocs/runtest.html)
There is also auto-generated class documentation here: [Opticka Class Docs](http://144.82.131.18/optickadocs/inherits.html), however this is only as good as the comments in the code, which are far from ideal...

Install Instructions
====================
Opticka prefers the latest Psychophysics Toolbox (V3.0.10) and at least Matlab 2010a. It has been tested and is mostly used on 64bit OS X 10.7.x & Matlab 2012a. You can simply download the .ZIP from Github, and add the contents/subdirectories to Matlab path. Or if you have git installed, clone this Github repo and add to Matlab path.

Opticka should currently be working both on OS X, Linux and Windows, though the LabJack control of the Omniplex currently only works under OS X and Linux (only a few days work to make it work under windows, if need be). I'm not really testing under Windows/Linux as much as in OS X. Linux is the preferred OS for PTB according the Mario Kleiner at the moment, but problems with our Eyelink Libraries keep us on OS X for the moment.
Features
=========
 * Values are always given in eye-relevant co-ordinates (degrees etc.) that are internally calculated based on screen geometry/distance
 * No limit on the number of independent variables, and variables can be linked to multiple stimuli.
 * Number of heterogeneous stimuli displayed simultaneously only limited by the GPU / computer power.
 * Display lists are used, so one can easily change drawing order (i.e. what stimulus draws over other stimuli), by changing its order on the list.
 * Object Oriented, allowing stimulus classes to be easily added and code to autodocument using DOxygen.
 * The set of stimuli and variables can be saved into protocol files, to easily run successive protocols quickly.
 * Fairly comprehensive control of the PTB interface to the drawing hardware, like blending mode, bit depth, windowing, verbosity.
 * Colour is defined in floating point format, takes advantage of higher bit depths in newer graphics cards when available. The buffer can be defined from 8-32bits, use full alpha blending within that space and enable a >8bit output using pseudogrey bitstealing techniques.
 * Sub-pixel precision (1/256th pixel) for movement and positioning.
 * TTL output to data acquisition and other devices. Currently uses LabJack to interface to the Plexon Omniplex using strobed words.
 * Can talk to other machines on the network during display using TCP/UDP (used to control Plexon online display, so one can see PSTHs for each stimulus variable shown in real time).
 * Each stimulus has its own relative X & Y position, and the screen centre can be arbitrarily moved via the GUI.
 * Can record stimuli to video files.
 * Manages monitor calibration using ColorCalII. Calibration sets can be saved and loaded easily via the GUI.
 * Gratings:
       * Per-frame update of properties for arbitrary numbers of grating patches.
       * Rectangular or circular aperture.
       * Cosine or hermite interpolation for filtering grating edges.
       * Square wave gratings
       * Gabors
 * Coherent dot stimuli, coherence expressed from 0-1. Either square or round dots. Colours can be simple, random, random luminance or binary. Kill rates allow random replacement rates for dots. Circular aperture option.
 * Bars, either solid colour or random noise texture. Bars can be animated, direction can be independent of their angle.
 * Flashing/pulsing spots.
 * Pictures/Images that can drift and rotate.
 * Hand-mapping module - use mouse controlled dynamic bar / texture / colour to handmap receptive fields; includes logging of clicked position and later printout / storage of hand maps. These maps are in screen co-ordinates for quick subsequent stimulus placement.