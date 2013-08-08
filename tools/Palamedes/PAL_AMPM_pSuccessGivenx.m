%
%PAL_AMPM_pSuccessGivenx  Derives probability of a positive response for 
%   all potential stimulus intensities that may be used on trial T + 1. 
%   Probability is calculated as the expected value of the probability of 
%   a positive response calculated across the posterior distribution.
%   
%   syntax: pSuccessGivenx = PAL_AMPM_pSuccessGivenx(PFLookUpTable, ...
%       pdf)
%
%   Internal function
%
%Introduced: Palamedes version 1.0.0 (NP)
%Modified: Palamedes version 1.5.0 (see History.m)

function pSuccessGivenx = PAL_AMPM_pSuccessGivenx(PFLookUpTable, pdf)

pdf5D = repmat(pdf, [1 1 1 1 size(PFLookUpTable,5)]);
pSuccessGivenx = sum(sum(sum(sum(pdf5D.*PFLookUpTable,1),2),3),4);