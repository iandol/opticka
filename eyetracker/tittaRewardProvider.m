classdef tittaRewardProvider < handle
	properties
		rM = []
		aM = []
		dummyMode = false
		verbose   = false  % if true, prints state updates to command line
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
		function obj = tittaRewardProvider(dummyMode)
			if nargin>0 && ~isempty(dummyMode)
				obj.dummyMode = ~~dummyMode;
			end
			% we share rewardManager and audioManager as singletons
			[obj.rM, obj.aM] = optickaCore.initialiseGlobals(true, true);
		end

		% ===================================================================
		function delete(obj)
			% ensure we stop the reward before we destruct
			obj.stop();
		end

		% ===================================================================
		function giveReward(obj)
			if ~obj.dummyMode
				obj.rM.giveReward();
				if ~isempty(obj.aM);obj.aM.beep(3000,0.1,0.1);end
				if obj.verbose
					fprintf('tittaRewardProvider: reward\n');
				end
			end
		end

		% ===================================================================
		function start(obj)
			if ~obj.dummyMode
				obj.giveReward();
			end
		end

		% ===================================================================
		function tick(obj)
			if ~obj.dummyMode
				obj.startT = GetSecs();
			end
		end

		% ===================================================================
		function stop(obj)
			if ~obj.dummyMode
				
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