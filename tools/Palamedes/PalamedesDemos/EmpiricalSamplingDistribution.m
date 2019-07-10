% EmpiricalSamplingDistribution.m compares a sampling distribution for the
% transformed likelihood ratio (asymptotically distributed as chi-square)
% to the theoretical sampling distribution. The model comparison is that
% between the fuller and lesser model described in section 3.3 of Prins &
% Kingdom (citation to follow)
%
% NP (January 2018)


function [] = EmpiricalSamplingDistribution()

if ~exist('PAL_version','file')
    disp('This demo requires the Palamedes toolbox to be installed and to be added ');
    disp('to Matlab''s search path. To download the Palamedes toolbox visit:');
    disp('www.palamedestoolbox.org');
    return;
end
if ~exist('chi2cdf','file')
    disp('It appears you do not have the Matlab ''statistics'' toolbox. The figure ');
    disp('will not contain the theoretical chi-square probability density function');
    chisquare = 0;
else
    chisquare = 1;
end

%Data for a two condition experiment (each row of the arrays corresponds to one
%condition).
StimLevels = [-2:1:2; -2:1:2];
OutOfNum = [50 50 50 50 50; 50 50 50 50 50];
NumPos =  [3 8 29 40 47; 2 3 31 45 49];

numMCsimuls = 10000;

%Parameter values (exact values to use for fixed parameters, guesses for free parameters)
%[threshold slope guess lapse] (may also specify different values for each condition using 
%array of size: number of conditions x 4)
parameterSeed = [0 2 0.02 0.02]; 

[paramsValuesLesser, LLLesser, ~, ~, ~, numParamsLesser] = ...
    PAL_PFML_FitMultiple(StimLevels, NumPos, OutOfNum, parameterSeed, @PAL_Logistic,...
    'thresholds','fixed',...
    'slopes','constrained',...
    'lapserates','fixed',...
    'guessrates','fixed');
[paramsValuesFuller, LLFuller, ~, ~, ~, numParamsFuller] = ...
    PAL_PFML_FitMultiple(StimLevels,NumPos,OutOfNum,paramsValuesLesser,@PAL_Logistic,...
    'thresholds','fixed',...
    'slopes','unconstrained',...
    'lapserates','fixed',...
    'guessrates','fixed');
[TLRFullervsLesser, pMCFullervsLesser, ~, ~, TLRSim] = PAL_PFLR_ModelComparison(StimLevels,NumPos,...
    OutOfNum,paramsValuesLesser,numMCsimuls,@PAL_Logistic,...
    'fullerthresholds','fixed',...
    'lesserthresholds','fixed',...
    'fullerslopes','unconstrained',...
    'lesserslopes','constrained',...
    'lesserguessrates','fixed',...
    'fullerguessrates','fixed',...
    'lesserlapserates','fixed',...
    'fullerlapserates','fixed');

%print results to command window
fprintf('\nLesser model: \n\n');
fprintf('Thresholds/PSEs\tSlopes\t\tGuess rates\tLapse rates\n');
fprintf('%f\t',paramsValuesLesser(1,:))
fprintf('\n');
fprintf('%f\t',paramsValuesLesser(2,:))
fprintf('\nNumber of free parameters: %d', numParamsLesser);

fprintf('\n\n\nFuller model: \n\n');
fprintf('Thresholds/PSEs\tSlopes\t\tGuess rates\tLapse rates\n');
fprintf('%f\t',paramsValuesFuller(1,:))
fprintf('\n');
fprintf('%f\t',paramsValuesFuller(2,:))
fprintf('\nNumber of free parameters: %d\n\n', numParamsFuller);

%Model comparisons based on p-values
fprintf('Null Hypothesis test Fuller vs Lesser model:');
fprintf('\nTransformed Likelihood Ratio (asymptotically distributed as chi-square): %f.',...
    TLRFullervsLesser);
fprintf('\ndegrees of freedom: %d.', numParamsFuller - numParamsLesser);
if chisquare   %statistics toolbox installed, use theoretical chi-square distribution
    pchisquare = 1-chi2cdf(TLRFullervsLesser,numParamsFuller-numParamsLesser);
    fprintf('\np-value based on chi-square distribution: %f', pchisquare);
end
fprintf('\np-value based on empirical sampling distribution: %f\n', pMCFullervsLesser);

figure('units','pixels','position',[100 100 500 300]);

barwidth = .1;
maxim = 13;
barcenters = [barwidth/2:barwidth:maxim];
vol = length(TLRSim)*barwidth;

tlr = hist(TLRSim,barcenters);
ax1 = axes('units','normalized','position',[.15 .2 .8 .75]);
bar(ax1,barcenters,tlr,1,'facecolor','y')
hold on
if chisquare
    plot(ax1,0.01:.01:maxim,chi2pdf(0.01:.01:maxim,1)*vol,'linewidth',1,'color','k');
end
xlim = [0 5];
ylim = [0 1.2*max(tlr)];
set(ax1, 'xlim',xlim,'ylim',ylim)
if chisquare
    xlabel('TLR/\chi^2')
else
    xlabel('TLR')
end
ylabel('frequency/density');

