function [n,thresholds] = plx_chan_thresholds(filename)
% plx_chan_thresholds(filename): Read channel thresholds from a .plx file
%
% [n,thresholds] = plx_chan_thresholds(filename)
%
% INPUT:
%   filename - if empty string, will use File Open dialog
%
% OUTPUT:
%   thresholds - array of tresholds, expressed in raw A/D counts
%   n - number of channel

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

[n,thresholds] = mexPlex(9, filename);