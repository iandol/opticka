% ========================================================================
%> @brief LABJACK Connects and manages a LabJack U3-HV
%>
%> Connects and manages a LabJack U3-HV
%>
% ========================================================================
classdef opxOnline < handle
	properties
		eventStart = 257
		eventEnd = -255
		maxWait = 30000
		autoRun = 1
		isSlave = 0
		protocol = 'udp'
		rAddress = '127.0.0.1'
		rPort = 8888
		lAddress = '127.0.0.1'
		lPort = 9889
		pollTime = 0.5
		verbosity = 0
	end
	
	properties (SetAccess = private, GetAccess = public)
		masterPort = 9990
		slavePort = 9991
		opxConn = 0 %> connection to the omniplex
		conn %listen connection
		msconn %master slave connection
		spikes %hold the sorted spikes
		nTrials = 0
		totalTrials = 5
		trial = struct()
		parameters
		units
		stimulus
		tmpfile
		isSlaveConnected = 0
		isMasterConnected = 0
	end
	
	properties (SetAccess = private, GetAccess = private)
		allowedProperties='^(isSlave|protocol|rPort|rAddress|verbosity)$'
		runCommand
		myFigure = -1
		myAxis = -1
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
		function obj = opxOnline(args)
			if nargin>0 && isstruct(args)
				fnames = fieldnames(args); %find our argument names
				for i=1:length(fnames);
					if regexp(fnames{i},obj.allowedProperties) %only set if allowed property
						obj.salutation(fnames{i},'Configuring setting in constructor');
						obj.(fnames{i})=args.(fnames{i}); %we set up the properies from the arguments as a structure
					end
				end
			end
			if ispc
				obj.runCommand = '!matlab -nodesktop -nosplash -r "opxRunSlave" &';
			else
				obj.runCommand = '!osascript -e ''tell application "Terminal"'' -e ''activate'' -e ''do script "matlab -nodesktop -nosplash -maci -r \"opxRunSlave\""'' -e ''end tell''';
			end
			if obj.isSlave == 0
				
				obj.spawnSlave;
				if obj.isSlaveConnected == 0
					warning('Sorry, slave process failed to initialize!!!')
				end
				obj.initializeMaster;
				obj.listenMaster;
				
			elseif obj.isSlave == 1
				
				obj.initializeSlave;
				obj.waitSlave;
				
			end
		end
		
		% ===================================================================
		%> @brief
		%>
		%>
		% ===================================================================
		function waitSlave(obj)
			fprintf('\nHumble Slave is Eagerly Listening to Master');
			loop = 1;
			while loop
				if ~rem(loop,20);fprintf('.');end
				if ~rem(loop,200);fprintf('\n');fprintf('~');obj.msconn.write('--abuse me do!--');end
				if obj.msconn.checkData
					data = obj.msconn.read(0);
					fprintf('\n{message:%s}',data);
					switch data
						case '--hello--'
							fprintf('\nThe master has spoken...');
							obj.msconn.write('--i bow--')
						case '--tmpfile--'
							obj.tmpfile = obj.msconn.read(0);
							fprintf('\nThe master tells me tmpfile= %s',obj.tmpfile);
						case '--master growls--'
							fprintf('\nMaster growls, time to lick some boot...');
						case '--quit--'
							fprintf('\nMy service is no longer required (sniff)...\n');
							data = obj.msconn.read(1); %we flush out the remaining commands
							%eval('exit')
							break
						case '--obey me!--'
							fprintf('\nThe master has barked because of opticka...');
							obj.msconn.write('--i quiver before you and opticka--')
						case '--tempfile--'
							obj.tmpfile = obj.msconn.read(0);
							fprintf('\nThe master told us tmp file is: %s', obj.tmpfile);
						otherwise
							fprintf('\nThe master has barked, but I understand not!...');
					end
				end
				if obj.msconn.checkStatus == 0 %have we disconnected?
					checkS = 1;
					while checkS < 10
						obj.msconn.close; %lets reconnect
						pause(0.1)
						obj.msconn.open;
						if obj.msconn.checkStatus ~= 0; 
							break
						end
						checkS = checkS + 1;
					end
				end
				if obj.checkKeys
					break
				end
				pause(0.2);
				loop = loop + 1;
			end
			fprintf('\nSlave is sleeping, use waitSlave to make me listen again...');		
		end
		
		% ===================================================================
		%> @brief
		%>
		%>
		% ===================================================================
		function listenMaster(obj)
			fprintf('\nListening for opticka, and controlling slave!');
			obj.msconn.write('--obey me!--');
			loop = 1;
			while loop
				if ~rem(loop,20);fprintf('.');end
				if ~rem(loop,200);fprintf('\n');fprintf('~');obj.msconn.write('--master growls--');end
				
				if obj.conn.checkData
					data = obj.conn.read(1);
					fprintf('\n{opticka message:%s}',data);
					for i=1:size(data,1)
						if iscell(data)
							datatmp = data{i};
						else
							datatmp = data(i,:);
						end
						switch datatmp
							case '--readStimulus--'
								obj.stimulus=obj.conn.readVar;
								fprintf('We have the stimulus from opticka, waiting for GO!');
							case '--GO!--'
								loop = 0;
								obj.parseData;
							case '--flushData--'
								fprintf('Opticka asked us to clear data, we MUST comply!');
								obj.flushData;
							case '--bark order--'
								fprintf('Opticka asked us to bark, we MUST comply!');
								obj.msconn.write('--obey me!--');
							case '--quit--'
								fprintf('Opticka asked us to quit, meanies!');
								obj.msconn.write('--quit--')
								loop = 0;
								break
							otherwise
								fprintf('Someone spoke, but what did they say?...')
						end
					end
					
				end
				if obj.msconn.checkData
					fprintf('\nSlave Message: ');
					data = obj.msconn.read(1);
					if iscell(data)
						for i = 1:length(data)
							fprintf('%s\t',data{i});
						end
						fprintf('\n');
					else
						fprintf('%s\n',data);
					end
				end
				
				if obj.msconn.checkStatus == 0
					checkS = 1;
					while checkS < 10
						obj.msconn.close;
						pause(0.1)
						obj.msconn.open;
						if obj.msconn.checkStatus ~= 0; 
							break
						end
						checkS = checkS + 1;
					end
				end
				
				if obj.conn.conn < 0; 
					obj.conn.checkClient;
					if obj.conn.conn > -1
						fprintf('\nWe''ve opened a new connection to opticka...\n')
						obj.conn.write('--opened--');
						pause(0.25)
					end
				end
				
				if obj.checkKeys
					obj.msconn.write('--quit--')
					break
				end
				pause(0.2)
				loop = loop + 1;
			end
			fprintf('\nMaster is sleeping, use listenMaster to make me listen again...');	
		end
		
		% ===================================================================
		%> @brief
		%>
		%>
		% ===================================================================
		function run(obj)
			abort=0;
			obj.opxConn = PL_InitClient(0);
			if obj.opxConn == 0
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
					PL_TrialDefine(obj.opxConn, obj.eventStart, obj.eventEnd, 0, 0, 0, 0, [1 2 3], [1], 0);
					fprintf('\nLooping at %i\n', obj.nTrials);
					[rn, trial, spike, analog, last] = PL_TrialStatus(obj.opxConn, 3, obj.maxWait); %wait until end of trial
					fprintf('rn: %i tr: %i sp: %i al: %i lst: %i\n',rn, trial, spike, analog, last);
					if last > 0
						[obj.trial(obj.nTrials).ne, obj.trial(obj.nTrials).eventList]  = PL_TrialEvents(obj.opxConn, 0, 0);
						[obj.trial(obj.nTrials).ns, obj.trial(obj.nTrials).spikeList]  = PL_TrialSpikes(obj.opxConn, 0, 0);
						obj.nTrials = obj.nTrials+1;
					end
					obj.draw;
					if obj.conn.checkData
						data = obj.conn.read(0);
						switch data
							case '--abort--'
								abort = 1;
								break
						end
					end
					% 					esc=obj.checkKeys;
					% 					if esc == 1
					% 						break
					% 					end
				end
				% you need to call PL_Close(s) to close the connection
				% with the Plexon server
				obj.close;
				obj.opxConn = 0;
				
				obj.listen;
				
			catch ME
				obj.nTrials = 0;
				obj.close;
				obj.opxConn = 0;
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
			if obj.opxConn>0
				pars = PL_GetPars(obj.opxConn);
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
			if obj.opxConn>0
				obj.units.raw = PL_GetNumUnits(obj.opxConn);
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
		function close(obj)
			if exist('mexPlexOnline')
				PL_Close(obj.opxConn);
			end
			if isa(obj.conn,'dataConnection')
				obj.conn.close;
			end
			if isa(obj.msconn,'dataConnection')
				obj.msconn.close;
			end
		end
	end %END METHODS
	
	%=======================================================================
	methods ( Access = private ) % PRIVATE METHODS
		%=======================================================================
		
		% ===================================================================
		%> @brief
		%>
		%>
		% ===================================================================
		function initializeMaster(obj)
			fprintf('\nMaster is initializing, bow before my greatness...\n');
			obj.conn=dataConnection(struct('rPort',obj.rPort,'lPort', ...
					obj.lPort, 'rAddress', obj.rAddress,'protocol','tcp', ...
					'autoOpen',1,'type','server','verbosity',obj.verbosity));
			if obj.conn.isOpen == 1
				fprintf('Master can listen to opticka...')
			else
				fprintf('Master is deaf...')
			end
			obj.tmpfile = [tempname,'.mat'];
			obj.msconn.write('--tmpfile--');
			obj.msconn.write(obj.tmpfile)
			fprintf('We tell slave to use tmpfile = %s', obj.tmpfile)
		end
		
		% ===================================================================
		%> @brief
		%>
		%>
		% ===================================================================
		function initializeSlave(obj)
			fprintf('\n===Slave is initializing, do with me what you will...===\n\n');
			obj.msconn=dataConnection(struct('rPort',obj.masterPort,'lPort', ...
					obj.slavePort, 'rAddress', obj.lAddress,'protocol',obj.protocol,'autoOpen',1, ...
					'verbosity',obj.verbosity));
			if obj.msconn.isOpen == 1
				fprintf('Slave has opened its ears...\n')
			else
				fprintf('Slave is deaf...\n')
			end
		end
		
		% ===================================================================
		%> @brief
		%>
		%>
		% ===================================================================
		function spawnSlave(obj)
			eval(obj.runCommand);
			obj.msconn=dataConnection(struct('rPort',obj.slavePort,'lPort', ...
				obj.masterPort, 'rAddress', obj.lAddress,'protocol',obj.protocol,'autoOpen',1, ...
				'verbosity',obj.verbosity));
			if obj.msconn.isOpen == 1
				fprintf('\nMaster can bark at slave...')
			else
				fprintf('\nMaster cannot bark at slave...')
			end
			i=1;
			while i
				if i > 100
					i=0;
					break
				end
				obj.msconn.write('--hello--')
				pause(0.1)
				response = obj.msconn.read;
				if iscell(response);response=response{1};end
				if regexpi(response, '--i bow--')
					fprintf('\nSlave knows who is boss...')
					obj.isSlaveConnected = 1;
					obj.isMasterConnected = 1;
					break
				end
				i=i+1;
				pause(0.5)
			end
			
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
		%> @brief Destructor
		%>
		%>
		% ===================================================================
		function delete(obj)
			obj.salutation('DELETE Method','Cleaning up now...')
			obj.close;
		end
		
		% ===================================================================
		%> @brief Prints messages dependent on verbosity
		%>
		%> Prints messages dependent on verbosity
		%> @param in the calling function
		%> @param message the message that needs printing to command window
		% ===================================================================
		function salutation(obj,in,message)
			if obj.verbosity > 0
				if ~exist('in','var')
					in = 'General Message';
				end
				if exist('message','var')
					fprintf([message ' | ' in '\n']);
				else
					fprintf(['\nHello from ' obj.name ' | opxOnline\n\n']);
				end
			end
		end
	end
end


