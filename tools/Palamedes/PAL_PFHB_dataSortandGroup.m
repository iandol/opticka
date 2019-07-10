%
%PAL_PFHB_dataSortandGroup    Combines and sorts like trials (i.e., those 
%   with identical entries in .x, .s, and .c fields) in data structure 
%   containing fields .x, (stimulus levels), .y (number of positive 
%   responses), .n (number of trials), .s (integer [1:Number of subjects] 
%   identifying subject), and .c (integer [1:Number of conditions] 
%   identifying subject).
%
%syntax: [data] = PAL_PFHB_dataSortandGroup(data)
%
%example:
%
% data.s = [1 2 2 2 2 2 1 2];
% data.c = [1 1 1 2 2 2 1 2];
% data.x = [2 9 2 7 5 3 3 3];
% data.y = [2 4 1 1 8 6 3 1];
% data.n = [7 6 4 5 9 8 8 2];
%
% data = PAL_PFHB_dataSortandGroup(data)
%
% data = 
% 
%   struct with fields:
% 
%     s: [1 1 2 2 2 2 2]
%     c: [1 1 1 1 2 2 2]
%     x: [2 3 2 9 3 5 7]
%     y: [2 3 1 4 7 8 1]
%     n: [7 8 4 6 10 9 5]
% 
%Introduced: Palamedes version 1.10.0 (NP)

function [dataSandG] = PAL_PFHB_dataSortandGroup(data)

if ~isfield(data,'s')
    data.s = ones(size(data.x));
end
if ~isfield(data,'c')
    data.c = ones(size(data.x));
end

dataSandG.s = [];
dataSandG.c = [];
dataSandG.x = [];
dataSandG.y = [];
dataSandG.n = [];

for s = 1:max(data.s)
    for c = 1:max(data.c)
        x = data.x(data.s == s & data.c == c);
        y = data.y(data.s == s & data.c == c);
        n = data.n(data.s == s & data.c == c);
        [x, y, n] = PAL_PFML_GroupTrialsbyX(x,y,n);
        dataSandG.s = [dataSandG.s s*ones(size(x))];
        dataSandG.c = [dataSandG.c c*ones(size(x))];
        dataSandG.x = [dataSandG.x x];
        dataSandG.y = [dataSandG.y y];
        dataSandG.n = [dataSandG.n n];
    end
end