%PAL_PFLR_LearningCurve_Demo.m
%
%This function analyzes the results of a human observer (MH) in a perceptual 
%learning experiment. MH was trained in 13 sessions of 500 trials each, %
%then performed two sessions (sessions 14 and 15) in which the retinal 
%location of the stimuli was changed from those trained, then performed two 
%sessions (sessions 16 and 17) at the trained retinal location but the 
%relevant task information was contained in first-order channels different 
%from those trained. Finally, MH performed two sessions (session 18 and 19) 
%using the original trained stimuli presented at the originally trained 
%retinal locations. Of theoretical interest was (among other things) 
%whether training transferred across first-order channels. In order to 
%address this question, two models are compared. In one (the 'lesser'  
%model), the thresholds in sessions 16 and 17 were constrained to adhere to
%the same learning curve that the 'trained sessions' were to adhere to. In
%the other (the 'fuller' model), the thresholds in sessions 16 and 17 were
%not so constrained but were free to take on any value. Thresholds in
%session 14 and 15 were free to take on any value in both models. Both
%models further assumed that the slope of the psychometric functions was 
%equal across sessions, that the lapse rate was equal across sessions and 
%that the function describing proportion correct as a function of stimulus 
%intensity in each of the session was a Gumbel function. These assumptions
%are tested in a Goodness-of-Fit test.
%
%The learning curve that thresholds in sessions 1-13 and 18-19 (fuller
%model) or sessions 1-13 and 16-19 (lesser model) were constrained to lie
%on was a three-parameter exponential decay function. It's three parameters
%describe the lower asymptote, the overall drop in threshold and the rate
%of this drop.
%
%Note that this is a one-step fit. The raw data (9,500 trials) are fit
%simultaneously across all 19 sessions. This is as opposed to a two-step
%fit in which sessions are fit individually, followed by fitting a learning
%curve to the threshold estimates. The one step approach has several
%advantages, among which are:
%   -it allows one to fit a single slope value across all sessions
%   -it allows one to fit a single lapse rate value across all sessions.
%       This single lapse rate is based on all 9,500 trials. As such, it
%       actually estimates the lapse rate (as opposed to accommodating 
%       sampling error, Prins 2012). Neither in the data fit nor in the 
%       fits to the bootstrap simulations is it necessary to constrain the 
%       lapse rate to an arbitrary interval.
%   -it takes into account that data in some sessions are 'messier' than 
%       data in other sessions. The messy sessions exert less inluence on 
%       the learning curve than 'cleaner' sessions.
%
%Prins, N. (2012). The psychometric function: The lapse rate revisited.
%   Journal of Vision, 12(6): 25. www.journalofvision.org/content/12/6/25
%
%NP (October 2015)

function [] = PAL_PFLR_LearningCurve_Demo()

clear all

if exist('OCTAVE_VERSION');
    fprintf('\nUnder Octave, Figures may not render (at all!) as intended. Visit\n');
    fprintf('www.palamedestoolbox.org/demosfiguregallery.html to see figures\n');
    fprintf('as intended.\n\n');
end

if exist('MH_data.mat','file')
    load('MH_data.mat'); %Data from observer MH
else
    disp('File MH_data.mat not found. Bye');
    return;
end

message = sprintf('Number of simulations to perform to determine standar');
message = strcat(message, 'd errors (try low number (e.g., 10) first, in ');
message = strcat(message, 'order to get an idea of how long this will take): ');
Bse = input(message);
message = sprintf('Number of simulations to perform to determine model c');
message = strcat(message, 'omparison p-values (ditto): ');
Bmc = input(message);

PF = @PAL_Gumbel;

[LLsat numParamsSat] = PAL_PFML_LLsaturated(NumPos, OutOfNum); %'Fit' saturated model

%%%%%%%%%Fuller Model F: 9 params (3 for learning curve, 4 transfer thresholds, 1 shared slope, 1 shared lapse) 

funcParamsF.funcA = @ParameterizeThresholds;            %function defined below
funcParamsF.paramsValuesA = [-.5 .35 .2 .1 .1 .1 .1];   %guesses for parameter values
funcParamsF.paramsFreeA = [1 1 1 1 1 1 1];              %1: free parameter, 0: fixed parameter
funcParamsF.funcB = @ParameterizeSlopes;                %function defined below
funcParamsF.paramsValuesB = [log(3)];                   %guesses for parameter values
funcParamsF.paramsFreeB = [1];                          %1: free parameter, 0: fixed parameter

%fit fuller model
[paramsF LLF exitflagF outputF funcParamsF numParamsF] = PAL_PFML_FitMultiple(StimLevels,NumPos,OutOfNum,[0 0 .5 .03],PF,'thresholds',funcParamsF,'slopes',funcParamsF,'guessrates','fixed','lapserates','cons','lapselimits',[0 1]);

%%%%%%%%%Lesser Model L: 7 params (3 for curve, 2 retinal location transfer thresholds, 1 shared slope, 1 shared lapse) 

funcParamsL = funcParamsF;                              %Model identical to above, except:
funcParamsL.paramsValuesA(6:7) = 0;                     %Set deviation of thresholds in sessions 16 and 17 from learning curve to value of 0
funcParamsL.paramsFreeA(6:7) = 0;                       %and fix these values

%fit lesser model
[paramsL LLL exitflagL outputL funcParamsL numParamsL] = PAL_PFML_FitMultiple(StimLevels,NumPos,OutOfNum,[0 0 .5 .03],PF,'thresholds',funcParamsL,'slopes',funcParamsL,'guessrates','fixed','lapserates','cons','lapselimits',[0 1]);

%Perform fuller vs lesser model comparison using likelihood ratio test
[TLR pTLR paramsL paramsF TLRSim converged funcParamsL funcParamsF] = PAL_PFLR_ModelComparison(StimLevels,NumPos,OutOfNum,paramsL,Bmc,PF,'lesserthresholds',funcParamsL,'lesserslopes',funcParamsL,'lesserguessrates','fixed','lesserlapserates','cons','fullerthresholds',funcParamsF,'fullerslopes',funcParamsF,'fullerguessrates','fixed','fullerlapserates','cons','lapselimits',[0 1]);

%Get SEs on parameters of fuller model through bootstrap:
[SD paramsFSim LLSim converged SDFfunc funcParamsFSim] = PAL_PFML_BootstrapParametricMultiple(StimLevels,OutOfNum,paramsF,Bse,PF,'thresholds',funcParamsF,'slopes',funcParamsF,'guessrates','fixed','lapserates','cons','lapselimits',[0 1]);

%Perform fuller vs saturated model comparison (i.e., Goodness-of-fit for fuller model)
[Dev pDev DevSim converged] = PAL_PFML_GoodnessOfFitMultiple(StimLevels,NumPos,OutOfNum,paramsF,Bmc,PF,'thresholds',funcParamsF,'slopes',funcParamsF,'guessrates','fixed','lapserates','cons','lapselimits',[0 1]);

%Fit conditions individually (for visualization only, not used in any model comparison)
searchGrid.alpha = linspace(-1,0,100);
searchGrid.beta = logspace(-1,2,100);
searchGrid.gamma = .5;
searchGrid.lambda = paramsF(1,4); %Use shared lapse rate under fuller model as fixed value

for cond = 1:19    
    [paramsI(cond,:) LLI(cond) exitflagI(cond)] = PAL_PFML_Fit(StimLevels(cond,:),NumPos(cond,:),OutOfNum(cond,:),searchGrid, [1 1 0 0],PF);
    [sdI(cond,:)] = PAL_PFML_BootstrapParametric(StimLevels(cond,:),OutOfNum(cond,:),paramsI(cond,:), [1 1 0 0],Bse,PF,'searchGrid',searchGrid);
end

%Remainder of code only serves to create figures
figure('units','pixels','position',[100 100 1000 600]);

%Text
axes('units','normalized','position',[.0 .85 1 .15]);
axis off;
text(.01,.8,'Model comparison: does learning transfer to change in orientation channel?','fontsize',16);
text(.01,.5,'Fuller Model: Thresholds 1 thru 13, 18 and 19 adhere to 3 parameter learning curve (green), 14 thru 17 are free, 1 shared slope, 1 shared lapse');
text(.01,.3,'Lesser Model: Thresholds 1 thru 13 and 16 thru 19 adhere to 3 parameter learning curve (red), 14 and 15 are free, 1 shared slope, 1 shared lapse');

%Results & Model Fits

axes('units','normalized','position',[.05 .5 .4 .3]);
x = [1:.01:13.5];
plot(x, funcParamsF.paramsValuesA(1) + funcParamsF.paramsValuesA(2)*exp(-funcParamsF.paramsValuesA(3)*(x-1)),'-','color',[0 .7 0],'linewidth',1);
hold on;
x = [17.5:.01:19];
plot(x, funcParamsF.paramsValuesA(1) + funcParamsF.paramsValuesA(2)*exp(-funcParamsF.paramsValuesA(3)*(x-1)),'-','color',[0 .7 0],'linewidth',1);
x = [13.5:.01:17.5];
plot(x, funcParamsF.paramsValuesA(1) + funcParamsF.paramsValuesA(2)*exp(-funcParamsF.paramsValuesA(3)*(x-1)),':','color',[0 .7 0],'linewidth',1);
x = [1:.01:13.5];
plot(x, funcParamsL.paramsValuesA(1) + funcParamsL.paramsValuesA(2)*exp(-funcParamsL.paramsValuesA(3)*(x-1)),'-','color',[.7 0 0],'linewidth',1);
x = [15.5:.01:19];
plot(x, funcParamsL.paramsValuesA(1) + funcParamsL.paramsValuesA(2)*exp(-funcParamsL.paramsValuesA(3)*(x-1)),'-','color',[.7 0 0],'linewidth',1);
x = [13.5:.01:15.5];
plot(x, funcParamsL.paramsValuesA(1) + funcParamsL.paramsValuesA(2)*exp(-funcParamsL.paramsValuesA(3)*(x-1)),':','color',[.7 0 0],'linewidth',1);

plot([1:13 18:19],paramsI([1:13 18:19],1),'ko','markerfacecolor','k','markersize',8);
hold on
plot([14:15],paramsI([14:15],1),'ks','markerfacecolor','w','markersize',8,'linewidth',1);
plot([16:17],paramsI([16:17],1),'k^','markerfacecolor','w','markersize',8,'linewidth',1);
plot(7,.9*(log10(.9)-log10(.4))+log10(.4),'ko','markerfacecolor','k','markersize',8);
text(8,.9*(log10(.9)-log10(.4))+log10(.4),'Trained','fontsize',10);
plot(7,.82*(log10(.9)-log10(.4))+log10(.4),'ks','markerfacecolor','w','markersize',8,'linewidth',1);
text(8,.82*(log10(.9)-log10(.4))+log10(.4),'Retinal Location Change','fontsize',10);
plot(7,.74*(log10(.9)-log10(.4))+log10(.4),'k^','markerfacecolor','w','markersize',8,'linewidth',1);
text(8,.74*(log10(.9)-log10(.4))+log10(.4),'Orientation Channel Change','fontsize',10);
for cond = 1:19
    line([cond cond],[paramsI(cond,1)-sdI(cond,1) paramsI(cond,1)+sdI(cond,1)],'color','k','linewidth',1);
end
axis([0 20 log10(.4) log10(.9)]);
text(3,.9*(log10(.9)-log10(.4))+log10(.4),'MH','FontSize',18);
set(gca,'ytick',[log10(.4) log10(.5) log10(.6) log10(.7) log10(.8) log10(.9)],'yticklabel',{'.4','.5','.6','.7','.8','.9'});
set(gca,'xtick',[0:5:20]);
text(0,1.08*(log10(.9)-log10(.4))+log10(.4),'Individual thresholds and model fits',...
     'color',[0 0 0],'Fontsize',11); 
set(gca,'linewidth',2,'fontsize',10);
xlabel('Session','fontsize',14);
ylabel('Threshold','fontsize',14);

%Learning rate under fuller model
axes('units','normalized','position',[.06 .07 .05 .3]);
hold on;
box on;
set(gca,'xlim',[0 2],'ylim',[.2 .4],'ytick',[.2:.1:.4],'xtick',[],'linewidth',2);
ylabel('Learning rate');

plot(1,funcParamsF.paramsValuesA(3),'o','color',[0 .7 0],'markerfacecolor',[0 .7 0],'markersize',10);
line([1 1],[funcParamsF.paramsValuesA(3)-SDFfunc.A(3) funcParamsF.paramsValuesA(3)+SDFfunc.A(3)],'linewidth',2,'color',[0 .7 0]);

text(0,1.08*(.4-.2)+.2, 'A few parameters and their SEs under fuller model','fontsize',11)

%Threshold asymptote under fuller model5
axes('units','normalized','position',[.18 .07 .05 .3]);
hold on;
box on;
set(gca,'xlim',[0 2],'ylim',[.4 .5],'ytick',[.4:.05:.5],'xtick',[],'linewidth',2);
ylabel('Threshold asymptote');

semilogy(1,10.^funcParamsF.paramsValuesA(1),'o','color',[0 .7 0],'markerfacecolor',[0 .7 0],'markersize',10);
line([1 1],[10.^(funcParamsF.paramsValuesA(1)-SDFfunc.A(1)) 10.^(funcParamsF.paramsValuesA(1)+SDFfunc.A(1))],'linewidth',2,'color',[0 .7 0]);



%(Shared) slope under fuller model
axes('units','normalized','position',[.3 .07 .05 .3]);
hold on;
box on;
set(gca,'xlim',[0 2],'ylim',[4 7],'ytick',[4:1:7],'xtick',[],'linewidth',2);
ylabel('(shared) Slope');

semilogy(1,exp(funcParamsF.paramsValuesB(1)),'o','color',[0 .7 0],'markerfacecolor',[0 .7 0],'markersize',10);
line([1 1],[exp(funcParamsF.paramsValuesB(1)-SDFfunc.B(1)) exp(funcParamsF.paramsValuesB(1)+SDFfunc.B(1))],'linewidth',2,'color',[0 .7 0]);

%(Shared) lapse rate under fuller model
axes('units','normalized','position',[.42 .07 .05 .3]);
hold on;
box on;
set(gca,'xlim',[0 2],'ylim',[.03 .07],'ytick',[.03:.01:.07],'xtick',[],'linewidth',2);
ylabel('(shared) lapse');

plot(1,paramsF(1,4),'o','color',[0 .7 0],'markerfacecolor',[0 .7 0],'markersize',10);
line([1 1],[paramsF(1,4)-SD(1,4) paramsF(1,4)+SD(1,4)],'linewidth',2,'color',[0 .7 0]);

%Simulated TLRs model comparison
axes('units','normalized','position',[.55 .5 .4 .3]);
[n centers] = hist(TLRSim(TLRSim<15),40);
hist(TLRSim(TLRSim<15),40);

h = findobj(gca,'Type','patch');
set(gca,'FontSize',12)
set(h,'FaceColor','y','EdgeColor','k')
set(gca,'xlim',[0 15]);
xlim = get(gca, 'Xlim');
hold on
if exist('chi2pdf.m') == 2
    volume = sum(n*(centers(2)-centers(1)));
    chi2x = xlim(1):xlim(2)/250:xlim(2);
    [maxim I]= max(n);
    chi2 = chi2pdf(chi2x,2)*volume;
    plot(chi2x,chi2,'k-','linewidth',2)
end
ylim = get(gca, 'Ylim');
plot(TLR,.05*ylim(2),'kv','MarkerSize',12,'MarkerFaceColor','k')
text(TLR,.15*ylim(2),'TLR data','Fontsize',11,'horizontalalignment',...
     'center');
message = ['p_{simul}: ' num2str(pTLR,'%5.4f')];
text(.95*xlim(2),.8*ylim(2),message,'horizontalalignment','right',...
    'fontsize',10);
if exist('chi2cdf.m') == 2
     message = ['p_{chi2}: ' num2str(1-chi2cdf(TLR,...
         2),'%5.4f')];
     text(.95*xlim(2),.7*ylim(2),message,'horizontalalignment','right',...
         'fontsize',10);
 end
 text(0,1.08*ylim(2),'Model Comparison (fuller vs. lesser) sampling distribution',...
     'color',[0 0 0],'Fontsize',11);
 xlabel('Simulated TLRs','FontSize',12)
 ylabel('frequency','FontSize',12);
set(gca,'linewidth',2);

%Goodness-of-fit fuller model
axes('units','normalized','position',[.55 .07 .4 .3]);
[n centers] = hist(DevSim,40);
hist(DevSim,40)
h = findobj(gca,'Type','patch');
set(gca,'FontSize',12)
set(h,'FaceColor','y','EdgeColor','k')
set(gca,'xlim',[.833*min(Dev,centers(1)) 1.2*max(Dev,centers(length(centers)))]);
xlim = get(gca, 'Xlim');
hold on
if exist('chi2pdf.m') == 2
    volume = sum(n*(centers(2)-centers(1)));
    chi2x = xlim(1):xlim(2)/250:xlim(2);
    [maxim I]= max(n);
    chi2 = chi2pdf(chi2x,numParamsSat-7)*volume;
    plot(chi2x,chi2,'k-','linewidth',2)
end
ylim = get(gca, 'Ylim');
plot(Dev,.05*ylim(2),'kv','MarkerSize',12,'MarkerFaceColor','k')
text(Dev,.15*ylim(2),'Deviance data','Fontsize',11,'horizontalalignment',...
     'center');
message = ['p_{simul}: ' num2str(pDev,'%5.4f')];
text(.95*xlim(2),.8*ylim(2),message,'horizontalalignment','right',...
    'fontsize',10);
if exist('chi2cdf.m') == 2
     message = ['p_{chi2}: ' num2str(1-chi2cdf(Dev,...
         numParamsSat-7),'%5.4f')];
     text(.95*xlim(2),.7*ylim(2),message,'horizontalalignment','right',...
         'fontsize',10);
 end
 text(xlim(1),1.08*ylim(2),'Goodness Of Fit of fuller model',...
     'color',[0 0 0],'Fontsize',12,'horizontalalignment','left');
 xlabel('Simulated Deviances','FontSize',12)
 ylabel('frequency','FontSize',12);
 set(gca,'linewidth',2);
 
end

function alphas=ParameterizeThresholds(thetas)
session=1:19;
alphas(1:19)=thetas(1)+thetas(2)*exp(-thetas(3)*(session-1));
alphas(14:17)=alphas(14:17)+thetas(4:7); %will overwrite alphas(14:17)
end

function betas=ParameterizeSlopes(rho)
betas (1:19)=exp(rho(1));
end