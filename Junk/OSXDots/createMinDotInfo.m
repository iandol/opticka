function dotInfo = createMinDotInfo(inputtype)
% dotInfo = createDotInfo(inputtype)
% creates the default dotInfo structure. inputtype is 1 for using keyboard,
% 2 for using touchscreen/mouse 
% only includes fields necessary to run dots themselves, to run one of the
% paradigms see createDotInfo
% saves the structure in the file dotInfoMatrix or returns it

% created June 2006 MKMK

%mfilename

if nargin < 1
    %inputtype = 1; % use keyboard
    inputtype = 2; % use touchscreen
end

% to have more than one set of dots, all of these must have information for
% more than one set of dots: aperture, speed, coh, direction, maxDotTime
% dotInfo.numDotField = 1;
% dotInfo.apXYD = [0 50 50];  
% %dotInfo.apXYD = [0 0 50];  
% dotInfo.speed = 50;
% dotInfo.coh = 512; 
% dotInfo.dir = 180;
% dotInfo.maxDotTime = 2;

dotInfo.numDotField = 2;
dotInfo.apXYD = [-50 0 60; 50 0 60]; 
%dotInfo.apXYD = [150 0 50; -150 0 50];  
dotInfo.speed = [2 2];
dotInfo.coh = [1000 500];
dotInfo.dir = [45 90];
dotInfo.maxDotTime = [20 20];

%dotInfo.trialtype = [1 1]; 
% [1 fixed duration 2 reaction time,  1 hold on 2 hold off] hold on means
% subject has to hold fixation during task.
dotInfo.trialtype = [1 1];

dotInfo.dotColor = [255 255 255]; % white dots default

% dot size in pixels
dotInfo.dotSize = 5;

% trialInfo.auto
% column 1: 1 to set manually, 2 to use fixation as center point, 3 to use aperture
% as center
% column 2: 1 to set coherence manually, 2 random, 3 correction mode
% column 3: 1 to set direction manually, 2 random
dotInfo.auto = [3 1 1];

%%%%%%% BELOW HERE IS STUFF THAT SHOULD GENERALLY NOT BE CHANGED!

dotInfo.maxDotsPerFrame = 1000;   % by trial and error.  Depends on graphics card
% Use test_dots7_noRex to find out when we miss frames.
% The dots routine tries to maintain a constant dot density, regardless of
% aperture size.  However, it respects MaxDotsPerFrame as an upper bound.
% The value of 53 was established for a 7100 with native graphics card.

% possible keys active during trial
dotInfo.keyEscape = KbName('escape');
dotInfo.keySpace = KbName('space');
dotInfo.keyReturn = KbName('return');
if inputtype == 1
    dotInfo.keyLeft = KbName('leftarrow');
    dotInfo.keyRight = KbName('rightarrow');
end

if inputtype == 1
    dotInfo.keyLeft = KbName('leftarrow');
    dotInfo.keyRight = KbName('rightarrow');
else
    mouse_left = 1;
    mouse_right = 2;
    dotInfo.mouse = [mouse_left, mouse_right];
end

if nargout < 1
    save dotInfoMatrix dotInfo
end
