%
%PAL_PFML_DevianceGoF   Determine Deviance value of fit.
%
%Syntax: Dev = PAL_DevianceGoF(StimLevels,NumPos,OutOfNum,params,PF)
%
%Internal function
%
%Introduced: Palamedes version 1.0.0 (NP)
% Modified: Palamedes version 1.3.0, 1.4.0 (see History.m)

function Dev = PAL_PFML_DevianceGoF(StimLevels,NumPos,OutOfNum,params,PF,varargin)

lapseFit = 'nAPLE';
gammaEQlambda = logical(false);

if ~isempty(varargin)
    NumOpts = length(varargin);
    for n = 1:2:NumOpts
        valid = 0;
        if strncmpi(varargin{n}, 'lapseFit',6)
            lapseFit = varargin{n+1};
            valid = 1;
        end                
        if strncmpi(varargin{n}, 'gammaEQlambda',6)
            gammaEQlambda = logical(varargin{n+1});
            valid = 1;
        end        
        if valid == 0
            message = [varargin{n} ' is not a valid option. Ignored.'];
            warning(message);
        end
    end            
end

for cond = 1:size(StimLevels,1)
    
    StimLevelsCond = StimLevels(cond,:);
    NumPosCond = NumPos(cond,:);
    OutOfNumCond = OutOfNum(cond,:);
    
    [StimLevelsCond NumPosCond OutOfNumCond] = PAL_PFML_GroupTrialsbyX(StimLevelsCond, NumPosCond, OutOfNumCond);
    negLLAugCond(cond) = PAL_PFML_negLLNonParametric(NumPosCond, OutOfNumCond);
    negLLConCond(cond) = PAL_PFML_negLL([], params(cond,:), [0 0 0 0], StimLevelsCond, NumPosCond, OutOfNumCond, PF,'lapseFit',lapseFit,'gammaEQlambda',gammaEQlambda);
    
end

negLLAug = sum(negLLAugCond);
negLLCon = sum(negLLConCond);

Dev = 2*(negLLCon-negLLAug);