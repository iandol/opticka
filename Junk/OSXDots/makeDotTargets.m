function targets = makeDotTargets(screenInfo, dotInfo)
% makes targets that are coordinated with dot position or fixation. Used in
% keyDots, but not necessary for using dots in experiments in general. For
% a little more info, see createDotInfo

if dotInfo.auto(1) == 1 % 1 set manually, take directly from tarXY
    xpos = dotInfo.tarXY(:,1);
    ypos = dotInfo.tarXY(:,2);
else
    if dotInfo.auto(1) == 2 % fixation is center
        xpos = [dotInfo.fixXY(:,1); dotInfo.tarXY(:,1)];
        ypos = [dotInfo.fixXY(:,2); dotInfo.tarXY(:,2)];
    elseif dotInfo.auto(1) == 3 % aperture is center
        xpos = [dotInfo.apXYD(:,1); dotInfo.tarXY(:,1)];
        ypos = [dotInfo.apXYD(:,2); dotInfo.tarXY(:,2)];
    end
    [xpos ypos] = targetPosits(xpos, ypos, dotInfo.dirSet);
end
% add fixation to targets
xpos = [dotInfo.fixXY(:,1); xpos]';
ypos = [dotInfo.fixXY(:,2); ypos]';
diam = [dotInfo.fixDiam dotInfo.tarDiam];
% for now assume all targets the same color
colors = repmat(dotInfo.tarColor,length(dotInfo.tarDiam),1);
colors = [dotInfo.fixColor; colors];

% initialize targets
targets = setNumTargets(length(xpos));

targets = newTargets(screenInfo, targets, 1:length(xpos), xpos, ypos, diam, colors);

if isempty(dotInfo.touchbig)
    targets.select = selectTargets(screenInfo, [xpos' ypos'], diam);
else
    targets.select = selectTargets(screenInfo, [xpos' ypos'], dotInfo.touchbig);
end
% these are different depending on whether using keypresses or touchscreen
% (mouse)
if isfield(dotInfo,'keyLeft') && ~isempty(dotInfo.keyLeft)
    targs = dotInfo.minTime(1);
    dots = dotInfo.minTime(2);
else
    targs = dotInfo.minTime(2);
    dots = dotInfo.minTime(3);
end
%targs
%dots
% hold off
if dotInfo.trialtype(2)==2
    %if dotInfo.minTime(2) > dotInfo.minTime(3)
    % subject not required to hold fixation, so fixation not on during dots
    % if dots come on before targets, don't show targets
    if targs > dots
        targets.show = [];
    else
        targets.show = 2:size(targets.rects,1);
    end
else
    %if dotInfo.minTime(2) > dotInfo.minTime(3)
    % fixation is on as long as dots are on
    % if dots come on before targets, don't show targets, only fixation
    if targs > dots
        targets.show = 1;
    else
        targets.show = 1:size(targets.rects,1);
    end
end