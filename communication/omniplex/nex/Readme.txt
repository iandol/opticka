Reading .nex files
------------------

Use readNexFile function to read the contents of *.nex file in Matlab.
For example:

nexFileData = readNexFile(filePath);
nexFileData1 = readNexFile(); % if file path is not specified, Open File dialog will be used

nexFileData is a structure that contains all the data from .nex file.
See comments in the readNexFile.m file for more information on the contents of nexFileData sctucture.



Writing .nex files
------------------

Use writeNexFile function to write the contents of nexFileData structure to .nex file.

For example (see file exampleSaveDataInNexFile.m):

% start new nex file data
nexFile = nexCreateFileData(40000);

% add continuous variable
% digitizing frequency 1000 Hz
Fs = 1000;
% time interval from 1 to 5
t= 1:1/Fs:5;
% sin with frequency 2 Hz
x2 = sin(2*pi*t*2);
% specify start time (t(1)), digitizing frequency (Fs), data (x2) and name
nexFile = nexAddContinuous(nexFile, t(1), Fs, x2, 'sin2Hz');

% add neuron spike train
% timestamps are in seconds
neuronTs = [0.5 0.9 2.1 2.3 2.5]'
nexFile = nexAddNeuron(nexFile, neuronTs, 'neuron1');

% add event spike train
eventTs = [10 20 30 40]';
nexFile = nexAddEvent(nexFile, eventTs, 'event1');

% add interval variable
intStarts = [5 10];
intEnds = [6 12];
nexFile = nexAddInterval(nexFile, intStarts, intEnds, 'interval1');

% add  waveforms
% waveform timestamps
waveTs = [1 2]';
% 2 waveforms (columns), 5 data points each
waves = [-10 0 10 20 30; -15 0 15 25 15]';
nexFile = nexAddWaveform(nexFile, 40000, waveTs, waves, 'wave1');

% save nex file (assuming nex directory in Windows 7)
writeNexFile(nexFile, 'C:\ProgramData\Nex Technologies\NeuroExplorer\test1.nex');
