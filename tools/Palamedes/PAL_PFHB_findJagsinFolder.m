%
%PAL_PFHB_findJagsinFolder  Find most recent version of JAGS in given
%   folder.
%   
%   syntax: [found, path] = PAL_PFHB_findJagsinFolder(potentialdir)
%
%Internal Function
%
% Introduced: Palamedes version 1.10.0 (NP)

function [found, path] = PAL_PFHB_findJagsinFolder(potentialdir)

found = false;
path = [];

if exist(potentialdir,'file')
    dirlist = dir(potentialdir);
    potpathno = 0;
    for entry = 1:length(dirlist)
        if length(dirlist(entry).name) >= 5 && strcmp(dirlist(entry).name(1:5),'JAGS-')
            potpathno = potpathno+1;
            versions(potpathno,:) = sscanf(dirlist(entry).name,'JAGS-%d.%d.%d')';
            path{potpathno} = strcat(dirlist(entry).name);
        end
    end
    if potpathno > 0
        [trash, I] = sortrows(versions,[-1 -2 -3]);
        path = strcat(potentialdir,filesep,char(path(I(1))),'\x64\bin');
        found = true;
    end
end