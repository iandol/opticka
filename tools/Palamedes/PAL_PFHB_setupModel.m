%
%PAL_PFHB_setupModel  Set up and initialize 'pfhb' structure based on 
%   contents of data structure and optional arguments.
%   
%   syntax: [pfhb] = PAL_PFHB_setupModel(data, varargin)
%
% Internal Function
%
% Introduced: Palamedes version 1.10.0 (NP)
% Modified: Palamedes version 1.10.2, 1.10.4 (See History.m)

function [pfhb] = PAL_PFHB_setupModel(data, varargin)

data = PAL_PFHB_dataSortandGroup(data);

data.Ncond = max(data.c);
data.Nsubj = max(data.s);

engine.engine = 'jags';
engine.version = [];
engine.path = [];
engine.recyclestan = false;
engine.found = false;
engine.nchains = 3;
engine.nsamples = 5000;
engine.nadapt = 2000;
engine.nburnin = 2000;
engine.keep = false;
engine.inits = [];
engine.seed = randi(2^16,1);
engine.parallel = false;
%Awkward but compatible with both Octave and Matlab:
machines = {'GLNXA64','MACI64','PCWIN64'};
machine.machine = char(machines(find([isunix ismac ispc],1,'last')));
machine.environment = PAL_environment;
machine.environment_version = version;
machine.palamedes_version = PAL_version('version_text');

model.PF = 'logistic';
model.Ncond = data.Ncond;
model.Nsubj = data.Nsubj;
model.gammaEQlambda = logical(false);
model.a.c = eye(data.Ncond);
model.a.Nc = size(model.a.c,1);
model.a.val = [];
model.a.priorFun = 'norm';
model.a.boundaries = [-Inf,Inf];
model.b.c = eye(data.Ncond);
model.b.Nc = size(model.b.c,1);
model.b.val = 0;
model.b.priorFun = 'norm';
model.b.boundaries = [-Inf,Inf];
model.g.c = [];
model.g.Nc = size(model.g.c,1);
model.g.val = 0.5;
model.g.priorFun = 'beta';                                      %Parameter values are NOT 'a' and 'b', but rather 'mu' (mean, a/(a+b)) and 'kappa' or 'concentration' (a + b)
model.g.boundaries = [0,1];
model.l.c = ones(1,data.Ncond)/data.Ncond;
model.l.Nc = size(model.l.c,1);
model.l.val = .02;
model.l.priorFun = 'beta';                                      %Parameter values are NOT 'a' and 'b', but rather 'mu' (mean, a/(a+b)) and 'kappa' or 'concentration' (a + b)
model.l.boundaries = [0,1];
if model.Nsubj > 1
    model.amu.Nc = model.a.Nc;
    model.amu.priorFun = 'norm';
    model.amu.boundaries = [-Inf,Inf];
    model.asigma.Nc = model.a.Nc;
    model.asigma.priorFun = 'unif';
    model.asigma.boundaries = [0,Inf];
    model.bmu.Nc = model.b.Nc;
    model.bmu.priorFun = 'norm';
    model.bmu.boundaries = [-Inf,Inf];
    model.bsigma.Nc = model.b.Nc;
    model.bsigma.priorFun = 'unif';
    model.bsigma.boundaries = [0,Inf];
    model.gmu.Nc = model.g.Nc;
    model.gmu.priorFun = 'beta';
    model.gmu.boundaries = [0,1];
    model.gkappa.Nc = model.g.Nc;
    model.gkappa.priorFun = 'gamma';                                 %gamma has 'shape' r (aka alpha or k) and 'rate' lambda (aka beta). Mean = r/lambda, Var = r/lambda^2
    model.gkappa.boundaries = [0,Inf];
    model.lmu.Nc = model.l.Nc;
    model.lmu.priorFun = 'beta';
    model.lmu.boundaries = [0,1];
    model.lkappa.Nc = model.l.Nc;
    model.lkappa.priorFun = 'gamma';
    model.lkappa.boundaries = [0,Inf];
end
model.deviance.boundaries = [0,Inf];


if ~isempty(varargin)
    NumOpts = length(varargin);
    n = 1;
    while n <= NumOpts
        valid = 0;
        if strcmpi(varargin{n}, 'engine')
            if any(strcmpi({'stan','jags'},varargin{n+1}))
                engine.engine = lower(varargin{n+1});
                valid = 1;
            else
                message = [varargin{n+1}, ' is not a valid argument to follow ''engine'', using ',engine.engine,'.'];
                warning('PALAMEDES:invalidOption',message);
                valid = 1;
            end
            add = 2;
        end  
        if strcmpi(varargin{n}, 'seed')
            engine.seed = varargin{n+1};
            valid = 1;
            add = 2;
        end 
        if strncmpi(varargin{n}, 'parallel',4)
            engine.parallel = varargin{n+1};
            valid = 1;
            add = 2;
        end          
        if any(strcmpi({'enginepath','jagspath','stanpath'},varargin{n}))
            engine.path = varargin{n+1};
            if exist(engine.path,'file')
                engine.found = true;
                valid = 1;
            else
                message = [engine.path,' is not a valid path. Will try to find engine myself.'];
                warning('PALAMEDES:invalidOption',message);
                engine.found = false;
            end
            add = 2;
        end  
        if any(strncmpi({'locat','thres','slope','guess','lapse'},varargin{n},5)) || any(strcmpi({'a','b','g','l'},varargin{n}))
            if length(varargin{n}) == 1
                param = varargin{n};
            else
                switch lower(varargin{n}(1:3))
                    case {'loc','thr'}
                        param = 'a';
                    case 'slo'
                        param = 'b';
                    case 'gue'
                        param = 'g';
                    case 'lap'
                        param = 'l';
                end
            end
            if strncmpi(varargin{n+1},'unconst',5)                
                model.(param).c = eye(data.Ncond);
                model.(param).Nc = size(model.(param).c,1);
                add = 2;
            end
            if strncmpi(varargin{n+1},'const',5)
                model.(param).c = ones(1,data.Ncond)/data.Ncond;
                model.(param).Nc = size(model.(param).c,1);
                add = 2;
            end
            if isnumeric(varargin{n+1})
                model.(param).c = varargin{n+1};
                model.(param).Nc = size(model.(param).c,1);
                add = 2;
            end
            if strncmpi(varargin{n+1},'fixed',5)
                model.(param).c = [];
                model.(param).Nc = 0;
                model.(param).val = varargin{n+2};
                add = 3;
            end
            
            valid = 1;
        end
        if strncmpi(varargin{n}, 'prior',5)
            if any(strcmpi({'a','b','g','l','amu','asigma','bmu','bsigma','gmu','gkappa','lmu','lkappa'},varargin{n+1}))
                switch varargin{n+1}
                    case {'a','b','amu','bmu'}
                        if any(strncmpi(varargin{n+2},{'norm','tdis'},4))
                           if PAL_whatIs(varargin{n+3}) == 1 && (size(varargin{n+3},1) == 1 || size(varargin{n+3},1) == model.(varargin{n+1}(1)).Nc) 
                               if size(varargin{n+3},1) == 1 && any(strcmpi(varargin{n+1},{'a','b'}))
                                   paramVals = repmat(varargin{n+3},[model.(varargin{n+1}).Nc, 1]);
                               else
                                   paramVals = varargin{n+3};
                               end
                               if strcmpi(varargin{n+2},'tdis')
                                    model.(varargin{n+1}).priorParams(1:size(paramVals,1),3) = 2;
                               end                               
                               model.(varargin{n+1}).priorFun = varargin{n+2};                               
                               model.(varargin{n+1}).priorParams(:,1:size(paramVals,2)) = paramVals;
                                
                               valid = 1;
                               add = 4;                               
                            end
                        end
                    case {'g','l','gmu','lmu'}
                        if any(strncmpi(varargin{n+2},{'beta','unif'},4))
                           if PAL_whatIs(varargin{n+3}) == 1 && (size(varargin{n+3},1) == 1 || size(varargin{n+3},1) == model.(varargin{n+1}(1)).Nc) 
                               if size(varargin{n+3},1) == 1
                                   paramVals = repmat(varargin{n+3},[model.(varargin{n+1}).Nc, 1]);
                               else
                                   paramVals = varargin{n+3};
                               end
                               model.(varargin{n+1}).priorFun = varargin{n+2};
                               model.(varargin{n+1}).priorParams = paramVals;
                                
                                valid = 1;
                                add = 4;
                           end
                        end
                    case {'gkappa','lkappa'}
                        if any(strncmpi(varargin{n+2},{'gamma','unif'},4))
                           if PAL_whatIs(varargin{n+3}) == 1 && (size(varargin{n+3},1) == 1 || size(varargin{n+3},1) == model.(varargin{n+1}(1)).Nc) 
                               if size(varargin{n+3},1) == 1
                                   paramVals = repmat(varargin{n+3},[model.(varargin{n+1}).Nc, 1]);
                               else
                                   paramVals = varargin{n+3};
                               end
                               model.(varargin{n+1}).priorFun = varargin{n+2};
                               model.(varargin{n+1}).priorParams = paramVals;
                                
                                valid = 1;
                                add = 4;
                           end
                        end
                    case {'asigma','bsigma'}
                        if any(strncmpi(varargin{n+2},{'gamma','unif'},4))
                           if PAL_whatIs(varargin{n+3}) == 1 && (size(varargin{n+3},1) == 1 || size(varargin{n+3},1) == model.(varargin{n+1}(1)).Nc) 
                               if size(varargin{n+3},1) == 1
                                   paramVals = repmat(varargin{n+3},[model.(varargin{n+1}).Nc, 1]);
                               else
                                   paramVals = varargin{n+3};
                               end
                               model.(varargin{n+1}).priorFun = varargin{n+2};
                               model.(varargin{n+1}).priorParams = paramVals;
                                
                                valid = 1;
                                add = 4;
                           end
                        end                        
                end
            else
                message = [varargin{n+1}, ' is not a valid argument to follow ''prior''.'];
                warning('PALAMEDES:invalidOption',message);
            end
        end
        if strncmpi(varargin{n}, 'gammaEQlambda',6)
            model.gammaEQlambda = logical(varargin{n+1});            
            valid = 1;
            add = 2;
        end  
        if strncmpi(varargin{n}, 'PF',2)
            if any(strcmpi(varargin{n+1},{'logistic','cumulativenormal','weibull','gumbel','quick','logquick','hyperbolicsecant'}))
                model.PF = lower(varargin{n+1});
                if any(strcmpi(model.PF,{'weibull','quick'}))
                    disp([char(10),'You selected ',model.PF,' as PF. We recommend log-transforming your stimulus intensity and using the Gumbel (log-Weibull) or log-Quick function instead. See www.palamedestoolbox.org/weibullandfriends.html.',char(10)]);                    
                end
                valid = 1;
            else
                message = [varargin{n+1}, ' is not a valid option for ''PF''. Using Logistic function instead.'];
                warning('PALAMEDES:invalidOption',message);
            end
            add = 2;
        end
        if strncmpi(varargin{n}, 'nchains',4)                  
            engine.nchains = varargin{n+1};
            valid = 1;
            add = 2;
        end             
        if strncmpi(varargin{n}, 'nsamples',2)                  
            engine.nsamples = varargin{n+1};
            valid = 1;
            add = 2;
        end                                
        if strncmpi(varargin{n}, 'nburnin',2)                  
            engine.nburnin = varargin{n+1};
            valid = 1;
            add = 2;
        end
        if strncmpi(varargin{n}, 'nadapt',2)                  
            engine.nadapt = varargin{n+1};
            valid = 1;
            add = 2;
        end         
        if strncmpi(varargin{n}, 'keep',4)
            engine.keep = varargin{n+1};
            valid = 1;
            add = 2;
        end 
        if strncmpi(varargin{n}, 'recy',4)
            engine.recyclestan = varargin{n+1};
            valid = 1;
            add = 2;
        end                                                
        if strncmpi(varargin{n}, 'init',4)
            if any(strcmpi({'a','b','g','l'},varargin{n+1})) && size(varargin{n+2},1) == 1
                engine.inits.(varargin{n+1}) = repmat(varargin{n+2},[model.Nsubj 1]);
            else
                engine.inits.(varargin{n+1}) = varargin{n+2};
            end
            valid = 1;
            add = 3;
        end   
        if valid == 0
            if PAL_whatIs(varargin{n}) == 1
                argument = mat2str(varargin{n});
            else
                argument = varargin{n};
            end
            warning('PALAMEDES:invalidOption','%s is not a valid option here or is used incorrectly. Ignored.',argument);
            n = n + 1;
        else        
            n = n + add;
        end
    end            
end

%initialize prior params here
if model.Nsubj == 1
    list = {'a','b','g','l'};
else
    list = {'amu','asigma','bmu','bsigma','gmu','gkappa','lmu','lkappa'};
end
for param = list
    if isfield(model,char(param))
        if isfield(model.(char(param)),'priorParams') %i.e., user supplied values
            if size(model.(char(param)).priorParams,1) == 1
                model.(char(param)).priorParams = repmat(model.(char(param)).priorParams,[model.(char(param)).Nc 1]);
            end
        else
            switch lower(model.(char(param)).priorFun(1:4))
                case 'norm'
                    model.(char(param)).priorParams(1:model.(char(param{1}(1))).Nc,1) = 0;
                    model.(char(param)).priorParams(1:model.(char(param{1}(1))).Nc,2) = 100;    
                case 'beta'
                    model.(char(param)).priorParams(1:model.(char(param{1}(1))).Nc,1) = 1/11;
                    model.(char(param)).priorParams(1:model.(char(param{1}(1))).Nc,2) = 11;
                case 'gamm'
                    model.(char(param)).priorParams(1:model.(char(param{1}(1))).Nc,1) = 1;
                    model.(char(param)).priorParams(1:model.(char(param{1}(1))).Nc,2) = .002;                
                case 'unif'
                    model.(char(param)).priorParams(1:model.(char(param{1}(1))).Nc,1) = 0;
                    model.(char(param)).priorParams(1:model.(char(param{1}(1))).Nc,2) = 1000;                
            end
        end
    end
end

if strcmpi(engine.engine,'stan') && ((strcmpi(machine.machine,'PCWIN64') && exist('stanModel.exe','file') && engine.recyclestan) || (any(strcmpi(machine.machine,{'MACI64','GLNXA64'})) && exist('stanModel','file')  && engine.recyclestan))
    engine.found = true;
end
if ~engine.found
    engine = PAL_PFHB_findEngine(engine,machine);
end

if ~engine.found
    pfhb.engine.found = false;
    return;
end

if engine.keep
    engine.dirout = strcat(cd,filesep,engine.engine,'_',datestr(now,'yyyymmddTHHMMSS'));
else
    engine.dirout = strcat(tempdir,engine.engine,'_',datestr(now,'yyyymmddTHHMMSS'),'_',char(randi([97 122],1,20)));
end

mkdir(engine.dirout);

model.a.cTtoP = pinv(model.a.c)';
model.b.cTtoP = pinv(model.b.c)';
model.g.cTtoP = pinv(model.g.c)';
model.l.cTtoP = pinv(model.l.c)';

model.parameters = PAL_PFHB_writeModel(model,engine);

data.ac = zeros(model.a.Nc,length(data.x));
for contrast = 1:model.a.Nc
    for cond = 1:data.Ncond
        data.ac(contrast,data.c == cond) = model.a.cTtoP(contrast,cond);
    end
end

data.bc = zeros(model.b.Nc,length(data.x));
for contrast = 1:model.b.Nc
    for cond = 1:data.Ncond
        data.bc(contrast,data.c == cond) = model.b.cTtoP(contrast,cond);
    end
end

data.gc = zeros(model.g.Nc,length(data.x));
for contrast = 1:model.g.Nc
    for cond = 1:data.Ncond
        data.gc(contrast,data.c == cond) = model.g.cTtoP(contrast,cond);
    end
end

data.lc = zeros(model.l.Nc,length(data.x));
for contrast = 1:model.l.Nc
    for cond = 1:data.Ncond
        data.lc(contrast,data.c == cond) = model.l.cTtoP(contrast,cond);
    end
end

if strcmp(machine.environment,'matlab')
    s = rng;
    rng(engine.seed);
else
    s = rand("state");
    rand("state",engine.seed);
end
[engine] = PAL_PFHB_figureInits(engine,model,data);
if strcmp(machine.environment,'matlab')
    rng(s);
else
    rand("state",s);
end

data.Nblocks = length(data.x);
data.Nca = model.a.Nc;
data.Ncb = model.b.Nc;
data.Ncg = model.g.Nc;
data.Ncl = model.l.Nc;

pfhb.data = data;
pfhb.model = model;
pfhb.engine = engine;
pfhb.machine = machine;