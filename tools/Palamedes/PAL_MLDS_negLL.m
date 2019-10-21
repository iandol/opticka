%
%PAL_MLDS_negLL (negative) Log Likelihood for MLDS fit.
%
%syntax: [negLL] = PAL_MLDS_negLL(FreeParams, stim, NumGreater, OutOfNum)
%
%Internal function
%
%Introduced: Palamedes version 1.0.0 (NP)
%Modified: Palamedes version 1.9.0 (see History.m)

function [negLL] = PAL_MLDS_negLL(FreeParams, stim, NumGreater, OutOfNum, varargin)

param = 0;

sdfactor = 1;

if ~isempty(varargin)
    NumOpts = length(varargin);
    for n = 1:2:NumOpts
        valid = 0;
        if strncmpi(varargin{n}, 'parameterization',5)
            if strncmpi(varargin{n+1}, 'devinck',3)
                if size(stim,2) == 2
                    sdfactor = sqrt(2);
                else
                    sdfactor = 2;
                end
                param = 1;
            end
            valid = 1;
        end
        if valid == 0
            warning('PALAMEDES:invalidOption','%s is not a valid option. Ignored.',varargin{n});
        end        
    end            
end

if param
    PsiValues = [0 FreeParams(1:length(FreeParams))];
    SDnoise = 1;
else
    PsiValues = [0 FreeParams(1:length(FreeParams)-1) 1];
    SDnoise = FreeParams(length(FreeParams));    
end

if size(stim,2) == 4
    D = (PsiValues(stim(:,2))-PsiValues(stim(:,1)))-(PsiValues(stim(:,4))-PsiValues(stim(:,3)));
end
if size(stim,2) == 3
    D = (PsiValues(stim(:,2))-PsiValues(stim(:,1)))-(PsiValues(stim(:,3))-PsiValues(stim(:,2)));
end
if size(stim,2) == 2
    D = (PsiValues(stim(:,1))-PsiValues(stim(:,2)));
end
    
Z_D = D./(SDnoise*sdfactor);
pFirst = .5 + .5*(1-erfc(Z_D./sqrt(2)));

negLL = -sum(NumGreater(NumGreater > 0).*log(pFirst(NumGreater > 0)))-sum((OutOfNum(NumGreater < OutOfNum)-NumGreater(NumGreater < OutOfNum)).*log(1-pFirst(NumGreater < OutOfNum)));