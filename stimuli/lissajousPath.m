% ========================================================================
%> @brief LISSAJOUSPATH Generates per-frame positions along a Lissajous curve
%>
%> A Lissajous figure is the path traced by two orthogonal sinusoidal
%> motions, see https://en.wikipedia.org/wiki/Lissajous_curve
%>
%>   x(τ) = xPosition + xAmplitude .* sin(a .* τ + delta)
%>   y(τ) = yPosition - yAmplitude .* sin(b .* τ)
%>
%> where τ runs from 0 to 2π.nPeriods. The ratio a:b sets the classic
%> 1:1, 1:2, 2:3 … figures, `delta` is the phase offset (0 gives a line,
%> π/2 an ellipse/circle) and `size` sets the peak-to-peak extent of the
%> figure in visual degrees. Positions are returned in Opticka degrees
%> (+X right, +Y down); the vertical axis is flipped so the figure appears
%> in the standard mathematical orientation (set `flipY` false to keep the
%> raw Opticka direction).
%>
%> The curve is resampled at constant arc length, so `speed` is the true
%> tangential velocity in °/s independent of local curvature. The display
%> frame rate is read from a screenManager during setup(), and one full
%> curve is generated when `totalTime` is empty:
%>
%> ```matlab
%> s = screenManager; open(s);              % PTB screen
%> t = discStimulus('size',1,'colour',[1 0 0]);
%> setup(t, s);
%> p = lissajousPath('a',3,'b',4,'delta',pi/4,'size',15,'speed',8);
%> setup(p, s);                             % fps from screenVals.fps
%> for i = 1:p.nFrames
%> 	[x, y] = step(p, t);                  % advance + move the stimulus
%> 	draw(t); flip(s);
%> end
%> ```
%>
%> Setup can also take a plain struct with `fps` (and `ppd`) fields, which
%> lets you generate paths offline (analysis, prerendering, unit tests)
%> without opening a PTB screen.
%>
%> Copyright ©2014-2026 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ========================================================================
classdef lissajousPath < optickaCore

	properties
		%> horizontal frequency coefficient a in x = A.sin(a.τ + δ), the
		%> a:b ratio defines the figure (e.g. a=3 b=4 gives a 3:4 figure)
		a double {mustBePositive} = 1
		%> vertical frequency coefficient b in y = B.sin(b.τ)
		b double {mustBePositive} = 2
		%> phase offset δ in radians; 0 gives a line, π/2 an ellipse and
		%> π/4 a tilted figure (see the Lissajous phase table)
		delta double = pi/2
		%> centre X position in visual degrees, +X is right of screen centre
		xPosition double = 0
		%> centre Y position in visual degrees, +Y is below screen centre
		yPosition double = 0
		%> peak-to-peak size of the figure in visual degrees, applied to
		%> both axes unless xSize / ySize are set
		size double {mustBePositive} = 10
		%> optional peak-to-peak X extent in degrees, overrides `size` for X
		xSize double {mustBePositive} = []
		%> optional peak-to-peak Y extent in degrees, overrides `size` for Y
		ySize double {mustBePositive} = []
		%> tangential speed along the path in °/s, negative reverses the
		%> direction of travel
		speed double = 10
		%> total animation time in seconds. If empty the duration is set
		%> by traversing one full curve at `speed`; if set, exactly this
		%> many seconds are generated at `speed` (the curve may repeat)
		totalTime double = []
		%> number of 2π parameter periods defining one full curve; with
		%> integer a and b the curve closes exactly at this point
		nPeriods double {mustBePositive} = 1
		%> flip the vertical axis so the figure is in standard mathematical
		%> orientation (+Y up); Opticka's native +Y is down
		flipY logical = true
		%> read the frame rate from the screenManager during setup(); set
		%> false to use the `fps` property instead (offline generation)
		useScreenFPS logical = true
		%> frame rate in Hz, filled from the screenManager during setup()
		fps double {mustBePositive} = []
		%> rotate stimuli passed to step()/apply() to the local tangent
		orientStimulus logical = false
		%> verbose output?
		verbose = false
	end

	properties (SetAccess = protected, GetAccess = public)
		%> total arc length of the generated path in degrees
		arcLength double = []
		%> per-frame arc length step in degrees
		dS double = []
		%> per-frame X position in degrees
		x double = []
		%> per-frame Y position in degrees
		y double = []
		%> per-frame direction of travel in degrees, 0 = right, 90 = down
		%> (matches the Opticka stimulus angle convention)
		direction double = []
		%> per-frame time in seconds from path onset
		t double = []
		%> per-frame curve parameter τ in radians
		tau double = []
		%> current frame index (1-based), 0 before the first step()
		tick double = 0
		%> pixels per degree, inherited from the screenManager on setup
		ppd double = 36
		%> has setup() generated a path?
		isSetup logical = false
	end

	properties (Dependent = true, SetAccess = protected, GetAccess = public)
		%> horizontal semi-axis in degrees, `size`/2 or `xSize`/2
		xAmplitude double
		%> vertical semi-axis in degrees, `size`/2 or `ySize`/2
		yAmplitude double
		%> frame interval in seconds
		ifi double
		%> number of frames generated
		nFrames double
		%> duration of the generated path in seconds
		duration double
		%> actual tangential speed in °/s after frame quantisation
		speedActual double
	end

	properties (Access = protected)
		%> dense parametric path samples in degrees
		pathX double = []
		%> dense parametric path samples in degrees
		pathY double = []
		%> cumulative arc length of the dense path samples
		pathS double = []
		%> curve parameter τ of the dense path samples
		pathTau double = []
		%> +1 or -1, from the sign of `speed`
		directionSign double = 1
		%> screen manager, when one was passed to setup()
		sM screenManager
		%> properties allowed to be passed on construction
		allowedProperties = ["a","b","delta","xPosition","yPosition","size",...
			"xSize","ySize","speed","totalTime","nPeriods","flipY",...
			"useScreenFPS","fps","orientStimulus","verbose"]
	end

	%=======================================================================
	methods %------------------PUBLIC METHODS
	%=======================================================================

		% ===================================================================
		%> @brief Class constructor
		%>
		%> @param varargin are passed as a structure of properties which is
		%> parsed.
		%> @return instance of class.
		% ===================================================================
		function me = lissajousPath(varargin)
			args = optickaCore.addDefaults(varargin,struct('name','lissajousPath'));
			me = me@optickaCore(args); %superclass constructor
			me.parseArgs(args,me.allowedProperties);
		end

		% ===================================================================
		%> @brief setup generates the path and reads the display frame rate
		%>
		%> @param screen a screenManager instance, or a struct with `fps`
		%> (and optionally `ppd` or a `screenVals` sub-struct) for offline
		%> generation. If omitted, a previously stored screenManager is used
		%> or the `fps` property (default 60 Hz).
		% ===================================================================
		function setup(me,screen)
			if exist('screen','var') && isa(screen,'screenManager')
				me.sM = screen;
				if me.useScreenFPS && isfield(screen.screenVals,'fps') ...
						&& ~isempty(screen.screenVals.fps) && screen.screenVals.fps > 0
					me.fps = screen.screenVals.fps;
				end
				me.ppd = screen.ppd;
			elseif exist('screen','var') && isstruct(screen)
				sv = screen;
				if isfield(sv,'screenVals') && isstruct(sv.screenVals)
					sv = sv.screenVals;
				end
				if me.useScreenFPS && isfield(sv,'fps') && ~isempty(sv.fps) ...
						&& sv.fps > 0
					me.fps = sv.fps;
				end
				if isfield(sv,'ppd') && ~isempty(sv.ppd)
					me.ppd = sv.ppd;
				end
			elseif isscalar(me.sM) && isa(me.sM,'screenManager')
				if me.useScreenFPS && ~isempty(me.sM.screenVals.fps)
					me.fps = me.sM.screenVals.fps;
				end
				me.ppd = me.sM.ppd;
			end

			if isempty(me.fps) || me.fps <= 0
				me.fps = 60;
				if me.verbose
					fprintf('≣≣≣≣⊱ lissajousPath: no fps available, using 60Hz\n');
				end
			end

			me.buildPath;
			me.isSetup = true;

			if me.verbose
				fprintf(['≣≣≣≣⊱ lissajousPath %g:%g δ=%0.3frad size=%g° ' ...
					'speed=%g°/s → %i frames @ %gHz (%.3fs, %0.2f° path)\n'],...
					me.a,me.b,me.delta,me.size,me.speed,me.nFrames,me.fps,...
					me.duration,me.arcLength);
			end
		end

		% ===================================================================
		%> @brief update rebuilds the path after properties have changed
		%>
		%> Use this between trials when a, b, delta, size, speed, totalTime
		%> or the centre have been modified; no need to call setup() again.
		% ===================================================================
		function update(me)
			if isempty(me.fps); me.fps = 60; end
			me.buildPath;
			me.isSetup = true;
		end

		% ===================================================================
		%> @brief step advances one frame and returns the new position
		%>
		%> The first call returns the start of the curve (frame 1) and the
		%> position wraps to frame 1 after the last frame, so a loop is
		%> seamless. Any stimuli passed are moved to the new position.
		%>
		%> @param varargin optional baseStimulus objects (or a cell array)
		%> to move, see apply()
		%> @return x X position in degrees
		%> @return y Y position in degrees
		% ===================================================================
		function [x,y] = step(me,varargin)
			if ~me.isSetup || me.nFrames < 1
				error('lissajousPath:notSetup','call setup() before step()');
			end
			me.tick = mod(me.tick,me.nFrames) + 1;
			x = me.x(me.tick);
			y = me.y(me.tick);
			if ~isempty(varargin)
				me.apply(varargin{:});
			end
		end

		% ===================================================================
		%> @brief apply moves stimuli to the current frame position
		%>
		%> Does not advance the frame counter, so several stimuli can be
		%> moved to the same position. Each argument may be a baseStimulus
		%> or a cell array of stimuli; stimuli that are not set up are
		%> skipped. With `orientStimulus` true the stimulus angle is set to
		%> the local tangent direction.
		%>
		%> @param varargin baseStimulus objects or cell arrays of them
		% ===================================================================
		function apply(me,varargin)
			if me.nFrames < 1; return; end
			idx = max(1,me.tick);
			posX = me.x(idx);
			posY = me.y(idx);
			for i = 1:numel(varargin)
				item = varargin{i};
				if iscell(item)
					items = item;
				else
					items = {item};
				end
				for j = 1:numel(items)
					thisStim = items{j};
					if isa(thisStim,'baseStimulus') && thisStim.isSetup
						thisStim.updateXY(posX,posY,true);
						if me.orientStimulus && isprop(thisStim,'angle')
							thisStim.setP('angle',me.direction(idx));
						end
					end
				end
			end
		end

		% ===================================================================
		%> @brief getPosition returns the position of a given frame
		%>
		%> @param frame frame index (1-based), wraps outside 1..nFrames
		%> @return x X position in degrees
		%> @return y Y position in degrees
		% ===================================================================
		function [x,y] = getPosition(me,frame)
			x = []; y = [];
			if me.nFrames < 1; return; end
			if ~exist('frame','var') || isempty(frame); frame = max(1,me.tick); end
			frame = mod(round(frame)-1,me.nFrames) + 1;
			x = me.x(frame);
			y = me.y(frame);
		end

		% ===================================================================
		%> @brief seek jumps to a time or frame without stepping
		%>
		%> Useful to randomise the start phase of a pursuit path between
		%> trials, or to jump to a known point in the animation.
		%>
		%> @param t time in seconds from path onset
		%> @param useFrame if true, `t` is treated as a frame index
		% ===================================================================
		function seek(me,t,useFrame)
			if ~exist('useFrame','var') || isempty(useFrame); useFrame = false; end
			if me.nFrames < 1; me.tick = 0; return; end
			if useFrame
				frame = round(t);
			else
				frame = round(t * me.fps) + 1;
			end
			me.tick = mod(frame-1,me.nFrames) + 1;
		end

		% ===================================================================
		%> @brief rewind returns to the start of the path
		%>
		%> Keeps the generated path so a trial can be repeated cheaply
		%> without calling setup() again.
		% ===================================================================
		function rewind(me)
			me.tick = 0;
		end

		% ===================================================================
		%> @brief reset clears the generated path back to pre-setup state
		% ===================================================================
		function reset(me)
			me.tick			= 0;
			me.x			= [];
			me.y			= [];
			me.direction	= [];
			me.t			= [];
			me.tau			= [];
			me.pathX		= [];
			me.pathY		= [];
			me.pathS		= [];
			me.pathTau		= [];
			me.arcLength	= [];
			me.dS			= [];
			me.isSetup		= false;
		end

		% ===================================================================
		%> @brief getData returns the generated path as a struct of arrays
		%>
		%> Suitable for saving alongside behavioural data.
		% ===================================================================
		function data = getData(me)
			data = struct(...
				'frame',(1:me.nFrames)',...
				'time',me.t(:),...
				'tau',me.tau(:),...
				'x',me.x(:),...
				'y',me.y(:),...
				'direction',me.direction(:),...
				'speed',me.speedActual,...
				'fps',me.fps,...
				'a',me.a,...
				'b',me.b,...
				'delta',me.delta,...
				'size',me.size,...
				'xPosition',me.xPosition,...
				'yPosition',me.yPosition,...
				'arcLength',me.arcLength);
		end

		% ===================================================================
		%> @brief getPath returns the dense parametric path samples
		%>
		%> These are the samples used to build the arc-length table, useful
		%> for plotting or distance analysis. Positions are in degrees.
		%>
		%> @return x dense X samples in degrees
		%> @return y dense Y samples in degrees
		% ===================================================================
		function [x,y] = getPath(me)
			x = me.pathX;
			y = me.pathY;
		end

		% ===================================================================
		%> @brief plotPath plots the path and the generated frame positions
		%>
		%> @param ax optional axes handle, a new figure is made if omitted
		%> @return ax the axes handle
		% ===================================================================
		function ax = plotPath(me,ax)
			if ~exist('ax','var') || isempty(ax)
				f = figure('Name','lissajousPath');
				ax = axes(f);
			end
			plot(ax,me.pathX,me.pathY,'-','Color',[0.65 0.65 0.65],'LineWidth',1);
			hold(ax,'on');
			plot(ax,me.x,me.y,'k.','MarkerSize',8);
			plot(ax,me.x(1),me.y(1),'o','MarkerFaceColor',[0.85 0.2 0.2],...
				'MarkerEdgeColor','none','MarkerSize',8);
			hold(ax,'off');
			axis(ax,'equal');
			axis(ax,'ij');
			grid(ax,'on');
			xlabel(ax,'X position (°)');
			ylabel(ax,'Y position (°)');
			title(ax,sprintf('%g:%g  δ = %0.2fπ  size = %g°  speed = %g°/s',...
				me.a,me.b,me.delta/pi,me.size,me.speed));
		end

		% ===================================================================
		%> @brief get.xAmplitude horizontal semi-axis in degrees
		% ===================================================================
		function value = get.xAmplitude(me)
			if isempty(me.xSize)
				value = me.size / 2;
			else
				value = me.xSize / 2;
			end
		end

		% ===================================================================
		%> @brief get.yAmplitude vertical semi-axis in degrees
		% ===================================================================
		function value = get.yAmplitude(me)
			if isempty(me.ySize)
				value = me.size / 2;
			else
				value = me.ySize / 2;
			end
		end

		% ===================================================================
		%> @brief get.ifi frame interval in seconds
		% ===================================================================
		function value = get.ifi(me)
			if isempty(me.fps)
				value = [];
			else
				value = 1 / me.fps;
			end
		end

		% ===================================================================
		%> @brief get.nFrames number of generated frames
		% ===================================================================
		function value = get.nFrames(me)
			value = numel(me.x);
		end

		% ===================================================================
		%> @brief get.duration duration of the generated path in seconds
		% ===================================================================
		function value = get.duration(me)
			if isempty(me.fps)
				value = [];
			else
				value = me.nFrames / me.fps;
			end
		end

		% ===================================================================
		%> @brief get.speedActual tangential speed after frame quantisation
		% ===================================================================
		function value = get.speedActual(me)
			if isempty(me.dS) || isempty(me.fps)
				value = [];
			else
				value = me.directionSign * me.dS * me.fps;
			end
		end

	end % END PUBLIC METHODS

	%=======================================================================
	methods ( Static ) %------------------STATIC METHODS
	%=======================================================================

		% ===================================================================
		%> @brief demo plots the classic Lissajous phase table
		%>
		%> Reproduces the standard frequency-ratio × phase table (1:1 to
		%> 5:6 across δ = 0, π/4, π/2, 3π/4, π) so the geometry can be
		%> checked at a glance.
		% ===================================================================
		function demo()
			ratios = [1 1; 1 2; 1 3; 2 3; 3 4; 3 5; 4 5; 5 6];
			phases = [0 pi/4 pi/2 3*pi/4 pi];
			f = figure('Name','Lissajous table','Color','w');
			tl = tiledlayout(f,numel(ratios),numel(phases),...
				'TileSpacing','compact','Padding','compact');
			for r = 1:size(ratios,1)
				for c = 1:numel(phases)
					ax = nexttile(tl);
					p = lissajousPath('a',ratios(r,1),'b',ratios(r,2),...
						'delta',phases(c),'size',10,'speed',10,...
						'useScreenFPS',false,'fps',60,'verbose',false);
					setup(p,struct('fps',60));
					plot(ax,p.pathX,p.pathY,'k-','LineWidth',1);
					axis(ax,'equal');
					axis(ax,'off');
					if r == 1
						title(ax,phaseLabel(phases(c)));
					end
					if c == 1
						ylabel(ax,sprintf('%d:%d',ratios(r,1),ratios(r,2)));
					end
				end
			end
		end

		% ===================================================================
		%> @brief demoAnimate animates a disc along a Lissajous path in PTB
		%>
		%> Minimal end-to-end example: open a screen, move a disc along the
		%> path at `speed` °/s and flip each frame. Press ESC to stop.
		% ===================================================================
		function demoAnimate()
			s = screenManager;
			if max(Screen('Screens')) == 0
				PsychDebugWindowConfiguration([],0.6);
			end
			sv = open(s); %#ok<NASGU>
			target = discStimulus('size',1.2,'colour',[0.9 0.2 0.2 1]);
			setup(target,s);
			p = lissajousPath('a',3,'b',4,'delta',pi/4,'size',12,'speed',10);
			setup(p,s);
			fprintf('≣≣≣≣⊱ animating %i frames (%.2fs at %0.2f°/s)\n',...
				p.nFrames,p.duration,p.speedActual);

			RestrictKeysForKbCheck(KbName('ESCAPE'));
			Priority(1);
			for i = 1:p.nFrames
				step(p,target);
				draw(target);
				drawText(s,sprintf('Lissajous %g:%g  frame %i/%i',...
					p.a,p.b,p.tick,p.nFrames));
				flip(s);
				[isKey,~,keyCode] = KbCheck(-1);
				if isKey && keyCode(KbName('ESCAPE')); break; end
			end
			Priority(0);
			reset(target);
			close(s);
			fprintf('lissajousPath: %i frames, %.2fs at %0.2f°/s, %.1f° path\n',...
				p.nFrames,p.duration,p.speedActual,p.arcLength);
		end

	end % END STATIC METHODS

	%=======================================================================
	methods ( Access = protected ) %-------PROTECTED METHODS-----% 
	%=======================================================================

		% ===================================================================
		%> @brief buildPath generates the arc-length parametrised path
		%>
		%> Samples the parametric curve densely, builds a cumulative arc
		%> length table, then places each frame at a constant arc-length
		%> step so tangential speed is uniform regardless of curvature.
		%> Frames are linearly interpolated from that table, the residual
		%> against the analytic curve is <0.001° even at cusps.
		% ===================================================================
		function buildPath(me)
			me.reset;

			if me.speed == 0
				error('lissajousPath:speed','speed must be non-zero to generate a path');
			end

			me.directionSign = sign(me.speed);

			%> dense samples: at least 2048 per period, scaled with the
			%> fastest frequency component so high-order figures are smooth
			perPeriod = max(2048,ceil(512 * max(me.a,me.b)));
			nSamples = max(2048,ceil(perPeriod * me.nPeriods));
			thisTau = linspace(0,2*pi*me.nPeriods,nSamples);
			px = me.xPosition + me.xAmplitude .* sin(me.a .* thisTau + me.delta);
			if me.flipY
				py = me.yPosition - me.yAmplitude .* sin(me.b .* thisTau);
			else
				py = me.yPosition + me.yAmplitude .* sin(me.b .* thisTau);
			end

			%> cumulative arc length table, dropping any duplicate points
			dStep = hypot(diff(px),diff(py));
			s = [0 cumsum(dStep)];
			keep = [true,diff(s) > 0];
			me.pathX = px(keep);
			me.pathY = py(keep);
			me.pathS = s(keep);
			me.pathTau = thisTau(keep);
			me.arcLength = me.pathS(end);
			if me.arcLength <= 0
				error('lissajousPath:degenerate',...
					'degenerate path, check a, b, delta and size');
			end

			%> frames: one full curve at `speed`, or exactly `totalTime`
			if isempty(me.totalTime)
				nF = max(2,round(me.arcLength / (abs(me.speed) / me.fps)));
				me.dS = me.arcLength / nF;
			else
				nF = max(2,round(me.totalTime * me.fps));
				me.dS = abs(me.speed) / me.fps;
				if me.dS > me.arcLength && me.verbose
					warning('lissajousPath:stepTooLarge',...
						'speed exceeds one full curve per frame, path wraps each frame');
				end
			end

			%> place every frame at a constant arc-length step and wrap
			sFrame = mod(me.directionSign .* (0:nF-1) .* me.dS,me.arcLength);
			me.x = interp1(me.pathS,me.pathX,sFrame,'linear');
			me.y = interp1(me.pathS,me.pathY,sFrame,'linear');

			%> tangent direction per frame in Opticka screen coordinates
			%> (0 = right, 90 = down), following the direction of travel
			dx = gradient(me.pathX);
			dy = gradient(me.pathY);
			tx = interp1(me.pathS,me.directionSign .* dx,sFrame,'linear');
			ty = interp1(me.pathS,me.directionSign .* dy,sFrame,'linear');
			me.direction = mod(atan2d(ty,tx),360);

			%> per-frame curve parameter and time
			me.tau = interp1(me.pathS,me.pathTau,sFrame,'linear');
			me.t = (0:nF-1) ./ me.fps;
			me.tick = 0;
		end

	end % END PROTECTED METHODS
end

% ========================================================================
%> @brief phaseLabel formats a phase as a fraction of π for plot titles
% ========================================================================
function out = phaseLabel(phase)
	f = phase / pi;
	if abs(f) < 1e-9
		out = '0';
	elseif abs(f - 1) < 1e-9
		out = '\pi';
	else
		[n,d] = rat(f);
		out = sprintf('%d\\pi/%d',n,d);
	end
end
