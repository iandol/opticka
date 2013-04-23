function [n,names] = plx_event_names(filename)
% plx_event_names(filename): Read name for each event type from a .plx file
%
% [n, names] = plx_event_names(filename)
%
% INPUT:
%   filename - if empty string, will use File Open dialog
%
% OUTPUT:
%   names - array of event name strings
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

[n, names] = mexPlex(16, filename);