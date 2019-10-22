% this example script demonstrates how to save data in .nex file

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

% ------------- OPTIONAL NEX FILE VERIFICATION -----------------------------------

% verify that we can open file in NeuroExplorer
nex = actxserver('NeuroExplorer.Application');
doc = nex.OpenDocument('C:\ProgramData\Nex Technologies\NeuroExplorer\test1.nex');

% make sure that all variables are in the file
nexCont = doc.Variable('sin2Hz');
nexNeuron = doc.Variable('neuron1');
nexEvent = doc.Variable('event1');
nexInt = doc.Variable('interval1');
nexWave = doc.Variable('wave1');
% get all the neuron timestamps
nexNeuronTimestamps = nexNeuron.Timestamps()'

% note that continuous values differ in .nex file
% the reason for this is that the values are stored as 2-byte integers
% in .nex file, so their resolution is of the order of 1.e-05
% get all the values and timestamps
contValues = nexCont.ContinuousValues();
contTimestamps = nexCont.Timestamps();
disp ([ 'max difference: ', num2str(max(abs(contValues-x2)))])
plot(contTimestamps, contValues);

% close NeuroExplorer
nex.delete;
