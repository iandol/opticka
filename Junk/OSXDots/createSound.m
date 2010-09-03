function [freq beepmatrix] = createSound
% create sound
% adapted from JP's initializeSounds
% MKMK Jul 2006
samplingRate = 22254.545454; 					% same default as SND (from makebeep)
freq = 500;
duration = 0.2;
mybeep = sin(2*pi*freq/samplingRate*(1:round(duration*samplingRate)));
beepmatrix = [mybeep;mybeep];