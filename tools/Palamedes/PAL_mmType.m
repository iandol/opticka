%
%PAL_mmType  Simple function that can identify some basic forms of model
%   matrices.
%
%   syntax: [type] = PAL_mmType(M)
%
%Input:
%
%   M: Numeric matrix
%
%Output: 
%   
%   type: 
%       if M is empty, type = 0
%       if M is an identity matrix, type = 1
%       if M is a row vector of equal values, type = 2
%       if M consists of orthogonal rows each of which corresponds to an
%           (unweighted) mean of some or all conditions, i.e., M is 
%           appropriate for a beta distributed variable (guess, lapse), 
%           e.g., [1/2 0 1/2 0 0; 0 1 0 0 0; 0 0 0 1/2 1/2], type = 3. 
%       if M is none of the above, type = 4
%
%Introduced: Palamedes version 1.10.0 (NP)

function [type] = PAL_mmType(M)

type = 4;

if isempty(M)
    type = 0;
end
if isdiag(M)  && all(diag(M) == 1)  %identity matrix (includes scalar equal to 1)
    type = 1;
end
if isrow(M) && (min(M) == max(M)) && ~isscalar(M) %row vector of equal values
    type = 2;
end
if all(abs(sum(M,2) - 1) < 1e-10) && PAL_isOrthogonal(M) && type ~= 1
    M(M==0) = NaN;
    if all(min(M,[],2) == max(M,[],2))
        type = 3;
    end
end