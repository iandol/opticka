% ========================================================================
%> @brief metaStimulus is a wrapper object for opticka stimuli
%> METASTIMULUS a collection of stimuli, wrapped in one object. It
%> allows you to treat a group of heterogenous stimuli as if they are a single
%> stimulus, so for example animate(metaStimulus) will run the animate method
%> for all stimuli in the group without having to call it for each stimulus.
%> You can also pick individual stimuli by using cell indexing of this
%> object. So for example metaStimulus{2} actually calls
%> metaStimulus.stimuli{2}.
%> You can also pass a mask stimulus set, and when you toggle showMask, the
%> mask stimuli will be drawn instead of the stimuli themselves, the timing
%> is left to the calling function.
%>
%> Copyright ©2014-2022 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ========================================================================
classdef metaStimulus < optickaCore
	
	%--------------------PUBLIC PROPERTIES----------%
	properties 
		%>cell array of opticka stimuli to manage
		stimuli cell		= {}
		%> do we draw the mask stimuli instead?
		showMask			= false
		%>mask stimuli
		maskStimuli			= {}
		%> screenManager handle
		screen
		%> verbose?
		verbose				= false
		%> choice allows to call only 1 stimulus in the group
		choice				= []
		%> which stimuli should fixation follow, see getFixationPositions()
		fixationChoice		= []
		%> which stimuli should exclusion follow, see getExclusionPositions()
		exclusionChoice		= []
		%> randomisation table to apply to a stimulus
		stimulusTable		= []
		%> choice for table
		tableChoice			= []
		%> control table for keyboard changes
		controlTable		= []
		%> show subsets of stimuli?
		stimulusSets		= []
		%> which set of stimuli to display
		setChoice			= 0;
		%> currently unused
		flashRate			= 0.25
	end
	
	%--------------------DEPENDENT PROPERTIES----------%
	properties (SetAccess = private, Dependent = true) 
		%> n number of stimuli managed by metaStimulus
		n
		%> n number of mask stimuli
		nMask
	end
	
	%--------------------VISIBLE PROPERTIES----------%
	properties (SetAccess = private, GetAccess = public) 
		%> stimulus family
		family				= 'meta'
		%> structure holding positions for each stimulus
		stimulusPositions	= []
		%> used for optional logging for update times
		updateLog			= []
	end
	
	%--------------------VISIBLE PROPERTIES----------%
	properties (SetAccess = private, GetAccess = public, Transient = true)
		lastXPosition		= 0
		lastYPosition		= 0
		lastXExclusion		= []
		lastYExclusion		= []
	end
	
	%--------------------PRIVATE PROPERTIES----------%
	properties (SetAccess = private, GetAccess = private)
		%> cache our dependent values for a bit more speed...
		n_
		nMask_
		%> allowed properties passed to object upon construction
		allowedProperties = 'setChoice|stimulusSets|controlTable|showMask|maskStimuli|verbose|stimuli|screen|choice|fixationChoice|exclusionChoice|stimulusTable|tableChoice'
		sM
	end
	
	%=======================================================================
	methods %------------------PUBLIC METHODS
	%=======================================================================
		
		% ===================================================================
		%> @brief Class constructor
		%>
		%> More detailed description of what the constructor does.
		%>
		%> @param varargin are passed as a structure of properties which is
		%> parsed.
		%> @return instance of class.
		% ===================================================================
		function me = metaStimulus(varargin)
			args = optickaCore.addDefaults(varargin,struct('name','metaStimulus'));
			me=me@optickaCore(args); %superclass constructor
			me.parseArgs(args,me.allowedProperties);
		end
		
		% ===================================================================
		%> @brief setup wrapper
		%>
		%> @param
		%> @return
		% ===================================================================
		function setup(me,s)
			if ~exist('s','var') || ~isa(s,'screenManager')
				if isa(me.screen,'screenManager')
					s = me.screen;
				else
					s = [];
				end
			end	
			if isa(s,'screenManager')
				for i = 1:me.n
					setup(me.stimuli{i},s);
				end
				for i = 1:me.nMask
					setup(me.maskStimuli{i},s);
				end
			else
				error('metaStimulus setup: no screenManager has been provided!!!')
			end
		end
		
		% ===================================================================
		%> @brief update wrapper
		%>
		%> @param choice override a single choice
		%> @return
		% ===================================================================
		function update(me,choice,mask)
			%tic
			if ~exist('mask','var');mask=false;end
			if exist('choice','var') && isnumeric(choice) %user forces a single stimulus
				
				for i = choice
					update(me.stimuli{i});
				end
				
			elseif ~isempty(me.choice) && isnumeric(me.choice) %object forces a single stimulus
				
				for i = me.choice
					update(me.stimuli{me.choice});
				end
				
			elseif mask && me.showMask == true && me.nMask_ > 0 %draw mask instead
				
				for i = 1:me.nMask
					update(me.maskStimuli{i});
				end
				
			else
		
				for i = 1:me.n_
					update(me.stimuli{i});
				end
				
			end
			%me.updateLog = [me.updateLog toc*1000];
		end
		
		% ===================================================================
		%> @brief draw wrapper
		%>
		%> @param choice override a single choice
		%> @return
		% ===================================================================
		function draw(me,choice)
			if exist('choice','var') && isnumeric(choice) %user forces a single stimulus
				
				for i = choice
					draw(me.stimuli{i});
				end
				
			elseif ~isempty(me.choice) && isnumeric(me.choice) %object forces a single stimulus
				
				for i = me.choice
					draw(me.stimuli{i});
				end
				
			elseif me.showMask == true && me.nMask_ > 0 %draw mask instead
				
				for i = 1:me.nMask_
					draw(me.maskStimuli{i});
				end
				
			else
				
				for i = 1:me.n_
					draw(me.stimuli{i});
				end
				
			end
		end
		
		% ===================================================================
		%> @brief animate wrapper
		%>
		%> @param choice allow a single selected stimulus
		%> @return
		% ===================================================================
		function animate(me,choice)
			if exist('choice','var') && isnumeric(choice) %user forces a stimulus
				
				for i = choice
					animate(me.stimuli{i});
				end
				
			elseif ~isempty(me.choice) && isnumeric(me.choice) %object forces a single stimulus
				
				for i = me.choice
					animate(me.stimuli{i});
				end
				
			elseif me.showMask == true && me.nMask_ > 0 %animate mask instead
				
				for i = 1:me.nMask_
					animate(me.maskStimuli{i});
				end
				
			else
	
				for i = 1:me.n_
					animate(me.stimuli{i});
				end
				
			end
		end
		
		% ===================================================================
		%> @brief reset ticks wrapper
		%>
		%> @param
		%> @return
		% ===================================================================
		function resetTicks(me)

			for i = 1:me.n
				resetTicks(me.stimuli{i});
			end
				
			for i = 1:me.nMask
				resetTicks(me.maskStimuli{i});
			end
			
		end
		
		% ===================================================================
		%> @brief reset wrapper
		%>
		%> @param
		%> @return
		% ===================================================================
		function reset(me)

			for i = 1:me.n
				reset(me.stimuli{i});
			end
				
			for i = 1:me.nMask
				reset(me.maskStimuli{i});
			end
			
		end
		
		% ===================================================================
		%> @brief randomise wrapper
		%>
		%> @param
		%> @return
		% ===================================================================
		function randomise(me)
			if ~isempty(me.stimulusTable)
				logs = '--->>> RANDOMISE Stimulus: ';
				for i = 1:length(me.stimulusTable)
					
					stims = me.stimulusTable(i).stimuli;
					name = me.stimulusTable(i).name;
					offset = me.stimulusTable(i).offset;
					
					if ~isempty(stims) && ~isempty(name)
	
						[r,c] = size(me.stimulusTable(i).values);
						if r > 1 && c > 1
							values = me.stimulusTable(i).values(randi(r),:);
						elseif r > 1
							values = me.stimulusTable(i).values(randi(r),1);
						else
							values = me.stimulusTable(i).values(1,randi(c));
						end

						for j=1:length(stims)
							if strcmpi(name,'xyPosition')
								me.stimuli{stims(j)}.xPositionOut = values(1);
								me.stimuli{stims(j)}.yPositionOut = values(2);
								me.lastXPosition = values(1);
								me.lastYPosition = values(2);
								logs = [logs 'XY: ' num2str(stims(j)) ];
							elseif isprop(me.stimuli{stims(j)}, [name 'Out'])
								me.stimuli{stims(j)}.([name 'Out']) = values;
								logs = [logs ' || ' name 'Out: ' num2str(values)];
								if ~isempty(offset)
									me.stimuli{offset(1)}.([name 'Out']) = values + offset(2);
									logs = [logs ' || OFFSET' name 'Out: ' num2str(values + offset(2))];
								end
							end
						end
					
					end
				end
				me.salutation(logs);
			end
		end
		
		% ===================================================================
		%> @brief Shorthand to set isVisible=true.
		%>
		% ===================================================================
		function show(me, choice)
			if exist('choice','var') && isnumeric(choice) %user forces a stimulus
				for i = choice
					show(me.stimuli{i});
				end
			else
				for i = 1:me.n_
					show(me.stimuli{i});
				end
			end
		end
				
		% ===================================================================
		%> @brief Shorthand to set isVisible=false.
		%>
		% ===================================================================
		function hide(me, choice)
			if exist('choice','var') && isnumeric(choice) %user forces a stimulus
				for i = choice
					hide(me.stimuli{i});
				end
			else
				for i = 1:me.n_
					hide(me.stimuli{i});
				end
			end
		end
		
		% ===================================================================
		%> @brief Edit -- fast change a particular value.
		%>
		% ===================================================================
		function edit(me, stims, var, value, mask)
			if ~exist('mask','var'); mask = false; end
			if mask == false
				for i = 1:length(stims)
					me.stimuli{stims(i)}.(var) = value;
				end
			else
				for i = 1:length(stims)
					me.maskStimuli{stims(i)}.(var) = value;
				end
			end
		end
		
		% ===================================================================
		%> @brief Return the stimulus fixation position
		%>s
		% ===================================================================
		function [x,y] = getFixationPositions(me)
			x = 0; y = 0;
			if ~isempty(me.fixationChoice)
				x=zeros(length(me.fixationChoice),1); y = x;
				for i=1:length(me.fixationChoice)
					x(i) = me.stimuli{me.fixationChoice(i)}.xPositionOut / me.screen.ppd;
					y(i) = me.stimuli{me.fixationChoice(i)}.yPositionOut / me.screen.ppd;
				end
				me.lastXPosition = x;
				me.lastYPosition = y;
			end
		end
		
		% ===================================================================
		%> @brief Return the stimulus exclusion positions
		%>
		% ===================================================================
		function [x,y] = getExclusionPositions(me)
			x = []; y = [];
			if ~isempty(me.fixationChoice)
				x=zeros(length(me.exclusionChoice),1); y = x;
				for i=1:length(me.exclusionChoice)
					x(i) = me.stimuli{me.exclusionChoice(i)}.xPositionOut / me.screen.ppd;
					y(i) = me.stimuli{me.exclusionChoice(i)}.yPositionOut / me.screen.ppd;
				end
				me.lastXExclusion = x;
				me.lastYExclusion = y;
			end
		end
		
		% ===================================================================
		%> @brief Return the stimulus positions
		%>
		% ===================================================================
		function out = getStimulusPositions(me, ignoreVisible)
			if ~exist('ignoreVisible','var'); ignoreVisible=false; end
			a=1;
			out = [];
			me.stimulusPositions = out;
			for i = 1:me.n_
				if ignoreVisible; check = true; else; check = me.stimuli{i}.isVisible; end
				if check && me.stimuli{i}.showOnTracker == true
					if isprop(me.stimuli{i},'sizeOut')
						if ~isempty(me.stimuli{i}.xOut)
							me.stimulusPositions(a).x = me.stimuli{i}.xOut;
							me.stimulusPositions(a).y = me.stimuli{i}.yOut;
						elseif ~isempty(me.stimuli{i}.mvRect)
							r = me.stimuli{i}.mvRect;
							me.stimulusPositions(a).x = r(3)-r(1);
							me.stimulusPositions(a).y = r(4)-r(2);
						else
							me.stimulusPositions(a).x = me.stimuli{i}.xPositionOut;
							me.stimulusPositions(a).y = me.stimuli{i}.yPositionOut;
						end
						me.stimulusPositions(a).size = me.stimuli{i}.sizeOut;
						if any(me.fixationChoice == i) 
							me.stimulusPositions(a).selected = true;
						else
							me.stimulusPositions(a).selected = false;
						end
						a = a + 1;
					end
				end
			end
			if ~isempty(me.stimulusPositions)
				out = me.stimulusPositions;
			end
		end
		
		% ===================================================================
		%> @brief Toggle show/hide for particular sets of stimuli
		%>
		% ===================================================================
		function showSet(me, set)
			if ~exist('set','var'); set = me.setChoice; end
			if ~isempty(me.stimulusSets)
				if set == 0 || set > me.n_; return; end
				hide(me);
				for i = me.stimulusSets{set}
					show(me.stimuli{i});
					if me.verbose;me.salutation('ShowSet',['Show stimulus ' num2str(i)],true); end
				end
			end
		end
		
		% ===================================================================
		%> @brief Toggle show/hide for particular sets of stimuli
		%>
		% ===================================================================
		function changeSet(me,value)
			if ~exist('value','var'); value = 0; end
			if ~isempty(me.stimulusSets) && value <= length(me.stimulusSets)
				me.setChoice = value;
				showSet(me);
			end
		end
		
		% ===================================================================
		%> @brief Run Stimulus in a window to preview
		%>
		% ===================================================================
		function run(me, benchmark, runtime, s, forceScreen)
		% run(benchmark, runtime, screenManager, forceFullscreen)
			try
				warning off
				if ~exist('benchmark','var') || isempty(benchmark)
					benchmark=false;
				end
				if ~exist('runtime','var') || isempty(runtime)
					runtime = 2; %seconds to run
				end
				if ~exist('s','var') || ~isa(s,'screenManager')
					s = screenManager;
					s.blend = true; 
					s.disableSyncTests = true;
					s.visualDebug = true;
					s.bitDepth = 'FloatingPoint32BitIfPossible';
				end
				if ~exist('forceScreen','var'); forceScreen = -1; end

				oldscreen = s.screen;
				oldbitdepth = s.bitDepth;
				if forceScreen >= 0
					s.screen = forceScreen;
					if forceScreen == 0 % make sure screen 0 does not trigger bits++ etc.
						s.bitDepth = 'FloatingPoint32BitIfPossible';
					end
				end
				prepareScreen(s);

				oldwindowed = s.windowed;
				if benchmark
					s.windowed = false;
				elseif forceScreen > -1
					s.windowed = [0 0 s.screenVals.width/2 s.screenVals.height/2]; %middle of screen
				end
			
				if ~s.isOpen
					sv=open(s);
				end
				setup(me,s); %setup our stimulus objects

				Priority(MaxPriority(s.win)); %bump our priority to maximum allowed

				draw(me);
				if benchmark
					Screen('DrawText', s.win, 'BENCHMARK: screen won''t update properly, see FPS in command window at end.', 5,5,[0.25 0.15 0]);
				else
					drawGrid(s); %draw +-5 degree dot grid
					Screen('DrawText', s.win, ['Preview ALL stimuli (grid is 1deg); static for 1 seconds, then animate for ' num2str(runtime) ' seconds...'], 5,5,[0.25 0.15 0]);
				end

				flip(s);
				update(me);
				WaitSecs('YieldSecs',1);
				nFrames = 0;
				for i = 1:(s.screenVals.fps*runtime) 
					nFrames = nFrames + 1;
					draw(me); %draw stimuli
					if ~benchmark && s.debug; drawGrid(s); end
					finishDrawing(s); %tell PTB/GPU to draw
					animate(me); %animate stimuli, ready for next draw();
					if benchmark
						Screen('Flip',s.win,0,2,2);
						if i == 1; vbl = GetSecs; end
					else
						vbl = Screen('Flip',s.win); %flip the buffer
					end
					if i == 1; startT = vbl; end
				end
				vbl = flip(s); endT = vbl;
				WaitSecs(0.5);
				Priority(0); ShowCursor; ListenChar(0);
				reset(me); %reset our stimulus ready for use again
				close(s); %close screen
				s.screen = oldscreen;
				s.windowed = oldwindowed;
				s.bitDepth = oldbitdepth;
				fps = nFrames / (endT-startT);
				fprintf('\n\n======>>> Stimulus: %s\n',me.fullName);
				fprintf('======>>> <strong>SPEED</strong> (%i frames in %.3f secs) = <strong>%.3f</strong> fps\n\n',...
					nFrames, endT-startT, fps);
				clear s fps benchmark runtime b bb i; %clear up a bit
				warning on
			catch ME
				warning on
				getReport(ME)
				Priority(0);
				if exist('s','var') && isa(s,'screenManager')
					close(s);
				end
				clear fps benchmark runtime b bb i; %clear up a bit
				reset(me); %reset our stimulus ready for use again
				rethrow(ME)				
			end
		end
		
		
		% ===================================================================
		%> @brief Run Stimulus in a window to preview
		%>
		% ===================================================================
		function runSingle(me,s,eL,runtime)
			if ~exist('eL','var') || ~isa(eL,'eyelinkManager')
				eL = eyelinkManager();
			end
			if ~exist('s','var') || ~isa(s,'screenManager')
				s = screenManager('verbose',false,'blend',true,...
				'bitDepth','FloatingPoint32BitIfPossible','debug',false,...
				'backgroundColour',[0.5 0.5 0.5 0]); %use a temporary screenManager object
			end
			if ~exist('runtime','var') || isempty(runtime)
				runtime = 5; %seconds to run
			end
			
			try
				lJ = labJack('name','runSingle','readResponse', false,'verbose',false);
				open(s); %open PTB screen
				setup(me,s); %setup our stimulus object

				fixX = 0;
				fixY = 0;
				firstFixInit = 2;
				firstFixTime = 2;
				firstFixRadius = 1.25;
				eL.isDummy = false; %use dummy or real eyelink?
				eL.recordData = false;
				eL.sampleRate = 250;
				eL.updateFixationValues(fixX, fixY, firstFixInit, firstFixTime, firstFixRadius, true);

				initialise(eL,s); %initialise eyelink with our screen
				%setup(eL); %setup eyelink

				eL.statusMessage('SINGLE TRIAL RUNNING'); %
				setOffline(eL); 
				trackerDrawFixation(eL)

				breakString = 'ok';
				breakloop = false;
				a=1;
				startRecording(eL);
				WaitSecs(1);
				syncTime(eL);
				Screen('Flip',s.win);
				while breakloop == false
					draw(me); %draw stimulus
					Screen('DrawingFinished', s.win); %tell PTB/GPU to draw

					getSample(eL);
					breakString = testSearchHoldFixation(eL,'yes','no');

					if strcmpi(breakString,'yes') 
						timedTTL(lJ,0,200);
						breakloop = true;
						fprintf('metaStimulus runSingle: CORRECT');
						break;
					elseif strcmpi(breakString,'no')
						breakloop = true;
						fprintf('metaStimulus runSingle: INCORRECT');
						break;
					end

					animate(me); %animate stimulus, will be seen on next draw

					Screen('Flip',s.win); %flip the buffer
				end
				Screen('Flip',s.win);Screen('Flip',s.win);
				WaitSecs(1);
				stopRecording(eL)
				close(s); %close screen
				close(eL);
				close(lJ)
				reset(me); %reset our stimulus ready for use again
			catch ME
				ListenChar(0);
				Eyelink('Shutdown');
				close(s);
				close(eL);
				close(lJ);
				reset(me); %reset our stimulus ready for use again
				rethrow(ME);
			end
			
		end
		% ===================================================================
		%> @brief print current choice if only single stimulus drawn
		%>
		%> @param
		%> @return
		% ===================================================================
		function printChoice(me)
			fprintf('%s current choice is: %g\n',me.fullName,me.choice)
		end
		
		% ===================================================================
		%> @brief get n dependent method
		%> @param
		%> @return n number of stimuli
		% ===================================================================
		function n = get.n(me)
			n = length(me.stimuli);
			me.n_ = n;
		end
		
		% ===================================================================
		%> @brief get nMask dependent method
		%> @param
		%> @return nMask number of mask stimuli
		% ===================================================================
		function nMask = get.nMask(me)
			nMask = length(me.maskStimuli);
			me.nMask_ = nMask;
		end
		
		
		% ===================================================================
		%> @brief set stimuli sanity checker
		%> @param in a stimuli group
		%> @return 
		% ===================================================================
		function set.stimuli(me,in)
			if iscell(in) % a cell array of stimuli
				me.stimuli = [];
				me.stimuli = in;
			elseif isa(in,'baseStimulus') %we are a single opticka stimulus
				me.stimuli = {in};
			elseif isempty(in)
				me.stimuli = {};
			else
				error([me.name ':set stimuli | not a cell array or baseStimulus child']);
			end
		end
		
		% ===================================================================
		%> @brief subsref allow {} to call stimuli cell array directly
		%>
		%> @param  s is the subsref struct
		%> @return varargout any output for the reference
		% ===================================================================
		function varargout = subsref(me,s)
			switch s(1).type
				% Use the built-in subsref for dot notation
				case '.'
					[varargout{1:nargout}] = builtin('subsref',me,s);
				case '()'
					%error([me.name ':subsref'],'Not a supported subscripted reference')
					[varargout{1:nargout}] = builtin('subsref',me.stimuli,s);
				case '{}'
					[varargout{1:nargout}] = builtin('subsref',me.stimuli,s);
			end
		end
		
		% ===================================================================
		%> @brief subsasgn allow {} to assign to the stimuli cell array
		%>
		%> @param  s is the subsref struct
		%> @param val is the value to assign
		%> @return me object
		% ===================================================================
		function me = subsasgn(me,s,val)
			switch s(1).type
				% Use the built-in subsref for dot notation
				case '.'
					me = builtin('subsasgn',me,s,val);
				case '()'
					%error([me.name ':subsasgn'],'Not a supported subscripted reference')
					sout = builtin('subsasgn',me.stimuli,s,val);
					if ~isempty(sout)
						me.stimuli = sout;
					else
						me.stimuli = {};
					end
				case '{}'
					sout = builtin('subsasgn',me.stimuli,s,val);
					if ~isempty(sout)
						if max(size(sout)) == 1
							sout = sout{1};
						end
						if ~iscell(sout)
							me.stimuli = {sout};
						else
							me.stimuli = sout;
						end
					else
						me.stimuli = {};
					end
			end
		end
	end%-------------------------END PUBLIC METHODS--------------------------------%
	
	%=======================================================================
	methods (Access = private) %------------------PRIVATE METHODS
	%=======================================================================
		
		
	end
end