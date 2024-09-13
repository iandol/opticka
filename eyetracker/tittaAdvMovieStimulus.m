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
        stimulus
		screen
        tex = 0
    end
    
    
    methods
		function me = tittaAdvMovieStimulus(screen)
			if exist('screen','var')
				me.screen = screen;
				me.bgColor = round(screen.backgroundColour * 255);
			end
            me.setCleanState();
        end

		function setVideoPlayer(me, in)
            me.stimulus = in;
			if in.isSetup
				me.screen = in.sM;
				me.videoSize = [me.stimulus.width; me.stimulus.height];
			end
        end
        
        function setCleanState(me)
            me.calState        = me.calStateEnum.undefined;
            me.currentPoint    = nan(1,3);
			if ~isempty(me.stimulus) && isa(me.stimulus,'movieStimulus')
                try me.stimulus.reset(); end %#ok<*TRYNC>
			end
        end

        function pos = get.pos(me)
            pos = me.currentPoint(2:3);
        end
        
        function qAllowAcceptKey = doDraw(me,wpnt,drawCmd,currentPoint,pos,~,~)
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
                    me.setCleanState();
                end
                return;
			end

			% make sure movieStimulus is setup
			if ~me.stimulus.isSetup
				setup(me.stimulus, me.screen);
				me.videoSize = [me.stimulus.width; me.stimulus.height];
			end
            
            % now that we have a wpnt, interrogate window
            if isempty(me.qFloatColorRange) && ~isempty(wpnt)
                me.qFloatColorRange    = Screen('ColorRange',wpnt)==1;
            end
            
            % check point changed
            curT = GetSecs;     % instead of using time directly, you could use the 'tick' call sequence number input to this function to animate your display
            if strcmp(drawCmd,'new')
                me.currentPoint    = [currentPoint pos];
                me.pointStartT     = curT;
                me.calState        = me.calStateEnum.showing;
            elseif strcmp(drawCmd,'redo')
                % start blink, restart animation.
                me.calState        = me.calStateEnum.blinking;
                me.blinkStartT     = curT;
                me.pointStartT     = 0;
            else % drawCmd == 'draw'
                % regular draw: check state transition
                if me.calState==me.calStateEnum.blinking && (curT-me.blinkStartT)>me.blinkInterval*me.blinkCount*2
                    % blink finished
                    me.calState    = me.calStateEnum.showing;
                    me.pointStartT = curT;
                end
            end
            
            % determine current point position
            curPos = me.currentPoint(2:3);
            
            % determine if we're ready to accept the user pressing the
            % accept calibration point button. User should not be able to
            % press it if point is not yet at the final position
            qAllowAcceptKey = me.calState~=me.calStateEnum.blinking;
            
            if ~isempty(wpnt)
				me.stimulus.updateXY(curPos(1),curPos(2));
				if (me.calState~=me.calStateEnum.blinking || mod((curT-me.blinkStartT)/me.blinkInterval/2,1)>.5)
					me.stimulus.draw();
				end
            end
        end
    end
    
    methods (Access = private, Hidden)
        function clr = getColorForWindow(me,clr)
            if me.qFloatColorRange
                clr = double(clr)/255;
            end
        end
    end
end
