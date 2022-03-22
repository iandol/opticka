
% ======================================================================
%> @class opticka
%> @brief GUI Manager for runExperiment() class
%>
%> Opticka is an object-oriented experiment manager wrapping the Psychophysics
%> toolbox; see http://iandol.github.com/opticka/ for more details. This
%> class builds and controls the GUI that manages interaction with
%> runExperiment and other classes (screenManager, metaStimulus,
%> taskSequence, stateMachine etc.)
%>
%> @todo expose maskStimulus settings in the optickaGUI
%> @todo improve the variable list editor: live updating
%> @todo add trialVar and blockVar from taskSequene to the GUI
%> @todo make a html-based help button for different parts of the GUI
%> @todo more flexible specification for arduino settings
%>
%> Copyright ©2014-2022 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ======================================================================
classdef opticka < optickaCore
	
	properties
		%> this is the main runExperiment object
		r runExperiment
		%> run in verbose mode?
		verbose					= false
	end
	
	properties (SetAccess = public, GetAccess = public, Transient = true)
		%> general store for misc properties
		store struct			= struct()
		%> initialise UI?
		initUI logical			= true
	end
	
	properties (SetAccess = protected, GetAccess = public, Transient = true)
		%> all of the handles to the opticka_ui GUI
		ui
	end
	
	properties (SetAccess = protected, GetAccess = public)
		%> version number
		optickaVersion char		= '2.07'
		%> is this a remote instance?
		remote					= false
	end

	properties (SetAccess = protected, GetAccess = public, Hidden = true)
		%> omniplex connection, via TCP
		oc
	end
	
	properties (SetAccess = private, GetAccess = private)
		%> history of display objects
		history
		%> spash screen handle
		ss
		%> used to sanitise passed values on construction
		allowedProperties char = 'verbose|initUI'
		%> which UI settings should be saved locally to the machine?
		uiPrefsList cell = {'OKOmniplexIP','OKMonitorDistance','OKpixelsPerCm',...
			'OKbackgroundColour','OKAntiAliasing','OKbitDepth','OKUseRetina',...
			'OKHideFlash','OKlogFrames','OKUsePhotoDiode','OKTrainingResearcherName',...
			'OKTrainingName','OKarduinoPort','OKdPPMode','OKDebug',...
			'OKOpenGLBlending','OKCalEditField','OKValEditField',...
			'OKTrackerDropDown','OKWindowSize','OKUseDummy'}
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
			
			args = optickaCore.addDefaults(varargin,struct('name','opticka'));
			me=me@optickaCore(args); %superclass constructor
			me.parseArgs(args,me.allowedProperties);
			
			if me.cloning == false
				if ~exist('OKStartTask_image.png','file');addOptickaToPath;end
				if me.initUI
					me.initialiseUI;
				end
			end
		end
		
		% ===================================================================
		%> @brief Route to private methods
		%>
		%> @param in switch to route to correct method.
		%> @param vars additional vars to pass.
		% ===================================================================
		function router(me,in,vars)
			% router(me,in,vars)
			if ~exist('vars','var')
				vars=[];
			end
			switch in
				case 'saveData'
					me.saveData();
				case 'saveProtocol'
					me.saveProtocol(vars);
				case 'loadProtocol'
					me.loadProtocol(vars);
				case 'deleteProtocol'
					me.deleteProtocol();
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
			if ~ishandle(me.ui.output)
				me.remote = true;
			end
		end

		% ===================================================================
		%> @brief connectToOmniplex
		%> Gets the settings from the UI and connects to omniplex
		%> @param 
		% ===================================================================
		function connectToOmniplex(me)
			rPort = me.gn(me.ui.OKOmniplexPort);
			rAddress = me.gs(me.ui.OKOmniplexIP);
			status = me.ping(rAddress);
			if status > 0
				set(me.ui.OKOmniplexStatus,'Value','Omniplex: machine ping ERROR!');
				errordlg('Cannot ping Omniplex machine, please ensure it is connected!!!');
				error('Cannot ping Omniplex, please ensure it is connected!!!');
			end
			if isempty(me.oc)
				in = struct('verbosity',0,'rPort',rPort,'rAddress',rAddress,'protocol','tcp');
				me.oc = dataConnection(in);
			else
				me.oc.rPort = me.gn(me.ui.OKOmniplexPort);
				me.oc.rAddress = me.gs(me.ui.OKOmniplexIP);
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
					fprintf('\n{opticka said: %s}\n',in);
					if regexpi(in,'(opened|ping)')
						fprintf('\nWe can ping omniplex master on try: %d\n',loop);
						set(me.ui.OKOmniplexStatus,'Value','Omniplex: connected via TCP');
						break
					else
						fprintf('\nOmniplex master not responding, try: %d\n',loop);
						set(me.ui.OKOmniplexStatus,'Value','Omniplex: not responding');
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
				data = me.oc.read('all');
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
					fprintf('\n{omniplex said: %s}\n',in);
					if regexpi(in,'(stimulusReceived)')
						set(me.ui.OKOmniplexStatus,'Value','Omniplex: connected+stimulus received');
						break;
					elseif regexpi(in,'(stimulusFailed)')
						set(me.ui.OKOmniplexStatus,'Value','Omniplex: connected, stimulus ERROR!');
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
				me.ss = SplashScreen(['Opticka V' me.optickaVersion],'opticka.png');
				if isdeployed
					me.ss.addText( 10, 30, ['Loading Opticka [D] V' me.optickaVersion '…'], 'FontSize', 20, 'Color', [1 0.8 0.5] )
				else
					me.ss.addText( 10, 30, ['Loading Opticka V' me.optickaVersion '…'], 'FontSize', 20, 'Color', [1 0.8 0.5] )
				end
				me.paths.filename = mfilename;
				me.paths.whereami = fileparts(which(mfilename));
				me.paths.startServer = [me.paths.whereami filesep 'udpserver' filesep 'launchDataConnection'];

				if ismac
					me.store.serverCommand = ['!osascript -e ''tell application "Terminal"'' -e ''activate'' -e ''do script "matlab -nodesktop -r \"runServer\""'' -e ''end tell'''];
				else
					me.store.serverCommand = '!matlab -nodesktop -nosplash -r "d=dataConnection(struct(''autoServer'',1,''lPort'',5678));" &';
				end

				if ismac || isunix
					me.paths.temp=tempdir;

					if ~exist([me.paths.parent filesep 'Protocols'],'dir')
						mkdir([me.paths.parent filesep 'Protocols']);
					end
					if ~isdeployed && ~exist([me.paths.parent filesep 'Protocols' filesep 'CoreProtocols'],'dir')
						src = [me.paths.whereami filesep 'CoreProtocols'];
						dst = [me.paths.parent filesep 'Protocols' filesep];
						cmd = ['!ln -s ' src ' ' dst];
						eval(cmd);
					end
					
					me.paths.protocols = [me.paths.parent filesep 'Protocols'];
					cd(me.paths.protocols);
					me.paths.currentPath = pwd;
					
					if ~exist([me.paths.parent filesep 'Calibration'],'dir')
						mkdir([me.paths.parent filesep 'Calibration']);
					end
					me.paths.calibration = [me.paths.parent filesep 'Calibration'];
					
					if ~exist([me.paths.temp 'History'],'dir')
						mkdir([me.paths.temp 'History']);
					end
					me.paths.historypath=[me.paths.temp 'History'];
					
					if ~exist([me.paths.parent filesep 'SavedData'],'dir')
						mkdir([me.paths.parent filesep 'SavedData']);
					end
					me.paths.savedData = [me.paths.parent filesep 'SavedData'];
				elseif ispc
					root = me.paths.parent;
					me.paths.temp=tempdir;
					
					if ~exist([root 'Protocols'],'dir')
						mkdir([root 'Protocols']);
					end
					me.paths.protocols = [root 'Protocols'];
					cd(me.paths.protocols);
					me.paths.currentPath = pwd;
					
					if ~exist([root 'Calibration'],'dir')
						mkdir([root 'Calibration']);
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

				me.ui = opticka_ui(me); %our GUI file
				
				me.loadPrefs();
				me.getScreenVals();
				me.getTaskVals();
				me.loadCalibration();
				me.refreshProtocolsList();

				OKTobiiUpdate(me.ui);
				
				%addlistener(me.r,'abortRun',@me.abortRunEvent);
				%addlistener(me.r,'endAllRuns',@me.endRunEvent);
				%addlistener(me.r,'runInfo',@me.runInfoEvent);
				
				if exist([me.paths.protocols filesep 'DefaultStateInfo.m'],'file')
					me.paths.stateInfoFile = [me.paths.protocols filesep 'DefaultStateInfo.m'];
					me.r.stateInfoFile = me.paths.stateInfoFile;
				elseif ~isdeployed
					me.paths.stateInfoFile = [me.paths.whereami filesep 'DefaultStateInfo.m'];
					me.r.stateInfoFile = me.paths.stateInfoFile;
				end
				
				me.r.researcherName = me.ui.OKTrainingResearcherName.Value;
				me.r.subjectName = me.ui.OKTrainingName.Value;
				getStateInfo(me);
				if ~isempty(me.ss); pause(0.1); delete(me.ss); me.ss = []; end
			catch ME
				try close(me.ui.OKRoot); me.ui = []; end %#ok<*TRYNC>
				if ~isempty(me.ss); delete(me.ss); me.ss = []; end
				warning('Problem initialising Opticka UI, please check errors on the commandline!');
				rethrow(ME);
			end
			
		end
		
		% ===================================================================
		%> @brief getScreenVals
		%> Gets the settings from the UI and updates our runExperiment object
		%> @param 
		% ===================================================================
		function getScreenVals(me)
			
			if isempty(me.r)
				if ~isdeployed || ~ismcc
					olds = me.ui.OKOptickaVersion.Text;
					me.ui.OKOptickaVersion.Text = 'Initialising Stimulus and Task objects...';
					%drawnow
				end
				me.r = runExperiment();
				initialise(me.r); % set up the runExperiment object
				s=cell(me.r.screen.maxScreen+1,1);
				for i=0:me.r.screen.maxScreen
					s{i+1} = num2str(i);
				end
				if ~isdeployed || ~ismcc
					me.ui.OKSelectScreen.Items = s;
					me.ui.OKSelectScreen.Value = s{end};
					clear s;
					me.ui.OKOptickaVersion.Text = olds; 
				end
			end
			
			me.r.screen.screen = me.gd(me.ui.OKSelectScreen);
			
			me.r.screen.distance = me.gd(me.ui.OKMonitorDistance);
			me.r.screen.pixelsPerCm = me.gd(me.ui.OKpixelsPerCm);
			me.r.screen.screenXOffset = me.gd(me.ui.OKscreenXOffset);
			me.r.screen.screenYOffset = me.gd(me.ui.OKscreenYOffset);
			
			me.r.screen.srcMode = me.gv(me.ui.OKGLSrc);
			
			me.r.screen.dstMode = me.gv(me.ui.OKGLDst);
			
			me.r.screen.bitDepth = me.gv(me.ui.OKbitDepth);
			
			me.r.screen.blend = me.gv(me.ui.OKOpenGLBlending);
			
			value = me.gp(me.ui.OKUseGamma);
			if isprop(me.r.screen,'gammaTable') && isa(me.r.screen.gammaTable,'calibrateLuminance') && ~isempty(me.r.screen.gammaTable)
				me.r.screen.gammaTable.choice = value - 1;
			end
			
			s=str2num(me.gv(me.ui.OKWindowSize)); %#ok<ST2NM>
			if isempty(s)
				me.r.screen.windowed = false;
			else
				me.r.screen.windowed = s;
			end
			
			me.r.logFrames = logical(me.gv(me.ui.OKlogFrames));
			me.r.benchmark = logical(me.gv(me.ui.OKbenchmark));
			me.r.screen.hideFlash = logical(me.gv(me.ui.OKHideFlash));
			me.r.screen.useRetina = logical(me.gv(me.ui.OKUseRetina));
			me.r.dummyMode = logical(me.gv(me.ui.OKUseDummy));
			if strcmpi(me.r.screen.bitDepth,'8bit')
				me.ui.OKAntiAliasing.Value = '0';
			end
			me.r.screen.antiAlias = me.gd(me.ui.OKAntiAliasing);
			me.r.screen.photoDiode = logical(me.gv(me.ui.OKUsePhotoDiode));
			me.r.screen.movieSettings.record = logical(me.gv(me.ui.OKrecordMovie));
			me.r.verbose = logical(me.gv(me.ui.OKVerbose)); %set method
			me.verbose = me.r.verbose;
			me.r.screen.debug = logical(me.gv(me.ui.OKDebug));
			me.r.debug = me.r.screen.debug;
			me.r.diaryMode = logical(me.gv(me.ui.OKDiaryMode));
			me.r.screen.visualDebug = me.r.screen.debug;
			me.r.screen.backgroundColour = me.gn(me.ui.OKbackgroundColour);
			%deprecated me.r.screen.nativeBeamPosition = logical(me.gv(me.h.OKNativeBeamPosition));
			
			if me.ui.OKuseLabJackStrobe.Checked == true
				me.r.useLabJackStrobe = true;
				me.r.useLabJackTStrobe = false;
			else
				me.r.useLabJackStrobe = false;
			end
			if me.ui.OKuseLabJackTStrobe.Checked == true
				me.r.useLabJackTStrobe = true;
				me.r.useLabJackStrobe = false;
			else
				me.r.useLabJackTStrobe = false;
			end
			if me.ui.OKuseDataPixx.Checked == true
				me.r.useDataPixx = true;
			else
				me.r.useDataPixx = false;
			end
			if me.ui.OKuseDisplayPP.Checked == true
				me.r.useDisplayPP = true;
				%me.r.dPPMode = get(me.h.OKdPPMode,'Value');
			else
				me.r.useDisplayPP = false;
			end
			if me.ui.OKuseArduino.Checked == true
				me.r.useArduino = true;
				me.r.arduinoPort = me.gv(me.ui.OKarduinoPort);
			else
				me.r.useArduino = false;
			end
			if me.ui.OKuseLabJackReward.Checked == true
				me.r.useLabJackReward = true;
			else
				me.r.useLabJackReward = false;
			end
			if me.ui.OKuseEyelink.Checked == true
				me.r.useEyeLink = true;
				me.r.useTobii = false;
				me.ui.OKuseTobii.Checked = false;
			else
				me.r.useEyeLink = false;
			end
			if me.ui.OKuseTobii.Checked == true
				me.r.useTobii = true;
				me.r.useEyeLink = false;
				e.h.OKuseEyelink.Checked = false;
			else
				me.r.useTobii = false;
			end
			if me.ui.OKuseEyeOccluder.Enable == true && me.ui.OKuseEyeOccluder.Checked == true
				me.r.useEyeOccluder = true;
			else
				me.r.useEyeOccluder = false;
			end
			
		end
		
		% ===================================================================
		%> @brief getTaskVals
		%> Gets the settings from the UI and updates our task object
		%> @param randomise do we run randomiseTask()? [default=FALSE]
		% ===================================================================
		function getTaskVals(me, randomise)
			if ~exist('randomise','var'); randomise = true; end
			if isempty(me.r.task)
				me.r.task = taskSequence;
				me.r.task.initialise;
			end
			if isfield(me.r.screenVals,'fps')
				me.r.task.fps = me.r.screenVals.fps;
			end
			me.r.task.trialTime = me.gd(me.ui.OKtrialTime);
			me.r.task.randomSeed = me.gn(me.ui.OKRandomSeed);
			me.r.task.randomGenerator = me.gs(me.ui.OKrandomGenerator);
			me.r.task.ibTime = me.gn(me.ui.OKibTime);
			me.r.task.randomise = logical(me.gv(me.ui.OKRandomise));
			me.r.task.isTime = me.gn(me.ui.OKisTime);
			me.r.task.nBlocks = me.gd(me.ui.OKnBlocks);
			me.r.task.realTime = logical(me.gv(me.ui.OKrealTime));
			if ~isempty(me.r.task.blockVar)
				me.r.task.blockVar.values = me.ge(me.ui.OKBlockValues);
				me.r.task.blockVar.probability = me.gn(me.ui.OKBlockProbability);
				if length(me.r.task.blockVar.values) ~= length(me.r.task.blockVar.probability)
					randomise = false;
				end
			end
			if ~isempty(me.r.task.trialVar)
				me.r.task.trialVar.values = me.ge(me.ui.OKTrialValues);
				me.r.task.trialVar.probability = me.gn(me.ui.OKTrialProbability);
				if length(me.r.task.trialVar.values) ~= length(me.r.task.trialVar.probability)
					randomise = false;
				end
			end
			if isempty(me.r.task.taskStream); me.r.task.initialiseGenerator; end
			if randomise; me.r.task.randomiseTask; end
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
					set(me.ui.OKTrainingText,'Value',o.store.statetext);
					set(me.ui.OKTrainingFileName,'Text',['FileName:' me.r.paths.stateInfoFile]);
				else
					set(me.ui.OKTrainingText,'Value','');
					set(me.ui.OKTrainingFileName,'Text','No File Specified...');
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
				if isempty(me.r.stimuli)
					me.r.stimuli = metaStimulus();
				end
			end
			fn = fieldnames(me.store);
			for i = 1:length(fn)
				if isa(me.store.(fn{i}),'baseStimulus')
					try closePanel(me.store.(fn{i})); end
					try me.store = rmfield(me.store, fn{i}); end
				end
			end
			ch = get(me.ui.OKPanelStimulus,'Children');
			for i = 1:length(ch)
				if strcmpi(get(ch(i),'Type'),'uipanel')
					delete(ch(i));
				end
			end
			me.ui.OKStimList.Items = {}; me.ui.OKStimList.Value = {};
		end
		
		% ===================================================================
		%> @brief getScreenVals
		%> Gets the settings from th UI and updates our runExperiment object
		%> @param 
		% ===================================================================
		function clearVariableList(me)
			if ~isempty(me.r)
				if ~isempty(me.r.task) && me.r.task.nVars > 0
					me.r.task = taskSequence();
				end
			end
			refreshVariableList(me);
		end
		
		% ===================================================================
		%> @brief addStimulus
		%> Run when we've added a new stimulus
		%> @param 
		% ===================================================================
		function addStimulus(me)
			me.refreshStimulusList;
			nidx = me.r.stimuli.n;
			me.ui.OKStimList.Value = me.ui.OKStimList.Items{end};
			if isfield(me.store,'evnt') %delete our previous event
				delete(me.store.evnt);
				me.store = rmfield(me.store,'evnt');
			end
			me.store.evnt = addlistener(me.r.stimuli{nidx},'readPanelUpdate',@me.readPanel);
			if isfield(me.store,'visibleStimulus')
				if ~strcmp(me.r.stimuli{nidx}.uuid,me.store.visibleStimulus.uuid) || ~me.store.visibleStimulus.isGUI
					me.store.visibleStimulus.closePanel();
					makePanel(me.r.stimuli{nidx},me.ui.OKPanelStimulus);
					me.store.visibleStimulus = me.r.stimuli{nidx};
				else
					me.store.visibleStimulus.showPanel;
				end
			else
				makePanel(me.r.stimuli{nidx},me.ui.OKPanelStimulus);
				me.store.visibleStimulus = me.r.stimuli{nidx};
			end
		end

		% ===================================================================
		%> @brief deleteStimulus
		%> 
		%> @param 
		% ===================================================================
		function deleteStimulus(me)
			if ~isempty(me.r.stimuli.n) && me.r.stimuli.n > 0
				v=me.gp(me.ui.OKStimList);
				if isfield(me.store,'visibleStimulus')
					if strcmp(me.store.visibleStimulus.uuid,me.r.stimuli{v}.uuid)
						closePanel(me.r.stimuli{v});
						me.store.visibleStimulus = [];
					end
				end
				me.r.stimuli(v) = [];
				if me.r.stimuli.n > 0
					v = v - 1;
					if v == 0; v = 1; end
					me.ui.OKStimList.Value = me.ui.OKStimList.Items{v};
					me.store.visibleStimulus = me.r.stimuli{v};
					if ~isempty(me.store.visibleStimulus) && ~me.store.visibleStimulus.isGUI
						makePanel(me.r.stimuli{v},me.ui.OKPanelStimulus);
						me.store.visibleStimulus = me.r.stimuli{v};
					else
						me.store.visibleStimulus.showPanel;
					end
				end
				me.refreshStimulusList;
			end
		end
		
		% ===================================================================
		%> @brief readPanel
		%> 
		%> @param 
		% ===================================================================
		function readPanel(me,src,varargin)
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
				if ~isfield(me.store, 'visibleStimulus') || ~isa(me.store.visibleStimulus, 'baseStimulus')
					v = 1;
					me.store.visibleStimulus = me.r.stimuli{1};
				else
					v = me.gp(me.ui.OKStimList); 
					if isempty(v) || v == 0; v = 1; end
					if strcmpi(me.r.stimuli{v}.uuid, me.store.visibleStimulus.uuid)
						skip = true;
					end
				end
				if v <= me.r.stimuli.n && ~skip
					if isfield(me.store, 'evnt')
						delete(me.store.evnt);
						me.store = rmfield(me.store, 'evnt');
					end
					if me.r.stimuli{v}.isGUI
						hidePanel(me.store.visibleStimulus);
						showPanel(me.r.stimuli{v});
					else
						hidePanel(me.store.visibleStimulus);
						makePanel(me.r.stimuli{v}, me.ui.OKPanelStimulus);
					end
					me.store.evnt = addlistener(me.r.stimuli{v}, 'readPanelUpdate', @me.readPanel);
					me.store.visibleStimulus = me.r.stimuli{v};
					me.refreshStimulusList;
				end
			end
		end
		
		% ===================================================================
		%> @brief modifyStimulus
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
				me.r.task.nVar(revertN+1).name = me.gs(me.ui.OKVariableName);
				s = me.gs(me.ui.OKVariableValues);
				if isempty(regexpi(s,'^\{'))
					me.r.task.nVar(revertN+1).values = str2num(s);
				else
					me.r.task.nVar(revertN+1).values = eval(s);
				end
				me.r.task.nVar(revertN+1).stimulus = me.gn(me.ui.OKVariableStimuli);
				offset = eval(['{' me.ui.OKVariableOffset.Value '}']);
				if isempty(offset) || (iscell(offset) && isempty(offset{1}))
					me.r.task.nVar(revertN+1).offsetstimulus = [];
					me.r.task.nVar(revertN+1).offsetvalue = [];
				else
					me.r.task.nVar(revertN+1).offsetstimulus = offset{1};
					me.r.task.nVar(revertN+1).offsetvalue = offset{2};
				end
				try 
					me.r.task.randomiseTask;
					validate(me.r.task);
				catch
					warndlg('There is a problem with the stimulus variables, please check!')
				end
				me.refreshVariableList;
			catch ME
				getReport(ME)
				rethrow(ME);
			end
		end

		% ===================================================================
		%> @brief updateVariable
		%> Gets the values from the UI and updates that var
		%> @param 
		% ===================================================================
		function updateVariable(me)	
			try
				pos = me.gp(me.ui.OKVarList);
				if isempty(pos) || pos == 0; return; end
				me.r.task.nVar(pos).name = me.gs(me.ui.OKVariableName);
				
				s = me.gs(me.ui.OKVariableValues);
				if isempty(regexpi(s,'^\{', 'once'))
					me.r.task.nVar(pos).values = str2num(s);
				else
					me.r.task.nVar(pos).values = eval(s);
				end
				
				me.r.task.nVar(pos).stimulus = me.gn(me.ui.OKVariableStimuli);
				
				offset = eval(['{' me.ui.OKVariableOffset.Value '}']);
				if isempty(offset) || (iscell(offset) && isempty(offset{1}))
					me.r.task.nVar(pos).offsetstimulus = [];
					me.r.task.nVar(pos).offsetvalue = [];
				else
					me.r.task.nVar(pos).offsetstimulus = offset{1};
					me.r.task.nVar(pos).offsetvalue = offset{2};
				end
				try 
					me.r.task.randomiseTask;
					validate(me.r.task);
				catch
					warndlg('There is a problem with the stimulus variables, please check!')
				end
				me.refreshVariableList;
			catch ME
				getReport(ME);
				rethrow(ME);
			end
		end

		% ===================================================================
		%> @brief editVariable
		%> Gets the settings from the UI and updates our runExperiment object
		%> @param 
		% ===================================================================
		function editVariable(me)
			if isobject(me.r.task) && me.r.task.nVars > 0
				
				pos = me.gp(me.ui.OKVarList);
				
				me.ui.OKVariableName.Value = me.r.task.nVar(pos).name;
				
				v=me.r.task.nVar(pos).values;
				if iscell(v)
					v = me.cellAsString(v);
				else
					v = num2str(me.r.task.nVar(pos).values);
				end
				str = v;
				str = regexprep(str,'\s+',' ');
				me.ui.OKVariableValues.Value = str;

				str = num2str(me.r.task.nVar(pos).stimulus);
				str = regexprep(str,'\s+',' ');
				me.ui.OKVariableStimuli.Value = str;
				
				if isnumeric(me.r.task.nVar(pos).offsetvalue)
					str=[num2str(me.r.task.nVar(pos).offsetstimulus) '; ' num2str(me.r.task.nVar(pos).offsetvalue)];
				else
					str=[num2str(me.r.task.nVar(pos).offsetstimulus) '; ''' me.r.task.nVar(pos).offsetvalue ''''];
				end
				me.ui.OKVariableOffset.Value = str;
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
				pos = me.gp(me.ui.OKVarList);
				if isempty(pos) || pos < 1; return; end 
				if pos <= me.r.task.nVars
					nV(pos)=[];
					me.r.task.nVar = [];
					me.r.task.nVar = nV;
					if me.r.task.nVars > 0
						me.r.task.randomiseTask;
					end
				end
				me.refreshVariableList;
			end
		end
		
		% ===================================================================
		%> @brief copyVariable
		%> Gets the settings from the UI and updates our runExperiment object
		%> @param 
		% ===================================================================
		function copyVariable(me)
			if isobject(me.r.task)
				val = me.gv(me.ui.OKVarList);
				me.r.task.nVar(end+1)=me.r.task.nVar(val);
				me.refreshVariableList;
			end
		end
		
		% ===================================================================
		%> @brief Load calibration file, better that this is manual...
		%> 
		% ===================================================================
		function loadCalibration(me)
			d = dir(me.paths.calibration);
			for i = 1:length(d)
				if isempty(regexp(d(i).name, '^\.+', 'once')) && d(i).isdir == false && d(i).bytes > 0
					ftime(i) = d(i).datenum;
				else
					ftime(i) = 0;
				end
			end
			if max(ftime) > 0
				[~,idx]=max(ftime);
				disp(['===>>> Opticka has found a potential calibration file: ' [me.paths.calibration filesep d(idx).name]]);
				%tmp = load([me.paths.calibration filesep d(idx).name]);
				%if isstruct(tmp)
				%	fn = fieldnames(tmp);
				%	tmp = tmp.(fn{1});
				%end
				%if isa(tmp,'calibrateLuminance')
				%	tmp.filename = [me.paths.calibration filesep d(idx).name];
				%	if isa(me.r,'runExperiment') && isa(me.r.screen,'screenManager')
				%		me.r.screen.gammaTable = tmp;
				%		me.h.OKUseGamma.Items =[ {'None'}; {'Gamma'}; me.r.screen.gammaTable.analysisMethods{:}']';
				%		me.r.screen.gammaTable.choice = 2;
				%	end
				%end
			end
		end
		
		% ===================================================================
		%> @brief 
		%> 
		% ===================================================================
		function saveCalibration(me)
			if isa(me.r.screen.gammaTable, 'calibrateLuminance')
				saveThis = true;
				tmp = me.r.screen.gammaTable;
				d = dir(me.paths.calibration);
				for i = 1:length(d)
					if isempty(regexp(d(i).name, '^\.+', 'once')) && d(i).isdir == false && d(i).bytes > 0
						if strcmp(d(i).name, tmp.filename)
							saveThis = false;
						end
					end
				end
				if saveThis == true
					save([me.paths.calibration filesep 'calibration-' date], 'tmp');
				end
			end
		end
		
		% ===================================================================
		%> @brief loadPrefs Load prefs better left local to the machine
		%> 
		% ===================================================================
		function loadPrefs(me)
			anyLoaded = false; prefnames = '';
			if ~ispref('opticka'); return; end
			for i = 1:length(me.uiPrefsList)
				prfname = me.uiPrefsList{i};
				if ispref('opticka',prfname) %pref exists
					if isprop(me.ui, prfname) %ui widget exists
						myhandle = me.ui.(prfname);
						prf = getpref('opticka', prfname);
						uiType = myhandle.Type;
						thisVal = '';
						switch uiType
							case 'uieditfield'
								if ischar(prf)
									myhandle.Value = prf; 
									thisVal = prf;
								else
									myhandle.Value = num2str(prf); 
									thisVal = myhandle.Value;
								end
							case 'uicheckbox'
								if islogical(prf) || isnumeric(prf)
									myhandle.Value = prf;
									thisVal = num2str(prf);
								end
							case 'uidropdown'
								str = myhandle.Items;
								if ischar(prf) && any(contains(prf, str))
									myhandle.Value = prf;
									thisVal = prf;
								end
						end
						prefnames = [prefnames ' ' prfname '«' thisVal '»'];
						if ~anyLoaded; anyLoaded = true; end
					end
				end	
			end
			if anyLoaded; fprintf('\n===>>> Opticka loaded its local preferences: %s \n',prefnames); end
		end
		
		% ===================================================================
		%> @brief savePrefs Save prefs better left local to the machine
		%> 
		% ===================================================================
		function savePrefs(me)
			if ispref('opticka'); rmpref('opticka'); end
			anySaved = false; prefnames = '';
			for i = 1:length(me.uiPrefsList)
				prfname = me.uiPrefsList{i};
				if ~isprop(me.ui,prfname); continue; end
				myhandle = me.ui.(prfname);
				uiType = myhandle.Type;
				switch uiType
					case 'uieditfield'
						prf = myhandle.Value;
						setpref('opticka', prfname, prf);
					case 'uicheckbox'
						prf = myhandle.Value;
						if ~islogical(prf); prf=logical(prf);end
						setpref('opticka', prfname, prf);
					case 'uidropdown'
						prf = myhandle.Value;
						setpref('opticka', prfname, prf);
				end
				prefnames = [prefnames ' ' prfname '«' num2str(prf) '»'];
				if ~anySaved; anySaved = true; end
			end
			if anySaved; fprintf('\n===>>> Opticka saved its local preferences: %s\n', prefnames); end
		end
		
	end
	
	%========================================================
	methods ( Hidden = true ) %----------HIDDEN METHODS
	%========================================================
		
		% ===================================================================
		%> @brief Delete Protocol
		%> Delete Protocol
		%> @param 
		% ===================================================================
		function deleteProtocol(me)
			v = me.gv(me.ui.OKProtocolsList);
			file = me.gs(me.ui.OKProtocolsList,v);
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
		function saveProtocol(me, copy)
			if ~exist('copy','var'); copy = false; end
			me.paths.currentPath = pwd;
			cd(me.paths.protocols);
			if isfield(me.store,'protocolName')
				fname = me.store.protocolName;
			else
				fname = 'Protocol.mat';
			end
			[f,p] = uiputfile('*.mat','Save Opticka Protocol',fname);
			if f ~= 0
				cd(p);
				tmp = clone(me);
				tmp.name = f;
				tmp.r.name = f;
				
				tmp.store = struct(); %lets just nuke this incase some rogue handles are lurking
				tmp.ui = struct(); %remove the handles to the UI which will not be valid on reload
				for i = 1:tmp.r.stimuli.n
					cleanHandles(tmp.r.stimuli{i}); %just in case!
				end
				[~, ff, ee] = fileparts(me.r.paths.stateInfoFile);
				if copy == true
					tmp.r.paths.stateInfoFile = [pwd filesep ff ee];
					if ~strcmpi(me.r.paths.stateInfoFile,tmp.r.paths.stateInfoFile)
						[status, msg] = copyfile(me.r.paths.stateInfoFile, tmp.r.paths.stateInfoFile, 'f');
						if status ~= 1
							warning(['Couldn''t copy state info file: ' msg]);
						else
							me.r.paths.stateInfoFile = tmp.r.paths.stateInfoFile;
							me.r.stateInfoFile = me.r.paths.stateInfoFile;
						end
					end
					save(f,'tmp');
					fprintf('\n---> Saving Protocol %s as copy (with state file) to %s\n', f, pwd);
					if exist(tmp.r.paths.stateInfoFile,'file')
						fprintf('\tState file path: %s\n', me.r.paths.stateInfoFile);
					end
					getStateInfo(me);
				else
					save(f,'tmp');
					fprintf('\n---> Saving Protocol %s (without state file) to %s\n', f, pwd);
				end
				me.refreshStimulusList;
				me.refreshVariableList;
				me.refreshProtocolsList;
				if isdeployed
					me.ui.OKOptickaVersion.Text = ['Opticka Experiment Manager [D] V' me.optickaVersion ' - ' f];
				else
					me.ui.OKOptickaVersion.Text = ['Opticka Experiment Manager V' me.optickaVersion ' - ' f];
				end
				clear tmp f p
			end
			cd(me.paths.currentPath);
		end
		
		% ===================================================================
		%> @brief Save Data
		%> Save data, by cloning a copy of the opticka object and saving this.
		% ===================================================================
		function saveData(me)
			me.paths.currentPath = pwd;
			cd(me.paths.savedData);
			[f,p] = uiputfile('*.mat','Save Last Run Data','Data.mat');
			if f ~= 0
				cd(p);
				data = clone(me);
				data.r.paths.stateInfoFile = me.r.paths.stateInfoFile;
				data.ui = struct(); %this property is supposed to be transient, but just in case remove the handles to the UI which will not be valid on reload
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
			me.r.stateInfoFile = me.r.paths.stateInfoFile;
		end
		
		% ===================================================================
		function loadProtocol(me,ui)
		%> @fn loadProtocol
		%> @brief Load Protocol
		%> Load Protocol
		%> @param ui -- do we show a uiload dialog?
		% ===================================================================	
			if ~exist('ui','var') || isempty(ui); ui = true; end
			me.paths.currentPath = pwd;

			if ui == true
				v = me.gv(me.ui.OKProtocolsList);
				if isempty(v)
					[fileName,p] = uigetfile('*.mat','Select an Opticka Protocol (saved as a .mat)');
				else
					fileName = v;
					p = me.paths.protocols;
				end
			else
				[fileName,p] = uigetfile('*.mat','Select an Opticka Protocol (saved as a .mat)'); %cd([me.paths.root filesep 'CoreProtocols'])
			end
			
			if isempty(fileName) | fileName == 0
				disp('--->>> Opticka loadProtocol: No file specified...')
				return
			end
			me.ui.OKOptickaVersion.Text = 'Loading Protocol, please wait...';
			cd(p);
			load(fileName, 'tmp');
			
			if ~isa(tmp,'opticka');warndlg('This is not an opticka protocol file...');return;end

			me.paths.protocols = p;
			
			me.comment = ['Protocol: ' fileName];
			me.store.protocolName = fileName;

			clearStimulusList(me);
			clearVariableList(me);
			
			salutation(me,sprintf('Routing Protocol FROM %s TO %s',tmp.fullName,me.fullName),[],true);
			
			fprintf('---> Opticka Protocol loading:\n');
			if isprop(tmp.r,'stimuli')
				if isa(tmp.r.stimuli,'metaStimulus')
					me.r.stimuli = tmp.r.stimuli;
					rm = [];
					for i = 1:me.r.stimuli.n
						if ~isa(me.r.stimuli{i},'baseStimulus')
							rm = [rm i];
						end
					end
					if ~isempty(rm); me.r.stimuli(rm) = []; end
					me.r.stimuli.stimulusSets = tmp.r.stimuli.stimulusSets;
					fprintf('\t…metaStimulus object loaded\n');
				elseif iscell(tmp.r.stimuli)
					me.r.stimuli = metaStimulus();
					me.r.stimuli.stimuli = tmp.r.stimuli;
					fprintf('\t…metaStimulus object loaded from cell array\n');
				else
					clear tmp;
					warndlg('Sorry, this protocol appears to have no stimulus objects, please remake');
					error('No stimulus found in protocol!!!');
				end
			elseif isprop(tmp.r,'stimulus')
				if iscell(tmp.r.stimulus)
					me.r.stimuli = metaStimulus();
					me.r.stimuli.stimuli = tmp.r.stimulus;
				elseif isa(tmp.r.stimulus,'metaStimulus')
					me.r.stimuli = tmp.r.stimulus;
				end
				fprintf('\t…legacy metaStimulus object loaded\n');
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

				me.r.paths.stateInfoFile = '';
				p1 = ''; p2 = ''; msg = '';
				if isprop(tmp.r,'stateInfoFile') && ~isempty(tmp.r.stateInfoFile)
					p1 = tmp.r.stateInfoFile;	
				end
				if isfield(tmp.r.paths,'stateInfoFile') && ~isempty(tmp.r.paths.stateInfoFile)
					p2 = tmp.r.paths.stateInfoFile;	
				end
				if contains(p1,'DefaultStateInfo.m') && ~contains(p2,'DefaultStateInfo.m')
					me.r.paths.stateInfoFile = p2;
					msg = ['p2:' msg];
				elseif ~isempty(p1) || strcmp(p1,p2)
					me.r.paths.stateInfoFile = p1;
					msg = ['p1:' msg];
				elseif ~isempty(p2)
					me.r.paths.stateInfoFile = p2;
					msg = ['p2:' msg];
				end
				if ~isempty(me.r.paths.stateInfoFile) && ~exist(me.r.paths.stateInfoFile,'file') % first try to find the file in current dir
					[~,f,e] = fileparts(me.r.paths.stateInfoFile);
					newfile = [pwd filesep f e];
					if exist(newfile, 'file')
						me.r.paths.stateInfoFile = newfile;
						msg = ['pwd:' msg];
					end
				end	
				if ~isempty(me.r.paths.stateInfoFile) && ~exist(me.r.paths.stateInfoFile,'file') % then try to replace the home directory
					me.r.paths.stateInfoFile=regexprep(tmp.r.stateInfoFile,'(.+)(.Code.opticka.+)',[getenv('HOME') '$2'],'ignorecase','once');
					msg = ['rehome:' msg];
				end
				if isempty(me.r.paths.stateInfoFile) || ~exist(me.r.paths.stateInfoFile,'file')
					warndlg(['Couldn''t find state info file! Sources were: ' p1 ' ' p2 '  --  Revert to DefaultStateInfo.m']);
					me.r.paths.stateInfoFile = which('DefaultStateInfo.m');
				else
					fprintf('\t…state info file [%s] : %s\n', msg, me.r.paths.stateInfoFile);
				end
				if isprop(me.r,'stateInfoFile'); me.r.stateInfoFile = me.r.paths.stateInfoFile; end
				me.getStateInfo();
				
				if isprop(tmp.r,'drawFixation');me.r.drawFixation=tmp.r.drawFixation;end
				if isprop(tmp.r,'dPPMode'); me.r.dPPMode = tmp.r.dPPMode; end
				%if isprop(tmp.r,'subjectName');me.r.subjectName = tmp.r.subjectName;me.h.OKTrainingName.Value = me.r.subjectName;end
				%if isprop(tmp.r,'researcherName');me.r.researcherName = tmp.r.researcherName;me.h.OKTrainingResearcherName.Value=me.r.researcherName;end
				me.r.subjectName = me.ui.OKTrainingName.Value;
				me.r.researcherName = me.ui.OKTrainingResearcherName.Value;

				me.ui.OKuseLabJackStrobe.Checked		= 'off';
				me.ui.OKuseLabJackTStrobe.Checked	= 'off';
				me.ui.OKuseDataPixx.Checked			= 'off';
				me.ui.OKuseDisplayPP.Checked			= 'off';
				me.ui.OKuseEyelink.Checked			= 'on';
				me.ui.OKuseTobii.Checked				= 'off';
				me.ui.OKuseLabJackReward.Checked		= 'off';
				me.ui.OKuseArduino.Checked			= 'off';
				me.ui.OKuseEyeOccluder.Checked		= 'off';
				me.ui.OKuseMagStim.Checked			= 'off';
				
				if isprop(tmp.r,'useLabJackTStrobe'); me.r.useLabJackTStrobe = tmp.r.useLabJackTStrobe; end
				if me.r.useLabJackTStrobe == true; me.ui.OKuseLabJackTStrobe.Checked = 'on'; end
				
				if isprop(tmp.r,'useDisplayPP'); me.r.useDisplayPP = tmp.r.useDisplayPP; end
				if me.r.useDisplayPP == true; me.ui.OKuseDisplayPP.Checked = 'on'; end
				
				if isprop(tmp.r,'useDataPixx'); me.r.useDataPixx = tmp.r.useDataPixx; end
				if me.r.useDataPixx == true; me.ui.OKuseDataPixx.Checked = 'on'; end
				
				if isprop(tmp.r,'useArduino'); me.r.useArduino = tmp.r.useArduino; end
				if me.r.useArduino == true; me.ui.OKuseArduino.Checked = 'on'; end
				
				if isprop(tmp.r,'useTobii'); me.r.useTobii = tmp.r.useTobii; end
				if me.r.useTobii == true; me.ui.OKuseTobii.Checked = 'on'; me.ui.OKuseEyelink.Checked = 'off';end
				
				if isprop(tmp.r,'useEyeLink'); me.r.useEyeLink = tmp.r.useEyeLink; end
				if me.r.useEyeLink == true; me.ui.OKuseEyelink.Checked = 'on'; me.ui.OKuseTobii.Checked = 'off';end
			end
			
			%copy screen parameters
			if isa(tmp.r.screen,'screenManager')
				me.ui.OKscreenXOffset.Value = num2str(tmp.r.screen.screenXOffset);
				me.ui.OKscreenYOffset.Value = num2str(tmp.r.screen.screenYOffset);
				
				%set(me.h.OKNativeBeamPosition,'Value', tmp.r.screen.nativeBeamPosition);
				
				list = me.gi(me.ui.OKGLSrc);
				val = me.findValue(list,tmp.r.screen.srcMode);
				if ~isempty(val) && val > 0 && val <=length(list)
					me.r.screen.srcMode = list{val(1)};
					me.ui.OKGLSrc.Value = me.r.screen.srcMode;
				end
				
				list = me.gi(me.ui.OKGLDst);
				val = me.findValue(list,tmp.r.screen.dstMode);
				if ~isempty(val) && val > 0
					me.r.screen.dstMode = list{val(1)};
					me.ui.OKGLDst.Value = me.r.screen.dstMode;
				end
				
				list = me.gi(me.ui.OKbitDepth);
				val = me.findValue(list,tmp.r.screen.bitDepth);
				if ~isempty(val) && val > 0
					me.r.screen.bitDepth = list{val(1)};
					me.ui.OKbitDepth.Value = me.r.screen.bitDepth;
				end
				
				set(me.ui.OKOpenGLBlending,'Value', tmp.r.screen.blend);
				set(me.ui.OKAntiAliasing,'Value', num2str(tmp.r.screen.antiAlias));
				set(me.ui.OKHideFlash,'Value', tmp.r.screen.hideFlash);
				set(me.ui.OKUseRetina,'Value', tmp.r.screen.useRetina);
				string = num2str(tmp.r.screen.backgroundColour);
				string = regexprep(string,'\s+',' '); %collapse spaces
				set(me.ui.OKbackgroundColour,'Value',string);
				fprintf('\t…screenManager settings copied\n');
			else
				fprintf('\t…No screenManager settings loaded!\n');
			end
			
			%===================copy task parameters taskSequence()
			if isempty(tmp.r.task)
				me.r.task = taskSequence;
				me.r.task.randomiseTask;
				fprintf('\t…taskSequence created\n');
			else
				me.r.task = tmp.r.task;
				for i=1:me.r.task.nVars
					if ~isfield(me.r.task.nVar(i),'offsetstimulus') %add these to older protocols that may not contain them
						me.r.task.nVar(i).offsetstimulus = [];
						me.r.task.nVar(i).offsetvalue = [];
					end
				end
				fprintf('\t…taskSequence assigned\n');
			end
			
			if isprop(me.r.task,'blockVar') && isfield(me.r.task.blockVar,'values') && isfield(me.r.task.blockVar,'probability')
				if iscell(me.r.task.blockVar.values)
					me.ui.OKBlockValues.Value = opticka.cellAsString(me.r.task.blockVar.values);
				end
				me.ui.OKBlockProbability.Value = regexprep(num2str(me.r.task.blockVar.probability), '\s+', ' ');
			end
			if isprop(me.r.task,'trialVar') && isfield(me.r.task.trialVar,'values') && isfield(me.r.task.trialVar,'probability')
				if iscell(me.r.task.trialVar.values)
					me.ui.OKTrialValues.Value = opticka.cellAsString(me.r.task.trialVar.values);
				end
				me.ui.OKTrialProbability.Value = regexprep(num2str(me.r.task.trialVar.probability), '\s+', ' ');
			end
			me.ui.OKRandomise.Value = logical(me.r.task.randomise);
			me.ui.OKrealTime.Value = logical(me.r.task.realTime);
			me.ui.OKtrialTime.Value = num2str(me.r.task.trialTime);
			me.ui.OKRandomSeed.Value = num2str(me.r.task.randomSeed);
			me.ui.OKisTime.Value = sprintf('%g ',me.r.task.isTime);
			me.ui.OKibTime.Value = sprintf('%g ',me.r.task.ibTime);
			me.ui.OKnBlocks.Value = num2str(me.r.task.nBlocks);
			
			if me.r.task.nVars > 0
				set(me.ui.OKAddVariable,'Enable','on');
				set(me.ui.OKDeleteVariable,'Enable','on');
				set(me.ui.OKCopyVariable,'Enable','on');
				set(me.ui.OKEditVariable,'Enable','on');
			end

			if me.r.stimuli.n > 0
				set(me.ui.OKDeleteStimulus,'Enable','on');
				set(me.ui.OKModifyStimulus,'Enable','on');
				set(me.ui.OKStimulusUp,'Enable','on');
				set(me.ui.OKStimulusDown,'Enable','on');
				set(me.ui.OKStimulusRun,'Enable','on');
				set(me.ui.OKStimulusRunBenchmark,'Enable','on');
				set(me.ui.OKStimulusRunAll,'Enable','on');
				set(me.ui.OKStimulusRunAllBenchmark,'Enable','on');
				set(me.ui.OKStimulusRunSingle,'Enable','on');
				me.store.visibleStimulus.uuid='';
				me.editStimulus;
			end
			
			me.getScreenVals;
			me.getTaskVals;
			me.refreshStimulusList;
			me.refreshVariableList;
			me.getScreenVals;
			me.refreshProtocolsList;
			me.ui.propertiesToVariables;
			
			fprintf('---> Protocol load finished…\n');

			if isdeployed
				me.ui.OKOptickaVersion.Text = ['Opticka Experiment Manager [D] V' me.optickaVersion ' - ' me.comment];
			else
				me.ui.OKOptickaVersion.Text = ['Opticka Experiment Manager V' me.optickaVersion ' - ' me.comment];
			end
			
			figure(me.ui.OKRoot);
		end
	end

	%========================================================
	methods ( Access = private ) %----------PRIVATE METHODS
	%========================================================

		
		% ======================================================================
		%> @brief Refresh the UI list of Protocols
		%> Refresh the UI list of Protocols
		%> @param
		% ======================================================================
		function refreshProtocolsList(me)
			
			set(me.ui.OKProtocolsList,'Items',{''});
			me.paths.currentPath = pwd;
			cd(me.paths.protocols);
			
			% Generate path based on given root directory
			files = dir(pwd);
			if isempty(files)
				set(me.ui.OKProtocolsList,'Items',{''});
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
			
			set(me.ui.OKProtocolsList,'Items',filelist);
			cd(me.paths.currentPath);
		end
		
		% ===================================================================
		%> @brief refreshStimulusList
		%> refreshes the stimulus list in the UI after add/remove new stimulus
		%> @param 
		% ===================================================================
		function refreshStimulusList(me)
			if me.r.stimuli.n == 0
				me.ui.OKStimList.Items = {};
				return
			end
			pos = me.gp(me.ui.OKStimList);
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
						tstr = [num2str(i) '.' name ':'];
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
						tstr = [num2str(i) '.' name ':'];
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
					case 'fixationcross'
						x=s.xPosition;
						y=s.yPosition;
						sz=s.size;
						c=s.colour;
						str{i} = [num2str(i) '.' name ': x=' num2str(x) ' y=' num2str(y) ' sz=' num2str(sz) ' col=' num2str(c, '%.2f ')];
					otherwise
						x=s.xPosition;
						y=s.yPosition;
						a=s.angle;
						str{i} = [num2str(i) '.' name ': x=' num2str(x) ' y=' num2str(y) ' ang=' num2str(a)];
				end
			end
			me.ui.OKStimList.Items = str;
			if ~isempty(pos) && pos <= length(str)
				me.ui.OKStimList.Value = str{pos};
			end
		end
		
		% ===================================================================
		%> @brief Refresh the Variable list in the UI
		%> 
		%> @param 
		% ===================================================================
		function refreshVariableList(me)
			if isempty(me.r.task) || me.r.task.nVars == 0
				me.ui.OKVarList.Items = {};
				me.ui.OKVarList.Value = {};
				return; 
			end
			if ~isempty(me.ui.OKVarList.Items) && ~isempty(me.ui.OKVarList.Value)
				pos = me.gp(me.ui.OKVarList);
			else
				pos = [];
			end
			str = cell(me.r.task.nVars,1);
			V = me.r.task.nVar;
			for i=1:me.r.task.nVars
				if iscell(V(i).values)
					v = me.cellAsString(V(i).values);
				else
					v = num2str(V(i).values);
				end
				str{i} = [V(i).name ' on Stim: ' num2str(V(i).stimulus) '|' v];
				if isfield(V, 'offsetstimulus') && ~isempty(V(i).offsetstimulus)
					str{i} =  [str{i} ' | Mod-Stim:' num2str(V(i).offsetstimulus) ' modifier:' num2str(V(i).offsetvalue)];
				end
				str{i}=regexprep(str{i},'\s+',' ');
			end
			me.ui.OKVarList.Items = str;
			if pos > me.r.task.nVars
				pos = me.r.task.nVars;
			end
			if isempty(pos) || pos <= 0
				pos = 1;
			end
			me.ui.OKVarList.Value = str{pos};
		end
		
		% ===================================================================
		%> @brief find the value in a cell string list
		%> 
		%> @param 
		% ===================================================================
		function value = findValue(me,list,entry)
			value = 1;
			if ischar(list); list = {list}; end
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
			ch = findall(me.ui.output);
			set(me.ui.output,'Units','pixels');
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
				fprintf('---> opticka loadobj: Assigning object… ');
				try fprintf('…previous object version: %s | dated: %s\n', in.optickaVersion, datestr(in.dateStamp)); end
				lobj = in;
			else
				try fprintf('---> Opticka loadobj: Recreating object %s from structure…\n',in.fullName_); end
				try fprintf('\t…previous object version: %s | dated: %s\n', in.optickaVersion, datestr(in.dateStamp)); end
				lobj = opticka('initUI',false);
				lobj.r = in.r;
				lobj.comment = in.comment;
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
		%> @brief gs (getstring)
		%> 
		%> @param inhandle handle to UI element
		%> @param value
		% ===================================================================
		function outv = gs(inhandle,value)
			if isprop(inhandle,'String')
				if exist('value','var') 
					s = get(inhandle,'String');
					outv = s{value};
				else
					outv = get(inhandle,'String');
				end
			elseif isprop(inhandle,'Value')
				if exist('value','var') 
					s = get(inhandle,'Value');
					outv = s{value};
				else
					outv = get(inhandle,'Value');
				end
			end
		end
		
		% ===================================================================
		%> @brief gi (getitems) items of a dropdown menu
		%> 
		%> @param inhandle handle to UI element
		% ===================================================================
		function outv = gi(inhandle)
			if isprop(inhandle,'Items')
				outv = inhandle.Items;
			else
				outv = {};
			end
		end
		
		% ===================================================================
		%> @brief gi (getposition) 1st position of selection in dropdown menu
		%> 
		%> @param inhandle handle to UI element
		% ===================================================================
		function outv = gp(inhandle)
			if isprop(inhandle,'Items') && ~isempty(inhandle.Value)
				outv = find(contains(inhandle.Items,inhandle.Value)==true, 1);
			elseif isprop(inhandle,'Items') && ~isempty(inhandle.Items) && isempty(inhandle.Value)
				inhandle.Value = inhandle.Items{1};
				outv = 1;
			else
				outv = [];
			end
		end
		
		% ===================================================================
		%> @brief gd (getdouble)
		%> 
		%> @param inhandle handle to UI element
		% ===================================================================
		function outv = gd(inhandle)
		%quick alias to get double value
			if isprop(inhandle,'String')
				outv = str2double(inhandle.String);
			elseif isprop(inhandle,'Value') && ~isnumeric(inhandle.Value)
				outv = str2double(inhandle.Value);
			elseif isprop(inhandle,'Value') && isnumeric(inhandle.Value)
				outv = inhandle.Value;
			else
				outv = [];
			end
		end
		
		% ===================================================================
		%> @brief gn (getnumber)
		%> 
		%> @param inhandle handle to UI element
		% ===================================================================
		function outv = gn(inhandle)
		% quick alias to get number value
			if isprop(inhandle,'String')
				outv = str2num(inhandle.String); %#ok<ST2NM>
			elseif isprop(inhandle,'Value')
				outv = str2num(inhandle.Value); %#ok<ST2NM>
			elseif isprop(inhandle,'Text')
				outv = str2num(inhandle.Text); %#ok<ST2NM>
			else
				outv = '';
			end
		end

		% ===================================================================
		%> @brief get string but eval to variable
		%> 
		%> @param inhandle handle to UI element
		% ===================================================================
		function outv = ge(inhandle)
		% quick alias to get number value
			if isprop(inhandle,'String')
				outv = eval(inhandle.String); %#ok<ST2NM>
			elseif isprop(inhandle,'Value')
				outv = eval(inhandle.Value); %#ok<ST2NM>
			elseif isprop(inhandle,'Text')
				outv = eval(inhandle.Text); %#ok<ST2NM>
			else
				outv = '';
			end
		end
		
		% ===================================================================
		%> @brief gv (getvalue)
		%> 
		%> @param inhandle handle to UI element
		% ===================================================================
		function outv = gv(inhandle)
		%quick alias to get ui value
			if isprop(inhandle,'Value')
				outv = inhandle.Value;
			else
				outv = [];
			end
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
		%> @fn cellAsString
		%> @brief convert a cell into a string to display in UI that we can eval
		%> back to a cell array. It collapses nested cells.
		%> 
		%> @param c cell array of strings
		%> @param addBrackets; add { } around string or not?
		%> @return s the string representation
		% ===================================================================
		function s = cellAsString(c, addBrackets)
			if ~exist('addBrackets','var'); addBrackets = true; end
			s = '';
			if ~iscell(c); return; end
			for i = 1:length(c)
				if ischar(c{i})
					s = [s '''' c{i} ''', '];
				elseif isnumeric(c{i})
					s = [s '[' num2str(c{i}) '], '];
				elseif iscell(c{i})
					s = [s  opticka.cellAsString(c{i}, false) ', '];
				end
			end
			s = regexprep(s,',\s*$','');
			if addBrackets; s = ['{' s '}']; end
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
			case 0
				y=(height/2)-(size(2)/2);
				if y < 0; y = 0; end
				set(gcf,'Position',[0 y size(1) size(2)]);	
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