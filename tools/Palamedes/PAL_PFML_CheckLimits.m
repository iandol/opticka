%
%PAL_PFML_CheckLimits   Check whether the parameter estimates found by 
%   PAL_PFML_Fit correspond to global maximum or whether a step function or 
%   constant function (each of which may be approached to any arbitrary 
%   degree of precision by model to be fitted) exists that has higher 
%   likelihood.
%
%Syntax: [paramsValuesOut, LL, scenario, message] = 
%   PAL_PFML_CheckLimits(StimLevels, NumPos, OutOfNum, paramsValuesIn, 
%   paramsFree, PF, {optional arguments})
%
%Input: 
%   'StimLevels': vector containing stimulus levels used.
%
%   'NumPos': vector containing for each of the entries of 'StimLevels' the 
%       number of trials on which a positive response (e.g., 'yes' or 
%       'correct') was given.
%
%   'OutOfNum': vector containing for each of the entries of 'StimLevels' 
%       the total number of trials.
%
%   'paramsValuesIn': parameter estimates that were returned by 
%       PAL_PFML_Fit.
%
%   'paramsFree': 1x4 vector coding which of the four parameters of the PF 
%       [threshold slope guess-rate lapse-rate] are free parameters and 
%       which are fixed parameters (1: free, 0: fixed). Any combination of
%       free and fixed parameters may be used.
%
%   'PF': psychometric function to be fitted. Passed as an inline function.
%       Options include:    
%           @PAL_Logistic
%           @PAL_Weibull
%           @PAL_Gumbel (i.e., log-Weibull)
%           @PAL_Quick
%           @PAL_logQuick
%           @PAL_CumulativeNormal
%           @PAL_Gumbel
%           @PAL_HyperbolicSecant
%
%Output:
%   'paramsValuesOut': 1x4 vector containing values of fitted and fixed 
%       parameters of the psychometric function [threshold slope guess-rate 
%       lapse-rate]. If 'scenario' (see below) equals 1 (and PAL_PFML_Fit's 
%       exitflag after completing fit equaled TRUE or 1), these will be
%       finite valued parameter estimates corresponding to the
%       maximum-likelihood fit. If 'scenario' equals -1, -2, or -3,
%       parameter values here are set to the values they will approach if
%       iterative search procedure (e.g., Nelder-Mead) would proceed
%       error-free and ad infinitum. These values may include finite values 
%       and may include -Inf or Inf. NaN is assigned to (free) parameters 
%       that are fully redundant with other (free) parameters. Read the 
%       output message for more details (Especially if scenario does not 
%       equal 1).
%
%   'LL': Log likelihood associated with the fit. This log likelihood can
%       only be approached by a PF with finite-valued parameters if 
%       scenario does not equal 1.
%
%   'scenario': 1 indicates that the parameter values (i.e.,
%       'parameterValues') correspond to the maximum-likelihood estimate. 
%       If value is -1, -2, or -3 the likelihood function does not contain 
%       a maximum (assuming an appropriate search grid was used in call to 
%       PAL_PFML_Fit. If 'scenario' equals -1, -2, or -3, the output 
%       message will describe a step or constant function that can be 
%       approached by a PF with the constraints provided by user and that 
%       has higher likelihood than the PF described by 'paramsValuesIn'.
%
%   'output': message containing information on the best fitting PF.
%
%The function has a few optional arguments. Note that results are 
%   meaningful only if these correspond to those that were used during
%   PAL_PFML_Fit.
%
%User may constrain the lapse rate to fall within a limited range using 
%   the optional argument 'lapseLimits', followed by a two-element vector 
%   containing lower and upper limit respectively. Default: [0 1]
%
%User may constrain the guess rate to fall within a limited range using 
%   the optional argument 'guessLimits', followed by a two-element vector 
%   containing lower and upper limit respectively. Default: [0 1]
%
%The guess rate and lapse rate parameter can be constrained to be equal, as 
%   would be appropriate, for example, in a bistable percept task. To 
%   accomplish this, use optional argument 'gammaEQlambda', followed by a 
%   1. Both the guess rate and lapse rate parameters will be fit according 
%   to options set for the lapse rate parameter. Entry for guess rate in 
%   'searchGrid' needs to be made but will be ignored.
%
%Examples:
% 
% PF = @PAL_Logistic;
% StimLevels = [-2:1:2];
% OutOfNum = 10.*ones(size(StimLevels));
% 
% searchGrid.alpha = [-2:.01:2];    %grid to search through for seed for
% searchGrid.beta = 10.^[-1:.01:2]; %iterative search procedure
% searchGrid.gamma = .5;
% searchGrid.lambda = .02;
% 
% paramsFree = [1 1 0 0];
% 
% %Example 1 (scenario = 1):
% 
% NumPos = [7 7 6 10 9];    %observer data
% 
% %Fit data:
% 
% [paramsValuesNM, LL, exitflag] = PAL_PFML_Fit(StimLevels, NumPos, ...
%   OutOfNum, searchGrid, paramsFree, PF);
% 
% [paramsValues, LL, scenario, message] = ...
%   PAL_PFML_CheckLimits(StimLevels, NumPos, OutOfNum, ...
%   paramsValuesNM, paramsFree, PF)
% 
% %Note also that use of searchGrid in above example avoided a possible 
% %convergence failure. Starting Nelder-Mead search at, for example, the 
% %point threshold = 0, slope = 10 (by setting searchGrid to: 
% %searchGrid = [0 10 .5 .02];) results in a failed convergence.
% 
% %Example 2 (scenario = -1):
% 
% NumPos = [6 5 8 6 10];    %observer data
% 
% %Fit data:
% 
% [paramsValuesNM, LL, exitflag] = PAL_PFML_Fit(StimLevels, NumPos, ...
%   OutOfNum, searchGrid, paramsFree, PF);
% 
% [paramsValues, LL, scenario, message] = ...
%   PAL_PFML_CheckLimits(StimLevels, NumPos, OutOfNum, ...
%   paramsValuesNM, paramsFree, PF)
% 
% %Note that use of searchGrid in above example avoided convergence on a 
% %local maximum in the likelihood function located at threshold = 0.6777 
% %and slope = 1.3253.
% 
% %Example 3 (scenario = -2):
% 
% NumPos = [7 5 10 9 9];  %All else as above
% 
% [paramsValuesNM LL exitflag] = PAL_PFML_Fit(StimLevels, NumPos, ...
%   OutOfNum, searchGrid, paramsFree, PF);
% 
% [paramsValues, LL, scenario, message] = ...
%   PAL_PFML_CheckLimits(StimLevels, NumPos, OutOfNum, ...
%   paramsValuesNM, paramsFree, PF)
% 
% %Example 4 (scenario = -3):
% 
% NumPos = [7 8 6 6 8];   %All else as above
% 
% [paramsValuesNM LL exitflag] = PAL_PFML_Fit(StimLevels, NumPos, ...
%   OutOfNum, searchGrid, paramsFree, PF);
% 
% [paramsValues, LL, scenario, message] = ...
%   PAL_PFML_CheckLimits(StimLevels, NumPos, OutOfNum, ...
%   paramsValuesNM, paramsFree, PF)
%
% Introduced: Palamedes version 1.9.0 (NP)

function [paramsValues, LL, scenario, message] = PAL_PFML_CheckLimits(StimLevels, NumPos, OutOfNum, paramsValues, paramsFree, PF, varargin)

lapseLimits = [0 1];
guessLimits = [0 1];
gammaEQlambda = logical(false);

if ~isempty(varargin)
    NumOpts = length(varargin);
    for n = 1:2:NumOpts
        valid = 0;
        if strncmpi(varargin{n}, 'lapseLimits',6)
            if paramsFree(4) == 0 && ~isempty(varargin{n+1})
                warning('PALAMEDES:invalidOption','Lapse rate is not a free parameter: ''LapseLimits'' argument ignored');
            else
                lapseLimits = varargin{n+1};
            end
            valid = 1;
        end
        if strncmpi(varargin{n}, 'guessLimits',6)
            if paramsFree(3) == 0 && ~isempty(varargin{n+1})
                warning('PALAMEDES:invalidOption','Guess rate is not a free parameter: ''GuessLimits'' argument ignored');
            else
                guessLimits = varargin{n+1};
            end
            valid = 1;
        end
        if strncmpi(varargin{n}, 'lapseFit',6)
            warning('PALAMEDES:invalidOption','''lapseFit'' is not supported in this function. Ignored');
            valid = 1;
        end
        if strncmpi(varargin{n}, 'gammaEQlambda',6)
            gammaEQlambda = logical(varargin{n+1});
            valid = 1;
        end
        if valid == 0
            warning('PALAMEDES:invalidOption','%s is not a valid option. Ignored.',varargin{n});
        end        
    end            
end

if gammaEQlambda
    paramsFree(3) = 0;
    if ~isempty(guessLimits)
        warning('PALAMEDES:invalidOption','Guess rate is constrained to equal lapse rate: ''guessLimits'' argument ignored and ''lapseLimits'' is used');
        guessLimits = lapseLimits;
    end
    if paramsValues(3) ~= paramsValues(4)
        warning('PALAMEDES:invalidValue','gammaEQlambda is set to true but supplied values do not match. Check results carefully.');
        paramsValues(3) = paramsValues(4);
    end
end

[StimLevels, NumPos, OutOfNum] = PAL_PFML_GroupTrialsbyX(StimLevels, NumPos, OutOfNum);

LLparams = -1*PAL_PFML_negLL(paramsValues,[],[1 1 1 1],StimLevels,NumPos,OutOfNum,PF);

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

[LLscenario Iscenario] = sort(round([LLparams maxWO maxW LLhor],12));

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
        paramsValues(2) = 0;
        if paramsFree(3) || paramsFree(4)
            paramsValues(1) = NaN;
            if paramsFree(3)
                paramsValues(3) = NaN;
            end
            if paramsFree(4)
                paramsValues(4) = NaN;
            end
            if gammaEQlambda
                paramsValues(3) = paramsValues(4);
            end
        else
            if phor > (paramsValues(3) + 1 - paramsValues(4))/2
                paramsValues(1) = -Inf;
            else
                paramsValues(1) = Inf;
            end
        end
        message = 'Assuming a proper search grid was used in call to PAL_PFML_Fit, it appears that the likelihood function does not contain a global maximum. The constant function valued at ';
        message = [message, num2str(phor)];
        message = [message, ' has higher likelihood than can be attained by the PF you are attempting to fit, but can be approached to any arbitrary degree of precision by it.'];
        
end