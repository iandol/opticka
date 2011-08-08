% ========================================================================
%> @brief textureStimulus is the superclass for texture based stimulus objects
%>
%> Superclass providing basic structure for texture stimulus classes
%>
% ========================================================================	
classdef textureStimulus < baseStimulus	
	properties %--------------------PUBLIC PROPERTIES----------%
		family = 'texture'
		type = 'simple'
		contrast = 1
		scale = 1
		interpMethod = 'nearest'
		fileName = []
		pixelScale = 1 %scale up the texture in the bar
	end
	
	properties (SetAccess = private, GetAccess = public)
		matrix
	end
	
	properties (SetAccess = private, GetAccess = private)
		%> allowed properties passed to object upon construction
		allowedProperties='type|fileName|contrast|scale|interpMethod|pixelScale';
		%>properties to not create transient copies of during setup phase
		ignoreProperties = 'scale|fileName|interpMethod|pixelScale'
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
		function obj = textureStimulus(args)
			%Initialise for superclass, stops a noargs error
			if nargin == 0
				args.family = 'texture';
			end
			
			obj=obj@baseStimulus(args); %we call the superclass constructor first
			
			if nargin>0 && isstruct(args)
				obj.parseArgs(args, obj.allowedProperties);
			end
			
			obj.ignoreProperties = ['^(' obj.ignorePropertiesBase '|' obj.ignoreProperties ')$'];
			obj.salutation('constructor','Texture Stimulus initialisation complete');
		end
		
		% ===================================================================
		%> @brief Setup this object in preperation for use
		%> When displaying a stimulus object, the main properties that are to be
		%> modified are copied into cache copies of the property, both to convert from 
		%> visual description (c/d, Hz, degrees) to
		%> computer metrics, and to be animated and modified as independant
		%> variables. So xPosition is copied to xPositionOut and converyed from
		%> degrees to pixels. The animation and drawing functions use these modified
		%> properties, and when they are updated, for example to change to a new
		%> xPosition, internal methods ensure reconversion and update any dependent
		%> properties. This method initialises the object for display.
		%>
		%> @param rE runExperiment object for reference
		% ===================================================================
		function setup(obj,rE,in)
			
			obj.reset;
			
			if ~exist('in','var')
				in = [];
			end
			
			if isempty(obj.isVisible)
				obj.show;
			end
			
			obj.ppd=rE.ppd;
			obj.ifi=rE.screenVals.ifi;
			obj.xCenter=rE.xCenter;
			obj.yCenter=rE.yCenter;
			obj.win=rE.win;
			
			obj.texture = []; %we need to reset this

			fn = fieldnames(textureStimulus);
			for j=1:length(fn)
				if isempty(obj.findprop([fn{j} 'Out'])) && isempty(regexp(fn{j},obj.ignoreProperties, 'once')) %create a temporary dynamic property
					p=obj.addprop([fn{j} 'Out']);
					p.Transient = true;%p.Hidden = true;
					if strcmp(fn{j},'xPosition');p.SetMethod = @set_xPositionOut;end
					if strcmp(fn{j},'yPosition');p.SetMethod = @set_yPositionOut;end
				end
				if isempty(regexp(fn{j},obj.ignoreProperties, 'once'))
					obj.([fn{j} 'Out']) = obj.(fn{j}); %copy our property value to our tempory copy
				end
			end
			
			if ~isempty(in)
				obj.matrix = in;
			elseif ~isempty(obj.fileName) && exist(obj.fileName,'file')
				obj.matrix = imread(obj.fileName);
			else
				obj.matrix = ones(obj.size*obj.ppd,obj.size*obj.ppd,3);
			end
			
			obj.matrix(:,:,4) = obj.alpha .* 255;
			
			obj.texture=Screen('MakeTexture',obj.win,obj.matrix,1);
			
			if isempty(obj.findprop('doDots'));p=obj.addprop('doDots');p.Transient = true;end
			if isempty(obj.findprop('doMotion'));p=obj.addprop('doMotion');p.Transient = true;end
			if isempty(obj.findprop('doDrift'));p=obj.addprop('doDrift');p.Transient = true;end
			if isempty(obj.findprop('doFlash'));p=obj.addprop('doFlash');p.Transient = true;end
			obj.doDots = false;
			obj.doMotion = false;
			obj.doDrift = false;
			obj.doFlash = false;
			
			if obj.speed>0 %we need to say this needs animating
				obj.doMotion=true;
 				%rE.task.stimIsMoving=[rE.task.stimIsMoving i];
			else
				obj.doMotion=false;
			end
			
			obj.setRect();
			
		end

		% ===================================================================
		%> @brief Update this stimulus object structure for runExperiment
		%>
		% ===================================================================
		function update(obj)
			obj.setRect();
			obj.tick = 1;
		end
		
		% ===================================================================
		%> @brief Draw an structure for runExperiment
		%>
		%> @param rE runExperiment object for reference
		%> @return stimulus structure.
		% ===================================================================
		function draw(obj)
			Screen('DrawTexture',obj.win,obj.texture,[],obj.mvRect,obj.angleOut);
		end
		
		% ===================================================================
		%> @brief Animate an structure for runExperiment
		%>
		%> @param rE runExperiment object for reference
		%> @return stimulus structure.
		% ===================================================================
		function animate(obj)
			if obj.doMotion == 1
				obj.mvRect=OffsetRect(obj.mvRect,obj.dX,obj.dY);
			end
			obj.tick = obj.tick + 1;
		end
		
		% ===================================================================
		%> @brief Reset an structure for runExperiment
		%>
		%> @param rE runExperiment object for reference
		%> @return
		% ===================================================================
		function reset(obj)
			obj.texture=[];
			obj.mvRect = [];
			obj.dstRect = [];
			obj.removeTmpProperties;
		end
		
	end %---END PUBLIC METHODS---%
	
	%=======================================================================
	methods ( Access = private ) %-------PRIVATE METHODS-----%
	%=======================================================================
		%> @brief xPositionOut Set method
		%>
		% ===================================================================
		function set_xPositionOut(obj,value)
			obj.xPositionOut = value*obj.ppd;
			if ~isempty(obj.texture);obj.setRect;end
		end
		
		% ===================================================================
		%> @brief yPositionOut Set method
		%>
		% ===================================================================
		function set_yPositionOut(obj,value)
			obj.yPositionOut = value*obj.ppd;
			if ~isempty(obj.texture);obj.setRect;end
		end
		
		% ===================================================================
		%> @brief setRect
		%>  setRect makes the PsychRect based on the texture and screen values
		% ===================================================================
		function setRect(obj)
			if isempty(obj.findprop('angleOut'));
				[dx dy]=pol2cart(obj.d2r(obj.angle),obj.startPosition);
			else
				[dx dy]=pol2cart(obj.d2r(obj.angleOut),obj.startPosition);
			end
			obj.dstRect=Screen('Rect',obj.texture);
			obj.dstRect=CenterRectOnPointd(obj.dstRect,obj.xCenter,obj.yCenter);
			if isempty(obj.findprop('xPositionOut'));
				obj.dstRect=OffsetRect(obj.dstRect,obj.xPosition*obj.ppd,obj.yPosition*obj.ppd);
			else
				obj.dstRect=OffsetRect(obj.dstRect,obj.xPositionOut+(dx*obj.ppd),obj.yPositionOut+(dy*obj.ppd));
			end
			obj.mvRect=obj.dstRect;
		end
	end
end