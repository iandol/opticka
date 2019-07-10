%
%PAL_removeSpaces  Remove superfluous spaces from string
%   
%   syntax: str = PAL_removeSpaces(str)
%
%Internal Function
%
% Introduced: Palamedes version 1.10.0 (NP)

function str = PAL_removeSpaces(str)

str(find(isspace(str(2:end)) == 1 & isspace(str(1:end-1)) == 1)) = [];