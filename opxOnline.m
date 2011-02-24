% ========================================================================
%> @brief LABJACK Connects and manages a LabJack U3-HV
%>
%> Connects and manages a LabJack U3-HV
%>
% ========================================================================
classdef opxOnline < handle
	properties
		eventStart = 101
		eventEnd = 102
		maxWait = 30000
		autoRun = 1
		autoServer = 0
		lPort = 8888
		rPort = 9999
		rAddress = '127.0.0.1'
		protocol = 'udp'
		pollTime = 0.5
	end
	
	properties (SetAccess = private, GetAccess = public)
		lAddress = '127.0.0.1'
		s = 0
		spikes %hold the sorted spikes
		nTrials = 0
		totalTrials = 5
		trial = struct()
		myFigure = -1
		myAxis = -1
		parameters
		units
		conn
		o
	end
	
	%=======================================================================
	methods %------------------PUBLIC METHODS
		%=======================================================================
		
		% ===================================================================
		%> @brief Class constructor
		%>
		%> More detailed description of what the constructor does.
		%>
		%> @param args are passed as a structure of properties which is
		%> parsed.
		%> @return instance of class.
		% ===================================================================
		function obj = opxOnline(varargin)
			[~,~,keyCode]=KbCheck;
			obj.run
		end
		
		% ===================================================================
		%> @brief 
		%>
		%> 
		% ===================================================================
		function listen(obj)
			obj.conn=dataConnection(struct('rPort',obj.rPort,'lPort', ...
				obj.lPort, 'rAddress', obj.rAddress,'protocol',obj.protocol));
			while loop
				pause(0.5)
				obj.conn.checkData
			end
		end
		
		% ===================================================================
		%> @brief 
		%>
		%> 
		% ===================================================================
		function run(obj)
			obj.s = PL_InitClient(0);
			if obj.s == 0
				return
			end
			
			obj.getParameters;
			obj.getnUnits;
			
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
				while obj.nTrials <= obj.totalTrials
					PL_TrialDefine(obj.s, obj.eventStart, obj.eventEnd, 0, 0, 0, 0, [1 2 3], [1], 0);
					fprintf('\nLooping at %i\n', obj.nTrials);
					[rn, trial, spike, analog, last] = PL_TrialStatus(obj.s, 3, obj.maxWait); %wait until end of trial
					fprintf('rn: %i tr: %i sp: %i al: %i lst: %i\n',rn, trial, spike, analog, last);
					if last > 0
						[obj.trial(obj.nTrials).ne, obj.trial(obj.nTrials).eventList]  = PL_TrialEvents(obj.s, 0, 0);
						[obj.trial(obj.nTrials).ns, obj.trial(obj.nTrials).spikeList]  = PL_TrialSpikes(obj.s, 0, 0);
						obj.nTrials = obj.nTrials+1;
					end
					obj.draw;
					esc=obj.checkKeys;
					if esc == 1
						break
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
		
		% ===================================================================
		%> @brief 
		%>
		%> 
		% ===================================================================
		function draw(obj)
			axes(obj.myAxis);
			plot([1:10],[1:10]*obj.nTrials)
			title(['On Trial: ' num2str(obj.nTrials)]);
			drawnow;
		end
		
		% ===================================================================
		%> @brief 
		%>
		%> 
		% ===================================================================
		function getParameters(obj)
			if obj.s>0
				pars = PL_GetPars(obj.s);
				fprintf('Server Parameters:\n\n');
				fprintf('DSP channels: %.0f\n', pars(1));
				fprintf('Timestamp tick (in usec): %.0f\n', pars(2));
				fprintf('Number of points in waveform: %.0f\n', pars(3));
				fprintf('Number of points before threshold: %.0f\n', pars(4));
				fprintf('Maximum number of points in waveform: %.0f\n', pars(5));
				fprintf('Total number of A/D channels: %.0f\n', pars(6));
				fprintf('Number of enabled A/D channels: %.0f\n', pars(7));
				fprintf('A/D frequency (for continuous "slow" channels, Hz): %.0f\n', pars(8));
				fprintf('A/D frequency (for continuous "fast" channels, Hz): %.0f\n', pars(13));
				fprintf('Server polling interval (msec): %.0f\n', pars(9));
				obj.parameters.raw = pars;
				obj.parameters.channels = pars(1);
				obj.parameters.timestamp=pars(2);
			end
		end
		
		% ===================================================================
		%> @brief 
		%>
		%> 
		% ===================================================================
		function getnUnits(obj)
			if obj.s>0
				obj.units.raw = PL_GetNumUnits(obj.s);
				obj.units.activeChs = find(obj.units.raw > 0);
				obj.units.nCh = length(obj.units.activeChs);
				obj.units.nSpikes = obj.units.raw(obj.units.raw > 0);
				for i=1:length(obj.units.activeChs)
					if i==1
						obj.units.index{1}=1:obj.units.nSpikes(1);
					else
						inc=sum(obj.units.nSpikes(1:i-1));
						obj.units.index{i}=(1:obj.units.nSpikes(i))+inc;
					end
				end
				obj.units.spikes = cell(sum(obj.units.nSpikes),1);
			end
		end
		
		% ===================================================================
		%> @brief 
		%>
		%> 
		% ===================================================================
		function updateUnits(obj)
			
		end
		
		% ===================================================================
		%> @brief 
		%>
		%> 
		% ===================================================================
		function out=checkKeys(obj)
			out=0;
			[~,~,keyCode]=KbCheck;
			keyCode=KbName(keyCode);
			if ~isempty(keyCode)
				key=keyCode;
				if iscell(key);key=key{1};end
				if regexpi(key,'^esc')
					out=1;
				end
			end
		end
		
		% ===================================================================
		%> @brief 
		%>
		%> 
		% ===================================================================
		function close(obj)
			PL_Close(obj.s);
		end
	end
end

