%
%PAL_PFHB_organizeSamples  Resizes MCMC samples to appropriate sizes and
%   creates a messssage listing the sampled and derived parameters.
%
%   syntax: [pfhb] = PAL_PFHB_organizeSamples(pfhb)
%
%   Internal function
%
%Introduced: Palamedes version 1.10.0 (NP)

function [pfhb] = PAL_PFHB_organizeSamples(pfhb)

paramList = ['Directly estimated model parameters:',char(10)];

someDerived = false;
paramCount = 0;    

for param = pfhb.model.parameters
    switch param{1}
        case 'a' 
            rows = pfhb.model.a.Nc;
            columns = pfhb.model.Nsubj;
            paramList = [paramList, '''a'' (location (''threshold''): '];
            listSubjects = true;
        case 'b' 
            rows = pfhb.model.b.Nc;
            columns = pfhb.model.Nsubj;
            paramList = [paramList, '''b'' (log(slope)): '];
            listSubjects = true;
        case 'g' 
            paramList = [paramList, '''g'' (lower asymptote (''guess'')): '];
            listSubjects = true;
            rows = pfhb.model.g.Nc;
            columns = pfhb.model.Nsubj;
        case 'l' 
            paramList = [paramList, '''l'' (1 - upper asymptote (''lapse'')): '];
            listSubjects = true;
            rows = pfhb.model.l.Nc;
            columns = pfhb.model.Nsubj;
        case 'amu' 
            paramList = [paramList, '''amu'' (mean of location): '];
            listSubjects = false;
            rows = pfhb.model.a.Nc;
            columns = 1;
        case 'asigma' 
            paramList = [paramList, '''asigma'' (sd of location): '];
            listSubjects = false;
            rows = pfhb.model.a.Nc;
            columns = 1;
        case 'anu' 
            paramList = [paramList, '''anu'' (df of location distribution): '];
            listSubjects = false;
            rows = pfhb.model.a.Nc;
            columns = 1;
        case 'bmu' 
            paramList = [paramList, '''bmu'' (mean of log(slope)): '];
            listSubjects = false;
            rows = pfhb.model.b.Nc;
            columns = 1;
        case 'bsigma' 
            paramList = [paramList, '''bsigma'' (sd of log(slope)): '];
            listSubjects = false;
            rows = pfhb.model.b.Nc;
            columns = 1;
        case 'bnu' 
            paramList = [paramList, '''bnu'' (df of log(slope) distribution): '];
            listSubjects = false;
            rows = pfhb.model.a.Nc;
            columns = 1;
        case 'gmu' 
            paramList = [paramList, '''gmu'' (mean of lower asymptote): '];
            listSubjects = false;
            rows = pfhb.model.g.Nc;
            columns = 1;
        case 'gkappa' 
            paramList = [paramList, '''gkappa'' (''concentration'' of lower asymptote): '];
            listSubjects = false;
            rows = pfhb.model.g.Nc;
            columns = 1;
        case 'lmu' 
            paramList = [paramList, '''lmu'' (mean of [1 - upper asymptote]): '];
            listSubjects = false;
            rows = pfhb.model.l.Nc;
            columns = 1;
        case 'lkappa' 
            paramList = [paramList, '''lkappa'' (''concentration'' of [1 -upper asymptote]): '];
            listSubjects = false;
            rows = pfhb.model.l.Nc;
            columns = 1;
        case 'deviance'
            rows = 1;
            columns = 1;
    end
    pfhb.samples.(param{1}) = reshape(pfhb.samples.(param{1}),[pfhb.engine.nchains pfhb.engine.nsamples rows columns]);
    paramCount = paramCount + rows*columns;
    if listSubjects
        paramList = [paramList, int2str(columns),' subjects x '];
    end
    paramList = [paramList, int2str(rows)];
    switch PAL_mmType(pfhb.model.(param{1}(1)).c)
        case 1
            paramList = [paramList, ' conditions',char(10)];
        case {2,3,4}
            paramList = [paramList, ' effects',char(10)];
    end
    
    if (strcmp(param{1},'a') || strcmp(param{1},'b') || strcmp(param{1},'g') || strcmp(param{1},'l') || strcmp(param{1},'amu') || strcmp(param{1},'bmu') || strcmp(param{1},'gmu') || strcmp(param{1},'lmu')) && PAL_mmType(pfhb.model.(param{1}(1)).c) ~= 1
        if ~someDerived
            paramListDerived = ['Derived:',char(10)];
            someDerived = true;
        end
        if strcmp(param{1},'a') || strcmp(param{1},'b') || strcmp(param{1},'g') || strcmp(param{1},'l')
            paramListDerived = [paramListDerived, param{1},'_actual: ', int2str(pfhb.model.Nsubj), ' subjects x ', int2str(pfhb.model.Ncond), ' conditions',char(10)]; 
            for chain = 1:pfhb.engine.nchains
                for sample = 1:pfhb.engine.nsamples
                    for subject = 1:pfhb.model.Nsubj                    
                        pfhb.samples.(strcat(param{1},'_actual'))(chain,sample,:,subject) = squeeze(pfhb.samples.(param{1})(chain,sample,:,subject))'*pfhb.model.(param{1}).cTtoP;
                    end
                end
            end
        else
            paramListDerived = [paramListDerived, param{1},'_actual: ', int2str(pfhb.model.Ncond), ' conditions',char(10)]; 
            for chain = 1:pfhb.engine.nchains
                for sample = 1:pfhb.engine.nsamples
                    pfhb.samples.(strcat(param{1},'_actual'))(chain,sample,:) = squeeze(pfhb.samples.(param{1})(chain,sample,:))'*pfhb.model.(param{1}(1)).cTtoP;
                end
            end
        end            
    end   
    
end

paramList = [int2str(paramCount),' ',paramList];
if someDerived
    paramList = [paramList, paramListDerived];
end
pfhb.model.paramsList = paramList;

end

