function [n,gains] = plx_adchan_gains(filename)
% plx_adchan_gains(filename): Read analog channel gains from .plx file
%
% [n,gains] = plx_adchan_gains(filename)
%
% INPUT:
%   filename - if empty string, will use File Open dialog
%
% OUTPUT:
%  gains - array of total gains
%  n - number of channels

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

[n,gains] = mexPlex(11, filename);