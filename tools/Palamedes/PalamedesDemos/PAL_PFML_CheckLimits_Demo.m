% PAL_PFML_CheckLimits_Demo.m demonstrates use of PAL_PFML_CheckLimits.m.
% PAL_PFML_CheckLimits.m checks whether the parameter estimates found by 
%   PAL_PFML_Fit correspond to a global maximum or whether a step function 
%   or constant function (each of which may be approached to any arbitrary 
%   degree of precision by model to be fitted) exists that has higher 
%   likelihood.
%
% NP (September 2018)


function [] = PAL_PFML_CheckLimits_Demo()

PF = @PAL_Logistic;
StimLevels = [-2:1:2];
OutOfNum = 10.*ones(size(StimLevels));

searchGrid.alpha = [-2:.01:2];    %grid to search through for seed for
searchGrid.beta = 10.^[-1:.01:2]; %iterative search procedure
searchGrid.gamma = .5;
searchGrid.lambda = .02;

paramsFree = [1 1 0 0];

%Example 1 (scenario = 1):

NumPos = [7 7 6 10 9];    %observer data

%Fit data:

[paramsValuesNM, LL, exitflag] = PAL_PFML_Fit(StimLevels, NumPos, ...
  OutOfNum, searchGrid, paramsFree, PF);

[paramsValues, LL, scenario, message] = ...
  PAL_PFML_CheckLimits(StimLevels, NumPos, OutOfNum, ...
  paramsValuesNM, paramsFree, PF)

%Note also that use of searchGrid in above example avoided a possible 
%convergence failure. Starting Nelder-Mead search at, for example, the 
%point threshold = 0, slope = 10 (by setting searchGrid to: 
%searchGrid = [0 10 .5 .02];) results in a failed convergence.

%Example 2 (scenario = -1): Figure 2 in Prins (under review)

NumPos = [6 5 8 6 10];    %observer data

%Fit data:

[paramsValuesNM, LL, exitflag] = PAL_PFML_Fit(StimLevels, NumPos, ...
  OutOfNum, searchGrid, paramsFree, PF);

[paramsValues, LL, scenario, message] = ...
  PAL_PFML_CheckLimits(StimLevels, NumPos, OutOfNum, ...
  paramsValuesNM, paramsFree, PF)

%Note also that use of searchGrid in above example avoided convergence on a 
%local maximum in the likelihood function located at threshold = 0.6777 
%and slope = 1.3253.

%Example 3 (scenario = -2): Figure 4 in Prins (under review)
%             

NumPos = [7 5 10 9 9];  %All else as above 

[paramsValuesNM LL exitflag] = PAL_PFML_Fit(StimLevels, NumPos, ...
  OutOfNum, searchGrid, paramsFree, PF);

[paramsValues, LL, scenario, message] = ...
  PAL_PFML_CheckLimits(StimLevels, NumPos, OutOfNum, ...
  paramsValuesNM, paramsFree, PF)

%Example 4 (scenario = -3): Figure 5 in Prins (under review)

NumPos = [7 8 6 6 8];   %All else as above

[paramsValuesNM LL exitflag] = PAL_PFML_Fit(StimLevels, NumPos, ...
  OutOfNum, searchGrid, paramsFree, PF);

[paramsValues, LL, scenario, message] = ...
  PAL_PFML_CheckLimits(StimLevels, NumPos, OutOfNum, ...
  paramsValuesNM, paramsFree, PF)