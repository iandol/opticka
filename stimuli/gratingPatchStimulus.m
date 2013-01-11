
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
			%Initialise for superclass, stops a noargs error
			if nargin == 0
				varargin.family = 'gratingpatch';
			end
			
			obj=obj@gratingStimulus(varargin); %we call the superclass constructor first
			
			obj.family = 'gratingpatch';
			
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
				Screen('DrawTexture', obj.win, obj.texture, [],obj.mvRect,...
					obj.angleOut, [], [], [], [], obj.rotateMode,...
					[obj.driftPhase, obj.sfOut, obj.contrastOut, obj.sigmaOut]);
				Screen('DrawTexture', obj.win, obj.texture, [],obj.mvRect+50,...
					obj.angleOut+90, [], [], [], [], obj.rotateMode,...
					[obj.driftPhase, obj.sfOut, obj.contrastOut, obj.sigmaOut]);
				obj.tick = obj.tick + 1;
			end
		end
		
		

		
	end %---END PUBLIC METHODS---%
	
	
	%=======================================================================
	methods ( Access = protected ) %-------PROTECTED METHODS-----%
	%=======================================================================
	
		
		
	end
end