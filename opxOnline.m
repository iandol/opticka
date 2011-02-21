classdef opxonline < handle
	properties
		s = 0
		nTrials = 0
		trial = struct()
	end
	
	methods
		% constructor
		function obj = opxonline(args)
			obj.run
		end
		
		%main run loop
		function run(obj)
			obj.s = PL_InitClient(0);
			if obj.s == 0
				return
			end
			
			obj.trial = struct;
			obj.nTrials=1;
			
			try
				while obj.nTrials <= 5
					PL_TrialDefine(obj.s, 5, 6, 0, 0, 0, 0, [1 2 3], [1], 0);
					fprintf('\nLooping at %i\n', obj.nTrials);
					[rn, trial, spike, analog, last] = PL_TrialStatus(obj.s, 3, 15000); %wait until end of trial
					fprintf('rn: %i tr: %i sp: %i al: %i lst: %i\n',rn, trial, spike, analog, last);
					if last > 0
						[obj.trial(obj.nTrials).ne, obj.trial(obj.nTrials).eventList]  = PL_TrialEvents(obj.s, 0, 0);
						[obj.trial(obj.nTrials).ns, obj.trial(obj.nTrials).spikeList]  = PL_TrialSpikes(obj.s, 0, 0);
						%[obj.trial(obj.nTrials).na, obj.trial(obj.nTrials).ts, obj.trial(obj.nTrials).analogList] = PL_TrialAnalogSamples(obj.s, 0, 0);
						obj.nTrials = obj.nTrials+1;
					end
				end
				% you need to call PL_Close(s) to close the connection
				% with the Plexon server
				obj.close;
				obj.s = 0;
				
			catch ME
				obj.nTrials = 0;
				obj.close;
				obj.s = 0;
				rethrow(ME)
			end
			
		end
		
		function close(obj)
			PL_Close(obj.s);
		end
	end
end

