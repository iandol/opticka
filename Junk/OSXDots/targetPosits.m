function [newx newy] = targetPosits(x, y, direction)
% newxy = targetPosits(x, y, direction)
% gives xy coordinates for any direction, given coordinates that set the
% distance, for example, if you want the x and y coordinates for 90
% degrees, at the same distance as [2 3] is from [-1 -4], then input
% newxy = targetPosits([2 3], [-1 -4], 90) and it will give x and y coordinates
% with center at xy(2,-1). Only looks at the first to x and y coordinates
% for the distance measure, but makes as many targets as directions given
% MKMK July 2006

distance = sqrt((x(2) - x(1)).^2 + (y(2) - y(1)).^2);
newy = (distance.*sind(direction) + y(1))';
newx = (distance.*cosd(direction) + x(1))';
