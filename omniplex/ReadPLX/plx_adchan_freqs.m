function [n,freqs] = plx_adchan_freqs(filename)
% plx_adchan_freq(filename): Read the per-channel frequencies for analog channels from a .plx file
%
% [n,freqs] = plx_adchan_freq(filename)
%
% INPUT:
%   filename - if empty string, will use File Open dialog
%
% OUTPUT:
%   freqs - array of frequencies
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

[n,freqs] = mexPlex(12, filename);