% This class is part of Titta, a toolbox providing convenient access to
% eye tracking functionality using Tobii eye trackers
%
% Titta can be found at https://github.com/dcnieho/Titta. Check there for
% the latest version.
% When using Titta or this class, please cite the following paper:
%
% Niehorster, D.C., Andersson, R. & Nystrom, M., (2020). Titta: A toolbox
% for creating Psychtoolbox and Psychopy experiments with Tobii eye
% trackers. Behavior Research Methods.
% doi: https://doi.org/10.3758/s13428-020-01358-8

classdef tittaCalStimulus < handle
    properties (Access=private, Constant)
        calStateEnum = struct('undefined',0, 'moving',1, 'shrinking',2 ,'waiting',3 ,'blinking',4);
    end
    properties (Access=private)
		screen
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
    end
    properties
		drawFcn				= 'drawPupilCoreMarker'
        doShrink            = true
        shrinkTime          = 0.5
        doMove              = true
        moveTime            = 1      % for whole screen distance, duration will be proportionally shorter when dot moves less than whole screen distance
        moveWithAcceleration= true
        doOscillate         = true
        oscillatePeriod     = 1.5
        blinkInterval       = 0.3
        blinkCount          = 2
        fixBackSizeBlink    = 3.5
        fixBackSizeMax      = 5
        fixBackSizeMaxOsc   = 3.5
        fixBackSizeMin      = 1.5
        fixFrontSize        = 5
        fixBackColor        = 0
        fixFrontColor       = 255
        bgColor             = 127
    end
    properties (Access=private, Hidden = true)
        qFloatColorRange    = [];
		ppd
    end
    
    
    methods
		function me = tittaCalStimulus(screen)
			if exist('screen','var') 
				me.screen = screen; 
				me.ppd = screen.ppd; 
				me.bgColor = floor(screen.backgroundColour(1:3) * 255);
			end
            me.setCleanState();
        end
        
        function setCleanState(me)
            me.calState = me.calStateEnum.undefined;
            me.currentPoint= nan(1,3);
            me.lastPoint= nan(1,3);
        end
        
        function qAllowAcceptKey = doDraw(me,wpnt,drawCmd,currentPoint,pos,~,~)
            % last two inputs, tick (monotonously increasing integer) and
            % stage ("cal" or "val") are not used in this code
            
            % if called with drawCmd == 'fullCleanUp', this is a signal
            % that calibration/validation is done, and cleanup can occur if
            % wanted. If called with drawCmd == 'sequenceCleanUp' that
            % means there should be a gap in the drawing sequence (e.g. no
            % smooth animation between two positions). For this one we can
            % just clean up state in both cases.
            if ismember(drawCmd,{'fullCleanUp','sequenceCleanUp'})
                me.setCleanState();
                return;
            end
            
            % now that we have a wpnt, get some needed variables
            if isempty(me.scrSize)
                me.scrSize = Screen('Rect',wpnt); me.scrSize(1:2) = [];
            end
            if isempty(me.qFloatColorRange)
                me.qFloatColorRange    = Screen('ColorRange',wpnt)==1;
            end
            
            % check point changed
            curT = GetSecs;     % instead of using time directly, you could use the 'tick' call sequence number input to this function to animate your display
            if strcmp(drawCmd,'new')
                if me.doMove && ~isnan(me.currentPoint(1))
                    me.calState = me.calStateEnum.moving;
                    me.moveStartT = curT;
                    % dot should move at constant speed regardless of
                    % distance to cover, moveTime contains time to move
                    % over width of whole screen. Adjust time to proportion
                    % of screen width covered by current move
                    dist = hypot(me.currentPoint(2)-pos(1),me.currentPoint(3)-pos(2));
                    me.moveDuration = me.moveTime*dist/me.scrSize(1);
                    if me.moveWithAcceleration
                        me.accel   = dist/(me.moveDuration/2)^2;  % solve x=.5*a*t^2 for a, use dist/2 for x
                        me.moveVec = (pos(1:2)-me.currentPoint(2:3))/dist;
                    end
                elseif me.doShrink
                    me.calState = me.calStateEnum.shrinking;
                    me.shrinkStartT = curT;
                else
                    me.calState = me.calStateEnum.waiting;
                    me.oscillStartT = curT;
                end
                
                me.lastPoint       = me.currentPoint;
                me.currentPoint    = [currentPoint pos];
            elseif strcmp(drawCmd,'redo')
                % start blink, pause animation.
                me.calState = me.calStateEnum.blinking;
                me.blinkStartT = curT;
            else % drawCmd == 'draw'
                % regular draw: check state transition
                if (me.calState==me.calStateEnum.moving && (curT-me.moveStartT)>me.moveDuration) || ...
                   (me.calState==me.calStateEnum.blinking && (curT-me.blinkStartT)>me.blinkInterval*me.blinkCount*2)
                    % move finished or blink finished
                    if me.doShrink
                        me.calState = me.calStateEnum.shrinking;
                        me.shrinkStartT = curT;
                    else
                        me.calState = me.calStateEnum.waiting;
                        me.oscillStartT = curT;
                    end
                elseif me.calState==me.calStateEnum.shrinking && (curT-me.shrinkStartT)>me.shrinkTime
                    me.calState = me.calStateEnum.waiting;
                    me.oscillStartT = curT;
                end
            end
            
            % determine current point position
            if me.calState==me.calStateEnum.moving
                frac = (curT-me.moveStartT)/me.moveDuration;
                if me.moveWithAcceleration
                    if frac<.5
                        curPos = me.lastPoint(2:3)    + me.moveVec*.5*me.accel*(                 curT-me.moveStartT)^2;
                    else
                        % implement deceleration by accelerating from the
                        % other side in backward time
                        curPos = me.currentPoint(2:3) - me.moveVec*.5*me.accel*(me.moveDuration-curT+me.moveStartT)^2;
                    end
                else
                    curPos = me.lastPoint(2:3).*(1-frac) + me.currentPoint(2:3).*frac;
                end
            else
                curPos = me.currentPoint(2:3);
            end
            
            % determine current point size
            if me.calState==me.calStateEnum.moving
                sz   = [me.fixBackSizeMax me.fixFrontSize];
            elseif me.calState==me.calStateEnum.shrinking
                dSize = me.fixBackSizeMax-me.fixBackSizeMin;
                frac = 1 - (curT-me.shrinkStartT)/me.shrinkTime;
                sz   = [me.fixBackSizeMin + frac.*dSize  me.fixFrontSize];
            elseif me.calState==me.calStateEnum.blinking
                sz   = [me.fixBackSizeBlink me.fixFrontSize];
            else
                if me.doOscillate
                    dSize = me.fixBackSizeMaxOsc-me.fixBackSizeMin;
                    phase = cos((curT-me.oscillStartT)/me.oscillatePeriod*2*pi);
                    if me.doShrink
                        frac = 1-(phase/2+.5);  % start small
                    else
                        frac =    phase/2+.5;   % start big
                    end
                    sz   = [me.fixBackSizeMin + frac.*dSize  me.fixFrontSize];
                else
                    sz   = [me.fixBackSizeMin me.fixFrontSize];
                end
            end
            
            % determine if we're ready to accept the user pressing the
            % accept calibration point button. User should not be able to
            % press it if point is not yet at the final position
            qAllowAcceptKey = ismember(me.calState,[me.calStateEnum.shrinking me.calStateEnum.waiting]);
            
            % draw
            %Screen('FillRect',wpnt,me.getColorForWindow(me.bgColor)); % needed when multi-flipping participant and operator screen, doesn't hurt when not needed
            if me.calState~=me.calStateEnum.blinking || mod((curT-me.blinkStartT)/me.blinkInterval/2,1)>.5
                me.drawAFixPoint(wpnt,curPos,sz);
            end
        end
    end
    
    methods (Access = private, Hidden)
        function drawAFixPoint(me,~,pos,sz)
            ListenChar(0);
            for p=1:size(pos,1)
				xy = me.screen.toDegrees([pos(p,1),pos(p,2)],'xy');
				me.screen.(me.drawFcn)(sz(1),xy(1),xy(2));
            end
        end
        
        function clr = getColorForWindow(me,clr)
            if me.qFloatColorRange
                clr = double(clr)/255;
            end
        end
    end
end
