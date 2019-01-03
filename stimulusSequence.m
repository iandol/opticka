% ========================================================================
%> @brief stimulusSequence a method of constanst variable manager
%> 
%> This class takes a series of visual variables (contrast, angle etc) with 
%> a set of values and randomly interleves them into a pseudorandom variable 
%> list each of which has a unique index number
% ========================================================================
classdef stimulusSequence < optickaCore & dynamicprops
	properties
		%> whether to randomise (true) or run sequentially (false)
		randomise logical = true
		%> structure holding each independant variable
		nVar
		%> number of repeat blocks to present
		nBlocks double = 1
		%> time stimulus trial is shown
		trialTime double = 2
		%> inter stimulus trial time
		isTime double = 1 
		%> inter block time
		ibTime double = 2
		%> what do we show in the blank?
		isStimulus
		%> do we follow real time or just number of ticks to get to a known time
		realTime logical = true
		%> random seed value, we can use this to set the RNG to a known state
		randomSeed
		%> mersenne twister default
		randomGenerator char = 'mt19937ar' 
		%> used for dynamically estimating total number of frames
		fps double = 60 
		%> will be used when we extend each trial to have sub-segments
		nSegments double = 1 
		%> segment info
		nSegment
		%> verbose or not
		verbose = false
	end
	
	properties (SetAccess = private, GetAccess = public)
		%> structure of variable values
		outValues 
		%> variable values wrapped in a per-block cell
		outVars 
		%> the unique identifier for each stimulus
		outIndex = 1
		%> mapping the stimulus to the number as a X Y and Z etc position for display
		outMap
		%> minimum number of blocks
		minBlocks
		%> log of with block resets
		resetLog
		%> have we initialised the dynamic task properties?
		taskInitialised logical = false
		%> has task finished
		taskFinished logical = false
	end
	
	properties (SetAccess = private, GetAccess = public, Transient = true, Hidden = true)
		%> reserved for future use of multiple random stream states
		states
		%> reserved for future use of multiple random stream states
		nStates = 1
		%> old random number stream
		oldStream
		%> current random number stream
		taskStream
		%> current random stream state
		currentState
	end
	
	properties (Dependent = true,  SetAccess = private)
		%> number of blocks, need to rename!
		nRuns 
		%> estimate of the total number of frames this task will occupy,
		%> requires accurate fps 
		nFrames 
		%> number of independant variables
		nVars = 0
	end
	
	properties (SetAccess = private, GetAccess = private)
		%> cache value for nVars
		nVars_
		%> handles from obj.showLog
		h
		%> properties allowed during initial construction
		allowedProperties char ='randomise|nVar|nBlocks|trialTime|isTime|ibTime|realTime|randomSeed|fps'
		%> used to handle problems with dependant property nVar: the problem is
		%> that set.nVar gets called before static loadobj, and therefore we need
		%> to handle this differently. Initially set to empty, set to true when
		%> running loadobj() and false when not loading object.
		isLoading = []
		%> properties used by loadobj when a structure is passed during load.
		%> this stops loading old randstreams etc.
		loadProperties cell = {'randomise','nVar','nBlocks','trialTime','isTime','ibTime','isStimulus','verbose',...
			'realTime','randomSeed','randomGenerator','nSegments','nSegment','outValues','outVars', ...
            'outIndex', 'outMap', 'minBlocks','states','nState','name'}
		%> nVar template and default values
		varTemplate struct = struct('name','','stimulus',[],'values',[],'offsetstimulus',[],'offsetvalue',[])
		%Set up the task structures needed
		taskProperties cell = {'response',[],'responseInfo',{},'tick',0,'blankTick',0,'thisRun',1,...
			'thisBlock',1,'totalRuns',1,'isBlank',false,'isTimeNow',1,'ibTimeNow',1,...
			'switched',false,'strobeThisFrame',false,'doUpdate',false,'startTime',0,'switchTime',0,...
			'switchTick',0,'timeNow',0,'runTimeList',[],'stimIsDrifting',[],'stimIsMoving',[],...
			'stimIsDots',[],'stimIsFlashing',[]}
		tProp cell = {'response',[],'responseInfo',{},'tick',0,'blankTick',0,'thisRun',1,...
			'thisBlock',1,'totalRuns',1,'isBlank',false,'isTimeNow',1,'ibTimeNow',1,...
			'switched',false,'strobeThisFrame',false,'doUpdate',false,'startTime',0,'switchTime',0,...
			'switchTick',0,'timeNow',0,'runTimeList',[],'stimIsDrifting',[],'stimIsMoving',[],...
			'stimIsDots',[],'stimIsFlashing',[]}
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
			if nargin == 0; varargin.name = 'stimulusSequence'; end
			obj=obj@optickaCore(varargin); %superclass constructor
			if nargin > 0; obj.parseArgs(varargin,obj.allowedProperties); end
			obj.nVar = obj.varTemplate;
			obj.initialiseRandom();
			obj.isLoading = false;
		end

		% ===================================================================
		%> @brief set up the random number generator
		%>
		%> set up the random number generator
		% ===================================================================
		function initialiseRandom(obj)
			if isnan(obj.mversion) || obj.mversion == 0
				obj.mversion = str2double(regexp(version,'(?<ver>^\d+\.\d+)','match','once'));
			end
			if isempty(obj.randomSeed)
				obj.randomSeed=round(rand*sum(clock));
			end
			if isempty(obj.oldStream)
				if obj.mversion > 7.11
					obj.oldStream = RandStream.getGlobalStream;
				else
					obj.oldStream = RandStream.getDefaultStream; %#ok<*GETRS>
				end
			end
			obj.taskStream = RandStream.create(obj.randomGenerator,'Seed',obj.randomSeed);
			if obj.mversion > 7.11
				RandStream.setGlobalStream(obj.taskStream);
			else
				RandStream.setDefaultStream(obj.taskStream); %#ok<*SETRS>
			end
		end
		
		% ===================================================================
		%> @brief Reset the random number generator
		%>
		%> reset the random number generator
		% ===================================================================
		function resetRandom(obj)
			obj.randomSeed=[];
			if obj.mversion > 7.11
				RandStream.setGlobalStream(obj.oldStream);
			else
				RandStream.setDefaultStream(obj.oldStream);
			end
		end
		
		% ===================================================================
		%> @brief Do the randomisation
		%>
		%> Do the randomisation
		% ===================================================================
		function randomiseStimuli(obj)
			if obj.nVars > 0 %no need unless we have some variables
				if obj.verbose==true;rSTime = tic;end
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
				obj.outVars = cell(obj.nBlocks, obj.nVars_);
				obj.outValues = cell(obj.nBlocks*obj.minBlocks, obj.nVars_);
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
						obj.outVars{i,f} = repmat(reshape(repmat(obj.nVar(f).values, len1, len2), obj.minBlocks, 1), obj.nVars_, 1);
						obj.outVars{i,f} = obj.outVars{i,f}(index);
						len2 = len2 * nLevels(f);
						mn=offset+1;
						mx=i*obj.minBlocks;
						idxm = mn:mx;
						for j = 1:length(idxm)
							if iscell(obj.outVars{i,f}(j))
								obj.outValues{idxm(j),f}=obj.outVars{i,f}{j};
							else
								obj.outValues{idxm(j),f}=obj.outVars{i,f}(j);
							end
						end
					end
					offset=offset+obj.minBlocks;
				end
				obj.outMap=zeros(size(obj.outValues));
				for f = 1:obj.nVars_
					for g = 1:length(obj.nVar(f).values)
						for hh = 1:length(obj.outValues(:,f))
							if iscell(obj.nVar(f).values(g))
								if (ischar(obj.nVar(f).values{g}) && ischar(obj.outValues{hh,f})) && strcmpi(obj.outValues{hh,f},obj.nVar(f).values{g})
									obj.outMap(hh,f) = g;
								elseif (isnumeric(obj.nVar(f).values{g}) && isnumeric(obj.outValues{hh,f})) && isequal(obj.outValues{hh,f}, obj.nVar(f).values{g})
									obj.outMap(hh,f) = g;
								%elseif ~ischar(obj.nVar(f).values{g}) && isequal(obj.outValues{hh,f}, obj.nVar(f).values{g})
								%	obj.outMap(hh,f) = g;
								end
							else
								if obj.outValues{hh,f} == obj.nVar(f).values(g)
									obj.outMap(hh,f) = g;
								end
							end
						end
					end
				end
				if obj.verbose; obj.salutation(sprintf('randomiseStimuli took %g ms\n',toc(rSTime)*1000)); end
			else
				obj.outIndex = 1; %there is only one stimulus, no variables
			end
		end
		
		% ===================================================================
		%> @brief Initialise the variables and task together
		%>
		% ===================================================================
		function initialise(obj)
			obj.randomiseStimuli();
			obj.initialiseTask();
		end
		
		% ===================================================================
		%> @brief Initialise the properties used to track the run
		%>
		%> Initialise the properties used to track the run. These are dynamic
		%> props.
		% ===================================================================
		function initialiseTask(obj)
			resetTask(obj);
			t = obj.tProp;
			for i = 1:2:length(t)
				if isempty(obj.findprop(t{i}))
					p = obj.addprop(t{i}); %add new dynamic property
				end
				obj.(t{i}) = t{i+1}; %#ok<*MCNPR>
			end
			obj.taskInitialised = true;
			randomiseTimes(obj);
		end
		
		% ===================================================================
		%> @brief update the task with a response
		%>
		% ===================================================================
		function updateTask(obj, thisResponse, runTime, info)
			if ~obj.taskInitialised; return; end
			if obj.totalRuns > obj.nRuns
				obj.taskFinished = true;
				fprintf('---> stimulusSequence.updateTask: Task FINISHED, no more updates allowed\n');
				return
			end

			if nargin > 1
				if isempty(thisResponse); thisResponse = NaN; end
				if ~exist('runTime','var') || isempty(runTime); runTime = GetSecs; end
				if ~exist('info','var') || isempty(info); info = 'none'; end
				obj.response(obj.totalRuns) = thisResponse;
				obj.responseInfo{obj.totalRuns} = info;
				obj.runTimeList(obj.totalRuns) = runTime - obj.startTime;
				if obj.verbose
					obj.salutation(sprintf('Task Run %i: response = %.2g @ %.2g secs',...
						obj.totalRuns, thisResponse, obj.runTimeList(obj.totalRuns)));
				end
			end

			if obj.totalRuns < obj.nRuns
				obj.totalRuns = obj.totalRuns + 1;
				[obj.thisBlock, obj.thisRun] = findRun(obj);
				randomiseTimes(obj);
			elseif obj.totalRuns == obj.nRuns
				obj.taskFinished = true;
				fprintf('---> stimulusSequence.updateTask: Task FINISHED, no more updates allowed\n');
			end
		end
		
		% ===================================================================
		%> @brief returns block and run from number of runs
		%>
		% ===================================================================
		function [block, run] = findRun(obj, index)
			if ~exist('index','var') || isempty(index); index = obj.totalRuns; end
			block = floor( (index - 1) / obj.minBlocks ) + 1;
			run = index - (obj.minBlocks * (block - 1));
		end
		
        % ===================================================================
		%> @brief the opposite of updateTask, step back one run
		%>
		% ===================================================================
        function rewindTask(obj)
            if obj.taskInitialised
                
                obj.response(obj.totalRuns) = [];
                obj.responseInfo{obj.totalRuns} = [];
                obj.runTimeList(obj.totalRuns) = [];
                obj.totalRuns = obj.totalRuns - 1;
				[obj.thisBlock, obj.thisRun] = findRun(obj);
                fprintf('===!!! REWIND Run to %i:',obj.totalRuns);
                
            end
        end
        
		% ===================================================================
		%> @brief we want to re-randomise the current run, replace it with
		%> another run in the same block. This adds some randomisation if a
		%> run needs to be rerun for a subject and you do not want the same
		%> stimulus repeatedly until there is a correct response...
		%>
		% ===================================================================
		function success = resetRun(obj)
			success = false;
			if obj.taskInitialised
				iLow = obj.totalRuns; % select from this run...
				iHigh = obj.thisBlock * obj.minBlocks; %...to the last run in the current block
				iRange = (iHigh - iLow) + 1;
				if iRange < 2
					return
				end
				randomChoice = randi(iRange); %random from 0 to range
				trialToSwap = obj.totalRuns + (randomChoice - 1);
				
				blockOffset = ((obj.thisBlock-1) * obj.minBlocks);
				blockSource = obj.totalRuns - blockOffset;
				blockDestination = trialToSwap - blockOffset;
				
				%outValues
				aTrial = obj.outValues(obj.totalRuns,:);
				bTrial = obj.outValues(trialToSwap,:);
				obj.outValues(obj.totalRuns,:) = bTrial;
				obj.outValues(trialToSwap,:) = aTrial;
				
				%outVars
				for i = 1:obj.nVars
					aVal = obj.outVars{obj.thisBlock,i}(blockSource);
					bVal = obj.outVars{obj.thisBlock,i}(blockDestination);
					obj.outVars{obj.thisBlock,i}(blockSource) = bVal;
					obj.outVars{obj.thisBlock,i}(blockDestination) = aVal;
				end
				
				%outIndex
				aIdx = obj.outIndex(obj.totalRuns,1);
				bIdx = obj.outIndex(trialToSwap,1);
				obj.outIndex(obj.totalRuns,1) = bIdx;
				obj.outIndex(trialToSwap,1) = aIdx;
				
				%outMap
				aMap = obj.outMap(obj.totalRuns,:);
				bMap = obj.outMap(trialToSwap,:);
				obj.outMap(obj.totalRuns,:) = bMap;
				obj.outMap(trialToSwap,:) = aMap;
				
				%log this change
				if isempty(obj.resetLog); myN = 1; else; myN = length(obj.resetLog)+1; end
				obj.resetLog(myN).randomChoice = randomChoice;
				obj.resetLog(myN).totalRuns = obj.totalRuns;
				obj.resetLog(myN).trialToSwap = trialToSwap;
				obj.resetLog(myN).blockSource = blockSource;
				obj.resetLog(myN).blockDestination = blockDestination;
				obj.resetLog(myN).aTrial = aTrial;
				obj.resetLog(myN).bTrial = bTrial;
				obj.resetLog(myN).aIdx = aIdx;
				obj.resetLog(myN).bIdx = bIdx;
				success = true;
				if obj.verbose;fprintf('--->>> stimulusSequence.resetRun() Task %i(v=%i): swap with = %i(v=%i) (random choice=%i)\n',obj.totalRuns, aIdx, trialToSwap, bIdx, randomChoice);end
			end
		end
		
		% ===================================================================
		%> @brief set method for the nVar structure
		%>
		%> Check we have a minimal nVar structure and deals new values
		%> appropriately.
		% ===================================================================
		function set.nVar(obj,invalue)
			if ~exist('invalue','var')
				return
			end
			if isempty(obj.nVar) || isempty(invalue) || length(fieldnames(obj.nVar)) ~= length(fieldnames(obj.varTemplate))
				obj.nVar = obj.varTemplate;
			end
			if ~isempty(invalue) && isstruct(invalue)
				idx = length(invalue);
				fn = fieldnames(invalue);
				fnTemplate = fieldnames(obj.varTemplate); %#ok<*MCSUP>
				fnOut = intersect(fn,fnTemplate);
				for ii = 1:idx
					for i = 1:length(fnOut)
						if ~isempty(invalue(ii).(fn{i}))
							obj.nVar(ii).(fn{i}) = invalue(ii).(fn{i});
						end
					end
%  					if isempty(obj.nVar(idx).(fnTemplate{1})) || obj.nVar(idx).(fnTemplate{2}) == 0 || isempty(obj.nVar(idx).(fnTemplate{3}))
%  						fprintf('---> Variable %g is not properly formed!!!\n',idx);
%  					end
				end
			end
		end
		
		% ===================================================================
		%> @brief Dependent property nVars get method
		%>
		%> Dependent property nVars get method
		% ===================================================================
		function nVars = get.nVars(obj)
			nVars = 0;
			if length(obj.nVar) > 0 && ~isempty(obj.nVar(1).name) %#ok<ISMT>
				nVars = length(obj.nVar);
			end
			obj.nVars_ = nVars; %cache value
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
			outvals = obj.outValues;
			data = cell(size(outvals,1),size(outvals,2)+2);
			for i = 1:size(outvals,1)
				for j = 1:obj.nVars
					if length(outvals{i,j}) > 1
						data{i,j} = num2str(outvals{i,j},'%2.3g ');
					else
						data{i,j} = outvals{i,j};
					end
				end
				data{i,obj.nVars+1} = obj.outIndex(i);
				for k = 1:size(obj.outMap,2)
					data{i,obj.nVars+(k+1)} = obj.outMap(i,k);
				end
			end
			if isempty(data)
				data = 'No variables!';
			end
			cnames = cell(obj.nVars,1);
			for ii = 1:obj.nVars
				cnames{ii} = obj.nVar(ii).name;
			end
			cnames{end+1} = 'outIndex';
			cnames{end+1} = 'Var1Index';
			cnames{end+1} = 'Var2Index';
			cnames{end+1} = 'Var3Index';
			cnames{end+1} = 'Var4Index';
			
			set(obj.h.uitable1,'Data',data)
			set(obj.h.uitable1,'ColumnName',cnames);
			set(obj.h.uitable1,'ColumnWidth',{60});
			set(obj.h.uitable1,'RowStriping','on')
			
			function build_gui()
				fsmall = 10;
				if ismac
					mfont = 'menlo';
				elseif ispc
					mfont = 'consolas';
				else %linux
					mfont = 'Fira Code';
				end
				obj.h.figure1 = figure( ...
					'Tag', 'sSLog', ...
					'Units', 'normalized', ...
					'Position', [0.01 0.5 0.25 0.5], ...
					'Name', 'stimulusSequence Presentation Order', ...
					'MenuBar', 'none', ...
					'NumberTitle', 'off', ...
					'Color', [0.94 0.94 0.94], ...
					'Resize', 'on');
				obj.h.uitable1 = uitable( ...
					'Parent', obj.h.figure1, ...
					'Tag', 'uitable1', ...
					'Units', 'normalized', ...
					'Position', [0 0 1 0.98], ...
					'FontName', mfont, ...
					'FontSize', fsmall, ...
					'BackgroundColor', [1 1 1;0.95 0.95 0.95], ...
					'ColumnEditable', [false,false], ...
					'ColumnFormat', {'char'}, ...
					'ColumnWidth', {'auto'});
				obj.h.uitable2 = uitable( ...
					'Parent', obj.h.figure1, ...
					'Tag', 'uitable1', ...
					'Units', 'normalized', ...
					'Position', [0 0.98 1 0.02], ...
					'FontName', mfont, ...
					'FontSize', fsmall, ...
					'BackgroundColor', [1 1 1;0.95 0.95 0.95], ...
					'ColumnEditable', [false,false], ...
					'ColumnFormat', {'char'}, ...
					'ColumnWidth', {'auto'});
			end
		end
		
		% ===================================================================
		%> @brief get a meta matrix compatible with vs parsed data,
		%  unwrapping cell arrays
		%>
		%> Generates a table with the randomised stimulus values
		% ===================================================================
		function [meta, key] = getMeta(obj)
			meta = [];
			vals = obj.outValues;
			idx = obj.outMap;
			if iscell(vals)
				for i = 1:size(vals,2)
					cc = [vals{:,i}]';
					if iscell(cc)
						t = '';
						u = unique(idx(:,i));
						for j=1:length(u)
							f = find(idx(:,i)==u(j));
							f = f(1);
							t = [t sprintf('')];
						end
						meta(:,i) = idx(:,i);
					else
						meta(:,i) = cc;
					end
					
				end
			else
				meta = obj.outValues;
			end
		end
		
		% ===================================================================
		%> @brief validate the stimulusSequence is ok
		%>
		%> Check we have a minimal task structure
		% ===================================================================
		function validate(obj)
			vin = obj.nVar;
			vout = vin;
			obj.nVar = [];
			shift = 0;
			for i = 1:length(vin)
				if isempty(vin(i).name) || isempty(vin(i).values) || isempty(vin(i).stimulus)
					vout(i + shift) = [];
					shift = shift-1;
				end
			end
			obj.nVar = vout;
			clear vin vout shift
			if obj.nVars == 0
				obj.outIndex = 1; %there is only one stimulus, no variables
			end
		end
		
	end % END METHODS
	
	%=======================================================================
	methods ( Access = private ) %------PRIVATE METHODS
	%=======================================================================
			
		% ===================================================================
		%> @brief reset dynamic task properties
		%> 
		%> 
		% ===================================================================
		function resetTask(obj)
			t = obj.tProp;
			for i = 1:2:length(t)
				p = obj.findprop(t{i});
				if ~isempty(p)
					delete(p);
				end
			end
			obj.taskInitialised = false;
			obj.taskFinished = false;
		end	
		
		% ===================================================================
		%> @brief reset dynamic task properties
		%> 
		%> 
		% ===================================================================
		function randomiseTimes(obj)
			if ~obj.taskInitialised;return;end
			if length(obj.isTime) == 2 %randomise isTime within a range
				t = obj.isTime;
				obj.isTimeNow = (rand * (t(2)-t(1))) + t(1);
				obj.isTimeNow = round(obj.isTimeNow*100)/100;
			end
			if length(obj.ibTime) == 2 %randomise ibTime within a range
				t = obj.ibTime;
				obj.ibTimeNow = (rand * (t(2)-t(1))) + t(1);
				obj.ibTimeNow = round(obj.ibTimeNow*100)/100;
			end
		end
		
		
	end
	
	%=======================================================================
	methods (Static) %------------------STATIC METHODS
	%=======================================================================
		
		% ===================================================================
		%> @brief make a matrix from a cell array
		%> 
		%> 
		% ===================================================================
		function out=cellStruct(in)
			out = [];
			if iscell(in)
				for i = 1:size(in,2)
					cc = [in{:,i}]';
					if iscell(cc)
						out = [out, [in{:,i}]'];
					else
						out = [out, cc];
					end
				end
			end
		end
		
		% ===================================================================
		%> @brief loadobj handler
		%>
		%> The problem is we use set.nVar to allow robust setting of
		%> variables, but set.nVar also gets called on loading and will mangle
		%> older saved protocols during load. We need to specify we are loading
		%> and use a conditional in set.nVar to do the right thing.
		% ===================================================================
		function lobj=loadobj(in)
			if ~isa(in,'stimulusSequence') && isstruct(in)
				fprintf('---> stimulusSequence loadobj: Rebuilding  structure...\n');
				lobj = stimulusSequence;
				lobj.isLoading = true;
				fni = fieldnames(in);
				fn = intersect(lobj.loadProperties,fni);
				for i=1:length(fn)
					lobj.(fn{i}) = in.(fn{i});
				end
			elseif isa(in,'stimulusSequence')
				%fprintf('--->  stimulusSequence loadobj: Loading stimulusSequence object...\n');
				in.currentState = []; %lets strip the old random streams
				in.oldStream = [];
				in.taskStream = [];
				lobj = in;
			else
				fprintf('--->  stimulusSequence loadobj: Loading stimulusSequence FAILED...\n');
			end
			lobj.isLoading = false;
		end
		
	end
	
end
