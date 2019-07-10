%
%PAL_contains  Emulates (some) functionality of Matlab's 'contains'
%   function
%
%   For compatibility with Octave
%
%   syntax: [patternFound] = PAL_contains(str, pattern)
%
%   PAL_contains returns logical true if string 'pattern' is contained in 
%       string 'str' or logical false otherwise.
%
% Introduced: Palamedes version 1.10.0 (NP)

function [patternFound] = PAL_contains(str,pattern)

patternFound = ~isempty(strfind(str,pattern));

end