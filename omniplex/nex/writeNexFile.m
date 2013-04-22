function [result] = writeNexFile(nexFile, fileName)
% [result] = writeNexFile(nexFile, fileName) -- write nexFile structure
% to the specified .nex file. returns 1 if succeeded, 0 if failed.
% 
% INPUT:
%   nexFile - a structure containing .nex file data
%
%           SOME FIELDS OF THIS STRUCTURE (VERSIONS ETC.) ARE NOT DESCRIBED
%           BELOW. IT IS RECOMMENDED THAT YOU READ A VALID .NEX FILE 
%           TO FILL THIS STRUCTURE, THEN MODIFY THE STRUCTURE AND SAVE IT.
%
%           IF YOU WANT TO CREATE NEW .NEX FILE, USE nexCreateFileData.m,
%           nexAddContinuous.m etc. See exampleSaveDataInNexFile.m.
%           
%   fileName - if empty string, will use File Save dialog
%
%   nexFile - a structure containing .nex file data
%   nexFile.version - file version
%   nexFile.comment - file comment
%   nexFile.tbeg - beginning of recording session (in seconds)
%   nexFile.tend - end of recording session (in seconds)
%
%   nexFile.neurons - array of neuron structures
%           neurons{i}.name - name of a neuron variable
%           neurons{i}.timestamps - array of neuron timestamps (in seconds)
%               to access timestamps for neuron 2 use {n} notation:
%               nexFile.neurons{2}.timestamps
%
%   nexFile.events - array of event structures
%           events{i}.name - name of event variable
%           events{i}.timestamps - array of event timestamps (in seconds)
%
%   nexFile.intervals - array of interval structures
%           intervals{i}.name - name of interval variable
%           intervals{i}.intStarts - array of interval starts (in seconds)
%           intervals{i}.intEnds - array of interval ends (in seconds)
%
%   nexFile.waves - array of wave structures
%           waves{i}.name - name of waveform variable
%           waves{i}.NPointsWave - number of data points in each wave
%           waves{i}.WFrequency - A/D frequency for wave data points
%           waves{i}.timestamps - array of wave timestamps (in seconds)
%           waves{i}.waveforms - matrix of waveforms (in milliVolts), each
%                             waveform is a column 
%
%   nexFile.contvars - array of continuous variable structures
%           contvars{i}.name - name of continuous variable
%           contvars{i}.ADFrequency - A/D frequency for data points
%
%           Continuous (a/d) data for one channel is allowed to have gaps 
%           in the recording (for example, if recording was paused, etc.).
%           Therefore, continuous data is stored in fragments. 
%           Each fragment has a timestamp and an index of the first data 
%           point of the fragment (data values for all fragments are stored
%           in one array and the index indicates the start of the fragment
%           data in this array).
%           The timestamp corresponds to the time of recording of 
%           the first a/d value in this fragment.
%
%           contvars{i}.timestamps - array of timestamps (fragments start times in seconds)
%           contvars{i}.fragmentStarts - array of start indexes for fragments in contvar.data array
%           contvars{i}.data - array of data points (in milliVolts)
%
%   nexFile.popvectors - array of population vector structures
%           popvectors{i}.name - name of population vector variable
%           popvectors{i}.weights - array of population vector weights
%
%   nexFile.markers - array of marker structures
%           markers{i}.name - name of marker variable
%           markers{i}.timestamps - array of marker timestamps (in seconds)
%           markers{i}.values - array of marker value structures
%               markers{i}.value.name - name of marker value 
%               markers{i}.value.strings - array of marker value strings
%

result = 0;

if (nargin < 2 || isempty(fileName))
   [fname, pathname] = uiputfile('*.nex', 'Save file name');
    if isequal(fname,0)
     error 'File name was not selected'
     return
   end
   fileName = fullfile(pathname, fname);
end

% note 'l' option when opening the file. 
% this options means that the file is 'little-endian'.
% this should ensure that the files are written correctly 
% on big-endian systems, such as Mac G5.
fid = fopen(fileName, 'w', 'l', 'US-ASCII');
if(fid == -1)
   error 'Unable to open file'
   return
end

% write header information
fwrite(fid, 827868494, 'int32');
fwrite(fid, nexFile.version, 'int32');
fwrite(fid, nexFile.comment, 'char');
padding = char(zeros(1, 256 - size(nexFile.comment,2)));
fwrite(fid, padding, 'char');
fwrite(fid, nexFile.freq, 'double');
fwrite(fid, int32(nexFile.tbeg*nexFile.freq), 'int32');
fwrite(fid, int32(nexFile.tend*nexFile.freq), 'int32');

% count all the variables
neuronCount = 0;
eventCount = 0;
intervalCount = 0;
waveCount = 0;
contCount = 0;
markerCount = 0;

if(isfield(nexFile, 'neurons'))
    neuronCount = size(nexFile.neurons, 1);
end
if(isfield(nexFile, 'events'))
    eventCount = size(nexFile.events, 1);
end
if(isfield(nexFile, 'intervals'))
    intervalCount = size(nexFile.intervals, 1);
end
if(isfield(nexFile, 'waves'))
    waveCount = size(nexFile.waves, 1);
end
if(isfield(nexFile, 'contvars'))
    contCount = size(nexFile.contvars, 1);
end
if(isfield(nexFile, 'markers'))
    markerCount = size(nexFile.markers, 1);
end

nvar = int32(neuronCount+eventCount+intervalCount+waveCount+contCount+markerCount);
fwrite(fid, nvar, 'int32');

% skip location of next header and padding
fwrite(fid, char(zeros(1, 260)), 'char');

% calculate where variable data starts
dataOffset = int32(544 + nvar*208);

% write variable headers
varVersion = int32(100);
n = 0;
wireNumber = 0;
unitNumber = 0;
gain = 0;
filter = 0;
xPos = 0;
yPos = 0;
WFrequency = 0;
ADtoMV = 0;
NPointsWave = 0;
NMarkers = 0;
MarkerLength = 0;
MVOfffset = 0;

% write neuron headers
for i = 1:neuronCount
    neuron = nexFile.neurons{i};
    % neuron variable type is zero
    fwrite(fid, 0, 'int32');
    varVersion = int32(100);
    if(isfield(neuron, 'varVersion'))
        varVersion = neuron.varVersion;
    end
    fwrite(fid, varVersion, 'int32');
    fwrite(fid, neuron.name, 'char');
    padding = char(zeros(1, 64 - size(neuron.name,2)));
    fwrite(fid, padding, 'char');
    fwrite(fid, dataOffset, 'int32');
    n = int32(size(neuron.timestamps,1));
    dataOffset = dataOffset + n*4;
    fwrite(fid, n, 'int32');
    wireNumber = 0;
    if(isfield(neuron, 'wireNumber'))
        wireNumber = neuron.wireNumber;
    end
    fwrite(fid, wireNumber, 'int32');
    unitNumber = 0;
    if(isfield(neuron, 'unitNumber'))
        unitNumber = neuron.unitNumber;
    end
    fwrite(fid, unitNumber, 'int32');
    fwrite(fid, gain, 'int32');
    fwrite(fid, filter, 'int32');
    xPos = 0;
    if(isfield(neuron, 'xPos'))
        xPos = neuron.xPos;
    end
    fwrite(fid, xPos, 'double');
    yPos = 0;
    if(isfield(neuron, 'yPos'))
        yPos = neuron.yPos;
    end
    fwrite(fid, yPos, 'double');
    fwrite(fid, WFrequency, 'double');
    fwrite(fid, ADtoMV, 'double');
    fwrite(fid, NPointsWave, 'int32');
    fwrite(fid, NMarkers, 'int32');
    fwrite(fid, MarkerLength, 'int32');
    fwrite(fid, MVOfffset, 'double');
    fwrite(fid, char(zeros(1, 60)), 'char');
end
   
% event headers
varVersion = int32(100);
wireNumber = 0;
unitNumber = 0;
gain = 0;
filter = 0;
xPos = 0;
yPos = 0;
WFrequency = 0;
ADtoMV = 0;
NPointsWave = 0;
NMarkers = 0;
MarkerLength = 0;
MVOfffset = 0;

for i = 1:eventCount
    event = nexFile.events{i};
    % event variable type is 1
    fwrite(fid, 1, 'int32');
    fwrite(fid, varVersion, 'int32');
    fwrite(fid, event.name, 'char');
    padding = char(zeros(1, 64 - size(event.name,2)));
    fwrite(fid, padding, 'char');
    fwrite(fid, dataOffset, 'int32');
    n = int32(size(event.timestamps,1));
    dataOffset = dataOffset + n*4;
    fwrite(fid, n, 'int32');
    fwrite(fid, wireNumber, 'int32');
    fwrite(fid, unitNumber, 'int32');
    fwrite(fid, gain, 'int32');
    fwrite(fid, filter, 'int32');
    fwrite(fid, xPos, 'double');
    fwrite(fid, yPos, 'double');
    fwrite(fid, WFrequency, 'double');
    fwrite(fid, ADtoMV, 'double');
    fwrite(fid, NPointsWave, 'int32');
    fwrite(fid, NMarkers, 'int32');
    fwrite(fid, MarkerLength, 'int32');
    fwrite(fid, MVOfffset, 'double');
    fwrite(fid, char(zeros(1, 60)), 'char');
end
    
% interval headers
varVersion = int32(100);
wireNumber = 0;
unitNumber = 0;
gain = 0;
filter = 0;
xPos = 0;
yPos = 0;
WFrequency = 0;
ADtoMV = 0;
NPointsWave = 0;
NMarkers = 0;
MarkerLength = 0;
MVOfffset = 0;

for i = 1:intervalCount
    interval = nexFile.intervals{i};
    % interval variable type is 2
    fwrite(fid, 2, 'int32');
    fwrite(fid, varVersion, 'int32');
    fwrite(fid, interval.name, 'char');
    padding = char(zeros(1, 64 - size(interval.name,2)));
    fwrite(fid, padding, 'char');
    fwrite(fid, dataOffset, 'int32');
    n = int32(size(interval.intStarts,1));
    dataOffset = dataOffset + n*8;
    fwrite(fid, n, 'int32');
    fwrite(fid, wireNumber, 'int32');
    fwrite(fid, unitNumber, 'int32');
    fwrite(fid, gain, 'int32');
    fwrite(fid, filter, 'int32');
    fwrite(fid, xPos, 'double');
    fwrite(fid, yPos, 'double');
    fwrite(fid, WFrequency, 'double');
    fwrite(fid, ADtoMV, 'double');
    fwrite(fid, NPointsWave, 'int32');
    fwrite(fid, NMarkers, 'int32');
    fwrite(fid, MarkerLength, 'int32');
    fwrite(fid, MVOfffset, 'double');
    fwrite(fid, char(zeros(1, 60)), 'char');
end

% wave headers
gain = 0;
filter = 0;
xPos = 0;
yPos = 0;
WFrequency = 0;
ADtoMV = 0;
NPointsWave = 0;
NMarkers = 0;
MarkerLength = 0;
MVOfffset = 0;

for i = 1:waveCount
    wave = nexFile.waves{i};
    % wave variable type is 3
    fwrite(fid, 3, 'int32');
    varVersion = int32(100);
    if(isfield(wave, 'varVersion'))
        varVersion = wave.varVersion;
    end
    fwrite(fid, varVersion, 'int32');
    fwrite(fid, wave.name, 'char');
    padding = char(zeros(1, 64 - size(wave.name,2)));
    fwrite(fid, padding, 'char');
    fwrite(fid, dataOffset, 'int32');
    n = int32(size(wave.timestamps,1));
    NPointsWave = wave.NPointsWave;
    dataOffset = dataOffset + n*4 + NPointsWave*n*2;
    fwrite(fid, n, 'int32');
    wireNumber = 0;
    if(isfield(wave, 'wireNumber'))
        wireNumber = wave.wireNumber;
    end
    fwrite(fid, wireNumber, 'int32');
    unitNumber = 0;
    if(isfield(wave, 'unitNumber'))
        unitNumber = wave.unitNumber;
    end
    fwrite(fid, unitNumber, 'int32');
    fwrite(fid, gain, 'int32');
    fwrite(fid, filter, 'int32');
    fwrite(fid, xPos, 'double');
    fwrite(fid, yPos, 'double');
    fwrite(fid, wave.WFrequency, 'double');
    nexFile.waves{i}.MVOfffset = 0;
    % we need to recalculate a/d to millivolts factor
    wmin = min(min(nexFile.waves{i}.waveforms));
    wmax = max(max(nexFile.waves{i}.waveforms));
    c = max(abs(wmin),abs(wmax));
    if (c == 0)
        c = 1;
    else
        c = c/32767;
    end
    nexFile.waves{i}.ADtoMV = c;
    
    fwrite(fid, nexFile.waves{i}.ADtoMV, 'double');
    fwrite(fid, wave.NPointsWave, 'int32');
    fwrite(fid, NMarkers, 'int32');
    fwrite(fid, MarkerLength, 'int32');
    fwrite(fid, nexFile.waves{i}.MVOfffset, 'double');
    fwrite(fid, char(zeros(1, 60)), 'char');
end
 
% continuous variables
wireNumber = 0;
unitNumber = 0;
gain = 0;
filter = 0;
xPos = 0;
yPos = 0;
WFrequency = 0;
ADtoMV = 0;
NPointsWave = 0;
NMarkers = 0;
MarkerLength = 0;
MVOfffset = 0;

% write variable headers
for i = 1:contCount
    % cont. variable type is 5
    fwrite(fid, 5, 'int32');
    varVersion = int32(100);
    if(isfield(nexFile.contvars{i}, 'varVersion'))
        varVersion = nexFile.contvars{i}.varVersion;
    end
    fwrite(fid, varVersion, 'int32');
    fwrite(fid, nexFile.contvars{i}.name, 'char');
    padding = char(zeros(1, 64 - size(nexFile.contvars{i}.name,2)));
    fwrite(fid, padding, 'char');
    fwrite(fid, dataOffset, 'int32');
    n = int32(size(nexFile.contvars{i}.timestamps,1));
    NPointsWave = size(nexFile.contvars{i}.data, 1);
    dataOffset = dataOffset + n*8 + NPointsWave*2;
    fwrite(fid, n, 'int32');
    fwrite(fid, wireNumber, 'int32');
    fwrite(fid, unitNumber, 'int32');
    fwrite(fid, gain, 'int32');
    fwrite(fid, filter, 'int32');
    fwrite(fid, xPos, 'double');
    fwrite(fid, yPos, 'double');
    fwrite(fid, nexFile.contvars{i}.ADFrequency, 'double');
    nexFile.contvars{i}.MVOfffset = 0;
        
    wmin = min(min(nexFile.contvars{i}.data));
    wmax = max(max(nexFile.contvars{i}.data));
    c = max(abs(wmin),abs(wmax));
    if (c == 0)
        c = 1;
    else
        c = c/32767;
    end
    nexFile.contvars{i}.ADtoMV = c;
    
    fwrite(fid, nexFile.contvars{i}.ADtoMV, 'double');
    fwrite(fid, NPointsWave, 'int32');
    fwrite(fid, NMarkers, 'int32');
    fwrite(fid, MarkerLength, 'int32');
    fwrite(fid, nexFile.contvars{i}.MVOfffset, 'double');
    fwrite(fid, char(zeros(1, 60)), 'char');
end

% markers
varVersion = int32(100);
wireNumber = 0;
unitNumber = 0;
gain = 0;
filter = 0;
xPos = 0;
yPos = 0;
WFrequency = 0;
ADtoMV = 0;
NPointsWave = 0;
NMarkers = 0;
MarkerLength = 0;
MVOfffset = 0;

for i = 1:markerCount
    marker = nexFile.markers{i};
    % marker variable type is 6
    fwrite(fid, 6, 'int32');
    fwrite(fid, varVersion, 'int32');
    fwrite(fid, marker.name, 'char');
    padding = char(zeros(1, 64 - size(marker.name,2)));
    fwrite(fid, padding, 'char');
    fwrite(fid, dataOffset, 'int32');
    n = int32(size(marker.timestamps,1));
    dataOffset = dataOffset + n*4;
    NMarkers = size(marker.values, 1);
    MarkerLength = 0;
    for j = 1:NMarkers
      v = marker.values{j,1};
      for k = 1:size(v.strings, 1)
        MarkerLength = max(MarkerLength, size(v.strings{k,1}, 2));
      end
    end
    % add extra char to hold zero (end of string)
    MarkerLength = MarkerLength + 1;
    nexFile.markers{i}.NMarkers = NMarkers;
    nexFile.markers{i}.MarkerLength = MarkerLength;
    dataOffset = dataOffset + NMarkers*64 + NMarkers*n*MarkerLength;
    fwrite(fid, n, 'int32');
    fwrite(fid, wireNumber, 'int32');
    fwrite(fid, unitNumber, 'int32');
    fwrite(fid, gain, 'int32');
    fwrite(fid, filter, 'int32');
    fwrite(fid, xPos, 'double');
    fwrite(fid, yPos, 'double');
    fwrite(fid, WFrequency, 'double');
    fwrite(fid, ADtoMV, 'double');
    fwrite(fid, NPointsWave, 'int32');
    fwrite(fid, NMarkers, 'int32');
    fwrite(fid, MarkerLength, 'int32');
    fwrite(fid, MVOfffset, 'double');
    fwrite(fid, char(zeros(1, 60)), 'char');
end

for i = 1:neuronCount
    fwrite(fid, nexFile.neurons{i}.timestamps.*nexFile.freq, 'int32');
end
for i = 1:eventCount
    fwrite(fid, nexFile.events{i}.timestamps.*nexFile.freq, 'int32');
end
for i = 1:intervalCount
    fwrite(fid, nexFile.intervals{i}.intStarts.*nexFile.freq, 'int32');
    fwrite(fid, nexFile.intervals{i}.intEnds.*nexFile.freq, 'int32');
end
for i = 1:waveCount
    fwrite(fid, nexFile.waves{i}.timestamps.*nexFile.freq, 'int32');
    wf = int16(nexFile.waves{i}.waveforms./nexFile.waves{i}.ADtoMV);
    fwrite(fid, wf, 'int16');
end
for i = 1:contCount
    fwrite(fid, nexFile.contvars{i}.timestamps.*nexFile.freq, 'int32');
    fwrite(fid, nexFile.contvars{i}.fragmentStarts - 1, 'int32');
    fwrite(fid, int16(nexFile.contvars{i}.data./nexFile.contvars{i}.ADtoMV), 'int16');
end

for i = 1:markerCount
    fwrite(fid, nexFile.markers{i}.timestamps.*nexFile.freq, 'int32');
    for j = 1:NMarkers
      v = nexFile.markers{i}.values{j,1};
      fwrite(fid, v.name, 'char');
      padding = char(zeros(1, 64 - size(v.name,2)));
      fwrite(fid, padding, 'char');
      for k = 1:size(v.strings, 1)
        fwrite(fid, v.strings{k,1}, 'char');
        padding = char(zeros(1, nexFile.markers{i}.MarkerLength - size(v.strings{k,1}, 2)));
        fwrite(fid, padding, 'char');  
      end
    end
end

fclose(fid);
result = 1;
