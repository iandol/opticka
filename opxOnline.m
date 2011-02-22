classdef opxOnline < handle
	properties
		s = 0
		nTrials = 0
		trial = struct()
		eventStart = 257
		eventEnd = -2
		maxWait = 30000
		myFigure = -1
		myAxis = -1
		autoRun = 0
	end
	
	methods
		% constructor
		function obj = opxOnline(varargin)
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
			
			if ~ishandle(obj.myFigure);
				obj.myFigure = figure;
			end
			if ~ishandle(obj.myAxis);
				obj.myAxis = axes;
			end
			obj.draw;
			
			try
				while obj.nTrials <= 5
					PL_TrialDefine(obj.s, obj.eventStart, obj.eventEnd, 0, 0, 0, 0, [1 2 3], [1], 0);
					fprintf('\nLooping at %i\n', obj.nTrials);
					[rn, trial, spike, analog, last] = PL_TrialStatus(obj.s, 3, obj.maxWait); %wait until end of trial
					fprintf('rn: %i tr: %i sp: %i al: %i lst: %i\n',rn, trial, spike, analog, last);
					if last > 0
						[obj.trial(obj.nTrials).ne, obj.trial(obj.nTrials).eventList]  = PL_TrialEvents(obj.s, 0, 0);
						[obj.trial(obj.nTrials).ns, obj.trial(obj.nTrials).spikeList]  = PL_TrialSpikes(obj.s, 0, 0);
						obj.nTrials = obj.nTrials+1;
					end
					[~,~,keyCode]=KbCheck;
					keyCode=KbName(keyCode);
					if ~isempty(keyCode)
						key=keyCode;
						if iscell(key);key=key{1};end
						if regexpi(key,'^esc')
							break
						end
					end
					obj.draw;
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
		
		function draw(obj)
			axes(obj.myAxis);
			plot([1:10],[1:10]*obj.nTrials)
			title(['On Trial: ' num2str(obj.nTrials)]);
			drawnow;
		end
		
		function close(obj)
			PL_Close(obj.s);
		end
	end
end

