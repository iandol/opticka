function screenInfo = openExperiment(monWidth, viewDist, curScreen)
% screenInfo = openExperiment(monWidth, viewDist, curScreen)
% Arguments:
%	monWidth ... viewing width of monitor (cm)
%	viewDist     ... distance from the center of the subject's eyes to
%	the monitor (cm)
%   curScreen         ... screen number for experiment
%                         default is 0.
% Sets the random number generator, opens the screen, gets the refresh
% rate, determines the center and ppd, and stops the update process 
% Used by both my dot code and my touch code.
% MKMK July 2006

mfilename
% 1. SEED RANDOM NUMBER GENERATOR
screenInfo.rseed = [];
rseed = sum(100*clock);
rand('state',rseed);
%screenInfo.rseed = sum(100*clock);
%rand('state',screenInfo.rseed);

% ---------------
% open the screen
% ---------------

% make sure we are using openGL
AssertOpenGL;

if nargin < 3
    curScreen = 0;
end

% added to make stuff behave itself in os x with multiple monitors
Screen('Preference', 'SkipSyncTests', 2);
Screen('Preference', 'VisualDebugLevel', 0);
%%%%

% Set the background to the background value.
screenInfo.bckgnd = 0;
[screenInfo.curWindow, screenInfo.screenRect] = Screen('OpenWindow', curScreen, screenInfo.bckgnd,[1 1 801 601],32, 2,0,0);
screenInfo.dontclear = 0; % 1 gives incremental drawing (does not clear buffer after flip)

%get the refresh rate of the screen
% need to change this if using crt, would be nice to have an if
% statement...
%screenInfo.monRefresh = Screen(curWindow,'FrameRate');
spf =Screen('GetFlipInterval', screenInfo.curWindow);      % seconds per frame
screenInfo.monRefresh = 1/spf;    % frames per second
screenInfo.frameDur = 1000/screenInfo.monRefresh;

screenInfo.center = [screenInfo.screenRect(3) screenInfo.screenRect(4)]/2;   	% coordinates of screen center (pixels)

% determine pixels per degree
% (pix/screen) * ... (screen/rad) * ... rad/deg
screenInfo.ppd = pi * screenInfo.screenRect(3) / atan(monWidth/viewDist/2) / 360;    % pixels per degree

HideCursor

% if reward system is hooked up, rewardOn = 1, otherwise rewardOn = 0;
screenInfo.rewardOn = 0;
%screenInfo.rewardOn = 1;

% get reward system ready
screenInfo.daq=DaqDeviceIndex;
