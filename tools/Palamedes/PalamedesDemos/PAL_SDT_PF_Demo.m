
% PAL_SDT_PF_Demo
% Demonstrates use of Palamedes functions to fit a PF (psychometric
% function) with an SDT (signal detection theory) model
%
%Demonstrates usage of Palamedes PF SDT routines:
%-PAL_SDT_PFML_Fit
%-PAL_SDT_PFML_BootstrapParametric
%-PAL_SDT_PFML_GoodnessOfFit
%
%Demonstrates usage of Palamedes SDT stimulus intensity to prop. correct 
%conversion routine
% PAL_SDT_SLtoPC
%
%%Demonstrates usage of Palamedes SDT prop. correct to d'prime conversion 
%routines
% e.g. PAL_SDT_MAFC_PCtoDP.  See full list in script
%
%Demonstrates usage of Palamedes standard PF routines:
%-PAL_PFML_Fit
%-PAL_PFML_BootstrapParametric
%-PAL_PFML_GoodnessOfFit
%
%secondary function:
%-PAL_Weibull
%
%More information on any of these functions may be found by typing
%help followed by the name of the function. e.g., help PAL_SDT_PFML_Fit
%
%Introduced: Palamedes version 1.8.0 (FK & NP)

clear all;


message = sprintf('Number of simulations to perform to determine standar');
message = strcat(message, 'd errors: ');
Bse = input(message);
message = sprintf('Number of simulations to perform to determine model c');
message = strcat(message, 'omparison p-value: ');
Bmc = input(message);


% Stimulus Levels, number correct, out of total number trials etc. 
StimLevels = [1 2 3 4 5 6 7 8]; 
NumPos=[51 53 55 69 72 86 95 99];
OutOfNum = [100 100 100 100 100 100 100 100];

% Calculate proportion correct
PC=NumPos./OutOfNum;

% Plot proportion correct against stimulus levels
figure('name','Individual Psychometric Functions','units','pixels',...
    'position',[50 50 1200 400]); 

h1 = axes('units','normalized','position',[.1 .15 .2 .8]);
set(h1, 'fontsize',16);
axis([1 8 .4 1.0]); axis square;
set(gca, 'Xtick',1:1:8);
set(gca, 'Ytick',.4:.1:1);
hold on;
a=plot(StimLevels,PC,'ko','markersize',8,'markerfacecolor','k'); 
xlabel('Stimulus level');
ylabel('Proportion correct');

h1legend = axes('units','normalized','position',[.105 .63 .12 .2]);
hold on
set(h1legend, 'xtick',[],'ytick',[],'box','on','xlim',[0 1], 'ylim',[0 1])
plot(h1legend,.1,5/6, 'o','MarkerEdgeColor','k','MarkerFaceColor','k','Markersize',10,'Linewidth',2);
text(h1legend, .22,5/6,'Data','FontSize',14);
plot(h1legend,[.02 .18],[3/6 3/6], '-','LineWidth',2,'color',[0 .9 0])
text(h1legend, .22,3/6,'SDT fit','FontSize',14);
plot(h1legend,[.02 .18],[1/6 1/6], 'r-','LineWidth',2)
text(h1legend, .22,1/6,'Weibull fit','FontSize',14);


%---------------------------- SDT model------------------------------


% SDT function to be fitted, plus its inverse SDT function
% Note that you need to know whether the SDT function requires the input 
% argument M for the number of alternatives in the forced-choice task.
% Note also that if the function uses Monte Carlo (MC) simulation the 
% fitting function PAL_SDT_PFML_Fit will likely be very slow

SDTfunc = @PAL_SDT_2AFC_DPtoPC; 
%SDTfunc = @PAL_SDT_MAFC_DPtoPC; % requires M
%SDTfunc = @PAL_SDT_3AFCoddity_IndMod_DPtoPC;
%SDTfunc = @PAL_SDT_MAFCoddity_IndMod_DPtoPC;  % requires M, uses MC
%SDTfunc = @PAL_SDT_MAFCoddity_DiffMod_DPtoPC;  % requires M, uses MC
%SDTfunc = @PAL_SDT_2AFCmatchSample_IndMod_DPtoPC;
%SDTfunc = @PAL_SDT_2AFCmatchSample_DiffMod_DPtoPC;

invSDTfunc = @PAL_SDT_2AFC_PCtoDP; 
%invSDTfunc = @PAL_SDT_MAFC_PCtoDP; % requires M
%invSDTfunc = @PAL_SDT_3AFCoddity_IndMod_PCtoDP;
%invSDTfunc = @PAL_SDT_MAFCoddity_IndMod_PCtoDP;  % requires M
%invSDTfunc = @PAL_SDT_MAFCoddity_DiffMod_PCtoDP; % requires M
%invSDTfunc = @PAL_SDT_2AFCmatchSample_IndMod_PCtoDP;
%invSDTfunc = @PAL_SDT_2AFCmatchSample_DiffMod_PCtoDP;

% Set M to the num alternatives in the forced-choice task; if the selected 
% SDT function does not take M as an argument, set M=[]

%Guesses for free SDT params stimulus gain g and transducer exponent p
g=0.33;
p=1.5;
SDTparams = [g p]; 
M=[]; % set number of forced-choice alternatives to empty 

% Fit with SDT model
[SDTparamsOut, negLL, trash, trash] = PAL_SDT_PFML_Fit(StimLevels,NumPos,OutOfNum,SDTparams,SDTfunc,M);

g=SDTparamsOut(1); % fitted value of g
p=SDTparamsOut(2); % fitted value of p

% generate fine grain SDT PF for plot                            
StimLevelsFineGrain = linspace(min(StimLevels),max(StimLevels),1000);
PCfromSDTfineGrain = PAL_SDT_SLtoPC(StimLevelsFineGrain,g,p,SDTfunc,M);

% Add fine grain PF
b=plot(h1,StimLevelsFineGrain,PCfromSDTfineGrain,'-','linewidth',2,'color',[0 .9 0]);
drawnow
% set params to fitted params
SDTparams=SDTparamsOut;

%Determine Standard errors on g and p
message = sprintf('\rDetermining SDT PF model standard errors.........');
disp(message);

[gSE, pSE] = PAL_SDT_PFML_BootstrapParametric(StimLevels,SDTparams,OutOfNum,SDTfunc,M,Bse);

% --------------calculate d-primes from raw PC data for second graph --------------------
if isempty(M) 
    DP = invSDTfunc(PC);
else
    DP = invSDTfunc(PC,M);
end

% plot d prime against stimulus level for raw data on separate graph
h2 = axes('units','normalized','position',[.4 .15 .2 .8]);
set(h2, 'fontsize',16);
axis([1 8 -1 4.0]); axis square;
set(gca, 'Xtick',1:1:8);
set(gca, 'Ytick',-1:1:4);
hold on;
d=plot(StimLevels,DP,'ko','markersize',8,'markerfacecolor','k'); 
xlabel('Stimulus level');
ylabel('d-prime');
drawnow

% Add fine grain model PF
DPfineGrain=(g.*StimLevelsFineGrain).^p;
e=plot(StimLevelsFineGrain,DPfineGrain,'-','linewidth',2,'color',[0 .9 0]);
hold on;

h2legend = axes('units','normalized','position',[.405 .68 .12 .15]);
hold on
set(h2legend, 'xtick',[],'ytick',[],'box','on','xlim',[0 1], 'ylim',[0 1])
plot(h2legend,.1,3/4, 'o','MarkerEdgeColor','k','MarkerFaceColor','k','Markersize',10,'Linewidth',2);
text(h2legend, .22,3/4,'Data','FontSize',14);
plot(h2legend,[.02 .18],[1/4 1/4], '-','LineWidth',2,'color',[0 .9 0])
text(h2legend, .22,1/4,'SDT fit','FontSize',14);
drawnow


% plot log d prime against log stimulus level for raw data on separate graph
h3 = axes('units','normalized','position',[.7 .15 .2 .8]);
set(h3, 'fontsize',16);
axis([0 1 -2 1]); axis square;
set(gca, 'Xtick',0:.25:1);
set(gca, 'Ytick',-2:.5:1);
hold on;
f=plot(log10(StimLevels),log10(DP),'ko','markersize',8,'markerfacecolor','k'); 
xlabel('Log stimulus level');
ylabel('Log d-prime');
drawnow

% Add fine grain model PF
pCoeff=polyfit(log10(StimLevels),log10(DP),1);
linFit=pCoeff(2)+pCoeff(1).*log10(StimLevelsFineGrain);
e=plot(log10(StimLevelsFineGrain),linFit,'-','linewidth',2,'color',[0 .9 0]);
hold on;

h3legend = axes('units','normalized','position',[.705 .68 .12 .15]);
hold on
set(h3legend, 'xtick',[],'ytick',[],'box','on','xlim',[0 1], 'ylim',[0 1])
plot(h3legend,.1,3/4, 'o','MarkerEdgeColor','k','MarkerFaceColor','k','Markersize',10,'Linewidth',2);
text(h3legend, .22,3/4,'Data','FontSize',14);
plot(h3legend,[.02 .18],[1/4 1/4], '-','LineWidth',2,'color',[0 .9 0])
text(h3legend, .22,1/4,'SDT fit','FontSize',14);
drawnow

p2=pCoeff(1);
g2=10.^(pCoeff(2)./pCoeff(1));

% Type out results for SDT PF fitted params
message = sprintf('SDT PF model fitted parameters......');
disp(message);
message = sprintf('Direct fit stimulus gain g: %6.4f se: %6.4f',g,gSE);
disp(message);
message = sprintf('Direct fit exponent p: %6.4f se: %6.4f',p,pSE);
disp(message);
message = sprintf('Log straight line fit stimulus gain g: %6.4f',g2);
disp(message);
message = sprintf('Log straight line fit exponent p: %6.4f',p2);
disp(message);


% Determine goodness-of-fit
message = sprintf('\rDetermining SDT PF model goodness-of-fit.........');
disp(message);

[trash, pDev, trash, trash] = PAL_SDT_PFML_GoodnessOfFit(StimLevels,SDTparams,NumPos,OutOfNum,SDTfunc,M,Bmc);
message=sprintf('p-value to reject SDT PF model (e.g. p<0.05 to reject): p=%6.4f',pDev); 
disp(message);

%---------------------------- Standard PF model------------------------------

%Standard PF function to be fitted
PFfunc = @PAL_Weibull;

%Parameter grid defining parameter space through which to perform a
%brute-force search for values to be used as initial guesses in iterative
%parameter search.
searchGrid.alpha = 0:.1:10;
searchGrid.beta = logspace(0.1,3,100);
searchGrid.gamma = .5;  %guessing factor scalar here (since fixed) but may be vector
searchGrid.lambda = 0.02;  %ditto

%Threshold and Slope are free parameters, guess and lapse rate are fixed
PFparamsFree = [1 1 0 0];  %1: free parameter, 0: fixed parameter


%Optional:
options = PAL_minimize('options');   %type PAL_minimize('options','help') for help
options.TolFun = 1e-09;     %increase required precision on LL
options.MaxIter = 100;
options.Display = 'off';    %suppress fminsearch messages

%Perform fit
[PFparams, LL, exitflag, output] = PAL_PFML_Fit(StimLevels,NumPos, ...
    OutOfNum,searchGrid,PFparamsFree,PFfunc,'searchOptions',options);

% Generate fine grain values
PCfromPFfineGrain=PAL_Weibull(PFparams,StimLevelsFineGrain);

%subplot(1,3,1);
c=plot(h1,StimLevelsFineGrain,PCfromPFfineGrain,'-','linewidth',2,'color',[.9 0 0]);
hold on


% Determine standard PF model bootstrap errors and goodness-of-fit
message = sprintf('\rDetermining standard PF model bootstrap errors and goodness-of-fit......');
disp(message);

% Obtain bootstrap errors
[SD, trash, trash, trash] = PAL_PFML_BootstrapParametric(...
        StimLevels, OutOfNum, PFparams, PFparamsFree, Bse, PFfunc, ...
        'searchOptions',options,'searchGrid', searchGrid);
    
% Determine goodness-of-fit    
[Dev, pDev] = PAL_PFML_GoodnessOfFit(StimLevels, NumPos, OutOfNum, ...
    PFparams, PFparamsFree, Bmc, PFfunc,'searchOptions',options, ...
    'searchGrid', searchGrid);


message = sprintf('\rStandard PF model fitted parameters.............');
disp(message);
message = sprintf('Standard PF threshold: %6.4f se: %6.4f',PFparams(1),SD(1));
disp(message);
message = sprintf('Standard PF slope: %6.4f se: %6.4f',PFparams(2),SD(2));
disp(message);
message=sprintf('p-value to reject standard PF model (e.g. p<0.05 to reject): p=%6.4f',pDev); 
disp(message);