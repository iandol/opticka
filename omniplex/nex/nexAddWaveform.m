function [ nexFile ] = nexAddWaveform( nexFile, WFreq, timestamps, waveforms, name )
% [nexFile] = nexAddWaveform( nexFile, WFreq, timestamps, waveforms, name )
%             -- adds waveform variable to nexFile data structure
%
% INPUT:
%   nexFile - nex file data structure created in nexCreateFileData
%   startTime - time of the first data point in seconds
%   WFreq - A/D samling rate of waveform variable in samples per second
%   timestamps - vector of wave timestamps (in seconds)
%   waveforms - matrix of waveform variable values in milliVolts
%               each waveform is a column
%   name - waveform variable name  
% 
    
    waveCount = 0;
    if(isfield(nexFile, 'waves'))
        waveCount = size(nexFile.waves, 1);
    end
    waveCount = waveCount+1;
    nexFile.waves{waveCount,1}.name = name;
    nexFile.waves{waveCount,1}.varVersion = 100;
    nexFile.waves{waveCount,1}.WFrequency = WFreq;
    % timestamps should be a vector
    numTimestamps = size(timestamps,1);
    if size(timestamps,1) == 1
        numTimestamps = size(timestamps,2);
        % if row, transpose to vector
        nexFile.waves{waveCount,1}.timestamps = timestamps';
    else
        nexFile.waves{waveCount,1}.timestamps = timestamps;
    end
    if numTimestamps == size(waveforms, 2) 
        nexFile.waves{waveCount,1}.waveforms = waveforms;
    else
        error 'sizes of timestamps and waveforms do not match'
        return
    end
    nexFile.waves{waveCount,1}.NPointsWave = size(waveforms, 1);
    % modify end of file timestamp value in file header
    nexFile.tend = max(nexFile.tend, timestamps(end));
end

