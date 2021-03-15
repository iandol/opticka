% ======================================================================
%> @brief Opticka stimulus generator GUI
%>
%> Opticka is an object oriented stimulus generator based on Psychophysics toolbox
%> See http://iandol.github.com/opticka/ for more details. This class builds the %> main GUI.
% ======================================================================
classdef opticka < optickaCore
	
	properties
		%> this is the main runExperiment object
		r runExperiment
		%> run in verbose mode?
		verbose = false
	end
	
	properties (SetAccess = public, GetAccess = public, Transient = true)
		%> general store for misc properties
		store struct = struct()
	end
	
	properties (SetAccess = protected, GetAccess = public, Transient = true)
		%> all of the handles to the opticka_ui GUI
		h struct
	end
	
	properties (SetAccess = protected, GetAccess = public)
		%> version number
		optickaVersion char = '1.20'
		%> history of display objects
		history
		%> is this a remote instance?
		remote = 0
		%> omniplex connection, via TCP
		oc
	end
	
	properties (SetAccess = private, GetAccess = private)
		%> used to sanitise passed values on construction
		allowedProperties char = 'verbose'
		%> which UI settings should be saved locally to the machine?
		uiPrefsList cell = {'OKOmniplexIP','OKMonitorDistance','OKpixelsPerCm',...
			'OKbackgroundColour','OKAntiAliasing','OKbitDepth','OKUseRetina',...
			'OKHideFlash','OKUsePhotoDiode','OKTrainingResearcherName',...
			'OKTrainingName','OKarduinoPort','OKdPPMode','OKDummyMode'}
	end
	
	%=======================================================================
	methods %------------------PUBLIC METHODS
	%=======================================================================
	
		% ===================================================================
		%> @brief Class constructor
		%>
		%> @param varargin are passed as a structure of properties which is
		%> parsed.
		%> @return instance of opticka class.
		% ===================================================================
		function me = opticka(varargin)
			if nargin == 0; varargin.name = 'opticka'; end
			me=me@optickaCore(varargin); %superclass constructor
			if nargin>0
				me.parseArgs(varargin, me.allowedProperties);
			end
			if me.cloning == false
				me.initialiseUI;
			end
		end
		
		% ===================================================================
		%> @brief Route calls to private methods
		%>
		%> @param in switch to route to correct method.
		%> @param vars additional vars to pass.
		% ===================================================================
		function router(me,in,vars)
			if ~exist('vars','var')
				vars=[];
			end
			switch in
				case 'saveData'
					me.saveData();
				case 'saveProtocol'
					me.saveProtocol();
				case 'loadProtocol'
					me.loadProtocol(vars);
				case 'deleteProtocol'
					me.deleteProtocol()
				case 'LoadStateInfo'
					me.loadStateInfo();
			end
		end
		
		% ===================================================================
		%> @brief Check if we are remote by checking existance of UI
		%>
		%> @param me self object
		% ===================================================================
		function amIRemote(me)
			if ~ishandle(me.h.output)
				me.remote = true;
			end
		end

		% ===================================================================
		%> @brief connectToOmniplex
		%> Gets the settings from the UI and connects to omniplex
		%> @param 
		% ===================================================================
		function connectToOmniplex(me)
			rPort = me.gn(me.h.OKOmniplexPort);
			rAddress = me.gs(me.h.OKOmniplexIP);
			status = me.ping(rAddress);
			if status > 0
				set(me.h.OKOmniplexStatus,'String','Omniplex: machine ping ERROR!')
					errordlg('Cannot ping Omniplex machine, please ensure it is connected!!!')
				error('Cannot ping Omniplex, please ensure it is connected!!!')
			end
			if isempty(me.oc)
				in = struct('verbosity',0,'rPort',rPort,'rAddress',rAddress,'protocol','tcp');
				me.oc = dataConnection(in);
			else
				me.oc.rPort = me.gn(me.h.OKOmniplexPort);
				me.oc.rAddress = me.gs(me.h.OKOmniplexIP);
			end
			if me.oc.checkStatus < 1
				loop = 1;
				while loop <= 10
					me.oc.close('conn',1);
					fprintf('\nTrying to connect...\n');
					me.oc.open;
					if me.oc.checkStatus > 0
						break
					end
					pause(0.1);
				end
				me.oc.write('--ping--');
				loop = 1;
				while loop < 8
					in = me.oc.read(0);
					fprintf('\n{opticka said: %s}\n',in)
					if regexpi(in,'(opened|ping)')
						fprintf('\nWe can ping omniplex master on try: %d\n',loop)
						set(me.h.OKOmniplexStatus,'String','Omniplex: connected via TCP')
						break
					else
						fprintf('\nOmniplex master not responding, try: %d\n',loop)
						set(me.h.OKOmniplexStatus,'String','Omniplex: not responding')
					end
					loop=loop+1;
					pause(0.2);
				end
				%drawnow;
			end
		end
		
		% ===================================================================
		%> @brief sendOmniplexStimulus
		%> Gets the settings from the UI and connects to omniplex
		%> @param 
		% ===================================================================
		function sendOmniplexStimulus(me,sendLog)
			if ~exist('sendLog','var')
				sendLog = false;
			end
			if me.oc.checkStatus > 0
				%flush read buffer
				data=me.oc.read('all');
				tLog=[];
				if me.oc.checkStatus > 0 %check again to make sure we are still open
					me.oc.write('--readStimulus--');
					pause(0.25);
					tic
					if sendLog == false
						if ~isempty(me.r.runLog);tLog = me.r.runLog;end
						me.r.deleteRunLog; %so we don't send too much data over TCP
					end
					tmpobj=me.r;
					me.oc.writeVar('o',tmpobj);
					if sendLog == false
						if ~isempty(tLog);me.r.restoreRunLog(tLog);end
					end
					fprintf('>>>Opticka: It took %g seconds to write and send stimulus to Omniplex machine\n',toc);
					loop = 1;
				while loop < 10
					in = me.oc.read(0);
					fprintf('\n{omniplex said: %s}\n',in)
					if regexpi(in,'(stimulusReceived)')
						set(me.h.OKOmniplexStatus,'String','Omniplex: connected+stimulus received')
						break
					elseif regexpi(in,'(stimulusFailed)')
						set(me.h.OKOmniplexStatus,'String','Omniplex: connected, stimulus ERROR!')
					end
					loop=loop+1;
					pause(0.2);
				end
				end
			end
		end
		
	end % END PUBLIC METHODS
	
	%========================================================
	methods (Hidden = true) %these have to be available publically, but lets hide them from obvious view
	%========================================================
		
		% ===================================================================
		%> @brief Start the UI
		%>
		%> @param 
		% ===================================================================
		function initialiseUI(me)
			try
				me.paths.whoami = mfilename;
				me.paths.whereami = fileparts(which(mfilename));
				me.paths.startServer = [me.paths.whereami filesep 'udpserver' filesep 'launchDataConnection'];

				if ismac
					me.store.serverCommand = ['!osascript -e ''tell application "Terminal"'' -e ''activate'' -e ''do script "matlab -nodesktop -r \"runServer\""'' -e ''end tell'''];
					me.paths.temp=tempdir;
					
					if ~exist(['~' filesep 'MatlabFiles' filesep 'Protocols'],'dir')
						mkdir(['~' filesep 'MatlabFiles' filesep 'Protocols']);
					end
					me.paths.protocols = ['~' filesep 'MatlabFiles' filesep 'Protocols'];
					cd(me.paths.protocols);
					me.paths.currentPath = pwd;
					
					if ~exist(['~' filesep 'MatlabFiles' filesep 'Calibration'],'dir')
						mkdir(['~' filesep 'MatlabFiles' filesep 'Calibration']);
					end
					me.paths.calibration = ['~' filesep 'MatlabFiles' filesep 'Calibration'];
					
					if ~exist([me.paths.temp 'History'],'dir')
						mkdir([me.paths.temp 'History']);
					end
					me.paths.historypath=[me.paths.temp 'History'];
					
					if ~exist(['~' filesep 'MatlabFiles' filesep 'SavedData'],'dir')
						mkdir(['~' filesep 'MatlabFiles' filesep 'SavedData']);
					end
					me.paths.savedData = ['~' filesep 'MatlabFiles' filesep 'SavedData'];
					
				elseif isunix
					me.store.serverCommand = '!matlab -nodesktop -nosplash -r "d=dataConnection(struct(''autoServer'',1,''lPort'',5678));" &';
					me.paths.temp=tempdir;
					if ~exist(['~' filesep 'MatlabFiles' filesep 'Protocols'],'dir')
						mkdir(['~' filesep 'MatlabFiles' filesep 'Protocols']);
					end
					me.paths.protocols = ['~' filesep 'MatlabFiles' filesep 'Protocols'];
					cd(me.paths.protocols);
					me.paths.currentPath = pwd;
					
					if ~exist(['~' filesep 'MatlabFiles' filesep 'Calibration'],'dir')
						mkdir(['~' filesep 'MatlabFiles' filesep 'Calibration']);
					end
					me.paths.calibration = ['~' filesep 'MatlabFiles' filesep 'Calibration'];
					
					if ~exist([me.paths.temp 'History'],'dir')
						mkdir([me.paths.temp 'History']);
					end
					me.paths.historypath=[me.paths.temp 'History'];
					
					if ~exist(['~' filesep 'MatlabFiles' filesep 'SavedData'],'dir')
						mkdir(['~' filesep 'MatlabFiles' filesep 'SavedData']);
					end
					me.paths.savedData = ['~' filesep 'MatlabFiles' filesep 'SavedData'];
				
				elseif ispc
					root = me.paths.parent;
					me.store.serverCommand = '!matlab -nodesktop -nosplash -r "d=dataConnection(struct(''autoServer'',1,''lPort'',5678));" &';
					me.paths.temp=tempdir;
					
					if ~exist([root 'Protocols'],'dir')
						mkdir([root 'Protocols'])
					end
					me.paths.protocols = [root 'Protocols'];
					cd(me.paths.protocols);
					me.paths.currentPath = pwd;
					
					if ~exist([root 'Calibration'],'dir')
						mkdir([root 'Calibration'])
					end
					me.paths.calibration = [root 'Calibration'];
					
					if ~exist([root 'History'],'dir')
						mkdir([root 'History']);
					end
					me.paths.historypath=[root 'History'];
					
					if ~exist([root 'SavedData'],'dir')
						mkdir([root 'SavedData']);
					end
					me.paths.savedData = [root 'SavedData'];
				end

				uihandle = opticka_ui; %our GUI file
				me.centerGUI(uihandle);
				me.h=guidata(uihandle);
				guidata(uihandle,me.h); %save back this change
				setappdata(me.h.output,'o',me); %we stash our object in the root appdata store for retirieval from the UI
				set(me.h.OKOptickaVersion,'String','Initialising GUI, please wait...');
				set(me.h.OKRoot,'Name',['Opticka Stimulus Generator V' me.optickaVersion]);
				drawnow;
					
				me.loadPrefs();
				me.getScreenVals();
				me.getTaskVals();
				me.loadCalibration();
				me.refreshProtocolsList();
				
				%addlistener(me.r,'abortRun',@me.abortRunEvent);
				%addlistener(me.r,'endAllRuns',@me.endRunEvent);
				%addlistener(me.r,'runInfo',@me.runInfoEvent);
				
				if exist([me.paths.protocols filesep 'DefaultStateInfo.m'],'file')
					me.paths.stateInfoFile = [me.paths.protocols filesep 'DefaultStateInfo.m'];
					me.r.stateInfoFile = me.paths.stateInfoFile;
				else
					me.paths.stateInfoFile = [me.paths.whereami filesep 'DefaultStateInfo.m'];
					me.r.stateInfoFile = me.paths.stateInfoFile;
				end
				
				me.h.OKTrainingResearcherName.String = me.r.researcherName;
				me.h.OKTrainingName.String = me.r.subjectName;
				getStateInfo(me);

				set(me.h.OKVarList,'String','');
				set(me.h.OKStimList,'String','');
				set(me.h.OKOptickaVersion,'String',['Opticka Stimulus Generator V' me.optickaVersion]);
				
			catch ME
				if  isfield(me.h,'output') && ~isempty(me.h.output) && isappdata(me.h.output,'o')
					rmappdata(me.h.output,'o');
					clear o;
				end
				if isfield(me.h,'output'); close(me.h.output); end
				errordlg('Problem initialising Opticka UI, please check errors on the commandline!')
				rethrow(ME)
			end
			
		end
		
		% ===================================================================
		%> @brief getScreenVals
		%> Gets the settings from the UI and updates our runExperiment object
		%> @param 
		% ===================================================================
		function getScreenVals(me)
			
			if isempty(me.r)
				olds = get(me.h.OKOptickaVersion,'String');
				set(me.h.OKOptickaVersion,'String','Initialising Stimulus and Task objects...')
				%drawnow
				me.r = runExperiment();
				initialise(me.r); % set up the runExperiment object
				s=cell(me.r.screen.maxScreen+1,1);
				for i=0:me.r.screen.maxScreen
					s{i+1} = num2str(i);
				end
				set(me.h.OKSelectScreen,'String', s);
				set(me.h.OKSelectScreen, 'Value', me.r.screen.screen+1);
				clear s;
				set(me.h.OKOptickaVersion,'String',olds)
			end
			
			me.r.screenSettings.optickahandle = me.h.output;
			
			me.r.screen.screen = me.gv(me.h.OKSelectScreen)-1;
			
			me.r.screen.distance = me.gd(me.h.OKMonitorDistance);
			me.r.screen.pixelsPerCm = me.gd(me.h.OKpixelsPerCm);
			me.r.screen.screenXOffset = me.gd(me.h.OKscreenXOffset);
			me.r.screen.screenYOffset = me.gd(me.h.OKscreenYOffset);
			
			value = me.gv(me.h.OKGLSrc);
			me.r.screen.srcMode = me.gs(me.h.OKGLSrc, value);
			
			value = me.gv(me.h.OKGLDst);
			me.r.screen.dstMode = me.gs(me.h.OKGLDst, value);
			
			value = me.gv(me.h.OKbitDepth);
			me.r.screen.bitDepth = me.gs(me.h.OKbitDepth, value);
			
			me.r.screen.blend = me.gv(me.h.OKOpenGLBlending);
			
			value = me.gv(me.h.OKUseGamma);
			if isprop(me.r.screen,'gammaTable') && isa(me.r.screen.gammaTable,'calibrateLuminance') && ~isempty(me.r.screen.gammaTable)
				me.r.screen.gammaTable.choice = value - 1;
			end
			
			s=str2num(get(me.h.OKWindowSize,'String')); %#ok<ST2NM>
			if isempty(s)
				me.r.screen.windowed = false;
			else
				me.r.screen.windowed = s;
			end
			
			me.r.logFrames = logical(me.gv(me.h.OKlogFrames));
			me.r.benchmark = logical(me.gv(me.h.OKbenchmark));
			me.r.screen.hideFlash = logical(me.gv(me.h.OKHideFlash));
			me.r.screen.useRetina = logical(me.gv(me.h.OKUseRetina));
			me.r.drawFixation = logical(me.gv(me.h.OKDrawFixation));
			me.r.dummyMode = logical(me.gv(me.h.OKDummyMode));
			if strcmpi(me.r.screen.bitDepth,'8bit')
				set(me.h.OKAntiAliasing,'String','0');
			end
			me.r.screen.antiAlias = me.gd(me.h.OKAntiAliasing);
			me.r.screen.photoDiode = logical(me.gv(me.h.OKUsePhotoDiode));
			me.r.screen.movieSettings.record = logical(me.gv(me.h.OKrecordMovie));
			me.r.verbose = logical(me.gv(me.h.OKVerbose)); %set method
			me.verbose = me.r.verbose;
			me.r.screen.debug = logical(me.gv(me.h.OKDebug));
			me.r.debug = me.r.screen.debug;
			me.r.screen.visualDebug = me.r.screen.debug;
			me.r.screen.backgroundColour = me.gn(me.h.OKbackgroundColour);
			%deprecated me.r.screen.nativeBeamPosition = logical(me.gv(me.h.OKNativeBeamPosition));
			
			if strcmpi(get(me.h.OKuseLabJackStrobe,'Checked'),'on')
				me.r.useLabJackStrobe = true;
			else
				me.r.useLabJackStrobe = false;
			end
			if strcmpi(get(me.h.OKuseLabJackReward,'Checked'),'on')
				me.r.useLabJackReward = true;
			else
				me.r.useLabJackReward = false;
			end
			if strcmpi(get(me.h.OKuseDataPixx,'Checked'),'on')
				me.r.useDataPixx = true;
			else
				me.r.useDataPixx = false;
			end
			if strcmpi(get(me.h.OKuseDisplayPP,'Checked'),'on')
				me.r.useDisplayPP = true;
				me.r.dPPMode = get(me.h.OKdPPMode,'String');
			else
				me.r.useDisplayPP = false;
			end
			if strcmpi(get(me.h.OKuseArduino,'Checked'),'on')
				me.r.useArduino = true;
				me.r.arduinoPort = get(me.h.OKarduinoPort,'String');
			else
				me.r.useArduino = false;
			end
			if strcmpi(get(me.h.OKuseEyelink,'Checked'),'on')
				me.r.useEyeLink = true;
				me.r.useTobii = false;
			else
				me.r.useEyeLink = false;
			end
			if strcmpi(get(me.h.OKuseTobii,'Checked'),'on')
				me.r.useEyeLink = false;
				me.r.useTobii = true;
			else
				me.r.useTobii = false;
			end
			if strcmpi(get(me.h.OKuseEyeOccluder,'Checked'),'on')
				me.r.useEyeOccluder = true;
			else
				me.r.useEyeOccluder = false;
			end
			
		end
		
		% ===================================================================
		%> @brief getTaskVals
		%> Gets the settings from th UI and updates our task object
		%> @param 
		% ===================================================================
		function getTaskVals(me)
			if isempty(me.r.task)
				me.r.task = stimulusSequence;
			end
			if isfield(me.r.screenVals,'fps')
				me.r.task.fps = me.r.screenVals.fps;
			end
			me.r.task.trialTime = me.gd(me.h.OKtrialTime);
			me.r.task.randomSeed = me.gn(me.h.OKRandomSeed);
			v = me.gv(me.h.OKrandomGenerator);
			me.r.task.randomGenerator = me.gs(me.h.OKrandomGenerator,v);
			me.r.task.ibTime = me.gn(me.h.OKibTime);
			me.r.task.randomise = logical(me.gv(me.h.OKRandomise));
			me.r.task.isTime = me.gn(me.h.OKisTime);
			me.r.task.nBlocks = me.gd(me.h.OKnBlocks);
			me.r.task.realTime = me.gv(me.h.OKrealTime);
			if isempty(me.r.task.taskStream); me.r.task.initialiseGenerator; end
			me.r.task.randomiseStimuli;
		end
		
		% ===================================================================
		%> @brief getStateInfo Load the training state info file into the UI
		%> 
		%> @param 
		% ===================================================================
		function getStateInfo(me)
			if ~isempty(me.r.paths.stateInfoFile) && ischar(me.r.paths.stateInfoFile)
				if ~exist(me.r.paths.stateInfoFile,'file')
					if ~isempty(regexpi(me.r.paths.stateInfoFile,'^\w:\\')) %is it a windows path?
						f = split(me.r.paths.stateInfoFile,'\');
						f = f{end};
					else
						[~,f,e] = fileparts(me.r.paths.stateInfoFile);
						f = [f e];
					end
					me.r.paths.stateInfoFile = [pwd filesep f];
				end
				if exist(me.r.paths.stateInfoFile,'file')
					fid = fopen(me.r.paths.stateInfoFile);
					tline = fgetl(fid);
					i=1;
					while ischar(tline)
						o.store.statetext{i} = tline;
						tline = fgetl(fid);
						i=i+1;
					end
					fclose(fid);
					set(me.h.OKTrainingText,'String',o.store.statetext);
					set(me.h.OKTrainingFileName,'String',['FileName:' me.r.paths.stateInfoFile]);
				else
					set(me.h.OKTrainingText,'String','');
					set(me.h.OKTrainingFileName,'String','No File Specified...');
				end
			end
		end
		
		% ===================================================================
		%> @brief clearStimulusList
		%> Erase any stimuli in the list.
		%> @param 
		% ===================================================================
		function clearStimulusList(me)
			if ~isempty(me.r)
				if ~isempty(me.r.stimuli)
					me.r.stimuli = metaStimulus();
				end
			end
			fn = fieldnames(me.store);
			for i = 1:length(fn)
				if isa(fn{i},'baseStimulus')
					closePanel(me.r.stimuli{i})
				end
			end
			ch = get(me.h.OKPanelStimulus,'Children');
			for i = 1:length(ch)
				if strcmpi(get(ch(i),'Type'),'uipanel')
					delete(ch(i))
				end
			end
			set(me.h.OKPanelStimulusText,'String','Stimulus Properties here...')
			set(me.h.OKStimList,'Value',1);
			set(me.h.OKStimList,'String','');			
		end
		
		% ===================================================================
		%> @brief getScreenVals
		%> Gets the settings from th UI and updates our runExperiment object
		%> @param 
		% ===================================================================
		function clearVariableList(me)
			if ~isempty(me.r)
				if ~isempty(me.r.task)
					me.r.task = [];
				end
			end
			set(me.h.OKVarList,'Value',1);
			set(me.h.OKVarList,'String','');
		end
		
		% ===================================================================
		%> @brief deleteStimulus
		%> 
		%> @param 
		% ===================================================================
		function deleteStimulus(me)
			if ~isempty(me.r.stimuli.n) && me.r.stimuli.n > 0
				v=me.gv(me.h.OKStimList);
				if isfield(me.store,'visibleStimulus');
					if strcmp(me.store.visibleStimulus.uuid,me.r.stimuli{v}.uuid)
						closePanel(me.r.stimuli{v})
					end
				end
				me.r.stimuli(v) = [];
				me.refreshStimulusList;
			else
				set(me.h.OKStimList,'Value',1);
				set(me.h.OKStimList,'String','');
			end
		end
		
		% ===================================================================
		%> @brief addStimulus
		%> Run when we've added a new stimulus
		%> @param 
		% ===================================================================
		function addStimulus(me)
			me.refreshStimulusList;
			nidx = me.r.stimuli.n;
			set(me.h.OKStimList,'Value',nidx);
			if isfield(me.store,'evnt') %delete our previous event
				delete(me.store.evnt);
				me.store = rmfield(me.store,'evnt');
			end
			me.store.evnt = addlistener(me.r.stimuli{nidx},'readPanelUpdate',@me.readPanel);
			if isfield(me.store,'visibleStimulus');
				me.store.visibleStimulus.closePanel();
			end
			makePanel(me.r.stimuli{nidx},me.h.OKPanelStimulus);
			me.store.visibleStimulus = me.r.stimuli{nidx};
		end
		
		% ===================================================================
		%> @brief readPanel
		%> 
		%> @param 
		% ===================================================================
		function readPanel(me,src,evnt)
			me.salutation('readPanel',['Triggered by: ' src.fullName],true);
			me.refreshStimulusList;
		end
		 
		% ===================================================================
		%> @brief editStimulus
		%> Gets the settings from the UI and updates our runExperiment object
		%> @param 
		% ===================================================================
		function editStimulus(me)
			if me.r.stimuli.n > 0
				skip = false;
				if ~isfield(me.store,'visibleStimulus') || ~isa(me.store.visibleStimulus,'baseStimulus')
					v = 1;
					me.store.visibleStimulus = me.r.stimuli{1};
				else
					v = get(me.h.OKStimList,'Value');
					if strcmpi(me.r.stimuli{v}.uuid,me.store.visibleStimulus.uuid)
						skip = false;
					end
				end
				if v <= me.r.stimuli.n && skip == false
					if isfield(me.store,'evnt')
						delete(me.store.evnt);
						me.store = rmfield(me.store,'evnt');
					end
					if isfield(me.store,'visibleStimulus') && isa(me.store.visibleStimulus,'baseStimulus')
						me.store.visibleStimulus.closePanel();
						me.store = rmfield(me.store,'visibleStimulus');
					end
					closePanel(me.r.stimuli{v});
					makePanel(me.r.stimuli{v},me.h.OKPanelStimulus);
					me.store.evnt = addlistener(me.r.stimuli{v},'readPanelUpdate',@me.readPanel);
					me.store.visibleStimulus = me.r.stimuli{v};
					me.refreshStimulusList;
				end
			end
		end
		
		% ===================================================================
		%> @brief editStimulus
		%> Gets the settings from th UI and updates our runExperiment object
		%> @param 
		% ===================================================================
		function modifyStimulus(me)
			me.refreshStimulusList;
		end
		
		% ===================================================================
		%> @brief addVariable
		%> Gets the settings from th UI and updates our runExperiment object
		%> @param 
		% ===================================================================
		function addVariable(me)		
			validate(me.r.task);
			revertN = me.r.task.nVars;
			try
				me.r.task.nVar(revertN+1).name = me.gs(me.h.OKVariableName);
				s = me.gs(me.h.OKVariableValues);
				if isempty(regexpi(s,'^\{'))
					me.r.task.nVar(revertN+1).values = str2num(s);
				else
					me.r.task.nVar(revertN+1).values = eval(s);
				end
				%me.r.task.nVar(revertN+1).values = me.gn(me.h.OKVariableValues);
				me.r.task.nVar(revertN+1).stimulus = me.gn(me.h.OKVariableStimuli);
				offset = me.gn(me.h.OKVariableOffset);
				if isempty(offset)
					me.r.task.nVar(revertN+1).offsetstimulus = [];
					me.r.task.nVar(revertN+1).offsetvalue = [];
				else
					me.r.task.nVar(revertN+1).offsetstimulus = offset(1);
					me.r.task.nVar(revertN+1).offsetvalue = offset(2);
				end
				validate(me.r.task);
				me.r.task.randomiseStimuli;

				me.refreshVariableList;
			
			catch ME
				getReport(ME)
				rethrow(ME);
			end
		end
		
		% ===================================================================
		%> @brief deleteVariable
		%> Gets the settings from the UI and updates our runExperiment object
		%> @param 
		% ===================================================================
		function deleteVariable(me)
			if isobject(me.r.task)
				nV = me.r.task.nVar;
				val = me.gv(me.h.OKVarList);
				if isempty(val);val=1;end %sometimes guide disables list, need workaround
				if val <= length(me.r.task.nVar);
					nV(val)=[];
					me.r.task.nVar = [];
					me.r.task.nVar = nV;
					if me.r.task.nVars > 0
						me.r.task.randomiseStimuli;
					end
				end
				me.refreshVariableList;
			end
		end
		
		% ===================================================================
		%> @brief editVariable
		%> Gets the settings from the UI and updates our runExperiment object
		%> @param 
		% ===================================================================
		function editVariable(me)
			
			if isobject(me.r.task)
				val = me.gv(me.h.OKVarList);
				set(me.h.OKVariableName,'String', me.r.task.nVar(val).name);
				v=me.r.task.nVar(val).values;
				if iscell(v)
					v = me.cell2str(v);
				else
					v = num2str(me.r.task.nVar(val).values);
				end
				str = v;
				str = regexprep(str,'\s+',' ');
				set(me.h.OKVariableValues,'String', str);
				str = num2str(me.r.task.nVar(val).stimulus);
				str = regexprep(str,'\s+',' ');
				set(me.h.OKVariableStimuli, 'String', str);
				str=[num2str(me.r.task.nVar(val).offsetstimulus) ';' num2str(me.r.task.nVar(val).offsetvalue)];
				set(me.h.OKVariableOffset,'String',str);
				me.deleteVariable
			end
			
		end
		
		% ===================================================================
		%> @brief copyVariable
		%> Gets the settings from the UI and updates our runExperiment object
		%> @param 
		% ===================================================================
		function copyVariable(me)
			if isobject(me.r.task)
				val = me.gv(me.h.OKVarList);
				me.r.task.nVar(end+1)=me.r.task.nVar(val);
				me.refreshVariableList;
			end
		end
		
		% ===================================================================
		%> @brief loadPrefs Load prefs better left local to the machine
		%> 
		% ===================================================================
		function loadCalibration(me)
			d = dir(me.paths.calibration);
			for i = 1:length(d)
				if isempty(regexp(d(i).name,'^\.+', 'once')) && d(i).isdir == false && d(i).bytes > 0
					ftime(i) = d(i).datenum;
				else
					ftime(i) = 0;
				end
			end
			if max(ftime) > 0
				[~,idx]=max(ftime);
				tmp = load([me.paths.calibration filesep d(idx).name]);
				if isstruct(tmp)
					fn = fieldnames(tmp);
					tmp = tmp.(fn{1});
				end
				if isa(tmp,'calibrateLuminance')
					tmp.filename = [me.paths.calibration filesep d(idx).name];
					if isa(me.r,'runExperiment') && isa(me.r.screen,'screenManager')
						me.r.screen.gammaTable = tmp;
						set(me.h.OKUseGamma,'Value',1);
						set(me.h.OKUseGamma,'String',['None'; 'Gamma'; me.r.screen.gammaTable.analysisMethods]);
						me.r.screen.gammaTable.choice = 2;
					end
				end
			end
		end
		
		% ===================================================================
		%> @brief loadPrefs Load prefs better left local to the machine
		%> 
		% ===================================================================
		function saveCalibration(me)
			if isa(me.r.screen.gammaTable,'calibrateLuminance')
				saveThis = true;
				tmp = me.r.screen.gammaTable;
				d = dir(me.paths.calibration);
				for i = 1:length(d)
					if isempty(regexp(d(i).name,'^\.+', 'once')) && d(i).isdir == false && d(i).bytes > 0
						if strcmp(d(i).name, tmp.filename)
							saveThis = false;
						end
					end
				end
				if saveThis == true
					save([me.paths.calibration filesep 'calibration-' date],'tmp');
				end
			end
		end
		
		% ===================================================================
		%> @brief loadPrefs Load prefs better left local to the machine
		%> 
		% ===================================================================
		function loadPrefs(me)
			for i = 1:length(me.uiPrefsList)
				prfname = me.uiPrefsList{i};
				if ispref('opticka',prfname) %pref exists
					if isfield(me.h, prfname) %ui widget exists
						myhandle = me.h.(prfname);
						prf = getpref('opticka',prfname);
						uiType = get(myhandle,'Style');
						switch uiType
							case 'edit'
								if ischar(prf)
									set(myhandle, 'String', prf);
								else
									set(myhandle, 'String', num2str(prf));
								end
							case 'checkbox'
								if islogical(prf) || isnumeric(prf)
									set(myhandle, 'Value', prf);
								end
							case 'popupmenu'
								str = get(myhandle,'String');
								if isnumeric(prf) && prf <= length(str)
									set(myhandle, 'Value', prf);
								end
						end
					end
				end	
			end
			%drawnow
		end
		
		% ===================================================================
		%> @brief savePrefs Save prefs better left local to the machine
		%> 
		% ===================================================================
		function savePrefs(me)
			for i = 1:length(me.uiPrefsList)
				prfname = me.uiPrefsList{i};
				myhandle = me.h.(prfname);
				uiType = get(myhandle,'Style');
				switch uiType
					case 'edit'
						prf = get(myhandle, 'String');
						setpref('opticka', prfname, prf);
					case 'checkbox'
						prf = get(myhandle, 'Value');
						if ~islogical(prf); prf=logical(prf);end
						setpref('opticka', prfname, prf);
					case 'popupmenu'
						prf = get(myhandle, 'Value');
						setpref('opticka', prfname, prf);
				end
			end
			fprintf('>>> Opticka saved its preferences...\n');
		end
		
	end
	
	%========================================================
	methods ( Access = private ) %----------PRIVATE METHODS
	%========================================================
		
		% ===================================================================
		%> @brief Delete Protocol
		%> Delete Protocol
		%> @param 
		% ===================================================================
		function deleteProtocol(me)
			v = me.gv(me.h.OKProtocolsList);
			file = me.gs(me.h.OKProtocolsList,v);
			me.paths.currentPath = pwd;
			cd(me.paths.protocols);
			out=questdlg(['Are you sure you want to delete ' file '?'],'Protocol Delete');
			if strcmpi(out,'yes')
				delete(file);
			end
			me.refreshProtocolsList;
			cd(me.paths.currentPath);
		end
		
		% ===================================================================
		%> @brief Save Protocol
		%> Save Protocol
		%> @param 
		% ===================================================================
		function saveProtocol(me)
			me.paths.currentPath = pwd;
			cd(me.paths.protocols);
			[f,p] = uiputfile('*.mat','Save Opticka Protocol','Protocol.mat');
			if f ~= 0
				cd(p);
				tmp = clone(me);
				tmp.name = f;
				tmp.r.name = f;
				tmp.r.paths.stateInfoFile = me.r.paths.stateInfoFile;
				tmp.store = struct(); %lets just nuke this incase some rogue handles are lurking
				tmp.h = struct(); %remove the handles to the UI which will not be valid on reload
				if isfield(tmp.r.screenSettings,'optickahandle'); tmp.r.screenSettings.optickahandle = []; end %!!!this fixes matlab bug 01255186
				for i = 1:tmp.r.stimuli.n
					cleanHandles(tmp.r.stimuli{i}); %just in case!
				end
				save(f,'tmp'); %this is the original code -- MAT CRASH on load, it is the same if i save me directly or the cloned variant tmp
				me.refreshStimulusList;
				me.refreshVariableList;
				me.refreshProtocolsList;
				clear tmp f p
			end
			cd(me.paths.currentPath);
		end
		
		% ===================================================================
		%> @brief Save Data
		%> Save Data
		%> @param 
		% ===================================================================
		function saveData(me)
			me.paths.currentPath = pwd;
			cd(me.paths.savedData);
			[f,p] = uiputfile('*.mat','Save Last Run Data','Data.mat');
			if f ~= 0
				cd(p);
				data = clone(me);
				data.r.paths.stateInfoFile = me.r.paths.stateInfoFile;
				data.h = struct(); %remove the handles to the UI which will not be valid on reload
				if isfield(data.r.screenSettings,'optickahandle'); data.r.screenSettings.optickahandle = []; end %!!!this fixes matlab bug 01255186
				for i = 1:data.r.stimuli.n
					cleanHandles(data.r.stimuli{i}); %just in case!
				end
				save(f,'data'); %this is the original code -- MAT CRASH on load, it is the same if i save me directly or the cloned variant tmp
				me.refreshStimulusList;
				me.refreshVariableList;
				me.refreshProtocolsList;
				clear data f p
			end
			cd(me.paths.currentPath);
		end
		
		% ===================================================================
		%> @brief Load State Info 
		%> Save Protocol
		%> @param 
		% ===================================================================
		function loadStateInfo(me)
			me.paths.currentPath = pwd;
			cd(me.paths.protocols);
			[fname,fpath] = uigetfile({'.m'},'Load State Info file (.m)');
			if ~ischar(fname) || isempty(fname)
				disp('No file selected...')
				return
			end
			me.paths.stateInfoFile = [fpath fname];
			me.r.paths.stateInfoFile = me.paths.stateInfoFile;
		end
		
		% ===================================================================
		%> @brief Load State Info 
		%> Save Protocol
		%> @param 
		% ===================================================================
		%function delete(me)
			%fprintf('---> %s DESTRUCTOR CALLED <---\n',me.fullName)
		%end
		
		% ===================================================================
		%> @brief Load Protocol
		%> Load Protocol
		%> @param ui do we show a uiload dialog?
		% ===================================================================
		function loadProtocol(me,ui)
			
			if ~exist('ui','var') || isempty(ui);	ui = true; end
			me.paths.currentPath = pwd;

			if ui == true
				v = me.gv(me.h.OKProtocolsList);
				s = me.h.OKProtocolsList.String;
				if isempty(s)
					[file,p] = uigetfile('*.mat','Select an Opticka Protocol (saved as a .mat)');
				else
					file = s{v};
					p = me.paths.protocols;
				end
			else
				[file,p] = uigetfile('*.mat','Select an Opticka Protocol (saved as a .mat)'); %cd([me.paths.root filesep 'CoreProtocols'])
			end
			
			if isempty(file) | file == 0
				disp('No file specified...')
				return
			end
			cd(p);
			load(file);
			me.paths.protocols = p;
			
			me.comment = ['Prt: ' file];
			
			salutation(me,sprintf('Routing Protocol from %s to %s',tmp.fullName,me.fullName),[],true);
			
			if exist('tmp','var') && isa(tmp,'opticka')
				if isprop(tmp.r,'stimuli')
					if isa(tmp.r.stimuli,'metaStimulus')
						me.r.stimuli = tmp.r.stimuli;
					elseif iscell(tmp.r.stimuli)
						me.r.stimuli = metaStimulus();
						me.r.stimuli.stimuli = tmp.r.stimuli;
					else
						clear tmp;
						warndlg('Sorry, this protocol is appears to have no stimulus objects, please remake');
						error('No stimulus found in protocol!!!');
					end
				elseif isprop(tmp.r,'stimulus')
					if iscell(tmp.r.stimulus)
						me.r.stimuli = metaStimulus();
						me.r.stimuli.stimuli = tmp.r.stimulus;
					elseif isa(tmp.r.stimulus,'metaStimulus')
						me.r.stimuli = tmp.r.stimulus;
					end
				else
					clear tmp;
					warndlg('Sorry, this protocol is appears to have no stimulus objects, please remake');
					error('No stimulus found in protocol!!!');
				end
				
				%copy rE parameters
				if isa(tmp.r,'runExperiment')
					if strcmpi(me.r.name,'runExperiment')
						me.r.name = [tmp.r.comment];
					else
						me.r.name = [tmp.r.name];
					end
					if isfield(tmp.r.paths,'stateInfoFile')
						if ~exist(tmp.r.paths.stateInfoFile,'file')
							[~,f,e] = fileparts(tmp.r.paths.stateInfoFile);
							newfile = [pwd filesep f e];
							if exist(tmp.r.paths.stateInfoFile,'file')
								me.r.paths.stateInfoFile =newfile;
							else
								me.r.paths.stateInfoFile = tmp.r.paths.stateInfoFile;
							end
						else
							me.r.paths.stateInfoFile = tmp.r.paths.stateInfoFile;
							me.getStateInfo();
						end
					elseif isprop(me.r,'stateInfoFile') && isprop(tmp.r,'stateInfoFile')
						me.r.paths.stateInfoFile = tmp.r.stateInfoFile;
						if ~exist(me.r.paths.stateInfoFile,'file')
							me.r.paths.stateInfoFile=regexprep(tmp.r.stateInfoFile,'(.+)(.Code.opticka.+)','~$2','ignorecase','once');
						end							
						me.getStateInfo();
					end
					
					if isprop(tmp.r,'drawFixation');me.r.drawFixation=tmp.r.drawFixation;me.h.OKdrawFixation.Value=me.r.drawFixation;end
					if isprop(tmp.r,'dPPMode'); me.r.dPPMode = tmp.r.dPPMode; me.h.OKdPPMode.String=me.r.dPPMode;end
					if isprop(tmp.r,'subjectName');me.r.subjectName = tmp.r.subjectName;me.h.OKTrainingName.String = me.r.subjectName;end
					if isprop(tmp.r,'researcherName');me.r.researcherName = tmp.r.researcherName;me.h.OKTrainingResearcherName.String=me.r.researcherName;end
					
					me.h.OKuseLabJackStrobe.Checked = 'off';
					me.h.OKuseDataPixx.Checked = 'off';
					me.h.OKuseDisplayPP.Checked = 'off';
					me.h.OKuseEyelink.Checked = 'off';
					me.h.OKuseTobii.Checked = 'on';
					me.h.OKuseLabJackReward.Checked = 'off';
					me.h.OKuseArduino.Checked = 'off';
					
					if isprop(tmp.r,'useDisplayPP'); me.r.useDisplayPP = tmp.r.useDisplayPP; end
					if me.r.useDisplayPP == true; me.h.OKuseDisplayPP.Checked = 'on'; end
					
					if isprop(tmp.r,'useDataPixx'); me.r.useDataPixx = tmp.r.useDataPixx; end
					if me.r.useDataPixx == true; me.h.OKuseDataPixx.Checked = 'on'; end
					
					if isprop(tmp.r,'useArduino'); me.r.useArduino = tmp.r.useArduino; end
					if me.r.useArduino == true; me.h.OKuseArduino.Checked = 'on'; end
					
					if isprop(tmp.r,'useEyeLink'); me.r.useEyeLink = tmp.r.useEyeLink; end
					if me.r.useEyeLink == true; me.h.OKuseEyelink.Checked = 'on'; me.h.OKuseTobii.Checked = 'off';end
					
					if isprop(tmp.r,'useTobii'); me.r.useTobii = tmp.r.useTobii; end
					if me.r.useTobii == true; me.h.OKuseTobii.Checked = 'on'; me.h.OKuseEyelink.Checked = 'off';end
				end
				
				%copy screen parameters
				if isa(tmp.r.screen,'screenManager')
					set(me.h.OKscreenXOffset,'String', num2str(tmp.r.screen.screenXOffset));
					set(me.h.OKscreenYOffset,'String', num2str(tmp.r.screen.screenYOffset));
					
					%set(me.h.OKNativeBeamPosition,'Value', tmp.r.screen.nativeBeamPosition);
					
					list = me.gs(me.h.OKGLSrc);
					val = me.findValue(list,tmp.r.screen.srcMode);
					me.r.screen.srcMode = list{val};
					set(me.h.OKGLSrc,'Value',val);
					
					list = me.gs(me.h.OKGLDst);
					val = me.findValue(list,tmp.r.screen.dstMode);
					me.r.screen.dstMode = list{val};
					set(me.h.OKGLDst,'Value',val);
					
					list = me.gs(me.h.OKbitDepth);
					val = me.findValue(list,tmp.r.screen.bitDepth);
					me.r.screen.bitDepth = list{val};
					set(me.h.OKbitDepth,'Value',val);
					
					set(me.h.OKOpenGLBlending,'Value', tmp.r.screen.blend);
					set(me.h.OKAntiAliasing,'String', num2str(tmp.r.screen.antiAlias));
					set(me.h.OKHideFlash,'Value', tmp.r.screen.hideFlash);
					set(me.h.OKUseRetina,'Value', tmp.r.screen.useRetina);
					string = num2str(tmp.r.screen.backgroundColour);
					string = regexprep(string,'\s+',' '); %collapse spaces
					set(me.h.OKbackgroundColour,'String',string);
				else
					me.salutation('No screenManager settings loaded!','',true);
				end
				%copy task parameters
				if isempty(tmp.r.task)
					me.r.task = stimulusSequence;
					me.r.task.randomiseStimuli;
				else
					me.r.task = tmp.r.task;
					for i=1:me.r.task.nVars
						if ~isfield(me.r.task.nVar(i),'offsetstimulus') %add these to older protocols that may not contain them
							me.r.task.nVar(i).offsetstimulus = [];
							me.r.task.nVar(i).offsetvalue = [];
						end
					end
				end
				
				set(me.h.OKtrialTime, 'String', num2str(me.r.task.trialTime));
				set(me.h.OKRandomSeed, 'String', num2str(me.r.task.randomSeed));
				set(me.h.OKisTime,'String',sprintf('%g ',me.r.task.isTime));
				set(me.h.OKibTime,'String',sprintf('%g ',me.r.task.ibTime));
				set(me.h.OKnBlocks,'String',num2str(me.r.task.nBlocks));
				
				me.getScreenVals;
				me.getTaskVals;
				me.refreshStimulusList;
				me.refreshVariableList;
				me.getScreenVals;
				me.getTaskVals;
				
				if me.r.task.nVars > 0
					set(me.h.OKDeleteVariable,'Enable','on');
					set(me.h.OKCopyVariable,'Enable','on');
					set(me.h.OKEditVariable,'Enable','on');
				end
				if me.r.stimuli.n > 0
					set(me.h.OKDeleteStimulus,'Enable','on');
					set(me.h.OKModifyStimulus,'Enable','on');
					set(me.h.OKInspectStimulus,'Enable','on');
					set(me.h.OKStimulusUp,'Enable','on');
					set(me.h.OKStimulusDown,'Enable','on');
					set(me.h.OKStimulusRun,'Enable','on');
					set(me.h.OKStimulusRunBenchmark,'Enable','on');
					set(me.h.OKStimulusRunAll,'Enable','on');
					set(me.h.OKStimulusRunAllBenchmark,'Enable','on');
					set(me.h.OKStimulusRunSingle,'Enable','on');
					me.store.visibleStimulus.uuid='';
					me.editStimulus;
				end
				
			end
			me.refreshProtocolsList;
			setappdata(me.h.output,'o',me);
		end
		
		% ======================================================================
		%> @brief Refresh the UI list of Protocols
		%> Refresh the UI list of Protocols
		%> @param
		% ======================================================================
		function refreshProtocolsList(me)
			
			set(me.h.OKProtocolsList,'String',{''});
			me.paths.currentPath = pwd;
			cd(me.paths.protocols);
			
			% Generate path based on given root directory
			files = dir(pwd);
			if isempty(files)
				set(me.h.OKProtocolsList,'String',{''});
				return
			end
			
			% set logical vector for subdirectory entries in d
			isdir = logical(cat(1,files.isdir));
			isfile = ~isdir;
			
			files = files(isfile); % select only directory entries from the current listing
			
			filelist=cell(0);
			for i=1:length(files)
				filename = files(i).name;
				if ~isempty(regexpi(filename,'\.mat$'))
					filelist{end+1} = filename;
				end
			end
			
			set(me.h.OKProtocolsList,'Value', 1);
			set(me.h.OKProtocolsList,'String',filelist);
			cd(me.paths.currentPath);
		end
		
		% ===================================================================
		%> @brief refreshStimulusList
		%> refreshes the stimulus list in the UI after add/remove new stimulus
		%> @param 
		% ===================================================================
		function refreshStimulusList(me)
			pos = get(me.h.OKStimList, 'Value');
			str = cell(me.r.stimuli.n,1);
			for i=1:me.r.stimuli.n
				s = me.r.stimuli{i};
				if isempty(s.name)
					name = s.family;
				else
					name = s.name;
				end
				switch s.family
					case 'grating'
						tstr = [num2str(i) '.' name ': '];
						tstr = [tstr ' x=' num2str(s.xPosition)];
						tstr = [tstr ' y=' num2str(s.yPosition)];
						tstr = [tstr ' c=' num2str(s.contrast)];
						tstr = [tstr ' a=' num2str(s.angle)];
						tstr = [tstr ' sz=' num2str(s.size)];
						tstr = [tstr ' sf=' num2str(s.sf)];
						tstr = [tstr ' tf=' num2str(s.tf)];
						tstr = [tstr ' p=' num2str(s.phase)];
						tstr = [tstr ' sg=' num2str(s.sigma)];
						str{i} = tstr;
					case 'gabor'
						tstr = [num2str(i) '.' name ': '];
						tstr = [tstr ' x=' num2str(s.xPosition)];
						tstr = [tstr ' y=' num2str(s.yPosition)];
						tstr = [tstr ' c=' num2str(s.contrast)];
						tstr = [tstr ' a=' num2str(s.angle)];
						tstr = [tstr ' sz=' num2str(s.size)];
						tstr = [tstr ' sf=' num2str(s.sf)];
						tstr = [tstr ' tf=' num2str(s.tf)];
						tstr = [tstr ' p=' num2str(s.phase)];
						str{i} = tstr;
					case 'bar'
						x=s.xPosition;
						y=s.yPosition;
						a=s.angle;
						str{i} = [num2str(i) '.' name ': x=' num2str(x) ' y=' num2str(y) ' ang=' num2str(a)];
					case 'dots'
						x=s.xPosition;
						y=s.yPosition;
						sz=s.size;
						a=s.angle;
						c=s.coherence;
						dn=s.density;
						sp=s.speed;
						k=s.kill;
						ct=s.colourType;
						str{i} = [num2str(i) '.' name ': x=' num2str(x) ' y=' num2str(y) ' sz=' num2str(sz) ' ang=' num2str(a) ' coh=' num2str(c) ' dn=' num2str(dn) ' sp=' num2str(sp) ' k=' num2str(k) ' ct=' ct];
					case 'ndots'
						x=s.xPosition;
						y=s.yPosition;
						sz=s.size;
						a=s.angle;
						c=s.coherence;
						dn=s.density;
						str{i} = [num2str(i) '.' name ': x=' num2str(x) ' y=' num2str(y) ' sz=' num2str(sz) ' ang=' num2str(a) ' coh=' num2str(c) ' dn=' num2str(dn)];
					case 'spot'
						x=s.xPosition;
						y=s.yPosition;
						sz=s.size;
						c=s.contrast;
						a=s.angle;
						str{i} = [num2str(i) '.' name ': x=' num2str(x) ' y=' num2str(y) ' sz=' num2str(sz) ' c=' num2str(c) ' ang=' num2str(a)];
					case 'texture'
						x=s.xPosition;
						y=s.yPosition;
						sz=s.size;
						c=s.contrast;
						sp=s.speed;
						p=s.fileName;
						str{i} = [num2str(i) '.' name ': x=' num2str(x) ' y=' num2str(y) ' sz=' num2str(sz) ' c=' num2str(c) ' sp=' num2str(sp) ' [' p ']'];
					case 'movie'
						x=s.xPosition;
						y=s.yPosition;
						sz=s.size;
						sp=s.speed;
						p=s.fileName;
						str{i} = [num2str(i) '.' name ': x=' num2str(x) ' y=' num2str(y) ' sz=' num2str(sz) ' sp=' num2str(sp) ' [' p ']'];
					otherwise
						x=s.xPosition;
						y=s.yPosition;
						a=s.angle;
						str{i} = [num2str(i) '.' name ': x=' num2str(x) ' y=' num2str(y) ' ang=' num2str(a)];
				end
			end
			if isempty(pos) || pos > length(str)
				pos = 1;
			end
			set(me.h.OKStimList,'String', str);
			set(me.h.OKStimList, 'Value', pos);
		end
		
		% ===================================================================
		%> @brief Refresh the Variable list in the UI
		%> 
		%> @param 
		% ===================================================================
		function refreshVariableList(me)
			pos = get(me.h.OKVarList, 'Value');
			str = cell(me.r.task.nVars,1);
			V = me.r.task.nVar;
			for i=1:me.r.task.nVars
				if iscell(V(i).values)
					v = me.cell2str(V(i).values);
				else
					v = num2str(V(i).values);
				end
				str{i} = [V(i).name ' on Stim: ' num2str(V(i).stimulus) '|' v];
				if isfield(V, 'offsetstimulus') && ~isempty(V(i).offsetstimulus)
					str{i} =  [str{i} ' | Stim ' num2str(V(i).offsetstimulus) ' offset:' num2str(V(i).offsetvalue)];
				end
				str{i}=regexprep(str{i},'\s+',' ');
			end
			set(me.h.OKVarList,'String',str);
			if pos > me.r.task.nVars
				pos = me.r.task.nVars;
			end
			if isempty(pos) || pos <= 0
				pos = 1;
			end
			set(me.h.OKVarList,'Value',pos);
		end
		
		% ===================================================================
		%> @brief find the value in a cell string list
		%> 
		%> @param 
		% ===================================================================
		function value = findValue(me,list,entry)
			value = 1;
			for i=1:length(list)
				if strcmpi(list{i},entry)
					value = i;
					return
				end
			end
		end
		
		% ===================================================================
		%> @brief Event triggered on abort
		%> 
		%> @param 
		% ===================================================================
		function value = abortRunEvent(me,src,evtdata)
			fprintf('---> Opticka: abortRun triggered!!!\n')
			if isa(me.oc,'dataConnection') && me.oc.isOpen == 1
				me.oc.write('--abort--');
			end
		end
		
		% ===================================================================
		%> @brief Event trigger on end
		%> 
		%> @param 
		% ===================================================================
		function value = endRunEvent(me,src,evtdata)
			fprintf('---> Opticka: endRun triggered!!!\n')
		end
		
		% ===================================================================
		%> @brief Event triggered on get info
		%> 
		%> @param 
		% ===================================================================
		function value = runInfoEvent(me,src,evtdata)
			fprintf('---> Opticka: runInfo triggered!!!\n')
		end
		
		% ===================================================================
		%> @brief fixUI Try to work around GUIDE OS X bugs
		%> 
		% ===================================================================
		function fixUI(me)
			ch = findall(me.h.output);
			set(me.h.output,'Units','pixels');
			for k = 1:length(ch)
				if isprop(ch(k),'Units')
					set(ch(k),'Units','pixels');
				end
				if isprop(ch(k),'FontName')
					set(ch(k),'FontName','verdana');
				end
			end
		end
		
		% ===================================================================
		%> @brief saveobj Our custom save method to prepare object for safe saving
		%> 
		%> @param me
		% ===================================================================
 		function sobj = saveobj(me)
 			sobj = me;
% 			if isfield(sobj.store,'evnt') %delete our previous event
% 				delete(sobj.store.evnt);
% 				sobj.store.evnt = [];
% 				sobj.store = rmfield(sobj.store,'evnt');
% 			end
% 			fn = fieldnames(sobj.store);
% 			for i=1:length(fn)
% 				if isa(sobj.store.(fn{i}),'baseStimulus')
% 					delete(sobj.store.(fn{i}));
% 					sobj.store.(fn{i}) = [];
% 					sobj.store = rmfield(sobj.store,fn{i});
% 				end
% 			end
% 			sobj.store.oldlook=[]; %need to remove this as java objects not supported for save in matlab
% 			sobj.oc = [];
 		end
		
	end
	
	%========================================================
	methods ( Static ) %----------Static METHODS
	%========================================================
	
		% ===================================================================
		%> @brief loadobj
		%> To be backwards compatible to older saved protocols, we have to parse 
		%> structures / objects specifically during object load
		%> @param in input object/structure
		% ===================================================================
		function lobj=loadobj(in)
			if isa(in,'opticka')
				fprintf('---> opticka loadobj: Assigning object...\n')
				lobj = in;
			else
				fprintf('---> opticka loadobj: Recreating object from structure...\n')
				lobj = opticka();
				lobj.r = in.r;
			end	
		end
		
		% ===================================================================
		%> @brief ping -- ping a network address
		%>	We send a single packet and wait only 10ms to ensure we have a fast connection
		%> @param rAddress remote address
		%> @return status is 0 if ping succeded
		% ===================================================================
		function [status, result] = ping(rAddress)
			if ~exist('rAddress','var')
				fprintf('status=opticka.ping(''IP'') = pings an IP address passed as a string\n')
				return
			end
			if ispc
				cmd = 'ping -n 1 -w 10 ';
			else
				cmd = 'ping -c 1 -W 10 ';
			end
			[status,result]=system([cmd rAddress]);
		end
		
		% ===================================================================
		%> @brief cell2str converts cell string to single string
		%> 
		%> @param in cell variable
		%> @return string
		% ===================================================================
		function str = cell2str(in)
			str = [];
			if iscell(in)
				str = '{';
				for i = 1:length(in)
					str = [str '[' num2str(in{i}) '],'];
				end
				str = regexprep(str,',$','}');
			end
		end
		% ===================================================================
		%> @brief gs (getstring)
		%> 
		%> @param inhandle handle to UI element
		%> @param value
		% ===================================================================
		function outhandle = gs(inhandle,value)
			if exist('value','var')
				s = get(inhandle,'String');
				outhandle = s{value};
			else
				outhandle = get(inhandle,'String');
			end
		end
		
		% ===================================================================
		%> @brief gd (getdouble)
		%> 
		%> @param inhandle handle to UI element
		% ===================================================================
		function outhandle = gd(inhandle)
		%quick alias to get double value
			outhandle = str2double(get(inhandle,'String'));
		end
		
		% ===================================================================
		%> @brief gn (getnumber)
		%> 
		%> @param inhandle handle to UI element
		% ===================================================================
		function outhandle = gn(inhandle)
		%quick alias to get number value
			outhandle = str2num(get(inhandle,'String')); %#ok<ST2NM>
		end
		
		% ===================================================================
		%> @brief gv (getvalue)
		%> 
		%> @param inhandle handle to UI element
		% ===================================================================
		function outhandle = gv(inhandle)
		%quick alias to get ui value
			outhandle = get(inhandle,'Value');
		end
		
		% ===================================================================
		%> @brief move GUI to center of screen
		%> 
		%> @param inhandle handle to UI element
		% ===================================================================
		function centerGUI(uihandle)
			pos=get(uihandle,'Position');
			size=[pos(3) pos(4)];
			scr=get(0,'ScreenSize');
			width=scr(3);
			height=scr(4);
			x=(width/2)-(size(1)/2);
			y=(height/2)-((size(2)+40)/2);
			if x < 1; x=0; end
			if y < 1; y=0; end
			set(uihandle,'Position',[x y size(1) size(2)]);
		end
		
		% ===================================================================
		%> @brief position and size figure
		%> 
		%> 
		% ===================================================================
		function resizeFigure(position,size,mult)
			oldunits = get(gcf,'Units');
			set(gcf,'Units','pixels');
			if nargin<1 || isempty(position)
				position=1;
			end
			if nargin<2 || isempty(size)
				pos=get(gcf,'Position');
				size=[pos(3) pos(4)];
			end
			if nargin < 3
				mult=1;
			end
			if mult ~=1
				size = size .* mult;
			end

			scr=get(0,'ScreenSize');
			width=scr(3);
			height=scr(4);

			if size(1) > width;	size(1) = width;	end
			if size(2) > height;	size(2) = height;	end

			switch(position)
			case 2 %a third off
				x=(width/3)-(size(1)/2);
				y=(height/2)-(size(2)/2);
				if x < 1; x=0; end
				if y < 1; y=0; end
				set(gcf,'Position',[x y size(1) size(2)]);
			case 3 %full height
				size(2) = height;
				x=(width/3)-(size(1)/2);
				y=(height/2)-(size(2)/2);
				if x < 1; x=0; end
				if y < 1; y=0; end
				set(gcf,'Position',[x y size(1) size(2)]);
			case 4 %full width
				size(1) = width;
				x=(width/3)-(size(1)/2);
				y=(height/2)-(size(2)/2);
				if x < 1; x=0; end
				if y < 1; y=0; end
				set(gcf,'Position',[x y size(1) size(2)]);
			case 5 %full screen
				size(1) = width;
				size(2) = height;
				x=(width/3)-(size(1)/2);
				y=(height/2)-(size(2)/2);
				if x < 1; x=0; end
				if y < 1; y=0; end
				set(gcf,'Position',[x y size(1) size(2)]);
			otherwise %center it
				x=(width/2)-(size(1)/2);
				y=(height/2)-((size(2)+40)/2);
				if x < 1; x=0; end
				if y < 1; y=0; end
				set(gcf,'Position',[x y size(1) size(2)]);
			end
			set(gcf,'Units',oldunits);
		end
		
	end
end