function [n, npw, ts, wave] = plx_waves_v(filename, channel, unit)
% plx_waves_v(filename, channel, unit): Read waveform data from a .plx file
%
% [n, npw, ts, wave] = plx_waves_v(filename, channel, unit)
%
% INPUT:
%   filename - if empty string, will use File Open dialog
%   channel - 1-based channel number
%   unit  - unit number (0- unsorted, 1-4 units a-d)
%
% OUTPUT:
%   n - number of waveforms
%   npw - number of points in each waveform
%   ts - array of timestamps (in seconds) 
%   wave - array of waveforms [npw, n] converted to mV

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

[n, npw, ts, wave] = mexPlex(19, filename, channel, unit);
