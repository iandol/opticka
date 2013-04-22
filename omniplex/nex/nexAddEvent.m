function [ nexFile ] = nexAddEvent( nexFile, timestamps, name )
% [nexFile] = nexAddEvent( nexFile, timestamps, name ) -- adds an event 
%             (series of timestamps) to nexFile data structure
%
% INPUT:
%   nexFile - nex file data structure created in nexCreateFileData
%   timestamps - vector of event timestamps in seconds
%   name - event name

    eventCount = 0;
    if(isfield(nexFile, 'events'))
        eventCount = size(nexFile.events, 1);
    end
    eventCount = eventCount+1;
    nexFile.events{eventCount,1}.name = name;
    nexFile.events{eventCount,1}.varVersion = 100;
    % timestamps should be a vector
    if size(timestamps,1) == 1
        % if row, transpose to vector
        nexFile.events{eventCount,1}.timestamps = timestamps';
    else
        nexFile.events{eventCount,1}.timestamps = timestamps;
    end
    % modify end of file timestamp value in file header
    nexFile.tend = max(nexFile.tend, timestamps(end));
end
