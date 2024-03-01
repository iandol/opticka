classdef tittaAdvMovieStimulus < handle
    properties (Access=private, Constant)
        calStateEnum = struct('undefined',0, 'showing',1, 'blinking',2)
    end
    properties (SetAccess=private)
        calState
        pointStartT
        blinkStartT
    end
    properties (Dependent, SetAccess=private)
        pos   % can't set position here, you set it through doDraw() with drawCmd 'new'
    end
    properties
        blinkInterval       = 0.3
        blinkCount          = 2
        bgColor             = 127
        videoSize           = []
    end
    properties (Access=private)
		qFloatColorRange
        currentPoint
        cumDurations
        videoPlayer
		screen
        tex = 0
    end
    
    
    methods
		function obj = tittaAdvMovieStimulus(screen)
			if exist('screen','var')
				obj.screen = screen;
				obj.bgColor = round(screen.backgroundColour * 255);
			end
            obj.setCleanState();
        end

        function setVideoPlayer(obj,videoPlayer)
            obj.videoPlayer = videoPlayer;
			if videoPlayer.isSetup
				obj.screen = videoPlayer.sM;
			end
        end
        
        function setCleanState(obj)
            obj.calState        = obj.calStateEnum.undefined;
            obj.currentPoint    = nan(1,3);
			if ~isempty(obj.videoPlayer)
                try obj.videoPlayer.reset(); end %#ok<*TRYNC>
			end
        end

        function pos = get.pos(obj)
            pos = obj.currentPoint(2:3);
        end
        
        function qAllowAcceptKey = doDraw(obj,wpnt,drawCmd,currentPoint,pos,~,~)
            % last two inputs, tick (monotonously increasing integer) and
            % stage ("cal" or "val") are not used in this code
            
            % if called with drawCmd == 'fullCleanUp', this is a signal
            % that calibration/validation is done, and cleanup can occur if
            % wanted. If called with drawCmd == 'sequenceCleanUp' that
            % means there should be a gap in the drawing sequence (e.g. no
            % smooth animation between two positions). For this one we keep
            % image playback state unless asked to fully clean up.
            if ismember(drawCmd,{'fullCleanUp','sequenceCleanUp'})
                if strcmp(drawCmd,'fullCleanUp')
                    obj.setCleanState();
                end
                return;
			end

			% make sure movieStimulus is setup
			if ~obj.videoPlayer.isSetup
				setup(obj.videoPlayer, obj.screen);
			end
            
            % now that we have a wpnt, interrogate window
            if isempty(obj.qFloatColorRange) && ~isempty(wpnt)
                obj.qFloatColorRange    = Screen('ColorRange',wpnt)==1;
            end
            
            % check point changed
            curT = GetSecs;     % instead of using time directly, you could use the 'tick' call sequence number input to this function to animate your display
            if strcmp(drawCmd,'new')
                obj.currentPoint    = [currentPoint pos];
                obj.pointStartT     = curT;
                obj.calState        = obj.calStateEnum.showing;
            elseif strcmp(drawCmd,'redo')
                % start blink, restart animation.
                obj.calState        = obj.calStateEnum.blinking;
                obj.blinkStartT     = curT;
                obj.pointStartT     = 0;
            else % drawCmd == 'draw'
                % regular draw: check state transition
                if obj.calState==obj.calStateEnum.blinking && (curT-obj.blinkStartT)>obj.blinkInterval*obj.blinkCount*2
                    % blink finished
                    obj.calState    = obj.calStateEnum.showing;
                    obj.pointStartT = curT;
                end
            end
            
            % determine current point position
            curPos = obj.currentPoint(2:3);
            
            % determine if we're ready to accept the user pressing the
            % accept calibration point button. User should not be able to
            % press it if point is not yet at the final position
            qAllowAcceptKey = obj.calState~=obj.calStateEnum.blinking;
            
            if ~isempty(wpnt)
				obj.videoPlayer.updateXY(curPos(1),curPos(2));
				if (obj.calState~=obj.calStateEnum.blinking || mod((curT-obj.blinkStartT)/obj.blinkInterval/2,1)>.5)
					obj.videoPlayer.draw();
				end
            end
        end
    end
    
    methods (Access = private, Hidden)
        function clr = getColorForWindow(obj,clr)
            if obj.qFloatColorRange
                clr = double(clr)/255;
            end
        end
    end
end
