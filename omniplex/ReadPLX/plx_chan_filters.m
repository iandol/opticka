function [n,filters] = plx_chan_filters(filename)
% plx_chan_filters(filename): Read channel filter settings for each spike channel from a .plx file
%
% [n,filters] = plx_chan_filters(filename)
%
% INPUT:
%   filename - if empty string, will use File Open dialog
%
% OUTPUT:
%   filter - array of filter values (0 or 1)
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

[n,filters] = mexPlex(10, filename);