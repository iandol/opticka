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
				obj.path.protocols = ['~' filesep 'MatlabFiles' filesep 'Protocols'];
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
			obj.handles.uihandle=opticka_UI; %our GUI file
			obj.h=guidata(obj.handles.uihandle);
			if ismac
				javax.swing.UIManager.setLookAndFeel(oldlook);
			end
			
			obj.r = runExperiment;
			obj.r.task = stimulusSequence;
			obj.getScreenVals;
			obj.getTaskVals;
			
			
		end
		
		function getScreenVals(obj)
			obj.r.distance=str2double(get(obj.h.OKMonitorDistance,'String'));
			obj.r.pixelspercm=str2double(get(obj.h.OKPixelsPerCm,'String'));
			obj.r.screenXOffset=str2double(get(obj.h.OKXCenter,'String'));
			obj.r.screenYOffset=str2double(get(obj.h.OKYCenter,'String'));
			value=get(obj.h.OKGLSrc,'Value');
			string=get(obj.h.OKGLSrc,'Value');
			obj.r.srcMode = string{value};
			value=get(obj.h.OKGLDst,'Value');
			string=get(obj.h.OKGLDst,'Value');
			obj.r.dstMode = string{value};
			obj.r.blend = get(obj.h.OKOpenGLBlending,'Value');
			if ~strcmp('[]', get(obj.h.OKWindowSize,'String')
				obj.r.windowed = 1;
			end
			obj.r.hideFlash = get(obj.h.OKHideFlash, 'Value');
			obj.r.antiAlias = str2double(get(obj.h.OKMultiSampling,'String'));
			obj.r.photoDiode =  get(obj.h.OKUsePhotoDiode, 'Value');
		end
		
		function getTaskVals(obj)
			
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
	end
end