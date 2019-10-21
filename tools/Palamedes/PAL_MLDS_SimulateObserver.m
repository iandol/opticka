%
%PAL_MLDS_SimulateObserver  Generate simulated responses in MLDS setting
%
%syntax: NumGreater = PAL_MLDS_SimulateObserver(Stim, OutOfNum, ...
%   PsiValues, SDnoise, {optional arguments})
%
%Input:
%   'Stim': Stimulus set (see e.g., PAL_MLDS_GenerateStimList)
%
%   'OutOfNum': Number of trials to be simulated for each row in 'Stim'
%
%   'PsiValues': PsiValues characterizing simulated observer.
%
%   'SDnoise': internal noise of simulated observer.
%
%Output:
%   'NumGreater': For each row in 'Stim' the number of 'greater than'
%       responses.
%
%By default, PAL_MLDS_SimulateObserver considers the noise magnitude 
%   (quantified by the input argument SDnoise) to be the standard deviation
%   of the Gaussian distributed noise that is added to the difference 
%   scores (as Maloney and Yang do in: 
%   http://jov.arvojournals.org/article.aspx?articleid=2192635). 
%   However, it is also possible to consider the noise magnitude to be the
%   standard deviation of the Gaussian distributed noise that is added to 
%   each individual stimulus in the pair, triple, or quadruple (as Devinck 
%   and Knoblauch do in: 
%   http://jov.arvojournals.org/article.aspx?articleid=2121211).
%   In order to treat the noise magnitude as Devinck and Knoblauch do, use:
%
%   NumGreater = PAL_MLDS_SimulateObserver(Stim, OutOfNum, ...
%       PsiValues, SDnoise, 'parameterization','devinck');
%
%Example:
%
%   Stim = PAL_MLDS_GenerateStimList(2, 4, 1, 2);
%   OutOfNum = ones(1,size(Stim,1));
%   PsiValues = [0 1/3 2/3 1];
%   SDnoise = .5;
%   NumGreater = PAL_MLDS_SimulateObserver(Stim, OutOfNum, PsiValues, ...
%       SDnoise)
%
%   might generate:
%
%   NumGreater =
%
%     0     1     0     1     0     0
%
%   Tip: use PAL_MLDS_GroupTrialsbyX to combine like trials.
%
%Introduced: Palamedes version 1.0.0 (NP)
%Modified: Palamedes version 1.6.3, 1.9.0 (see History.m)

function NumGreater = PAL_MLDS_SimulateObserver(Stim, OutOfNum, PsiValues, SDnoise, varargin)

if ~isempty(varargin)
    NumOpts = length(varargin);
    for n = 1:2:NumOpts
        valid = 0;
        if strncmpi(varargin{n}, 'param',3)
            if strncmpi(varargin{n+1}, 'dev',3)
                if ~isempty(SDnoise) & SDnoise ~= 1
                    message =  'Using Devinck & Knoblauch parameterization of MLDS, noise SD is defined to equal 1. User supplied value will be ignored. ';
                    message = [message 'In order to avoid seeing this message again, use either the value 1 or an empty matrix in function call.'];
                    warning('PALAMEDES:DevinckKnoblauchSDignored',message);
                end
                if size(Stim,2) == 2
                    SDnoise = sqrt(2);  %Noise amplitude on difference score.
                else
                    SDnoise = 2;        %ditto
                end
            end
            valid = 1;
        end        
        if valid == 0
            warning('PALAMEDES:invalidOption','%s is not a valid option. Ignored.',varargin{n});
        end        
    end            
end

if size(Stim,2) == 4
    D = (PsiValues(Stim(:,2))-PsiValues(Stim(:,1)))-(PsiValues(Stim(:,4))-PsiValues(Stim(:,3)));
end
if size(Stim,2) == 3
    D = (PsiValues(Stim(:,2))-PsiValues(Stim(:,1)))-(PsiValues(Stim(:,3))-PsiValues(Stim(:,2)));
end
if size(Stim,2) == 2
    D = (PsiValues(Stim(:,1))-PsiValues(Stim(:,2)));
end

NumGreater = zeros(1,length(D));

for Level = 1:length(D)
    Z_D = D(Level)./SDnoise;
    pFirst = .5 + .5*(1-erfc(Z_D./sqrt(2)));
    Pos = rand(OutOfNum(Level),1);
    Pos(Pos < pFirst) = 1;
    Pos(Pos ~= 1) = 0;
    NumGreater(Level) = sum(Pos);
end