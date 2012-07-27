%> @mainpage Welcome to Opticka
%> @section intro Introduction
%> @par
%> Opticka is an object oriented framework/GUI for the Psychophysics toolbox, allowing randomised interleaved presentation of parameter varying stimuli specified in experimenter-relevant values. It is designed to work on OS X, Windows (currently no digital I/O) or Linux, and can interface via strobed words (using a cheap and very reliable LabJack) and ethernet with external harware for recording neurophysiological data.
%> @par
%> A public mirror on Github: https://github.com/iandol/opticka
%> @par
%> An example of a minimal experiment / testcase: http://144.82.131.18/optickadocs/runtest.html
%> @par
%> And a log of all changes and bugfixes: https://github.com/iandol/opticka/commits/master
%> @par
%> @section nutsBolts Features?
%> @par
%> <ul>
%> <li>❦ Values are always given in eye-relevant co-ordinates (degrees etc.) that are internally calculated based on screeen geometry/distance</li>
%> <li>❦ No limit on the number of independent variables, and variables can be linked to multiple stimuli.</li>
%> <li>❦ Number of heterogeneous stimuli displayed simultaneously only limited by the GPU / computer power.</li>
%> <li>❦ Display lists are used, so one can easily change drawing order (i.e. what stimulus draws over other stimuli), by changing its order on the list.</li>
%> <li>❦ Object Oriented, allowing stimulus classes to be easily added and code to autodocument using DOxygen.</li>
%> <li>❦ The set of stimuli and variables can be saved into protocol files, to easily run successive protocols quickly.</li>
%> <li>❦ Fairly comprehensive control of the PTB interface to the drawing hardware, like blending mode, bit depth, windowing, verbosity.</li>
%> <li>❦ Colour is defined in floating point format, takes advantage of higher bit depths in newer graphics cards when available. The buffer can be defined from 8-32bits, use full alpha blending within that space and enable a greater than 8bit output using pseudogrey bitstealing techniques.</li>
%> <li>❦ Sub-pixel precision (1/256th pixel) for movement and positioning.</li>
%> <li>❦ TTL output to data acquisition and other devices. Currently uses LabJack to interface to the Plexon Omniplex using strobed words.</li>
%> <li>❦ Can talk to other machines on the network during display using TCP/UDP (used to control Plexon online display, so one can see PSTHs for each stimulus variable shown in real time).</li>
%> <li>❦ Each stimulus has its own relative X & Y position, and the screen centre can be arbitrarily moved via the GUI.</li>
%> <li>❦ Can record stimuli to video files.</li>
%> <li>❦ Manages monitor calibration using ColorCalII. Calibration sets can be saved and loaded easily via the GUI.</li>
%> <li>❦ Gratings:</li>
%> <li>      • Per-frame update of properties for arbitrary numbers of grating patches.</li>
%> <li>      • Rectangular or circular aperture.</li>
%> <li>      • Cosine or hermite interpolation for filtering grating edges.</li>
%> <li>      • Square wave gratings</li>
%> <li>      • Gabors</li>
%> <li>❦ Coherent dot stimuli, coherence expressed from 0-1. Either square or round dots. Colours can be simple, random, random luminance or binary. Kill rates allow random replacement rates for dots. Circular aperture option.</li>
%> <li>❦ Bars, either solid colour or random noise texture. Bars can be animated, direction can be independent of their angle.</li>
%> <li>❦ Flashing/pulsing spots.</li>
%> <li>❦ Pictures/Images that can drift and rotate.</li>
%> <li>❦ Hand-mapping module - use mouse controlled dynamic bar / texture / colour to handmap receptive fields; includes logging of clicked position and later printout / storage of hand maps. These maps are in screen co-ordinates for quick subsequent stimulus placement.</li>
%> </ul>