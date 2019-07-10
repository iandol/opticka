%
%PAL_PFHB_writeInits  Write sampler initiation values to file
%   
%   syntax: [] = PAL_PFHB_writeInits(engine)
%
%Internal Function
%
% Introduced: Palamedes version 1.10.0 (NP)

function [] = PAL_PFHB_writeInits(engine)

    for chain = 1:engine.nchains
        fname = strcat(engine.dirout,'/Init_',int2str(chain),'.R');
        PAL_mat2Rdump(engine.inits,fname);
        
        if strcmp(engine.engine,'jags')
            fo = fopen(fname,'a');
            fprintf(fo, ['".RNG.name" <- "base::Wichmann-Hill"\n".RNG.seed" <- ',int2str(engine.seed+chain-1)]);
            fclose (fo);
        end        
    end