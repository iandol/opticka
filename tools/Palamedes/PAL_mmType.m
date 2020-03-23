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
%       if M is a row vector of equal values, type = 2 (if condition for
%           type 3 is also satisfied, type will be set to equal 3)
%       if M consists of orthogonal rows each of which corresponds to an
%           (unweighted) mean of some or all conditions, i.e., M is 
%           appropriate for a beta distributed variable (guess, lapse), 
%           e.g., [1/2 0 1/2 0 0; 0 1 0 0 0; 0 0 0 1/2 1/2], type = 3. 
%       if M is none of the above, type = 4
%
%Introduced: Palamedes version 1.10.0 (NP)
%Modified: Palamedes version 1.10.1 (See History.m)

function [type] = PAL_mmType(M)

type = 4;

if isempty(M)
    type = 0;
end
if size(M,1) == size(M,2) && sum(sum(M - eye(size(M)))) == 0 && max(max(M - eye(size(M)))) == 0
    type = 1;
end
if size(M,1) == 1 && (min(M) == max(M)) && ~isscalar(M) %row vector of equal values
    type = 2;
end
if all(abs(sum(M,2) - 1) < 1e-10) && PAL_isOrthogonal(M) && type ~= 1
    M(M==0) = NaN;
    if all(min(M,[],2) == max(M,[],2))
        type = 3;
    end
end