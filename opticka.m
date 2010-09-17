classdef opticka < dynamicprops
	%OPTICKA GUI controller class
	%   Detailed explanation to come
	properties
		workingDir = '~/Code/opticka/';
		paths
		h
		r
		verbose
		store
		version='0.43'
	end
	
	properties (SetAccess = private, GetAccess = public)
		handles
		load
	end
	properties (SetAccess = private, GetAccess = private)
		allowedPropertiesBase='^(workingDir|verbose)$'
	end
	
	methods
		%-------------------CONSTRUCTOR----------------------%
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
		
		%-------------------Start the UI----------------------%
		function initialiseUI(obj)
			if ismac
				obj.paths.temp=tempdir;
				if ~exist(['~' filesep 'MatlabFiles' filesep 'Protocols'],'dir')
					mkdir(['~' filesep 'MatlabFiles' filesep 'Protocols']);
				end
				obj.paths.protocols = ['~' filesep 'MatlabFiles' filesep 'Protocols'];
				if ~exist([obj.paths.temp 'History'],'dir')
					mkdir([obj.paths.temp 'History']);
				end
				obj.paths.historypath=[obj.paths.temp 'History'];
				obj.store.oldlook=javax.swing.UIManager.getLookAndFeel;
				javax.swing.UIManager.setLookAndFeel('javax.swing.plaf.metal.MetalLookAndFeel');
			elseif ispc
				obj.paths.temp=tempdir;
				if ~exist(['c:\MatlabFiles\Protocols'],'dir')
					mkdir(['c:\MatlabFiles\Protocols'])
				end
				obj.paths.protocols = ['c:\MatlabFiles\Protocols'];
				if ~exist(['c:\MatlabFiles\History'],'dir')
					mkdir(['c:\MatlabFiles\History'])
				end
				obj.paths.historypath=[obj.paths.temp 'History'];
			end
			obj.handles.uihandle=opticka_ui; %our GUI file
			obj.h=guidata(obj.handles.uihandle);
			if ismac
				javax.swing.UIManager.setLookAndFeel(obj.store.oldlook);
			end
			
			set(obj.h.OKRoot,'Name',['Opticka Stimulus Generator V' obj.version])
			set(obj.h.OKOptickaVersion,'String',['Opticka Stimulus Generator V' obj.version])
			obj.getScreenVals;
			obj.getTaskVals;
			setappdata(0,'o',obj); %we stash our object in the root appdata store
			
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
			
		end
				
		function getScreenVals(obj)
			
			if isempty(obj.r)
				obj.r = runExperiment;
			end
			obj.r.distance = obj.gd(obj.h.OKMonitorDistance);
			obj.r.pixelsPerCm = obj.gd(obj.h.OKPixelsPerCm);
			obj.r.screenXOffset = obj.gd(obj.h.OKXCenter);
			obj.r.screenYOffset = obj.gd(obj.h.OKYCenter);
			
			value = obj.gv(obj.h.OKGLSrc);
			string = obj.gs(obj.h.OKGLSrc);
			obj.r.srcMode = string{value};
			
			value = obj.gv(obj.h.OKGLDst);
			string = obj.gs(obj.h.OKGLDst);
			obj.r.dstMode = string{value};
			
			obj.r.blend = obj.gv(obj.h.OKOpenGLBlending);
			if regexp(get(obj.h.OKWindowSize,'String'),'[]')
				obj.r.windowed = 1;
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
			
		end
		
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
			
		end
		%---------------------------------------------------------
		function clearStimulusList(obj)
			if ~isempty(obj.r)
				if ~isempty(obj.r.stimulus)
					obj.r.stimulus = [];
					obj.store.stimN = 0;
					obj.store.gratingN = 0;
					obj.store.barN = 0;
					obj.store.dotsN = 0;
					obj.store.spotN = 0;
					obj.store.plaidN = 0;
					obj.store.noiseN = 0;
				end
			end
			set(obj.h.OKStimList,'String','');
		end
		
		%---------------------------------------------------------
		function clearVariableList(obj)
			if ~isempty(obj.r)
				if ~isempty(obj.r.task)
					obj.r.task = [];
				end
			end
			set(obj.h.OKVarList,'String','');
		end
		
		%---------------------------------------------------------
		function deleteStimulus(obj)
			n = fieldnames(obj.r.stimulus); %get what stimulus fields we have
			if ~isempty(n)
				s=length(obj.r.stimulus.(n{end})); %how many of that stim are there?
				obj.r.stimulus.(n{end}) = obj.r.stimulus.(n{end})(1:s-1);
				if isempty(obj.r.stimulus.(n{end}))
					obj.r.stimulus=rmfield(obj.r.stimulus,n{end});
				end
				
				obj.store.stimN = obj.store.stimN - 1;
				if obj.store.stimN < 0;obj.store.stimN = 0;end
				obj.r.updatesList;
				
				string = obj.gs(obj.h.OKStimList);
				set(obj.h.OKStimList,'String',string(1:end-1));
			end
			
		end
		
		%---------------------------------------------------------
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
			
			obj.r.stimulus.g(obj.r.sList.gN + 1) = gratingStimulus(tmp);
			
			obj.r.updatesList;
			
			obj.store.gratingN = obj.r.sList.gN;
			string = obj.gs(obj.h.OKStimList);
			switch tmp.gabor
				case 0
					string{length(string)+1} = ['Grating #' num2str(obj.r.sList.gN)];
				case 1
					string{length(string)+1} = ['Gabor #' num2str(obj.r.sList.gN)];
			end
			set(obj.h.OKStimList,'String',string);
			
			obj.store.stimList = obj.r.sList.list;
			
		end
		
		function addBar(obj)
			tmp = struct;
			tmp.xPosition = obj.gd(obj.h.OKPanelBarxPosition);
			tmp.yPosition = obj.gd(obj.h.OKPanelBaryPosition);
			tmp.barLength = obj.gd(obj.h.OKPanelBarbarLength);
			tmp.barWidth = obj.gd(obj.h.OKPanelBarbarWidth);
			tmp.contrast = obj.gd(obj.h.OKPanelBarcontrast);
			v = obj.gv(obj.h.OKPanelBartype);
			tmp.type = obj.gs(obj.h.OKPanelBartype,v);
			tmp.startPosition = obj.gd(obj.h.OKPanelBarstartPosition);
			tmp.colour = obj.gn(obj.h.OKPanelBarcolour);
			tmp.alpha = obj.gd(obj.h.OKPanelBaralpha);
			
			obj.r.stimulus.b(obj.r.sList.bN + 1) = barStimulus(tmp);
			
			obj.r.updatesList;
			
			obj.store.barN = obj.r.sList.bN;
			string = obj.gs(obj.h.OKStimList);
			string{length(string)+1} = ['Bar #' num2str(obj.r.sList.bN)];
			set(obj.h.OKStimList,'String',string);
			
			obj.store.stimList = obj.r.sList.list;
			
		end
		
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
			
			obj.r.stimulus.d(obj.r.sList.dN + 1) = dotsStimulus(tmp);
			
			obj.r.updatesList;
			
			obj.store.dotsN = obj.r.sList.dN;
			string = obj.gs(obj.h.OKStimList);
			string{length(string)+1} = ['Coherent Dots #' num2str(obj.r.sList.dN)];
			set(obj.h.OKStimList,'String',string);
			
			obj.store.stimList = obj.r.sList.list;
			
		end
		
		function addSpot(obj)
			tmp = struct;
			tmp.xPosition = obj.gd(obj.h.OKPanelSpotxPosition);
			tmp.yPosition = obj.gd(obj.h.OKPanelSpotyPosition);
			tmp.size = obj.gd(obj.h.OKPanelSpotsize);
			tmp.angle = obj.gd(obj.h.OKPanelSpotangle);
			tmp.speed = obj.gd(obj.h.OKPanelSpotspeed);
			tmp.colour = obj.gn(obj.h.OKPanelSpotcolour);
			tmp.alpha = obj.gd(obj.h.OKPanelSpotalpha);
			
			obj.r.stimulus.d(obj.r.sList.sN + 1) = spotStimulus(tmp);
			
			obj.r.updatesList;
			
			obj.store.spotN = obj.r.sList.sN;
			string = obj.gs(obj.h.OKStimList);
			string{length(string)+1} = ['Spot #' num2str(obj.r.sList.sN)];
			set(obj.h.OKStimList,'String',string);
			
			obj.store.stimList = obj.r.sList.list;
			
		end
		
		function addVariable(obj)
			
			obj.r.task.nVar(obj.r.task.nVars+1).name = obj.gs(obj.h.OKVariableName);
			obj.r.task.nVar(obj.r.task.nVars+1).values = obj.gn(obj.h.OKVariableValues);
			obj.r.task.nVar(obj.r.task.nVars+1).stimulus = obj.gn(obj.h.OKVariableStimuli);
			
			obj.r.task.randomiseStimuli;
			obj.store.nVars = obj.r.task.nVars;
			
			string = obj.gs(obj.h.OKVarList);
			string{length(string)+1} = [obj.r.task.nVar(obj.r.task.nVars).name... 
				' on Stimuli: ' num2str(obj.r.task.nVar(obj.r.task.nVars).stimulus)];
			set(obj.h.OKVarList,'String',string);
			
		end
		
		function deleteVariable(obj)
			
			if isobject(obj.r.task)
				obj.r.task.nVars = obj.r.task.nVars - 1;
				obj.store.nVars = obj.r.task.nVars;
				obj.r.task.nVar=obj.r.task.nVar(1:obj.r.task.nVars);
			end
			
			if obj.r.task.nVars<0;obj.r.task.nVars=0;end
			if obj.store.nVars<0;obj.store.nVars=0;end
			
			string = obj.gs(obj.h.OKVarList);
			string = string(1:length(string)-1);
			set(obj.h.OKVarList,'Value',1);
			set(obj.h.OKVarList,'String',string);
			
		end
	end
	
	methods ( Access = protected ) %----------PRIVATE METHODS---------%
		
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

		function outhandle = gs(obj,inhandle,value)
			if exist('value','var')
				s = get(inhandle,'String');
				outhandle = s{value};
			else
				outhandle = get(inhandle,'String');
			end
		end
		function outhandle = gd(obj,inhandle)
			outhandle = str2double(get(inhandle,'String'));
		end
		function outhandle = gn(obj,inhandle)
			outhandle = str2num(get(inhandle,'String'));
		end
		function outhandle = gv(obj,inhandle)
			outhandle = get(inhandle,'Value');
		end
		
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