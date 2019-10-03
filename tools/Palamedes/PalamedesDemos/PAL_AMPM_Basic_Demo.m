%
%PAL_AMPM_Basic_Demo  Demonstrates use of Palamedes routines to implement 
%the basic 'psi' adaptive procedure (Kontsevich & Tyler, 1999) without any 
%frills. If you're new to using the psi method start here. PAL_AMPM_Demo
%demonstrates some variations on the psi method (see Prins, 2013 or 
%www.palamedestoolbox.org/psimarginal.html) and has lots of code that make
%pretty pictures, implement fancy options and such but might make code hard 
%to plow through.
%
%The psi-method keeps track of a 2D (threshold x slope) posterior and 
%selects stimulus placement that will minimize the expected entrop in this 
%posterior. It assumes a fixed lapse and guess rate.
%
%Note that user may define a prior other than the constrained uniform prior
%used here (see PAL_AMPM_Demo for example).
%
%Demonstrates usage of Palamedes functions:
%-PAL_AMPM_setupPM
%-PAL_AMPM_updatePM
%secondary:
%PAL_Gumbel
%
%More information on any of these functions may be found by typing
%help followed by the name of the function. e.g., help PAL_AMPM_setupPM
%
%References:
%
%Kontsevich, LL & Tyler, CW (1999). Bayesian adaptive estimation of
%psychometric slope and threshold. Vision Research, 39, 2729-2737.
%
%Prins, N. (2013). The psi-marginal adaptive method: how to give nuisance 
%parameters the attention they deserve (no more, no less). Journal of
%Vision, 13(7):3, 1-17. doi: 10.1167/13.7.3 
%
%NP (June 2016)

clear all

S = warning('QUERY', 'PALAMEDES:AMPM_setupPM:priorTranspose');
warning('off','PALAMEDES:AMPM_setupPM:priorTranspose');

fprintf(1,'\n')
disp('This script demonstrates basic, no-frills use of Kontsevich & Tyler''s (1999)')
disp('original psi-method. PAL_AMPM_Demo demonstrates variations on the psi method,')
disp('uses a non-uniform prior and other fancy options, and makes pretty pictures.')
fprintf(1,'\n')
disp('To see figures of trial-to-trial stimulus placement and posterior, run PAL_AMPM_Demo ');
disp('and select ''Original Psi'' when prompted');
fprintf(1,'\n')

%Set up psi
NumTrials = 240;

grain = 201; %grain of posterior, high numbers make method more precise at the cost of RAM and time to compute.
             %Always check posterior after method completes [using e.g., :
             %image(PAL_Scale0to1(PM.pdf)*64)] to check whether appropriate
             %grain and parameter ranges were used.

PF = @PAL_Gumbel; %assumed psychometric function

%Stimulus values the method can select from
stimRange = (linspace(PF([0 1 0 0],.1,'inverse'),PF([0 1 0 0],.9999,'inverse'),21));

%Define parameter ranges to be included in posterior
priorAlphaRange = linspace(PF([0 1 0 0],.1,'inverse'),PF([0 1 0 0],.9999,'inverse'),grain);
priorBetaRange =  linspace(log10(.0625),log10(16),grain); %Use log10 transformed values of beta (slope) parameter in PF
priorGammaRange = 0.5;  %fixed value (using vector here would make it a free parameter) 
priorLambdaRange = .02; %ditto
%tip: Free parameters sensibly and responsibly (as opposed to just because you can). See www.palamedestoolbox.org/understandingfitting.html.

%Initialize PM structure
PM = PAL_AMPM_setupPM('priorAlphaRange',priorAlphaRange,...
                      'priorBetaRange',priorBetaRange,...
                      'priorGammaRange',priorGammaRange,...
                      'priorLambdaRange',priorLambdaRange,...
                      'numtrials',NumTrials,...
                      'PF' , PF,...
                      'stimRange',stimRange);                  

paramsGen = [0, 1, .5, .02];   %parameter values [alpha, beta, gamma, lambda] (or [threshold, slope, guess, lapse]) used to simulate observer
                                
%trial loop
while PM.stop ~= 1

    response = rand(1) < PF(paramsGen, PM.xCurrent);    %simulate observer

    %update PM based on response
    PM = PAL_AMPM_updatePM(PM,response);

end

disp('Threshold estimate:')
PM.threshold(end)
disp('Slope estimate:')
10.^PM.slope(end)           %PM.slope is in log10 units of beta parameter

%reset warning to original state
warning(S);