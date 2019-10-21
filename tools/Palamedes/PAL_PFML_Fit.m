%
%PAL_PFML_Fit   Fit a psychometric function to data using a Maximum 
%    Likelihood criterion.
%
%Syntax: [paramsValues LL scenario output] = PAL_PFML_Fit(StimLevels, ...
%   NumPos, OutOfNum, searchGrid, paramsFree, PF, {optional arguments})
%
%Input: 
%   'StimLevels': vector containing stimulus levels used.
%
%   'NumPos':
%       vector containing for each of the entries of 'StimLevels' the 
%       number of trials a positive response (e.g., 'yes' or 'correct') was
%       given.
%
%   'OutOfNum': vector containing for each of the entries of 'StimLevels' 
%       the total number of trials.
%
%   'searchGrid': Either a 1x4 vector [threshold slope guess-rate 
%       lapse-rate] containing initial guesses for free parametervalues and 
%       fixed values for fixed parameters or a structure with vector fields 
%       .alpha, .beta, .gamma, .lambda collectively defining a 4D parameter 
%       grid through which to perform a brute-force search for initial 
%       guesses (using PAL_PFML_BruteForceFit). These initial values will
%       serve as seeds for the Nelder-Mead iterative search. Fields for 
%       fixed parameters should be scalars equal to the fixed value. Note 
%       that fields for free parameters may also be scalars in which case 
%       the provided value will serve as the initial value for Nelder-Mead 
%       search. Note that choices made here have a large effect on 
%       processing time and memory usage.
%
%   'paramsFree': 1x4 vector coding which of the four parameters of the PF 
%       [threshold slope guess-rate lapse-rate] are free parameters and 
%       which are fixed parameters (1: free, 0: fixed).
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
%   'paramsValues': 1x4 vector containing values of fitted and fixed 
%       parameters of the psychometric function [threshold slope guess-rate 
%       lapse-rate].
%
%   'LL': Log likelihood associated with the fit.
%
%   'scenario': 1 indicates a succesful fit, a negative number indicates 
%       that the likelihood function does not contain a global maximum.
%       For more information, see below or visit
%       www.palamedestoolbox.org/understandingfitting.html
%
%   'output': message containing some information concerning fitting
%       process.
%
%User may constrain the lapse rate to fall within a limited range using 
%   the optional argument 'lapseLimits', followed by a two-element vector 
%   containing lower and upper limit respectively. Default: [0 1]
%
%User may constrain the guess rate to fall within a limited range using 
%   the optional argument 'guessLimits', followed by a two-element vector 
%   containing lower and upper limit respectively. Default: [0 1]
%
%Different fitting schemes may be specified using the optional argument
%   'lapseFits'. Default value is 'nAPLE' (non-Asymptotic Performance Lapse 
%   Estimation), in which all free parameters are estimated jointly in the 
%   manner outlined by e.g., Wichmann & Hill (2001). In case the highest 
%   stimulus value in 'StimLevels' is so high that it can be assumed that 
%   errors at this intensity can only be due to lapses, the alternative 
%   fitting scheme 'jAPLE' (joint APLE) may be specified. 'jAPLE' assumes 
%   that errors at highest 'StimLevel' are due exclusively to lapses, and 
%   observations at this intensity contribute only to estimate of lapse 
%   rate. Observations at other values in 'StimLevels' contribute to all 
%   free parameters (including lapse rate). For more information see: 
%   http://www.journalofvision.org/content/12/6/25
%
%The guess rate and lapse rate parameter can be constrained to be equal, as 
%   would be appropriate, for example, in a bistable percept task. To 
%   accomplish this, use optional argument 'gammaEQlambda', followed by a 
%   1. Both the guess rate and lapse rate parameters will be fit according 
%   to options set for the lapse rate parameter. Entry for guess rate in 
%   'searchGrid' needs to be made but will be ignored.
%
%PAL_PFML_Fit uses Nelder-Mead Simplex method to find the maximum 
%   in the likelihood function. The default search options may be changed 
%   by using the optional argument 'SearchOptions' followed by an options 
%   structure created using options = PAL_minimize('options'). See example 
%   of usage below. For more information type 
%   PAL_minimize('options','help').
%
%   If the likelihood function contains a global maximum (and assuming that 
%   an appropriate search grid is used), the fitting procedure will find 
%   the global maximum. However, sometimes the likelihood function does not 
%   contain a global maximum. This situation would occasionally result in 
%   'false' convergences (procedure claims to have found global maximum but 
%   has not) and incorrect values for parameter estimates. Starting in 
%   Palamedes version 1.10.0 fitting procedures will, by default, check 
%   whether a fit corresponds to a global maximum. If not, the procedure 
%   will identify the best-fitting function that can be asymptotically 
%   approached by the PF (this will be either a step function or a constant 
%   function). It will also assign parameter values that are most 
%   appropriate for the identified 'scenario'. These values may include 
%   +/- Infinity or NaN. A code identifying the 'scenario' is returned in 
%   output argument 'scenario' (see 
%   www.palamedestoolbox.understandingfitting.html for more information). 
%   output.message will contain information on the best-fitting PF. It is 
%   important to note that failed convergences are the result of 'Too much 
%   model, too little data' (i.e., one is trying to estimate parameters 
%   that the data do not contain enough information on). User may override 
%   this default behavior by using the 'checkLimits' option followed by 0 
%   (or logical false). Using this option, false convergences may happen in 
%   which case the parameter estimates will be inaccurate. In other words, 
%   users are strongly discouraged from changing the default. A better 
%   solution is to either get more data or fit a simpler model. Another 
%   option is to use a Bayesian fitting approach.
%
%Full example:
%
%   options = PAL_minimize('options') %options structure containing default
%                                     %values            
%   PF = @PAL_Logistic;
%   StimLevels = [-3:1:3];
%   NumPos = [0 13 28 56 73 91 93];    %observer data
%   OutOfNum = 100.*ones(size(StimLevels));
%   searchGrid.alpha = [-1:.01:1];    %structure defining grid to
%   searchGrid.beta = 10.^[-1:.01:2]; %search for initial values
%   searchGrid.gamma = [0:.01:.06];
%   searchGrid.lambda = [0:.01:.06];
%
%   %or (not advised):
%   % searchGrid = [0 1 0.01 0.01];       %Guesses
%
%   paramsFree = [1 1 1 1];
%
%   %Fit data:
%
%   paramsValues = PAL_PFML_Fit(StimLevels, NumPos, OutOfNum, ...
%       searchGrid, paramsFree, PF,'lapseLimits',[0 1],'guessLimits',...
%       [0 1], 'searchOptions',options)
%
% Introduced: Palamedes version 1.0.0 (NP)
% Modified: Palamedes version 1.0.2, 1.2.0, 1.3.0, 1.3.1, 1.4.0, 1.6.3,
%   1.8.1, 1.9.0, 1.9.1 (see History.m)

function [paramsValues, LL, scenario, output] = PAL_PFML_Fit(StimLevels, NumPos, OutOfNum, searchGrid, paramsFree, PF, varargin)

options = [];
lapseLimits = [0 1];
guessLimits = [0 1];
lapseFit = 'default';
gammaEQlambda = logical(false);
checkLimits = paramsFree(2);    %if slope is fixed, there is no point

if ~isempty(varargin)
    NumOpts = length(varargin);
    for n = 1:2:NumOpts
        valid = 0;
        if strncmpi(varargin{n}, 'SearchOptions',7)
            options = varargin{n+1};
            valid = 1;
        end
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
        if strncmpi(varargin{n}, 'checkLimits',7)
            checkLimits = varargin{n+1};
            if checkLimits && ~paramsFree(2)
                checkLimits = false;
                warning('PALAMEDES:invalidOption','You set ''checkLimits'' to true but the slope is not a free parameter. Ignored.',varargin{n});
            end
            valid = 1;
        end
        if valid == 0
            warning('PALAMEDES:invalidOption','%s is not a valid option. Ignored.',varargin{n});
        end        
    end            
end

if ~isempty(guessLimits) && gammaEQlambda
    warning('PALAMEDES:invalidOption','Guess rate is constrained to equal lapse rate: ''guessLimits'' argument ignored');
    guessLimits = lapseLimits;
end

[StimLevels, NumPos, OutOfNum] = PAL_PFML_GroupTrialsbyX(StimLevels, NumPos, OutOfNum);

if isstruct(searchGrid)
    if gammaEQlambda
        searchGrid.gamma = 0;
    end
    searchGrid = PAL_PFML_BruteForceFit(StimLevels, NumPos, OutOfNum, searchGrid, PF, 'lapseFit',lapseFit,'gammaEQlambda',gammaEQlambda);
end

if gammaEQlambda
    searchGrid(3) = searchGrid(4);
    paramsFree(3) = 0;
end

paramsFreeVals = searchGrid(paramsFree == 1);
paramsFixedVals = searchGrid(paramsFree == 0);

if isempty(paramsFreeVals)
    negLL = PAL_PFML_negLL(paramsFreeVals, paramsFixedVals, paramsFree, StimLevels, NumPos, OutOfNum, PF,'lapseFit',lapseFit);
    scenario = 1;
    output = [];
else
    [paramsFreeVals, negLL, scenario, output] = PAL_minimize(@PAL_PFML_negLL, paramsFreeVals, options, paramsFixedVals, paramsFree, StimLevels, NumPos, OutOfNum, PF,'lapseLimits',lapseLimits,'guessLimits',guessLimits,'lapseFit',lapseFit,'gammaEQlambda',gammaEQlambda);
end

paramsValues = zeros(1,4);
paramsValues(paramsFree == 1) = paramsFreeVals;
paramsValues(paramsFree == 0) = paramsFixedVals;

if gammaEQlambda
    paramsValues(3) = paramsValues(4);
end

output.seed = ['Nelder-Mead Simplex search seed: [' num2str(searchGrid) ']'];
LL = -1*negLL;

if checkLimits
    [paramsValues, LL, scenario, message] = PAL_PFML_CheckLimitsEngine(StimLevels, NumPos, OutOfNum, paramsValues, LL, paramsFree, guessLimits, lapseLimits, gammaEQlambda);
    output.message = message;
end
