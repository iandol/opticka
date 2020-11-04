%
%PAL_AMPM_updatePM  Updates structure which contains settings for and 
%   results of psi method adaptive method (see also PAL_AMPM_setupPM).
%   
%   syntax: PM = PAL_AMPM_updatePM(PM,response,{optional argument})
%
%After having created a structure 'PM' using PAL_AMPM_setupPM, use 
%   something akin to the following loop to control stimulus intensity
%   during experimental run:
%
%   while ~PM.stop
%       
%       %Present trial here at stimulus magnitude in 'PM.xCurrent'
%       %and collect response (1: correct/greater than, 0: incorrect/
%       %smaller than)
%
%       PM = PAL_AMPM_updatePM(PM, response); %update PM structure based 
%                                             %on response                                    
%    
%    end
%
%If multiple lapse rates are included in the prior distribution (i.e., if
%   PM.priorLambdaRange is a vector [see PAL_AMPM_setupPM]), the psi method
%   has a tendency to produce series of consecutive placements at very high
%   stimulus intensities. In order to avoid this, one has the option to use
%   a fixed lapse rate on any trial (i.e., as the original Psi Method would
%   [Kontsevich & Tyler, 1999]). The value that will be used for the fixed
%   lapse rate is the value corresponding to its current maximum likelihood
%   estimate. Generally (though not necessarily, especially at the start of 
%   a run), the resulting selection for stimulus intensity will not be near 
%   asymptotic performance. In order to select a stimulus intensity using a 
%   fixed lapse rate use the optional argument 'fixLapse', followed by a 
%   logical TRUE. Example:
%
%   PM = PAL_AMPM_updatePM(PM, response, 'fixLapse',1);
%
%   For more information see: www.palamedestoolbox.org/psimarginal.html
%
%Introduced: Palamedes version 1.0.0 (NP)
%Modified: Palamedes version 1.5.0, 1.6.0, 1.6.1, 1.6.3, 1.10.5 (see 
%   History.m)

function PM = PAL_AMPM_updatePM(PM,response,varargin)

fixLapse = false;

valid = 0;
if ~isempty(varargin)
    if strncmpi(varargin{1}, 'fixL',4)            
        fixLapse = varargin{2};                
        valid = 1;
    end
    if valid == 0
        warning('PALAMEDES:invalidOption','%s is not a valid option. Ignored.',varargin{1})
    end        
end

trial = length(PM.x);
PM.response(trial) = response;

if response == 1
    PM.pdf = PM.posteriorTplus1givenSuccess(:,:,:,:,find(PM.stimRange == PM.xCurrent));
else
    PM.pdf = PM.posteriorTplus1givenFailure(:,:,:,:,find(PM.stimRange == PM.xCurrent));
end
PM.pdf = PM.pdf./sum(sum(sum(sum(PM.pdf))));

[PM, expectedEntropy] = PAL_AMPM_expectedEntropy(PM,'fixLapse',fixLapse);

[minEntropy, PM.I] = min(squeeze(expectedEntropy));

PM.xCurrent = PM.stimRange(PM.I);
PM.x(trial+1) = PM.xCurrent;

a = sum(sum(sum(sum(PM.priorAlphas.*PM.pdf))));
b = sum(sum(sum(sum(PM.priorBetas.*PM.pdf))));
g = sum(sum(sum(sum(PM.priorGammas.*PM.pdf))));
l = sum(sum(sum(sum(PM.priorLambdas.*PM.pdf))));

se_a = sqrt(sum(sum(sum(sum(((PM.priorAlphas-a).^2).*PM.pdf)))));
se_b = sqrt(sum(sum(sum(sum(((PM.priorBetas-b).^2).*PM.pdf)))));
se_g = sqrt(sum(sum(sum(sum(((PM.priorGammas-g).^2).*PM.pdf)))));
se_l = sqrt(sum(sum(sum(sum(((PM.priorLambdas-l).^2).*PM.pdf)))));

aUP = sum(sum(sum(sum(PM.priorAlphas.*PM.pdf./PM.prior))))./sum(sum(sum(sum(PM.pdf./PM.prior))));
bUP = sum(sum(sum(sum(PM.priorBetas.*PM.pdf./PM.prior))))./sum(sum(sum(sum(PM.pdf./PM.prior))));
gUP = sum(sum(sum(sum(PM.priorGammas.*PM.pdf./PM.prior))))./sum(sum(sum(sum(PM.pdf./PM.prior))));
lUP = sum(sum(sum(sum(PM.priorLambdas.*PM.pdf./PM.prior))))./sum(sum(sum(sum(PM.pdf./PM.prior))));

se_aUP = sqrt(sum(sum(sum(sum(((PM.priorAlphas-aUP).^2).*PM.pdf./PM.prior))))./sum(sum(sum(sum(PM.pdf./PM.prior)))));
se_bUP = sqrt(sum(sum(sum(sum(((PM.priorBetas-bUP).^2).*PM.pdf./PM.prior))))./sum(sum(sum(sum(PM.pdf./PM.prior)))));
se_gUP = sqrt(sum(sum(sum(sum(((PM.priorGammas-gUP).^2).*PM.pdf./PM.prior))))./sum(sum(sum(sum(PM.pdf./PM.prior)))));
se_lUP = sqrt(sum(sum(sum(sum(((PM.priorLambdas-lUP).^2).*PM.pdf./PM.prior))))./sum(sum(sum(sum(PM.pdf./PM.prior)))));

if PM.gpu
    [PM.threshold(trial), PM.slope(trial), PM.guess(trial), PM.lapse(trial), PM.seThreshold(trial), PM.seSlope(trial), PM.seGuess(trial), PM.seLapse(trial), PM.thresholdUniformPrior(trial), PM.slopeUniformPrior(trial), PM.guessUniformPrior(trial), PM.lapseUniformPrior(trial), PM.seThresholdUniformPrior(trial), PM.seSlopeUniformPrior(trial), PM.seGuessUniformPrior(trial), PM.seLapseUniformPrior(trial)] = ...
        gather(a, b, g, l, se_a, se_b, se_g, se_l, aUP, bUP, gUP, lUP, se_aUP, se_bUP, se_gUP, se_lUP);
else
    PM.threshold(trial) = a;
    PM.slope(trial) = b;
    PM.guess(trial) = g;
    PM.lapse(trial) = l;
    PM.seThreshold(trial) = se_a;
    PM.seSlope(trial) = se_b;
    PM.seGuess(trial) = se_g;
    PM.seLapse(trial) = se_l;
    PM.thresholdUniformPrior(trial) = aUP;
    PM.slopeUniformPrior(trial) = bUP;
    PM.guessUniformPrior(trial) = gUP;
    PM.lapseUniformPrior(trial) = lUP; 
    PM.seThresholdUniformPrior(trial) = se_aUP;
    PM.seSlopeUniformPrior(trial) = se_bUP;
    PM.seGuessUniformPrior(trial) = se_gUP;
    PM.seLapseUniformPrior(trial) = se_lUP;
end

if PM.gammaEQlambda
    PM.guess(trial) = PM.lapse(trial);
    PM.seGuess(trial) = PM.seLapse(trial);
    PM.guessUniformPrior(trial) = PM.lapseUniformPrior(trial);
    PM.seGuessUniformPrior(trial) = PM.seLapseUniformPrior(trial);
end
if trial == PM.numTrials
    PM.stop = 1;
end