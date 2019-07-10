%
%PAL_environment  Returns 'octave' or 'matlab' depending on environment 
%   from which it is called.
%   
%   syntax: environment = PAL_environment
%
%Introduced: Palamedes version 1.10.0 (NP)

function environment = PAL_environment()

if exist('OCTAVE_VERSION', 'builtin')
    environment = 'octave';
else
    environment = 'matlab';
end