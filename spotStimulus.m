% ========================================================================
%> @brief single bar stimulus, inherits from baseStimulus
%> SPOTSTIMULUS single bar stimulus, inherits from baseStimulus
%>   The current properties are:
% ========================================================================
classdef spotStimulus < baseStimulus

   properties %--------------------PUBLIC PROPERTIES----------%
		family = 'spot'
		type = 'simple'
		flashTime = [0.5 0.5]
		flashOn = true
		contrast = 1
	end
	
	properties (Dependent = true, SetAccess = private, GetAccess = private)
		flashSwitch
	end
	
	properties (SetAccess = private, GetAccess = private)
		flashCounter = 1
		flashBG = [0.5 0.5 0.5 0]
		flashFG = [1 1 1 1]
		allowedProperties='^(type|flashTime|flashOn|contrast)$'
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
		%> @return instance of the class.
		% ===================================================================
		function obj = spotStimulus(args) 
			%Initialise for superclass, stops a noargs error
			if nargin == 0
				args.family = 'spot';
			end
			obj=obj@baseStimulus(args); %we call the superclass constructor first
			if nargin>0 && isstruct(args)
				fnames = fieldnames(args); %find our argument names
				for i=1:length(fnames);
					if regexp(fnames{i},obj.allowedProperties) %only set if allowed property
						obj.salutation(fnames{i},'Configuring setting in spotStimulus constructor');
						obj.(fnames{i})=args.(fnames{i}); %we set up the properies from the arguments as a structure
					end
				end
			end
			obj.salutation('constructor','Spot Stimulus initialisation complete');
		end
		
		% ===================================================================
		%> @brief Setup an structure for runExperiment
		%>
		%> @param rE runExperiment object for reference
		%> @return
		% ===================================================================
		function setup(obj,rE)
			
			if exist('rE','var')
				obj.ppd=rE.ppd;
				obj.ifi=rE.screenVals.ifi;
				obj.xCenter=rE.xCenter;
				obj.yCenter=rE.yCenter;
				obj.win=rE.win;
			end

			fn = fieldnames(spotStimulus);
			for j=1:length(fn)
				if isempty(obj.findprop([fn{j} 'Out'])) && isempty(regexp(fn{j},obj.ignoreProperties, 'once'))%create a temporary dynamic property
					p=obj.addprop([fn{j} 'Out']);
					p.Transient = true;%p.Hidden = true;
					if strcmp(fn{j},'size');p.SetMethod = @setsizeOut;end
					if strcmp(fn{j},'xPosition');p.SetMethod = @setxPositionOut;end
					if strcmp(fn{j},'yPosition');p.SetMethod = @setyPositionOut;end
					if strcmp(fn{j},'contrast');p.SetMethod = @setcontrastOut;end
				end
				if isempty(regexp(fn{j},obj.ignoreProperties, 'once'))
					obj.([fn{j} 'Out']) = obj.(fn{j}); %copy our property value to our tempory copy
				end
			end
			
			if isempty(obj.findprop('doFlash'));p=obj.addprop('doFlash');p.Transient = true;end
			if isempty(obj.findprop('doDots'));p=obj.addprop('doDots');p.Transient = true;end
			if isempty(obj.findprop('doMotion'));p=obj.addprop('doMotion');p.Transient = true;end
			if isempty(obj.findprop('doDrift'));p=obj.addprop('doDrift');p.Transient = true;end
			obj.doDots = 0;
			obj.doMotion = 0;
			obj.doDrift = 0;
			obj.doFlash = 0;
			if obj.speedOut > 0; obj.doMotion = 1; end
			
			if strcmp(obj.type,'flash')
				obj.doFlash = 1;
				bg = [rE.backgroundColour(1:3) obj.alpha];
				obj.setupFlash(bg);
			end

			if isempty(obj.findprop('xTmp'));p=obj.addprop('xTmp');p.Transient = true;end
			if isempty(obj.findprop('yTmp'));p=obj.addprop('yTmp');p.Transient = true;end
			obj.computePosition;
			
		end
		
		% ===================================================================
		%> @brief Update an structure for runExperiment
		%>
		%> @param rE runExperiment object for reference
		%> @return stimulus structure.
		% ===================================================================
		function update(obj)
			obj.computePosition;
			if obj.doFlash
				obj.resetFlash;
			end
		end
		
		% ===================================================================
		%> @brief Draw an structure for runExperiment
		%>
		%> @param rE runExperiment object for reference
		%> @return stimulus structure.
		% ===================================================================
		function draw(obj)
			Screen('gluDisk',obj.win,obj.colourOut,obj.xTmp,obj.yTmp,obj.sizeOut);
		end

		% ===================================================================
		%> @brief Animate an structure for runExperiment
		%>
		%> @param rE runExperiment object for reference
		%> @return stimulus structure.
		% ===================================================================
		function animate(obj)
			if obj.doMotion == 1
				obj.xTmp = obj.xTmp + obj.dX;
				obj.yTmp = obj.yTmp + obj.dY;
			end
			if obj.doFlash == 1
				if obj.flashCounter <= obj.flashSwitch
					obj.flashCounter=obj.flashCounter+1;
				else
					obj.flashCounter = 1;
					obj.flashOn = ~obj.flashOn;
					if obj.flashOn == true
						obj.colourOut = obj.flashFG;
					else
						obj.colourOut = obj.flashBG;
					end
				end
			end
		end
		
		% ===================================================================
		%> @brief Reset an structure for runExperiment
		%>
		%> @param rE runExperiment object for reference
		%> @return stimulus structure.
		% ===================================================================
		function reset(obj)
			obj.texture=[];
			obj.removeTmpProperties;
		end
		
		% ===================================================================
		%> @brief flashSwitch Get method
		%>
		% ===================================================================
		function flashSwitch = get.flashSwitch(obj)
			if obj.flashOn == true
				flashSwitch = round(obj.flashTime(1) / obj.ifi);
			else
				flashSwitch = round(obj.flashTime(2) / obj.ifi);
			end
		end
		
		
	end %---END PUBLIC METHODS---%
	
	%=======================================================================
	methods ( Access = private ) %-------PRIVATE METHODS-----%
	%=======================================================================
		% ===================================================================
		%> @brief sizeOut Set method
		%>
		% ===================================================================
		function setsizeOut(obj,value)
			obj.sizeOut = (value*obj.ppd) / 2; %divide by 2 to get diameter
		end
		
		% ===================================================================
		%> @brief xPositionOut Set method
		%>
		% ===================================================================
		function setxPositionOut(obj,value)
			obj.xPositionOut = (value*obj.ppd) + obj.xCenter;
			if ~isempty(obj.findprop('xTmp'));obj.computePosition;end
		end

		% ===================================================================
		%> @brief yPositionOut Set method
		%>
		% ===================================================================
		function setyPositionOut(obj,value)
			obj.yPositionOut = (value*obj.ppd) + obj.yCenter;
			if ~isempty(obj.findprop('xTmp'));obj.computePosition;end
		end
		
		% ===================================================================
		%> @brief contrast Set method
		%>
		% ===================================================================
		function setcontrastOut(obj,value)
			obj.contrast = value;
			if obj.contrast < 1
				obj.flashFG = obj.colour .* obj.contrast;
				obj.flashFG = obj.colour .* obj.contrast;
			end
		end
		
		% ===================================================================
		%> @brief setupFlash
		%>
		% ===================================================================
		function setupFlash(obj,bg)
			obj.flashFG = obj.colour .* obj.contrast;
			obj.flashBG = bg;% .* 1-obj.contrast;
			obj.flashCounter = 1;
		end
		
		% ===================================================================
		%> @brief yPositionOut Set method
		%>
		% ===================================================================
		function resetFlash(obj)
			obj.colourOut = obj.flashFG;
			obj.flashCounter = 1;
		end
		
		% ===================================================================
		%> @brief compute xTmp and yTmp
		%>
		% ===================================================================
		function computePosition(obj)
			if isempty(obj.findprop('angleOut'));
				[dx dy]=pol2cart(obj.d2r(obj.angle),obj.startPosition);
			else
				[dx dy]=pol2cart(obj.d2r(obj.angleOut),obj.startPositionOut);
			end
			obj.xTmp = obj.xPositionOut + (dx * obj.ppd); 
			obj.yTmp = obj.yPositionOut + (dy * obj.ppd);
		end
			
	end
end