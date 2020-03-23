%
%PAL_PFHB_findStaninFolderList  Find Stan in (list of) given folder.
%   
%   syntax: [found, path] = PAL_PFHB_findStaninFolderList(list,maxdepth,machine)
%
%Internal Function
%
% Introduced: Palamedes version 1.10.0 (NP)
% Modified: Palamedes version 1.10.1 (see History.m)


function [found, path] = PAL_PFHB_findStaninFolderList(list,maxdepth,machine)

path = [];
found = false;

if any(strcmpi(machine.machine,{'MACI64','GLNXA64'}))
    paths = [];
    [notfound,paths] = system(['find ',list,' -maxdepth ',int2str(maxdepth),' -name "cmdstan-[0-9].*" -type d']);  
    pos = strfind(paths,'cmdstan-');
    if ~isempty(pos)
        newls = [0 strfind(paths,char(10))];
        if length(newls) == 2
            path = paths;
            found = true;
        else
            potpathno = 0;
            for line = 1:length(newls)-1
                potpath = paths(newls(line)+1:newls(line+1));
                if ~strcmp(potpath(1:4),'find')
                    potpathno = potpathno+1;
                    path{potpathno} = potpath;                    
                    versions(potpathno,:) = sscanf(potpath(strfind(potpath,'cmdstan-'):end-1),'cmdstan-%d.%d.%d')';
                end
            end
            [trash, I] = sortrows(versions,[-1 -2 -3]);
            path = char(path(I(1)));
            found = true;
        end
    end
else
    [notfound,paths] = system(['dir ',list,'*runCmdStanTests.py /s /b']);
    if ~notfound
        newls = [0 strfind(paths,char(10))];
        potpathno = 0;
        for line = 1:length(newls)-1
            potpath = paths(newls(line)+1:newls(line+1));
            potpath = potpath(1:find(potpath == '\',1,'last'));
            potpathno = potpathno+1;
            path{potpathno} = potpath;                    
            versions(potpathno,:) = sscanf(potpath(strfind(potpath,'cmdstan-'):end-1),'cmdstan-%d.%d.%d')';
        end
        [trash, I] = sortrows(versions,[-1 -2 -3]);
        path = char(path(I(1)));
        found = true;
    end
end