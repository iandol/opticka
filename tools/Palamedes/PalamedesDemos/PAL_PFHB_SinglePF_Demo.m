%
%PAL_PFHB_SinglePF_Demo  Demonstrates use of PAL_PFHB_fitModel.m to fit a
%single psychometric function to some data using a Bayesian criterion. The 
%model that is fitted is shown here:
%www.palamedestoolbox.org/hierarchicalbayesian.html)
%JAGS (http://mcmc-jags.sourceforge.net/) or cmdSTAN ('command Stan')
%(https://mc-stan.org/users/interfaces/cmdstan.html) must first be
%installed before this will work. JAGS or Stan will perform the MCMC
%sampling of the posterior.
%Note that in order for MCMC sampling to converge you'll need at least one
%of these conditions to exist:
%1. High number of trials (this is why this fit will likely converge)
%2. Informative priors (default priors are not informative)
%3. High number of participants
%4. Low number of free parameters
%5. Luck
%(see www.palamedestoolbox.org/understandingfitting.html for more
%information on why fits may fail to converge).
%
%NP (May 2019)

engine = input('Use Stan or JAGS (either must be installed from third party first, see PAL_PFHB_fitModel for information)? Type stan or jags: ','s');

data.x = [-2:1:2];
data.y = [48 62 75 84 96];
data.n = 100*ones(1,5);

%Use defaults (except for engine):
pfhb = PAL_PFHB_fitModel(data,'engine',engine);

PAL_PFHB_inspectFit(pfhb);       %accepts optional arguments
PAL_PFHB_inspectParam(pfhb);     %accepts optional arguments