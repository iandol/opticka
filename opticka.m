% ======================================================================
%> @brief Opticka stimulus generator class
%>
%> Opticka is a stimulus generator based on Psychophysics toolbox
%>
% ======================================================================
classdef (Sealed) opticka < handle
		
	properties
		%> this is the main runExperiment object
		r 
		%> run in verbose mode?
		verbose
		%> general store for misc properties
		store
	end
	
	properties (SetAccess = private, GetAccess = public)
		%> storage of various paths
		paths
		%> all of the handles to th opticka_ui GUI
		h
		%> version number
		version='0.500'
		%> is this a remote instance?
		remote = 0
		%> omniplex connection
		oc
	end
	
	properties (SetAccess = private, GetAccess = private)
		allowedPropertiesBase='^(workingDir|verbose)$' %used to sanitise passed values on construction
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
		%> More detailed description of what the constructor does.
		%>
		%> @param args are passed as a structure of properties which is
		%> parsed.
		%> @return instance of opticka class.
		% ===================================================================
		function obj = opticka(args)
			if nargin>0 && isstruct(args)
				if nargin>0 && isstruct(args)
					fnames = fieldnames(args); %find our argument names
					for i=1:length(fnames);
						if regexp(fnames{i},obj.allowedPropertiesBase) %only set if allowed property
							obj.salutation(fnames{i},'Configuring setting in baseStimulus constructor');
							obj.(fnames{i})=args.(fnames{i}); %we set up the properies from the arguments as a structure
						end
					end
				end
			end
			obj.initialiseUI;
		end
		
		% ===================================================================
		%> @brief Route calls to private methods (yeah, I know...)
		%>
		%> @param in switch to route to correct method.
		% ===================================================================
		function router(obj,in,vars)
			if ~exist('vars','var')
				vars=[];
			end
			switch in
				case 'saveProtocol'
					obj.saveProtocol;
				case 'loadProtocol'
					obj.loadProtocol(vars);
				case 'deleteProtocol'
					obj.deleteProtocol
					
			end
		end
		
		% ===================================================================
		%> @brief Check if we are remote by checking existance of UI
		%>
		%> @param obj self object
		% ===================================================================
		function amIRemote(obj)
			if ~ishandle(obj.h.uihandle)
				obj.remote = 1;
			end
		end
		
		% ===================================================================
			%> @brief connectToOmniplex
		%> Gets the settings from the UI and connects to omniplex
		%> @param 
		% ===================================================================
		function connectToOmniplex(obj)
			if isempty(obj.oc)
				rPort = obj.gn(obj.h.OKOmniplexPort);
				rAddress = obj.gs(obj.h.OKOmniplexIP);
				status = obj.ping(rAddress);
				if status > 0
					set(obj.h.OKOmniplexStatus,'String','Omniplex: ping ERROR!')
					error('Cannot ping Omniplex, please ensure it is connected!!!')
				end
				in = struct('verbosity',0,'rPort',rPort,'rAddress',rAddress,'protocol','tcp');
				obj.oc = dataConnection(in);
			else
				obj.oc.rPort = obj.gn(obj.h.OKOmniplexPort);
				obj.oc.rAddress = obj.gs(obj.h.OKOmniplexIP);
				data=obj.oc.read(0);
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
						set(obj.h.OKOmniplexStatus,'String','Omniplex: connected')
						break
					else
						fprintf('\nOmniplex master not responding, try: %d\n',loop)
						set(obj.h.OKOmniplexStatus,'String','Omniplex: not responding')
					end
					loop=loop+1;
					pause(0.2);
				end
				drawnow;
			end
		end
		
		% ===================================================================
		%> @brief connectToOmniplex
		%> Gets the settings from the UI and connects to omniplex
		%> @param 
		% ===================================================================
		function sendOmniplexStimulus(obj)
			if obj.oc.checkStatus > 0
				%flush read buffer
				data=obj.oc.read('all');
				tLog=[];
				if obj.oc.checkStatus > 0 %check again to make sure we are still open
					tic
					obj.oc.write('--readStimulus--');
					pause(0.25);
					if ~isempty(obj.r.timeLog);tLog = obj.r.timeLog;end
					obj.r.deleteTimeLog; %so we don't send too much data over TCP
					tmpobj=obj.r;
					obj.oc.writeVar('o',tmpobj);
					if ~isempty(tLog);obj.r.restoreTimeLog(tLog);end
					toc
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
					obj.store.serverCommand = ['!osascript -e ''tell application "Terminal"'' -e ''activate'' -e ''do script "matlab -nodesktop -maci -r \"runServer\""'' -e ''end tell'''];

					obj.paths.temp=tempdir;
					if ~exist(['~' filesep 'MatlabFiles' filesep 'Protocols'],'dir')
						mkdir(['~' filesep 'MatlabFiles' filesep 'Protocols']);
						end
					obj.paths.protocols = ['~' filesep 'MatlabFiles' filesep 'Protocols'];
					cd(obj.paths.protocols);
					obj.paths.currentPath = pwd;
					if ~exist([obj.paths.temp 'History'],'dir')
						mkdir([obj.paths.temp 'History']);
					end
					obj.paths.historypath=[obj.paths.temp 'History'];
				
				elseif ispc
					obj.store.serverCommand = '!matlab -nodesktop -nosplash -r "d=dataConnection(struct(''autoServer'',1,''lPort'',5678));" &';
					obj.paths.temp=tempdir;
					if ~exist('c:\MatlabFiles\Protocols','dir')
						mkdir('c:\MatlabFiles\Protocols')
					end
					obj.paths.protocols = ['c:\MatlabFiles\Protocols'];
					cd(obj.paths.protocols);
					obj.paths.currentPath = pwd;
					if ~exist('c:\MatlabFiles\History','dir')
						mkdir('c:\MatlabFiles\History')
					end
					obj.paths.historypath=[obj.paths.temp 'History'];
				end
				
				obj.store.oldlook=javax.swing.UIManager.getLookAndFeel;
				obj.store.newlook='javax.swing.plaf.metal.MetalLookAndFeel';
				if ismac || ispc
					javax.swing.UIManager.setLookAndFeel(obj.store.newlook);
				end
				uihandle=opticka_ui; %our GUI file
				obj.h=guidata(uihandle);
				obj.h.uihandle = uihandle;
				if ismac || ispc
					javax.swing.UIManager.setLookAndFeel(obj.store.oldlook);
				end
				set(obj.h.OKPanelGrating,'Visible','off')
				drawnow;
				set(obj.h.OKPanelGrating,'Visible','on')
				
				set(obj.h.OKRoot,'Name',['Opticka Stimulus Generator V' obj.version])
				set(obj.h.OKOptickaVersion,'String',['Opticka Stimulus Generator V' obj.version])
				drawnow;
				obj.getScreenVals;
				obj.getTaskVals;
				obj.refreshProtocolsList;
				addlistener(obj.r,'abortRun',@obj.abortRunEvent);
				addlistener(obj.r,'endRun',@obj.endRunEvent);
				addlistener(obj.r,'runInfo',@obj.runInfoEvent);

				setappdata(0,'o',obj); %we stash our object in the root appdata store for retirieval from the UI

				obj.store.nVars = 0;
				obj.store.visibleStimulus = 'grating'; %our default shown stimulus
				obj.store.stimN = 0;
				obj.store.stimList = '';
				obj.store.gratingN = 0;
				obj.store.barN = 0;
				obj.store.dotsN = 0;
				obj.store.spotN = 0;
				obj.store.plaidN = 0;
				obj.store.noiseN = 0;

				set(obj.h.OKVarList,'String','');
				set(obj.h.OKStimList,'String','');
			catch ME
				close(obj.h.uihandle);
				if ismac || ispc
					javax.swing.UIManager.setLookAndFeel(obj.store.oldlook);
				end
				if isappdata(0,'o')
					rmappdata(0,'o');
					clear o;
				end
				errordlg('Problem initialising Opticka, please check errors on the commandline')
				rethrow(ME)
			end
			
		end
		
		% ===================================================================
		%> @brief getScreenVals
		%> Gets the settings from th UI and updates our runExperiment object
		%> @param 
		% ===================================================================
		function getScreenVals(obj)
			
			if isempty(obj.r)
				set(obj.h.OKOptickaVersion,'String','Initialising Stimulus object...')
				drawnow
				obj.r = runExperiment;
				s=cell(obj.r.maxScreen+1,1);
				for i=0:obj.r.maxScreen
					s{i+1} = num2str(i);
				end
				set(obj.h.OKSelectScreen,'String', s);
				set(obj.h.OKSelectScreen, 'Value', obj.r.screen+1);
				clear s;
				set(obj.h.OKOptickaVersion,'String',['Opticka Stimulus Generator V' obj.version])
				drawnow
			end
			
			obj.r.screen = obj.gv(obj.h.OKSelectScreen)-1;
			
			obj.r.distance = obj.gd(obj.h.OKMonitorDistance);
			obj.r.pixelsPerCm = obj.gd(obj.h.OKPixelsPerCm);
			obj.r.screenXOffset = obj.gd(obj.h.OKXCenter);
			obj.r.screenYOffset = obj.gd(obj.h.OKYCenter);
			
			value = obj.gv(obj.h.OKGLSrc);
			obj.r.srcMode = obj.gs(obj.h.OKGLSrc, value);
			
			value = obj.gv(obj.h.OKGLDst);
			obj.r.dstMode = obj.gs(obj.h.OKGLDst, value);
			
			obj.r.blend = obj.gv(obj.h.OKOpenGLBlending);
			
			s=str2num(get(obj.h.OKWindowSize,'String')); %#ok<ST2NM>
			if isempty(s)
				obj.r.windowed = 0;
			else
				obj.r.windowed = s;
			end
			
			obj.r.hideFlash = obj.gv(obj.h.OKHideFlash);
			obj.r.antiAlias = obj.gd(obj.h.OKAntiAliasing);
			obj.r.photoDiode = obj.gv(obj.h.OKUsePhotoDiode);
			obj.r.movieSettings.record = obj.gv(obj.h.OKrecordMovie);
			obj.r.verbose = obj.gv(obj.h.OKVerbose);
			obj.r.debug = obj.gv(obj.h.OKDebug);
			obj.r.visualDebug = obj.gv(obj.h.OKDebug);
			obj.r.backgroundColour = obj.gn(obj.h.OKbackgroundColour);
			obj.r.fixationPoint = obj.gv(obj.h.OKFixationSpot);
			obj.r.useLabJack = obj.gv(obj.h.OKuseLabJack);
			obj.r.serialPortName = obj.gs(obj.h.OKSerialPortName);
			
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
			obj.r.task.fps = obj.r.screenVals.fps;
			obj.r.task.trialTime = obj.gd(obj.h.OKtrialTime);
			obj.r.task.randomSeed = obj.gn(obj.h.OKRandomSeed);
			v = obj.gv(obj.h.OKrandomGenerator);
			obj.r.task.randomGenerator = obj.gs(obj.h.OKrandomGenerator,v);
			obj.r.task.itTime = obj.gd(obj.h.OKitTime);
			obj.r.task.randomise = obj.gv(obj.h.OKRandomise);
			obj.r.task.isTime = obj.gd(obj.h.OKisTime);
			obj.r.task.nTrials = obj.gd(obj.h.OKnTrials);
			obj.r.task.realTime = obj.gv(obj.h.OKrealTime);
			obj.r.task.initialiseRandom;
			obj.r.task.randomiseStimuli;
			
		end
		
		% ===================================================================
		%> @brief clearStimulusList
		%> Erase any stimuli in the list.
		%> @param 
		% ===================================================================
		function clearStimulusList(obj)
			if ~isempty(obj.r)
				if ~isempty(obj.r.stimulus)
					obj.r.stimulus = {};
					obj.r.updatesList();
				end
			end
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
			n = length(obj.r.stimulus); %get what stimulus fields we have
			if ~isempty(n)
				get(obj.h.OKVarList,'Value');
				obj.r.stimulus = obj.r.stimulus(1:n-1);
				if isempty(obj.r.stimulus)
					obj.r.stimulus={};
				end
				
				obj.r.updatesList;
				
				obj.refreshStimulusList;
			else
				obj.r.updatesList;
				set(obj.h.OKStimList,'Value',1);
				set(obj.h.OKStimList,'String','');
			end
		end
		
		% ===================================================================
		%> @brief addGrating
		%> 
		%> @param 
		% ===================================================================
		function addGrating(obj)
			tmp = struct;
			
			tmp.gabor = obj.gv(obj.h.OKPanelGratinggabor)-1;
			tmp.xPosition = obj.gd(obj.h.OKPanelGratingxPosition);
			tmp.yPosition = obj.gd(obj.h.OKPanelGratingyPosition);
			tmp.size = obj.gd(obj.h.OKPanelGratingsize);
			tmp.sf = obj.gd(obj.h.OKPanelGratingsf);
			tmp.tf = obj.gd(obj.h.OKPanelGratingtf);
			tmp.contrast = obj.gd(obj.h.OKPanelGratingcontrast);
			tmp.phase = obj.gd(obj.h.OKPanelGratingphase);
			tmp.speed = obj.gd(obj.h.OKPanelGratingspeed);
			tmp.angle = obj.gd(obj.h.OKPanelGratingangle);
			tmp.motionAngle = obj.gd(obj.h.OKPanelGratingmotionAngle);
			tmp.startPosition = obj.gd(obj.h.OKPanelGratingstartPosition);
			tmp.aspectRatio = obj.gd(obj.h.OKPanelGratingaspectRatio);
			tmp.contrastMult = obj.gd(obj.h.OKPanelGratingcontrastMult);
			tmp.driftDirection = obj.gv(obj.h.OKPanelGratingdriftDirection);
			tmp.colour = obj.gn(obj.h.OKPanelGratingcolour);
			tmp.alpha = obj.gd(obj.h.OKPanelGratingalpha);
			tmp.rotationMethod = obj.gv(obj.h.OKPanelGratingrotationMethod);
			tmp.mask = obj.gv(obj.h.OKPanelGratingmask);
			tmp.disableNorm = obj.gv(obj.h.OKPanelGratingdisableNorm);
			tmp.spatialConstant = obj.gn(obj.h.OKPanelGratingspatialConstant);
			tmp.sigma = obj.gn(obj.h.OKPanelGratingsigma);
			tmp.useAlpha = obj.gv(obj.h.OKPanelGratinguseAlpha);
			tmp.smoothMethod = obj.gv(obj.h.OKPanelGratingsmoothMethod);
			tmp.correctPhase = obj.gv(obj.h.OKPanelGratingcorrectPhase);
			
			obj.r.stimulus{obj.r.sList.n+1} = gratingStimulus(tmp);
			
			obj.r.updatesList;
			obj.refreshStimulusList;
		end
		
		% ===================================================================
		%> @brief addBar
		%> Add bar stimulus
		%> @param 
		% ===================================================================
		function addBar(obj)
			tmp = struct;
			tmp.angle = obj.gd(obj.h.OKPanelBarangle);
			tmp.xPosition = obj.gd(obj.h.OKPanelBarxPosition);
			tmp.yPosition = obj.gd(obj.h.OKPanelBaryPosition);
			tmp.barLength = obj.gd(obj.h.OKPanelBarbarLength);
			tmp.barWidth = obj.gd(obj.h.OKPanelBarbarWidth);
			tmp.contrast = obj.gd(obj.h.OKPanelBarcontrast);
			tmp.scale = obj.gd(obj.h.OKPanelBarscale);
			v = obj.gv(obj.h.OKPanelBartype);
			tmp.type = obj.gs(obj.h.OKPanelBartype,v);
			v = obj.gv(obj.h.OKPanelBarinterpMethod);
			tmp.interpMethod = obj.gs(obj.h.OKPanelBarinterpMethod,v);
			tmp.startPosition = obj.gd(obj.h.OKPanelBarstartPosition);
			tmp.colour = obj.gn(obj.h.OKPanelBarcolour);
			tmp.alpha = obj.gd(obj.h.OKPanelBaralpha);
			tmp.speed = obj.gd(obj.h.OKPanelBarspeed);
			
			obj.r.stimulus{obj.r.sList.n+1} = barStimulus(tmp);
			
			obj.r.updatesList;
			obj.refreshStimulusList;			
		end
		
		% ===================================================================
		%> @brief addDots
		%> Gets the settings from th UI and updates our runExperiment object
		%> @param 
		% ===================================================================
		function addDots(obj)
			tmp = struct;
			tmp.xPosition = obj.gd(obj.h.OKPanelDotsxPosition);
			tmp.yPosition = obj.gd(obj.h.OKPanelDotsyPosition);
			tmp.size = obj.gd(obj.h.OKPanelDotssize);
			tmp.angle = obj.gd(obj.h.OKPanelDotsangle);
			tmp.coherence = obj.gd(obj.h.OKPanelDotscoherence);
			tmp.nDots = obj.gd(obj.h.OKPanelDotsnDots);
			tmp.dotSize = obj.gd(obj.h.OKPanelDotsdotSize);
			tmp.speed = obj.gd(obj.h.OKPanelDotsspeed);
			tmp.colour = obj.gn(obj.h.OKPanelDotscolour);
			tmp.alpha = obj.gd(obj.h.OKPanelDotsalpha);
			tmp.dotType = obj.gv(obj.h.OKPanelDotsdotType)-1;
			v = obj.gv(obj.h.OKPanelDotstype);
			tmp.type = obj.gs(obj.h.OKPanelDotstype,v);
			
			obj.r.stimulus{obj.r.sList.n+1} = dotsStimulus(tmp);
			
			obj.r.updatesList;
			obj.refreshStimulusList;
		end
		
		% ===================================================================
		%> @brief addSpot
		%> Gets the settings from th UI and updates our runExperiment object
		%> @param 
		% ===================================================================
		function addSpot(obj)
			tmp = struct;
			tmp.xPosition = obj.gd(obj.h.OKPanelSpotxPosition);
			tmp.yPosition = obj.gd(obj.h.OKPanelSpotyPosition);
			tmp.size = obj.gd(obj.h.OKPanelSpotsize);
			tmp.angle = obj.gd(obj.h.OKPanelSpotangle);
			tmp.speed = obj.gd(obj.h.OKPanelSpotspeed);
			tmp.contrast = obj.gd(obj.h.OKPanelSpotcontrast);
			tmp.colour = obj.gn(obj.h.OKPanelSpotcolour);
			tmp.flashTime = obj.gn(obj.h.OKPanelSpotflashTime);
			tmp.alpha = obj.gd(obj.h.OKPanelSpotalpha);
			tmp.startPosition = obj.gd(obj.h.OKPanelSpotstartPosition);
			v = obj.gv(obj.h.OKPanelSpottype);
			tmp.type = obj.gs(obj.h.OKPanelSpottype,v);
			tmp.flashOn = logical(obj.gv(obj.h.OKPanelSpotflashOn));
			
			obj.r.stimulus{obj.r.sList.n+1} = spotStimulus(tmp);
			
			obj.r.updatesList;
			obj.refreshStimulusList;
		end
		
		% ===================================================================
		%> @brief editStimulus
		%> Gets the settings from th UI and updates our runExperiment object
		%> @param 
		% ===================================================================
		function editStimulus(obj)
			v=obj.gv(obj.h.OKStimList);
			family=obj.r.stimulus{v}.family;
			switch family
				case 'grating'
					fragment = 'OKPanelGrating';
				case 'spot'
					fragment = 'OKPanelSpot';
				otherwise 
					fragment = 'OKPanelSpot';
			end
			out = obj.dealUItoStructure(fragment);
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
			
			if isempty(obj.r.task.nVars);obj.r.task.nVars=0;end
			revertN = obj.r.task.nVars;
			
			try
			
				obj.r.task.nVar(obj.r.task.nVars+1).name = obj.gs(obj.h.OKVariableName);
				obj.r.task.nVar(obj.r.task.nVars+1).values = obj.gn(obj.h.OKVariableValues);
				obj.r.task.nVar(obj.r.task.nVars+1).stimulus = obj.gn(obj.h.OKVariableStimuli);

				obj.r.task.randomiseStimuli;
				obj.store.nVars = obj.r.task.nVars;

				obj.refreshVariableList;
			
			catch ME
				
				obj.r.task.nVars = revertN;
				obj.r.task.nVars = obj.r.task.nVars(1:revertN);
				rethrow ME;
				
			end
			
		end
		
		% ===================================================================
		%> @brief deleteVariable
		%> Gets the settings from th UI and updates our runExperiment object
		%> @param 
		% ===================================================================
		function deleteVariable(obj)
			
			if isobject(obj.r.task)
				obj.r.task.nVars = obj.r.task.nVars - 1;
				obj.store.nVars = obj.r.task.nVars;
				obj.r.task.nVar=obj.r.task.nVar(1:obj.r.task.nVars);
				if obj.r.task.nVars > 0
					obj.r.task.randomiseStimuli;
				end
			end
			
			if obj.r.task.nVars<0;obj.r.task.nVars=0;end
			if obj.store.nVars<0;obj.store.nVars=0;end
			
			obj.refreshVariableList;
			
		end

	end
	
	%========================================================
	methods ( Access = private ) %----------PRIVATE METHODS
	%========================================================
	
		% ===================================================================
		%> @brief 
		%> 
		%> @param 
		%> @return
		% ===================================================================
		function out = dealUItoStructure(obj,fragment)
			if ~exist('fragment','var')
				fragment = 'OKPanelGrating';
			end
			tt=fieldnames(obj.h);
			a=1;
			out=[];
			for i=1:length(tt)
				[ii,oo]=regexp(tt{i},fragment);
				l=length(tt{i});
				if ~isempty(ii) && oo < l
					out(a).name=tt{i}(ii:end);
					out(a).fragment=tt{i}(oo:end);
					a=a+1;
				end
			end
		end
		
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
			tmp = obj;
			tmp.store.oldlook = [];
			uisave('tmp','new protocol');
			cd(obj.paths.currentPath);
			obj.refreshProtocolsList;
			
		end
		
		% ===================================================================
		%> @brief Load Protocol
		%> Load Protocol
		%> @param uiload do we show a uiload dialog?
		% ===================================================================
		function loadProtocol(obj,ui)
			
			file = [];
			
			if ~exist('ui','var') || isempty(ui)
				ui=0;
			end
			
			if ui == 0
				v = obj.gv(obj.h.OKProtocolsList);
				file = obj.gs(obj.h.OKProtocolsList,v);
			end
			
			obj.paths.currentPath = pwd;
			cd(obj.paths.protocols);
			
			if isempty(file)
				uiload;
			else
				load(file);
			end
			
			if exist('tmp','var') && isa(tmp,'opticka')
				
				%copy screen parameters
				
				set(obj.h.OKXCenter,'String', num2str(tmp.r.screenXOffset));
				set(obj.h.OKYCenter,'String', num2str(tmp.r.screenYOffset));
				
				list = obj.gs(obj.h.OKGLSrc);
				val = obj.findValue(list,tmp.r.srcMode);
				obj.r.srcMode = list{val};
				
				list = obj.gs(obj.h.OKGLDst);
				val = obj.findValue(list,tmp.r.dstMode);
				obj.r.dstMode = list{val};
				
				set(obj.h.OKOpenGLBlending,'Value', tmp.r.blend);
				set(obj.h.OKAntiAliasing,'String', num2str(tmp.r.antiAlias));
				string = num2str(tmp.r.backgroundColour);
				string = regexprep(string,'\s+',' '); %collapse spaces
				set(obj.h.OKbackgroundColour,'String',string);
				
				%copy task parameters
				if isempty(tmp.r.task)
					obj.r.task = stimulusSequence;
					obj.r.task.randomiseStimuli;
				else
					obj.r.task = tmp.r.task;
				end
				set(obj.h.OKtrialTime, 'String', num2str(obj.r.task.trialTime));
				set(obj.h.OKRandomSeed, 'String', num2str(obj.r.task.randomSeed));
				set(obj.h.OKitTime,'String',num2str(obj.r.task.itTime));
				set(obj.h.OKisTime,'String',num2str(obj.r.task.isTime));
				set(obj.h.OKnTrials,'String',num2str(obj.r.task.nTrials));
				
				if iscell(tmp.r.stimulus);
					obj.r.stimulus = tmp.r.stimulus;
				else
					errordlg('Sorry, this protocol is not compatible with current opticka, please remake');
					obj.r.stimulus={};
				end
				clear tmp;
				
				obj.r.updatesList;				
				obj.refreshStimulusList;
				obj.refreshVariableList;
				
				if obj.r.task.nVars > 0
					set(obj.h.OKDeleteVariable,'Enable','on');
				end
				if ~isempty(obj.r.stimulus)
					set(obj.h.OKDeleteStimulus,'Enable','on');
					set(obj.h.OKModifyStimulus,'Enable','on');
					set(obj.h.OKStimulusUp,'Enable','on');
					set(obj.h.OKStimulusDown,'Enable','on');
				end
				
			end
			
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
			
			filelist=cell(size(files));
			for i=1:length(files)
				filename = files(i).name;
				filelist{i} = filename;
			end
			
			set(obj.h.OKProtocolsList,'Value', 1);
			set(obj.h.OKProtocolsList,'String',filelist);
			
		end
		
		% ===================================================================
		%> @brief refreshStimulusList
		%> refreshes the stimulus list in th UI after adding new stimulus
		%> @param 
		% ===================================================================
		function refreshStimulusList(obj)
			pos = get(obj.h.OKStimList, 'Value');
			str = cell(obj.r.sList.n,1);
			for i=1:obj.r.sList.n
				s = obj.r.stimulus{i};
				switch s.family
					case 'grating'
						if s.gabor == 0
							name = 'Grating ';
						else
							name = 'Gabor ';
						end
						tstr = [name num2str(i) ':'];
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
					case 'bar'
						x=s.xPosition;
						y=s.yPosition;
						a=s.angle;
						str{i} = ['Bar ' num2str(i) ': x=' num2str(x) ' y=' num2str(y) ' ang=' num2str(a)];
					case 'dots'
						x=s.xPosition;
						y=s.yPosition;
						sz=s.size;
						a=s.angle;
						c=s.coherence;
						str{i} = ['Dots ' num2str(i) ': x=' num2str(x) ' y=' num2str(y) ' sz=' num2str(sz) ' ang=' num2str(a) ' coh=' num2str(c)];
					case 'spot'
						x=s.xPosition;
						y=s.yPosition;
						sz=s.size;
						c=s.contrast;
						str{i} = ['Spot ' num2str(i) ': x=' num2str(x) ' y=' num2str(y) ' sz=' num2str(sz) ' c=' num2str(c)];
				end
			end
			if pos > length(str)
				pos = 1;
			end
			set(obj.h.OKStimList,'String', str);
			set(obj.h.OKStimList, 'Value', pos);
		end
		
		% ===================================================================
		%> @brief getstring
		%> 
		%> @param 
		% ===================================================================
		function refreshVariableList(obj)
			str = cell(obj.r.task.nVars,1);
			for i=1:obj.r.task.nVars
				str{i} = [obj.r.task.nVar(i).name ' on Stim: ' num2str(obj.r.task.nVar(i).stimulus) '|' num2str(obj.r.task.nVar(i).values)];
				str{i}=regexprep(str{i},'(  )+',' ');
			end
			set(obj.h.OKVarList,'Value',1);
			set(obj.h.OKVarList,'String',str);
		end
		
		% ===================================================================
		%> @brief fprintf Wrapper function
		%> fprintf Wrapper function
		%> @param in -- Calling function
		%> @param message -- message to print
		% ===================================================================
		function salutation(obj,in,message)
			if obj.verbose==1
				if ~exist('in','var')
					in = 'undefined';
				end
				if exist('message','var')
					fprintf([message ' | ' in '\n']);
				else
					fprintf(['\n' obj.family ' stimulus, ' in '\n']);
				end
			end
		end
		
		% ===================================================================
		%> @brief find the value in a cell string list
		%> 
		%> @param 
		% ===================================================================
		function value = findValue(obj,list,entry)
			value = 1;
			for i=1:length(list)
				if regexp(list{i},entry)
					value = i;
					return
				end
			end
		end
		
		% ===================================================================
		%> @brief find the value in a cell string list
		%> 
		%> @param 
		% ===================================================================
		function value = abortRunEvent(obj,src,evtdata)
			fprintf('abortRun triggered!!!\n')
			if isa(obj.oc,'dataConnection') && obj.oc.isOpen == 1
				obj.oc.write('--abort--');
			end
		end
		
		% ===================================================================
		%> @brief find the value in a cell string list
		%> 
		%> @param 
		% ===================================================================
		function value = endRunEvent(obj,src,evtdata)
			fprintf('endRun triggered!!!\n')
		end
		
		% ===================================================================
		%> @brief find the value in a cell string list
		%> 
		%> @param 
		% ===================================================================
		function value = runInfoEvent(obj,src,evtdata)
			fprintf('runInfo triggered!!!\n')
		end
		
		% ===================================================================
		%> @brief getstring
		%> 
		%> @param 
		% ===================================================================
		function outhandle = gs(obj,inhandle,value)
		%quick alias to get string value
			if exist('value','var')
				s = get(inhandle,'String');
				outhandle = s{value};
			else
				outhandle = get(inhandle,'String');
			end
		end
		
		% ===================================================================
		%> @brief getdouble
		%> 
		%> @param 
		% ===================================================================
		function outhandle = gd(obj,inhandle)
		%quick alias to get double value
			outhandle = str2double(get(inhandle,'String'));
		end
		
		% ===================================================================
		%> @brief getnumber
		%> 
		%> @param 
		% ===================================================================
		function outhandle = gn(obj,inhandle)
		%quick alias to get number value
			outhandle = str2num(get(inhandle,'String'));
		end
		
		% ===================================================================
		%> @brief getvalue
		%> 
		%> @param 
		% ===================================================================
		function outhandle = gv(obj,inhandle)
		%quick alias to get ui value
			outhandle = get(inhandle,'Value');
		end
		
		% ===================================================================
		%> @brief saveobj
		%> 
		%> @param obj
		% ===================================================================
		function obj = saveobj(obj)
			obj.store.oldlook=[]; %need to remove this as java objects not supported for save in matlab
			obj.oc = [];
		end
		
		% ===================================================================
		%> @brief try to work around GUIDE OS X bugs
		%> 
		%> @param 
		% ===================================================================
		function fixUI(obj)
			ch = findall(obj.h.uihandle);
			set(obj.h.uihandle,'Units','pixels');
			for k = 1:length(ch)
				if isprop(ch(k),'Units')
					set(ch(k),'Units','pixels');
				end
				if isprop(ch(k),'FontName')
					set(ch(k),'FontName','verdana');
				end
			end
		end
		
	end
	
	%========================================================
	methods ( Static ) %----------Static METHODS
	%========================================================
	
		% ===================================================================
		%> @brief ping a network address
		%>	We send a single packet and wait only 10ms to ensure we have a fast connection
		%> @param rAddress remote address
		% ===================================================================
		function status = ping(rAddress)
			
			if ispc
				cmd = 'ping -n 1 -w 10 ';
			else
				cmd = 'ping -c 1 -W 10 ';
			end
			[status,~]=system([cmd rAddress]);
		end
	end
	
	end