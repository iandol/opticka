% ========================================================================
%> @brief LABJACK Connects and manages a LabJack U3-HV
%>
%> Connects and manages a LabJack U3-HV
%>
% ========================================================================
classdef opxOnline < handle
	properties
		type = 'launcher'
		eventStart = 257
		eventEnd = -255
		maxWait = 30000
		autoRun = 1
		isSlave = 0
		protocol = 'udp'
		rAddress = '127.0.0.1'
		rPort = 8998
		lAddress = '127.0.0.1'
		lPort = 9889
		pollTime = 0.5
		verbosity = 0
	end
	
	properties (SetAccess = private, GetAccess = public)
		masterPort = 9990
		slavePort = 9991
		opxConn %> connection to the omniplex
		conn %listen connection
		msconn %master slave connection
		spikes %hold the sorted spikes
		nRuns = 0
		totalRuns = 5
		trial = struct()
		parameters
		units
		stimulus
		tmpFile
		isSlaveConnected = 0
		isMasterConnected = 0
		error
		h %GUI handles
	end
	
	properties (SetAccess = private, GetAccess = private)
		allowedProperties='^(type|eventStart|eventEnd|protocol|rPort|rAddress|verbosity)$'
		slaveCommand
		masterCommand
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
			if strcmpi(obj.type,'master') || strcmpi(obj.type,'launcher')
				obj.isSlave = 0;
			end
			if ispc
				obj.masterCommand = '!matlab -nodesktop -nosplash -r "opxRunMaster" &';
				obj.slaveCommand = '!matlab -nodesktop -nosplash -nojvm -r "opxRunSlave" &';
			else
				obj.masterCommand = '!osascript -e ''tell application "Terminal"'' -e ''activate'' -e ''do script "matlab -nodesktop -nosplash -maci -r \"opxRunMaster\""'' -e ''end tell''';
				obj.slaveCommand = '!osascript -e ''tell application "Terminal"'' -e ''activate'' -e ''do script "matlab -nodesktop -nosplash -nojvm -maci -r \"opxRunSlave\""'' -e ''end tell''';
			end
			switch obj.type
				
				case 'master'
					
					obj.spawnSlave;
					if obj.isSlaveConnected == 0
						warning('Sorry, slave process failed to initialize!!!')
					end
					obj.initializeMaster;
					obj.listenMaster;
					
				case 'slave'
					
					obj.initializeSlave;
					obj.waitSlave;
					
				case 'launcher'
					%we simply need to launch a new master and return
					eval(obj.masterCommand);
					
			end
		end
		
		% ===================================================================
		%> @brief listenMaster
		%>
		%>
		% ===================================================================
		function listenMaster(obj)
			fprintf('\nListening for opticka, and controlling slave!');
			loop = 1;
			while loop
				if ~rem(loop,20);fprintf('.');end
				if ~rem(loop,200);fprintf('\n');fprintf('~');obj.msconn.write('--master growls--');end
				
				if obj.conn.checkData
					data = obj.conn.read(0);
					%data = regexprep(data,'\n','');
					fprintf('\n{opticka message:%s}',data);
					switch data
						case '--ping--'
							obj.conn.write('--ping--');
							obj.msconn.write('--ping--');
							fprintf('\nOpticka pinged us, we ping opticka and slave!');
						case '--readStimulus--'
							obj.stimulus=obj.conn.readVar;
							obj.totalRuns = obj.stimulus.r.task.nRuns;
							if isa(obj.stimulus,'opticka')
								fprintf('We have the stimulus from opticka, waiting for GO!');
								obj.msconn.write('--nRuns--');
								obj.msconn.write(uint32(obj.totalRuns));
							else
								fprintf('We have the stimulus from opticka, but it is malformed!');
								obj.stimulus = [];
							end
						case '--GO!--'
							if ~isempty(obj.stimulus)
								loop = 0;
								opx.msconn.write('--GO!--') %tell slave to run
								obj.parseData;
								break
							end
						case '--flushData--'
							fprintf('Opticka asked us to clear data, we should comply!');
							%obj.flushData;
						case '--bark order--'
							obj.msconn.write('\n--obey me!--\n');
							fprintf('\nOpticka asked us to bark, we should comply!');
						case '--quit--'
							fprintf('\nOpticka asked us to quit, meanies!');
							obj.msconn.write('--quit--')
							loop = 0;
							break
						otherwise
							fprintf('Someone spoke, but what did they say?...')
					end
				end
				
				if obj.msconn.checkData
					fprintf('\n{slave message: ');
					data = obj.msconn.read(0);
					if iscell(data)
						for i = 1:length(data)
							fprintf('%s\t',data{i});
						end
						fprintf('}\n');
					else
						fprintf('%s}\n',data);
					end
				end
				
				if obj.msconn.checkStatus ~= 6 %are we a udp client?
					checkS = 1;
					while checkS < 10
						obj.msconn.close;
						pause(0.1)
						obj.msconn.open;
						if obj.msconn.checkStatus == 6; 
							break
						end
						checkS = checkS + 1;
					end
				end
				
				if obj.conn.checkStatus ~= 12; %are we a TCP server?
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
				pause(0.1)
				loop = loop + 1;
			end
			fprintf('\nMaster is sleeping, use listenMaster to make me listen again...');	
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
					data = regexprep(data,'\n','');
					fprintf('\n{message:%s}',data);
					switch data
						case '--nRuns--'
							nRuns = double(obj.msconn.read(0,'uint32'))
							obj.totalRuns = nRuns;
							fprintf('\nMaster send us number of runs: %d\n',obj.totalRuns);
						case '--ping--'
							obj.msconn.write('--ping--');
							fprintf('\nMaster pinged us, we ping back!');
						case '--hello--'
							fprintf('\nThe master has spoken...');
							obj.msconn.write('--i bow--')
						case '--tmpFile--'
							obj.tmpFile = obj.msconn.read(0);
							fprintf('\nThe master tells me tmpFile= %s',obj.tmpFile);
						case '--master growls--'
							fprintf('\nMaster growls, time to lick some boot...');
						case '--quit--'
							fprintf('\nMy service is no longer required (sniff)...\n');
							data = obj.msconn.read(1); %we flush out the remaining commands
							%eval('exit')
							break
						case '--GO!--'
							fprintf('Time to run, yay!')
							loop = 0;
						case '--obey me!--'
							fprintf('\nThe master has barked because of opticka...');
							obj.msconn.write('--i quiver before you and opticka--')
						case '--tempfile--'
							obj.tmpFile = obj.msconn.read(0);
							fprintf('\nThe master told us tmp file is: %s', obj.tmpFile);
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
		function parseData(obj)
			
		end
		
		% ===================================================================
		%> @brief
		%>
		%>
		% ===================================================================
		function run(obj)
			tic
			abort=0;
			obj.nRuns = 0;
			
			obj.opxConn = PL_InitClient(0);
			if obj.opxConn == 0
				return
			end
			
			obj.getParameters;
			obj.getnUnits;
			
			save(obj.tmpFile,obj);
			obj.msconn.write('--beforeRun--');
			pause(0.1);
			
			obj.trial = struct;
			obj.nRuns=1;
			toc
			try
				while obj.nRuns <= obj.totalRuns
					PL_TrialDefine(obj.opxConn, obj.eventStart, obj.eventEnd, 0, 0, 0, 0, [1 2 3], [1], 0);
					fprintf('\nLooping at %i\n', obj.nRuns);
					[rn, trial, spike, analog, last] = PL_TrialStatus(obj.opxConn, 3, obj.maxWait); %wait until end of trial
					fprintf('rn: %i tr: %i sp: %i al: %i lst: %i\n',rn, trial, spike, analog, last);
					if last > 0
						tic
						[obj.trial(obj.nRuns).ne, obj.trial(obj.nRuns).eventList]  = PL_TrialEvents(obj.opxConn, 0, 0);
						[obj.trial(obj.nRuns).ns, obj.trial(obj.nRuns).spikeList]  = PL_TrialSpikes(obj.opxConn, 0, 0);
						
						save(obj.tmpFile,obj);
						obj.msconn.write('--finishRun--');
						obj.msconn.write(uint32(obj.nRuns));
						
						obj.nRuns = obj.nRuns+1;
						toc
					end
					if obj.msconn.checkData
						command = obj.conn.read(0);
						switch command
							case '--abort--'
								abort = 1;
								break
						end
					end

				end
				
				% you need to call PL_Close(s) to close the connection
				% with the Plexon server
				obj.closePlexon;
				
				obj.waitSlave;
				
			catch ME
				obj.nRuns = 0;
				obj.closePlexon;
				obj.error = ME;
			end
		end
		
		% ===================================================================
		%> @brief
		%>
		%>
		% ===================================================================
		function draw(obj)
			axes(obj.myAxis);
			plot([1:10],[1:10]*obj.nRuns)
			title(['On Trial: ' num2str(obj.nRuns)]);
			drawnow;
		end
		
		% ===================================================================
		%> @brief
		%>
		%>
		% ===================================================================
		function closePlexon(obj)
			if exist('mexPlexOnline','file') && ~isempty(obj.opxConn) && obj.opxConn > 0
				PL_Close(obj.opxConn);
				obj.opxConn = [];
			end
		end
		
		% ===================================================================
		%> @brief
		%>
		%>
		% ===================================================================
		function closeAll(obj)
			obj.closePlexon;
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
				obj.parameters.timedivisor = 1e6 / obj.parameters.timestamp;
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
		function reopenConnctions(obj)
			switch obj.type
				case 'master'
					try
						if obj.conn.checkStatus == 0
							obj.conn.closeAll;
							obj.msconn.closeAll;
							obj.msconn.open;
							obj.conn.open;
						end
					catch ME
						obj.error = ME;
					end
				case 'slave'
					try
						if obj.conn.checkStatus == 0
							obj.msconn.closeAll;
							obj.msconn.open;
						end
					catch ME
						obj.error = ME;
					end
			end
		end
		% ===================================================================
		%> @brief
		%>
		%>
		% ===================================================================
		function initializeMaster(obj)
			fprintf('\nMaster is initializing, bow before my greatness...\n');
			obj.conn=dataConnection(struct('verbosity',obj.verbosity, 'rPort', obj.rPort, ...
				'lPort', obj.lPort, 'lAddress', obj.lAddress, 'rAddress', ... 
				obj.rAddress, 'protocol', 'tcp', 'autoOpen', 1, 'type', 'server'));
			if obj.conn.isOpen == 1
				fprintf('Master can listen for opticka...')
			else
				fprintf('Master is deaf...')
			end
			obj.tmpFile = [tempname,'.mat'];
			obj.msconn.write('--tmpFile--');
			obj.msconn.write(obj.tmpFile)
			fprintf('We tell slave to use tmpFile = %s', obj.tmpFile)
		end
		
		% ===================================================================
		%> @brief
		%>
		%>
		% ===================================================================
		function initializeSlave(obj)
			fprintf('\n===Slave is initializing, do with me what you will...===\n\n');
			obj.msconn=dataConnection(struct('verbosity', obj.verbosity, 'rPort', obj.masterPort, ...
					'lPort', obj.slavePort, 'rAddress', obj.lAddress, ... 
					'protocol',	obj.protocol,'autoOpen',1));
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
			eval(obj.slaveCommand);
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
				if ~isempty(response) && ~isempty(regexpi(response, '--i bow--'))
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
			obj.closeAll;
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


