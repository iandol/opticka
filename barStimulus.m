classdef barStimulus < baseStimulus
%BARSTIMULUS single bar stimulus, inherits from baseStimulus
%   The current properties are:

   properties %--------------------PUBLIC PROPERTIES----------%
		family = 'bar'
		type = 'solid'
		barWidth = 1
		barLength = 2
		angle = 0
		speed = 1
		contrast = []
	end
	
	properties (SetAccess = private, GetAccess = public)
		matrix
		rmatrix
		delta
		dX
		dY
	end
	
	properties (SetAccess = private, GetAccess = private)
		allowedProperties='^(barWidth|barLength|angle|speed|startPosition|endPosition|contrast)$';
	end
	
   methods %----------PUBLIC METHODS---------%
		%-------------------CONSTRUCTOR----------------------%
		function obj = barStimulus(args) 
			%Initialise for superclass, stops a noargs error
			if nargin == 0
				args.family = 'bar';
			end
			obj=obj@baseStimulus(args); %we call the superclass constructor first
			%check we are a grating
% 			if ~strcmp(obj.family,'bar')
% 				error('Sorry, you are trying to call a barStimulus with a family other than bar');
% 			end
			%start to build our parameters
			if nargin>0 && isstruct(args)
				fnames = fieldnames(args); %find our argument names
				for i=1:length(fnames);
					if regexp(fnames{i},obj.allowedProperties) %only set if allowed property
						obj.salutation(fnames{i},'Configuring setting in barStimulus constructor');
						obj.(fnames{i})=args.(fnames{i}); %we set up the properies from the arguments as a structure
					end
				end
			end
			obj.family='bar';
			obj.salutation('constructor','Bar Stimulus initialisation complete');
		end
		
		function constructMatrix(obj,ppd)
			%use the passed pixels per degree to make a RGBA matrix of the
			%correct dimensions
			bw = round(obj.barWidth*ppd);
			bl = round(obj.barLength*ppd);
			obj.matrix(:,:,1)=ones(bl,bw)*obj.color(1);
			obj.matrix(:,:,2)=ones(bl,bw)*obj.color(2);
			obj.matrix(:,:,3)=ones(bl,bw)*obj.color(3);
			obj.matrix(:,:,4)=ones(bl,bw)*obj.color(4);
			switch obj.type
				case 'random'
					obj.rmatrix=rand(bl,bw);
					for i=1:3
						obj.matrix(:,:,i)=obj.matrix(:,:,i).*obj.rmatrix;
					end
					obj.matrix(:,:,4)=ones(bl,bw)*obj.alpha;
				case 'randomN'
					obj.rmatrix=randn(bl,bw);
					for i=1:3
						obj.matrix(:,:,i)=obj.matrix(:,:,i).*obj.rmatrix;
					end
					obj.matrix(:,:,4)=ones(bl,bw)*obj.alpha;
				otherwise
					obj.matrix(:,:,4)=ones(bl,bw)*obj.alpha;
			end
		end
		
		function updatePosition(obj,angle,delta)
			obj.dX= delta * cos(ang2rad(angle));
			obj.dY= delta * sin(ang2rad(angle));
		end
		
		function set.barLength(obj,value)
			if ~(value > 0)
				value = 0.1;
			end
			obj.barLength = value;
			if obj.barLength>obj.barWidth
				obj.salutation('WARNING:','Length is smaller than width');
			end
			obj.salutation(['set length: ' num2str(value)],'Custom set method')
		end
		function set.barWidth(obj,value)
			if ~(value > 0)
				value = 0.1;
			end
			obj.barWidth = value;
			if obj.barWidth<obj.barLength
				obj.salutation('WARNING:','Width is larger than length');
			end
			obj.salutation(['set width: ' num2str(value)],'Custom set method')
		end
		
	end %---END PUBLIC METHODS---%
	
	methods ( Access = private ) %----------PRIVATE METHODS---------%
		
	end
end