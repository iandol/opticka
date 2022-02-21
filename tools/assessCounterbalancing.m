function outputMatrix = assessCounterbalancing(conditionOrder)

% result = assessCounterbalancing(conditionOrder)
%
% This function accepts an ordered array of integers with each unique integer
% representing a different experimental condition. It assesses whether the
% sequence of conditions is counterbalanced for serial order carryover
% effects to the 1st-order, i.e. for first order counterbalancing, is each
% condition preceded by every other condition equally often.
%
% INPUT:
% - conditionOrder: an ordered list of integers with each integer
% representing one condition. 
%
% OUTPUT:
% -outputMatrix: square matrix which represents the counterbalancing of
% conditions. The first dimension of the matrix represents trial n-1 and
% the second dimension represents trial n. Position Aij in the matrix
% represents how many times condition j is preceded by condition i
%
% by Joseph Brooks, 2011, University College London
% Version 1.0 29.2.2012
% brooks.jl@gmail.com

outputMatrix = zeros(length(unique(conditionOrder)),length(unique(conditionOrder)));

for i = 2:length(conditionOrder)
    outputMatrix(conditionOrder(i-1),conditionOrder(i)) = outputMatrix(conditionOrder(i-1),conditionOrder(i)) + 1;
end