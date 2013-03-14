function I1Demo()
% I1Demo()
%
% Basic demo showing how to use the I1Toolbox.
%   -Detects i1
%   -Calibrates i1
%   -Waits for user to press button on i1
%   -Takes a single light measurement
%   -Prints CIE Lxy coordinates for measurement
%   -Plots raw spectral data for measurement
%
% History:
%
% Aug 23, 2012  paa     Written

AssertOpenGL;   % We use PTB-3

% Confirm that there is an i1 detected in the system
if I1('IsConnected') == 0
    fprintf('\nNo i1 detected\n');
    return;
end

% i1 needs to be calibrated after plugging it in, and before doing any measurements.
fprintf('\nPlace i1 onto its white calibration tile, then press i1 button to continue: ');
while I1('KeyPressed') == 0
    WaitSecs(0.01);
end
fprintf('Calibrating...');
I1('Calibrate');

% Now we can take any number of measurements, and collect CIE Lxy and raw spectral data for each measurement.
% For demo purposes, we'll just collect a single datum, print the Lxy coordinates, and plot the spectral data.
fprintf('\nPlace i1 sensor over light source, then press i1 button to measure: ');
while I1('KeyPressed') == 0
    WaitSecs(0.01);
end
fprintf('Measuring...');
I1('TriggerMeasurement');
Lxy = I1('GetTriStimulus');
fprintf('\nCIE Lxy = (%g,%g,%g)\n', Lxy(1), Lxy(2), Lxy(3));
fprintf('\nPlotting raw spectral data\n');
spectralData = I1('GetSpectrum');
wavelengths = [380:10:730];
plot(wavelengths, spectralData);
