%
%PAL_PFBA_Fit   Fit parameters of psychometric function using Bayesian 
%           criterion.
%
%syntax: [paramsValues posterior] = PAL_PFBA_Fit(StimLevels, NumPos, ...
%           OutOfNum, parameterGrid, PF, {optional arguments})
%
%PAL_PFBA_Fit derives a posterior distribution across threshold x slope x
%   guess rate x lapse rate parameter space and computes expected values of 
%   parameters (to be used as parameter estimates). Standard errors are 
%   derived as the marginal standard deviations of parameters in posterior
%   distribution.
%
%Input: 
%   'StimLevels': vector containing the stimulus levels utilized
%
%   'NumPos': vector of equal length to 'StimLevels' containing for each of 
%       the stimulus levels the number of positive responses (e.g., 'yes' 
%       or 'correct') observed.
%
%   'OutOfNum': vector of equal length to 'StimLevels' containing the 
%       number of trials tested at each of the stimulus levels.
%
%   'parameterGrid': structure with fields: alpha, beta, gamma, lambda.
%       Each field specifies a vector or scalar containing values for the
%       parameter to be included in the posterior distribution. grid.beta
%       values must be specified as log10 transforms of the beta parameters 
%       in the PF.
%
%   'PF': The psychometric function to be fitted. This needs to be passed 
%       as an inline function. Options include:
%           @PAL_Logistic
%           @PAL_Weibull
%           @PAL_Gumbel (i.e., log-Weibull)
%           @PAL_Quick
%           @PAL_logQuick
%           @PAL_CumulativeNormal
%           @PAL_Gumbel
%           @PAL_HyperbolicSecant
%
%Output:
%   'paramsValues': 2x4 array. First row contains parameter estimates 
%       ([threshold slope guess lapse]). Second row contains standard
%       errors of parameters.
%
%   'posterior': The posterior distribution. Useful to check e.g., whether 
%       the posterior is (effectively) contained within the parameter space
%       considered, whether the distribution is symmetrical, etc.
%
%   User has the option to specify a prior distribution (if no prior is
%       provided, a rectangular distribution on parameterGrid is used as 
%       prior [aka 'uniform prior' or 'prior of ignorance']). The prior 
%       distribution should be defined across the parameter space [i.e., be 
%       of size length(grid.alpha)xlength(grid.beta)xlength(grid.gamma)x
%       length(grid.lambda)]. Use optional argument 'prior', followed by 
%       array containing the prior to specify a prior other than the 
%       uniform prior. 
%
%Full Example:
%
%   StimLevels = [-3:1:3];
%   NumPos = [55 55 66 75 91 94 97];
%   OutOfNum = [100 100 100 100 100 100 100];
%   grid.alpha = [-1:.01:1];
%   grid.beta = [-.5:.01:.5];
%   grid.gamma = 0.5;
%   grid.lambda = [0:.01:.06];
%   PF = @PAL_Logistic;
%
%   %Using uniform prior:
%
%   [paramsValues] = PAL_PFBA_Fit(StimLevels, NumPos, ...
%       OutOfNum, grid, PF)
%
%   returns:
%
%   paramsValues =
%
%   -0.2967    0.0741    0.5000    0.0260
%    0.2228    0.1018    0.0000    0.0169
%
%   %Or specify custom prior:
%
%   [a b g l] = ndgrid(grid.alpha,grid.beta,grid.gamma,grid.lambda);
%   prior = PAL_pdfNormal(a,0,2).*PAL_pdfNormal(b,0,1).*l.^2.*(1-l).^98; %last two terms define beta distribution (minus normalization) with mode 0.02 on lapse rate
%   prior = prior./sum(sum(sum(sum(prior))));   %normalization happens here
%   [paramsValues posterior] = PAL_PFBA_Fit(StimLevels, ...
%       NumPos, OutOfNum, grid, PF,'prior',prior);
%
%Introduced: Palamedes version 1.0.0 (NP)
%Modified: Palamedes version 1.6.3, 1.8.1 (see History.m)

function [paramsValues, posterior] = PAL_PFBA_Fit(StimLevels, NumPos, OutOfNum, varargin);

if isstruct(varargin{1})    %Using 'new style' (version 1.8.1 onwards)
    grid = varargin{1};    
    PF = varargin{2};
    if length(varargin)>2
        valid = 0;
        if strcmpi(varargin{3}, 'prior')
            prior = varargin{4};
            valid = 1;
        end
        if valid == 0
            warning('PALAMEDES:invalidOption','%s is not a valid option. Ignored.',varargin{n});
        end        
    else
        prior = ones(length(grid.alpha),length(grid.beta),length(grid.gamma),length(grid.lambda));
        prior = prior/sum(sum(sum(sum(prior))));
    end
    
    [StimLevels, NumPos, OutOfNum] = PAL_PFML_GroupTrialsbyX(StimLevels, NumPos, OutOfNum);

    grid.beta = 10.^grid.beta;
    [trash trash posterior] = PAL_PFML_BruteForceFit(StimLevels,NumPos, OutOfNum, grid, PF);
    grid.beta = log10(grid.beta);    
    
    posterior = posterior-max(max(max(max(posterior))));
    posterior = exp(posterior);
    posterior = posterior.*prior;
    posterior = posterior/sum(sum(sum(sum(posterior))));

    posteriora = squeeze(sum(sum(sum(posterior,4),3),2))';
    posteriorb = squeeze(sum(sum(sum(posterior,4),3),1));
    posteriorg = squeeze(sum(sum(sum(posterior,4),2),1))';
    posteriorl = squeeze(sum(sum(sum(posterior,3),2),1))';

    paramsValues(1,1) = sum(posteriora.*grid.alpha);
    paramsValues(1,2) = sum(posteriorb.*grid.beta);
    paramsValues(1,3) = sum(posteriorg.*grid.gamma);
    paramsValues(1,4) = sum(posteriorl.*grid.lambda);

    paramsValues(2,1) = (sum(posteriora.*(grid.alpha-paramsValues(1,1)).^2))^.5;
    paramsValues(2,2) = (sum(posteriorb.*(grid.beta-paramsValues(1,2)).^2))^.5;
    paramsValues(2,3) = (sum(posteriorg.*(grid.gamma-paramsValues(1,3)).^2))^.5;
    paramsValues(2,4) = (sum(posteriorl.*(grid.lambda-paramsValues(1,4)).^2))^.5;

else           %using 'old style' (version 1.8.0 and earlier)

    message = ['You are using PAL_PFBA_Fit ''old style''. PAL_PFBA_Fit has improved! '];
    message = [message 'However, new style usage is not compatible with old style usage. For '];
    message = [message 'now, old and new style usage are both supported. To learn new style usage '];
    message = [message 'type ''help PAL_PFBA_Fit''. In some future version of Palamedes, old style '];
    message = [message 'usage will no longer be supported.'];
    warning('PALAMEDES:OldStyle', message);
    [paramsValues posterior] = PAL_PFBA_Fit_OldStyle(StimLevels, NumPos, OutOfNum, varargin{1},varargin{2}, varargin{3},varargin{4}, varargin{5},varargin{6:length(varargin)});
    
end