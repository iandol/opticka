%
%PAL_AMPM_PosteriorTplus1  Derives posterior distributions for combinations
%   of stimulus intensity and response on trial T + 1 in psi method 
%   adaptive procedure.
%   
%   syntax: [PosteriorTplus1givenSuccess PosteriorTplus1givenFailure] = ...
%       PAL_AMPM_PosteriorTplus1(pdf, PFLookUpTable)
%
%   Internal function
%
%Introduced: Palamedes version 1.0.0 (NP)
%Modified: Palamedes version 1.5.0 (see History.m)

function [PosteriorTplus1givenSuccess PosteriorTplus1givenFailure] = PAL_AMPM_PosteriorTplus1(pdf, PFLookUpTable)

pdf5D = repmat(pdf, [1 1 1 1 size(PFLookUpTable,5)]);

Denominator = squeeze(sum(sum(sum(sum(pdf5D.*PFLookUpTable,1),2),3),4));
Denominator = repmat(Denominator, [1 size(pdf5D,1) size(pdf5D,2) size(pdf5D,3) size(pdf5D,4)]);
Denominator = permute(Denominator, [2 3 4 5 1]);

PosteriorTplus1givenSuccess = (pdf5D.*PFLookUpTable)./Denominator;

Denominator = squeeze(sum(sum(sum(sum(pdf5D.*(1-PFLookUpTable),1),2),3),4));
Denominator = repmat(Denominator, [1 size(pdf5D,1) size(pdf5D,2) size(pdf5D,3) size(pdf5D,4)]);
Denominator = permute(Denominator, [2 3 4 5 1]);

PosteriorTplus1givenFailure = (pdf5D.*(1-PFLookUpTable))./Denominator;