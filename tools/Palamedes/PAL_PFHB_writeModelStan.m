%
%PAL_PFHB_writeModelStan  Write stan model according to specifications
%   
%   syntax: [parameters] = PAL_PFHB_writeModelStan(model,engine)
%
%Internal Function
%
% Introduced: Palamedes version 1.10.0 (NP)
% Modified: Palamedes version 1.10.3 (See History.m)

function [parameters] = PAL_PFHB_writeModelStan(model,engine)

dir = engine.dirout;

%%%%%%%%%%%%%%%%data

dataText = ['data{',char(10),...
    '   int <lower = 1> Nblocks;',char(10),...
    '   int <lower = 1> Nsubj;',char(10),...
    '   vector[Nblocks] x;',char(10),...
    '   int <lower = 0>  y[Nblocks];',char(10),...
    '   int <lower = 0>  n[Nblocks];',char(10),...
    '   int <lower = 0>  s[Nblocks];',char(10),...
    '   int <lower = 0, upper = 1>  finite[Nblocks];',char(10),...
    '   int <lower = 0, upper = 1>  pInf[Nblocks];',char(10),...
    '   int <lower = 0, upper = 1>  nInf[Nblocks];',char(10),...
    '   int <lower = 0> Nca;',char(10),...
    '   int <lower = 0> Ncb;',char(10),...
    '   int <lower = 0> Ncg;',char(10),...
    '   int <lower = 0> Ncl;',char(10)'];
paramText = ['parameters{',char(10)];
modelText = ['model{',char(10),...
    '   vector[Nblocks] alpha;',char(10),...
    '   vector[Nblocks] beta;',char(10),...
    '   vector[Nblocks] gamma;',char(10),...
    '   vector[Nblocks] lambda;',char(10)];
paramCounter = 0;

        
params = {'a','b','g','l'};


for param = 1:4
    if model.(params{param}).Nc > 0
        switch params{param}
            case {'a','b'}
                lowerupper = '';
            case {'g','l'}
                lowerupper = '<lower = 0, upper = 1>';
        end
        
        if ~(strcmp(params{param},'g') & model.gammaEQlambda)                        
        
            parameters{paramCounter+1} = params{param};
            paramCounter = paramCounter+1;    
            if model.(params{param}).Nc == 1        
                dataText = [dataText,'   real ',params{param},'c[Nblocks];',char(10)];
                if model.Nsubj == 1
                    paramText = [paramText,'   real',lowerupper,' ',params{param},';',char(10)];
                else
                    paramText = [paramText,'   vector',lowerupper,'[Nsubj] ',params{param},';',char(10)];
                    paramText = [paramText,'   real',lowerupper,' ',params{param},'mu;',char(10)];
                    parameters{paramCounter+1} = [params{param},'mu'];
                    if any(strcmp(params{param},{'a','b'}))
                        paramText = [paramText,'   real<lower = 0> ',params{param},'sigma;',char(10)];
                        parameters{paramCounter+2} = [params{param},'sigma'];
                    else
                        paramText = [paramText,'   real<lower = 0> ',params{param},'kappa;',char(10)];
                        parameters{paramCounter+2} = [params{param},'kappa'];
                    end
                    paramCounter = paramCounter+2;
                end
            end
            if model.(params{param}).Nc > 1    
                dataText = [dataText,'   matrix[Nc',params{param},',Nblocks] ',params{param},'c;',char(10)];
                if model.Nsubj == 1
                    paramText = [paramText,'   vector',lowerupper,'[Nc',params{param},'] ',params{param},';',char(10)];
                else
                    paramText = [paramText,'   matrix',lowerupper,'[Nsubj,Nc',params{param},'] ',params{param},';',char(10)];
                    paramText = [paramText,'   vector',lowerupper,'[Nc',params{param},'] ',params{param},'mu;',char(10)];
                    parameters{paramCounter+1} = [params{param},'mu'];
                    if any(strcmp(params{param},{'a','b'}))
                        paramText = [paramText,'   vector<lower = 0>[Nc',params{param},'] ',params{param},'sigma;',char(10)];
                        parameters{paramCounter+2} = [params{param},'sigma'];
                    else
                        paramText = [paramText,'   vector<lower = 0>[Nc',params{param},'] ',params{param},'kappa;',char(10)];
                        parameters{paramCounter+2} = [params{param},'kappa'];
                    end
                    paramCounter = paramCounter+2;
                end
            end
        end
    end
end
        

dataText = [dataText,'}',char(10)];
paramText = [paramText,'}',char(10)];


%%%%%%%%%%%%%%%%model

paramCounter = 0;

params = {'a','b','g','l'};
for param = 1:4
    if model.(params{param}).Nc > 0
        switch lower(model.(params{param}).priorFun(1:4))
            case 'norm'
                dist_txt = 'normal';
                open_txt = '(';
            case 'tdis'
                dist_txt = 'student_t';
                open_txt = '(2,';
            case 'beta'
                dist_txt = 'beta';
                open_txt = '(';
            case 'unif'
                dist_txt = 'uniform';
                open_txt = '(';
        end        
        if model.Nsubj == 1                
            for c = 1:model.(params{param}).Nc
                if model.(params{param}).Nc == 1
                    entry_txt = '';
                else
                    entry_txt = ['[',int2str(c),']'];
                end
                modelText = [modelText,'   ',params{param},entry_txt,' ~ ',dist_txt,open_txt,num2str(model.(params{param}).priorParams(c,1)),',',num2str(model.(params{param}).priorParams(c,2)),');',char(10)];
            end
            
        else
            switch lower(model.(params{param}).priorFun(1:4))
                case 'norm'
                    param1_txt = [params{param},'mu'];
                    param2_txt = [params{param},'sigma'];
                case 'tdis'
                    param1_txt = [params{param},'mu'];
                    param2_txt = [params{param},'sigma'];
                case 'beta'
                    param1_txt = [params{param},'mu'];
                    param2_txt = [params{param},'kappa'];
            end        
            for s = 1:model.Nsubj
                for c = 1:model.(params{param}).Nc
                    if model.(params{param}).Nc == 1
                        entry_txt = ['[',int2str(s),']'];
                        entry2_txt = '';
                    else
                        entry_txt = ['[',int2str(s),',',int2str(c),']'];
                        entry2_txt = ['[',int2str(c),']'];
                    end
                    if ~strcmp(lower(model.(params{param}).priorFun(1:4)),'beta')
                        modelText = [modelText,'   ',params{param},entry_txt,' ~ ',dist_txt,open_txt,param1_txt,entry2_txt,',',param2_txt,entry2_txt,');',char(10)];
                    else
                        modelText = [modelText,'   ',params{param},entry_txt,' ~ ',dist_txt,open_txt,param1_txt,entry2_txt,'*',param2_txt,entry2_txt,',',          '(1 - ',param1_txt,entry2_txt,')*',param2_txt,entry2_txt           ,');',char(10)];
                    end
                end
            end
        end        
        paramCounter = paramCounter + 1;
        parameters{paramCounter} = params{param};
    end 
end



if model.Nsubj > 1
    params = {'a','b','g','l'};
    for param = 1:4
        if model.(params{param}).Nc > 0
            switch lower(model.(strcat(params{param},'mu')).priorFun(1:4))
                case 'norm'
                    for c = 1:model.(params{param}).Nc
                        if model.(params{param}).Nc == 1
                            entry_txt = '';
                        else
                            entry_txt = ['[',int2str(c),']'];
                        end  
                        switch lower(model.(strcat(params{param},'sigma')).priorFun(1:4))
                            case 'unif'
                                sigma_dist = 'uniform';
                            case 'gamm'
                                sigma_dist = 'gamma';
                        end
                        modelText = [modelText,'   ',params{param},'mu',entry_txt,' ~ normal(',num2str(model.(strcat(params{param},'mu')).priorParams(c,1)),',',num2str(model.(strcat(params{param},'mu')).priorParams(c,2)),');',char(10)];
                        modelText = [modelText,'   ',params{param},'sigma',entry_txt,' ~ ',sigma_dist,'(',num2str(model.(strcat(params{param},'sigma')).priorParams(c,1)),',',num2str(model.(strcat(params{param},'sigma')).priorParams(c,2)),');',char(10)];
                    end
                    paramCounter = paramCounter + 1;
                    parameters{paramCounter} = strcat(params{param},'mu');
                    paramCounter = paramCounter + 1;
                    parameters{paramCounter} = strcat(params{param},'sigma');
                case 'tdis'
                    for c = 1:model.(params{param}).Nc
                        if model.(params{param}).Nc == 1
                            entry_txt = '';
                        else
                            entry_txt = ['[',int2str(c),']'];
                        end  
                        switch lower(model.(strcat(params{param},'sigma')).priorFun(1:4))
                            case 'unif'
                                sigma_dist = 'uniform';
                            case 'gamm'
                                sigma_dist = 'gamma';
                        end                        
                        modelText = [modelText,'   ',params{param},'mu',entry_txt,' ~ student_t(2,',num2str(model.(strcat(params{param},'mu')).priorParams(c,1)),',',num2str(model.(strcat(params{param},'mu')).priorParams(c,2)),');',char(10)];
                        modelText = [modelText,'   ',params{param},'sigma',entry_txt,' ~ ',sigma_dist,'(',num2str(model.(strcat(params{param},'sigma')).priorParams(c,1)),',',num2str(model.(strcat(params{param},'sigma')).priorParams(c,2)),');',char(10)];
                    end
                    paramCounter = paramCounter + 1;
                    parameters{paramCounter} = strcat(params{param},'mu');       
                    paramCounter = paramCounter + 1;
                    parameters{paramCounter} = strcat(params{param},'sigma');            
                case 'beta'
                    for c = 1:model.(params{param}).Nc  
                        if model.(params{param}).Nc == 1
                            entry_txt = '';
                        else
                            entry_txt = ['[',int2str(c),']'];
                        end  
                        switch lower(model.(strcat(params{param},'kappa')).priorFun(1:4))
                            case 'unif'
                                kappa_dist = 'uniform';
                            case 'gamm'
                                kappa_dist = 'gamma';
                        end                                                
                        modelText = [modelText,'   ',params{param},'mu',entry_txt,' ~ beta(',num2str(model.(strcat(params{param},'mu')).priorParams(c,1)),',',num2str(model.(strcat(params{param},'mu')).priorParams(c,2)),');',char(10)];
                        modelText = [modelText,'   ',params{param},'kappa',entry_txt,' ~ ',kappa_dist,'(',num2str(model.(strcat(params{param},'kappa')).priorParams(c,1)),',',num2str(model.(strcat(params{param},'kappa')).priorParams(c,2)),');',char(10)];
                    end
                    paramCounter = paramCounter + 1;
                    parameters{paramCounter} = strcat(params{param},'mu');
                    paramCounter = paramCounter + 1;
                    parameters{paramCounter} = strcat(params{param},'kappa');
            end
        end
    end
end

modelText = [modelText,'   for(i in 1:Nblocks){',char(10)];

switch model.a.Nc
    case 0
        modelText = [modelText, '    alpha[i] = ',num2str(model.a.val),';'];    
    case 1
        if model.Nsubj == 1
            modelText = [modelText, '    alpha[i] = a*ac[i];'];
        else
            modelText = [modelText, '    alpha[i] = a[s[i]]*ac[i];'];
        end
    otherwise
        modelText = [modelText, '    alpha[i] = '];
        for c = 1:model.a.Nc
            if model.Nsubj == 1
                modelText = [modelText, 'a[',int2str(c),']*ac[',int2str(c),',i]'];
            else
                modelText = [modelText, 'a[s[i],',int2str(c),']*ac[',int2str(c),',i]'];
            end
            if c < model.a.Nc
                modelText = [modelText,'+'];
            else
                modelText = [modelText,';'];
            end
        end
end
modelText = [modelText,char(10)];

switch model.b.Nc
    case 0
        modelText = [modelText, '    beta[i] = ',num2str(model.b.val),';'];    
    case 1
        if model.Nsubj == 1
            modelText = [modelText, '    beta[i] = b*bc[i];'];
        else
            modelText = [modelText, '    beta[i] = b[s[i]]*bc[i];'];
        end
    otherwise
        modelText = [modelText, '    beta[i] = '];
        for c = 1:model.b.Nc
            if model.Nsubj == 1
                modelText = [modelText, 'b[',int2str(c),']*bc[',int2str(c),',i]'];
            else
                modelText = [modelText, 'b[s[i],',int2str(c),']*bc[',int2str(c),',i]'];
            end
            if c < model.b.Nc
                modelText = [modelText,'+'];
            else
                modelText = [modelText,';'];
            end
        end
end
modelText = [modelText,char(10)];

if model.gammaEQlambda
    switch model.l.Nc
        case 0
            modelText = [modelText, '    gamma[i] = ',num2str(model.l.val),';'];    
        case 1
            if model.Nsubj == 1
                modelText = [modelText, '    gamma[i] = l*lc[i];'];
            else
                modelText = [modelText, '    gamma[i] = l[s[i]]*lc[i];'];
            end
        otherwise
            modelText = [modelText, '    gamma[i] = '];
            for c = 1:model.l.Nc
                if model.Nsubj == 1
                    modelText = [modelText, 'l[',int2str(c),']*lc[',int2str(c),',i]'];
                else
                    modelText = [modelText, 'l[s[i],',int2str(c),']*lc[',int2str(c),',i]'];
                end
                if c < model.l.Nc
                    modelText = [modelText,'+'];
                else
                    modelText = [modelText,';'];
                end
            end
    end
else
    switch model.g.Nc
        case 0
            modelText = [modelText, '    gamma[i] = ',num2str(model.g.val),';'];    
        case 1
            if model.Nsubj == 1
                modelText = [modelText, '    gamma[i] = g*gc[i];'];
            else
                modelText = [modelText, '    gamma[i] = g[s[i]]*gc[i];'];
            end
        otherwise
            modelText = [modelText, '    gamma[i] = '];
            for c = 1:model.g.Nc
                if model.Nsubj == 1
                    modelText = [modelText, 'g[',int2str(c),']*gc[',int2str(c),',i]'];
                else
                    modelText = [modelText, 'g[s[i],',int2str(c),']*gc[',int2str(c),',i]'];
                end
                if c < model.g.Nc
                    modelText = [modelText,'+'];
                else
                    modelText = [modelText,';'];                    
                end
            end
    end
end
modelText = [modelText,char(10)];
    
switch model.l.Nc
    case 0
        modelText = [modelText, '    lambda[i] = ',num2str(model.l.val),';'];    
    case 1
        if model.Nsubj == 1
            modelText = [modelText, '    lambda[i] = l*lc[i];'];
        else
            modelText = [modelText, '    lambda[i] = l[s[i]]*lc[i];'];
        end
    otherwise
        modelText = [modelText, '    lambda[i] = '];
        for c = 1:model.l.Nc
            if model.Nsubj == 1
                modelText = [modelText, 'l[',int2str(c),']*lc[',int2str(c),',i]'];
            else
                modelText = [modelText, 'l[s[i],',int2str(c),']*lc[',int2str(c),',i]'];
            end
            if c < model.l.Nc
                modelText = [modelText,'+'];
            else
                modelText = [modelText,';'];                
            end
        end
end
modelText = [modelText,char(10)];

modelText = [modelText, '    y[i] ~ binomial(n[i],nInf[i]*gamma[i] + pInf[i]*(1 - lambda[i]) + finite[i]*(gamma[i] + (1 - gamma[i] - lambda[i])*'];


switch model.PF
    case 'logistic'
        modelText = [modelText,'(1/(1+exp(-1*10^beta[i]*(x[i]-alpha[i]))))));'];
    case 'cumulativenormal'
        modelText = [modelText,'Phi((x[i]-alpha[i])*10^beta[i])));'];
    case 'weibull'
        modelText = [modelText,'(1 - exp(-1*(x[i]/alpha[i])^10^beta[i]))));'];
    case 'gumbel'
        modelText = [modelText,'(1-exp(-1*10^(10^beta[i]*(x[i]-alpha[i]))))));'];
    case 'quick'
        modelText = [modelText,'(1 - 2^(-1*(x[i]/alpha[i])^10^beta[i]))));'];
    case 'logquick'
        modelText = [modelText,'(1-2^(-1*10^(10^beta[i]*(x[i]-alpha[i]))))));'];
    case 'hyperbolicsecant'
        modelText = [modelText,'((1/asin(1))*atan(exp((asin(1))*10^beta[i]*(x[i]-alpha[i]))))));'];
end

modelText = [modelText,char(10),'   }',char(10)];
modelText = [modelText,'}',char(10)];

fo = fopen(strcat(dir,'/stanModel.stan'),'w');
text = ['//This file was created by the Palamedes Toolbox',char(10),'//www.palamedestoolbox.org. Please cite us if you use this in research.',char(10),char(10)]; 
fprintf(fo,'%s',text);
fprintf(fo,'%s',dataText);
fprintf(fo,'%s',paramText);
fprintf(fo,'%s',modelText);
fclose(fo);