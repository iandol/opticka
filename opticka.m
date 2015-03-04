% ======================================================================
%> @brief Opticka stimulus generator class
%>
%> Opticka is an object oriented stimulus generator based on Psychophysics toolbox
%> See http://iandol.github.com/opticka/ for more details
% ======================================================================
classdef opticka < optickaCore
	
	properties
		%> this is the main runExperiment object
		r
		%> run in verbose mode?
		verbose = false
	end
	
	properties (SetAccess = public, GetAccess = public, Transient = true)
		%> general store for misc properties
		store@struct = struct()
	end
	
	properties (SetAccess = protected, GetAccess = public, Transient = true)
		%> all of the handles to the opticka_ui GUI
		h@struct
	end
	
	properties (SetAccess = protected, GetAccess = public)
		%> version number
		optickaVersion@char = '1.016'
		%> history of display objects
		history
		%> is this a remote instance?
		remote = 0
		%> omniplex connection, via TCP
		oc
	end
	
	properties (SetAccess = private, GetAccess = private)
		%> used to sanitise passed values on construction
		allowedProperties@char='verbose'
		%> which UI settings should be saved locally to the machine?
		uiPrefsList@cell = {'OKOmniplexIP','OKMonitorDistance','OKpixelsPerCm',...
			'OKbackgroundColour','OKAntiAliasing','OKbitDepth','OKTrainingResearcherName',...
			'OKTrainingName'};
	end
	
	events
		variableChange
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
		function obj = opticka(varargin)
			if nargin == 0; varargin.name = 'opticka'; end
			obj=obj@optickaCore(varargin); %superclass constructor
			if nargin>0
				obj.parseArgs(varargin, obj.allowedProperties);
			end
			if obj.cloning == false
				obj.initialiseUI;
			end
		end
		
		% ===================================================================
		%> @brief Route calls to private methods (yeah, I know...)
		%>
		%> @param in switch to route to correct method.
		%> @param vars additional vars to pass.
		% ===================================================================
		function router(obj,in,vars)
			if ~exist('vars','var')
				vars=[];
			end
			switch in
				case 'saveProtocol'
					obj.saveProtocol();
				case 'loadProtocol'
					obj.loadProtocol(vars);
				case 'deleteProtocol'
					obj.deleteProtocol()
				case 'LoadStateInfo'
					obj.loadStateInfo();
			end
		end
		
		% ===================================================================
		%> @brief Check if we are remote by checking existance of UI
		%>
		%> @param obj self object
		% ===================================================================
		function amIRemote(obj)
			if ~ishandle(obj.h.output)
				obj.remote = 1;
			end
		end

		% ===================================================================
		%> @brief connectToOmniplex
		%> Gets the settings from the UI and connects to omniplex
		%> @param 
		% ===================================================================
		function connectToOmniplex(obj)
			rPort = obj.gn(obj.h.OKOmniplexPort);
			rAddress = obj.gs(obj.h.OKOmniplexIP);
			status = obj.ping(rAddress);
			if status > 0
				set(obj.h.OKOmniplexStatus,'String','Omniplex: machine ping ERROR!')
					errordlg('Cannot ping Omniplex machine, please ensure it is connected!!!')
				error('Cannot ping Omniplex, please ensure it is connected!!!')
			end
			if isempty(obj.oc)
				in = struct('verbosity',0,'rPort',rPort,'rAddress',rAddress,'protocol','tcp');
				obj.oc = dataConnection(in);
			else
				obj.oc.rPort = obj.gn(obj.h.OKOmniplexPort);
				obj.oc.rAddress = obj.gs(obj.h.OKOmniplexIP);
			end
			if obj.oc.checkStatus < 1
				loop = 1;
				while loop <= 10
					obj.oc.close('conn',1);
					fprintf('\nTrying to connect...\n');
					obj.oc.open;
					if obj.oc.checkStatus > 0
						break
					end
					pause(0.1);
				end
				obj.oc.write('--ping--');
				loop = 1;
				while loop < 8
					in = obj.oc.read(0);
					fprintf('\n{opticka said: %s}\n',in)
					if regexpi(in,'(opened|ping)')
						fprintf('\nWe can ping omniplex master on try: %d\n',loop)
						set(obj.h.OKOmniplexStatus,'String','Omniplex: connected via TCP')
						break
					else
						fprintf('\nOmniplex master not responding, try: %d\n',loop)
						set(obj.h.OKOmniplexStatus,'String','Omniplex: not responding')
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
		function sendOmniplexStimulus(obj,sendLog)
			if ~exist('sendLog','var')
				sendLog = false;
			end
			if obj.oc.checkStatus > 0
				%flush read buffer
				data=obj.oc.read('all');
				tLog=[];
				if obj.oc.checkStatus > 0 %check again to make sure we are still open
					obj.oc.write('--readStimulus--');
					pause(0.25);
					tic
					if sendLog == false
						if ~isempty(obj.r.runLog);tLog = obj.r.runLog;end
						obj.r.deleteRunLog; %so we don't send too much data over TCP
					end
					tmpobj=obj.r;
					obj.oc.writeVar('o',tmpobj);
					if sendLog == false
						if ~isempty(tLog);obj.r.restoreRunLog(tLog);end
					end
					fprintf('>>>Opticka: It took %g seconds to write and send stimulus to Omniplex machine\n',toc);
					loop = 1;
				while loop < 10
					in = obj.oc.read(0);
					fprintf('\n{omniplex said: %s}\n',in)
					if regexpi(in,'(stimulusReceived)')
						set(obj.h.OKOmniplexStatus,'String','Omniplex: connected+stimulus received')
						break
					elseif regexpi(in,'(stimulusFailed)')
						set(obj.h.OKOmniplexStatus,'String','Omniplex: connected, stimulus ERROR!')
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
		function initialiseUI(obj)
			try
				obj.paths.whoami = mfilename;
				obj.paths.whereami = fileparts(which(mfilename));
				obj.paths.startServer = [obj.paths.whereami filesep 'udpserver' filesep 'launchDataConnection'];

				if ismac
					obj.store.serverCommand = ['!osascript -e ''tell application "Terminal"'' -e ''activate'' -e ''do script "matlab -nodesktop -r \"runServer\""'' -e ''end tell'''];
					obj.paths.temp=tempdir;
					
					if ~exist(['~' filesep 'MatlabFiles' filesep 'Protocols'],'dir')
						mkdir(['~' filesep 'MatlabFiles' filesep 'Protocols']);
					end
					obj.paths.protocols = ['~' filesep 'MatlabFiles' filesep 'Protocols'];
					cd(obj.paths.protocols);
					obj.paths.currentPath = pwd;
					
					if ~exist(['~' filesep 'MatlabFiles' filesep 'Calibration'],'dir')
						mkdir(['~' filesep 'MatlabFiles' filesep 'Calibration']);
					end
					obj.paths.calibration = ['~' filesep 'MatlabFiles' filesep 'Calibration'];
					
					if ~exist([obj.paths.temp 'History'],'dir')
						mkdir([obj.paths.temp 'History']);
					end
					obj.paths.historypath=[obj.paths.temp 'History'];
					
					if ~exist(['~' filesep 'MatlabFiles' filesep 'SavedData'],'dir')
						mkdir(['~' filesep 'MatlabFiles' filesep 'SavedData']);
					end
					obj.paths.savedData = ['~' filesep 'MatlabFiles' filesep 'SavedData'];
					
				elseif isunix
					obj.store.serverCommand = '!matlab -nodesktop -nosplash -r "d=dataConnection(struct(''autoServer'',1,''lPort'',5678));" &';
					obj.paths.temp=tempdir;
					if ~exist(['~' filesep 'MatlabFiles' filesep 'Protocols'],'dir')
						mkdir(['~' filesep 'MatlabFiles' filesep 'Protocols']);
					end
					obj.paths.protocols = ['~' filesep 'MatlabFiles' filesep 'Protocols'];
					cd(obj.paths.protocols);
					obj.paths.currentPath = pwd;
					if ~exist(['~' filesep 'MatlabFiles' filesep 'Calibration'],'dir')
						mkdir(['~' filesep 'MatlabFiles' filesep 'Calibration']);
					end
					obj.paths.calibration = ['~' filesep 'MatlabFiles' filesep 'Calibration'];
					if ~exist([obj.paths.temp 'History'],'dir')
						mkdir([obj.paths.temp 'History']);
					end
					obj.paths.historypath=[obj.paths.temp 'History'];
					
					if ~exist(['~' filesep 'MatlabFiles' filesep 'SavedData'],'dir')
						mkdir(['~' filesep 'MatlabFiles' filesep 'SavedData']);
					end
					obj.paths.savedData = ['~' filesep 'MatlabFiles' filesep 'SavedData'];
				
				elseif ispc
					%root = 'c:\MatlabFiles';
					root = 'c:\Users\Guest\MatlabFiles\';
					obj.store.serverCommand = '!matlab -nodesktop -nosplash -r "d=dataConnection(struct(''autoServer'',1,''lPort'',5678));" &';
					obj.paths.temp=tempdir;
					if ~exist([root 'Protocols'],'dir')
						mkdir([root 'Protocols'])
					end
					obj.paths.protocols = [root 'Protocols'];
					cd(obj.paths.protocols);
					obj.paths.currentPath = pwd;
					if ~exist([root 'Calibration'],'dir')
						mkdir([root 'Calibration'])
					end
					obj.paths.calibration = [root 'Calibration'];
					if ~exist([root 'History'],'dir')
						mkdir([root 'History']);
					end
					obj.paths.historypath=[root 'History'];
					
					if ~exist([root 'SavedData'],'dir')
						mkdir([root 'SavedData']);
					end
					obj.paths.savedData = [root 'SavedData'];
				end

				uihandle = opticka_ui; %our GUI file
				obj.centerGUI(uihandle);
				obj.h=guidata(uihandle);
				guidata(uihandle,obj.h); %save back this change
				setappdata(obj.h.output,'o',obj); %we stash our object in the root appdata store for retirieval from the UI
				set(obj.h.OKOptickaVersion,'String','Initialising GUI, please wait...');
				set(obj.h.OKRoot,'Name',['Opticka Stimulus Generator V' obj.optickaVersion]);
				drawnow;
					
				obj.loadPrefs();
				obj.getScreenVals();
				obj.getTaskVals();
				obj.loadCalibration();
				obj.refreshProtocolsList();
				addlistener(obj.r,'abortRun',@obj.abortRunEvent);
				addlistener(obj.r,'endRun',@obj.endRunEvent);
				addlistener(obj.r,'runInfo',@obj.runInfoEvent);
				
				if exist([obj.paths.protocols filesep 'DefaultStateInfo.m'],'file')
					obj.paths.stateInfoFile = [obj.paths.protocols filesep 'DefaultStateInfo.m'];
					obj.r.stateInfoFile = obj.paths.stateInfoFile;
				else
					obj.paths.stateInfoFile = [obj.paths.whereami filesep 'DefaultStateInfo.m'];
					obj.r.stateInfoFile = obj.paths.stateInfoFile;
				end
				
				obj.h.OKTrainingResearcherName.String = obj.r.researcherName;
				obj.h.OKTrainingName.String = obj.r.subjectName;
				getStateInfo(obj);

				set(obj.h.OKVarList,'String','');
				set(obj.h.OKStimList,'String','');
				set(obj.h.OKOptickaVersion,'String',['Opticka Stimulus Generator V' obj.optickaVersion]);
				
			catch ME
				if  isfield(obj.h,'output') && ~isempty(obj.h.output) && isappdata(obj.h.output,'o')
					rmappdata(obj.h.output,'o');
					clear o;
				end
				if isfield(obj.h,'output'); close(obj.h.output); end
				errordlg('Problem initialising Opticka UI, please check errors on the commandline!')
				rethrow(ME)
			end
			
		end
		
		% ===================================================================
		%> @brief getScreenVals
		%> Gets the settings from the UI and updates our runExperiment object
		%> @param 
		% ===================================================================
		function getScreenVals(obj)
			
			if isempty(obj.r)
				olds = get(obj.h.OKOptickaVersion,'String');
				set(obj.h.OKOptickaVersion,'String','Initialising Stimulus and Task objects...')
				%drawnow
				obj.r = runExperiment();
				initialise(obj.r); % set up the runExperiment object
				s=cell(obj.r.screen.maxScreen+1,1);
				for i=0:obj.r.screen.maxScreen
					s{i+1} = num2str(i);
				end
				set(obj.h.OKSelectScreen,'String', s);
				set(obj.h.OKSelectScreen, 'Value', obj.r.screen.screen+1);
				clear s;
				set(obj.h.OKOptickaVersion,'String',olds)
			end
			
			obj.r.screenSettings.optickahandle = obj.h.output;
			
			obj.r.screen.screen = obj.gv(obj.h.OKSelectScreen)-1;
			
			obj.r.screen.distance = obj.gd(obj.h.OKMonitorDistance);
			obj.r.screen.pixelsPerCm = obj.gd(obj.h.OKpixelsPerCm);
			obj.r.screen.screenXOffset = obj.gd(obj.h.OKscreenXOffset);
			obj.r.screen.screenYOffset = obj.gd(obj.h.OKscreenYOffset);
			
			value = obj.gv(obj.h.OKGLSrc);
			obj.r.screen.srcMode = obj.gs(obj.h.OKGLSrc, value);
			
			value = obj.gv(obj.h.OKGLDst);
			obj.r.screen.dstMode = obj.gs(obj.h.OKGLDst, value);
			
			value = obj.gv(obj.h.OKbitDepth);
			obj.r.screen.bitDepth = obj.gs(obj.h.OKbitDepth, value);
			
			obj.r.screen.blend = obj.gv(obj.h.OKOpenGLBlending);
			
			value = obj.gv(obj.h.OKUseGamma);
			if isa(obj.r.screen.gammaTable,'calibrateLuminance')
				obj.r.screen.gammaTable.choice = value - 1;
			end
			
			s=str2num(get(obj.h.OKWindowSize,'String')); %#ok<ST2NM>
			if isempty(s)
				obj.r.screen.windowed = 0;
			else
				obj.r.screen.windowed = s;
			end
			
			obj.r.logFrames = logical(obj.gv(obj.h.OKlogFrames));
			obj.r.benchmark = logical(obj.gv(obj.h.OKbenchmark));
			obj.r.screen.hideFlash = logical(obj.gv(obj.h.OKHideFlash));
			if strcmpi(obj.r.screen.bitDepth,'8bit')
				set(obj.h.OKAntiAliasing,'String','0');
			end
			obj.r.screen.antiAlias = obj.gd(obj.h.OKAntiAliasing);
			obj.r.screen.photoDiode = logical(obj.gv(obj.h.OKUsePhotoDiode));
			obj.r.screen.movieSettings.record = logical(obj.gv(obj.h.OKrecordMovie));
			obj.r.verbose = logical(obj.gv(obj.h.OKVerbose)); %set method
			obj.verbose = obj.r.verbose;
			obj.r.screen.debug = logical(obj.gv(obj.h.OKDebug));
			obj.r.screen.visualDebug = logical(obj.gv(obj.h.OKDebug));
			obj.r.screen.backgroundColour = obj.gn(obj.h.OKbackgroundColour);
			obj.r.screen.nativeBeamPosition = logical(obj.gv(obj.h.OKNativeBeamPosition));
			
			if strcmpi(get(obj.h.OKuseLabJack,'Checked'),'on')
				obj.r.useLabJack = true;
			else
				obj.r.useLabJack = false;
			end
			if strcmpi(get(obj.h.OKuseDataPixx,'Checked'),'on')
				obj.r.useDataPixx = true;
			else
				obj.r.useDataPixx = false;
			end
			if strcmpi(get(obj.h.OKuseEyeLink,'Checked'),'on')
				obj.r.useEyeLink = true;
			else
				obj.r.useEyeLink = false;
			end
			
		end
		
		% ===================================================================
		%> @brief getTaskVals
		%> Gets the settings from th UI and updates our task object
		%> @param 
		% ===================================================================
		function getTaskVals(obj)
			if isempty(obj.r.task)
				obj.r.task = stimulusSequence;
			end
			if isfield(obj.r.screenVals,'fps')
				obj.r.task.fps = obj.r.screenVals.fps;
			end
			obj.r.task.trialTime = obj.gd(obj.h.OKtrialTime);
			obj.r.task.randomSeed = obj.gn(obj.h.OKRandomSeed);
			v = obj.gv(obj.h.OKrandomGenerator);
			obj.r.task.randomGenerator = obj.gs(obj.h.OKrandomGenerator,v);
			obj.r.task.ibTime = obj.gd(obj.h.OKitTime);
			obj.r.task.randomise = logical(obj.gv(obj.h.OKRandomise));
			obj.r.task.isTime = obj.gd(obj.h.OKisTime);
			obj.r.task.nBlocks = obj.gd(obj.h.OKnBlocks);
			obj.r.task.realTime = obj.gv(obj.h.OKrealTime);
			if isempty(obj.r.task.taskStream); obj.r.task.initialiseRandom; end
			obj.r.task.randomiseStimuli;
		end
		
		% ===================================================================
		%> @brief getStateInfo Load the training state info file into the UI
		%> 
		%> @param 
		% ===================================================================
		function getStateInfo(obj)
			if ~isempty(obj.r.paths.stateInfoFile) && ischar(obj.r.paths.stateInfoFile) && exist(obj.r.paths.stateInfoFile,'file')
				fid = fopen(obj.r.paths.stateInfoFile);
				tline = fgetl(fid);
				i=1;
				while ischar(tline)
					o.store.statetext{i} = tline;
					tline = fgetl(fid);
					i=i+1;
				end
				fclose(fid);
				set(obj.h.OKTrainingText,'String',o.store.statetext);
				set(obj.h.OKTrainingFileName,'String',['FileName:' obj.r.paths.stateInfoFile]);
			else
				set(obj.h.OKTrainingText,'String','');
				set(obj.h.OKTrainingFileName,'String','No File Specified...');
			end
		end
		
		% ===================================================================
		%> @brief clearStimulusList
		%> Erase any stimuli in the list.
		%> @param 
		% ===================================================================
		function clearStimulusList(obj)
			if ~isempty(obj.r)
				if ~isempty(obj.r.stimuli)
					obj.r.stimuli = metaStimulus();
				end
			end
			fn = fieldnames(obj.store);
			for i = 1:length(fn)
				if isa(fn{i},'baseStimulus')
					closePanel(obj.r.stimuli{i})
				end
			end
			ch = get(obj.h.OKPanelStimulus,'Children');
			for i = 1:length(ch)
				if strcmpi(get(ch(i),'Type'),'uipanel')
					delete(ch(i))
				end
			end
			set(obj.h.OKPanelStimulusText,'String','Stimulus Properties here...')
			set(obj.h.OKStimList,'Value',1);
			set(obj.h.OKStimList,'String','');			
		end
		
		% ===================================================================
		%> @brief getScreenVals
		%> Gets the settings from th UI and updates our runExperiment object
		%> @param 
		% ===================================================================
		function clearVariableList(obj)
			if ~isempty(obj.r)
				if ~isempty(obj.r.task)
					obj.r.task = [];
				end
			end
			set(obj.h.OKVarList,'Value',1);
			set(obj.h.OKVarList,'String','');
		end
		
		% ===================================================================
		%> @brief deleteStimulus
		%> 
		%> @param 
		% ===================================================================
		function deleteStimulus(obj)
			if ~isempty(obj.r.stimuli.n) && obj.r.stimuli.n > 0
				v=obj.gv(obj.h.OKStimList);
				if isfield(obj.store,'visibleStimulus');
					if strcmp(obj.store.visibleStimulus.uuid,obj.r.stimuli{v}.uuid)
						closePanel(obj.r.stimuli{v})
					end
				end
				obj.r.stimuli(v) = [];
				obj.refreshStimulusList;
			else
				set(obj.h.OKStimList,'Value',1);
				set(obj.h.OKStimList,'String','');
			end
		end
		
		% ===================================================================
		%> @brief addStimulus
		%> Run when we've added a new stimulus
		%> @param 
		% ===================================================================
		function addStimulus(obj)
			obj.refreshStimulusList;
			nidx = obj.r.stimuli.n;
			set(obj.h.OKStimList,'Value',nidx);
			if isfield(obj.store,'evnt') %delete our previous event
				delete(obj.store.evnt);
				obj.store = rmfield(obj.store,'evnt');
			end
			obj.store.evnt = addlistener(obj.r.stimuli{nidx},'readPanelUpdate',@obj.readPanel);
			if isfield(obj.store,'visibleStimulus');
				obj.store.visibleStimulus.closePanel();
			end
			makePanel(obj.r.stimuli{nidx},obj.h.OKPanelStimulus);
			obj.store.visibleStimulus = obj.r.stimuli{nidx};
		end
		
		% ===================================================================
		%> @brief readPanel
		%> 
		%> @param 
		% ===================================================================
		function readPanel(obj,src,evnt)
			obj.salutation('readPanel',['Triggered by: ' src.fullName],true);
			obj.refreshStimulusList;
		end
		 
		% ===================================================================
		%> @brief editStimulus
		%> Gets the settings from the UI and updates our runExperiment object
		%> @param 
		% ===================================================================
		function editStimulus(obj)
			if obj.r.stimuli.n > 0
				skip = false;
				if ~isfield(obj.store,'visibleStimulus') || ~isa(obj.store.visibleStimulus,'baseStimulus')
					v = 1;
					obj.store.visibleStimulus = obj.r.stimuli{1};
				else
					v = get(obj.h.OKStimList,'Value');
					if strcmpi(obj.r.stimuli{v}.uuid,obj.store.visibleStimulus.uuid)
						skip = false;
					end
				end
				if v <= obj.r.stimuli.n && skip == false
					if isfield(obj.store,'evnt')
						delete(obj.store.evnt);
						obj.store = rmfield(obj.store,'evnt');
					end
					if isfield(obj.store,'visibleStimulus') && isa(obj.store.visibleStimulus,'baseStimulus')
						obj.store.visibleStimulus.closePanel();
						obj.store = rmfield(obj.store,'visibleStimulus');
					end
					closePanel(obj.r.stimuli{v});
					makePanel(obj.r.stimuli{v},obj.h.OKPanelStimulus);
					obj.store.evnt = addlistener(obj.r.stimuli{v},'readPanelUpdate',@obj.readPanel);
					obj.store.visibleStimulus = obj.r.stimuli{v};
					obj.refreshStimulusList;
				end
			end
		end
		
		% ===================================================================
		%> @brief editStimulus
		%> Gets the settings from th UI and updates our runExperiment object
		%> @param 
		% ===================================================================
		function modifyStimulus(obj)
			obj.refreshStimulusList;
		end
		
		% ===================================================================
		%> @brief addVariable
		%> Gets the settings from th UI and updates our runExperiment object
		%> @param 
		% ===================================================================
		function addVariable(obj)		
			validate(obj.r.task);
			revertN = obj.r.task.nVars;
			try
				obj.r.task.nVar(revertN+1).name = obj.gs(obj.h.OKVariableName);
				s = obj.gs(obj.h.OKVariableValues);
				if isempty(regexpi(s,'^\{'))
					obj.r.task.nVar(revertN+1).values = str2num(s);
				else
					obj.r.task.nVar(revertN+1).values = eval(s);
				end
				obj.r.task.nVar(revertN+1).values = obj.gn(obj.h.OKVariableValues);
				obj.r.task.nVar(revertN+1).stimulus = obj.gn(obj.h.OKVariableStimuli);
				offset = obj.gn(obj.h.OKVariableOffset);
				if isempty(offset)
					obj.r.task.nVar(revertN+1).offsetstimulus = [];
					obj.r.task.nVar(revertN+1).offsetvalue = [];
				else
					obj.r.task.nVar(revertN+1).offsetstimulus = offset(1);
					obj.r.task.nVar(revertN+1).offsetvalue = offset(2);
				end
				validate(obj.r.task);
				obj.r.task.randomiseStimuli;

				obj.refreshVariableList;
			
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
		function deleteVariable(obj)
			if isobject(obj.r.task)
				nV = obj.r.task.nVar;
				val = obj.gv(obj.h.OKVarList);
				if isempty(val);val=1;end %sometimes guide disables list, need workaround
				if val <= length(obj.r.task.nVar);
					nV(val)=[];
					obj.r.task.nVar = [];
					obj.r.task.nVar = nV;
					if obj.r.task.nVars > 0
						obj.r.task.randomiseStimuli;
					end
				end
				obj.refreshVariableList;
			end
		end
		
		% ===================================================================
		%> @brief editVariable
		%> Gets the settings from the UI and updates our runExperiment object
		%> @param 
		% ===================================================================
		function editVariable(obj)
			
			if isobject(obj.r.task)
				val = obj.gv(obj.h.OKVarList);
				set(obj.h.OKVariableName,'String', obj.r.task.nVar(val).name);
				v=obj.r.task.nVar(val).values;
				if iscell(v)
					v = obj.cell2str(v);
				else
					v = num2str(obj.r.task.nVar(val).values);
				end
				str = v;
				str = regexprep(str,'\s+',' ');
				set(obj.h.OKVariableValues,'String', str);
				str = num2str(obj.r.task.nVar(val).stimulus);
				str = regexprep(str,'\s+',' ');
				set(obj.h.OKVariableStimuli, 'String', str);
				str=[num2str(obj.r.task.nVar(val).offsetstimulus) ';' num2str(obj.r.task.nVar(val).offsetvalue)];
				set(obj.h.OKVariableOffset,'String',str);
				obj.deleteVariable
			end
			
		end
		
		% ===================================================================
		%> @brief copyVariable
		%> Gets the settings from the UI and updates our runExperiment object
		%> @param 
		% ===================================================================
		function copyVariable(obj)
			if isobject(obj.r.task)
				val = obj.gv(obj.h.OKVarList);
				obj.r.task.nVar(end+1)=obj.r.task.nVar(val);
				obj.refreshVariableList;
			end
		end
		
		% ===================================================================
		%> @brief loadPrefs Load prefs better left local to the machine
		%> 
		% ===================================================================
		function loadCalibration(obj)
			d = dir(obj.paths.calibration);
			for i = 1:length(d)
				if isempty(regexp(d(i).name,'^\.+', 'once')) && d(i).isdir == false && d(i).bytes > 0
					ftime(i) = d(i).datenum;
				else
					ftime(i) = 0;
				end
			end
			if max(ftime) > 0
				[~,idx]=max(ftime);
				load([obj.paths.calibration filesep d(idx).name]);
				if isa(tmp,'calibrateLuminance')
					tmp.filename = [obj.paths.calibration filesep d(idx).name];
					if isa(obj.r,'runExperiment') && isa(obj.r.screen,'screenManager')
						obj.r.screen.gammaTable = tmp;
						set(obj.h.OKUseGamma,'Value',1);
						set(obj.h.OKUseGamma,'String',['None'; 'Gamma'; obj.r.screen.gammaTable.analysisMethods]);
						obj.r.screen.gammaTable.choice = 1;
					end
				end
			end
		end
		
		% ===================================================================
		%> @brief loadPrefs Load prefs better left local to the machine
		%> 
		% ===================================================================
		function saveCalibration(obj)
			if isa(obj.r.screen.gammaTable,'calibrateLuminance')
				saveThis = true;
				tmp = obj.r.screen.gammaTable;
				d = dir(obj.paths.calibration);
				for i = 1:length(d)
					if isempty(regexp(d(i).name,'^\.+', 'once')) && d(i).isdir == false && d(i).bytes > 0
						if strcmp(d(i).name, tmp.filename)
							saveThis = false;
						end
					end
				end
				if saveThis == true
					save([obj.paths.calibration filesep 'calibration-' date],'tmp');
				end
			end
		end
		
		% ===================================================================
		%> @brief loadPrefs Load prefs better left local to the machine
		%> 
		% ===================================================================
		function loadPrefs(obj)
			for i = 1:length(obj.uiPrefsList)
				prfname = obj.uiPrefsList{i};
				if ispref('opticka',prfname) %pref exists
					if isfield(obj.h, prfname) %ui widget exists
						myhandle = obj.h.(prfname);
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
			drawnow
		end
		
		% ===================================================================
		%> @brief savePrefs Save prefs better left local to the machine
		%> 
		% ===================================================================
		function savePrefs(obj)
			for i = 1:length(obj.uiPrefsList)
				prfname = obj.uiPrefsList{i};
				myhandle = obj.h.(prfname);
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
		function deleteProtocol(obj)
			v = obj.gv(obj.h.OKProtocolsList);
			file = obj.gs(obj.h.OKProtocolsList,v);
			obj.paths.currentPath = pwd;
			cd(obj.paths.protocols);
			out=questdlg(['Are you sure you want to delete ' file '?'],'Protocol Delete');
			if strcmpi(out,'yes')
				delete(file);
			end
			obj.refreshProtocolsList;
			cd(obj.paths.currentPath);
		end
		
		% ===================================================================
		%> @brief Save Protocol
		%> Save Protocol
		%> @param 
		% ===================================================================
		function saveProtocol(obj)
			obj.paths.currentPath = pwd;
			cd(obj.paths.protocols);
			[f,p] = uiputfile('*.mat','Save Opticka Protocol','Protocol.mat');
			if f ~= 0
				cd(p);
				tmp = clone(obj);
				tmp.r.paths.stateInfoFile = obj.r.paths.stateInfoFile;
				tmp.store = struct(); %lets just nuke this incase some rogue handles are lurking
				tmp.h = struct(); %remove the handles to the UI which will not be valid on reload
				if isfield(tmp.r.screenSettings,'optickahandle'); tmp.r.screenSettings.optickahandle = []; end %!!!this fixes matlab bug 01255186
				for i = 1:tmp.r.stimuli.n
					cleanHandles(tmp.r.stimuli{i}); %just in case!
				end
				save(f,'tmp'); %this is the original code -- MAT CRASH on load, it is the same if i save obj directly or the cloned variant tmp
				obj.refreshStimulusList;
				obj.refreshVariableList;
				obj.refreshProtocolsList;
				clear tmp f p
			end
			cd(obj.paths.currentPath);
		end
		
		% ===================================================================
		%> @brief Load State Info 
		%> Save Protocol
		%> @param 
		% ===================================================================
		function loadStateInfo(obj)
			obj.paths.currentPath = pwd;
			cd(obj.paths.protocols);
			[fname,fpath] = uigetfile({'.m'},'Load State Info file (.m)');
			if ~ischar(fname) || isempty(fname)
				disp('No file selected...')
				return
			end
			obj.paths.stateInfoFile = [fpath fname];
			obj.r.paths.stateInfoFile = obj.paths.stateInfoFile;
		end
		
		% ===================================================================
		%> @brief Load State Info 
		%> Save Protocol
		%> @param 
		% ===================================================================
		%function delete(obj)
			%fprintf('---> %s DESTRUCTOR CALLED <---\n',obj.fullName)
		%end
		
		% ===================================================================
		%> @brief Load Protocol
		%> Load Protocol
		%> @param ui do we show a uiload dialog?
		% ===================================================================
		function loadProtocol(obj,ui)
			
			if ~exist('ui','var') || isempty(ui);	ui = true; end
			obj.paths.currentPath = pwd;

			if ui == true
				v = obj.gv(obj.h.OKProtocolsList);
				file = obj.gs(obj.h.OKProtocolsList,v);
				p = obj.paths.protocols;
			else
				[file,p] = uigetfile('*.mat','Select an Opticka Protocol (saved as a .mat)'); %cd([obj.paths.root filesep 'CoreProtocols'])
			end
			
			if isempty(file) | file == 0
				return
			end
			cd(p);
			load(file);
			obj.paths.protocols = p;
			
			obj.comment = ['Protocol: ' file];
			obj.r.comment = obj.comment;
			
			if exist('tmp','var') && isa(tmp,'opticka')
				if isprop(tmp.r,'stimuli')
					if isa(tmp.r.stimuli,'metaStimulus')
						obj.r.stimuli = tmp.r.stimuli;
					elseif iscell(tmp.r.stimuli)
						obj.r.stimuli = metaStimulus();
						obj.r.stimuli.stimuli = tmp.r.stimuli;
					else
						clear tmp;
						warndlg('Sorry, this protocol is appears to have no stimulus objects, please remake');
						error('No stimulus found in protocol!!!');
					end
				elseif isprop(tmp.r,'stimulus')
					if iscell(tmp.r.stimulus)
						obj.r.stimuli = metaStimulus();
						obj.r.stimuli.stimuli = tmp.r.stimulus;
					elseif isa(tmp.r.stimulus,'metaStimulus')
						obj.r.stimuli = tmp.r.stimulus;
					end
				else
					clear tmp;
					warndlg('Sorry, this protocol is appears to have no stimulus objects, please remake');
					error('No stimulus found in protocol!!!');
				end
				
				%copy rE parameters
				if isa(tmp.r,'runExperiment')
					if strcmpi(obj.r.name,'runExperiment')
						obj.r.name = [obj.comment];
					else
						obj.r.name = [obj.r.name ':' obj.comment];
					end
					if isfield(tmp.r.paths,'stateInfoFile')
						obj.r.paths.stateInfoFile = tmp.r.paths.stateInfoFile;
						obj.getStateInfo();
					elseif isprop(obj.r,'stateInfoFile') && isprop(tmp.r,'stateInfoFile')
						obj.r.paths.stateInfoFile = tmp.r.stateInfoFile;
						if ~exist(obj.r.paths.stateInfoFile,'file')
							obj.r.paths.stateInfoFile=regexprep(tmp.r.stateInfoFile,'(.+)(.Code.opticka.+)','~$2','ignorecase','once');
						end							
						obj.getStateInfo();
					end
					obj.h.OKuseLabJack.Checked = 'off';	obj.h.OKuseDataPixx.Checked = 'off'; obj.h.OKuseEyeLink.Checked = 'off';
					obj.r.useLabJack = tmp.r.useLabJack;
					if obj.r.useLabJack == true; obj.h.OKuseLabJack.Checked = 'on'; end
					obj.r.useDataPixx = tmp.r.useDataPixx;
					if obj.r.useDataPixx == true; obj.h.OKuseDataPixx.Checked = 'on'; end
					obj.r.useEyeLink = tmp.r.useEyeLink;
					if obj.r.useEyeLink == true; obj.h.OKuseEyeLink.Checked = 'on'; end
				end
				
				%copy screen parameters
				if isa(tmp.r.screen,'screenManager')
					set(obj.h.OKscreenXOffset,'String', num2str(tmp.r.screen.screenXOffset));
					set(obj.h.OKscreenYOffset,'String', num2str(tmp.r.screen.screenYOffset));
					
					set(obj.h.OKNativeBeamPosition,'Value', tmp.r.screen.nativeBeamPosition);
					
					list = obj.gs(obj.h.OKGLSrc);
					val = obj.findValue(list,tmp.r.screen.srcMode);
					obj.r.screen.srcMode = list{val};
					set(obj.h.OKGLSrc,'Value',val);
					
					list = obj.gs(obj.h.OKGLDst);
					val = obj.findValue(list,tmp.r.screen.dstMode);
					obj.r.screen.dstMode = list{val};
					set(obj.h.OKGLDst,'Value',val);
					
					list = obj.gs(obj.h.OKbitDepth);
					val = obj.findValue(list,tmp.r.screen.bitDepth);
					obj.r.screen.bitDepth = list{val};
					set(obj.h.OKbitDepth,'Value',val);
					
					set(obj.h.OKOpenGLBlending,'Value', tmp.r.screen.blend);
					set(obj.h.OKAntiAliasing,'String', num2str(tmp.r.screen.antiAlias));
					set(obj.h.OKHideFlash,'Value', tmp.r.screen.hideFlash);
					string = num2str(tmp.r.screen.backgroundColour);
					string = regexprep(string,'\s+',' '); %collapse spaces
					set(obj.h.OKbackgroundColour,'String',string);
				else
					obj.salutation('No screenManager settings loaded!','',true);
				end
				%copy task parameters
				if isempty(tmp.r.task)
					obj.r.task = stimulusSequence;
					obj.r.task.randomiseStimuli;
				else
					obj.r.task = tmp.r.task;
					for i=1:obj.r.task.nVars
						if ~isfield(obj.r.task.nVar(i),'offsetstimulus') %add these to older protocols that may not contain them
							obj.r.task.nVar(i).offsetstimulus = [];
							obj.r.task.nVar(i).offsetvalue = [];
						end
					end
				end
				
				set(obj.h.OKtrialTime, 'String', num2str(obj.r.task.trialTime));
				set(obj.h.OKRandomSeed, 'String', num2str(obj.r.task.randomSeed));
				set(obj.h.OKitTime,'String',num2str(obj.r.task.ibTime));
				set(obj.h.OKisTime,'String',num2str(obj.r.task.isTime));
				set(obj.h.OKnBlocks,'String',num2str(obj.r.task.nBlocks));
				
				obj.getScreenVals;
				obj.getTaskVals;
				obj.refreshStimulusList;
				obj.refreshVariableList;
				obj.getScreenVals;
				obj.getTaskVals;
				
				if obj.r.task.nVars > 0
					set(obj.h.OKDeleteVariable,'Enable','on');
					set(obj.h.OKCopyVariable,'Enable','on');
					set(obj.h.OKEditVariable,'Enable','on');
				end
				if obj.r.stimuli.n > 0
					set(obj.h.OKDeleteStimulus,'Enable','on');
					set(obj.h.OKModifyStimulus,'Enable','on');
					set(obj.h.OKInspectStimulus,'Enable','on');
					set(obj.h.OKStimulusUp,'Enable','on');
					set(obj.h.OKStimulusDown,'Enable','on');
					set(obj.h.OKStimulusRun,'Enable','on');
					set(obj.h.OKStimulusRunBenchmark,'Enable','on');
					set(obj.h.OKStimulusRunAll,'Enable','on');
					set(obj.h.OKStimulusRunAllBenchmark,'Enable','on');
					set(obj.h.OKStimulusRunSingle,'Enable','on');
					obj.store.visibleStimulus.uuid='';
					obj.editStimulus;
				end
				
			end
			obj.refreshProtocolsList;
			o = getappdata(obj.h.output,'o');
			salutation(obj,sprintf('GUI routed from %s to %s\n',o.fullName,obj.fullName));
			setappdata(obj.h.output,'o',obj)
		end
		
		% ======================================================================
		%> @brief Refresh the UI list of Protocols
		%> Refresh the UI list of Protocols
		%> @param
		% ======================================================================
		function refreshProtocolsList(obj)
			
			set(obj.h.OKProtocolsList,'String',{''});
			obj.paths.currentPath = pwd;
			cd(obj.paths.protocols);
			
			% Generate path based on given root directory
			files = dir(pwd);
			if isempty(files)
				set(obj.h.OKProtocolsList,'String',{''});
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
			
			set(obj.h.OKProtocolsList,'Value', 1);
			set(obj.h.OKProtocolsList,'String',filelist);
			cd(obj.paths.currentPath);
		end
		
		% ===================================================================
		%> @brief refreshStimulusList
		%> refreshes the stimulus list in the UI after add/remove new stimulus
		%> @param 
		% ===================================================================
		function refreshStimulusList(obj)
			pos = get(obj.h.OKStimList, 'Value');
			str = cell(obj.r.stimuli.n,1);
			for i=1:obj.r.stimuli.n
				s = obj.r.stimuli{i};
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
			set(obj.h.OKStimList,'String', str);
			set(obj.h.OKStimList, 'Value', pos);
		end
		
		% ===================================================================
		%> @brief Refresh the Variable list in the UI
		%> 
		%> @param 
		% ===================================================================
		function refreshVariableList(obj)
			pos = get(obj.h.OKVarList, 'Value');
			str = cell(obj.r.task.nVars,1);
			V = obj.r.task.nVar;
			for i=1:obj.r.task.nVars
				if iscell(V(i).values)
					v = obj.cell2str(V(i).values);
				else
					v = num2str(V(i).values);
				end
				str{i} = [V(i).name ' on Stim: ' num2str(V(i).stimulus) '|' v];
				if isfield(V, 'offsetstimulus') && ~isempty(V(i).offsetstimulus)
					str{i} =  [str{i} ' | Stim ' num2str(V(i).offsetstimulus) ' offset:' num2str(V(i).offsetvalue)];
				end
				str{i}=regexprep(str{i},'\s+',' ');
			end
			set(obj.h.OKVarList,'String',str);
			if pos > obj.r.task.nVars
				pos = obj.r.task.nVars;
			end
			if isempty(pos) || pos <= 0
				pos = 1;
			end
			set(obj.h.OKVarList,'Value',pos);
		end
		
		% ===================================================================
		%> @brief find the value in a cell string list
		%> 
		%> @param 
		% ===================================================================
		function value = findValue(obj,list,entry)
			value = 1;
			for i=1:length(list)
				if regexpi(list{i},entry)
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
		function value = abortRunEvent(obj,src,evtdata)
			fprintf('---> Opticka: abortRun triggered!!!\n')
			if isa(obj.oc,'dataConnection') && obj.oc.isOpen == 1
				obj.oc.write('--abort--');
			end
		end
		
		% ===================================================================
		%> @brief Event trigger on end
		%> 
		%> @param 
		% ===================================================================
		function value = endRunEvent(obj,src,evtdata)
			fprintf('---> Opticka: endRun triggered!!!\n')
		end
		
		% ===================================================================
		%> @brief Event triggered on get info
		%> 
		%> @param 
		% ===================================================================
		function value = runInfoEvent(obj,src,evtdata)
			fprintf('---> Opticka: runInfo triggered!!!\n')
		end
		
		% ===================================================================
		%> @brief fixUI Try to work around GUIDE OS X bugs
		%> 
		% ===================================================================
		function fixUI(obj)
			ch = findall(obj.h.output);
			set(obj.h.output,'Units','pixels');
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
		%> @param obj
		% ===================================================================
 		function sobj = saveobj(obj)
 			sobj = obj;
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
			if nargin<1 || isempty(position);
				position=1;
			end
			if nargin<2 || isempty(size);
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