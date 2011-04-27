%> @mainpage Welcome to Opticka
%> @section intro Introduction
%> @par
%> Opticka is a visual stimulus generator, built as a replacement for VS. It uses the Psychophysics Toolbox, which itself is a wrapper for OpenGL through Matlab. It requires Matlab 2010a at a minimum. 
%> @par
%> There is a feature/bug tracker here (same login/pass as the scratchpad): http://144.82.131.18:3000/projects/opticka/activity 
%> @par
%> And a log of all changes and bugfixes: http://144.82.131.18:3000/projects/opticka/repository
%> @par
%> @section nutsBolts Features?
%> @par
%>  - Object Oriented, allowing stimulus classes to be easily added.
%>  - Individual runs can have variable numbers of segments, allowing fixation/masking type methodology.
%>  - No limit on the number of independent variables, and variables can be linked to multiple stimuli.
%>  - Colour is defined in floating point format, takes advantage of higher bit depths in newer graphics cards when available.
%>  - Sub-pixel precision (1/256th pixel).
%>  - TTL output to data acquisition and other devices. Currently uses LabJack to interface to Omniplex.
%>  - Can talk to other machines on the network during display using TCP/UDP (used to control online display).
%>  - Each stimulus has its own relative X Y position, and the screen center can be arbitrarily moved.
%>  - Number of heterogeneous stimuli displayed simultaneously only limited by the GPU / computer power
%>  - Gratings:
%>    - Per-frame update of properties for arbitrary numbers of grating patches
%>    - Rectangular or circular aperture
%>    - Cosine or hermite interpolation for filtering grating edges 
%>    - Gabors, though note slight differences in what contrast means due to gaussian window.
%>  - Coherent dots, coherence expressed from 0-1. Either square or round dots. Colours can be simple, random, random luminance or binary.
%>  - Bars, either solid colour or random noise texture.
%>  - Flashing/pulsing spots.
%>  - Hand-mapping - including logging of clicked position and later printout of hand maps.