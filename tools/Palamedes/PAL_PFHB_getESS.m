%
%PAL_PFHB_getESS    Determines the effective sample size for MCMC chain.
%
%   syntax: [ess] = PAL_PFHB_getESS(sample,varargin)
%
%Input:
%
%   sample: vector containing MCMC chain
%
%Output: 
%   
%   ess: effective sample size
%
%   By default, the effective sample size is determined using batch means.
%   User may opt instead to base estimate on autocorrelation by using the
%   optional argument 'autocorrelation'.       
%
%Introduced: Palamedes version 1.10.0 (NP)
%Modified: Palamedes version 1.10.4 (See History.m)

function [ess] = PAL_PFHB_getESS(sample,varargin)

method = 2;
if ~isempty(varargin)
    valid = 0;
    if strncmpi(varargin{1}, 'autocorrelation',3)
        method = 1;
        valid = 1;
    end
    if strncmpi(varargin{1}, 'batch',3)
        method = 2;
        valid = 1;
    end
    if valid == 0
        warning('PALAMEDES:invalidOption','%s is not a valid option. Ignored.',varargin{1});
    end
end

if method == 1      %autocorrelation method
    for chain = 1:size(sample,1)
        autoc = [];
        lag = 0;
        cc = ones(2);
        while cc(1,2) > .05
            lag = lag + 1;
            cc = corrcoef(sample(chain,1:(end-lag)),sample(chain,(1+lag):end));
            autoc(lag) = cc(1,2);
        end
        if lag > 1
            ESSa(chain) = length(sample(chain,:))/(1 + 2*sum(autoc));
        else
            ESSa(chain) = length(sample(chain,:));
        end
    end
    ess = sum(ESSa);
else                %batch method
    batchsize = 100;
    for chain = 1:size(sample,1)
        for batch = 1:floor(length(sample(chain,:))/batchsize)
            mbatch(batch) = mean(sample(chain,(batch-1)*batchsize+1:batch*batchsize));
        end
        ESSb(chain) = length(sample(chain,:))*var(sample(chain,:))/(batchsize*var(mbatch));
    end
    ess = sum(ESSb);
end