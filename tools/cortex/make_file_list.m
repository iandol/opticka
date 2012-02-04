function [dirout,num]=make_file_list(input)
%function [dirout,num]=make_file_list(input)

% B Jagadeesh
% 2/19/98
% Reads a directory and types it to the screen.
% Needs an input that contains the pathname of the directory,
% and any wild cards desired (for example, 'c:\matlab\mfiles\id*.*')
dirout=[];
d=dir(input)
[num dum]=size(d)

for i=1:num
   disp(d(i).name);
   dirout=strvcat(dirout,d(i).name);
end
