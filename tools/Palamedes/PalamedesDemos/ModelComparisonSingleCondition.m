% ModelComparisonSingleCondition.m demonstrates how to perform model 
% comparisons in a simple single-condition example.
%
% In the single-condition scenario, models are defined by specifying
% whether each of the parameters of the PF are free or fixed.
%
% Model comparisons for a two-condition scenario are demonstrated in 
%   ModelComparisonTwoConditions.m  
%
% More complex model comparisons are demonstrated in:
%
% PAL_PFLR_Demo: similar to this demo, but produces figures and performs
%   a few different model model comparisons.
%
% PAL_PFLR_FourGroupDemo: performs a trend analysis on the thresholds in
%   four experimental condition.
%
% PAL_PFLR_LearningCurve_Demo: tests whether transfer of learning occurred
%   by comparing a model in which thresholds in transfer condition adhere
%   to learning curve to a model in which they deviate from this curve.
%
% These and other example model comparisons are also shown here:
% www.palamedestoolbox.org/modelcomparisons.html
%
% NP (January 2018)


function [] = ModelComparisonSingleConditon()

if ~exist('PAL_version','file')
    disp('This demo requires the Palamedes toolbox to be installed and to be added ');
    disp('to Matlab''s search path. To download the Palamedes toolbox visit:');
    disp('www.palamedestoolbox.org');
    return;
end
if exist('chi2cdf','file')
    disp('It appears you have the Matlab ''statistics'' toolbox. p-values will be');
    disp('based on the theoretical chi-square distribution.');
    pfromChi2 = 1;
    numMCsimuls = 0;    %Do not perform Monte Carlo simulations
else
    disp('It appears you do not have the Matlab ''statistics'' toolbox. Palamedes will');
    disp('run Monte Carlo simulations in order to estimate p-values. Each p-value will');
    disp('be based on only 100 simulations in this demo (and not be very reliable for');
    disp('that reason), use a higher number of simulations for more reliable p-values.');
    pfromChi2 = 0;
    numMCsimuls = 100;  %Perform 100 Monte Carlo simulations for each p-value
end

%Data for a two condition experiment (each row of the arrays corresponds to one
%condition).
StimLevels = [-2:1:2];
OutOfNum = [50 50 50 50 50];
NumPos =  [3 8 29 40 47];

%Determine Log Likelihood and number of estimated parameters for saturated model
[LLSaturated, numParamsSaturated] = PAL_PFML_LLsaturated(NumPos, OutOfNum);

fprintf('\nWorking ....\n\n');

paramsFreeLesser = [0 1 0 0]; %[alpha beta gamma lambda], 0: fixed, 1: free
numParamsLesser = sum(paramsFreeLesser);
%Search grid through which to search for 'seed' for iterative fitting
%algorithm:
searchGridLesser.alpha = 0;       %fixed parameter value
searchGridLesser.beta = 10.^linspace(-2,2,101);
searchGridLesser.gamma = .02;     %fixed parameter value
searchGridLesser.lambda = .02;    %fixed parameter value

paramsFreeFuller = [1 1 0 0];
numParamsFuller = sum(paramsFreeFuller);
searchGridFuller.alpha = linspace(-2,2,101);
searchGridFuller.beta = 10.^linspace(-2,2,101);
searchGridFuller.gamma = .02; 
searchGridFuller.lambda = .02;

%Simple fit of lesser model
[paramsValuesLesser, LLLesser, exitflagLesser, outputLesser] = ...
    PAL_PFML_Fit(StimLevels, NumPos, OutOfNum, searchGridLesser, paramsFreeLesser,@PAL_Logistic);
%Simple fit of fuller model
[paramsValuesFuller, LLFuller, exitflagFuller, outputFuller] = ...
    PAL_PFML_Fit(StimLevels, NumPos, OutOfNum, searchGridFuller, paramsFreeFuller,@PAL_Logistic);

[TLRFullervsLesser, pMCFullervsLesser] = PAL_PFLR_ModelComparison(StimLevels,NumPos,...
    OutOfNum,paramsValuesLesser,numMCsimuls,@PAL_Logistic,...
    'fullerthresholds','unconstrained',...
    'lesserthresholds','fixed',...
    'fullerslopes','unconstrained',...
    'lesserslopes','unconstrained',...
    'lesserguessrates','fixed',...
    'fullerguessrates','fixed',...
    'lesserlapserates','fixed',...
    'fullerlapserates','fixed');
    
%Determine Goodness-of-Fit of Lesser model
[DevLesser, pMCGOFLesser, DevSim, convergedGoF] = PAL_PFML_GoodnessOfFit(StimLevels,NumPos,OutOfNum,...
    paramsValuesLesser,paramsFreeLesser,numMCsimuls,@PAL_Logistic,'searchGrid', searchGridLesser);

%get p-value of model comparisons 
if pfromChi2   %statistics toolbox installed, use theoretical chi-square distribution
    pFullervsLesser = 1-chi2cdf(TLRFullervsLesser,numParamsFuller-numParamsLesser);
    pGOFLesser = 1-chi2cdf(DevLesser,numParamsSaturated-numParamsLesser);
else   %statistics toolbox not installed, use Monte Carlo Based p-values found above
    pFullervsLesser = pMCFullervsLesser;
    pGOFLesser = pMCGOFLesser;
end

%print results to command window
fprintf('\nLesser model: \n\n');
fprintf('Threshold/PSE\tSlope\t\tGuess rate\tLapse rate\n');
fprintf('%f\t',paramsValuesLesser)
fprintf('\nLog Likelihood: %f', LLLesser);
fprintf('\nNumber of free parameters: %d', numParamsLesser);
fprintf('\nAIC: %f', -2*LLLesser + 2*numParamsLesser);

fprintf('\n\n\nFuller model: \n\n');
fprintf('Threshold/PSE\tSlope\t\tGuess rate\tLapse rate\n');
fprintf('%f\t',paramsValuesFuller)
fprintf('\nLog Likelihood: %f', LLFuller);
fprintf('\nNumber of free parameters: %d', numParamsFuller);
fprintf('\nAIC: %f', -2*LLFuller + 2*numParamsFuller);

fprintf('\n\n\nSaturated model: \n\n');
fprintf('Log Likelihood: %f', LLSaturated);
fprintf('\nNumber of free parameters: %d', numParamsSaturated);
fprintf('\nAIC: %f\n', -2*LLSaturated + 2*numParamsSaturated);

fprintf('\n(Models with lower AICs are preferred over models with higher AICs)\n\n');

%Model comparisons based on p-values
fprintf('Null Hypothesis test Fuller vs Lesser model:');
fprintf('\nTransformed Likelihood Ratio (asymptotically distributed as chi-square): %f.',...
    TLRFullervsLesser);
fprintf('\ndegrees of freedom: %d.', numParamsFuller - numParamsLesser);
fprintf('\np-value: %f\n', pFullervsLesser);

fprintf('\nNull Hypothesis test Lesser vs Saturated model (aka ''Goodness-of-Fit of Lesser Model''):');
fprintf('\nTransformed Likelihood Ratio (aka ''Deviance'' in context of Goodness-of-Fit: %f', DevLesser);
fprintf('\ndegrees of freedom: %d.', numParamsSaturated - numParamsLesser);
fprintf('\np-value: %f\n\n', pGOFLesser);