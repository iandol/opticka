classdef barStimulus < baseStimulus
%BARSTIMULUS single bar stimulus, inherits from baseStimulus
%   The current properties are:

   properties %--------------------PUBLIC PROPERTIES----------%
		family = 'bar'
		type = 'solid'
		pixelScale = 1 %scale up the texture in the bar
		barWidth = 1
		barLength = 2
		angle = 0
		speed = 1
		contrast = []
	end
	
	properties (SetAccess = private, GetAccess = public)
		matrix
		rmatrix
		dstRect
		mvRect
		texture
	end
	
	properties (SetAccess = private, GetAccess = private)
		allowedProperties='^(type|barWidth|barLength|angle|speed|contrast)$';
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
		function obj = barStimulus(args) 
			%Initialise for superclass, stops a noargs error
			if nargin == 0
				args.family = 'bar';
			end
			obj=obj@baseStimulus(args); %we call the superclass constructor first
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
		
		% ===================================================================
		%> @brief Generate an structure for runExperiment
		%>
		%> @param rE runExperiment object for reference
		%> @return stimulus structure.
		% ===================================================================
		function constructMatrix(obj,ppd)
			%use the passed pixels per degree to make a RGBA matrix of the
			%correct dimensions
			obj.matrix=[]; %reset the matrix
			if length(obj.colour) == 3
				obj.colour(4) = obj.alpha;
			end
			bw = round(obj.barWidth*ppd);
			bl = round(obj.barLength*ppd);
			obj.matrix = ones(bl,bw,4); %allocate the size correctly
			obj.matrix(:,:,1)=ones(bl,bw)*obj.colour(1);
			obj.matrix(:,:,2)=ones(bl,bw)*obj.colour(2);
			obj.matrix(:,:,3)=ones(bl,bw)*obj.colour(3);
			obj.matrix(:,:,4)=ones(bl,bw)*obj.colour(4);
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
				case 'randomBW'
					obj.rmatrix=rand(bl,bw);
					obj.rmatrix(obj.rmatrix < 0.5) = 0;
					obj.rmatrix(obj.rmatrix >= 0.5) = 1;
					for i=1:3
						obj.matrix(:,:,i)=obj.matrix(:,:,i).*obj.rmatrix;
					end
					obj.matrix(:,:,4)=ones(bl,bw)*obj.alpha;
				otherwise
					obj.matrix(:,:,4)=ones(bl,bw)*obj.alpha;
			end
		end
		
		% ===================================================================
		%> @brief Generate an structure for runExperiment
		%>
		%> @param rE runExperiment object for reference
		%> @return stimulus structure.
		% ===================================================================
		function out = setup(obj,rE)
		
			fn = fieldnames(obj);
			for j=1:length(fn)
				%out.(fn{j}) = obj.(fn{j});
				if isempty(obj.findprop(['t' fn{j}])) %create a temporary dynamic property
					p=obj.addprop(['t' fn{j}]);
					p.Transient = true;
					p.Hidden = true;
				end
				obj.(['t' fn{j}]) = obj.(fn{j}); %copy our property value to our tempory copy
			end
			
			if isempty(obj.findprop('doDots'));obj.addprop('doDots');end
			if isempty(obj.findprop('doMotion'));obj.addprop('doMotion');end
			if isempty(obj.findprop('doDrift'));obj.addprop('doDrift');end
			obj.doDots = [];
			obj.doMotion = [];
			obj.doDrift = [];
			
			obj.delta = (obj.speed*rE.ppd) * rE.screenVals.ifi;
			
			obj.constructMatrix(rE.ppd) %make our matrix
			obj.texture=Screen('MakeTexture',rE.win,obj.matrix,1,[],2);
			
			[obj.dX obj.dY] = obj.updatePosition(obj.delta,obj.angle);
			
			if length(obj.colour) == 3
				obj.colour = [obj.colour obj.alpha];
			end
			out.colour=obj.colour;
			
			if obj.speed>0 %we need to say this needs animating
				obj.doMotion=1;
 				%rE.task.stimIsMoving=[rE.task.stimIsMoving i];
			else
				obj.doMotion=0;
			end
			
			obj.dstRect=Screen('Rect',obj.texture);
			obj.dstRect=CenterRectOnPoint(obj.dstRect,rE.xCenter,rE.yCenter);
			obj.dstRect=OffsetRect(obj.dstRect,(obj.xPosition)*rE.ppd,(obj.yPosition)*rE.ppd);
			obj.mvRect=obj.dstRect;
			
			out = obj.toStructure;
		end
		
		% ===================================================================
		%> @brief Update an structure for runExperiment
		%>
		%> @param in runExperiment object for reference
		%> @return stimulus structure.
		% ===================================================================
		function out = update(obj,rE)
			
		end
		
		% ===================================================================
		%> @brief Draw an structure for runExperiment
		%>
		%> @param rE runExperiment object for reference
		%> @return stimulus structure.
		% ===================================================================
		function out = draw(obj,rE)
			
		end
		
		% ===================================================================
		%> @brief Update an structure for runExperiment
		%>
		%> @param in runExperiment object for reference
		%> @return stimulus structure.
		% ===================================================================
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
		
		% ===================================================================
		%> @brief Update an structure for runExperiment
		%>
		%> @param in runExperiment object for reference
		%> @return stimulus structure.
		% ===================================================================
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