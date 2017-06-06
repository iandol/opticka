# Opticka Stimulus Generator #

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.12293.svg)](https://doi.org/10.5281/zenodo.592253)  

Opticka Stimulus Generator is an object oriented framework with optional GUI for the [Psychophysics toolbox (PTB)](http://psychtoolbox.org/wikka.php?wakka=HomePage), allowing randomised interleaved presentation of complex visual stimuli. It is designed to work on OS X, Windows or Linux, and interfaces via strobed words (using either a DataPixx [15+1bit] or a LabJack [11bit]) and ethernet with a Plexon Omniplex for recording neurophysiological and behavioural data. The communication class can send TTLs and strobed words out to other equipment types. Behavioural control uses the Eyelink eye tracker and a full behavioural repertoire is available by using [State-Machine](http://iandol.github.io/OptickaDocs/classstate_machine.html#details) logic. Opticka uses the TCP interface to the Eyelink affording much better control, reliability and data recording over using analog voltages alone. The various base classes can be used without the need to run the GUI (see [optickatest.m](http://iandol.github.io/OptickaDocs/optickatest.html) for an example), and plug-n-play stimuli provide a unified interface (setup, animate, draw, update, reset) to integrate into existing/other PTB routines. The various object methods take care of all the background geometry and normalization, meaning stimuli are much easier to use than “raw” PTB. Full analysis routines are also present for taking the raw Plexon files (.PLX or .PL2), Eyelink files (.EDF) and behavioural responses and parsing them into a consistent structure, interfacing directly with [Fieldtrip](http://fieldtrip.fcdonders.nl/start) for further spike, LFP, and spike-LFP analysis. The data structures also allow the use of Jonathan Victor's [STA toolkit](http://www.ncbi.nlm.nih.gov/pmc/articles/PMC2818590/), and [nStat toolbox](http://www.neurostat.mit.edu/nstat/) (a pp-GLM modelling approach to analysing neural data). Opticka, because it is object oriented, is far more modular than MonkeyLogic (as well as having much better graphics).

![Opticka Screenshot](https://github.com/iandol/opticka/raw/gh-pages/images/opticka.png)
## Example hardware setup
![Example hardware setup to run Opticka](http://i62.tinypic.com/fxqq12.png)

# Quick Documentation
optickatest.m is a self-documenting minimal toy example showing a mini method of constants (MOC) experiment with 10 different stimuli. Read the Matlab-generated HTML for ``optickatest.m`` here: [optickatest.m Report](http://iandol.github.io/OptickaDocs/optickatest.html).
There is also auto-generated class documentation here: [Opticka Class Docs](http://iandol.github.io/OptickaDocs/inherits.html), however this is only as good as the comments in the code, which as always could be improved...

# Install Instructions
Opticka prefers the latest Psychophysics Toolbox (V3.0.12) and at least Matlab 2010a. It has been tested and is mostly used on 64bit OS X 10.10.x & Matlab 2014b (which is great update BTW). You can simply download the .ZIP from Github, and add the contents/subdirectories to Matlab path. Or if you have git installed, clone this Github repo and add to Matlab path.

Opticka should currently be working both on OS X, Linux and Windows, though the LabJack control of the Omniplex currently only works under OS X and Linux (only a few days work to make it work under windows, if need be, as Labjack uses a different interface on windows and *nix). I'm not really testing under Windows/Linux as much as in OS X. Linux is the preferred OS for PTB according the Mario Kleiner at the moment, but problems with the Eyelink Libraries keep us on OS X for the moment.
## Features
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
* Manages monitor calibration using ColorCalII from CRG or an i1Pro from ViewPixx. Calibration sets can be saved and loaded easily via the GUI.
* Gratings (all using procedural textures for high performance):
   * Per-frame update of properties for arbitrary numbers of grating patches.
   * Rectangular or circular aperture.
   * Cosine or hermite interpolation for filtering grating edges.
   * Square wave gratings, also using a procedural texture, i.e. very fast.
   * Gabors
* Coherent dot stimuli, coherence expressed from 0-1. Either square or round dots. Colours can be simple, random, random luminance or binary. Kill rates allow random replacement rates for dots. Circularly smoothed masked aperture option. Newsroom style dots with motion distributions etc.
* Bars, either solid colour or random noise texture. Bars can be animated, direction can be independent of their angle.
* Flashing/pulsing spots.
* Pictures/Images that can drift and rotate.
* Hand-mapping module - use mouse controlled dynamic bar / texture / colour to handmap receptive fields; includes logging of clicked position and later printout / storage of hand maps. These maps are in screen co-ordinates for quick subsequent stimulus placement.
