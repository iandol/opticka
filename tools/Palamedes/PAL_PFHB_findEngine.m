%
%PAL_PFHB_findEngine  Find path to Stan or Jags
%   
%   syntax: [engine] = PAL_PFHB_findEngine(engine,machine)
%
%Internal Function
%
% Introduced: Palamedes version 1.10.0 (NP)
% Modified: Palamedes version 1.10.1, 1.10.2 (see History.m)

function [engine] = PAL_PFHB_findEngine(engine,machine)

%linux, mac, jags
if strcmpi(engine.engine,'jags') && any(strcmpi(machine.machine,{'MACI64','GLNXA64'}))
    if exist('/usr/bin/jags','file')
        engine.path = '/usr/bin';
        engine.found = true;
    elseif exist('/usr/local/bin/jags','file')
        engine.path = '/usr/local/bin';
        engine.found = true;
    end
end

%linux, mac, stan
if strcmpi(engine.engine,'stan') && any(strcmpi(machine.machine,{'MACI64','GLNXA64'}))
    if engine.recyclestan && exist('stanmodel','file')
        engine.found = true;
        engine.path = pwd;
    else
        list = '/usr/local /usr/local/bin /user/bin /opt';
        [engine.found, engine.path] = PAL_PFHB_findStaninFolderList(list,1,machine);
        if ~engine.found
            list = pwd;
            if strcmpi(machine.machine,'GLNXA64')
                pos = strfind(list,'home');
                username = list(pos+5:find(list(pos+6:end)==filesep,1)+6);
                list = ['/home/',username];
            else
                pos = strfind(list,'Users');
                username = list(pos+6:find(list(pos+7:end)==filesep,1)+7);
                list = ['/Users/',username];
            end                
            [engine.found,engine.path] = PAL_PFHB_findStaninFolderList(list,4,machine);
        end
    end
end

%windows, jags
if strcmpi(engine.engine,'jags') && strcmpi(machine.machine,'PCWIN64')
    %look in Windows PATH variable first...
    [trash,paths] = system('path');
    inpath = strfind(paths,'JAGS');
    if ~isempty(inpath)
        pathseparators = strfind(paths,';');
        find(pathseparators < inpath(1),1,'last');
        find(pathseparators > inpath(1),1,'first');
        engine.path = paths(pathseparators(find(pathseparators < inpath(1),1,'last'))+1:pathseparators(find(pathseparators > inpath(1),1,'first'))-1);
        if exist(engine.path,'file')
            engine.found = true;
        end
    else
        disp(['Did not find a valid JAGS path in Windows PATH variable, will attempt to find JAGS myself.',char(10),'To improve speed (slightly), consider adding JAGS path to Windows PATH variable or use ''enginepath''',char(10),'argument (type help PAL_PFHB_fitModel)']);
    end
    if ~engine.found
        potentialdir = pwd;
        separators = find(potentialdir == filesep);
        potentialdir = [potentialdir(1:separators(3)-1) '\AppData\Local\JAGS'];
        [engine.found, engine.path] = PAL_PFHB_findJagsinFolder(potentialdir);
    end
    if ~engine.found        
        potentialdir = 'c:\Program Files\JAGS';
        [engine.found, engine.path] = PAL_PFHB_findJagsinFolder(potentialdir);
    end    
end

%windows, stan
if strcmpi(engine.engine,'stan') && strcmpi(machine.machine,'PCWIN64')
    %look in Windows PATH variable first...
    [trash,paths] = system('path');
    inpath = strfind(paths,'cmdstan');
    if ~isempty(inpath) 
        pathseparators = strfind(paths,';');
        find(pathseparators < inpath(1),1,'last');
        find(pathseparators > inpath(1),1,'first');
        engine.path = paths(pathseparators(find(pathseparators < inpath(1),1,'last'))+1:pathseparators(find(pathseparators > inpath(1),1,'first'))-1);
        if exist(engine.path,'file')
            engine.found = true;
        end
    else
        disp(['Did not find a valid Stan path in Windows PATH variable, will attempt to find Stan myself.',char(10),'This will take a while. To improve speed, consider adding Stan path to Windows PATH variable or use ''enginepath''',char(10),'argument (type help PAL_PFHB_fitModel)']);
        [engine.found, engine.path] = PAL_PFHB_findStaninFolderList('c:\',[],machine);
    end
end

if engine.found
    disp(['Found MCMC sampler (or a way to build it) here: ',char(10),engine.path,char(10),'and will use it. This may not be the latest version that is installed. Type ''help PAL_PFHB_fitModel'' for suggestions.']);
else
    disp('Could not find MCMC sampler (or a way to build it). Type ''help PAL_PFHB_fitModel'' for suggestions.');
end
