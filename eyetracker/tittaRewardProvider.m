classdef tittaRewardProvider < handle
    properties
        rM = []
        aM = []
        dummyMode = false
        verbose   = true  % if true, prints state updates to command line
    end
    properties (Hidden = true)
        dutyCycle = inf    % ms. If set to something other than inf, reward will be on for dutyCycle ms, then off for dutyCycle ms, etc for as long rewards are on. This requires frequently calling tick( 
    end
    properties ( SetAccess = private)
        on = false
        dispensing = false
    end
    properties (Access = private, Hidden = true)
        startT
    end

    methods
        % ===================================================================
        function obj = tittaRewardProvider(dummyMode, rM, aM)
            if nargin>0 && ~isempty(dummyMode)
                obj.dummyMode = ~~dummyMode;
            end
            if nargin>1 && ~isempty(rM)
                obj.rM = rM;
            end
            if nargin>2 && ~isempty(aM)
                obj.aM = aM;
            end
        end

        % ===================================================================
        function delete(obj)
            % ensure we stop the reward before we destruct
            obj.stop();
        end

        % ===================================================================
        function start(obj)
            if ~obj.dummyMode
                obj.startT = GetSecs();
                obj.rM.giveReward();
                if obj.verbose
                    fprintf('tittaRewardProvider: reward\n');
                end
            end
        end

        % ===================================================================
        function tick(obj)
            if ~obj.dummyMode
                
            end
        end

        % ===================================================================
        function stop(obj)
            if ~obj.dummyMode
                if obj.verbose
                    fprintf('tittaRewardProvider: stop\n');
                end
            end
        end
    end

    methods (Access = private, Hidden)
        % ===================================================================
        function dispense(obj,start)
            if start
                obj.dispensing = true;
            else
                obj.dispensing = false;
            end
        end
    end
end