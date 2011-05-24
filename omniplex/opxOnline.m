% ========================================================================
%> @brief LABJACK Connects and manages a LabJack U3-HV
%>
%> Connects and manages a LabJack U3-HV
%>
% ========================================================================
classdef opxOnline < handle
	properties
		type = 'launcher'
		eventStart = 257 %257 is any strobed event
		eventEnd = -255
		maxWait = 6000
		autoRun = 1
		isSlave = 0
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
	end
	
	properties (SetAccess = private, GetAccess = public)
		masterPort = 11111
		slavePort = 11112
		conn %listen connection
		msconn %master slave connection
		spikes %hold the sorted spikes
		nRuns = 0
		totalRuns = 0
		trial = []
		parameters = []
		units = []
		stimulus
		tmpFile
		data
		error
	end
	
	properties (SetAccess = private, GetAccess = public, Transient = true)
		isLooping = false
		opxConn %> connection to the omniplex
		isSlaveConnected = 0
		isMasterConnected = 0
		h %GUI handles
	end
	
	properties (SetAccess = private, GetAccess = private)
		allowedProperties='^(type|eventStart|eventEnd|protocol|rPort|rAddress|verbosity|cleanup)$'
		slaveCommand
		masterCommand
		oldcv = 0
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
				Screen('Preference', 'SuppressAllWarnings',1);
				Screen('Preference', 'Verbosity', 0);
				Screen('Preference', 'VisualDebugLevel',0);
				obj.masterCommand = '!matlab -nodesktop -nosplash -r "opxRunMaster" &';
				obj.slaveCommand =  '!matlab -nodesktop -nosplash -r "opxRunSlave" &';
			else
				obj.masterCommand = '!osascript -e ''tell application "Terminal"'' -e ''activate'' -e ''do script "matlab -nodesktop -nosplash -maci -r \"opxRunMaster\""'' -e ''end tell''';
				obj.slaveCommand = '!osascript -e ''tell application "Terminal"'' -e ''activate'' -e ''do script "matlab -nodesktop -nosplash -nojvm -maci -r \"opxRunSlave\""'' -e ''end tell''';
			end
			
			switch obj.type
				
				case 'master'
					
                    obj.spawnSlave;
					obj.initializeUI;
					
					if obj.isSlaveConnected == 0
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
										fprintf('We have the stimulus from opticka, waiting for GO!');
										set(obj.h.opxUIInfoBox,'String',['We have stimulus, nRuns= ' num2str(obj.totalRuns) ' | waiting for go...'])
									else
										fprintf('We have a stimulus from opticka, but it is malformed!');
										set(obj.h.opxUIInfoBox,'String',['We have stimulus, but it was malformed!'])
										obj.stimulus = [];
										obj.conn.write('--stimulusFailed--');
									end
									obj.initializePlot('stimulus')
									break
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
						pause(0.2)
					end
				end
				
				if obj.checkKeys
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
				if ~rem(loop,400);fprintf('\n');fprintf('quiver at %i',loop);obj.msconn.write('--abuse me do!--');end
				
				if obj.msconn.checkData
					data = obj.msconn.read(0);
					data = regexprep(data,'\n','');
					fprintf('\n{message:%s}',data);
					switch data
						
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
								pause(0.1);
								if obj.msconn.checkData
									obj.tmpFile = obj.msconn.read(0);
									fprintf('\nThe master tells me tmpFile= %s\n',obj.tmpFile);
									break
								end
								tloop = tloop + 1;
							end
							
						case '--eval--'
							tloop = 1;
							while tloop < 10
								pause(0.1);
								if obj.msconn.checkData
									command = obj.msconn.read(0);
									fprintf('\nThe master tells us to eval= %s\n',command);
									eval(command);
									break
								end
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
				if obj.msconn.checkStatus('conn') < 1 %have we disconnected?
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
		%> @brief The main loop the master runs to load data saved by slave
		%> and then plot it lazily
		%>
		%>
		% ===================================================================
		function parseData(obj)
			loop = 1;
			obj.isLooping = true;
			abort = 0;
			opx=[];
			fprintf('\n\n===Parse Data Loop Starting===\n')
			while loop
				
				if ~rem(loop,40);fprintf('.');end
				if ~rem(loop,400);fprintf('\n');fprintf('ParseData:');end
				
				if obj.conn.checkData
					data = obj.conn.read(0);
					data = regexprep(data,'\n','');
					fprintf('\n{opticka message:%s}',data);
					switch data
						
						case '--ping--'
							obj.conn.write('--ping--');
							obj.msconn.write('--ping--');
							fprintf('\nOpticka pinged us, we ping opticka and slave!');

						case '--abort--'
							obj.msconn.write('--abort--');
							fprintf('\nOpticka asks us to abort, tell slave to stop too!');
							pause(0.3);
							abort = 1;
					end
				end
				
				if obj.msconn.checkData
					data = obj.msconn.read(0);
					fprintf('\n{Slave message:%s}',data);
					switch data
						
						case '--beforeRun--'
							load(obj.tmpFile);
							obj.units = opx.units;
							obj.parameters = opx.parameters;
							obj.data=parseOpxSpikes;
							obj.data.initialize(obj);
							obj.initializePlot;
							fprintf('\nSlave is about to run the main collection loop...');
							set(obj.h.opxUIInfoBox,'String','Omniplex about to start data collection, slave waiting...');
							clear opx
							
						case '--finishRun--'
							tloop = 1;
							while tloop < 10
								if obj.msconn.checkData
									obj.nRuns = double(obj.msconn.read(0,'uint32'));
									fprintf('\nThe slave has completed run %d\n',obj.nRuns);
									break
								end
								pause(0.05);
								tloop = tloop + 1;
							end
							load(obj.tmpFile);
							obj.trial = opx.trial;
							obj.data.parseNextRun(obj);
							obj.plotData;
							set(obj.h.opxUIInfoBox,'String',['The slave has completed run ' num2str(obj.nRuns)]);
							clear opx
							
						case '--finishAll--'
							load(obj.tmpFile);
							obj.trial = opx.trial;
							obj.plotData
							loop = 0;
							pause(0.2)
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
			tic
			abort=0;
			obj.nRuns = 0;
			
			status = obj.openPlexon;
			if status == -1
				abort = 1;
			end
			figure;
			ah=axes;
			
			obj.getParameters;
			obj.getnUnits;
			
			obj.trial = struct;
			obj.nRuns=1;
			obj.saveData;
			obj.msconn.write('--beforeRun--');
			pause(0.1);
			toc
			try
				while obj.nRuns <= obj.totalRuns && abort < 1
					PL_TrialDefine(obj.opxConn, obj.eventStart, obj.eventEnd, 0, 0, 0, 0, [1,2,3,4,5,6,7,8,9], [1], 0);
					fprintf('\nWaiting for run: %i\n', obj.nRuns);
					[rn, trial, spike, analog, last] = PL_TrialStatus(obj.opxConn, 3, obj.maxWait); %wait until end of trial
					tic
					if last > 0
						[obj.trial(obj.nRuns).ne, obj.trial(obj.nRuns).eventList]  = PL_TrialEvents(obj.opxConn, 0, 0);
						[obj.trial(obj.nRuns).ns, obj.trial(obj.nRuns).spikeList]  = PL_TrialSpikes(obj.opxConn, 0, 0);
						[~, ~, analogList] = PL_TrialAnalogSamples(obj.opxConn, 0, 0);
						obj.saveData;
						obj.msconn.write('--finishRun--');
						obj.msconn.write(uint32(obj.nRuns));
						obj.nRuns = obj.nRuns+1;
					end
					if obj.msconn.checkData
						command = obj.msconn.read(0);
						switch command
							case '--abort--'
								fprintf('\nWe''ve been asked to abort\n')
								abort = 1;
								break
							case '--ping--'
								fprintf('\nMaster pinged, we ping back...\n')
								obj.msconn.write('--ping--')
						end
					end
					if obj.checkKeys
						break
					end
					toc
					if exist('analogList','var');plot(ah,analogList);axis tight;title('Raw Analog Signal');end
					fprintf('rn: %i tr: %i sp: %i al: %i lst: %i\n',rn, trial, spike, analog, last);
				end
				obj.saveData; %final save of data
				if abort == 1
					obj.msconn.write('--finishAbort--');
				else
					obj.msconn.write('--finishAll--');
				end
				obj.msconn.write(uint32(obj.nRuns));
				% you need to call PL_Close(s) to close the connection
				% with the Plexon server
				obj.closePlexon;
				obj.listenSlave;
				
			catch ME
				obj.error = ME;
				fprintf('There was some error during data collection by slave!\n');
				fprintf('Error message: %s\n',obj.error.message);
				fprintf('Line: %d ',obj.error.stack.line);
				obj.nRuns = 0;
				obj.closePlexon;
				obj.listenSlave;
			end
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
			fprintf('Plotting data from cell: %d\n',cv)
			xmax = str2num(get(obj.h.opxUIEdit1,'String'));
			ymax = str2num(get(obj.h.opxUIEdit2,'String'));
			binWidth = str2num(get(obj.h.opxUIEdit3,'String'));
			if isempty(binWidth);binWidth = 25;end
			bins = round((obj.data.trialTime*1000) / binWidth);
			if isempty(xmax);xmax=2;end
			if isempty(ymax);ymax=50;end
			if isempty(zval);zval=1;end
			
			matrixSize = obj.data.matrixSize;
			offset = matrixSize*(zval-1);
			map = cell2mat(obj.data.unit{cv}.map(:,:,zval));  %maps our index to our display matrix
			map = map'; %remember subplot indexes by rows have to transform matrix first
			
			try
				if (obj.replotFlag == 1 || (cv ~= obj.oldcv) || method == 2)
					subplot(1,1,1,'Parent',obj.h.opxUIPanel)
					switch method
						case 1
							pos = 1;
							startP = 1 + offset;
							endP = matrixSize + offset;
							fprintf('Plotting all points...\n');
							for i = startP:endP
								[x,y,z]=selectIndex(map(pos));
								data = obj.data.unit{cv}.raw{y,x,zval};
								nt = obj.data.unit{cv}.trials{y,x,zval};
								varlabel = [num2str(obj.data.unit{cv}.map{y,x,zval}) ': ' obj.data.unit{cv}.label{y,x,zval}];
								selectPlot(obj.data.xLength,obj.data.yLength,pos,'subplot');
								plotPSTH()
								pos = pos + 1;
							end
						case 2
							fprintf('Plotting Curve: (x=all y=%d z=%d)\n',yval,zval);
							data = obj.data.unit{cv}.trialsums(yval,:,zval);
							plotCurve();
					end
				else %single subplot
					thisRun = obj.data.thisRun;
					index = obj.data.thisIndex;
					fprintf('DEBUG: %d / %d\n',thisRun,index)
					[x,y,z]=selectIndex(index);
					if z == zval %our displayed z value is in the indexed position
						fprintf('Plotting run: %d (x=%d y=%d z=%d)\n',thisRun,x,y,z)
						plotIndex=find(map==index);
						data = obj.data.unit{cv}.raw{y,x,z};
						nt = obj.data.unit{1}.trials{y,x,z};
						varlabel = [num2str(obj.data.unit{cv}.map{y,x,z}) ': ' obj.data.unit{cv}.label{y,x,z}];
						selectPlot(obj.data.xLength,obj.data.yLength,plotIndex,'subplot');
						switch method
							case 1
								plotPSTH(thisRun)
							case 2
								plotCurve(y,z)
							case 3

						end
					else
						fprintf('Plot Not Visible: %d (x=%d y=%d z=%d)\n',thisRun,x,y,z)
					end
				end
			catch ME
				obj.error = ME;
				fprintf('Plot Error message: %s\n',obj.error.message);
				fprintf('Line: %d ',obj.error.stack.line);
			end
			drawnow;
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
			function selectPlot(inx,iny,inpos,method)
				margins=0.06;
				if ~exist('method','var')
					method = 'subplot';
				end
				switch method
					case 'subplot'
						subplot(iny,inx,inpos,'Parent',obj.h.opxUIPanel)
					case 'subplot_tight'
						subplot_tight(iny,inx,inpos,margins,'Parent',obj.h.opxUIPanel)
					case 'subaxis'
						
				end
				
			end
			
			% ===================================================================
			%> @brief Plots PSTH (inline function of plotData)
			% ===================================================================
			function plotPSTH(inRun)
				[n,t]=hist(data,bins);
				n=convertToHz(n);
				bar(t,n)
				title(['Cell: ' num2str(cv) ' | Trials: ' num2str(nt) ' | Var: ' varlabel],'FontSize',6);
				axis([0 xmax 0 ymax]);
				set(gca,'FontSize',6);
				h = findobj(gca,'Type','patch');
				if exist('inRun','var')
					set(h,'FaceColor',[0.4 0 0],'EdgeColor',[0 0 0]);
				else
					set(h,'FaceColor',[0 0 0],'EdgeColor',[0 0 0]);
				end
				
			end
			
			% ===================================================================
			%> @brief Plots Curve (inline function of plotData)
			% ===================================================================
			function plotCurve()
				for ii = 1:length(data)
					[mn(ii),er(ii)]=stderr(data{ii});
				end
				
				areabar(obj.data.xValues',mn',er',[0.8 0.8 0.8],'k.-');
				xlabel(obj.stimulus.task.nVar(1).name)
				ylabel('Spikes / Stimulus');
			end
			
			% ===================================================================
			%> @brief Converts to spikes per second (inline function of plotData)
			% ===================================================================
			function out = convertToHz(inn)
				out=(inn/nt)*(1000/binWidth);
			end
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
			if ~isstruct(obj.h) || ~ishandle(obj.h.uihandle)
				obj.initializeUI;
			end
			try
				if strcmpi(type,'all')
					setStimulusValues();
					setCellValues();
				elseif strcmpi(type,'stimulus')
					setStimulusValues();
				end
				obj.replotFlag = 1;
			catch ME
				obj.error = ME;
				fprintf('Initialize Plot Error message: %s\n',obj.error.message);
				fprintf('Line: %d ',obj.error.stack.line);
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
		%> @brief Saves a reduced set of our object as a structure
		%>
		%>
		% ===================================================================
		function saveData(obj)
			try
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
			catch ME
				obj.error = ME;
				fprintf('There was some error during data collection + save data by slave!\n');
				fprintf('Error message: %s\n',obj.error.message);
				fprintf('Line: %d ',obj.error.stack.line);
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
				obj.units.chlist = [obj.units.list{:}];
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
		%> @brief InitializeUI opens the UI and sets appdata
		%>
		%>
		% ===================================================================
		function initializeUI(obj)
			obj.h = [];
			uihandle=opx_ui; %our GUI file
			obj.h=guidata(uihandle);
			obj.h.uihandle = uihandle;
			setappdata(0,'opx',obj); %we stash our object in the root appdata store for retirieval from the UI
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
		%> @brief Destructor
		%>
		%>
		% ===================================================================
		function delete(obj)
			if obj.cleanup == 1
				setappdata(0,'opx',[])
				obj.salutation('opxOnline Delete Method','Cleaning up now...')
				obj.closeAll;
			else
				setappdata(0,'opx',[])
				obj.salutation('opxOnline Delete Method','Closing (no cleanup)...')
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
	end
	
	methods (Static)
		% ===================================================================
		%> @brief load object method
		%>
		%>
		% ===================================================================
		function lobj=loadobj(in)
			fprintf('Loading opxOnline object...\n')
			in.cleanup=0;
			if isa(in.conn,'dataConnection')
				in.conn.cleanup=0;
			end
			if isa(in.conn,'dataConnection')
				in.msconn.cleanup=0;
			end
			lobj=in;
		end
	end
end


