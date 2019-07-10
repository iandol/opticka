%
%PAL_PFHB_getSummaryStats    Calculates summary statistics for parameters 
%   in Bayesian analysis.
%
%   syntax: [summStats] = PAL_PFHB_getSummaryStats(pfhb)
%
%   Creates a structure 'summStats' with fields:
%       .linList: structure that lists all free and derived parameters: 
%           .p: parameter name (e.g., 'a', 'bsigma', 'l', 'l_actual', etc.)
%           .s: subject ID: 1, 2, etc
%           .c: condition (or effect) ID: 1, 2, etc.
%           .Rhat: value for Rhat (or psrf)
%           (PAL_PFHB_inspectParam(pfhb,'rhat') will go through parameters
%               in order of Rhat value (high to low))
%           .ess: value for ess (effective sample size)
%           (PAL_PFHB_inspectParam(pfhb,'ess') will go through parameters
%               in order of ess value (low to high))
%       .{parameter name} (e.g., .a, .asigma, also: .deviance):
%           .mode
%           .mean
%           .median
%           .sd (standard deviation)
%           .ess (effective sample size)
%           .HDI95low (lower bound on 95% Highest Density Interval)
%           .HDI95high (higher bound on 95% Highest Density Interval)
%           .HDI68low (lower bound on 68.27% Highest Density Interval)
%           .HDI68high (higher bound on 68.27% Highest Density Interval)
%           .Rhat: value for Rhat (or psrf)
%       .dic: estimate of deviance information criterion (mean(deviance) +
%           var(deviance)/2; e.g., Gelman et al, 2004)(Not working for 
%           Stan)
%       .corrMatrix: bivariate correlations between all pairs of parameters
%           in .linList (in same order, i.e., corrMatrix(n,m) contains
%           correlation between the n-th and m-th entry in .linList.
%           PAL_PFHB_inspectParam(pfhb,'correlation') will go through pairs
%           of parameters in order of correlation strength (high to low)
%
%Introduced: Palamedes version 1.10.0 (NP)

function [summStats] = PAL_PFHB_getSummaryStats(pfhb)
    
params = fieldnames(pfhb.samples);
samplesAll = [];
iLinList = 0;

for Iparam = 1:length(params)
    sample = pfhb.samples.(params{Iparam});    
    switch params{Iparam}
        case 'a' 
            rows = pfhb.model.a.Nc;
            columns = pfhb.model.Nsubj;
        case 'a_actual' 
            rows = pfhb.model.Ncond;
            columns = pfhb.model.Nsubj;
        case 'b' 
            rows = pfhb.model.b.Nc;
            columns = pfhb.model.Nsubj;
        case 'b_actual' 
            rows = pfhb.model.Ncond;
            columns = pfhb.model.Nsubj;
        case 'g' 
            rows = pfhb.model.g.Nc;
            columns = pfhb.model.Nsubj;
        case 'g_actual' 
            rows = pfhb.model.Ncond;
            columns = pfhb.model.Nsubj;
        case 'l' 
            rows = pfhb.model.l.Nc;
            columns = pfhb.model.Nsubj;
        case 'l_actual' 
            rows = pfhb.model.Ncond;
            columns = pfhb.model.Nsubj;
        case 'amu' 
            rows = pfhb.model.a.Nc;
            columns = 1;
        case 'amu_actual' 
            rows = pfhb.model.Ncond;
            columns = 1;
        case 'asigma' 
            rows = pfhb.model.a.Nc;
            columns = 1;
        case 'bmu' 
            rows = pfhb.model.b.Nc;
            columns = 1;
        case 'bmu_actual' 
            rows = pfhb.model.Ncond;
            columns = 1;
        case 'bsigma' 
            rows = pfhb.model.b.Nc;
            columns = 1;
        case 'gmu' 
            rows = pfhb.model.g.Nc;
            columns = 1;
        case 'gmu_actual' 
            rows = pfhb.model.Ncond;
            columns = 1;
        case 'gkappa' 
            rows = pfhb.model.g.Nc;
            columns = 1;
        case 'lmu' 
            rows = pfhb.model.l.Nc;
            columns = 1;
        case 'lmu_actual' 
            rows = pfhb.model.Ncond;
            columns = 1;
        case 'lkappa' 
            rows = pfhb.model.l.Nc;
            columns = 1;
        case 'deviance'
            rows = 1;
            columns = 1;
           
    end
        
    sz = size(sample);
    sample = reshape( sample, sz(1), sz(2), rows*columns,[]);
    samplesAll = [samplesAll reshape(sample,sz(1)*sz(2),[])];    

    for index = 1:size(sample,3)
        
        condition = mod((index-1),rows)+1;
        subject = ceil(index/rows);
        iLinList = iLinList + 1;
        summStats.linList.p(iLinList) = {params{Iparam}};
        summStats.linList.s(iLinList) = subject;
        summStats.linList.c(iLinList) = condition;
        samplep = sample(:,:,index);     
        
        if isfield(pfhb.model,(params{Iparam})) && isfield(pfhb.model.(params{Iparam}),'boundaries')
            boundaries = pfhb.model.(params{Iparam}).boundaries;
        else
            boundaries = [-Inf,Inf];
        end
        [grid,pdf,cdf] = PAL_kde(samplep(:),boundaries);
        summStats.(params{Iparam}).mode(index) = grid(pdf == max(pdf));
        summStats.(params{Iparam}).mean(index) = mean(samplep(:));
        summStats.(params{Iparam}).median(index) = median(samplep(:));
        summStats.(params{Iparam}).sd(index) = std(samplep(:));
        summStats.(params{Iparam}).ess(index) = PAL_PFHB_getESS(samplep);
        i = 1;
        width = [];
        while cdf(i) <.05
            m_below = cdf(i);
            j = find(cdf<(.95+m_below),1,'last');
            width(i) = j - i;
            i = i + 1;
        end
        [minim, I] = PAL_findMax(-width);
        summStats.(params{Iparam}).HDI95low(index) = grid(I(2)+1);
        summStats.(params{Iparam}).HDI95high(index) = grid(I(2)-minim);
        while cdf(i) <.3173
            m_below = cdf(i);
            j = find(cdf<(.6827+m_below),1,'last');
            width(i) = j - i;
            i = i + 1;
        end
        [minim, I] = PAL_findMax(-width);
        summStats.(params{Iparam}).HDI68low(index) = grid(I(2)+1);
        summStats.(params{Iparam}).HDI68high(index) = grid(I(2)-minim);
        summStats.(params{Iparam}).Rhat(index) = PAL_PFHB_getRhat(samplep);
        summStats.linList.Rhat(iLinList) = summStats.(params{Iparam}).Rhat(index);
        summStats.linList.ess(iLinList) = summStats.(params{Iparam}).ess(index);
        if strcmp(params{Iparam},'deviance')
            summStats.dic = mean(samplep(:))+var(samplep(:))/2; %Gelman et al., 2004
        end
        
    end
    
    summStats.(params{Iparam}).mode = reshape(summStats.(params{Iparam}).mode,[rows columns]);
    summStats.(params{Iparam}).mean = reshape(summStats.(params{Iparam}).mean,[rows columns]);
    summStats.(params{Iparam}).median = reshape(summStats.(params{Iparam}).median,[rows columns]);
    summStats.(params{Iparam}).sd = reshape(summStats.(params{Iparam}).sd,[rows columns]);    
    summStats.(params{Iparam}).HDI95low = reshape(summStats.(params{Iparam}).HDI95low,[rows columns]);
    summStats.(params{Iparam}).HDI95high = reshape(summStats.(params{Iparam}).HDI95high,[rows columns]);
    summStats.(params{Iparam}).HDI68low = reshape(summStats.(params{Iparam}).HDI68low,[rows columns]);
    summStats.(params{Iparam}).HDI68high = reshape(summStats.(params{Iparam}).HDI68high,[rows columns]);
    summStats.(params{Iparam}).ess = reshape(summStats.(params{Iparam}).ess,[rows columns]);
    summStats.(params{Iparam}).Rhat = reshape(summStats.(params{Iparam}).Rhat,[rows columns]);
    
end

summStats.corrMatrix = corrcoef(samplesAll);