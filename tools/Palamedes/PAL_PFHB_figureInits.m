%
%PAL_PFHB_figureInits  Find reasonable initials for MCMC sampling based on
%   distribution of trials across stimulus intensities (unless initials
%   were provided by user).
%   
%   syntax: [engine] = PAL_PFHB_figureInits(engine,model,data)
%
%Internal Function
%
% Introduced: Palamedes version 1.10.0 (NP)

function [engine] = PAL_PFHB_figureInits(engine,model,data)

if ~isfield(engine.inits,'g') && model.g.Nc > 0
    engine.inits.g = .1.*ones(model.g.Nc,model.Nsubj)';    
end
if ~isfield(engine.inits,'gmu') && model.g.Nc > 0 && model.Nsubj > 1
    engine.inits.gmu = .1.*ones(model.g.Nc,1)';    
end
if ~isfield(engine.inits,'gkappa') && model.g.Nc > 0 && model.Nsubj > 1
    engine.inits.gkappa = 10.*ones(model.g.Nc,1)';    
end
if ~isfield(engine.inits,'l') && model.l.Nc > 0
    engine.inits.l = .03.*ones(model.l.Nc,model.Nsubj)';    
end
if ~isfield(engine.inits,'lmu') && model.l.Nc > 0 && model.Nsubj > 1
    engine.inits.lmu = .03.*ones(model.l.Nc,1)';    
end
if ~isfield(engine.inits,'lkappa') && model.l.Nc > 0 && model.Nsubj > 1
    engine.inits.lkappa = 10.*ones(model.l.Nc,1)';    
end

switch model.PF
    case 'logistic'
        slopeAdjust = 0;
    case 'cumulativenormal'
        slopeAdjust = -0.222;
    case {'gumbel','logquick'}
        slopeAdjust = -0.553;
    case 'hyperbolicsecant'
        slopeAdjust = -0.276;
    case {'weibull','quick'}        %will depend on alpha and is essentially a random guess. Suggestion: log-transform x and use Gumbel or logQuick
        slopeAdjust = 0;
end

if (model.a.Nc > 0 && ~isfield(engine.inits,'a')) || (model.b.Nc > 0 && ~isfield(engine.inits,'b'))
    m = zeros(model.Ncond,model.Nsubj);
    sd = zeros(model.Ncond,model.Nsubj);
    for s = 1:model.Nsubj
        for c = 1:model.Ncond
            x = data.x(data.s == s & data.c == c);
            n = data.n(data.s == s & data.c == c);
            x = x(2:end-1);
            n = n(2:end-1);
            m(c,s) = sum(x.*n)/sum(n);
            sd(c,s) = sqrt(sum(n.*(x-m(c,s)).^2)./sum(n));
        end
    end
end
    
if (model.a.Nc > 0 && ~isfield(engine.inits,'a'))
    engine.inits.a = (model.a.c*(m+sd.*randn(size(m))/5))';    
    if model.Nsubj > 1
        [engine.inits.amu, engine.inits.asigma] = PAL_MeanSDSSandSE(engine.inits.a);
    end
end
if (model.b.Nc > 0 && ~isfield(engine.inits,'b'))
    engine.inits.b = (model.b.c*(slopeAdjust+(1.5-sd)/2.5))';
    if model.Nsubj > 1
        [engine.inits.bmu, engine.inits.bsigma] = PAL_MeanSDSSandSE(engine.inits.b);
    end    
end