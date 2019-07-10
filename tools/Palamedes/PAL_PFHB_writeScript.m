%
%PAL_PFHB_PAL_PFHB_writeScript  Write script for JAGS
%   
%   syntax: [] = PAL_PFHB_writeScript(engine,model)
%
%Internal Function
%
% Introduced: Palamedes version 1.10.0 (NP)

function [] = PAL_PFHB_writeScript(engine,model)

for chain = 1:engine.nchains
    
    fo = fopen(strcat(engine.dirout,filesep,'jagsScript',int2str(chain),'.cmd'),'w');

    fprintf(fo, '%s\n','load dic');
    fprintf(fo, '%s\n',['model in "',engine.dirout,filesep,'jagsModel.txt"']);
    fprintf(fo, '%s\n',['data in "',engine.dirout,'/data_Rdump.R"']);
    fprintf(fo, '%s\n','compile, nchains(1)');
    fprintf(fo, '%s\n',['parameters in "',engine.dirout,'/Init_',int2str(chain),'.R", chain(1)']);
    fprintf(fo, '%s\n','initialize');
    fprintf(fo, '%s\n',['adapt ',int2str(engine.nadapt)]);
    fprintf(fo, '%s\n',['update ',int2str(engine.nburnin)]);
    for index = 1:length(model.parameters)
        fprintf(fo, '%s\n',['monitor ',model.parameters{index}]);
    end
    fprintf(fo, '%s\n','monitor deviance');
    fprintf(fo, '%s\n',['update ',int2str(engine.nsamples)]);
    fprintf(fo, '%s\n',['coda *, stem("',engine.dirout,'/coda',int2str(chain),'")']);
    fprintf(fo, '%s\n','exit');
    fclose(fo);

end