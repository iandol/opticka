function [ nexFile ] = nexCreateFileData( timestampFrequency )
% [nexFile] = nexCreateFileData(timestampFrequency) -- creates empty nex file data structure
%
% INPUT:
%   timestampFrequency - timestamp frequency in Hertz
%
    nexFile.version = 100;
    nexFile.comment = '';
    nexFile.freq = timestampFrequency;
    nexFile.tbeg = 0;
    % fake end time of 1 time tick. tend will be modified by nexAdd* functions
    nexFile.tend = 1/timestampFrequency; 
end

