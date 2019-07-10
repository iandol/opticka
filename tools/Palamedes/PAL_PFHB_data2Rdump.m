%
%PAL_PFHB_data2Rdump  Add fields .finite, .pInf, and .nInf to 'data'
%   structure, indicating, respectively, whether values in field x are 
%   finite-valued, equal to +Inf or to -Inf, then writes 'data' to R dump
%   format.
%
%   syntax: [success] = PAL_PFHB_data2Rdump(data, filename)
%
%   'data' must have field .x
%   filename may contain path and should (for good form) have extension
%       '.R'
%
%   returns 0 if file could not be created, 1 otherwise.   
%
% Introduced: Palamedes version 1.10.0 (NP)

function [success] = PAL_PFHB_data2Rdump(data,filename)

success = 0;
data.finite = true(size(data.x));
data.pInf = false(size(data.x));
data.nInf = false(size(data.x));

if any(isinf(data.x))
    if any(data.x == -Inf)
        data.nInf = (data.x == -Inf);
        data.finite(data.x == -Inf) = 0;      
    end
    if any(data.x == Inf)
        data.pInf = (data.x == Inf);
        data.finite(data.x == Inf) = 0;
    end
    data.x(isinf(data.x)) = 0;
end

success = PAL_mat2Rdump(data,filename);