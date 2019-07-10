%
%PAL_PFHB_buildStan  Issues OS-appropriate directive to build executable
%   Stan model
%
%   syntax: [syscmd] = PAL_PFHB_buildStan(engine,machine)
%
%Internal function
%
%Introduced: Palamedes version 1.10.0 (NP)

function [syscmd] = PAL_PFHB_buildStan(engine,machine)

if strcmpi(machine.machine,'PCWIN64')
    dirout = engine.dirout;
    dirout(dirout == '\') = '/';
    syscmd = ['cd ',engine.path,' && ','make ',dirout,'/stanModel.exe'];
    system(syscmd);
    if strcmp(engine.engine,'stan') && engine.recyclestan && ~exist('stanModel.exe','file')
        copyfile([engine.dirout,filesep,'stanModel.exe']);
    end
else
    syscmd = ['cd ',engine.path,char(10),'make ',engine.dirout,'/stanModel',char(10)];
    system(syscmd);
    if strcmp(engine.engine,'stan') && engine.recyclestan && ~exist('stanModel','file')
        copyfile([engine.dirout,filesep,'stanModel']);
    end
end