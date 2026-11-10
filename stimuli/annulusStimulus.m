% ========================================================================
%> @brief unfilled circular outline (annulus) stimulus, inherits from baseStimulus
%> ANNULUSSTIMULUS draws a circular outline of a given outer diameter and line
%> thickness using Screen('FrameOval'), leaving the interior untouched so the
%> screen background shows through — i.e. an "empty circle" / ring.
%>
%> Screen('FrameOval') renders a true annular sector (gluDisk with an inner and
%> outer radius, one polygon slice per pixel of circumference), so the ring is
%> smooth and its OUTER edge is exactly `size` degrees across; `lineWidth` grows
%> inwards from that outer edge.
%>
%> Typical use — a 2° empty circle with a 0.05° outline:
%>   a = annulusStimulus('size',2,'lineWidth',0.05,'colour',[0 0 0]);
%>   setup(a, sM); draw(a);
%>
%> See also discStimulus (filled disc), fixationCrossStimulus (cross).
%>
%> Copyright ©2014-2026 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ========================================================================
classdef annulusStimulus < baseStimulus

	properties %--------------------PUBLIC PROPERTIES----------%
		%> type can be "simple"
		type = 'simple'
		%> thickness of the circular outline in visual degrees (°). Grows
		%> inwards from the outer edge, so the outer diameter is always
		%> `size`. Values >= size/2 close the ring into a filled disc.
		lineWidth double {mustBePositive} = 0.1
	end

	properties (SetAccess = protected, GetAccess = public)
		%> stimulus family
		family = 'annulus'
	end

	properties (SetAccess = private, GetAccess = public, Hidden = true)
		typeList = {'simple'}
	end

	properties (SetAccess = private, GetAccess = public, Hidden = true)
		%> outer diameter in pixels, computed on setup/update
		sizeOut double = []
		%> outline thickness in pixels, computed on setup/update
		lineWidthOut double = []
		%> RGBA colour used for drawing, computed on setup/update
		colourOut double = []
	end

	properties (SetAccess = private, GetAccess = private)
		%> do we need to swap the blend mode for drawing?
		changeBlend logical = false
		allowedProperties = {'lineWidth'}
	end

	%=======================================================================
	methods %------------------PUBLIC METHODS
	%=======================================================================

		% ===================================================================
		%> @brief Class constructor
		%>
		%> @param varargin are passed as a structure of properties which is
		%> parsed.
		%> @return instance of the class.
		% ===================================================================
		function me = annulusStimulus(varargin)
			args = optickaCore.addDefaults(varargin,...
				struct('name','Annulus','colour',[1 1 1 1],'size',2,'lineWidth',0.05));
			me = me@baseStimulus(args); %we call the superclass constructor first
			me.parseArgs(args, me.allowedProperties);

			me.isRect = true; %we position and draw using a rect
			me.szIsPx = false; %size is defined in degrees

			me.salutation('constructor','Stimulus initialisation complete');
		end

		% ===================================================================
		%> @brief Setup the stimulus object
		%>
		%> caches the degree->pixel conversions used by draw() so that no PTB
		%> or property lookups happen per frame.
		%>
		%> @param sM handle to the current screenManager object
		% ===================================================================
		function setup(me, sM)

			reset(me);
			me.inSetup = true; me.isSetup = false;
			if isempty(me.isVisible); me.show; end

			me.sM = sM;
			if ~sM.isOpen; error('Screen needs to be Open!'); end
			me.ppd = sM.ppd;
			me.screenVals = sM.screenVals;

			%transient position copies used by baseStimulus.computePosition()
			if isempty(me.findprop('xPositionOut')); p = me.addprop('xPositionOut'); p.Transient = true; end %#ok<*NASGU>
			if isempty(me.findprop('yPositionOut')); p = me.addprop('yPositionOut'); p.Transient = true; end
			me.xPositionOut = me.xPosition * me.ppd;
			me.yPositionOut = me.yPosition * me.ppd;

			me.computeDrawingValues();

			addRuntimeProperties(me); % create transient runtime action properties

			if me.sM.blend && strcmpi(me.sM.srcMode,'GL_SRC_ALPHA') && strcmpi(me.sM.dstMode,'GL_ONE_MINUS_SRC_ALPHA')
				me.changeBlend = false;
			else
				me.changeBlend = true;
			end

			me.inSetup = false; me.isSetup = true;
			computePosition(me);
			setRect(me);
			if me.doAnimator; me.animator.setup(me.sM); me.syncAnimator(); end
		end

		% ===================================================================
		%> @brief Update the stimulus for runExperiment
		%>
		%> Call between trials after changing colour/size/position: rebuilds
		%> the cached pixel values from the user-facing properties.
		% ===================================================================
		function update(me)
			me.rewindAnimator();
			resetTicks(me);
			me.inSetup = false;
			me.xPositionOut = me.xPosition * me.ppd;
			me.yPositionOut = me.yPosition * me.ppd;
			me.computeDrawingValues();
			computePosition(me);
			setRect(me);
		end

		% ===================================================================
		%> @brief Draw the ring into the current PTB draw buffer
		% ===================================================================
		function draw(me)
			if me.isVisible && me.tick >= me.delayTicks && me.tick < me.offTicks
				if me.mouseOverride && ~me.mouseValid; me.tick = me.tick + 1; return; end
				pen = min(me.lineWidthOut, me.szPx / 2); %never close the ring
				if pen < 1; pen = 1; end
				if me.changeBlend; Screen('BlendFunction', me.sM.win, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA'); end
				% Screen('FrameOval', windowPtr [, colour] [, rect] [, penWidth] [, penHeight])
				Screen('FrameOval', me.sM.win, me.colourOut, me.mvRect, pen);
				if me.changeBlend; Screen('BlendFunction', me.sM.win, me.sM.srcMode, me.sM.dstMode); end
				me.drawTick = me.drawTick + 1;
			end
			if me.isVisible; me.tick = me.tick + 1; end
		end

		% ===================================================================
		%> @brief Animate the stimulus for runExperiment
		% ===================================================================
		function animate(me)
			if me.isVisible && me.tick >= me.delayTicks
				if me.mouseOverride
					getMousePosition(me);
					if me.mouseValid
						me.mvRect = CenterRectOnPointd(me.mvRect, me.mouseX, me.mouseY);
					end
					return
				end
				if me.doAnimator
					me.applyAnimator();
				elseif me.doMotion
					me.mvRect = OffsetRect(me.mvRect, me.dX_, me.dY_);
				end
			end
		end

		% ===================================================================
		%> @brief Reset the stimulus back to its pre-setup state
		% ===================================================================
		function reset(me)
			resetTicks(me);
			me.inSetup = false;
			me.colourOut = [];
			me.sizeOut = [];
			me.lineWidthOut = [];
			me.removeTmpProperties;
		end

		% ===================================================================
		%> @brief Small demo to check the stimulus renders correctly
		%> opens a screen and previews this annulus for 3 seconds
		% ===================================================================
		function demo(me)
			run(me, false, 3);
		end

	end %---END PUBLIC METHODS---%

	%=======================================================================
	methods ( Access = protected ) %-------PROTECTED METHODS-----% 
	%=======================================================================

		% ===================================================================
		%> @brief Convert properties into cached pixel drawing values
		% ===================================================================
		function computeDrawingValues(me)
			me.sizeOut = me.size * me.ppd;
			me.szPx = me.sizeOut;
			me.szD = me.size;
			me.lineWidthOut = max(1, me.lineWidth * me.ppd);
			c = me.colour;
			if numel(c) == 3; c = [c(1:3) me.alpha]; end
			if isempty(c); c = [1 1 1 me.alpha]; end
			me.colourOut = c(1:4);
		end

		% ===================================================================
		%> @brief setRect makes the PsychRect for the outline
		%> the rect is square, sized `size` degrees and centred on xFinal/yFinal
		% ===================================================================
		function setRect(me)
			if isempty(me.xFinal) || isempty(me.yFinal) || isempty(me.szPx); return; end
			if me.mouseOverride && me.mouseValid
				me.mvRect = CenterRectOnPointd([0 0 me.szPx me.szPx], me.mouseX, me.mouseY);
			else
				me.mvRect = CenterRectOnPointd([0 0 me.szPx me.szPx], me.xFinal, me.yFinal);
			end
			me.setAnimationDelta();
		end

	end

end
