%
%PAL_PFBA_Fit_OldStyle   Fit threshold and slope parameters of psychometric 
%   function using Bayesian criterion. Old version of PAL_PFBA_Fit.m.
%   Obsolete starting version 1.8.1. This function is invoked when users 
%   use the new PAL_PFBA_Fit using 'old style' arguments.
%
%   Newer and better version of PAL_PFBA_Fit is available. Use it.
%
%Introduced: Palamedes version 1.8.1 (NP)

function [paramsValues, posterior] = PAL_PFBA_Fit_OldStyle(StimLevels, NumPos, OutOfNum, priorAlphaValues, priorBetaValues, gamma, lambda, PF, varargin)

prior = ones(length(priorBetaValues),length(priorAlphaValues))/(length(priorBetaValues).*length(priorAlphaValues));

if ~isempty(varargin)
    NumOpts = length(varargin);
    for n = 1:2:NumOpts
        valid = 0;
        if strcmpi(varargin{n}, 'prior')
            prior = varargin{n+1};
            valid = 1;
        end
        if valid == 0
            warning('PALAMEDES:invalidOption','%s is not a valid option. Ignored.',varargin{n});
        end        
    end            
end

prior = log(prior);

[StimLevels, NumPos, OutOfNum] = PAL_PFML_GroupTrialsbyX(StimLevels, NumPos, OutOfNum);

[params.alpha, params.beta] = meshgrid(priorAlphaValues,priorBetaValues);
params.beta = 10.^params.beta;
params.gamma = gamma;
params.lambda = lambda;

llikelihood = prior;

for StimLevel = 1:length(StimLevels)
    pcorrect = PF(params, StimLevels(StimLevel));
    llikelihood = llikelihood+log(pcorrect).*NumPos(StimLevel)+log(1-pcorrect).*(OutOfNum(StimLevel)-NumPos(StimLevel));
end

llikelihood = llikelihood-max(max(llikelihood)); %this avoids likelihoods containing zeros
likelihood = exp(llikelihood);
posterior = likelihood./sum(sum(likelihood));

posteriora = sum(posterior,1);
posteriorb = sum(posterior,2);

paramsValues(1) = sum(posteriora.*priorAlphaValues);
paramsValues(2) = sum(posteriorb.*priorBetaValues');
paramsValues(3) = (sum(posteriora.*(priorAlphaValues-paramsValues(1)).^2))^.5;
paramsValues(4) = (sum(posteriorb.*(priorBetaValues'-paramsValues(2)).^2))^.5;