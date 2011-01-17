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
		version='0.492'
		%> ?
		load
	end
	
	properties (SetAccess = private, GetAccess = private)
		allowedPropertiesBase='^(workingDir|verbose)$' %used to sanitise passed values on construction
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
		function router(obj,in)
			switch in
				case 'saveProtocol'
					obj.saveProtocol;
				case 'loadProtocol'
					obj.loadProtocol;
			end
		end
		
	end
	
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

					obj.store.serverCommand = ['!osascript -e ''tell application "Terminal"'' -e ''activate'' -e ''do script "' obj.paths.startServer '"'' -e ''end tell'''];

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
					obj.store.oldlook=javax.swing.UIManager.getLookAndFeel;
					javax.swing.UIManager.setLookAndFeel('javax.swing.plaf.metal.MetalLookAndFeel');
				elseif ispc

					obj.store.serverCommand = ['!matlab -nodesktop -nosplash -r "d=dataConnection(struct(''autoServer'',1,''lPort'',5678));"'];
					obj.paths.temp=tempdir;
					if ~exist(['c:\MatlabFiles\Protocols'],'dir')
						mkdir(['c:\MatlabFiles\Protocols'])
					end
					obj.paths.protocols = ['c:\MatlabFiles\Protocols'];
					cd(obj.paths.protocols);
					obj.paths.currentPath = pwd;
					if ~exist(['c:\MatlabFiles\History'],'dir')
						mkdir(['c:\MatlabFiles\History'])
					end
					obj.paths.historypath=[obj.paths.temp 'History'];
				end
				uihandle=opticka_ui; %our GUI file
				obj.h=guidata(uihandle);
				obj.h.uihandle = uihandle;
				if ismac
					javax.swing.UIManager.setLookAndFeel(obj.store.oldlook);
				end

				set(obj.h.OKRoot,'Name',['Opticka Stimulus Generator V' obj.version])
				set(obj.h.OKOptickaVersion,'String',['Opticka Stimulus Generator V' obj.version])
				drawnow;
				obj.getScreenVals;
				obj.getTaskVals;
				obj.refreshProtocolsList;

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
				if isappdata(0,'o')
					rmappdata(0,'o');
					clear o;
				end
				close(uihandle);
				errordlg('Problen in initialising Opticka, please check errors on commandline')
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
				set(obj.h.OKOptickaVersion,'String',['Opticka Stimulus Generator V' obj.version])
				drawnow
			end
			obj.r.distance = obj.gd(obj.h.OKMonitorDistance);
			obj.r.pixelsPerCm = obj.gd(obj.h.OKPixelsPerCm);
			obj.r.screenXOffset = obj.gd(obj.h.OKXCenter);
			obj.r.screenYOffset = obj.gd(obj.h.OKYCenter);
			
			value = obj.gv(obj.h.OKGLSrc);
			obj.r.srcMode = obj.gs(obj.h.OKGLSrc, value);
			
			value = obj.gv(obj.h.OKGLDst);
			obj.r.dstMode = obj.gs(obj.h.OKGLDst, value);
			
			obj.r.blend = obj.gv(obj.h.OKOpenGLBlending);
			
			s=str2num(get(obj.h.OKWindowSize,'String'));
			if isempty(s)
				obj.r.windowed = 0;
			else
				obj.r.windowed = s;
			end
			
			obj.r.hideFlash = obj.gv(obj.h.OKHideFlash);
			obj.r.antiAlias = obj.gd(obj.h.OKAntiAliasing);
			obj.r.photoDiode = obj.gv(obj.h.OKUsePhotoDiode);
			obj.r.verbose = obj.gv(obj.h.OKVerbose);
			obj.r.debug = obj.gv(obj.h.OKDebug);
			obj.r.visualDebug = obj.gv(obj.h.OKDebug);
			obj.r.backgroundColour = obj.gn(obj.h.OKbackgroundColour);
			obj.r.fixationPoint = obj.gv(obj.h.OKFixationSpot);
			obj.r.useLabJack = obj.gv(obj.h.OKuseLabJack);
			obj.r.serialPortName = obj.gs(obj.h.OKSerialPortName);
			
		end
		
		% ===================================================================
		%> @brief getScreenVals
		%> Gets the settings from th UI and updates our runExperiment object
		%> @param 
		% ===================================================================
		function getTaskVals(obj)
			
			if isempty(obj.r.task)
				obj.r.task = stimulusSequence;
				obj.r.task.randomiseStimuli;
			end
			obj.r.task.trialTime = obj.gd(obj.h.OKtrialTime);
			obj.r.task.randomSeed = obj.gn(obj.h.OKRandomSeed);
			if isempty(obj.r.task.randomSeed) || isnan(obj.r.task.randomSeed)
				obj.r.task.randomSeed = GetSecs;
			end
			v = obj.gv(obj.h.OKrandomGenerator);
			obj.r.task.randomGenerator = obj.gs(obj.h.OKrandomGenerator,v);
			obj.r.task.itTime = obj.gd(obj.h.OKitTime);
			obj.r.task.randomise = obj.gv(obj.h.OKRandomise);
			obj.r.task.isTime = obj.gd(obj.h.OKisTime);
			obj.r.task.nTrials = obj.gd(obj.h.OKnTrials);
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
			tmp.colour = obj.gn(obj.h.OKPanelSpotcolour);
			tmp.flashTime = obj.gn(obj.h.OKPanelSpotflashTime);
			tmp.alpha = obj.gd(obj.h.OKPanelSpotalpha);
			tmp.startPosition = obj.gd(obj.h.OKPanelSpotstartPosition);
			v = obj.gv(obj.h.OKPanelSpottype);
			tmp.type = obj.gs(obj.h.OKPanelSpottype,v);
			
			obj.r.stimulus{obj.r.sList.n+1} = spotStimulus(tmp);
			
			obj.r.updatesList;
			obj.refreshStimulusList;
		end
		
		% ===================================================================
		%> @brief addVariable
		%> Gets the settings from th UI and updates our runExperiment object
		%> @param 
		% ===================================================================
		function addVariable(obj)
			
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
			end
			
			if obj.r.task.nVars<0;obj.r.task.nVars=0;end
			if obj.store.nVars<0;obj.store.nVars=0;end
			
			obj.refreshVariableList;
			
		end
	end
	
	%========================================================
	methods ( Access = protected ) %----------PRIVATE METHODS
	%========================================================
	
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
		
		function dealUItoStructure(obj)
			tt=fieldnames(obj.h);
			for i=1:length(tt)
				
			end
		end
		
		% ===================================================================
		%> @brief Load Protocol
		%> Load Protocol
		%> @param 
		% ===================================================================
		function loadProtocol(obj)
			
			v = obj.gv(obj.h.OKProtocolsList);
			file = obj.gs(obj.h.OKProtocolsList,v);
			
			obj.paths.currentPath = pwd;
			cd(obj.paths.protocols);
			
			if isempty(file)
				uiload('MATLAB');
			else
				load(file);
			end
			
			if isa(tmp,'opticka')
				
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
				set(obj.h.OKAntiAliasing,'Value', tmp.r.antiAlias);
				set(obj.h.OKbackgroundColour,'String',num2str(tmp.r.backgroundColour));
				
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
			str = cell(obj.r.sList.n,1);
			for i=1:obj.r.sList.n
				s = obj.r.stimulus{i};
				switch s.family
					case 'grating'
						x=s.xPosition;
						y=s.yPosition;
						c=s.contrast;
						a=s.angle;
						sz=s.size;
						if s.gabor == 0
							name = 'Grating ';
						else
							name = 'Gabor ';
						end
						str{i} = [name num2str(i) ': x=' num2str(x) ' y=' num2str(y) ' c=' num2str(c) ' ang=' num2str(a) ' sz=' num2str(sz)];
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
						str{i} = ['Dots ' num2str(i) ': x=' num2str(x) ' y=' num2str(y) ' sz=' num2str(sz) ' ang=' num2str(a)];
					case 'spot'
						x=s.xPosition;
						y=s.yPosition;
						sz=s.size;
						str{i} = ['Spot ' num2str(i) ': x=' num2str(x) ' y=' num2str(y) ' sz=' num2str(sz)];
				end
			end
			set(obj.h.OKStimList,'String', str);
			set(obj.h.OKStimList, 'Value', 1);
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
		end
		
		% ===================================================================
		%> @brief try to work around GUIDE OS X bugs
		%> 
		%> @param 
		% ===================================================================
		function fixUI(obj)
			ch = findall(obj.handles.uihandle);
			set(obj.handles.uihandle,'Units','pixels');
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
end