%
%PAL_PFML_BootstrapParametric    Perform parametric bootstrap to
%   determine standard errors on parameters of fitted psychometric
%   function.
%
%syntax: [SD paramsSim LLSim converged] = ...
%   PAL_PFML_BootstrapParametric(StimLevels, OutOfNum, paramsGen, ...
%       paramsFree, B, PF,{optional arguments})
%
%Input:
%   'StimLevels': vector containing stimulus levels used.
%
%   'OutOfNum': vector containing for each of the entries of 'StimLevels' 
%       the total number of trials.
%
%   'paramsGen': 1x4 vector containing parametervalues [threshold slope 
%       guess-rate lapse-rate] to be used during simulations. PAL_PFML_Fit 
%       might be used to obtain parameter values characterizing observer's
%       psychometric function.
%
%   'paramsFree': 1x4 vector coding which of the four parameters of the PF 
%       (in the order: [threshold slope guess-rate lapse-rate]) are free 
%       parameters and which are fixed parameters (1: free, 0: fixed, ).
%
%   'B': number of bootstrap simulations to perform.
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
%   'SD': 1x4 vector containing standard deviations of the PF's parameters
%       across the B fits to simulated data. These are estimates of the
%       standard errors of the parameter estimates.
%
%   'paramsSim': Bx4 matrix containing the fitted parameters for all B fits
%       to simulated data.
%
%   'LLSim': vector containing Log Likelihoods associated with all B fits
%       to simulated data.
%
%   'converged': For each simulation contains a 1 in case the fit was
%       succesfull (i.e., converged) or a 0 in case it did not.
%
%   PAL_PFML_BootstrapParametric will generate a warning if not all 
%       simulations were fit succesfully.
%
%   PAL_PFML_BootstrapParametric will accept a few optional arguments:
%
%       Use 'searchGrid' argument to define a 4D parameter 
%       grid through which to perform a brute-force search for initial 
%       guesses (performed by PAL_PFML_BruteForceFit) to be used during 
%       fitting procedure. Structure should have fields .alpha, .beta, 
%       .gamma, and .lambda. Each should list parameter values to be 
%       included in brute force search. Fields for fixed parameters should 
%       be scalars equal to the fixed parameter value. Note that all fields 
%       may be scalars in which case no brute-force search will precede the 
%       iterative parameter search. For more information, see example 
%       below. Note that choices made here may have a large effect on 
%       processing time and memory usage. Note that usage of the 
%       'searchGrid' option will generally reduce processing time ((because
%       the serial iterative Nelder-Mead search will be shorter). Usage of 
%       the 'searchGrid' option will also reduce the chances of a fit 
%       failing (see: www.palamedestoolbox.org/understandingfitting.html).
%       In some future version of Palamedes the 'searchGrid' argument will 
%       be required. 
%
%       If highest entry in 'StimLevels' is so high that it can be 
%       assumed that errors observed there can be due only to lapses, one 
%       may use 'lapseFit' argument to specify alternative fitting scheme. 
%       Options: 'nAPLE' (default), 'iAPLE', and 'jAPLE'. Type help 
%       PAL_PFML_Fit or go to: 
%       http://www.journalofvision.org/content/12/6/25 for more 
%       information.
%
%       The guess rate and lapse rate parameter can be constrained to be 
%       equal, as would be appropriate, for example, in a bistable percept 
%       task. To accomplish this, use optional argument 'gammaEQlambda', 
%       followed by a 1. Both the guess rate and lapse rate parameters will 
%       be fit according to options set for the lapse rate parameter. Entry
%       for guess rate in searchGrid needs to be made but will be ignored.
%
%       Options 'maxTries' and 'rangeTries' were operational up to and
%       including Palamedes version 1.7.0. Usage of these arguments will
%       result in a warning stating that the arguments will be ignored and
%       will encourage users to utilize the 'searchGrid' options (see
%       above), which is a much superior manner in which to avoid failed
%       fits.
%
%       User may constrain the lapse rate to fall within limited range 
%       using the optional argument 'lapseLimits', followed by a two-
%       element vector containing lower and upper limit respectively. See 
%       full example below.
%
%       User may constrain the guess rate to fall within limited range 
%       using the optional argument 'guessLimits', followed by a two-
%       element vector containing lower and upper limit respectively.
%
%   PAL_PFML_BootstrapNonParametric uses Nelder-Mead Simplex method to find 
%   the maximum in the likelihood function. The default search options may 
%   be changed by using the optional argument 'SearchOptions' followed by 
%   an options structure created using options = PAL_minimize('options'), 
%   then modified. See example of usage in PAL_PFML_Fit. For more 
%   information type PAL_minimize('options','help').
%
%Example:
%
%   PF = @PAL_Logistic;
%   StimLevels = [-3:1:3];
%   NumPos = [55 55 66 75 91 94 97];    %Human data
%   OutOfNum = 100.*ones(size(StimLevels));
%   paramsFree = [1 1 0 1];
%   searchGrid.alpha = [-1:.1:1];    %structure defining grid to
%   searchGrid.beta = 10.^[-1:.1:2]; %search for initial values
%   searchGrid.gamma = .5;
%   searchGrid.lambda = [0:.005:.03];
%
%   %First fit data:
%
%   paramsValues = PAL_PFML_Fit(StimLevels, NumPos, OutOfNum, ...
%       searchGrid, paramsFree, PF,'lapseLimits',[0 .03]);
%
%   %Estimate standard errors:
%
%   B = 400;
%
%   [SD paramsSim LLSim converged] = ...
%       PAL_PFML_BootstrapParametric(StimLevels, OutOfNum, ...
%       paramsValues, paramsFree, B, PF, 'lapseLimits',[0 .03], ...
%       'searchGrid', searchGrid);
%
% Introduced: Palamedes version 1.0.0 (NP)
% Modified: Palamedes version 1.0.2, 1.1.0, 1.2.0, 1.3.0, 1.3.1, 1.4.0, 
%   1.6.3, 1.8.1 (see History.m)

function [SD, paramsSim, LLSim, converged] = PAL_PFML_BootstrapParametric(StimLevels, OutOfNum, paramsValues, paramsFree, B, PF, varargin)

searchGrid = paramsValues;

options = [];
lapseLimits = [];
guessLimits = [];
lapseFit = 'default';
gammaEQlambda = logical(false);

paramsSim = zeros(B,4);
LLSim = zeros(B,1);
converged = false(B,1);

mTrTflag = false;

if ~isempty(varargin)
    NumOpts = length(varargin);
    for n = 1:2:NumOpts
        valid = 0;
        if strncmpi(varargin{n}, 'SearchOptions',7)
            options = varargin{n+1};
            valid = 1;
        end
        if strncmpi(varargin{n}, 'maxTries',4)
            mTrTflag = true;
            valid = 1;
        end
        if strncmpi(varargin{n}, 'rangeTries',6)
            mTrTflag = true;
            valid = 1;
        end
        if strncmpi(varargin{n}, 'lapseLimits',6)
            if paramsFree(4) == 1
                lapseLimits = varargin{n+1};
            else
                warning('PALAMEDES:invalidOption','Lapse rate is not a free parameter: ''LapseLimits'' argument ignored');
            end
            valid = 1;
        end
        if strncmpi(varargin{n}, 'guessLimits',6)
            if paramsFree(3) == 1
                guessLimits = varargin{n+1};
            else
                warning('PALAMEDES:invalidOption','Guess rate is not a free parameter: ''GuessLimits'' argument ignored');
            end
            valid = 1;
        end
        if strncmpi(varargin{n}, 'searchGrid',8)
            searchGrid = varargin{n+1};
            valid = 1;
        end
        if strncmpi(varargin{n}, 'lapseFit',6)
            if paramsFree(4) == 0
                warning('PALAMEDES:invalidOption','Lapse rate is not a free parameter: ''LapseFit'' argument ignored');
            else
                lapseFit = varargin{n+1};
            end
            valid = 1;
        end
        if strncmpi(varargin{n}, 'gammaEQlambda',6)
            gammaEQlambda = logical(varargin{n+1});
            if gammaEQlambda                
                if paramsValues(3) ~= paramsValues(4)
                    paramsValues(3) = paramsValues(4);
                    warning('PALAMEDES:invalidOption','Generating gamma value changed to %s in order to match lapse value.',num2str(paramsValues(3)));
                end                
            valid = 1;
            end
        end        
        if valid == 0
            warning('PALAMEDES:invalidOption','%s is not a valid option. Ignored.',varargin{n});
        end
    end            
end

if mTrTflag
    message = ['''maxTries'' and ''rangeTries'' options are obsolete and '];
    message = [message 'will be ignored. Use ''searchGrid'' option instead. See: '];
    message = [message 'www.palamedestoolbox.org/understandingfitting.html '];
    message = [message 'for more information.'];
    warning('PALAMEDES:invalidOption',message);
end

if ~isempty(guessLimits) && gammaEQlambda
    warning('PALAMEDES:invalidOption','Guess rate is constrained to equal lapse rate: ''guessLimits'' argument ignored');
    guessLimits = [];
end

if ~isstruct(searchGrid)
    message = ['Option to use generating parameter values as initial '];    
    message = [message 'guesses in fitting procedure will be removed in '];
    message = [message 'some future version of Palamedes. Instead use '];
    message = [message 'optional argument ''searchGrid'' to pass a '];
    message = [message 'structure defining a 4D parameter space through '];
    message = [message 'which to search for initial search values using a '];
    message = [message 'brute force search. Type help '];
    message = [message 'PAL_PFML_BootstrapParametric for more information.'];
    warning('PALAMEDES:useSearchGrid',message);
    warning('off','PALAMEDES:useSearchgrid');
end

[StimLevels, trash, OutOfNum] = PAL_PFML_GroupTrialsbyX(StimLevels, ones(size(StimLevels)), OutOfNum);

if isstruct(searchGrid)
    
    if gammaEQlambda
        searchGrid.gamma = 0;
    end    
    
    [paramsGrid.alpha, paramsGrid.beta, paramsGrid.gamma, paramsGrid.lambda] = ndgrid(searchGrid.alpha,searchGrid.beta,searchGrid.gamma,searchGrid.lambda);

    singletonDim = uint16(size(paramsGrid.alpha) == 1);    
    
    [paramsGrid.alpha] = squeeze(paramsGrid.alpha);
    [paramsGrid.beta] = squeeze(paramsGrid.beta);
    [paramsGrid.gamma] = squeeze(paramsGrid.gamma);
    [paramsGrid.lambda] = squeeze(paramsGrid.lambda);

    if gammaEQlambda
        paramsGrid.gamma = paramsGrid.lambda;
    end    
    
    for level = 1:length(StimLevels)
        logpcorrect(level,:,:,:,:) = log(PF(paramsGrid,StimLevels(1,level)));
        logpincorrect(level,:,:,:,:) = log(1-PF(paramsGrid,StimLevels(1,level)));
    end
else
    paramsGuess = paramsValues;
    if gammaEQlambda
        paramsGuess(3) = paramsGuess(4);
        paramsFree(3) = 0;
    end    
end
    
for b = 1:B
    
    %Simulate experiment
    NumPosSim = PAL_PF_SimulateObserverParametric(paramsValues, StimLevels, OutOfNum, PF,'lapseFit',lapseFit,'gammaEQlambda',gammaEQlambda);

    if isstruct(searchGrid)
        
        LLspace = zeros(size(paramsGrid.alpha,1),size(paramsGrid.alpha,2),size(paramsGrid.alpha,3),size(paramsGrid.alpha,4));

        if size(LLspace,2) == 1 && ndims(LLspace) == 2
            LLspace = LLspace';
        end

        switch lower(lapseFit(1:3))
            case {'nap', 'def'}
                for level = 1:length(StimLevels)
                   LLspace = LLspace + NumPosSim(level).*squeeze(logpcorrect(level,:,:,:,:))+(OutOfNum(level)-NumPosSim(level)).*squeeze(logpincorrect(level,:,:,:,:));
                end
            case {'jap','iap'}
                len = length(NumPosSim);                            
                LLspace = log((1-paramsGrid.lambda).^NumPosSim(len))+log(paramsGrid.lambda.^(OutOfNum(len)-NumPosSim(len))); %0*log(0) evaluates to NaN, log(0.^0) does not
                if gammaEQlambda
                    LLspace = LLspace + log(paramsGrid.lambda.^NumPosSim(1)) + log((1-paramsGrid.lambda).^(OutOfNum(1)-NumPosSim(1)));
                end
                for level = 1+gammaEQlambda:len-1
                    LLspace = LLspace + NumPosSim(level).*squeeze(logpcorrect(level,:,:,:,:))+(OutOfNum(level)-NumPosSim(level)).*squeeze(logpincorrect(level,:,:,:,:));
                end    
        end

        if isvector(LLspace)
            [maxim, Itemp] = max(LLspace);
        else
            if strncmpi(lapseFit,'iap',3)
                [trash, lapseIndex] = min(abs(searchGrid.lambda-(1-NumPosSim(len)/OutOfNum(len))));
                LLspace = shiftdim(LLspace,length(size(LLspace))-1);
                [maxim, Itemp] = PAL_findMax(LLspace(lapseIndex,:,:,:));
                Itemp = circshift(Itemp',length(size(LLspace))-1)';
            else
                [maxim, Itemp] = PAL_findMax(LLspace);
            end
        end
        
        I = ones(1,4);
        
        I(singletonDim == 0) = Itemp;
        
        paramsGuess = [searchGrid.alpha(I(1)) searchGrid.beta(I(2)) searchGrid.gamma(I(3)) searchGrid.lambda(I(4))];
        if strncmpi(lapseFit,'iap',3)
            paramsGuess(4) = 1-NumPosSim(len)/OutOfNum(len);
        end
    end
    
    [paramsSim(b,:), LLSim(b,:), converged(b)] = PAL_PFML_Fit(StimLevels, NumPosSim, OutOfNum, paramsGuess, paramsFree, PF, 'SearchOptions', options,'lapseLimits',lapseLimits,'guessLimits',guessLimits,'lapseFit',lapseFit,'gammaEQlambda',gammaEQlambda);

    if ~converged(b)
        warning('PALAMEDES:convergeFail','Fit to simulation %s of %s did not converge.',int2str(b), int2str(B));        
    end
    
end

exitflag = sum(converged) == B;
if exitflag ~= 1
    message = ['Use (or adjust use of) ''searchGrid'' option. In case this does not work, '];
    message = [message 'a global maximum in the likelihood function may not exist.'];
    message = [message 'See www.palamedestoolbox.org/understandingfitting.html for more '];
    message = [message 'information'];
    warning('PALAMEDES:convergeFail',['Only %s of %s simulations converged. ' message],int2str(sum(converged)), int2str(B));
end

[Mean, SD] = PAL_MeanSDSSandSE(paramsSim);