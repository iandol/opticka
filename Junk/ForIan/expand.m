% function to repeat any given input matrix 3 times for single subject analysis
% used for final hetsearch study where 12 subjects were used each with 3 scans

function [output] = expand(input, no_repeats);

temp = [];
for eachrepeat = 1:no_repeats;
   temp = [temp,input];
end

output = temp;
clear temp;

