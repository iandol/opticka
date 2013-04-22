function [ nexFile ] = nexAddNeuron( nexFile, timestamps, name )
% [nexFile] = nexAddNeuron( nexFile, timestamps, name ) -- adds a neuron 
%             to nexFile data structure
%
% INPUT:
%   nexFile - nex file data structure created in nexCreateFileData
%   timestamps - vector of neuron timestamps in seconds
%   name - neuron name
%
    neuronCount = 0;
    if(isfield(nexFile, 'neurons'))
        neuronCount = size(nexFile.neurons, 1);
    end
    neuronCount = neuronCount+1;
    nexFile.neurons{neuronCount,1}.name = name;
    nexFile.neurons{neuronCount,1}.varVersion = 100;
    nexFile.neurons{neuronCount,1}.wireNumber = 0;
    nexFile.neurons{neuronCount,1}.unitNumber = 0;
    nexFile.neurons{neuronCount,1}.xPos = 0;
    nexFile.neurons{neuronCount,1}.yPos = 0;
    % timestamps should be a vector
    if size(timestamps,1) == 1
        % if row, transpose to vector
        nexFile.neurons{neuronCount,1}.timestamps = timestamps';
    else
         nexFile.neurons{neuronCount,1}.timestamps = timestamps;
    end
    % modify end of file timestamp value in file header
    nexFile.tend = max(nexFile.tend, timestamps(end));
end
