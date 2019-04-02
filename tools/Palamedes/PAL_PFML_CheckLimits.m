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
% Modified: Palamedes version 1.9.1 (see History.m)

function [paramsValues, LL, scenario, message] = PAL_PFML_CheckLimits(StimLevels, NumPos, OutOfNum, paramsValues, paramsFree, PF, varargin)

lapseLimits = [0 1];
guessLimits = [0 1];
gammaEQlambda = logical(false);
lapseFit = 'default';

if ~isempty(varargin)
    NumOpts = length(varargin);
    for n = 1:2:NumOpts
        valid = 0;
        if strncmpi(varargin{n}, 'lapseLimits',6)
            if paramsFree(4) == 0 && ~isempty(varargin{n+1}) && ~all(varargin{n+1} == [0 1])
                warning('PALAMEDES:invalidOption','Lapse rate is not a free parameter: ''LapseLimits'' argument ignored');
            else
                lapseLimits = varargin{n+1};
            end
            valid = 1;
        end
        if strncmpi(varargin{n}, 'guessLimits',6)
            if paramsFree(3) == 0 && ~isempty(varargin{n+1}) && ~all(varargin{n+1} == [0 1])
                warning('PALAMEDES:invalidOption','Guess rate is not a free parameter: ''GuessLimits'' argument ignored');
            else
                guessLimits = varargin{n+1};
            end
            valid = 1;
        end
        if strncmpi(varargin{n}, 'lapseFit',6)
            if paramsFree(4) == 0  && ~strncmp(varargin{n+1},'def',3)
                warning('PALAMEDES:invalidOption','Lapse rate is not a free parameter: ''LapseFit'' argument ignored');   
            else
                if strncmpi(varargin{n+1}, 'nAPLE',5) || strncmpi(varargin{n+1}, 'jAPLE',5) || strncmpi(varargin{n+1}, 'default',5)
                    lapseFit = varargin{n+1};
                else 
                    if strncmpi(varargin{n+1}, 'iAPLE',5)
                        warning('PALAMEDES:invalidOption','iAPLE fitting no longer supported, using jAPLE fitting instead (iAPLE instead of jAPLE fitting is hard to justify anyway).');
                    else
                        warning('PALAMEDES:invalidOption','%s is not a valid option for ''lapseFit''. ignored', varargin{n+1});   
                    end
                end                
            end 
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

LLparams = -1*PAL_PFML_negLL(paramsValues,[],[1 1 1 1],StimLevels,NumPos,OutOfNum,PF,'lapseFit',lapseFit);

[paramsValues, LL, scenario, message] = PAL_PFML_CheckLimitsEngine(StimLevels, NumPos, OutOfNum, paramsValues, LLparams, paramsFree, guessLimits, lapseLimits, gammaEQlambda);

