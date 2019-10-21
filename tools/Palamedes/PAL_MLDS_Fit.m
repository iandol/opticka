%
%PAL_MLDS_Fit   Fit scaling data using the method developed by Maloney & 
%   Yang (2003) Journal of Vision, 3, 5 or Devinck & Knoblauch's 2012
%   variation (Journal of Vision, 12, 19) on this method.
%
%syntax: [PsiValues SDnoise LL exitflag output] = PAL_MLDS_Fit(Stim, ...
%   NumGreater, OutOfNum, PsiValues, SDnoise, {optional arguments})
%
%Input:
%   'Stim': Listing of stimulus pairs, triads or quadruples used in
%       experiment. May contain repeats (i.e., like trials need not be
%       grouped). See PAL_MLDS_GenerateStimList for format.
%
%   'NumGreater': For each row of 'Stim', 'NumGreater' lists the number of
%       trials on which the response was 'greater' (for pairs i-j: j was
%       judged greater than i, for triads i-j-k: (k - j) was deemed greater
%       than (j - i), for quadruples i-j-k-l: (k - l) was deemed greater
%       than (j - i)).
%
%   'OutOfNum': For each row of 'Stim', 'OutOfNum' lists the number of
%       trials.
%
%   'PsiValues' is a vector containing initial guesses for the values of 
%       Psi. Must have as many elements as there are stimulus levels in
%       'Stim', first entry must be 0. If using the Maloney and Yang 
%       implementation (default, see below), the last entry must be 1.
%
%   'SDnoise' is a scalar containing initial guess for magnitude of
%       internal noise. If using Devinck & Knoblauch implementation (see 
%       below), SDnoise is defined to equal 1 and user should pass an empty 
%       matrix.
%
%Output:
%   'PsiValues': Best-fitting values for Psi.
%
%   'SDnoise': Best-fitting value for internal noise. In Devinck and
%       Knoblauch implementation SDnoise is not fitted but defined to equal 
%       1.
%
%   'LL': Log likelihood associated with the fit.
%
%   'exitflag': 1 indicates a succesful fit, 0 indicates fit did not
%       converge (trying again using new initial guesses might help).
%
%   'output': message containing some information concerning fitting
%       process.
%
%   By default, PAL_MLDS_Fit uses Maloney & Yang's (2003) conceptualization
%       of the fitting problem. M&Y anchor the lowest and highest internal 
%       stimulus intensities (at 0 and 1 respectively) and estimate the 
%       remaining internal stimulus intensities relative to the anchors as
%       well as the internal noise magnitude. User may also opt to use
%       Devinck & Knoblauch's (2012) conceptualization. D&K anchor the
%       lowest internal stimulus intensity (at 0) as well as the internal
%       noise magnitude (at 1) and estimate the remaining internal stimulus
%       intensities. One advantage of D&K's conceptualization is that it
%       does not assume that the last stimulus intensity is associated with
%       a higher internal stimulus intensity, allowing the fitting of a 
%       control condition in which the stimuli are not expected to 
%       correspond to different internal stimulus intensities. Also, D&K
%       quantify the noise magnitude differently compared to M&Y, see
%       original sources for more detail. In order to fit data according to 
%       D&K conceptualization, use (something like):
%
%   [PsiValues SDnoise LL exitflag output] = PAL_MLDS_Fit(Stim, ...
%       NumGreater, OutOfNum, PsiValues, [], ...
%       'parameterization','Devinck')
%
%   PAL_MLDS_Fit uses Nelder-Mead Simplex method. The default search 
%       options may be changed by using the following syntax:
%
%   [PsiValues SDnoise LL exitflag output] = PAL_MLDS_Fit(Stim, ...
%       NumGreater, OutOfNum, PsiValues, SDnoise, 'SearchOptions', options)
%
%   where 'options' is a structure that can be created using:
%       options = PAL_minimize('options');
%   type PAL_minimize('options','help'); to get a brief explanation of
%       options available and their default values.
%
%Example:
%
%   Stim = PAL_MLDS_GenerateStimList(2, 6, 2, 10);
%   OutOfNum = ones(1,size(Stim,1));
%   PsiValues = [0:1/5:1];
%   SDnoise = .5;
%
%   %Generate hypothetical data:
%   NumGreater = PAL_MLDS_SimulateObserver(Stim, OutOfNum, PsiValues, ...
%      SDnoise);
%  
%   options = PAL_minimize('options');
%   options.TolX = 1e-9;    %increase desired precision
%
%   %Fit hypothetical data Maloney & Yang style:
%   [PsiValuesMY SDnoiseMY] = PAL_MLDS_Fit(Stim, NumGreater, OutOfNum, ...
%       PsiValues, SDnoise,'SearchOptions',options);
%
%   %Fit hypothetical data Devinck & Knoblauch style:
%   [PsiValuesDK SDnoiseDK] = PAL_MLDS_Fit(Stim, NumGreater, OutOfNum, ...
%       PsiValues, [],'SearchOptions',options,'parameterization',...
%       'devinck');
%
% %Note that PsiValuesMY and PsiValuesDK are merely scaled versions of each
% %other:
%
%   scatter(PsiValuesMY, PsiValuesDK);
%
% Introduced: Palamedes version 1.0.0 (NP)
% Modified: Palamedes version 1.4.0, 1.6.3, 1.9.0 (NP): (see History.m)

function [PsiValues, SDnoise, LL, exitflag, output] = PAL_MLDS_Fit(Stim, NumGreater, OutOfNum, PsiValues, SDnoise, varargin)

options = [];
parameterization = 'maloney';

if ~isempty(varargin)
    NumOpts = length(varargin);
    for n = 1:2:NumOpts
        valid = 0;
        if strncmpi(varargin{n}, 'parameterization',5)
            parameterization = varargin{n+1};
            valid = 1;
        end        
        if strncmpi(varargin{n}, 'SearchOptions',7)
            options = varargin{n+1};
            valid = 1;
        end
        if valid == 0
            warning('PALAMEDES:invalidOption','%s is not a valid option. Ignored.',varargin{n});
        end        
    end            
end

NumLevels = length(PsiValues);

if strncmpi(parameterization,'dev',3)
    FreeParams = PsiValues(2:NumLevels);
    if ~isempty(SDnoise) & SDnoise ~= 1
        message =  'Using Devinck & Knoblauch parameterization of MLDS, noise SD is defined to equal 1. User supplied value will be ignored. ';
        message = [message 'In order to avoid seeing this message again, use either the value 1 or an empty matrix in function call.'];
        warning('PALAMEDES:DevinckKnoblauchSDignored',message);
    end
else
    FreeParams = [PsiValues(2:NumLevels-1) SDnoise];
end

[FreeParams, negLL, exitflag, output] = PAL_minimize(@PAL_MLDS_negLL,FreeParams, options, Stim, NumGreater, OutOfNum,'param',parameterization);

LL = -negLL;

if strncmpi(parameterization,'dev',3)
    PsiValues(2:NumLevels) = FreeParams;
    SDnoise = 1;
else
    PsiValues(2:NumLevels-1) = FreeParams(1:NumLevels-2);
    SDnoise = FreeParams(NumLevels-1);
end