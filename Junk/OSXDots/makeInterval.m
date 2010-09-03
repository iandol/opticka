function interval = makeInterval(typeInt,minNum,maxNum,meanNum)
% interval = makeInterval(typeInt,minNum,maxNum,meanNum)
% typeInt = 0 fixed delay, minNum is actual delay time (need minNum)
% typeInt = 1 uniform distribution (need minNum and maxNum)
% typeInt = 2 exponential distribution (need all three)
% minNum = minimum value
% maxNum = maximum value
% meanNum = mean of distribution
% MKMK March 2006
typeInt;
minNum;

sizeNum = size(minNum);
sizeInt = length(minNum);
interval = zeros(sizeNum);

if typeInt == 0
    interval(:) = minNum;
elseif typeInt == 1
    interval(:) = minNum + (maxNum - minNum).*rand(sizeInt,1);
elseif typeInt == 2
    interval(:) = maxNum + 1;
    while interval > maxNum
        interval = minNum + exprnd(meanNum,sizeInt,1);
    end    
end
