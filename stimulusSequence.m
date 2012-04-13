classdef stimulusSequence < dynamicprops
	properties
		%> whether to randomise (true) or run sequentially (false)
		randomise = true
		%> number of independant variables
		nVars = 0
		%> structure holding each independant variable
		nVar
		%> number of repeat blocks to present
		nBlocks = 1
		%> time stimulus trial is shown
		trialTime = 2
		%> inter stimulus trial time
		isTime = 1 
		%> inter block time
		ibTime = 2
		%> what do we show in the blank?
		isStimulus
		%> verbose or not
		verbose = true
		%> do we fillow real time or just number of ticks to get to a known time
		realTime = true
		%> random seed value, we can use this to set the RNG to a known state
		randomSeed
		%> mersenne twister default
		randomGenerator='mt19937ar' 
		%> used for dynamically estimating total number of frames
		fps = 60 
		%> will be used when we extend each trial to have sub-segments
		nSegments = 1 
		%> segment info
		nSegment
	end
	
	properties (SetAccess = private, GetAccess = public)
		%> structure of variable values
		outValues 
		%> variable values wrapped in trial cell
		outVars 
		%> the unique identifier for each stimulus
		outIndex 
		%> mapping the stimulus to the number as a X Y and Z etc position for display
		outMap
		%> old random number stream
		oldStream
		%> current random number stream
		taskStream
		%> minimum number of blocks
		minBlocks
		%> current random stream state
		currentState
		%> reserved for future use of multiple random stream states
		states
		%> reserved for future use of multiple random stream states
		nstates = 1
	end
	
	properties (Dependent = true,  SetAccess = private)
		%> number of blocks, need to rename!
		nRuns
		%> estimate of the total number of frames this task will occupy,
		%> requires accurate fps 
		nFrames
	end
	
	properties (SetAccess = private, GetAccess = private)
		h
		allowedProperties='^(randomise|nVars|nBlocks|trialTime|isTime|ibTime|realTime|randomSeed|fps)$'
	end
	
	methods
		% ===================================================================
		%> @brief Class constructor
		%>
		%> Send any parameters to parseArgs.
		%>
		%> @param varargin are passed as a structure of properties which is
		%> parsed.
		%> @return instance of the class.
		% ===================================================================
		function obj = stimulusSequence(varargin) 
			if nargin > 0
				obj.parseArgs(varargin,obj.allowedProperties)
			end
			obj.initialiseRandom();
		end
		
		% ===================================================================
		%> @brief set up the random number generator
		%>
		%> set up the random number generator
		% ===================================================================
		function initialiseRandom(obj)
			tic
			if isempty(obj.randomSeed)
				obj.randomSeed=round(rand*sum(clock));
			end
			if isempty(obj.oldStream)
				obj.oldStream = RandStream.getDefaultStream;
			end
			obj.taskStream = RandStream.create(obj.randomGenerator,'Seed',obj.randomSeed);
			RandStream.setDefaultStream(obj.taskStream);
			obj.salutation(sprintf('Initialise Randomisation: %g seconds',toc));
		end
		
		% ===================================================================
		%> @brief Reset the random number generator
		%>
		%> reset the random number generator
		% ===================================================================
		function resetRandom(obj)
			obj.randomSeed=[];
			RandStream.setDefaultStream(obj.oldStream);
		end
		
		% ===================================================================
		%> @brief Do the randomisation
		%>
		%> Do the randomisation
		% ===================================================================
		function randomiseStimuli(obj)
			tic
			obj.nVars=length(obj.nVar);
			
			obj.currentState=obj.taskStream.State;
			%obj.states(obj.nstates) = obj.currentState;
			%obj.nstates = obj.nstates + 1;
			
			nLevels = zeros(obj.nVars, 1);
			for f = 1:obj.nVars
				nLevels(f) = length(obj.nVar(f).values);
			end
			
			obj.minBlocks = prod(nLevels);
			if isempty(obj.minBlocks)
				obj.minBlocks = 1;
			end
			if obj.minBlocks > 2046
				warndlg('WARNING: You are exceeding the number of stimuli the Plexon can identify!')
			end

			% initialize cell array that will hold balanced variables
			obj.outVars = cell(obj.nBlocks, obj.nVars);
			obj.outValues = [];
			obj.outIndex = [];

			% the following initializes and runs the main loop in the function, which
			% generates enough repetitions of each factor, ensuring a balanced design,
			% and randomizes them
			offset=0;
			for i = 1:obj.nBlocks
				len1 = obj.minBlocks;
				len2 = 1;
				if obj.randomise == true
					[~, index] = sort(rand(obj.minBlocks, 1));
				else
					index = (1:obj.minBlocks)';
				end
				obj.outIndex = [obj.outIndex; index];
				for f = 1:obj.nVars
					len1 = len1 / nLevels(f);
					if size(obj.nVar(f).values, 1) ~= 1
						% ensure that factor levels are arranged in one row
						obj.nVar(f).values = reshape(obj.nVar(f).values, 1, numel(obj.nVar(1).values));
					end
					% this is the critical line: it ensures there are enough repetitions
					% of the current factor in the correct order
					obj.outVars{i,f} = repmat(reshape(repmat(obj.nVar(f).values, len1, len2), obj.minBlocks, 1), obj.nVars, 1);
					obj.outVars{i,f} = obj.outVars{i,f}(index);
					len2 = len2 * nLevels(f);
					mn=offset+1;
					mx=i*obj.minBlocks;
					obj.outValues(mn:mx,f)=obj.outVars{i,f};
				end
				offset=offset+obj.minBlocks;
			end
			obj.outMap=zeros(size(obj.outValues));
			for f = 1:obj.nVars
				for g = 1:length(obj.nVar(f).values)
					gidx = obj.outValues(:,f) == obj.nVar(f).values(g);
					obj.outMap(gidx,f) = g;
				end
			end
			obj.salutation(sprintf('Randomise Stimuli: %g seconds\n',toc));
		end
		
		% ===================================================================
		%> @brief Dependent property nRuns get method
		%>
		%> Dependent property nruns get method
		% ===================================================================
		function nRuns = get.nRuns(obj)
			nRuns = obj.minBlocks*obj.nBlocks;
		end
		
		% ===================================================================
		%> @brief Dependent property nFrames get method
		%>
		%> Dependent property nFrames get method
		% ===================================================================
		function nFrames = get.nFrames(obj)
			nSecs = (obj.nRuns * obj.trialTime) + (obj.minBlocks-1 * obj.isTime) + (obj.nBlocks-1 * obj.ibTime);
			nFrames = ceil(nSecs) * ceil(obj.fps); %be a bit generous in defining how many frames the task will take
		end
		
		% ===================================================================
		%> @brief showLog
		%>
		%> Generates a table with the randomised stimulus values
		% ===================================================================
		function showLog(obj)

			obj.h = struct();
			build_gui();
			data = [obj.outValues obj.outIndex obj.outMap];
			for ii = 1:obj.nVars
				cnames{ii} = obj.nVar(ii).name;
			end
			cnames{end+1} = 'outIndex';
			cnames{end+1} = 'Var1Index';
			cnames{end+1} = 'Var2Index';
			cnames{end+1} = 'Var3Index';
			
			set(obj.h.uitable1,'Data',data)
			set(obj.h.uitable1,'ColumnName',cnames);
			set(obj.h.uitable1,'ColumnWidth',{60});
			set(obj.h.uitable1,'FontName','FixedWidth')
			set(obj.h.uitable1,'RowStriping','on')

			function build_gui()
				obj.h.figure1 = figure( ...
					'Tag', 'SSLog', ...
					'Units', 'normalized', ...
					'Position', [0.1 0.1 0.2 0.5], ...
					'Name', 'stimulusSequence Log', ...
					'MenuBar', 'none', ...
					'NumberTitle', 'off', ...
					'Color', [0.94 0.94 0.94], ...
					'Resize', 'on');
				obj.h.uitable1 = uitable( ...
					'Parent', obj.h.figure1, ...
					'Tag', 'uitable1', ...
					'Units', 'normalized', ...
					'Position', [0 0 1 1], ...
					'FontName', 'Helvetica', ...
					'FontSize', 10, ...
					'BackgroundColor', [1 1 1;0.95 0.95 0.95], ...
					'ColumnEditable', [false,false], ...
					'ColumnFormat', {'char'}, ...
					'ColumnWidth', {'auto'});
			end
		end
		
	end % END STATIC METHODS
	
	%=======================================================================
	methods ( Access = private ) % PRIVATE METHODS
	%=======================================================================

		% ===================================================================
		%> @brief Prints messages dependent on verbosity
		%>
		%> Prints messages dependent on verbosity
		%> @param in the calling function
		%> @param message the message that needs printing to command window
		% ===================================================================
		function salutation(obj,in,message)
			if obj.verbose==1
				if ~exist('in','var')
					in = 'random user';
				end
				if exist('message','var')
					fprintf(['---> stimulusSequence: ' message ' | ' in '\n']);
				else
					fprintf(['---> stimulusSequence: ' in '\n']);
				end
			end
		end
		
		% ===================================================================
		%> @brief Sets properties from a structure, ignores invalid properties
		%>
		%> @param args input structure
		% ===================================================================
		function parseArgs(obj, args, allowedProperties)
			allowedProperties = ['^(' allowedProperties ')$'];
			while iscell(args) && length(args) == 1
				args = args{1};
			end
			if iscell(args)
				if mod(length(args),2) == 1 % odd
					args = args(1:end-1); %remove last arg
				end
				odd = logical(mod(1:length(args),2));
				even = logical(abs(odd-1));
				args = cell2struct(args(even),args(odd),2);
			end
			fnames = fieldnames(args); %find our argument names
			for i=1:length(fnames);
				if regexp(fnames{i},allowedProperties) %only set if allowed property
					obj.salutation(fnames{i},'Configuring setting in constructor');
					obj.(fnames{i})=args.(fnames{i}); %we set up the properies from the arguments as a structure
				end
			end
		end
		
	end
end