%
%PAL_PFHB_runEngine  Issue OS and engine (stan, JAGS) appropriate command 
%   to OS to start MCMC sampling and wait for sampling to be finished.
%   
%   syntax: [status, OSsays, syscmd] = PAL_PFHB_runEngine(engine,machine)
%
%Internal Function
%
% Introduced: Palamedes version 1.10.0 (NP)
% Modified: Palamedes version 1.10.1 (See History.m)

function [status, OSsays, syscmd] = PAL_PFHB_runEngine(engine,machine)

if strcmp(engine.engine,'stan')
    if strcmpi(machine.machine,'PCWIN64')
        if engine.recyclestan
            enginefolder = cd;
        else
            enginefolder = engine.dirout;
        end
        for chain = 1:engine.nchains            
            syscmd = ['"',enginefolder,'\stanModel','" ',' sample num_samples=',int2str(engine.nsamples),' random seed=',int2str(engine.seed),' id=',int2str(chain),' data file="',engine.dirout,'\data_Rdump.R" init="',engine.dirout,'\Init_',int2str(chain),'.R" output file="',engine.dirout,'\samples',int2str(chain),'.csv"'];
            if engine.parallel
                syscmd = [syscmd, '  && exit &'];
            end
            [status, OSsays] = system(syscmd);
            if status ~= 0
                return;
            end
        end
    else    
        if engine.recyclestan
            enginefolder = cd;
        else
            enginefolder = engine.dirout;
        end
        for chain = 1:engine.nchains
            syscmd = [enginefolder,'/stanModel sample num_samples=',int2str(engine.nsamples),' random seed=',int2str(engine.seed),' id=',int2str(chain),' data file=',engine.dirout,'/data_Rdump.R init=',engine.dirout,'/Init_',int2str(chain),'.R  output file=',engine.dirout,'/samples',int2str(chain),'.csv'];
            if engine.parallel
                syscmd = [syscmd, ' &'];
            end
            [status, OSsays] = system(syscmd);
            if status ~= 0
                return;
            end
        end        
    end        
end

if strcmp(engine.engine,'jags')
    for chain = 1:engine.nchains
        if strcmpi(machine.machine,'PCWIN64')
            syscmd = ['"',engine.path,'\jags','" "',engine.dirout, '\jagsScript',int2str(chain),'.cmd"'];            
            if engine.parallel
                syscmd = [syscmd, '  && exit &'];
            end            
        else
            syscmd = [engine.path,'/jags ',engine.dirout, '/jagsScript',int2str(chain),'.cmd'];
            if engine.parallel
                syscmd = [syscmd, ' &'];
            end            
        end
        [status, OSsays] = system(syscmd);
        if status ~= 0
            return;
        end
    end   
end
if engine.parallel
    PAL_PFHB_engineFinished(engine);
end