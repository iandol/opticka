%
%PAL_PFHB_fitModel  Fit psychometric function(s) to single set of data or
%   simultaneously to multiple sets of data obtained from multiple subjects
%   and/or in multiple conditions using Bayesian criterion. Requires that
%   JAGS (http://mcmc-jags.sourceforge.net/) or cmdSTAN ('command Stan')
%   (https://mc-stan.org/users/interfaces/cmdstan.html) is installed.
%   Compatible with Linux, MAC, Windows, Octave and Matlab. Please cite
%   JAGS or Stan (as well as Palamedes) when you use this function in your 
%   research.
%   
%   syntax: pfhb = PAL_PFHB_fitModel(data,{optional arguments})
%
%Input: 
%
%   'data': structure that must (at least) have fields: 'x','y', and 'n'.
%       Fields 'x', 'y', and 'n' must have same length and list, 
%       respectively, the stimulus intensity, the number of positive 
%       responses observed at intensities listed in 'x', and the number of 
%       trials used at intensities listed in 'x'. If data were obtained 
%       from multiple subjects, structure should also contain a field 's', 
%       which for each entry lists the subject ID using consecutive 
%       integers starting with 1 (1, 2, 3, ..). If data were obtained 
%       across multiple conditions, structure should also contain a field 
%       'c', which for each entry lists the condition ID using consecutive 
%       integers starting with 1 (1, 2, 3, ..). See the various PFHB demo
%       programs in PalamedesDemos folder for examples.
%
%Output:
%
%   'pfhb': structure that contains data, information on the model fitted,
%       'raw' JAGS/STAN samples, and summary statistics for the model 
%       parameters. 'pfhb' may be inspected directly, may be passed to
%       PAL_PFHB_inspectFit to inspect data and fit obtained in a specific
%       condition for a specific subject (type 'help PAL_PFHB_inspectFit')
%       or may be passed to PAL_PFHB_inspectParam to inspect, for each 
%       specific parameter, the posterior distribution with summary
%       statistics as well as diagnostics (type 'help
%       PAL_PFHB_instpectParam'). Note that reported slope parameter values
%       are on a log10-transformed scale relative to the 'beta' parameter
%       found in standard parameterizations of the various psychometric
%       function (logistic, gumbel, etc.). 
%
%By default, PAL_PFHB_fitModel will fit a model with location parameter 
%   (aka, 'threshold') and slope unconstrained across conditions, guess
%   rate fixed at 0.5 (i.e., 2-AFC is assumed) and the lapse rate
%   constrained to be equal across conditions (but not subjects). This
%   effectively assumes that each subject has his/her own lapse rate that
%   is constant across all conditions. The default form of the sigmoid is 
%   the logistic function. A schematic of the default model and default 
%   prior functions used is shown here:
%   www.palamedestoolbox.org/hierarchicalbayesian.html
%   By default, JAGS will be used as the MCMC sampler.
%   The default choices may be modified using optional arguments listed 
%   below.
%
%Optional arguments:
%
%   'PF': Should be followed by form of psychometric function to be fitted.
%       Options: 'logistic' (default), 'cumulativenormal', 'weibull',
%       'gumbel' (i.e., log-Weibull), 'quick', 'logquick',
%       'hyperbolicsecant'. Note: Instead of using Weibull or Quick it is
%       strongly recommended to log-transform stimulus intensities and use 
%       the log-forms of these functions instead (gumbel and logquick,
%       respectively). See www.palamedestoolbox.org/weibullandfriends.html
%
%   'a','location', or 'threshold': Specify constraint on the PFs location
%       parameter across multiple conditions. Options: 
%           'unconstrained' (default): location parameter is free to vary
%               across conditions
%           'constrained': location parameters are constrained to have same
%               value across all conditions.
%           a model matrix: one also has the option to specify a
%               reparametrization of the location parameter using a model 
%               matrix. Model matrix must have as many columns as there are
%               conditions. Each row of the matrix defines a to-be- 
%               estimated parameter as some linear combination of location 
%               parameters (using e.g., a so-called 'contrast'). See 
%               examples in PalamedesDemos folder. 
%           'fixed': fixed value is used for parameter. Option 'fixed' 
%               should be followed by a third argument: a scalar value that 
%               is to be used as the fixed value for parameter.
%
%   'b', or 'slope': Specify constraint on the PFs log10(slope) parameter 
%       across multiple conditions. Options are identical to those for 'a'
%       above.
%
%   'l', or 'lapse': Specify constraint on the PFs lapse parameter 
%       across multiple conditions. Options are identical to those for 'a'
%       above. Note though that when a model matrix is used care should be 
%       taken that a beta distribution makes sense as the prior for the 
%       parameters the model defines. Essentially, rows of model matrix
%       should define mean lapse rate across multiple conditions (e.g., 
%       [1/2 1/2 0 0 0] would define a to-be-estimated parameter that would 
%       correspond to the mean lapse rate across conditions 1 and 2 in a 5 
%       condition experiment). Default: 'constrained' (in effect assuming 
%       that the probability of lapsing is independent of condition).
%
%   'g', or 'guess': Specify constraint on the PFs guess parameter 
%       across multiple conditions. Options (and concerns) are identical to 
%       those for 'l' above, except that the default is 'fixed' (at 0.5, 
%       appropriate for 2AFC task).
%
%   'gammaEQlambda': when followed by 1 (or true) the guess rate is
%       constrained to equal the lapse rate as would be appropriate for
%       some tasks.
%
%   'prior': priors for any parameters may be changed using the 'prior'
%       argument. the argument should be followed by three additional
%       arguments. The first specifies the parameter to which the prior
%       should be applied ('a', 'b', 'g', 'l', 'amu', 'asigma', bmu',
%       'bsigma', 'gmu', 'gkappa', 'lmu', or 'lkappa'). The second 
%       specifies the form of the prior distribution ('norm' or 'tdis' for
%       'a','b','amu', and 'bmu'; 'beta' or 'unif' for 'g','l','gmu', and
%       'lmu'; 'gamma' or 'unif' for 'asigma', 'bsigma', 'gkappa', and
%       'lkappa'). The third specifies parameters for prior as a 1 x 2 
%       vector ([mean, sd] for 'norm' and 'tdis'; [mean, concentration] for
%       'beta'; [lower_bound, upper_bound] for 'unif'; [shape, rate] for
%       gamma). Parameter values for 'a', 'b', 'g', and 'l' will be ignored
%       if data from multiple subjects are modelled, but must still be
%       supplied (use, e.g., [0 0]). See
%       www.palamedestoolbox.org/hierarchicalbayesian.html for key to the
%       interpretation of the various parameters.
%
%   'engine': when followed by 'stan', Stan MCMC sampler will be used. If
%       followed by 'jags', JAGS MCMC sampler will be used. Default:
%       'jags'. Either must be installed from third party first. 
%
%   'enginepath', 'stanpath', or 'jagspath' (interchangeable): If not used, 
%       PAL_PFHB_fitModel will look for Stan or JAGS in a few locations 
%       where they may be expected to reside (e.g., /opt directory in 
%       Linux, in MS Windows Palamedes will check whether path is included 
%       in Windows PATH variable). Palamedes will make some effort to
%       locate and use the latest version of sampler software if multiple 
%       versions are installed, but may not select the newest version if 
%       different versions reside on different branches of your file 
%       structure. Palamedes may also fail to find any version of Stan or 
%       JAGS. To specify path yourself use this argument followed by the 
%       path to directory (e.g., 'enginepath','/opt/cmdstan-2.18.1').
%
%   'seed': followed by positive integer makes MCMC sampler use the 
%       specified integer as seed for the random number generator. The 
%       environment's (Matlab or Octave) random number generator will also 
%       be seeded with this number (the environment used generator to
%       jitter initial values to be used by MCMC sampler.
%
%   'keep': when followed by 1 (or logical true) stores some temporary 
%       JAGS/STAN specific files in a (created) subfolder of the current 
%       folder (i.e., folder from which PAL_PFHB_fitModel is called0. When 
%       followed by 0 (or logical false) JAGS/STAN files will be deleted 
%       after run. Default: false.
%
%   'recyclestan': If followed by logical false or 0 (default) and Stan is 
%       used, a new executable Stan sampler will be compiled and build. 
%       This is a time-consuming process. In order to use a previously-
%       built executable Stan sampler that is located in the current 
%       directory follow 'recyclestan' by logical true or 1. If
%       'recyclestan' is followed by logical true but no executable stan
%       sampler exists in currect folder, a new executable Stan sample will
%       be created and placed in the current folder such that it can be
%       used in consequent runs. Note that when an existing Stan executable
%       is recycled, all model specifications are those that were specified 
%       when the executable was built. Note also that Stan executables are 
%       specific to model choices, number of subjects, etc.
%
%   'parallel': when followed by logical true (or non-zero scalar) MCMC
%       chains will run in parallel (no parallel toolbox required). When 
%       followed by logical false (or 0) MCMC chains will run in series 
%       (default). Depending on your OS and whether you're using Octave or 
%       Matlab messages from sampler may either not be visible at all or 
%       appear in various ways (in Matlab or Octave command window or in OS 
%       windows). Note that when 'parallel' is set to true, force-quitting 
%       PAL_PFHB_fitModel or even quitting Octave/Matlab will not terminate 
%       MCMC sampling once it has started. In case you force-quit 
%       PAL_PFHB_fitModel before sampling is completed, terminate any MCMC 
%       processes that are still using OS. When 'parallel' is set to true, 
%       PAL_PFHB_fitModel will (simultaneously) use either all processor 
%       cores the machine has available or as many processor cores as there 
%       are MCMC chains to be run (whichever is the lower number).
%
%   'nchains': followed by a positive integer specifies the number of MCMC
%       chains JAGS or Stan should run. Default: 3.
%
%   'nsamples': followed by a positive integer specifies the number of 
%       MCMC samples that should be taken per chain. Default: 5000.
%
%   'nburnin': followed by a positive integer specifies the number of 
%       MCMC 'burn in' samples should be taken per chain. Default: 1000.
%       Only affects JAGS, not STAN.
%
%   'nadapt': followed by a positive integer specifies the number of 
%       MCMC adaptation samples should be taken per chain. Default: 1000.
%
%   'initialize': allows user to provide starting values for MCMC samples.
%       This should be the first attempt to remedy poor convergence of a 
%       given model and dataset. By default, PAL_PFHB_fitModel uses the 
%       distribution of trials across stimulus intensities to find intial 
%       values that should at least be somewhere in the ballpark. To 
%       override this, use the 'initialize' option. Three arguments must be 
%       provided to change initial values. The first is 'initialize', the 
%       second specifies the parameter to be initialized ('a', 'b', 'g', 
%       'l','amu','asigma','bmu','bsigma','gmu','gkappa','lmu','lkappa'), 
%       and the third is an array that specifies the initial values to be 
%       used. For 'a', 'b', 'g', or 'l', this array should be of size 
%       1 x nc or ns x nc (where ns = number of subjects in experiment and 
%       nc = number of conditions in experiment (or number of 'effects' if 
%       parameter is 'constrained' or a model matrix is used to specify 
%       constraints on parameter). If a 1 x nc array is specified and 
%       multiple subjects are included in data structure, the values
%       specified will be used for all subjects. For 'amu', 'asigma', 
%       'bmu', 'bsigma', 'gmu', 'gkappa', 'lmu', and 'lkappa' array should
%       be 1 x nc.
%
%   Using 'Inf' or '-Inf' as stimulus intensity:
%       Note that stimulus intensities may include -Inf and Inf. Function 
%       'F' in the generic formulation of the psychometric function:
%
%       psi(x) = gamma + (1 - gamma - lambda)*F(x; alpha, beta)
%           (e.g., eq. 4.2b in Kingdom & Prins, 2016)
%
%       will evaluate to 0 and 1 when x = -Inf and Inf respectively.
%       Stimulus intensities equal to Inf may be used to implement fitting
%       of the lapse rate 'jAPLE' style (Prins, 2012). That is, if a 
%       stimulus intensity is used that is so high that it can be safely 
%       assumed that a negative (e.g., incorrect) response there must be 
%       due to a lapse, a model can be fitted that takes that into account. 
%       This can be implemented by setting this stimulus intensity to Inf 
%       in the data structure. Such a strategy can significantly reduce 
%       uncertainty in the lapse rate and concomitantly in the location and 
%       slope parameters. See equation (2) in Prins (2012) Journal of 
%       Vision, 12(6), 25 for the model that is fitted when this option is 
%       used. Above generalizes to tasks for which a positive responce at a 
%       very low stimulus value can be safely assumed to be the result of a 
%       lapse. In that case, -Inf should be assigned to the very low 
%       stimulus value. A stimulus intensity equal to -Inf may also be used 
%       when a stimulus intensity equal to 0 was used but stimulus 
%       intensities in data.x are log-transformed.
%
%
%Example of simple, one condition, one subject PF fit:
%
%   data.x = [-2:1:2];
%   data.y = [48 62 75 84 96];
%   data.n = 100*ones(1,5);
%   
%   pfhb = PAL_PFHB_fitModel(data);
%   PAL_PFHB_inspectFit(pfhb);       %accepts optional arguments
%   PAL_PFHB_inspectParam(pfhb);     %accepts optional arguments
%
%other examples are included in the PalamedesDemos folder.
%
%Introduced: Palamedes version 1.10.0 (NP)
%Modified: Palamedes version 1.10.1, 1.10.2, 1.10.4 (See History.m)

function [pfhb] = PAL_PFHB_fitModel(data, varargin)

disp([char(10),'Prepping ....']);

pfhb = PAL_PFHB_setupModel(data, varargin{:});
if ~pfhb.engine.found
    error('PALAMEDES:noMCMCSamplerfound','No sampler (or way to build it) found. Exiting');
end
if strcmp(pfhb.machine.environment,'octave')    
    confirm_recursive_rmdir(0, 'local');
end

PAL_PFHB_data2Rdump(pfhb.data,strcat(pfhb.engine.dirout,filesep,'data_Rdump.R'));
PAL_PFHB_writeInits(pfhb.engine);

if strcmp(pfhb.engine.engine,'jags')
    PAL_PFHB_writeScript(pfhb.engine, pfhb.model);
end
if strcmp(pfhb.engine.engine,'stan')
     if pfhb.engine.recyclestan && ((exist('stanModel','file') && any(strcmpi(pfhb.machine.machine,{'MACI64','GLNXA64'}))) || (exist('stanModel.exe','file') && strcmpi(pfhb.machine.machine,'PCWIN64')))
        disp('Recycling existing Stan executable ...');
     else
        disp('Stan is building executable ...');
        [status, OSsays, syscmd] = PAL_PFHB_buildStan(pfhb.engine,pfhb.machine);
        if status ~= 0
            message = ['Building Stan executable failed. Palamedes issued the command: ',char(10), syscmd, char(10), 'to your OS and your OS said: ',char(10), OSsays, char(10)];
            message = [message, 'First thing to do is to try and find out whether CmdStan is in working order:',char(10)];             
            message = [message, 'Q1: Does PAL_PFHB_SinglePF_Demo (in PalamedesDemos folder) complete without error when you select Stan?', char(10)];
            message = [message, 'If you answered ''yes'' to Q1: This is possibly a Palamedes bug. Send us an e-mail: palamedes@palamedestoolbox.org.', char(10)];
            message = [message, 'If you answered ''no'' to Q1, move to Q2.', char(10)];
            message = [message, 'Q2: Can you get the CmdStan bernoulli example (see CmdStan User''s guide) to work? (if you have multiple versions of CmdStan use the same version Palamedes is trying to use): ', char(10)]; 
            message = [message, 'If you answered ''yes'' to Q2: This is possibly a Palamedes bug. Send us an e-mail: palamedes@palamedestoolbox.org.', char(10)]; 
            message = [message, 'If you answered ''no'' to Q2: Get bernoulli example to work, then try again.']; 
            error('PALAMEDES:StanBuildFail',message);
        end
     end
end

disp(['Waiting for ',upper(pfhb.engine.engine),' to complete ....',char(10)]);    
[status OSsays pfhb.engine.syscmd] = PAL_PFHB_runEngine(pfhb.engine,pfhb.machine);
if status ~= 0
    message = ['Execution of ',upper(pfhb.engine.engine), ' failed. Palamedes issued the command: ',char(10), pfhb.engine.syscmd, char(10), 'to your OS and your OS (or ',upper(pfhb.engine.engine),') said: ',char(10), OSsays, char(10)];
    error('PALAMEDES:SamplerExecuteFail',message);
else
    if strcmpi(pfhb.engine.engine,'jags') && ~isempty(OSsays)
        temp = find(OSsays == ' ', 4);
        pfhb.engine.version = OSsays(temp(3)+1:temp(4)-1);
    end
end


disp(['Reading and analyzing samples ....',char(10)]);
if strcmp(pfhb.engine.engine,'jags')
    pfhb.samples = PAL_PFHB_readCODA(pfhb.engine);
else
    [pfhb.samples trash trash pfhb.engine.version] = PAL_PFHB_readStanOutput(pfhb.engine);    
end
if ~pfhb.engine.keep
    rmdir(pfhb.engine.dirout,'s');
end
pfhb = PAL_PFHB_organizeSamples(pfhb);

pfhb.summStats = PAL_PFHB_getSummaryStats(pfhb);

[maxRhat] = PAL_findMax(pfhb.summStats.linList.Rhat); 
pfhb.model.message = [char(10),char(10),'Fit completed using ',pfhb.engine.engine,' sampler. The maximum value of Gelman and Rubin''s Rhat diagnostic (or psrf',char(10),'[''Potential Scale Reduction Factor'']) observed was ', num2str(maxRhat,'%.5f'), ' (a value smaller than 1.05 is generally considered',char(10)','to suggest successful convergence). In order to inspect parameters in decreasing order of Rhat value, type',char(10), '''PAL_PFHB_inspectParam([name of model structure],''Rhat'').',char(10),char(10)];
disp(pfhb.model.message);
disp(pfhb.model.paramsList);

end