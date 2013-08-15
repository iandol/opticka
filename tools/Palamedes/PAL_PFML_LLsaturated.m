%
%PAL_PFML_LLsaturated   Returns Log Likelhood and number of parameters in
%saturated model.
%
%syntax: [LL numParams] = PAL_PFML_LLsaturated(NumPos, OutOfNum)
%
%Requires trials to have been grouped (e.g., using PAL_PFML_GroupTrialsByX)
%
%Example:
%
%[LL numParams] = PAL_PFML_LLsaturated([0 1; 2 3], [0 2; 3 4]) returns:
%
%LL = -5.5452
%numParams = 3;
%
%Introduced: Palamedes version 1.1.0 (NP)

function [LL numParams] = PAL_PFML_LLsaturated(NumPos, OutOfNum)

warningstates = warning('query','all');
warning off MATLAB:DivideByZero

[LL numParams] = PAL_PFML_negLLNonParametric(NumPos, OutOfNum);
LL = -LL;

warning(warningstates);