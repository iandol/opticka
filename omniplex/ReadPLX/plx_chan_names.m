function [n,names] = plx_chan_names(filename)
% plx_chan_names(filename): Read name for each spike channel from a .plx file
%
% [n,names] = plx_chan_names(filename)
%
% INPUT:
%   filename - if empty string, will use File Open dialog
%
% OUTPUT:
%   names - array of channel name strings
%   n - number of channels

if nargin < 1
    error 'Expected 1 input argument';
end
if (isempty(filename))
   [fname, pathname] = uigetfile('*.plx', 'Select a Plexon .plx file');
   if isequal(fname,0)
     error 'No file was selected'
   end
   filename = fullfile(pathname, fname);
end

[n,names] = mexPlex(14, filename);