%
%PAL_AMUD_analyzeUD  Determines threshold estimates based on up/down
%   adaptive method
%   
%   syntax: Mean = PAL_AMUD_analyzeUD(UD, {optional arguments})
%
%   After having completed an up/down staircase PAL_AMUD_analyzeUD may be
%       used to determine threshold estimate based on the mean of the
%       last specified number of trials or number of reversals that
%       occurred in the run.
%
%   By default,
%
%   Mean = PAL_AMUD_analyzeUD(UD) will calculate the mean of all but the
%       first two reversals.
%
%   User may change defaults by providing optional arguments in pairs. The 
%   first argument sets the criterion by which to terminate, it's options 
%   are 'reversals' and 'trials'. It should be followed by a scalar 
%   indicating the number of reversals or trials after which run should be
%   terminated. For example,
%
%   Mean = PAL_AMUD_analyzeUD(UD, 'reversals',10) will calculate the mean 
%       of the last 10 reversals.
%
%   and,
%
%   Mean = PAL_AMUD_analyzeUD(UD, 'trials',25) will calculate the mean 
%       of the last 25 trials.
%
%Introduced: Palamedes version 1.0.0 (NP)

function Mean = PAL_AMUD_analyzeUD(UD, varargin)

HighReversal = max(UD.reversal);
NumTrials = length(UD.response);

if ~isempty(varargin)
    NumOpts = length(varargin);
    for n = 1:2:NumOpts
        valid = 0;
        if strncmpi(varargin{n}, 'reversals',4)            
            criterion = 'reversals';
            number = varargin{n+1};
            LowReversal = HighReversal - number + 1;
            if LowReversal < 1
                message = ['You asked for the last ' int2str(number) ' reversals. There are only ' int2str(HighReversal) ' reversals.'];
                warning(message);
                LowReversal = 1;
            end
            valid = 1;
        end
        if strncmpi(varargin{n}, 'trials',4)            
            criterion = 'trials';
            number = varargin{n+1};
            LowTrial = NumTrials - number + 1;
            if LowTrial < 1
                message = ['You asked for the last ' int2str(number) ' trials. There are only ' int2str(NumTrials) ' trials.'];
                warning(message);
                LowTrial = 1;
            end
            valid = 1;
        end
        if valid == 0
            message = [varargin{n} ' is not a valid option. Ignored.'];
            warning(message);
        end        
    end            
else
    criterion = 'reversals';
    LowReversal = 3;
end

if strncmpi(criterion,'reversals',4)
    Mean = sum(UD.xStaircase(UD.reversal >= LowReversal))/(HighReversal-LowReversal+1);
else
    Mean = sum(UD.xStaircase(LowTrial:NumTrials))/(NumTrials-LowTrial+1);
end