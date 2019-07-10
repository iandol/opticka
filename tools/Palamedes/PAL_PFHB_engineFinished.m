%
%PAL_PFHB_engineFinished  Waits for Stan or JAGS to finish its work.
%   
%   syntax: [done] = PAL_PFHB_engineFinished(engine)
%
%Internal Function
%
%Introduced: Palamedes version 1.10.0 (NP)

function [done] = PAL_PFHB_engineFinished(engine)

switch engine.engine
    case 'stan'
        for chain = 1:engine.nchains
            fname = [engine.dirout,filesep,'samples',int2str(chain),'.csv'];
            while ~exist(fname,'file')
                pause(.05);
            end
            done = 0;
            fi = fopen(fname,'r');
            while ~done  
                fseek(fi,-40,'eof');   
                done = PAL_contains(fscanf(fi,'%s'),'(Total)');
                if ~done
                    pause(.05);
                end
            end
            fclose(fi);
        end
    case 'jags' 
        for chain = 1:engine.nchains
            fname = [engine.dirout,filesep,'coda',int2str(chain),'chain1.txt'];
            fname2 = [engine.dirout,filesep,'coda',int2str(chain),'index.txt'];
            while ~exist(fname,'file')  || ~exist(fname2,'file')                
                pause(.05);
            end
            done = 0;
            fi = fopen(fname2,'r');
            while ~done  
                fseek(fi,-100,'eof');   
                done = PAL_contains(fscanf(fi,'%s'),'deviance');
                if ~done
                    pause(.05);
                end
            end
            fclose(fi);
        end
        

end