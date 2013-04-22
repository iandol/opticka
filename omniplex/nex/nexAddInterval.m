function [ nexFile ] = nexAddInterval( nexFile, intervalStarts, intervalEnds, name )
% [nexFile] = nexAddInterval( nexFile, intervalStarts, intervalEnds, name ) 
%              -- adds an interval variable (series of intervals) to nexFile data structure
%
% INPUT:
%   nexFile - nex file data structure created in nexCreateFileData
%   intervalStarts - a vector of interval starts in seconds
%   intervalEnds - a vector of interval ends in seconds
%   name - interval variable name

    intervalCount = 0;
    if(isfield(nexFile, 'intervals'))
        intervalCount = size(nexFile.intervals, 1);
    end
    intervalCount = intervalCount+1;
    nexFile.intervals{intervalCount,1}.name = name;
    nexFile.intervals{intervalCount,1}.varVersion = 100;
    if size(intervalStarts,1) == 1
        % if row, transpose to vector
        nexFile.intervals{intervalCount,1}.intStarts = intervalStarts';
    else
        nexFile.intervals{intervalCount,1}.intStarts = intervalStarts;
    end
    if size(intervalEnds,1) == 1
        % if row, transpose to vector
        nexFile.intervals{intervalCount,1}.intEnds = intervalEnds';
    else
        nexFile.intervals{intervalCount,1}.intEnds = intervalEnds;
    end
    % modify end of file timestamp value in file header
    nexFile.tend = max(nexFile.tend, intervalEnds(end));
end
