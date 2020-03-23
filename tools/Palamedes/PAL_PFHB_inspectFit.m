%
%PAL_PFHB_inspectFit    Graph data and fit for single subject/condition 
%   combination.
%
%   syntax: PAL_PFHB_inspectFit(pfhb,{optional arguments})
%
%Input:
%   
%   pfhb: Structure created by PAL_PFHB_fitModel
%
%Optional arguments (none are case-sensitive, defaults are indicated by 
%   {}):
%
%   subject: followed by subject ID ({1}, 2, 3, etc.)
%
%   condition: followed by condition ID ({1}, 2, 3, etc.)
%
%   hiDensityCurves: followed by n (some integer [0, Inf) {100}) adds n 
%       PFs to graph that are randomly sampled from posterior.
%
%   centralTendency: followed by additional argument 'mean', {'mode'},
%       'median', uses indicated measure of central tendency.
%
%   all: cycle through all subject x condition combinations. User is
%       prompted for <enter> to move to next or to hit q key followed by
%       enter to quit.
%   
%Introduced: Palamedes version 1.10.0 (NP)
%Modified: Palamedes version 1.10.3 (See History.m)

function [] = PAL_PFHB_inspectFit(pfhb, varargin)

switch pfhb.model.PF
    case 'logistic'
        PF = @PAL_Logistic;
    case 'cumulativenormal'
        PF = @PAL_CumulativeNormal;
    case 'weibull'
        PF = @PAL_Weibull;
    case 'gumbel'
        PF = @PAL_Gumbel;
    case 'quick'
        PF = @PAL_Quick;
    case 'logquick'
        PF = @PAL_logQuick;
    case 'hyperbolicsecant'
        PF = @PAL_HyperbolicSecant;
end

number = 1;
s = 1;
c = 1;
hiDensityCurves = 100;
centralTendency = 'mode';
paramNames = {'a','b','g','l'};

if ~isempty(varargin)
    NumOpts = length(varargin);
    n = 1;
    while n <= NumOpts
        valid = 0;
       if strncmpi(varargin{n}, 'subject',4)
            s = varargin{n+1};            
            valid = 1;
            add = 2;
        end                        
        if strncmpi(varargin{n}, 'condition',4)
            c = varargin{n+1};            
            valid = 1;
            add = 2;
        end
        if strncmpi(varargin{n}, 'hiDensityCurves',4)
            hiDensityCurves = varargin{n+1};            
            valid = 1;
            add = 2;
        end
        if strncmpi(varargin{n}, 'all',3)
            number = pfhb.model.Ncond*pfhb.model.Nsubj;            
            valid = 1;
            add = 1;
        end        
        if strncmpi(varargin{n}, 'centralTendency',4)
            if ~strcmpi(varargin{n+1},'mean') && ~strcmpi(varargin{n+1},'median') && ~strcmpi(varargin{n+1},'mode')
                warning('PALAMEDES:invalidOption','%s is not a valid value for CentralTendency. Ignored.',varargin{n+1});
            else
                centralTendency = varargin{n+1};
            end
            valid = 1;
            add = 2;
        end
        
        if valid == 0
            warning('PALAMEDES:invalidOption','%s is not a valid option. Ignored.',varargin{n});
            n = n + 1;
        else        
            n = n + add;
        end
    end            
end


for loop = 1:number
    
    if number > 1
        s = floor((loop-1)/pfhb.model.Ncond)+1;
        c = mod((loop-1),pfhb.model.Ncond)+1;
    end

    f = figure('units','normalized','position',[.1 .1 .4 .4]);
    axes
    hold on
    box on
    xlabel('Stimulus Intensity');
    ylabel('proportion positive');

    x = pfhb.data.x(pfhb.data.s == s & pfhb.data.c == c);
    y = pfhb.data.y(pfhb.data.s == s & pfhb.data.c == c);
    n = pfhb.data.n(pfhb.data.s == s & pfhb.data.c == c);

    infiniteLim = [x(1) == -Inf x(end) == Inf];
    minx = min(x(~isinf(x)));
    maxx = max(x(~isinf(x)));
    xlimcurve = [minx-(maxx-minx)/5,maxx+(maxx-minx)/5];
    if any(strcmpi(pfhb.model.PF,{'weibull','quick'})) && xlimcurve(1) < 0
        xlimcurve(1) = 0;
    end
    xcurve = linspace(xlimcurve(1),xlimcurve(end),1001);
    
    sampI = [randi(pfhb.engine.nchains,[1 hiDensityCurves]); randi(pfhb.engine.nsamples,[1 hiDensityCurves])];

    for hdc = 1:hiDensityCurves

        for paramI = 1:4
            param = paramNames{paramI};
            if ~isempty(pfhb.model.(param).cTtoP)
                samp = pfhb.samples.(param)(sampI(1,hdc),sampI(2,hdc),:,s);     
                params(paramI) = squeeze(samp)'*pfhb.model.(param).cTtoP(:,c);            
            else
                params(paramI) = pfhb.model.(param).val;
            end
        end
        params(2) = 10.^params(2);
        if pfhb.model.gammaEQlambda
            params(3) = params(4);
        end

        transp = plot(xcurve, PF(params,xcurve),'-','linewidth',2,'color',[.5 .5 .5]);
        if strcmp(pfhb.machine.environment,'matlab')
            transp.Color(4) = 1/(log(hiDensityCurves)+1);
        end

    end

    for paramI = 1:4
        param = paramNames{paramI};
        if ~isempty(pfhb.model.(param).cTtoP)
            params(paramI) = pfhb.summStats.(param).(centralTendency)(:,s)'*pfhb.model.(param).cTtoP(:,c);
        else
            params(paramI) = pfhb.model.(param).val;
        end
    end
    params(2) = 10.^params(2);
    if pfhb.model.gammaEQlambda
        params(3) = params(4);
    end

    plot(xcurve, PF(params,xcurve),'k-','linewidth',2);

    for ix = 1:length(x)
        if ~isinf(x(ix))
            plot(x(ix),y(ix)./n(ix),'o','markersize',30*sqrt(n(ix)./max(n)),'color',[0.8 0 0.2],'markerfacecolor',[0.8 0 0.2]);
        end
    end

    if any(infiniteLim)
        xlim = get(gca,'xlim');
        xt = get(gca,'xtick');
        xticklabel = get(gca,'xticklabel');
        xtick = xt(xt > xlimcurve(1) & xt < xlimcurve(2));
        xticklabel = xticklabel(xt > xlimcurve(1) & xt < xlimcurve(2));
        if infiniteLim(1)
            xlim(1) = xlimcurve(1) - (xlimcurve(2)-xlimcurve(1))/4;
            x(1) = .8*xlim(1) + .2*xlimcurve(1);
            xtick = [x(1) xtick];
            xticklabel = [{-Inf'}; xticklabel];
            for hdc = 1:hiDensityCurves

                if ~isempty(pfhb.model.g.cTtoP)
                    samp = pfhb.samples.g(sampI(1,hdc),sampI(2,hdc),:,s);     
                    value = squeeze(samp)'*pfhb.model.g.cTtoP(:,c);            
                else
                    value = pfhb.model.g.val;
                end
                transp = line([x(1) .5*xlim(1) + .5*xlimcurve(1)],[value value], 'linewidth',2,'color',[.5 .5 .5]);
                if strcmp(pfhb.machine.environment,'matlab')
                    transp.Color(4) = 1/(log(hiDensityCurves)+1);
                end
            end
            line([x(1) .5*xlim(1) + .5*xlimcurve(1)],[params(3) params(3)], 'linewidth',2,'color',[0 0 0]);
            plot(x(1),y(1)./n(1),'o','markersize',30*sqrt(n(1)./max(n)),'color',[0.8 0 0.2],'markerfacecolor',[0.8 0 0.2])
        end
        if infiniteLim(2)
            xlim(2) = xlimcurve(2) + (xlimcurve(2)-xlimcurve(1))/4;
            x(end) = .8*xlim(2) + .2*xlimcurve(2);
            xtick = [xtick x(end)];
            xticklabel = [xticklabel; {Inf'}];
            for hdc = 1:hiDensityCurves

                if ~isempty(pfhb.model.l.cTtoP)
                    samp = pfhb.samples.l(sampI(1,hdc),sampI(2,hdc),:,s);     
                    value = squeeze(samp)'*pfhb.model.l.cTtoP(:,c);            
                else
                    value = pfhb.model.l.val;
                end
                transp = line([x(end) .5*xlim(2) + .5*xlimcurve(2)],[1-value 1-value], 'linewidth',2,'color',[.5 .5 .5]);
                if strcmp(pfhb.machine.environment,'matlab')
                    transp.Color(4) = 1/(log(hiDensityCurves)+1);
                end
            end        
            line([x(end) .5*xlim(2) + .5*xlimcurve(2)],[1-params(4) 1-params(4)], 'linewidth',2,'color',[0 0 0]);
            plot(x(end),y(end)./n(end),'o','markersize',30*sqrt(n(end)./max(n)),'color',[0.8 0 0.2],'markerfacecolor',[0.8 0 0.2])
        end

    else
        xlim = xlimcurve;
        xtick = get(gca,'xtick');
        xticklabel = get(gca,'xticklabel');
    end

    set(gca, 'xlim', xlim,'ylim',[0 1]);
    set(gca,'xtick',xtick,'xticklabel',xticklabel)


    text(xlim(1) + (xlim(2)-xlim(1))./10, 1.05,['Subject: ',int2str(s),'   Condition: ', int2str(c)]);
    text(xlim(1) + (xlim(2)-xlim(1))*.65, .3,['Parameter values (',centralTendency,'):']);
    text(xlim(1) + (xlim(2)-xlim(1))*.65, .25,['\alpha: ',num2str(params(1))]);
    text(xlim(1) + (xlim(2)-xlim(1))*.65, .2,['\beta: ',num2str(params(2))]);
    text(xlim(1) + (xlim(2)-xlim(1))*.65, .15,['\gamma: ',num2str(params(3))]);
    text(xlim(1) + (xlim(2)-xlim(1))*.65, .1,['\lambda: ',num2str(params(4))]);
    
    if number > 1
        q = input('Hit <enter> to see next or type ''q'' (without quotes) followed by <enter> to quit\n','s');
        close(f); 
        if q == 'q'
            close all;
            break;
        end
    end


end
