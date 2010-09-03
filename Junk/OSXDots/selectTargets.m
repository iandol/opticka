function select = selectTargets(screenInfo, xy, diamTar)
% select = selectTargets(screenInfo, xy, diamTar)
% puts the targets into correct coordinates for checking to see if a touch
% is within the boundaries of the targets.
% translate the coordinates, move the center and invert y, and change from
% visual degrees to pixels

temp = ones(size(xy));
temp = [screenInfo.center(1).*temp(:,1) screenInfo.center(2).*temp(:,2)];
tar_xy = [temp(:,1)+xy(:,1)*screenInfo.ppd/10 temp(:,2)-xy(:,2)*screenInfo.ppd/10];
%diamTar = [diamTar; diamTar]';
select = [tar_xy(:,1) tar_xy(:,2) diamTar'/2*screenInfo.ppd/10];
