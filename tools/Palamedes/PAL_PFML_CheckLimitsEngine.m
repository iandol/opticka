%
%PAL_PFML_CheckLimitsEngine     Check whether likelihood function contains
%   true maximum
%
%Syntax: [paramsValues, LL, scenario, message] = ...
%   PAL_PFML_CheckLimitsEngine(StimLevels, NumPos, OutOfNum, ...
%   paramsValues, LLparams, paramsFree, guessLimits, lapseLimits, ...
%   gammaEQlambda)
%
%Internal Function
%
% Introduced: Palamedes version 1.9.1 (NP)
%Modified: Palamedes version 1.10.1 (See History.m)

function [paramsValues, LL, scenario, message] = PAL_PFML_CheckLimitsEngine(StimLevels, NumPos, OutOfNum, paramsValues, LLparams, paramsFree, guessLimits, lapseLimits, gammaEQlambda)

LLstepW = zeros(1,length(StimLevels));
lowerAsymptoteW = zeros(1,length(StimLevels));
upperAsymptoteW = zeros(1,length(StimLevels));
LLstepWO = zeros(1,length(StimLevels)-1);
lowerAsymptoteWO = zeros(1,length(StimLevels)-1);
upperAsymptoteWO = zeros(1,length(StimLevels)-1);

for xIndex = 1:length(StimLevels)

    patxIndex = NumPos(xIndex)./OutOfNum(xIndex);
    
    if paramsFree(4) == 0
        upperAsymptoteW(xIndex) = 1-paramsValues(4);
    else
        if gammaEQlambda
            lapse = (sum(OutOfNum(xIndex+1:end)) - sum(NumPos(xIndex+1:end))+sum(NumPos(1:xIndex-1)))./(sum(OutOfNum(xIndex+1:end))+sum(OutOfNum(1:xIndex-1)));
            lapse = max(lapseLimits(1),min(lapse,lapseLimits(2)));
            lowerAsymptoteW(xIndex) = lapse;
            upperAsymptoteW(xIndex) = 1-lapse;
        else
            lapse = 1 - sum(NumPos(xIndex+1:end))./sum(OutOfNum(xIndex+1:end));
            lapse = max(lapseLimits(1),min(lapse,lapseLimits(2)));
            upperAsymptoteW(xIndex) = 1-lapse;            
        end
    end    
    if paramsFree(3) == 0
        if ~gammaEQlambda
            lowerAsymptoteW(xIndex) = paramsValues(3);
        end
    else
        lowerAsymptoteW(xIndex) = min(max(sum(NumPos(1:xIndex-1))./sum(OutOfNum(1:xIndex-1)),guessLimits(1)),guessLimits(2));                               
    end    
    if patxIndex >= upperAsymptoteW(xIndex) || patxIndex <= lowerAsymptoteW(xIndex) || lowerAsymptoteW(xIndex) > upperAsymptoteW(xIndex)
        LLstepW(xIndex) = -Inf;     %Not this scenario
    else
        LLstepW(xIndex) = PAL_nansum(NumPos(1:xIndex-1).*log(lowerAsymptoteW(xIndex))) + PAL_nansum((OutOfNum(1:xIndex-1) - NumPos(1:xIndex-1)).*log(1-lowerAsymptoteW(xIndex))) + ...
            PAL_nansum(NumPos(xIndex+1:end).*log(upperAsymptoteW(xIndex))) + PAL_nansum((OutOfNum(xIndex+1:end) - NumPos(xIndex+1:end)).*log(1-upperAsymptoteW(xIndex))) + ...
            PAL_nansum(NumPos(xIndex).*log(patxIndex)) + PAL_nansum((OutOfNum(xIndex)-NumPos(xIndex)).*log(1-patxIndex));                            
    end
end

for xIndex = 1:length(StimLevels)-1
    if paramsFree(4) == 0
        upperAsymptoteWO(xIndex) = 1-paramsValues(4);
    else
        if gammaEQlambda
            lapse = (sum(OutOfNum(xIndex+1:end))-sum(NumPos(xIndex+1:end))+sum(NumPos(1:xIndex)))./sum(OutOfNum);
            lapse = max(lapseLimits(1),min(lapse,lapseLimits(2)));
            lowerAsymptoteWO(xIndex) = lapse;
            upperAsymptoteWO(xIndex) = 1-lapse;
        else   
            lapse = 1 - sum(NumPos(xIndex+1:end))./sum(OutOfNum(xIndex+1:end));
            lapse = max(lapseLimits(1),min(lapse,lapseLimits(2)));
            upperAsymptoteWO(xIndex) = 1-lapse;
        end
    end    
    if paramsFree(3) == 0
        if ~gammaEQlambda
            lowerAsymptoteWO(xIndex) = paramsValues(3);
        end
    else
        lowerAsymptoteWO(xIndex) = min(max(sum(NumPos(1:xIndex))./sum(OutOfNum(1:xIndex)),guessLimits(1)),guessLimits(2));
    end   
    if lowerAsymptoteWO(xIndex) > upperAsymptoteWO(xIndex)
        LLstepWO(xIndex) = -Inf;    %Not this scenario
    else
        LLstepWO(xIndex) = PAL_nansum(NumPos(1:xIndex).*log(lowerAsymptoteWO(xIndex))) + PAL_nansum((OutOfNum(1:xIndex) - NumPos(1:xIndex)).*log(1-lowerAsymptoteWO(xIndex))) + ...
            PAL_nansum(NumPos(xIndex+1:end).*log(upperAsymptoteWO(xIndex))) + PAL_nansum((OutOfNum(xIndex+1:end) - NumPos(xIndex+1:end)).*log(1-upperAsymptoteWO(xIndex)));        
    end
end

phor = sum(NumPos)./sum(OutOfNum);
if phor >= 1 - paramsValues(4) && paramsFree(4) == 0
    phor = 1 - paramsValues(4);
end
if phor <= paramsValues(3) && paramsFree(3) == 0
    phor = paramsValues(3);
end
LLhor = PAL_nansum(NumPos.*log(phor))+PAL_nansum((OutOfNum-NumPos).*log(1-phor));

[maxW IW] = max(LLstepW);
[maxWO IWO] = max(LLstepWO);

[LLscenario Iscenario] = sort(round(1e12*[LLparams maxWO maxW LLhor])/1e12);

switch Iscenario(4)
    case 1
        LL = LLparams;
        scenario = 1;
        message = 'A maximum in the likelihood function was found. Assuming a proper search grid was used in call to PAL_PFML_Fit, this is the global maximum in the likelihood.';
    case 3            
        LL = maxW;
        xI = IW;
        scenario = -1;        
        paramsValues(1) = StimLevels(xI);
        paramsValues(2) = Inf;
        paramsValues(3) = lowerAsymptoteW(IW);
        paramsValues(4) = 1 - upperAsymptoteW(IW);
        if xI == 1 && paramsFree(3)
            paramsValues(3) = NaN;
        end
        if xI == length(StimLevels) && paramsFree(4)
            paramsValues(4) = NaN;
        end
        message = 'Assuming a proper search grid was used in call to PAL_PFML_Fit, it appears that the likelihood function does not contain a global maximum. The step function valued at ';
        if xI ~= 1
            message = [message, num2str(paramsValues(3))];
            message = [message, ' at stimulus intensities less than '];
            message = [message, num2str(paramsValues(1))];
        end
        if xI ~= length(StimLevels)
            message = [message, ', at '];
            message = [message, num2str(1-paramsValues(4))];
            message = [message, ' at stimulus intensities greater than '];
            message = [message, num2str(paramsValues(1))];
        end
        message = [message, ', and at '];
        message = [message, num2str(NumPos(xI)./OutOfNum(xI))];
        message = [message, ' at stimulus intensities equal to '];
        message = [message, num2str(StimLevels(xI))];
        message = [message, ' has higher likelihood than can be attained by the PF you are attempting to fit, but can be approached to any arbitrary degree of precision by it.'];
        
    case 2        
        LL = maxWO;
        xI = IWO;
        scenario = -2;
        paramsValues(1) = (StimLevels(xI)+StimLevels(xI+1))/2;
        paramsValues(2) = Inf;
        paramsValues(3) = lowerAsymptoteWO(IWO);
        paramsValues(4) = 1 - upperAsymptoteWO(IWO);
        message = 'Assuming a proper search grid was used in call to PAL_PFML_Fit, it appears that the likelihood function does not contain a global maximum. A step function valued at ';
        message = [message, num2str(paramsValues(3))];
        message = [message, ' at stimulus intensities less than/equal to '];
        message = [message, num2str(StimLevels(xI))];
        message = [message, ', and at '];
        message = [message, num2str(1-paramsValues(4))];
        message = [message, ' at stimulus intensities greater than/equal to '];
        message = [message, num2str(StimLevels(xI+1))];
        message = [message, ' has higher likelihood than can be attained by the PF you are attempting to fit, but can be approached to any arbitrary degree of precision by it.'];
            
    case 4
        LL = LLhor;
        scenario = -3;
        paramsValues(1) = NaN;
        paramsValues(2) = NaN;
        if paramsFree(3)
            paramsValues(3) = NaN;
        end
        if paramsFree(4)
            paramsValues(4) = NaN;
        end
        if gammaEQlambda
            paramsValues(3) = paramsValues(4);
        end
        if ~paramsFree(3) && ~paramsFree(4)
            if phor > (paramsValues(3) + 1 - paramsValues(4))/2 && phor < (1 - paramsValues(4))
                paramsValues(1) = -Inf;
                paramsValues(2) = 0;
            end
            if phor < (paramsValues(3) + 1 - paramsValues(4))/2 && phor > paramsValues(3)
                paramsValues(1) = Inf;
                paramsValues(2) = 0;
            end
        end
        message = 'Assuming a proper search grid was used in call to PAL_PFML_Fit, it appears that the likelihood function does not contain a global maximum. The constant function valued at ';
        message = [message, num2str(phor)];
        message = [message, ' has higher likelihood than can be attained by the PF you are attempting to fit, but can be approached to any arbitrary degree of precision by it.'];
        
end