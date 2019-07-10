%
%PAL_PFHB_writeModel  Write Stan or JAGS model according to specifications
%   
%   syntax: [parameters] = PAL_PFHB_writeModel(model,engine)
%
%Internal Function
%
% Introduced: Palamedes version 1.10.0 (NP)

function [parameters] = PAL_PFHB_writeModel(model,engine)

switch engine.engine
    case 'stan'
        [parameters] = PAL_PFHB_writeModelStan(model,engine);
    case 'jags'
        [parameters] = PAL_PFHB_writeModelJags(model,engine);
end