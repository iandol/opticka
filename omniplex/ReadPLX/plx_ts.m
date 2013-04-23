function [n, ts] = plx_ts(filename, channel, unit)
% plx_ts(filename, channel, unit): Read spike timestamps from a .plx file
%
% [n, ts] = plx_ts(filename, channel, unit)
%
% INPUT:
%   filename - if empty string, will use File Open dialog
%   channel - 1-based channel number
%   unit  - unit number (0- unsorted, 1-4 units a-d)
%
% OUTPUT:
%   n - number of timestamps
%   ts - array of timestamps (in seconds)

if nargin < 3
    error 'Expected 3 input arguments';
end
if (isempty(filename))
   [fname, pathname] = uigetfile('*.plx', 'Select a Plexon .plx file');
   if isequal(fname,0)
     error 'No file was selected'
   end
   filename = fullfile(pathname, fname);
end

[n, ts] = mexPlex(5, filename, channel, unit);