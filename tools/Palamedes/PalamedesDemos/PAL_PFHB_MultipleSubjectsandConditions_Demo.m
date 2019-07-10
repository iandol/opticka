%
%PAL_PFHB_MultipleSubjectsandConditions_Demo  Demonstrates use of 
%PAL_PFHB_fitModel.m to fit multiple psychometric functions to data derived 
%from multiple subjects testing in multiple conditions using a Bayesian 
%criterion. Data are collected using the psi-marginal method (this takes a 
%little bit of time). The model that is fitted is shown here:
%www.palamedestoolbox.org/hierarchicalbayesian.html)
%JAGS (http://mcmc-jags.sourceforge.net/) or cmdSTAN ('command Stan')
%(https://mc-stan.org/users/interfaces/cmdstan.html) must first be
%installed before this will work. JAGS or Stan will perform the MCMC
%sampling of the posterior. Some of the optional tweaks are demonstrated
%here.
%Note that in order for MCMC sampling to converge you'll need at least one
%of these conditions to exist:
%1. High number of trials
%2. Informative priors (default priors are not informative)
%3. High number of participants
%4. Low number of free parameters
%5. Luck
%(see www.palamedestoolbox.org/understandingfitting.html for more
%information on why fits may fail to converge).
%
%NP (May 2019)

engine = input('Use Stan or JAGS (either must be installed from third party first, see PAL_PFHB_fitModel for information)? Type stan or jags: ','s');

disp(['Generating some data using adaptive method. This may take a while....',char(10)]);


Ncond = 4;
Nsubj = 6;
Ntrials = 500;
PF = @PAL_Logistic;

%Generate some data using adaptive psi-method (type help PAL_AMPM_setupPM
%for more information)

grain = 51;

%Define parameter ranges to be included in posterior
priorAlphaRange = linspace(-2, 2,grain);
priorBetaRange =  linspace(-1,1,grain); %Use log10 transformed values of beta (slope) parameter in PF
priorGammaRange = 0; %Value shown here is inconsequential: guess rate will be constrained to be equal to lapse rate
priorLambdaRange = 0:.01:.1; 

stimRange = [linspace(-4,4,51)];


[a b g l] = ndgrid(priorAlphaRange,priorBetaRange,priorGammaRange,priorLambdaRange);

prior = PAL_pdfNormal(a,0,1).*PAL_pdfNormal(b,0,1).*betapdf(l,1,10);    %prior for psi-marginal method
prior = prior./sum(sum(sum(sum(prior))));

%generating parameters
for cond = 1:Ncond
    a(cond,1:Nsubj) = .25*randn(1)+randn(1,Nsubj)*.5;
    b(cond,1:Nsubj) = .5+.25*randn(1)+randn(1,Nsubj)*.25;
end
l = repmat([.01 .02 .03 .07 .01 .04],[Ncond,1]);    %different lapse rate for each subjects
g = l;

data.x = [];
data.s = [];
data.c = [];
data.y = [];
data.n = [];

for c = 1:Ncond
    
    for s = 1:Nsubj
        
        paramsGen = [a(c,s), 10.^b(c,s), g(c,s), l(c,s)];   %parameter values [alpha, beta, gamma, lambda] (or [threshold, slope, guess, lapse]) used to simulate observer

        %Initialize PM structure
        PM = PAL_AMPM_setupPM('priorAlphaRange',priorAlphaRange,...
                              'priorBetaRange',priorBetaRange,...
                              'priorGammaRange',priorGammaRange,...
                              'priorLambdaRange',priorLambdaRange,...
                              'numtrials',Ntrials,...
                              'PF' , PF,...
                              'stimRange',stimRange,...
                              'marginalize',[4],...
                              'gammaeqlambda',true,...
                              'prior',prior);                  


        %trial loop
        while PM.stop ~= 1

            response = rand(1) < PF(paramsGen, PM.xCurrent);    %simulate observer

            %update PM based on response
            PM = PAL_AMPM_updatePM(PM,response);

        end
        [xG yG nG] = PAL_PFML_GroupTrialsbyX(PM.x(1:end-1),PM.response,ones(size(PM.response)));

        data.x = [data.x xG];
        data.y = [data.y yG];
        data.n = [data.n nG];
        data.c = [data.c c*ones(size(xG))];
        data.s = [data.s s*ones(size(xG))];

    end
end

disp(['Analyzing data....',char(10)]);

[pfhb] = PAL_PFHB_fitModel(data,'engine',engine,'prior','bmu','normal',[0 1],'prior','b','normal',[0 1],'nsamples',15000,'gammaeqlambda',true);

PAL_PFHB_inspectParam(pfhb,'amu','condition',2);
PAL_PFHB_inspectParam(pfhb,'a','subject',1,'condition',1,'l','subject',1,'effect',1);

PAL_PFHB_inspectFit(pfhb,'subject',1,'condition',1,'centraltend','mean');