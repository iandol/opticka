% ========================================================================
%> @brief opxOnline Provides an interface between Opticka and the Plexon
%>	for online data display
%> 
%>
%>
%> Copyright ©2014-2022 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ========================================================================
classdef opxOnline < handle
	properties
		%> type is either launcher, master or slave
		type = 'launcher'
		%> event marker used by Plexon SDK; 257 is any strobed event
		eventStart = 257
		%>event marker to denote trial end; 2047 is the maximum strobe number we can generate
		eventEnd = -32767
		%> time to wait between trials by the slave
		maxWait = 6000 
		autoRun = 1
		protocol = 'udp'
		rAddress = '127.0.0.1'
		rPort = 8998
		lAddress = '127.0.0.1'
		lPort = 9889
		pollTime = 0.5
		verbosity = 0
		%> sometimes we shouldn't cleanup connections on delete, e.g. when we pass this
		%> object to another matlab instance as we will close the wrong connections!!!
		cleanup = 1
		%> should we replot all data in the ui?
		replotFlag = 0
		%> struct containing several plot options
		plotOptions
		%> the directory to save completed runs
		saveDirectory = 'E:\PlexonData\'
	end
	
	properties (SetAccess = private, GetAccess = public)
		%> a dateStamp initialised on first construction
		dateStamp
		%> master UDP port
		masterPort = 11111
		%> slave UDP port
		slavePort = 11112
		%> listen connection
		conn 
		%> master slave connection
		msconn 
		nRuns = 0
		totalRuns = 0
		%> structure with raw spike data generated from the Plexon trial-based API
		trial = []
		%> parameters of the Plexon connection
		parameters = []
		%> information about sorted units from the Plexon
		units = []
		%> the stimulus sent from the opticka display machine
		stimulus
		%> the temporary file used to store data files shared between master and slave
		tmpFile
		%> the raw data in trial parsed via the parseOpxSpikes class
		data
		%> the last error caught in try / catch statements
		error
	end
	
	properties (SetAccess = private, GetAccess = public, Transient = true)
		isLooping = false
		%> connection to the omniplex
		opxConn 
		%> did we establish a slave connection
		isSlaveConnected = false
		%> did we establish a master connection
		isMasterConnected = false
		%> GUI handles
		h
		%> our panel for plotting
		p
	end
	
	properties (SetAccess = private, GetAccess = private)
		allowedProperties='type|eventStart|eventEnd|protocol|rPort|rAddress|verbosity|cleanup'
		slaveCommand
		masterCommand
		oldcv = 0
		%> should we respecify the matrix for plotting?
		respecifyMatrix = false
		%> Matlab version
		mversion
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
			
			if nargin>0
				obj.parseArgs(args);
			end
			
			obj.dateStamp = datestr(clock);
			obj.mversion = str2double(regexpi(version,'(?<ver>^\d\.\d[\d]?)','match','once'));
			fprintf('\n\nWelcome to opxOnline, running under Matlab %i\n\n',obj.mversion);
			
			if ispc
				try %#ok<TRYNC>
					Screen('Preference', 'SuppressAllWarnings',1);
					Screen('Preference', 'Verbosity', 0);
					Screen('Preference', 'VisualDebugLevel',0);
				end
				obj.masterCommand = '!matlab -nodesktop -nosplash -r "opxRunMaster" &';
				obj.slaveCommand =  '!matlab -nodesktop -nosplash -r "opxRunSlave" &';
			else
				obj.masterCommand = '!osascript -e ''tell application "Terminal"'' -e ''activate'' -e ''do script "matlab -nodesktop -nosplash -r \"opxRunMaster\""'' -e ''end tell''';
				obj.slaveCommand = '!osascript -e ''tell application "Terminal"'' -e ''activate'' -e ''do script "matlab -nodesktop -nosplash -nojvm -r \"opxRunSlave\""'' -e ''end tell''';
			end
			
			switch obj.type
				
				case 'master'
					
					obj.spawnSlave;
					obj.initializeUI;
					
					if obj.isSlaveConnected == false
						%warning('Sorry, slave failed to initialize!!!')
					end
					
					obj.initializeMaster;
					pause(0.1)
					
					if ispc
						p=fileparts(mfilename('fullpath'));
						dos([p filesep 'moveMatlab.exe']);
					elseif ismac
						p=fileparts(mfilename('fullpath'));
						unix(['osascript ' p filesep 'moveMatlab.applescript']);
					end
					
					obj.listenMaster;
					
				case 'slave'
					
					obj.initializeSlave;
					obj.listenSlave;
					
				case 'launcher'
					%we simply need to launch a new master and return
					eval(obj.masterCommand);
					
				otherwise
					return
					
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
			runNext = '';
			
			if obj.msconn.checkStatus ~= 6 %are we a udp client to the slave?
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
			
			if obj.conn.checkStatus('rconn') < 1;
				obj.conn.open;
			end
			
			set(obj.h.opxUIInfoBox,'String','Waiting for Opticka to (re)connect to us...');
			
			while loop
				
				if ~rem(loop,40);fprintf('.');end
				if ~rem(loop,400);fprintf('\n');fprintf('growl');obj.msconn.write('--master growls--');end
				
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
							obj.stimulus = [];
							tloop = 1;
							while tloop < 10
								pause(0.3);
								if obj.conn.checkData
									obj.stimulus=obj.conn.readVar;
									if isa(obj.stimulus,'runExperiment')
										obj.totalRuns = obj.stimulus.task.nRuns;
										obj.conn.write('--stimulusReceived--');
										obj.msconn.write('--nRuns--');
										obj.msconn.write(uint32(obj.totalRuns));
										fprintf('We have the stimulus from opticka, waiting for GO!\n');
										try
											obj.initializePlot('stimulus')
											t=obj.describeStimulus;
											[s1,s2]=size(t);
											[tt{2:s1+1}] = t{1:s1};
											tt{1} = ['We have stimulus, nRuns= ' num2str(obj.totalRuns) ' | waiting for go...\n'];
											for i = 1:length(tt)
												fprintf(tt{i});
											end
											set(obj.h.opxUIInfoBox,'String',tt)
										end
										break
									else
										fprintf('We have a stimulus from opticka, but it is malformed!');
										set(obj.h.opxUIInfoBox,'String',['We have stimulus, but it was malformed!'])
										obj.stimulus = [];
										obj.conn.write('--stimulusFailed--');
									end
								end
								tloop = tloop + 1;
							end
							
						case '--GO!--'
							if ~isempty(obj.stimulus)
								loop = 0;
								obj.msconn.write('--GO!--') %tell slave to run
								runNext = 'parseData';
								break
							end
							
						case '--eval--'
							tloop = 1;
							while tloop < 10
								pause(0.1);
								if obj.conn.checkData
									command = obj.msconn.read(0);
									fprintf('\nOpticka tells us to eval= %s\n',command);
									eval(command);
									break
								end
								tloop = tloop + 1;
							end
							
						case '--bark order--'
							obj.msconn.write('--obey me!--');
							fprintf('\nOpticka asked us to bark, we should comply!');
							
						case '--quit--'
							fprintf('\nOpticka asked us to quit, meanies!');
							obj.msconn.write('--quit--')
							loop = 0;
							break
							
						case '--exit--'
							fprintf('\nMy service is no longer required (sniff)...\n');
							eval('exit')
							break
							
						otherwise
							fprintf('Someone spoke, but what did they say?...')
					end
				end
				
				if obj.msconn.checkData
					fprintf('\n{slave message: ');
					readdata = obj.msconn.read(0);
					if iscell(readdata)
						for i = 1:length(readdata)
							fprintf('%s\t',readdata{i});
						end
						fprintf('}\n');
					else
						fprintf('%s}\n',readdata);
					end
				end
				
				if obj.msconn.checkStatus ~= 6 %are we a udp client, if not we try to reopen our connection
					checkS = 1;
					while checkS < 10
						obj.msconn.close;
						pause(0.1)
						obj.msconn.open;
						fprintf('\nWe may have disconnected, retrying: %i\n',checkS);
						if obj.msconn.checkStatus == 6;
							break
						end
						checkS = checkS + 1;
					end
				end
				
				if obj.conn.checkStatus ~= 12; %are we a TCP server?
					obj.conn.checkClient;
					if obj.conn.conn > 0
						fprintf('\nWe''ve opened a new connection to opticka...\n')
						set(obj.h.opxUIInfoBox,'String','Opticka has connected to us, waiting for stimulus!...');
						obj.conn.write('--opened--');
					end
				end
				
				if obj.checkKeys %has someone pressed the escape key to break the loop?
					obj.msconn.write('--quit--')
					break
				end
				pause(0.1)
				loop = loop + 1;
			end %end of main while loop
			
			switch runNext
				case 'parseData'
					set(obj.h.opxUIInfoBox,'String','Preparing to parse the online data...');
					obj.parseData;
				otherwise
					fprintf('\nMaster is sleeping, use listenMaster to make me listen again...');
			end
			
		end
		
		% ===================================================================
		%> @brief
		%>
		%>
		% ===================================================================
		function listenSlave(obj)
			
			fprintf('\nHumble Slave is Eagerly Listening to Master\n');
			loop = 1;
			obj.totalRuns = 0; %we reset it waiting for new stimulus
			
			if obj.msconn.checkStatus < 1 %have we disconnected?
				checkS = 1;
				while checkS < 5
					obj.msconn.close; %lets reconnect
					pause(0.1)
					obj.msconn.open;
					if obj.msconn.checkStatus > 0;
						break
					end
					checkS = checkS + 1;
				end
			end
			
			while loop
				
				if ~rem(loop,40);fprintf('.');end
				if ~rem(loop,400);fprintf('\n');fprintf('quiver at %i',loop);obj.msconn.write('--abuse me!--');end
				
				if obj.msconn.checkData
					readdata = obj.msconn.read(0);
					readdata = regexprep(readdata,'\n','');
					fprintf('\n{message:%s}\n',readdata);
					switch readdata
						
						case '--nRuns--'
							tloop = 1;
							obj.totalRuns = 0;
							while tloop < 10
								if obj.msconn.checkData
									tRun = double(obj.msconn.read(0,'uint32'));
									if tRun > 0 && tRun < 10000
										obj.totalRuns = tRun;
										fprintf('\nMaster send us number of runs: %d\n',obj.totalRuns);
										break
									end
								end
								pause(0.1);
								tloop = tloop + 1;
							end
							
						case '--ping--'
							obj.msconn.write('--ping--');
							fprintf('\nMaster pinged us, we ping back!\n');
							
						case '--hello--'
							fprintf('\nThe master has spoken...\n');
							obj.msconn.write('--i bow--');
							
						case '--tmpFile--'
							tloop = 1;
							while tloop < 10
								if obj.msconn.checkData
									obj.tmpFile = obj.msconn.read(0);
									fprintf('\nMaster tells me tmpFile = %s\n',obj.tmpFile);
									break
								end
								pause(0.1);
								tloop = tloop + 1;
							end
							
						case '--eval--'
							tloop = 1;
							while tloop < 10
								if obj.msconn.checkData
									command = obj.msconn.read(0);
									fprintf('\nThe master tells us to eval= %s\n',command);
									eval(command);
									break
								end
								pause(0.1);
								tloop = tloop + 1;
							end
							
						case '--master growls--'
							fprintf('\nMaster growls, we should lick some boot...\n');
							
						case '--quit--'
							fprintf('\nMy service is no longer required (sniff)...\n');
							data = obj.msconn.read(1); %we flush out the remaining commands
							break
							
						case '--exit--'
							fprintf('\nMy service is no longer required (sniff)...\n');
							eval('exit');
							
						case '--GO!--'
							if obj.totalRuns > 0
								fprintf('\nTime to run, yay!\n')
								obj.collectData;
							end
							
						case '--obey me!--'
							fprintf('\nThe master has barked because of opticka...\n');
							obj.msconn.write('--i quiver before you and opticka--');
							
						otherwise
							fprintf('\nThe master has barked, but I understand not!...\n');
					end
				end
				if obj.msconn.checkStatus('conn') < 1 %have we disconnected? if so, lets try and reopen connection
					lloop = 1;
					while lloop < 10
						fprintf('\nWe may have disconnected, retrying: %i\n',lloop);
						for i = 1:length(obj.msconn.connList)
							try %#ok<TRYNC>
								pnet(obj.msconn.connList(i), 'close');
							end
						end
						obj.msconn.open;
						if obj.msconn.checkStatus ~= 0;
							break
						end
						pause(0.1);
						lloop = lloop + 1;
					end
				end
				if obj.checkKeys
					break
				end
				pause(0.2);
				loop = loop + 1;
			end
			fprintf('\nSlave is sleeping, use listenSlave to make me listen again...');
		end
		
		% ===================================================================
		%> @brief parseData -- The main loop the master runs to load data saved by slave
		%> and then plot it lazily
		%>
		%>
		% ===================================================================
		function parseData(obj)
			obj.data=parseOpxSpikes;
			loop = 1;
			obj.isLooping = true;
			abort = 0;
			obj.nRuns = 0;
			opx=[];
			fprintf('\n\n===Parse Data Loop Starting===\n')
			while loop
				
				if ~rem(loop,40);fprintf('.');end
				if ~rem(loop,400);fprintf('\n');fprintf('ParseData:');end
				
				if obj.conn.checkData
					readdata = obj.conn.read(0);
					readdata = regexprep(readdata,'\n','');
					fprintf('\n{opticka message:%s}\n',readdata);
					switch readdata
						
						case '--ping--'
							obj.conn.write('--ping--');
							%obj.msconn.write('--ping--'); %don't ping slave, it is busy
							fprintf('\nOpticka pinged us, we ping opticka back!');
						case '--abort--'
							obj.msconn.write('--abort--');
							fprintf('\n\nOpticka asks us to abort, tell slave to stop too!');
							pause(0.1);
							abort = 1;
					end
				end
				
				if obj.msconn.checkData
					readdata = obj.msconn.read(0);
					fprintf('\n{Slave message:%s}\n',readdata);
					switch readdata
						
						case '--beforeRun--'
							load(obj.tmpFile);
							obj.units = opx.units;
							obj.parameters = opx.parameters;
							obj.data.initialize(obj);
							obj.initializePlot;
							fprintf('\nSlave is about to run the main collection loop...');
							set(obj.h.opxUIInfoBox,'String','Omniplex about to start data collection, slave waiting...');
							clear opx
							
						case '--finishRun--'
							dontPlot = false;
% 							tloop = 1;
% 							while tloop < 10
% 								if obj.msconn.checkData
% 									obj.nRuns = double(obj.msconn.read(0,'uint32'));
% 									fprintf('\nThe slave has completed run %d (tloop=%i)\n',obj.nRuns,tloop);
% 									break
% 								end
% 								tloop = tloop + 1;
% 							end
							load(obj.tmpFile);
							obj.trial = opx.trial;
							tic
							if opx.nRuns > obj.nRuns+1
								fprintf('We''ve lagged behind, lets parse from %d to %d runs...\n',obj.nRuns+1,opx.nRuns);
								obj.data.parseRuns(obj,[obj.nRuns+1:opx.nRuns]);
							elseif opx.nRuns == obj.nRuns+1
								obj.data.parseNextRun(obj);
							else
								fprintf('\nWaiting for slave...\n')
								dontPlot = true;
							end
							toc
							obj.nRuns = opx.nRuns;
							tic
							if dontPlot == false; obj.plotData; end
							toc
							set(obj.h.opxUIInfoBox,'String',['The slave has completed run ' num2str(obj.nRuns)]);
							clear opx
							
						case '--finishAll--'
							load(obj.tmpFile);
							obj.trial = opx.trial;
							obj.plotData
							loop = 0;
							tloop = 1;
							while tloop < 10
								pause(0.1);
								if obj.conn.checkData
									tdata = obj.conn.read(0);
									if strcmpi(tdata,'--finalStimulus--')
										pause(0.5);
										tstim=obj.conn.readVar;
										if isa(obj.stimulus,'runExperiment')
											obj.conn.write('--stimulusReceived--');
											obj.stimulus = tstim;
											fprintf('We have the stimulus from opticka after %i loops, lets save it!',tloop);
										else
											fprintf('We have a stimulus from opticka, but it is malformed!');
											set(obj.h.opxUIInfoBox,'String','We have stimulus, but it was malformed!')
											obj.conn.write('--stimulusFailed--');
										end
									end
								end
								tloop = tloop + 1;
							end
							save(obj.saveDirectory,'obj');
							save(obj.tmpFile,'obj');
							pause(0.2)
							abort = 1;
							
						case '--finishAbort--'
							load(obj.tmpFile);
							obj.trial = opx.trial;
							obj.plotData
							loop = 0;
							pause(0.2)
							save(obj.tmpFile,'obj');
							pause(0.2)
							abort = 1;
							
						case '--error--'
							fprintf('\nSlave choked on an error!...');
							abort = 1;
					end
				end
				if abort == 1;
					break
				end
			end
			obj.isLooping = false;
			obj.listenMaster
		end
		
		% ===================================================================
		%> @brief Main slave loop to collect and save  spikes from the Onmiplex
		%>
		%>
		% ===================================================================
		function collectData(obj)
			abort=0;
			status = obj.openPlexon;
			if status == -1
				abort = 1;
			end
			
			obj.getParameters;
			obj.getnUnits;
			
			obj.trial = struct;
			obj.nRuns = 1;
			obj.saveData;
			obj.msconn.write('--beforeRun--');
			pause(0.1);
			try
				while obj.nRuns <= obj.totalRuns && abort < 1
					PL_TrialDefine(obj.opxConn, obj.eventStart, obj.eventEnd, 0, 0, 0, 0, [1:16], 0, 0);
					fprintf('\nWaiting for run: %i\n', obj.nRuns);
					[rn, trial, spike, analog, last] = PL_TrialStatus(obj.opxConn, 3, obj.maxWait); %wait until end of trial
					tic
					if last > 0
						[obj.trial(obj.nRuns).ne, obj.trial(obj.nRuns).eventList]  = PL_TrialEvents(obj.opxConn, 0, 0);
						[obj.trial(obj.nRuns).ns, obj.trial(obj.nRuns).spikeList]  = PL_TrialSpikes(obj.opxConn, 0, 0);
						%[~, ~, analogList] = PL_TrialAnalogSamples(obj.opxConn, 0, 0);
						%fprintf('\nWe received %d spikes and %d events\n',obj.trial(obj.nRuns).ns,obj.trial(obj.nRuns).ne)
						obj.saveData('spikes');
						obj.msconn.write('--finishRun--');
						%obj.msconn.write(uint32(obj.nRuns));
						obj.nRuns = obj.nRuns+1;
					end
					if obj.msconn.checkData
						command = obj.msconn.read(0);
						switch command
							case '--abort--'
								fprintf('\nWe''ve been asked to abort\n')
								abort = 1;
								break
% 							case '--ping--'
% 								fprintf('\nMaster pinged, we ping back...\n')
% 								obj.msconn.write('--ping--')
						end
					end
					if obj.checkKeys
						break
					end
					toc
					%if exist('analogList','var');plot(ah,analogList);axis tight;title('Raw Analog Signal');end
					fprintf('run: %i trial: %i sp: %i al: %i lst: %i\n',rn, trial, spike, analog, last);
				end
				obj.saveData; %final save of data
				if abort == 1
					obj.msconn.write('--finishAbort--');
					obj.msconn.write(uint32(obj.nRuns));
				else
					obj.msconn.write('--finishAll--');
					obj.msconn.write(uint32(obj.nRuns));
				end
				% you need to call PL_Close(s) to close the connection
				% with the Plexon server
				obj.closePlexon;
				obj.listenSlave;
				
			catch ME
				obj.error = ME;
				fprintf('There was some error during data collection by slave!\n');
				fprintf('Error message: %s\n',obj.error.message);
				for i=1:length(obj.error.stack);fprintf('%i --- %s\n',obj.error.stack(i).line,obj.error.stack(i).name);end
				obj.nRuns = 0;
				obj.closePlexon;
				obj.listenSlave;
			end
		end
		
		% ===================================================================
		%> @brief plot is a shortcut function for commandline use
		%>
		% ===================================================================
		function plot(obj)
			if  ~isfield(obj.h,'uihandle') || ~ishandle(obj.h.uihandle)
				obj.initializePlot;
			end
			obj.plotData;
			set(obj.h.opxUIInfoBox,'String',['nRuns: ' num2str(obj.data.nRuns) ' | Created: ' obj.data.initializeDate]);
		end
		
		% ===================================================================
		%> @brief plotData is the main plotting function
		%> This takes our parseOpxSpikes data structure which is collected with
		%> parseData and plots it, either for all points (replotFlag==1) or just
		%> for the last trial that ran during a collection loop
		%>
		% ===================================================================
		function plotData(obj)
			cv = get(obj.h.opxUICell,'Value');
			xval = get(obj.h.opxUISelect1,'Value');
			yval = get(obj.h.opxUISelect2,'Value');
			zval = get(obj.h.opxUISelect3,'Value');
			method = get(obj.h.opxUIAnalysisMethod,'Value');
			fprintf('Plot using cell: %d -- ',cv)
			xmin = 0;
			xmax = str2num(get(obj.h.opxUIEdit1,'String'));
			if length(xmax) == 2
				xmin = xmax(1);
				xmax = xmax(2);
			end
			ymin = 0;
			ymax = str2num(get(obj.h.opxUIEdit2,'String'));
			if length(ymax) == 2
				ymin = ymax(1);
				ymax = ymax(2);
			end
			binWidth = str2double(get(obj.h.opxUIEdit3,'String'));
			if isempty(binWidth);binWidth = 25;end
			bins = round((obj.data.trialTime*1000) / binWidth);
			if isempty(xmax);xmax=2;end
			if isempty(ymax);ymax=50;end
			if isempty(zval);zval=1;end
			
			matrixSize = obj.data.matrixSize;
			offset = matrixSize*(zval-1);
			map = cell2mat(obj.data.unit{cv}.map(:,:,zval));  %maps our index to our display matrix
			nrows = size(map,1);
			ncols = size(map,2);
			map = map'; %remember subplot indexes by rows have to transform matrix first
			
			try
				if (obj.replotFlag == 1 || obj.respecifyMatrix == true || (cv ~= obj.oldcv) || method == 2)
					if ~isempty(obj.p);delete(obj.p);obj.p=[];end
					%obj.p = panel(obj.h.opxUIPanel,'defer');
					switch method
						case 1
							%obj.p.pack(obj.data.yLength, obj.data.xLength);
							pos = 1;
							startP = 1 + offset;
							endP = matrixSize + offset;
							fprintf('Plotting all points (offset: %i:%i)...\n', startP, endP);
							for i = startP:endP
								[x,y,z]=selectIndex(map(pos));
								data = obj.data.unit{cv}.raw{y,x,zval};
								nt = obj.data.unit{cv}.trials{y,x,zval};
								varlabel = [num2str(obj.data.unit{cv}.map{y,x,zval}) ': ' obj.data.unit{cv}.label{y,x,zval}];
								%obj.p(y,x).select();
								subplot(nrows,ncols,pos,'Parent',obj.h.opxUIPanel)
								plotPSTH()
								pos = pos + 1;
							end
							%obj.p.xlabel('Time (s)');
							%obj.p.ylabel('Instantaneous Firing Rate (Hz)');
							obj.respecifyMatrix=false;
							
						case 2
							%obj.p.pack(1,1);
							%obj.p(1,1).select();
							subplot(1,1,1,'Parent',obj.h.opxUIPanel)
							fprintf('Plotting Curve: (x=all y=%d z=%d)\n',yval,zval);
							data = obj.data.unit{cv}.trialsums(yval,:,zval);
							plotCurve();
							%obj.p.xlabel(obj.stimulus.task.nVar(1).name)
							%obj.p.ylabel('Spikes / Stimulus');
							obj.respecifyMatrix=true;
							
						case 3
							
					end
					%obj.p.de.margin = 0;
					%obj.p.margin = [15 15 5 15];
					%obj.p.fontsize = 10;
					%obj.p.de.fontsize = 10;
					%obj.p.refresh();
					
				else %single subplot
					thisRun = obj.data.thisRun;
					index = obj.data.thisIndex;
					[x,y,z]=selectIndex(index);
					if z == zval %our displayed z value is in the indexed position
						fprintf('Plotting run: %d (x=%d y=%d z=%d)\n',thisRun,x,y,z)
						plotIndex=find(map==index);
						switch method
							case 1
								data = obj.data.unit{cv}.raw{y,x,z};
								nt = obj.data.unit{1}.trials{y,x,z};
								varlabel = [num2str(obj.data.unit{cv}.map{y,x,z}) ': ' obj.data.unit{cv}.label{y,x,z}];
								%obj.p(y,x).select();
								subplot(nrows,ncols,plotIndex,'Parent',obj.h.opxUIPanel)
								plotPSTH(thisRun)
							case 2
								%obj.p.pack(1,1);
								%obj.p(1,1).select();
								subplot(1,1,1,'Parent',obj.h.opxUIPanel)
								plotCurve()
							case 3
								
						end
						%obj.p.de.margin = 0;
						%obj.p.margin = [15 15 5 15];
						%obj.p.fontsize = 10;
						%obj.p.de.fontsize = 10;
						%obj.p.refresh();
					else
						fprintf('Plot Not Visible: %d (x=%d y=%d z=%d)\n',thisRun,x,y,z)
					end
				end
			catch ME
				obj.error = ME;
				fprintf('Plot Error %s message: %s\n',obj.error.identifier,obj.error.message);
				for i=1:length(obj.error.stack);fprintf('%i --- %s\n',obj.error.stack(i).line,obj.error.stack(i).name);end
			end
			obj.replotFlag = 0;
			obj.oldcv=cv;
			
			% ===================================================================
			%> @brief Plots PSTH (inline function of plotData)
			% ===================================================================
			function [x,y,z]=selectIndex(inIdx)
				x = 1;
				y = 1;
				z = 1;
				mypos=find(obj.data.sIndex==inIdx);
				mypos=mypos(1);
				switch obj.data.nVars
					case 1
						x=obj.data.sMap(mypos,1);
					case 2
						x=obj.data.sMap(mypos,1);
						y=obj.data.sMap(mypos,2);
					case 3
						x=obj.data.sMap(mypos,1);
						y=obj.data.sMap(mypos,2);
						z=obj.data.sMap(mypos,3);
				end
			end

			% ===================================================================
			%> @brief Plots PSTH (inline function of plotData)
			% ===================================================================
			function plotPSTH(inRun)
				[n,t]=hist(data,bins);
				n=convertToHz(n);
				bar(t,n)
				tt={['Ch:' num2str(cv) ' | Trls:' num2str(nt)];['Var: ' varlabel]};
				text((xmax/30),ymax-(ymax/10),tt,'FontSize',8,'Color',[0.5 0.5 0.5]);
				axis([xmin xmax ymin ymax]);
				ph = findobj(gca,'Type','patch');
				if exist('inRun','var')
					set(ph,'FaceColor',[0.4 0 0],'EdgeColor',[0.4 0 0]);
				else
					set(ph,'FaceColor',[0 0 0],'EdgeColor',[0 0 0]);
				end
				pp=get(gca,'Position');
				perc=5;
				set(gca,'Position',[pp(1) pp(2) pp(3)+(pp(3)/perc) pp(4)+(pp(4)/perc)])
				if x ~= 1 
					set(gca,'YTickLabel',[]);
				end
				if y ~= obj.data.yLength
					set(gca,'XTickLabel',[]);
				end
				set(gca,'XGrid','off','YGrid','off','XMinorTick', 'on','YMinorTick','on','XColor',[0.3 0.3 0.3],'YColor',[0.3 0.3 0.3]);
				set(gca,'XGrid','off','YGrid','off','XMinorTick', 'on','YMinorTick','on','XColor',[0.4 0.4 0.4],'YColor',[0.4 0.4 0.4]);
			end
			
			% ===================================================================
			%> @brief Plots Curve (inline function of plotData)
			% ===================================================================
			function plotCurve()
				for ii = 1:length(data)
					[mn(ii),er(ii)]=analysisCore.stderr(data{ii});
				end
				me.areabar(obj.data.xValues',mn',er',[0.8 0.8 0.8],'k.-');
				set(gca,'XGrid','on','YGrid','on','XMinorTick', 'on','YMinorTick','on','XColor',[0.4 0.4 0.4],'YColor',[0.4 0.4 0.4]);
				xmin=min(obj.data.xValues);
				xmax=max(obj.data.xValues);
				axis([xmin-(xmax/20) xmax+(xmax/20) ymin ymax])
				box on
			end
			
			% ===================================================================
			%> @brief Plots Curve (inline function of plotData)
			% ===================================================================
			function plotDensity()
				
			end
			
			% ===================================================================
			%> @brief Converts to spikes per second (inline function of plotData)
			% ===================================================================
			function out = convertToHz(inn)
				out=(inn/nt)*(1000/binWidth);
			end
		end
		
		% ===================================================================
		%> @brief plot is a shortcut function for commandline use
		%>
		% ===================================================================
		function checkPlexonValues(obj)
			status = obj.openPlexon;
			if status == -1
				abort = 1;
			end
			obj.getnUnits;
			obj.initializePlot;
			obj.closePlexon;
		end
		
		% ===================================================================
		%> @brief Initialize the Plot before data collection starts
		%>	This sets up the plot UI with the cell (type='all') and/or stimulus
		%>	(type='stimulus') parameters.
		%> @param type Configure all or just the stimulus parameter
		% ===================================================================
		function initializePlot(obj,type)
			if ~exist('type','var')
				type = 'all';
			end
			if ~isstruct(obj.h) || ~isfield(obj.h,'uihandle')  || ~ishandle(obj.h.uihandle)
				obj.initializeUI;
			end
			try
				if strcmpi(type,'all')
					setStimulusValues();
					setCellValues();
				elseif strcmpi(type,'stimulus')
					setStimulusValues();
				end
				%obj.p = panel(obj.h.opxUIPanel,'defer');
				obj.replotFlag = 1;
			catch ME
				obj.error = ME;
				fprintf('Initialize Plot Error message: %s\n',obj.error.message);
				for i=1:length(obj.error.stack);fprintf('%i --- %s\n',obj.error.stack(i).line,obj.error.stack(i).name);end
			end
			% ===================================================================
			%> @brief makes cell list for UI (inline function of initializePlot)
			% ===================================================================
			function setCellValues()
				if isstruct(obj.units)
					s=cellstr(num2str((1:obj.units.totalCells)'));
					set(obj.h.opxUICell,'String', s);
				end
			end
			% ===================================================================
			%> @brief sets UI values for stimulus (inline function of initializePlot)
			% ===================================================================
			function setStimulusValues()
				if isa(obj.stimulus,'runExperiment')
					switch obj.stimulus.task.nVars
						case 0
							set(obj.h.opxUISelect1,'Enable','off')
							set(obj.h.opxUISelect2,'Enable','off')
							set(obj.h.opxUISelect3,'Enable','off')
							set(obj.h.opxUISelect1,'String',' ')
							set(obj.h.opxUISelect2,'String',' ')
							set(obj.h.opxUISelect3,'String',' ')
						case 1
							set(obj.h.opxUISelect1,'Enable','on')
							set(obj.h.opxUISelect2,'Enable','off')
							set(obj.h.opxUISelect3,'Enable','off')
							set(obj.h.opxUISelect1,'String',num2str(obj.stimulus.task.nVar(1).values'))
							set(obj.h.opxUISelect2,'String',' ')
							set(obj.h.opxUISelect3,'String',' ')
						case 2
							set(obj.h.opxUISelect1,'Enable','on')
							set(obj.h.opxUISelect2,'Enable','on')
							set(obj.h.opxUISelect3,'Enable','off')
							set(obj.h.opxUISelect1,'String',num2str(obj.stimulus.task.nVar(1).values'))
							set(obj.h.opxUISelect2,'String',num2str(obj.stimulus.task.nVar(2).values'))
							set(obj.h.opxUISelect3,'String',' ')
						case 3
							set(obj.h.opxUISelect1,'Enable','on')
							set(obj.h.opxUISelect2,'Enable','on')
							set(obj.h.opxUISelect3,'Enable','on')
							set(obj.h.opxUISelect1,'String',num2str(obj.stimulus.task.nVar(1).values'))
							set(obj.h.opxUISelect2,'String',num2str(obj.stimulus.task.nVar(2).values'))
							set(obj.h.opxUISelect3,'String',num2str(obj.stimulus.task.nVar(3).values'))
					end
					time=obj.stimulus.task.trialTime;
					set(obj.h.opxUIEdit1,'String',num2str(time))
					set(obj.h.opxUIEdit2,'String','50')
					set(obj.h.opxUIEdit3,'String','50')
				end
			end
		end
		
		% ===================================================================
		%> @brief Saves a reduced set of our object as a structure, passing
		%>		'spikes' reduces the data transmitted even further
		%>
		% ===================================================================
		function saveData(obj,type)
			if ~exist('type','var');type='all';end
			try
				switch type
					case 'spikes'
						opx.type='spikesonly';
						opx.nRuns = obj.nRuns;
						opx.trial = obj.trial;
						opx.tmpFile = obj.tmpFile;
						save(obj.tmpFile,'opx');
						fprintf('Spike data saved...\n')
					case 'reduced'
						opx.type = obj.type;
						opx.nRuns = obj.nRuns;
						opx.totalRuns = obj.totalRuns;
						opx.spikes = obj.spikes;
						opx.trial = obj.trial;
						opx.units = obj.units;
						opx.parameters = obj.parameters;
						opx.stimulus = obj.stimulus;
						opx.tmpFile = obj.tmpFile;
						save(obj.tmpFile,'opx');
					otherwise
						save(obj.tmpFile,'obj');
				end
			catch ME
				obj.error = ME;
				fprintf('There was some error during data collection + save data by slave!\n');
				fprintf('Error message: %s\n',obj.error.message);
				for i=1:length(obj.error.stack);fprintf('%i --- %s\n',obj.error.stack(i).line,obj.error.stack(i).name);end
			end
		end
		
		% ===================================================================
		%> @brief
		%>
		%>
		% ===================================================================
		function status=openPlexon(obj)
			status = -1;
			obj.opxConn = PL_InitClient(0);
			if obj.opxConn ~= 0
				status = 1;
				fprintf('\nPLEXON Client Connection open...\n');
			end
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
		%> @brief CloseAll closes all possible connections
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
		%> @brief Destructor
		%>
		% ===================================================================
		function delete(obj)
			obj.verbosity = 1;
			if obj.cleanup == 1
				obj.salutation('opxOnline Delete Method','Cleaning up now...')
				if isfield(obj.h,'uihandle') && ishandle(obj.h.uihandle)
					close(obj.h.uihandle);
				end
				if isfield(obj.h,'uiname') && isappdata(0,obj.h.uiname)
					rmappdata(0,obj.h.uiname)
				end
				obj.closeAll;
			else
				if isfield(obj.h,'uiname') && isappdata(0,obj.h.uiname)
					rmappdata(0,obj.h.uiname)
				end
				obj.salutation('opxOnline Delete Method','Closing (no cleanup)...')
			end
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
				obj.units.raw = obj.units.raw(1:32); %workround plexon bug
				obj.units.activeChs = find(obj.units.raw > 0);
				obj.units.nCh = length(obj.units.activeChs);
				obj.units.nCells = obj.units.raw(obj.units.raw > 0);
				obj.units.totalCells = sum(obj.units.nCells);
				for i=1:obj.units.nCh
					if i==1
						obj.units.indexb{1}=1:obj.units.nCells(1);
						obj.units.index{1}=1:obj.units.nCells(1);
						obj.units.listb(1:obj.units.nCells(i))=i;
						obj.units.list{i}(1:obj.units.nCells(i))=i;
					else
						inc=sum(obj.units.nCells(1:i-1));
						obj.units.indexb{i}=(1:obj.units.nCells(i))+inc;
						obj.units.index{i}=1:obj.units.nCells(i);
						obj.units.listb(1:obj.units.nCells(i))=i;
						obj.units.list{i}(1:obj.units.nCells(i))=i;
					end
				end
				obj.units.chlist = [obj.units.activeChs];
				obj.units.celllist=[obj.units.index{:}];
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
						for i=1:length(obj.error.stack);fprintf('%i --- %s\n',obj.error.stack(i).line,obj.error.stack(i).name);end
					end
				case 'slave'
					try
						if obj.conn.checkStatus == 0
							obj.msconn.closeAll;
							obj.msconn.open;
						end
					catch ME
						obj.error = ME;
						for i=1:length(obj.error.stack);fprintf('%i --- %s\n',obj.error.stack(i).line,obj.error.stack(i).name);end
					end
			end
		end
		
		% ===================================================================
		%> @brief InitializeUI opens the UI and sets appdata
		%>
		%>
		% ===================================================================
		function initializeUI(obj)
			obj.h = [];
			uihandle=opx_ui; %our GUI file
			obj.h=guidata(uihandle);
			obj.h.uihandle = uihandle;
			obj.h.uiname = ['opx' num2str(uihandle)];
			setappdata(0,obj.h.uiname,obj); %we stash our object in the root appdata store for retirieval from the UI
			set(obj.h.opxUIEdit1,'String','2')
			set(obj.h.opxUIEdit2,'String','50')
			set(obj.h.opxUIEdit3,'String','50')
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
				fprintf('Master can listen for opticka...\n')
			else
				fprintf('Master is deaf...\n')
			end
			obj.tmpFile = [tempname,'.mat'];
			obj.msconn.write('--tmpFile--');
			obj.msconn.write(obj.tmpFile)
			fprintf('We tell slave to use tmpFile: %s\n', obj.tmpFile)
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
			obj.msconn=dataConnection(struct('verbosity',obj.verbosity, 'rPort',obj.slavePort,'lPort', ...
				obj.masterPort, 'rAddress', obj.lAddress,'protocol',obj.protocol,'autoOpen',1));
			if obj.msconn.isOpen == 1
				fprintf('Master can bark at slave...\n')
			else
				fprintf('Master cannot bark at slave...\n')
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
		
		% ===================================================================
		%> @brief Sets properties from a structure, ignores invalid properties
		%>
		%> @param args input structure
		% ===================================================================
		function parseArgs(obj,args)
			allowedProperties = ['^(' obj.allowedProperties ')$'];
			while iscell(args) && length(args) == 1
				args = args{1};
			end
			if iscell(args)
				if mod(length(args),2) == 1 % odd
					args = args(1:end-1); %remove last arg
				end
				odd = logical(mod(1:length(args),2));
				even = logical(abs(odd-1));
				args = cell2struct(args(even),args(odd),2);
			end
			fnames = fieldnames(args); %find our argument names
			for i=1:length(fnames);
				if regexp(fnames{i},allowedProperties) %only set if allowed property
					obj.salutation(fnames{i},'Configuring setting in constructor');
					obj.(fnames{i})=args.(fnames{i}); %we set up the properies from the arguments as a structure
				end
			end
		end
		
		% ===================================================================
		%> @brief describeStimulus Simply returns a text string with the
		%>   info about the stimulus
		%>
		%> @return t a string with the info
		% ===================================================================
		function t = describeStimulus(obj)
			t='';
			if ~isempty(obj.stimulus)
				a = 1;
				s=obj.stimulus;
				for i = 1:s.stimuli.n
					t{a} = ['Stimulus' num2str(i) ': ' s.stimuli{i}.family];
					a = a + 1;
				end
				for i = 1: s.task.nVar
					t{a} = ['Variable' num2str(i) ': ' s.task.nVar(i).name];
					a = a + 1;
				end
			end
		end
		
		
	end
	
	methods (Static)
		% ===================================================================
		%> @brief load object method
		%>
		% ===================================================================
		function lobj=loadobj(in)
			fprintf('Loading opxOnline object...\n')
			in.cleanup=1;
			if isa(in.conn,'dataConnection')
				in.conn.cleanup=0;
			end
			if isa(in.conn,'dataConnection')
				in.msconn.cleanup=0;
			end
			lobj=in;
		end
		
		% ===================================================================
		%> @brief save object method
		%>
		% ===================================================================
		function sobj=saveobj(in)
			fprintf('Saving opxOnline object...\n')
			sobj=in;
		end
	end
end


