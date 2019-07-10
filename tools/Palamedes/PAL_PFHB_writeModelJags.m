%
%PAL_PFHB_writeModelJags  Write JAGS model according to specifications
%   
%   syntax: [parameters] = PAL_PFHB_writeModelJags(model,engine)
%
%Internal Function
%
% Introduced: Palamedes version 1.10.0 (NP)

function [parameters] = PAL_PFHB_writeModelJags(model,engine)

dir = engine.dirout;

text = ['#This file was created by the Palamedes Toolbox',char(10),'#www.palamedestoolbox.org. Please cite us if you use this in research.',char(10),char(10)]; 

switch model.PF
    case 'logistic'
        modelText = '(1/(1+exp(-1*10^beta[i]*(x[i]-alpha[i])))))';
    case 'cumulativenormal'
        modelText = 'pnorm((x[i]-alpha[i])*10^beta[i],0,1))';
    case 'weibull'
        modelText = '(1 - exp(-1*(x[i]/alpha[i])^10^beta[i])))';
    case 'gumbel'
        modelText = '(1-exp(-1*10^(10^beta[i]*(x[i]-alpha[i])))))';
    case 'quick'
        modelText = '(1 - 2^(-1*(x[i]/alpha[i])^10^beta[i])))';
    case 'logquick'
        modelText = '(1-2^(-1*10^(10^beta[i]*(x[i]-alpha[i])))))';
    case 'hyperbolicsecant'
        modelText = '((1/asin(1))*atan(exp((asin(1))*10^beta[i]*(x[i]-alpha[i])))))';
end

modelText = ['nInf[i]*gamma[i] + pInf[i]*(1 - lambda[i]) + finite[i]*(gamma[i] + (1 - gamma[i] - lambda[i])*',modelText];

text = [text,'model{',char(10),'for(i in 1:Nblocks){',char(10)];

switch model.a.Nc
    case 0
        text = [text, '    alpha[i] = ',num2str(model.a.val)];    
    case 1
        if model.Nsubj == 1
            text = [text, '    alpha[i] = a*ac[i]'];
        else
            text = [text, '    alpha[i] = a[s[i]]*ac[i]'];
        end
    otherwise
        text = [text, '    alpha[i] = '];
        for c = 1:model.a.Nc
            if model.Nsubj == 1
                text = [text, 'a[',int2str(c),']*ac[',int2str(c),',i]'];
            else
                text = [text, 'a[s[i],',int2str(c),']*ac[',int2str(c),',i]'];
            end
            if c < model.a.Nc
                text = [text,'+'];
            end
        end
end
text = [text,char(10)];

switch model.b.Nc
    case 0
        text = [text, '    beta[i] = ',num2str(model.b.val)];    
    case 1
        if model.Nsubj == 1
            text = [text, '    beta[i] = b*bc[i]'];
        else
            text = [text, '    beta[i] = b[s[i]]*bc[i]'];
        end
    otherwise
        text = [text, '    beta[i] = '];
        for c = 1:model.b.Nc
            if model.Nsubj == 1
                text = [text, 'b[',int2str(c),']*bc[',int2str(c),',i]'];
            else
                text = [text, 'b[s[i],',int2str(c),']*bc[',int2str(c),',i]'];
            end
            if c < model.b.Nc
                text = [text,'+'];
            end
        end
end
text = [text,char(10)];

if model.gammaEQlambda
    switch model.l.Nc
        case 0
            text = [text, '    gamma[i] = ',num2str(model.l.val)];    
        case 1
            if model.Nsubj == 1
                text = [text, '    gamma[i] = l*lc[i]'];
            else
                text = [text, '    gamma[i] = l[s[i]]*lc[i]'];
            end
        otherwise
            text = [text, '    gamma[i] = '];
            for c = 1:model.l.Nc
                if model.Nsubj == 1
                    text = [text, 'l[',int2str(c),']*lc[',int2str(c),',i]'];
                else
                    text = [text, 'l[s[i],',int2str(c),']*lc[',int2str(c),',i]'];
                end
                if c < model.l.Nc
                    text = [text,'+'];
                end
            end
    end
else
    switch model.g.Nc
        case 0
            text = [text, '    gamma[i] = ',num2str(model.g.val)];    
        case 1
            if model.Nsubj == 1
                text = [text, '    gamma[i] = g*gc[i]'];
            else
                text = [text, '    gamma[i] = g[s[i]]*gc[i]'];
            end
        otherwise
            text = [text, '    gamma[i] = '];
            for c = 1:model.g.Nc
                if model.Nsubj == 1
                    text = [text, 'g[',int2str(c),']*gc[',int2str(c),',i]'];
                else
                    text = [text, 'g[s[i],',int2str(c),']*gc[',int2str(c),',i]'];
                end
                if c < model.g.Nc
                    text = [text,'+'];
                end
            end
    end
end
text = [text,char(10)];
    
switch model.l.Nc
    case 0
        text = [text, '    lambda[i] = ',num2str(model.l.val)];    
    case 1
        if model.Nsubj == 1
            text = [text, '    lambda[i] = l*lc[i]'];
        else
            text = [text, '    lambda[i] = l[s[i]]*lc[i]'];
        end
    otherwise
        text = [text, '    lambda[i] = '];
        for c = 1:model.l.Nc
            if model.Nsubj == 1
                text = [text, 'l[',int2str(c),']*lc[',int2str(c),',i]'];
            else
                text = [text, 'l[s[i],',int2str(c),']*lc[',int2str(c),',i]'];
            end
            if c < model.l.Nc
                text = [text,'+'];
            end
        end
end
text = [text,char(10)];

text = [text, '    y[i] ~ dbin(',modelText,',n[i])',char(10)];


text = [text,'}',char(10)];

paramCounter = 0;

params = {'a','b','g','l'};
for param = 1:4
    if model.(params{param}).Nc > 0
        if model.Nsubj == 1    
            switch lower(model.(params{param}).priorFun(1:4))
                case 'norm'
                    for c = 1:model.(params{param}).Nc
                        text = [text , params{param},'[',int2str(c),'] ~ dnorm(' , num2str(model.(params{param}).priorParams(c,1)) , ',' , num2str(1/model.(params{param}).priorParams(c,2).^2) , ')' , char(10)];
                    end
                case 'tdis'
                    for c = 1:model.(params{param}).Nc
                        text = [text , params{param},'[',int2str(c),'] ~ dt(' , num2str(model.(params{param}).priorParams(c,1)) , ',' , num2str(1/model.(params{param}).priorParams(c,2).^2), ',2)' , char(10)];
                    end
                case 'beta'
                    for c = 1:model.(params{param}).Nc
                        text = [text , params{param},'[',int2str(c),'] ~ dbeta(' , num2str(model.(params{param}).priorParams(c,1)*model.(params{param}).priorParams(c,2)) , ',' , num2str((1-model.(params{param}).priorParams(c,1))*model.(params{param}).priorParams(c,2)) , ')' , char(10)];
                    end
                case 'unif'
                    for c = 1:model.(params{param}).Nc
                        text = [text , params{param},'[',int2str(c),'] ~ dunif(' , num2str(model.(params{param}).priorParams(c,1)) , ',' , num2str(model.(params{param}).priorParams(c,2)) , ')' , char(10)];
                    end
            end
        else
            
            text = [text,'for(s in 1:Nsubj){',char(10)];
            if model.(params{param}).Nc > 1       
                text = [text,'    for(c in 1:Nc',params{param},'){',char(10)];
                text = [text,'        ',params{param},'[s,c] ~ '];
                indexText = '[c]';
            else
                text = [text,'    ',params{param},'[s] ~ '];
                indexText = '';
            end
            switch lower(model.(params{param}).priorFun(1:4))
                case 'norm'
                        text = [text , 'dnorm(',params{param},'mu',indexText,',1/',params{param},'sigma',indexText,'^2)' , char(10)];
                case 'tdis'
                        text = [text , 'dt(',params{param},'mu',indexText,',1/',params{param},'sigma',indexText,'^2,2)' , char(10)];
                case 'beta'
                        text = [text , 'dbeta(',params{param},'mu',indexText,'*',params{param},'kappa',indexText,',(1-',params{param},'mu',indexText,')*',params{param},'kappa',indexText,')' , char(10)];
            end
            if model.(params{param}).Nc > 1       
                text = [text,'    }',char(10),'}',char(10)];
            else
                text = [text,'}',char(10)];
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
                        text = [text,params{param},'mu[',int2str(c),'] ~ dnorm(' , num2str(model.(strcat(params{param},'mu')).priorParams(c,1)) , ',' , num2str(1/model.(strcat(params{param},'mu')).priorParams(c,2).^2) , ')',char(10)];
                        text = [text,params{param},'sigma[',int2str(c),'] ~ d',model.(strcat(params{param},'sigma')).priorFun,'(' , num2str(model.(strcat(params{param},'sigma')).priorParams(c,1)) , ',' , num2str(model.(strcat(params{param},'sigma')).priorParams(c,2)) , ')',char(10)];
                    end
                    paramCounter = paramCounter + 1;
                    parameters{paramCounter} = strcat(params{param},'mu');
                    paramCounter = paramCounter + 1;
                    parameters{paramCounter} = strcat(params{param},'sigma');
                case 'tdis'
                    for c = 1:model.(params{param}).Nc
                        text = [text,params{param},'mu[',int2str(c),'] ~ dt(' , num2str(model.(strcat(params{param},'mu')).priorParams(c,1)) , ',' , num2str(1/model.(strcat(params{param},'mu')).priorParams(c,2).^2), ',2)',char(10)];
                        text = [text,params{param},'sigma[',int2str(c),'] ~ d',model.(strcat(params{param},'sigma')).priorFun,'(' , num2str(model.(strcat(params{param},'sigma')).priorParams(c,1)) , ',' , num2str(model.(strcat(params{param},'sigma')).priorParams(c,2)) , ')',char(10)];
                    end
                    paramCounter = paramCounter + 1;
                    parameters{paramCounter} = strcat(params{param},'mu');       
                    paramCounter = paramCounter + 1;
                    parameters{paramCounter} = strcat(params{param},'sigma');            
                case 'beta'
                    for c = 1:model.(params{param}).Nc
                        text = [text,params{param},'mu[',int2str(c),'] ~ dbeta(' , num2str(model.(strcat(params{param},'mu')).priorParams(c,1)*model.(strcat(params{param},'mu')).priorParams(c,2)) , ',' , num2str((1-model.(strcat(params{param},'mu')).priorParams(c,1))*model.(strcat(params{param},'mu')).priorParams(c,2)) , ')',char(10)];
                        text = [text,params{param},'kappa[',int2str(c),'] ~ d',model.(strcat(params{param},'kappa')).priorFun,'(' , num2str(model.(strcat(params{param},'kappa')).priorParams(c,1)) , ',' , num2str(model.(strcat(params{param},'kappa')).priorParams(c,2)) , ')',char(10)];
                    end
                    paramCounter = paramCounter + 1;
                    parameters{paramCounter} = strcat(params{param},'mu');
                    paramCounter = paramCounter + 1;
                    parameters{paramCounter} = strcat(params{param},'kappa');
            end
        end
    end
end
text = [text,'}']; 

fo = fopen(strcat(dir,'/jagsModel.txt'),'w');
fprintf(fo,'%s',text);
fclose(fo);