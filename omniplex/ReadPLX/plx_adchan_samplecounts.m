function [n,samplecounts] = plx_adchan_samplecounts(filename)
% plx_adchan_samplecounts(filename): Read the per-channel sample counts for analog channels from a .plx file
%
% [n,samplecounts] = plx_adchan_samplecounts(filename)
%
% INPUT:
%   filename - if empty string, will use File Open dialog
%
% OUTPUT:
%   n - number of channels
%   samplecounts - array of sample counts

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

[n,samplecounts] = mexPlex(23, filename);