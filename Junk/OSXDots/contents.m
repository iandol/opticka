% Contents - OSX dots without clut (using DrawDots)
% 
% closeExperiment
% closes the screen, returns priority to zero, starts the update process,
% and shows the cursor.
%
% createDotInfo -
% dotInfo = createDotInfo(screenInfo) makes the structure dotInfo, which
% contains all of the information necessary to plot the dots - used both
% with and without clut, this version has all kinds of extra stuff for
% using my touchscreen/mouse or keypress routines
%
% createMinDotInfo -
% dotInfo = createMinDotInfo(screenInfo) makes the structure dotInfo, with
% the minimum amount of info to plot just dots.
%
% createSound
% [freq beepmatrix] = createSound
% makes the matrix to create the same sound used in the human experiments
% on the eyelink for feedback
%
% createTRect -
% tarRects = getTRect(target_array, screenInfo) takes a list of target
% parameters: x,y,diameter, in visual degrees, and creates a target array
% for use with FillOval or FillRect
% 
% DemoOSX -
% demonstrates how to use newTargets to change position,color,etc of
% targets and does a demo of the dots, no response required.
%
% dotgui -
% makes a gui to manipulate the config file (dotInfoMatrix.mat that holds
% dotInfo).
%
% dotsOnlyDemo
% simple script for testing just the dots, change parameters of dots in
% createMinDotInfo.m
%
% dotsX
% function that actually makes the random dot patches - uses the Screen
% BlendFunction to make the mask
%
% dotsXnomask
% function that makes the random dot patches in a square (no mask). Not
% used by any other files in the directory currently.
%
% drawDotsTest 
% script to draw dots with DrawDots - no mask, This code is completely
% independent of the other dots code I have written - iow, you just need
% the psychtoolbox to run it, no other files.
%
% keyDots
% experiment using dots and keypresses. If there is no config file on the
% path, creates one using createDotInfo and whatever defaults are set.
%
% makeDotTargets
% makes targets that are coordinated with dot position or fixation.
%
% makeInterval
% interval = makeInterval(typeInt,minNum,maxNum,meanNum)
% creates a distribution of numbers, either uniform or exponential (or
% returns the same distribution minNum)
%
% newTargets
% function to create/move/change targets. based on targets in original dots
% code, created to be versatile and separate from dots code. DemoOSX shows
% how to use it. 
%
% openExperiment
% screenInfo = openExperiment(monWidth, viewDist, curScreen)
% Sets the random number generator, opens the screen, gets the refresh
% rate, determines the center and ppd, and stops the update process 
%
% randomDotTrial
%
% determines if trials are being randomly chosen, and then picks from
% random distribution
%
% setNumTargets 
% creates the structure where the target information is kept. Should be
% called before newTargets.
% 
% showTargets
% function that shows whichever targets are requested (by way of their
% index number)
%