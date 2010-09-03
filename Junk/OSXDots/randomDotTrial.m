function dotInfo = randomDotTrial(dotInfo, errorcnt)
% choose the next trial randomly, unless already chosen


%errorcnt
if dotInfo.auto(2) == 2
    dotInfo.coh = dotInfo.cohSet(ceil(rand*length(dotInfo.cohSet)))*1000; 
end

% if auto(3) == 2, then errorcnt will always be [0 0], so will always
% be random, if auto(3) == 3, check to see how many errors in current
% direction
if dotInfo.auto(3) > 1 % otherwise direction stays as it was
    % if more than 2 mistakes in same direction
    %if errorcnt(2) > 2
    if any(errorcnt > 2)
        % keep doing the same direction until the monkey gets it correct
        %disp('get it right damnit')
        dotInfo.dir = dotInfo.dirSet(find(errorcnt > 2));
        %dotInfo.dir = dotInfo.dirSet(errorcnt(1));
    else
        %disp('random')
        dotInfo.dir = dotInfo.dirSet(ceil(rand*length(dotInfo.dirSet)));
    end
end

% make time distributions - only has affect if variable distribution
dotInfo.minTime = makeInterval(dotInfo.itype,dotInfo.durTime,dotInfo.imax,dotInfo.imean);

%dot duration is always 4 if responding with mouse (not keys), for both
%reaction time (max. duration) and fixed duration, but always 4 if
%responding with keys.
if isfield(dotInfo,'keyLeft')
    dotInfo.maxDotTime = dotInfo.minTime(3);
else
    dotInfo.maxDotTime = dotInfo.minTime(4);
end

save dotInfoMatrix dotInfo
