%
%PAL_PFHB_inspectParam    Display posterior and diagnostic plots for 
%   individual parameters or difference parameters, return summary 
%   statistics.
%
%   syntax: [stats samples]= ..
%               PAL_PFHB_inspectParam(pfhb,{optional arguments})
%
%Input:
%   
%   pfhb: Structure created and returned by PAL_PFHB_fitModel
%
%Optional arguments (none are case-sensitive, defaults are indicated by 
%   {}):
%
%   {parameter name} (e.g., {'a'}, 'lmu', 'deviance', etc.). A second 
%       parameter may be specified in which case plots show difference 
%       values and a scatter plot of the two parameters is included.
%
%   subject: follow by subject ID ({1}, 2, 3, etc.). Will be applied to
%       last specified parameter name (e.g., to plot difference between
%       parameter 'a' for subject 1 and parameter 'b' for subject 2 use:
%       PAL_PFHB_inspectParam(pfhb,'a','subject',1,'b','subject',2);)
%
%   condition (or effect): follow by condition ID ({1}, 2, 3, etc.) or by
%       number referring to row in model matrix applied to parameter (each 
%       row would presumably specify some effect (e.g., intercept, linear 
%       trend, pairwise comparison, etc.). Will be applied to last 
%       specified parameter name.
%
%   hdi: width of high density interval reported. Follow by scalar. If
%       supplied value is in (0, 1) it is interpreted as a proportion, if
%       it is in (1, 100) it will be interpreted as percentage. Default:
%       0.95.
%       
%   rhat: cycle through all parameters in order of Rhat value (high to 
%       low). Routine will wait for <enter> between parameters. This is
%       useful to investigate high Rhat values. To exit, precede <enter>
%       with 'q' (no quotes). Arguments specifying parameter name, subject 
%       or condition will be ignored.     
%
%   correl: cycle through all parameter pairings in order of correlation
%       between them (strong to weak). Routine will wait for <enter> 
%       between parameters. This is useful to investigate high Rhat values. 
%       To exit, precede <enter> with 'q' (no quotes). Arguments specifying 
%       parameter name, subject or condition will be ignored.     
%
%   ess: cycle through all parameters in order of ess value (low to 
%       high). Routine will wait for <enter> between parameters. This is
%       useful to investigate low values. To exit, precede <enter>
%       with 'q' (no quotes). Arguments specifying parameter name, subject 
%       or condition will be ignored.
%
%   nofigures: no figures are produced. Useful if one is only interested in
%       summary statistics not already available in pfhb (e.g., different
%       width of HDI, or difference between samples of two parameters)
%
%Output:
%
%   stats: structure containing summary statistics
%
%   samples: MCMC samples (useful only if two parameters are specified in
%       arguments in which case it contains the difference between the 
%       samples for the two parameters specified).
%
%Example:
%
%   data.x = [-2:1:2];
%   data.y = [48 62 75 84 96];
%   data.n = 100*ones(1,5);
%   
%   pfhb = PAL_PFHB_fitModel(data);
%   PAL_PFHB_inspectParam(pfhb,'l','hdi',.9);
%   PAL_PFHB_inspectParam(pfhb,'b','l','hdi',50);
%
%Introduced: Palamedes version 1.10.0 (NP)

function [stat, samples] = PAL_PFHB_inspectParam(pfhb, varargin)

params = fieldnames(pfhb.samples);
param1specified = false;
param2specified = false;
param1 = params{1};
subject1 = 1;
condition1 = 1;
param2 = params{1};
subject2 = 1;
condition2 = 1;
oneortwo = 1;
rhat = false;
correl = false;
ess = false;
order = 0;
hdi = 0.95;
nofigs = false;

if ~isempty(varargin)
    NumOpts = length(varargin);
    n = 1;
    while n <= NumOpts
        valid = 0;
        if any(strcmp(params,varargin{n}))
            if ~param1specified
                param1 = varargin{n};            
                param1specified = true;
            else
                param2 = varargin{n};    
                param2specified = true;
                oneortwo = 2;
            end
            valid = 1;
            add = 1;
        end
        if strcmpi(varargin{n}, 'subject')
            if param2specified
                param = param2;
            else
                param = param1;
            end
            if varargin{n+1} > pfhb.model.Nsubj
                message = [num2str(varargin{n+1}),' is not a valid value for ''subject'', maximum value is ', int2str(pfhb.model.Nsubj),'. Using subject 1 instead.'];
                warning('PALAMEDES:invalidOption',message);                
            else
                if any(strcmp({'amu','asigma','bmu','bsigma','gmu','gkappa','lmu','lkappa','deviance'},param))
                    message = ['''subject'' is not a valid argument for parameter ''',param,'''. Ignored.'];
                    warning('PALAMEDES:invalidOption',message);
                else
                    if param2specified
                        subject2 = varargin{n+1};
                    else
                        subject1 = varargin{n+1};
                    end
                end
            end
            valid = 1;
            add = 2;
        end
        if strcmpi(varargin{n}, 'condition') || strcmpi(varargin{n}, 'effect')
            if param2specified
                param = param2;
            else
                param = param1;
            end
            if strcmp('deviance',param)
                message = '''condition'' is not a valid argument for parameter ''deviance''. Ignored.';
                warning('PALAMEDES:invalidOption',message);
            else
                if varargin{n+1} > pfhb.model.(param(1)).Nc  
                    message = [num2str(varargin{n+1}),' is not a valid value for ''',varargin{n},''' (when ''parameter'' is ''',param,'''), maximum value is ', int2str(pfhb.model.(param(1)).Nc),'. Using value 1 instead. '];
                    if any(strcmp(params, strcat(param(1),'_actual'))) && varargin{n+1} <= pfhb.model.Ncond
                        message = [message, 'Note that parameter ''',param(1),''' was reparameterized (and thus, ''',varargin{n},''' does not actually refer to a condition in experiment, but rather to an effect [i.e., a row in the model matrix], in this case: [',PAL_removeSpaces(num2str(pfhb.model.(param(1)).c)),']).'];
                    end
                    warning('PALAMEDES:invalidOption',message);                
                else
                    if param2specified
                        condition2 = varargin{n+1};
                    else
                        condition1 = varargin{n+1};
                    end
                end
            end
            valid = 1;
            add = 2;
        end

        if strcmpi(varargin{n}, 'hdi')
            hdi = varargin{n+1};
            if hdi >= 1
                hdi = hdi/100;
            end
            valid = 1;            
            add = 2;
        end
        if strcmpi(varargin{n}, 'rhat')
            [trash, order] = sort(pfhb.summStats.linList.Rhat,'descend');  
            rhat = true;
            valid = 1;
            oneortwo = 1;
            add = 1;
        end
        if strcmpi(varargin{n}, 'ess')
            [trash, order] = sort(pfhb.summStats.linList.ess,'ascend');  
            ess = true;
            valid = 1;
            oneortwo = 1;
            add = 1;
        end
        if strncmpi(varargin{n}, 'nofigures',5)
            nofigs = true;
            valid = 1;
            add = 1;
        end        
        if strncmpi(varargin{n}, 'correl',3)
            cmatrix = tril(pfhb.summStats.corrMatrix,-1);
            cmatrix(abs(cmatrix-1)<1e-10) = 0;
            [trash, preorder] = sort(abs(cmatrix(:)),'descend');
            order = zeros(length(preorder),2);
            order(:,1) = mod(preorder-1,size(cmatrix,1))+1;
            order(:,2) = floor((preorder-1)/size(cmatrix,1))+1;
            correl = true;
            valid = 1;
            oneortwo = 2;
            add = 1;
        end

        if valid == 0
            warning('PALAMEDES:invalidOption','%s is not a valid option. Ignored.',varargin{n});
            n = n + 1;
        else        
            n = n + add;
        end
    end            
end

if nofigs
    order = 0;  %overrule if modified
end

for loop = 1:length(order)

    if rhat || ess
        param1 = pfhb.summStats.linList.p{order(loop)};
        condition1 = pfhb.summStats.linList.c(order(loop));
        subject1 = pfhb.summStats.linList.s(order(loop));
    end
    if correl
        param1 = pfhb.summStats.linList.p{order(loop,1)};
        condition1 = pfhb.summStats.linList.c(order(loop,1));
        subject1 = pfhb.summStats.linList.s(order(loop,1));
        param2 = pfhb.summStats.linList.p{order(loop,2)};
        condition2 = pfhb.summStats.linList.c(order(loop,2));
        subject2 = pfhb.summStats.linList.s(order(loop,2));
    end

    if ~((rhat || correl) && ~isempty(strfind(param1,'_actual')))     %Only show results for parameters that were directly sampled
    
        samples = getfield(pfhb.samples,param1,{':',':',condition1,subject1});

        if oneortwo == 2
            samples1 = samples;
            samples2 = getfield(pfhb.samples,param2,{':',':',condition2,subject2});
            samples = samples1-samples2;
        end

        maxlag = 20;
        auto = zeros(size(samples,1), maxlag+1,2,2);
        for chain = 1:size(samples,1)
            %autocorrelation
            for lag = 0:maxlag
                auto(chain,lag+1,:,:) = corrcoef(samples(chain,1:end-lag),samples(chain,1+lag:end));
            end
        end
        stat.ess = PAL_PFHB_getESS(samples,'autocorrelation'); 
        stat.Rhat = PAL_PFHB_getRhat(samples);

        if isfield(pfhb.model,(param1)) && isfield(pfhb.model.(param1),'boundaries') && oneortwo == 1
            boundaries = pfhb.model.(param1).boundaries;
        else
            boundaries = [-Inf,Inf];
        end
                
        [grid,pdf,cdf] = PAL_kde(samples(:),boundaries);

        i = 1;
        width = [];
        while cdf(i) < 1 - hdi
            m_below = cdf(i);
            j = find(cdf<(hdi+m_below),1,'last');
            width(i) = j - i;
            i = i + 1;
        end
        [minim, I] = PAL_findMax(-width);
        stat.HDIlow = grid(I(2)+1);
        stat.HDIhigh = grid(I(2)-minim);

        stat.mode = grid(find(pdf == max(pdf)));
        stat.mean = mean(samples(:));
        stat.median = median(samples(:));
        stat.sd = std(samples(:));
        
        if oneortwo == 2
            cc = corrcoef(samples1(:),samples2(:));
            stat.corr = cc(1,2);
        end                    
        
        if ~nofigs

            f = figure('units','normalized','position',[.1 .1 .8 .8]);

            tagboard = axes('units','normalized','position',[0 0 1 1],'fontsize',12,'xlim',[0 1],'ylim',[0 1]);
            hold on
            axis off;
            paramID = ['parameter: ''',param1,''''];        
            if any(strcmp(param1,{'a','b','g','l','a_actual','b_actual','g_actual','l_actual'})) && pfhb.model.Nsubj > 1
                paramID = [paramID, ' subject: ',int2str(subject1)];
            end
            if any(strcmp(param1,{'a','b','g','l','amu','bmu','gmu','lmu','asigma','bsigma','gkappa','lkappa'})) && pfhb.model.Ncond > 1
                if PAL_mmType(pfhb.model.(param1(1)).c) == 1
                    paramID = [paramID, ' condition: ',int2str(condition1)];
                end
                if PAL_mmType(pfhb.model.(param1(1)).c) == 2
                    paramID = [paramID, ' condition: all'];
                end
                if PAL_mmType(pfhb.model.(param1(1)).c) > 2
                    paramID = [paramID, ' effect: [',PAL_removeSpaces(num2str(pfhb.model.(param1(1)).c(condition1,:))),']'];                    
                end                    
            end
            figureHeader = paramID;
            if oneortwo == 2
                param2ID = ['parameter: ''',param2,''''];
                if any(strcmp(param2,{'a','b','g','l','a_actual','b_actual','g_actual','l_actual'})) && pfhb.model.Nsubj > 1
                    param2ID = [param2ID, ' subject: ',int2str(subject2)];
                end
                if any(strcmp(param2,{'a','b','g','l','amu','bmu','gmu','lmu','asigma','bsigma','gkappa','lkappa'})) && pfhb.model.Ncond > 1
                    if PAL_mmType(pfhb.model.(param2(1)).c) == 1
                        param2ID = [param2ID, ' condition: ',int2str(condition2)];
                    end
                    if PAL_mmType(pfhb.model.(param2(1)).c) == 2
                        param2ID = [param2ID, ' condition: all'];
                    end
                    if PAL_mmType(pfhb.model.(param2(1)).c) > 2
                        param2ID = [param2ID, ' effect: [',PAL_removeSpaces(num2str(pfhb.model.(param2(1)).c(condition2,:))),']'];
                    end  
                end
                figureHeader = [paramID, ' - ', param2ID];
            end

            text(.5,.97,figureHeader,'fontsize',16,'horizontalalignment','center','Interpreter','none')
            set(tagboard,'handlevisibility','off');

            axes('units','normalized','position',[.1 .52 .38 .38],'fontsize',12);
            box on;
            hold on;
            plot(samples')
            xlabel('Iteration');
            ylabel('Value');
            set(gca,'xlim',[0 pfhb.engine.nsamples]);
            ylim = get(gca,'ylim');

            text(pfhb.engine.nsamples*.75,ylim(2)-(ylim(2)-ylim(1))*.07,['Rhat = ',num2str(stat.Rhat,'%1.4f')],'fontsize',12);

            axes('units','normalized','position',[.55 .52 .38 .38],'fontsize',12);
            box on;
            hold on;
            [mass, x] = hist(samples(:),50);
            bar(x,mass/(sum(mass)*(x(2)-x(1))),1,'w');
            plot(grid,pdf,'linewidth',2);
            xlabel('Value');
            ylabel('density');
            xlim = [grid(1),grid(end)];
            set(gca,'xlim',xlim);
            ylim = get(gca,'ylim');
            line([stat.HDIlow, stat.HDIhigh],[max(pdf(I(2)),pdf(I(2)-minim)) max(pdf(I(2)),pdf(I(2)-minim))],'linewidth',2);
            text(mean([stat.HDIlow, stat.HDIhigh]),pdf(I(2))+(ylim(2)-ylim(1))/15,[num2str(stat.HDIlow,'%.3g'),' - ',num2str(stat.HDIhigh,'%.3g')],'horizontalalignment','center','fontsize',12,'backgroundcolor','w');
            text(xlim(1)+(xlim(2)-xlim(1))*.7,ylim(2)-(ylim(2)-ylim(1))/15,['mean: ', num2str(stat.mean,'%.3f')],'fontsize',12);
            text(xlim(1)+(xlim(2)-xlim(1))*.7,ylim(2)-2*(ylim(2)-ylim(1))/15,['mode: ', num2str(stat.mode,'%.3f')],'fontsize',12);
            text(xlim(1)+(xlim(2)-xlim(1))*.7,ylim(2)-3*(ylim(2)-ylim(1))/15,['median: ', num2str(stat.median,'%.3f')],'fontsize',12);


            axes('units','normalized','position',[.1 .07 .38 .38],'fontsize',12,'ylim',[-.2 1],'xlim',[0 maxlag]);
            box on;
            hold on;
            line([0 maxlag],[0 0],'linestyle',':','color',[.5 .5 .5],'linewidth',2);
            plot(0:maxlag,auto(:,:,1,2)','linewidth',2);        
            xlabel('lag');
            ylabel('autocorrelation');
            text(maxlag*.75,.9,['N: ',int2str(length(samples(:)))],'fontsize',12);
            text(maxlag*.75,.8,['ESS: ',num2str(stat.ess,'%.1f')],'fontsize',12);


            if oneortwo == 2
                axes('units','normalized','position',[.55 .07 .38 .38],'fontsize',12);
                box on;
                hold on;
                scatter(samples1(:),samples2(:),12,'filled');
                xlabel(paramID);
                ylabel(param2ID);
                xlim = get(gca,'xlim');
                ylim = get(gca,'ylim');
                text(xlim(2)-(xlim(2)-xlim(1))/10,ylim(2)-(ylim(2)-ylim(1))/20,['r = ', num2str(cc(1,2),'%.4g')],'fontsize',12,'horizontalalignment','right');
            end
            if rhat || correl || ess

                q = input('Hit <enter> to see next or type ''q'' (without quotes) followed by <enter> to quit\n','s');
                close(f); 
                if q == 'q'
                    close all;
                    break;
                end
            end
        end
    end
end
