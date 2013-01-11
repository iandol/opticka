
% ========================================================================
%> @brief two patch grating stimulus, inherits from gratingstimulus
%> GRATINGSTIMULUS single grating stimulus, inherits from baseStimulus
% ========================================================================
classdef gratingPatchStimulus < gratingStimulus
	
	properties %--------------------PUBLIC PROPERTIES----------%
		%> spatial frequency
		sf2 = 1
		%> temporal frequency
		tf2 = 1
		%> phase of grating
		phase2 = 0
		%> contrast of grating
		contrast2 = 0.5
		%>
		aspectRatio2 = 2
		%> Position of inducer?
		inducerPosition = 2
	end
	
	properties (SetAccess = protected, GetAccess = public)
		
	end
	
	properties (SetAccess = private, GetAccess = public, Hidden = true)
	
	end
	
	properties (SetAccess = protected, GetAccess = protected)
		
	end
	
	properties (SetAccess = private, GetAccess = private)
		
	end
	
	events (ListenAccess = 'private', NotifyAccess = 'private') %only this class can access these
		
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
		function obj = gratingPatchStimulus(varargin)
			if nargin == 0
				varargin.family = ''; %Initialise for superclass, stops a noargs error
			end
			
			obj=obj@gratingStimulus(varargin); %we call the superclass constructor first
			obj.family = 'gratingpatch'; %override superclass family name
			
			if nargin>0
				obj.parseArgs(varargin, obj.allowedProperties);
			end
			
			obj.salutation('constructor method','Stimulus initialisation complete');
		end
		
		% ===================================================================
		%> @brief Draw this stimulus object for display
		%>
		%> 
		% ===================================================================
		function draw(obj)
			if obj.isVisible == true
				
				scale = obj.aspectRatio2;
				dstRect = obj.mvRect;
				dstRect(4) = dstRect(4)+(obj.sizeOut*scale);
				dstRect2 = AlignRect(dstRect,obj.mvRect,'top');
				dstRect2 = AdjoinRect(dstRect2,obj.mvRect,obj.inducerPosition);
				
				o=[obj.driftPhase, obj.sfOut, obj.contrastOut, obj.sigmaOut];
				o2 = [obj.driftPhase, obj.sfOut, obj.contrast2, obj.sigmaOut];
				%o(3) = o(3)/2;
				o2(2) = o2(2)*scale;
				
				r = [dstRect2',obj.mvRect'];
				o = [o2', o'];
				
				Screen('DrawTextures', obj.win, obj.texture, [], r,...
					obj.angleOut, [], [], [], [], obj.rotateMode,...
					o);
				obj.tick = obj.tick + 1;
			end
		end
		
		

		
	end %---END PUBLIC METHODS---%
	
	
	%=======================================================================
	methods ( Access = protected ) %-------PROTECTED METHODS-----%
	%=======================================================================
	
		
		
	end
end