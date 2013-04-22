function [nexFile] = readNexFile(fileName)
% [nexFile] = readNexFile(fileName) -- read .nex file and return file data
%             in nexFile structure
%
% INPUT:
%   fileName - if empty string, will use File Open dialog
%
% OUTPUT:
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
%                                waveform is a column 
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
%               markers{i}.values{j}.name - name of marker value 
%               markers{i}.values{j}.strings - array of marker value strings
%

nexFile = [];

if (nargin == 0 | isempty(fileName))
   [fname, pathname] = uigetfile('*.nex', 'Select a NeuroExplorer file');
   if isequal(fname,0)
     error 'No file was selected'
     return
   end
   fileName = fullfile(pathname, fname);
end

% note 'l' option when opening the file. 
% this options means that the file is 'little-endian'.
% this should ensure that the files are read correctly 
% on big-endian systems, such as Mac G5.
fid = fopen(fileName, 'r', 'l','US-ASCII');
if(fid == -1)
   error 'Unable to open file'
   return
end

magic = fread(fid, 1, 'int32');
if magic ~= 827868494
    error 'The file is not a valid .nex file'
end
nexFile.version = fread(fid, 1, 'int32');
comment = fread(fid, 256, '*char')';
% remove first zero and all characters after the first zero
comment(end+1) = 0; 
nexFile.comment = comment(1:min(find(comment==0))-1);
nexFile.freq = fread(fid, 1, 'double');
nexFile.tbeg = fread(fid, 1, 'int32')./nexFile.freq;
nexFile.tend = fread(fid, 1, 'int32')./nexFile.freq;
nvar = fread(fid, 1, 'int32');

% skip location of next header fields and padding
fseek(fid, 260, 'cof');

neuronCount = 0;
eventCount = 0;
intervalCount = 0;
waveCount = 0;
popCount = 0;
contCount = 0;
markerCount = 0;

% real all variables
for variableIndex=1:nvar
    % read variable header
    type = fread(fid, 1, 'int32');
    varVersion = fread(fid, 1, 'int32');
    name = fread(fid, 64, '*char')';
    % remove first zero and all characters after the first zero
    name(end+1) = 0;
    name = name(1:min(find(name==0))-1);
    offset = fread(fid, 1, 'int32');
    n = fread(fid, 1, 'int32');
    wireNumber = fread(fid, 1, 'int32');
    unitNumber = fread(fid, 1, 'int32');
    gain = fread(fid, 1, 'int32');
    filter = fread(fid, 1, 'int32');
    xPos = fread(fid, 1, 'double');
    yPos = fread(fid, 1, 'double');
    WFrequency = fread(fid, 1, 'double'); % wf sampling fr.
    ADtoMV  = fread(fid, 1, 'double'); % coeff to convert from AD values to Millivolts.
    NPointsWave = fread(fid, 1, 'int32'); % number of points in each wave
    NMarkers = fread(fid, 1, 'int32'); % how many values are associated with each marker
    MarkerLength = fread(fid, 1, 'int32'); % how many characters are in each marker value
    MVOfffset = fread(fid, 1, 'double'); % coeff to shift AD values in Millivolts: mv = raw*ADtoMV+MVOfffset
    filePosition = ftell(fid);
    switch type
        case 0 % neuron
            neuronCount = neuronCount+1;
            nexFile.neurons{neuronCount,1}.name = name;
            nexFile.neurons{neuronCount,1}.varVersion = varVersion;
            if varVersion > 100
                nexFile.neurons{neuronCount,1}.wireNumber = wireNumber;
                nexFile.neurons{neuronCount,1}.unitNumber = unitNumber;
            else
                nexFile.neurons{neuronCount,1}.wireNumber = 0;
                nexFile.neurons{neuronCount,1}.unitNumber = 0;
            end
            nexFile.neurons{neuronCount,1}.xPos = xPos;
            nexFile.neurons{neuronCount,1}.yPos = yPos;
            % go to the variable data position and read timestamps
            fseek(fid, offset, 'bof');
            nexFile.neurons{neuronCount,1}.timestamps = fread(fid, [n 1], 'int32')./nexFile.freq;
                        
        case 1 % event
            eventCount = eventCount+1;
            nexFile.events{eventCount,1}.name = name;
            nexFile.events{eventCount,1}.varVersion = varVersion;
            fseek(fid, offset, 'bof');
            nexFile.events{eventCount,1}.timestamps = fread(fid, [n 1], 'int32')./nexFile.freq;
                    
        case 2 % interval
            intervalCount = intervalCount+1;
            nexFile.intervals{intervalCount,1}.name = name;
            nexFile.intervals{intervalCount,1}.varVersion = varVersion;
            fseek(fid, offset, 'bof');
            nexFile.intervals{intervalCount,1}.intStarts = fread(fid, [n 1], 'int32')./nexFile.freq;
            nexFile.intervals{intervalCount,1}.intEnds = fread(fid, [n 1], 'int32')./nexFile.freq;
                    
        case 3 % waveform
            waveCount = waveCount+1;
            nexFile.waves{waveCount,1}.name = name;
            nexFile.waves{waveCount,1}.varVersion = varVersion;
            nexFile.waves{waveCount,1}.NPointsWave = NPointsWave;
            nexFile.waves{waveCount,1}.WFrequency = WFrequency;
            if varVersion > 100
                nexFile.waves{waveCount,1}.wireNumber = wireNumber;
                nexFile.waves{waveCount,1}.unitNumber = unitNumber;
            else
                nexFile.waves{waveCount,1}.wireNumber = 0;
                nexFile.waves{waveCount,1}.unitNumber = 0;
            end
            nexFile.waves{waveCount,1}.ADtoMV = ADtoMV;
            if nexFile.version > 104
                nexFile.waves{waveCount,1}.MVOfffset = MVOfffset;
            else
                nexFile.waves{waveCount,1}.MVOfffset = 0;
            end
            fseek(fid, offset, 'bof');
            nexFile.waves{waveCount,1}.timestamps = fread(fid, [n 1], 'int32')./nexFile.freq;
            wf = fread(fid, [NPointsWave n], 'int16');
            nexFile.waves{waveCount,1}.waveforms = wf.*ADtoMV + nexFile.waves{waveCount,1}.MVOfffset;
                        
        case 4 % population vector
            popCount = popCount+1;
            nexFile.popvectors{popCount,1}.name = name;
            nexFile.popvectors{popCount,1}.varVersion = varVersion;
            fseek(fid, offset, 'bof');
            nexFile.popvectors{popCount,1}.weights = fread(fid, [n 1], 'double');
                        
        case 5 % continuous variable
            contCount = contCount+1;
            nexFile.contvars{contCount,1}.name = name;
            nexFile.contvars{contCount,1}.varVersion = varVersion;
            nexFile.contvars{contCount,1}.ADtoMV = ADtoMV;
            if nexFile.version > 104
                nexFile.contvars{contCount,1}.MVOfffset = MVOfffset;
            else
                nexFile.contvars{contCount,1}.MVOfffset = 0;
            end
            nexFile.contvars{contCount,1}.ADFrequency = WFrequency;
            fseek(fid, offset, 'bof');
            nexFile.contvars{contCount,1}.timestamps = fread(fid, [n 1], 'int32')./nexFile.freq;
            nexFile.contvars{contCount,1}.fragmentStarts = fread(fid, [n 1], 'int32') + 1;
            nexFile.contvars{contCount,1}.data = fread(fid, [NPointsWave 1], 'int16').*ADtoMV + nexFile.contvars{contCount,1}.MVOfffset;
                     
        case 6 % marker
            markerCount = markerCount+1;
            nexFile.markers{markerCount,1}.name = name;
            nexFile.markers{markerCount,1}.varVersion = varVersion;
            fseek(fid, offset, 'bof');
            nexFile.markers{markerCount,1}.timestamps = fread(fid, [n 1], 'int32')./nexFile.freq;
            for markerFieldIndex=1:NMarkers
                markerName = fread(fid, 64, '*char')';
                % remove first zero and all characters after the first zero
                markerName(end+1) = 0;
                markerName = markerName(1:min(find(markerName==0))-1);
                nexFile.markers{markerCount,1}.values{markerFieldIndex,1}.name = markerName;
                for markerValueIndex = 1:n
                    markerValue = fread(fid, MarkerLength, '*char')';
                    % remove first zero and all characters after the first zero
                    markerValue(end+1) = 0;
                    markerValue = markerValue(1:min(find(markerValue==0))-1);
                    nexFile.markers{markerCount,1}.values{markerFieldIndex,1}.strings{markerValueIndex, 1} = markerValue;
                end
            end
                    
        otherwise
            disp (['unknown variable type ' num2str(type)]);
    end
    % return to file position that was after reading the variable header
    fseek(fid, filePosition, 'bof');
    dummy = fread(fid, 60, 'char');
end
fclose(fid);