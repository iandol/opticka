function [ nexFile ] = nexAddContinuous( nexFile, startTime, adFreq, values, name )
% [nexFile] = nexAddContinuous( nexFile, startTime, adFreq, values, name ) 
%         -- adds continuous variable to nexFile data structure
%
% INPUT:
%   nexFile - nex file data structure created in nexCreateFileData
%   startTime - time of the first data point in seconds
%   adFreq - A/D sampling rate of continuous variable in samples per second
%   values - vector of continuous variable values in milliVolts
%   name - continuous variable name  
% 
    contCount = 0;
    if(isfield(nexFile, 'contvars'))
        contCount = size(nexFile.contvars, 1);
    end
    contCount = contCount+1;
    nexFile.contvars{contCount,1}.name = name;
    nexFile.contvars{contCount,1}.varVersion = 100;
    nexFile.contvars{contCount,1}.ADFrequency = adFreq;
    nexFile.contvars{contCount,1}.timestamps = startTime;
    nexFile.contvars{contCount,1}.fragmentStarts = 1;
    nexFile.contvars{contCount,1}.data = values;
    
    % values should be a vector
    if size(values,1) == 1
        % if row, transpose to vector
        nexFile.contvars{contCount,1}.data = values';
    else
        nexFile.contvars{contCount,1}.data = values;
    end
    
    % modify end of file timestamp value in file header
    nexFile.tend = max(nexFile.tend, startTime+(max(size(values))-1)/adFreq);
end

