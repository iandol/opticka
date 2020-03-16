% ========================================================================
%> @brief plays an animated movie for a calibration stimulus
%>
%>
% ========================================================================	
classdef tittaCalMovieStimulus < handle
	properties (Access=private, Constant)
		calStateEnum = struct('undefined',0, 'moving',1, 'shrinking',2 ,'waiting',3 ,'blinking',4);
	end
	properties (Access=private)
		calState
		currentPoint
		lastPoint
		moveStartT
		shrinkStartT
		oscillStartT
		blinkStartT
		moveDuration
		moveVec
		accel
		scrSize
		startWaiting = false;
	end
	properties
		doShrink            = false
		shrinkTime          = 0.5
		doMove              = true
		moveTime            = 1       % for whole screen distance, duration will be proportionally shorter when dot moves less than whole screen distance
		moveWithAcceleration= true
		doOscillate         = false
		oscillatePeriod     = 1.5
		blinkInterval       = 0.2
		blinkCount          = 4
		fixBackSizeBlink    = 35
		fixBackSizeMax      = 50
		fixBackSizeMaxOsc   = 35
		fixBackSizeMin      = 15
		fixFrontSize        = 5
		movie				= []
		sM					= []
		oldpos				= []
		verbose				= true
	end
	
	methods
		function obj = tittaCalMovieStimulus()
			obj.setCleanState();
		end
		
		function setCleanState(obj)
			obj.oldpos = [];
			obj.calState = obj.calStateEnum.undefined;
			obj.currentPoint= nan(1,3);
			obj.lastPoint= nan(1,3);
			if ~isempty(obj.movie) && isa(obj.movie,'movieStimulus')
				obj.movie.reset();
				if ~isempty(obj.sM)
					if ~obj.movie.isSetup; obj.movie.setup(obj.sM); end
					if obj.verbose;fprintf('!!!>>>SET-CLEAN-STATE SETUP MOVIE\n');end
				end
			end
			if obj.verbose;fprintf('!!!>>>SET-CLEAN-STATE DONE\n');end
		end
		
		function initialise(obj,m)
			obj.oldpos = [];
			obj.movie = m;
			obj.sM = m.sM;
			if ~isempty(obj.sM) && isa(obj.movie,'movieStimulus')
				if ~obj.movie.isSetup; obj.movie.setup(obj.sM); end
			end
			if ~isempty(obj.sM) && isa(obj.sM.audio,'audioManager') && ~obj.sM.audio.isSetup
				obj.sM.audio.setup();
			end
			obj.scrSize = obj.sM.winRect(3:4);
			if obj.verbose;fprintf('!!!>>>CALMOVIESTIM SET INITIAL STATE\n');end
		end
		
		function qAllowAcceptKey = doDraw(obj,wpnt,drawCmd,currentPoint,pos,~,~)
			% last two inputs, tick (monotonously increasing integer and stage
			% ("cal" or "val") are not used in this code
			
			% if called with drawCmd == 'cleanUp', this is a signal that
			% calibration/validation is done, and cleanup can occur if
			% wanted
			if strcmp(drawCmd,'cleanUp')
				if obj.verbose;fprintf('!!!>>>RUN CLEANUP\n');end
				obj.setCleanState();
				return;
			end
			
			% check point changed
			curT = GetSecs;     % instead of using time directly, you could use the 'tick' call sequence number input to this function to animate your display
			if strcmp(drawCmd,'new')
				if obj.doMove && ~isnan(obj.currentPoint(1))
					obj.calState = obj.calStateEnum.moving;
					obj.moveStartT = curT;
					% dot should move at constant speed regardless of
					% distance to cover, moveTime contains time to move
					% over width of whole screen. Adjust time to proportion
					% of screen width covered by current move
					dist = hypot(obj.currentPoint(2)-pos(1),obj.currentPoint(3)-pos(2));
					obj.moveDuration = obj.moveTime*dist/obj.scrSize(1);
					if obj.moveWithAcceleration
						obj.accel   = dist/(obj.moveDuration/2)^2;  % solve x=.5*a*t^2 for a, use dist/2 for x
						obj.moveVec = (pos(1:2)-obj.currentPoint(2:3))/dist;
					end
				elseif obj.doShrink
					obj.calState = obj.calStateEnum.shrinking;
					obj.shrinkStartT = curT;
				else
					obj.sM.audio.play()
					obj.calState = obj.calStateEnum.waiting;
					obj.oscillStartT = curT;
				end
				obj.lastPoint       = obj.currentPoint;
				obj.currentPoint    = [currentPoint pos];
			elseif strcmp(drawCmd,'redo')
				% start blink, pause animation.
				obj.calState = obj.calStateEnum.blinking;
				obj.blinkStartT = curT;
			else % drawCmd == 'draw'
				% regular draw: check state transition
				if (obj.calState==obj.calStateEnum.moving && (curT-obj.moveStartT)>obj.moveDuration) || ...
						(obj.calState==obj.calStateEnum.blinking && (curT-obj.blinkStartT)>obj.blinkInterval*obj.blinkCount*2)
					% move finished or blink finished
					if obj.doShrink
						obj.a.play();
						obj.calState = obj.calStateEnum.shrinking;
						obj.shrinkStartT = curT;
					else
						obj.calState = obj.calStateEnum.waiting;
						obj.oscillStartT = curT;
						obj.sM.audio.play();
					end
				elseif obj.calState==obj.calStateEnum.shrinking && (curT-obj.shrinkStartT)>obj.shrinkTime
					obj.calState = obj.calStateEnum.waiting;
					obj.oscillStartT = curT;
				end
			end
			
			% determine current point position
			if obj.calState==obj.calStateEnum.moving
				frac = (curT-obj.moveStartT)/obj.moveDuration;
				if obj.moveWithAcceleration
					if frac<.5
						curPos = obj.lastPoint(2:3) + obj.moveVec*.5*obj.accel*(curT-obj.moveStartT)^2;
					else
						% implement deceleration by accelerating from the
						% other side in backward time
						curPos = obj.currentPoint(2:3) - obj.moveVec*.5*obj.accel*(obj.moveDuration-curT+obj.moveStartT)^2;
					end
				else
					curPos = obj.lastPoint(2:3).*(1-frac) + obj.currentPoint(2:3).*frac;
				end
			else
				curPos = obj.currentPoint(2:3);
			end
			
			% determine if we're ready to accept the user pressing the
			% accept calibration point button. User should not be able to
			% press it if point is not yet at the final position
			qAllowAcceptKey = ismember(obj.calState,[obj.calStateEnum.shrinking obj.calStateEnum.waiting]);
			
			% draw
			Screen('FillRect',wpnt,obj.sM.backgroundColour); % needed when multi-flipping participant and operator screen, doesn't hurt when not needed
			if obj.calState~=obj.calStateEnum.blinking || mod((curT-obj.blinkStartT)/obj.blinkInterval/2,1)>.5
				obj.drawMovie(curPos);
			end
		end
	end
	
	methods (Access = private, Hidden)
		function drawMovie(obj,pos)
			if isempty(obj.oldpos) || ~all(pos==obj.oldpos)
				obj.oldpos = pos;
				obj.movie.updatePositions(pos(1),pos(2));
			end
			obj.movie.draw();
		end
	end
end