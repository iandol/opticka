classdef gratingStimulus < baseStimulus
%GRATINGSTIMULUS single grating stimulus, inherits from baseStimulus
%   The current properties are:
%   sf = spatial frequency in degrees
%   tf = temporal frequency
%   angle = angle in degrees
%   rotationMethod = do we rotate the grating texture (1) or the patch
%   itself (0)
%   phase = phase of grating
%   contrast = contrast from 0 - 1
%   mask = use circular mask (1) or not (0)
%   gabor = use a gabor rather than grating

   properties %--------------------PUBLIC PROPERTIES----------%
		family = 'grating'
		type = 'procedural'
		sf = 5
		tf = 2
		angle = 0
		rotationMethod = 1
		phase = 0
		contrast = 0.75
		mask = 0
		gabor = 0
		driftDirection=1
		speed = 0
		moveAngle = 0
	end
	
	properties (SetAccess = private, GetAccess = private)
		allowedProperties='^(sf|tf|method|angle|phase|rotationMethod|contrast|mask|gabor|driftDirection|speed|startPosition)$';
	end
	
   methods %----------PUBLIC METHODS---------%
		%-------------------CONSTRUCTOR----------------------%
		function obj = gratingStimulus(args) 
			%Initialise for superclass, stops a noargs error
			if nargin == 0
				args.family = 'grating';
			end
			obj=obj@baseStimulus(args); %we call the superclass constructor first
			%check we are a grating
			if ~strcmp(obj.family,'grating')
				error('Sorry, you are trying to call a gratingStimulus with a family other than grating');
			end
			%start to build our parameters
			if nargin>0 && isstruct(args)
				fnames = fieldnames(args); %find our argument names
				for i=1:length(fnames);
					if regexp(fnames{i},obj.allowedProperties) %only set if allowed property
						obj.salutation(fnames{i},'Configuring setting in gratingStimulus constructor');
						obj.(fnames{i})=args.(fnames{i}); %we set up the properies from the arguments as a structure
					end
				end
			end
			obj.salutation('constructor','Grating Stimulus initialisation complete');
		end
		
		function set.sf(obj,value)
			if ~(value > 0)
				value = 0.01;
			end
			obj.sf = value;
			obj.salutation(['set sf: ' num2str(value)],'Custom set method')
		end
		
	end %---END PUBLIC METHODS---%
	
	methods ( Access = private ) %----------PRIVATE METHODS---------%
		
	end
end