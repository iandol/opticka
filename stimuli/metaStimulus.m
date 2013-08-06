% ========================================================================
%> @brief metaStimulus is a  wrapper for opticka stimuli
%> METASTIMULUS a collection of stimuli, wrapped in one structure. It
%> allows you to treat a group of heterogenous stimuli as if it is a single
%> stimulus, so for example animate(metaStimulus) will run the animate method
%> for all stimuli in the group without having to call it for each stimulus.
%> You can also pick individual stimuli by using cell indexing of this
%> object. So for example metaStimulus{2} actually calls
%> metaStimulus.stimuli{2}.
%> You can also pass a mask stimulus set, and when you toggle showMask, the
%> mask stimuli will be drawn instead of the stimuli themselves, the timing
%> is left to the calling function.
% ========================================================================
classdef metaStimulus < optickaCore
	
	%--------------------PUBLIC PROPERTIES----------%
	properties 
		%>cell array of opticka stimuli to manage
		stimuli = {}
		%> do we draw the mask stimuli instead?
		showMask = false
		%>mask stimuli
		maskStimuli = {}
		%> screenManager handle
		screen
		%> verbose?
		verbose = false
		%> choice allows to call only 1 stimulus in the group
		choice = []
		%>which of the stimuli should fixation follow?
		fixationChoice = []
		%> randomisation table to apply to a stimulus
		stimulusTable = []
		%> choice for table
		tableChoice = []
		%> control table for keyboard changes
		controlTable = []
		%> show subsets of stimuli?
		stimulusSets = []
		%>
		setChoice = 0;
		%>
		flashRate = 0.25
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
		family = 'meta'
		%> structure holing positions for each stimulus
		stimulusPositions = []
		%> used for optional logging for update times
		updateLog = []
	end
	
	%--------------------VISIBLE PROPERTIES----------%
	properties (SetAccess = private, GetAccess = public, Transient = true); 
		%> stimulus family
		lastXPosition = 0
		lastYPosition = 0
	end
	
	%--------------------PRIVATE PROPERTIES----------%
	properties (SetAccess = private, GetAccess = private) 
		%> allowed properties passed to object upon construction
		allowedProperties = 'showMask|maskStimuli|verbose|stimuli|screen|choice'
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
		function obj = metaStimulus(varargin)
			if nargin == 0; varargin.name = 'metaStimulus';end
			if nargin>0; obj.parseArgs(varargin,obj.allowedProperties); end
		end
		
		% ===================================================================
		%> @brief setup wrapper
		%>
		%> @param
		%> @return
		% ===================================================================
		function setup(obj,s)
			if ~exist('s','var') || ~isa(s,'screenManager')
				if isa(obj.screen,'screenManager')
					s = obj.screen;
				else
					s = [];
				end
			end	
			if isa(s,'screenManager')
				for i = 1:obj.n
					setup(obj.stimuli{i},s);
				end
				for i = 1:obj.nMask
					setup(obj.maskStimuli{i},s);
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
		function update(obj,choice)
			%tic
			if exist('choice','var') %user forces a single stimulus
				
				update(obj.stimuli{choice});
				
% 			elseif ~isempty(obj.choice) %object forces a single stimulus
% 				
% 				update(obj.stimuli{obj.choice});
				
			elseif obj.showMask == true && obj.nMask > 0 %draw mask instead
				
				for i = 1:obj.nMask
					update(obj.maskStimuli{i});
				end
				
			else
		
				for i = 1:obj.n
					update(obj.stimuli{i});
				end
				
			end
			%obj.updateLog = [obj.updateLog toc*1000];
		end
		
		% ===================================================================
		%> @brief draw wrapper
		%>
		%> @param choice override a single choice
		%> @return
		% ===================================================================
		function draw(obj,choice)
			if exist('choice','var') %user forces a single stimulus
				
				draw(obj.stimuli{choice});
				
% 			elseif ~isempty(obj.choice) %object forces a single stimulus
% 				
% 				draw(obj.stimuli{obj.choice});
				
			elseif obj.showMask == true && obj.nMask > 0 %draw mask instead
				
				for i = 1:obj.nMask
					draw(obj.maskStimuli{i});
				end
				
			else
				
				for i = 1:obj.n
					draw(obj.stimuli{i});
				end
				
			end
		end
		
		% ===================================================================
		%> @brief animate wrapper
		%>
		%> @param choice allow a single selected stimulus
		%> @return
		% ===================================================================
		function animate(obj,choice)
			if exist('choice','var') %user forces a single stimulus
				
				animate(obj.stimuli{choice});
				
% 			elseif ~isempty(obj.choice) %object forces a single stimulus
% 				
% 				animate(obj.stimuli{obj.choice});
				
			elseif obj.showMask == true && obj.nMask > 0 %draw mask instead
				
				for i = 1:obj.nMask
					animate(obj.maskStimuli{i});
				end
				
			else
				
				for i = 1:obj.n
					animate(obj.stimuli{i});
				end
				
			end
		end
		
		% ===================================================================
		%> @brief reset wrapper
		%>
		%> @param
		%> @return
		% ===================================================================
		function reset(obj)

			for i = 1:obj.n
				reset(obj.stimuli{i});
			end
				
			for i = 1:obj.nMask
				reset(obj.maskStimuli{i});
			end
			
		end
		
		% ===================================================================
		%> @brief randomise wrapper
		%>
		%> @param
		%> @return
		% ===================================================================
		function randomise(obj)
			if ~isempty(obj.stimulusTable)
				logs = '--->>> RANDOMISE Stimulus: ';
				for i = 1:length(obj.stimulusTable)
					
					stims = obj.stimulusTable(i).stimuli;
					name = obj.stimulusTable(i).name;
					offset = obj.stimulusTable(i).offset;
					
					if ~isempty(stims) && ~isempty(name)
	
						[r,c] = size(obj.stimulusTable(i).values);
						if r > 1 && c > 1
							values = obj.stimulusTable(i).values(randi(r),:);
						elseif r > 1
							values = obj.stimulusTable(i).values(randi(r),1);
						else
							values = obj.stimulusTable(i).values(1,randi(c));
						end

						for j=1:length(stims)
							if strcmpi(name,'xyPosition')
								obj.stimuli{stims(j)}.xPositionOut = values(1);
								obj.stimuli{stims(j)}.yPositionOut = values(2);
								obj.lastXPosition = values(1);
								obj.lastYPosition = values(2);
								logs = [logs 'XY: ' num2str(stims(j)) ];
							elseif isprop(obj.stimuli{stims(j)}, [name 'Out'])
								obj.stimuli{stims(j)}.([name 'Out']) = values;
								logs = [logs ' || ' name 'Out: ' num2str(values)];
								if ~isempty(offset)
									obj.stimuli{offset(1)}.([name 'Out']) = values + offset(2);
									logs = [logs ' || OFFSET' name 'Out: ' num2str(values + offset(2))];
								end
							end
						end
					
					end
				end
				obj.salutation(logs);
			end
		end
		
		% ===================================================================
		%> @brief Shorthand to set isVisible=true.
		%>
		% ===================================================================
		function show(obj)
			for i = 1:obj.n
				show(obj.stimuli{i});
			end
		end
				
		% ===================================================================
		%> @brief Shorthand to set isVisible=false.
		%>
		% ===================================================================
		function hide(obj)
			for i = 1:obj.n
				hide(obj.stimuli{i});
			end
		end
		
		% ===================================================================
		%> @brief Edit -- fast change a particular value.
		%>
		% ===================================================================
		function edit(obj, stims, var, value)
			for i = 1:length(stims)
				obj.stimuli{stims(i)}.(var) = value;
			end
		end
		
		% ===================================================================
		%> @brief Return the stimulus positions
		%>
		% ===================================================================
		function [x,y] = getFixationPositions(obj)
			x = 0; y = 0;
			if ~isempty(obj.fixationChoice)
				x = obj.stimuli{obj.fixationChoice}.xPositionOut;
				y = obj.stimuli{obj.fixationChoice}.yPositionOut;
				xy = toDegrees(obj,[x y]);
				x = xy(1); y = xy(2);
				obj.lastXPosition = x;
				obj.lastYPosition = y;
			end
		end
		
		% ===================================================================
		%> @brief Return the stimulus positions
		%>
		% ===================================================================
		function out = getStimulusPositions(obj)
			a=1;
			out = [];
			obj.stimulusPositions = out;
			for i = 1:obj.n
				if obj.stimuli{i}.isVisible == true
					if isprop(obj.stimuli{i},'sizeOut')
						obj.stimulusPositions(a).x = obj.stimuli{i}.xPositionOut;
						obj.stimulusPositions(a).y = obj.stimuli{i}.yPositionOut;
						obj.stimulusPositions(a).size = obj.stimuli{i}.sizeOut;
						if obj.fixationChoice == i 
							obj.stimulusPositions(a).selected = true;
						else
							obj.stimulusPositions(a).selected = false;
						end
						fprintf('Stim%i = X: %.2g Y: %.2g Size: %.2g\n',i, obj.stimulusPositions(a).x,obj.stimulusPositions(a).y,obj.stimulusPositions(a).size);
					end
				end
			end
			if ~isempty(obj.stimulusPositions)
				out = obj.stimulusPositions;
			end
		end
		
		% ===================================================================
		%> @brief Toggle show/hide for particular sets of stimuli
		%>
		% ===================================================================
		function showSet(obj)
			if ~isempty(obj.stimulusSets) && obj.setChoice > 0
				sets = obj.stimulusSets{obj.setChoice};
				if max(sets) <= obj.n
					hide(obj)
					for i = 1:length(sets)
						show(obj.stimuli{sets(i)});
					end
				end
			end
		end
		
		% ===================================================================
		%> @brief Run Stimulus in a window to preview
		%>
		% ===================================================================
		function run(obj,benchmark,runtime,s)
			if ~exist('benchmark','var') || isempty(benchmark)
				benchmark=false;
			end
			if ~exist('runtime','var') || isempty(runtime)
				runtime = 2; %seconds to run
			end
			if ~exist('s','var') || ~isa(s,'screenManager')
				s = screenManager('verbose',false,'blend',true,'screen',0,...
				'bitDepth','8bit','debug',false,...
				'backgroundColour',[0.5 0.5 0.5 0]); %use a temporary screenManager object
			end
			
			oldwindowed = s.windowed;
			if benchmark
				s.windowed = [];
			else
				%s.windowed = [0 0 s.screenVals.width/2 s.screenVals.height/2];
				%s.windowed = CenterRect([0 0 s.screenVals.width/2 s.screenVals.height/2], s.winRect); %middle of screen
			end
			open(s); %open PTB screen
			s.windowed = oldwindowed;
			setup(obj,s); %setup our stimulus object
			draw(obj); %draw stimulus
			drawGrid(s); %draw +-5 degree dot grid
			drawScreenCenter(s); %centre spot
			if benchmark; 
				Screen('DrawText', s.win, 'Benchmark, screen will not update properly, see FPS on command window at end.', 5,5,[0 0 0]);
			else
				Screen('DrawText', s.win, 'Stimulus unanimated for 1 second, animated for 2, then unanimated for a final second...', 5,5,[0 0 0]);
			end
			Screen('Flip',s.win);
			WaitSecs(1);
			if benchmark; b=GetSecs; end
			for i = 1:(s.screenVals.fps*runtime) %should be 2 seconds worth of flips
				draw(obj); %draw stimulus
				if ~benchmark;
					drawGrid(s); %draw +-5 degree dot grid
					drawScreenCenter(s); %centre spot
				end
				Screen('DrawingFinished', s.win); %tell PTB/GPU to draw
				animate(obj); %animate stimulus, will be seen on next draw
				if benchmark
					Screen('Flip',s.win,0,2,2);
				else
					Screen('Flip',s.win); %flip the buffer
				end
			end
			if benchmark; bb=GetSecs; end
			WaitSecs(1);
			Screen('Flip',s.win);
			WaitSecs(0.25);
			if benchmark
				fps = (s.screenVals.fps*runtime) / (bb-b);
				fprintf('\n------> SPEED = %g fps\n', fps);
			end
			close(s); %close screen
			clear s fps benchmark runtime b bb i; %clear up a bit
			reset(obj); %reset our stimulus ready for use again
		end
		
		
		% ===================================================================
		%> @brief Run Stimulus in a window to preview
		%>
		% ===================================================================
		function runSingle(obj,s,eL,runtime)
			if ~exist('eL','var') || ~isa(eL,'eyelinkManager')
				eL = eyelinkManager();
			end
			if ~exist('s','var') || ~isa(s,'screenManager')
				s = screenManager('verbose',false,'blend',true,'screen',0,...
				'bitDepth','8bit','debug',false,...
				'backgroundColour',[0.5 0.5 0.5 0]); %use a temporary screenManager object
			end
			if ~exist('runtime','var') || isempty(runtime)
				runtime = 2; %seconds to run
			end
			
			try
				lJ = labJack('name','runSingle','readResponse', false,'verbose',false);
				open(s); %open PTB screen
				setup(obj,s); %setup our stimulus object

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
					draw(obj); %draw stimulus
					Screen('DrawingFinished', s.win); %tell PTB/GPU to draw

					getSample(eL);
					breakString = testSearchHoldFixation(eL,'yes','no');

					if strcmpi(breakString,'yes') 
						timedTTL(lJ,0,200);
						breakloop = true;
						fprintf('metaStimulus: CORRECT');
						break;
					elseif strcmpi(breakString,'no')
						breakloop = true;
						fprintf('metaStimulus: INCORRECT');
						break;
					end

					animate(obj); %animate stimulus, will be seen on next draw

					Screen('Flip',s.win); %flip the buffer
				end
				Screen('Flip',s.win);Screen('Flip',s.win);
				WaitSecs(1);
				stopRecording(eL)
				close(s); %close screen
				close(eL);
				close(lJ)
				reset(obj); %reset our stimulus ready for use again
			catch ME
				ListenChar(0);
				Eyelink('Shutdown');
				close(s);
				close(eL);
				close(lJ);
				reset(obj); %reset our stimulus ready for use again
				rethrow(ME);
			end
			
		end
		% ===================================================================
		%> @brief print current choice if only single stimulus drawn
		%>
		%> @param
		%> @return
		% ===================================================================
		function printChoice(obj)
			fprintf('%s current choice is: %g\n',obj.fullName,obj.choice)
		end
		
		% ===================================================================
		%> @brief get n dependent method
		%> @param
		%> @return n number of stimuli
		% ===================================================================
		function n = get.n(obj)
			n = length(obj.stimuli);
		end
		
		% ===================================================================
		%> @brief get nMask dependent method
		%> @param
		%> @return nMask number of mask stimuli
		% ===================================================================
		function nMask = get.nMask(obj)
			nMask = length(obj.maskStimuli);
		end
		
		
		% ===================================================================
		%> @brief set stimuli sanity checker
		%> @param in a stimuli group
		%> @return 
		% ===================================================================
		function set.stimuli(obj,in)
			if iscell(in) % a cell array of stimuli
				obj.stimuli = [];
				obj.stimuli = in;
			elseif isa(in,'baseStimulus') %we are a single opticka stimulus
				obj.stimuli = {in};
			elseif isempty(in)
				obj.stimuli = {};
			else
				error([obj.name ':set stimuli | not a cell array or baseStimulus child']);
			end
		end
		
		% ===================================================================
		%> @brief subsref allow {} to call stimuli cell array directly
		%>
		%> @param  s is the subsref struct
		%> @return varargout any output for the reference
		% ===================================================================
		function varargout = subsref(obj,s)
			switch s(1).type
				% Use the built-in subsref for dot notation
				case '.'
					[varargout{1:nargout}] = builtin('subsref',obj,s);
				case '()'
					%error([obj.name ':subsref'],'Not a supported subscripted reference')
					[varargout{1:nargout}] = builtin('subsref',obj.stimuli,s);
				case '{}'
					[varargout{1:nargout}] = builtin('subsref',obj.stimuli,s);
			end
		end
		
		% ===================================================================
		%> @brief subsasgn allow {} to assign to the stimuli cell array
		%>
		%> @param  s is the subsref struct
		%> @param val is the value to assign
		%> @return obj object
		% ===================================================================
		function obj = subsasgn(obj,s,val)
			switch s(1).type
				% Use the built-in subsref for dot notation
				case '.'
					obj = builtin('subsasgn',obj,s,val);
				case '()'
					%error([obj.name ':subsasgn'],'Not a supported subscripted reference')
					sout = builtin('subsasgn',obj.stimuli,s,val);
					if ~isempty(sout)
						obj.stimuli = sout;
					else
						obj.stimuli = {};
					end
				case '{}'
					sout = builtin('subsasgn',obj.stimuli,s,val);
					if ~isempty(sout)
						if max(size(sout)) == 1
							sout = sout{1};
						end
						obj.stimuli = sout;
					else
						obj.stimuli = {};
					end
			end
		end
	end%-------------------------END PUBLIC METHODS--------------------------------%
	
	%=======================================================================
	methods (Access = private) %------------------PRIVATE METHODS
	%=======================================================================
		
		% ===================================================================
		%> @brief
		%>
		% ===================================================================
		function out = toDegrees(obj,in,axis)
			if ~exist('axis','var');axis='';end
			switch axis
				case 'x'
					out = (in - obj.screen.xCenter) / obj.screen.ppd;
				case 'y'
					out = (in - obj.screen.yCenter) / obj.screen.ppd;
				otherwise
					if length(in)==2
						out(1) = (in(1) - obj.screen.xCenter) / obj.screen.ppd;
						out(2) = (in(2) - obj.screen.yCenter) / obj.screen.ppd;
					else
						out = 0;
					end
			end
		end
		
		% ===================================================================
		%> @brief
		%>
		% ===================================================================
		function out = toPixels(obj,in,axis)
			if ~exist('axis','var');axis='';end
			switch axis
				case 'x'
					out = (in * obj.screen.ppd) + obj.screen.xCenter;
				case 'y'
					out = (in * obj.screen.ppd) + obj.screen.yCenter;
				otherwise
					if length(in)==2
						out(1) = (in(1) * obj.screen.ppd) + obj.screen.xCenter;
						out(2) = (in(2) * obj.screen.ppd) + obj.screen.yCenter;
					else
						out = 0;
					end
			end
		end
		
	end
end