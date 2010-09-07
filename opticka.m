classdef opticka < dynamicprops
	%OPTICKA GUI controller class
	%   Detailed explanation to come
	properties
		workingDir = '~/Code/opticka/';
		paths
		h
		r
		task
		stim
		verbose
	end
	properties (SetAccess = private, GetAccess = private)
		allowedPropertiesBase='^(workingDir)$'
		store
		handles
		load
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
			
			obj.r = runExperiment;
			obj.r.task = stimulusSequence;
			obj.getScreenVals;
			obj.getTaskVals;
			setappdata(0,'o',obj);
			
		end
		
		function getScreenVals(obj)
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
			if ~strcmp('[]', get(obj.h.OKWindowSize,'String'))
				obj.r.windowed = 1;
			end
			obj.r.hideFlash = obj.gv(obj.h.OKHideFlash);
			obj.r.antiAlias = obj.gd(obj.h.OKMultiSampling);
			obj.r.photoDiode = obj.gv(obj.h.OKUsePhotoDiode);
			obj.r.verbose = obj.gd(obj.h.OKVerbose);
		end
		
		function getTaskVals(obj)
			obj.r.task.trialTime = obj.gd(obj.h.OKtrialTime);
			obj.r.task.randomSeed = obj.gd(obj.h.OKRandomSeed);
			obj.r.task.randomGenerator = obj.gs(obj.h.OKrandomGenerator);
			obj.r.task.itTime = obj.gd(obj.h.OKitTime);
			obj.r.task.randomise = obj.gd(obj.h.OKRandomise);
			obj.r.task.isTime = obj.gd(obj.h.OKisTime);
			obj.r.task.nTrials = obj.gd(obj.h.OKnTrials);
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
		
		function outhandle = gs(obj,inhandle)
			outhandle = get(inhandle,'String');
		end
		function outhandle = gd(obj,inhandle)
			outhandle = str2double(get(inhandle,'String'));
		end
		function outhandle = gv(obj,inhandle)
			outhandle = get(inhandle,'Value');
		end
		
	end
end