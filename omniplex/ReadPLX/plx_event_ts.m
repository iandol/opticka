function [n, ts, sv] = plx_event_ts(filename, channel)
% plx_event_ts(filename, channel) Read event timestamps from a .plx file
%
% [n, ts, sv] = plx_event_ts(filename, channel)
%
% INPUT:
%   filename - if empty string, will use File Open dialog
%   channel - 1-based external channel number
%             strobed channel has channel number 257  
%
% OUTPUT:
%   n - number of timestamps
%   ts - array of timestamps (in seconds)
%   sv - array of strobed event values (filled only if channel is 257)

if nargin < 2
    error 'Expected 2 input arguments';
end
if (isempty(filename))
   [fname, pathname] = uigetfile('*.plx', 'Select a Plexon .plx file');
   if isequal(fname,0)
     error 'No file was selected'
   end
   filename = fullfile(pathname, fname);
end

[n, ts, sv] = mexPlex(3, filename, channel);