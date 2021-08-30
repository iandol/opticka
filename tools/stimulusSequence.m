% ========================================================================
%> DEPRECATED, use taskSequence. 
% ========================================================================
classdef stimulusSequence < optickaCore & dynamicprops
	properties
		%> whether to randomise (true) or run sequentially (false)
		randomise logical = true
		%> structure holding each independant variable
		nVar struct
		%> structure holding details of block level variable
		blockVar struct
		%> number of repeat blocks to present
		nBlocks double = 1
		%> time stimulus trial is shown
		trialTime double = 2
		%> inter stimulus trial time
		isTime double = 1
		%> inter block time
		ibTime double = 2
		%> do we follow real time or just number of ticks to get to a known time
		realTime logical = true
		%> random seed value, we can use this to set the RNG to a known state
		randomSeed
		%> mersenne twister default
		randomGenerator char = 'mt19937ar'
		%> used for dynamically estimating total number of frames
		fps double = 60
		%> verbose or not
		verbose = false
		%> insert a blank condition?
		addBlank logical = false
	end
	
	properties (SetAccess = private, GetAccess = public)
		%> structure of variable values
		outValues
		%> variable values wrapped in a per-block cell
		outVars
		%> the unique identifier for each stimulus
		outIndex
		%> mapping the stimulus to the number as a X Y and Z etc position for display
		outMap
		%> block level randomised variable
		outBlock 
		%> variable labels
		varLabels
		%> variable list
		varList
		%> minimum number of blocks
		minBlocks
		%> log of within block resets
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
		nVars
	end
	
	properties (SetAccess = private, GetAccess = private)
		isStimulus
		%> cache value for nVars
		nVars_
		%> handles from me.showLog
		h
		%> properties allowed during initial construction
		allowedProperties char = ['randomise|nVar|nBlocks|trialTime|isTime|ibTime|realTime|randomSeed|fps'...
			'randomGenerator|verbose|addBlank']
		%> used to handle problems with dependant property nVar: the problem is
		%> that set.nVar gets called before static loadobj, and therefore we need
		%> to handle this differently. Initially set to empty, set to true when
		%> running loadobj() and false when not loading object.
		isLoading = []
		%> properties used by loadobj when a structure is passed during load.
		%> this stops loading old randstreams etc.
		loadProperties cell = {'randomise','nVar','nBlocks','trialTime','isTime','ibTime','isStimulus','verbose',...
			'realTime','randomSeed','randomGenerator','outValues','outVars','addBlank', ...
			'outIndex', 'outMap', 'minBlocks','states','nState','name'}
		%> nVar template and default values
		varTemplate struct = struct('name','','stimulus',[],'values',[],'offsetstimulus',[],'offsetvalue',[])
		%> nVar template and default values
		blockTemplate struct = struct('values',{'normal'})
		%> Set up the task structures needed
		tProp cell = {'totalRuns',1,'thisBlock',1,'thisRun',1,'isBlank',false,...
			'isTimeNow',1,'ibTimeNow',1,'response',[],'responseInfo',{},'tick',0,'blankTick',0,...
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
		function me = stimulusSequence(varargin)
			
			args = optickaCore.addDefaults(varargin,struct('name','stimulusSequence'));
			me=me@optickaCore(args); %superclass constructor
			me.parseArgs(args,me.allowedProperties);
			
			me.nVar = me.varTemplate;
			me.blockVar = me.blockTemplate;
			me.initialiseGenerator();
			me.isLoading = false;
		end
		
		% ===================================================================
		%> @brief set up the random number generator
		%>
		%> set up the random number generator
		% ===================================================================
		function initialiseGenerator(me)
			if isnan(me.mversion) || me.mversion == 0
				me.mversion = str2double(regexp(version,'(?<ver>^\d+\.\d+)','match','once'));
			end
			if isempty(me.randomSeed)
				me.randomSeed=round(rand*sum(clock));
			end
			if isempty(me.oldStream)
				if me.mversion > 7.11
					me.oldStream = RandStream.getGlobalStream;
				else
					me.oldStream = RandStream.getDefaultStream; %#ok<*GETRS>
				end
			end
			me.taskStream = RandStream.create(me.randomGenerator,'Seed',me.randomSeed);
			if me.mversion > 7.11
				RandStream.setGlobalStream(me.taskStream);
			else
				RandStream.setDefaultStream(me.taskStream); %#ok<*SETRS>
			end
		end
		
		% ===================================================================
		%> @brief Reset the random number generator
		%>
		%> reset the random number generator
		% ===================================================================
		function resetRandom(me)
			me.randomSeed=[];
			if me.mversion > 7.11
				RandStream.setGlobalStream(me.oldStream);
			else
				RandStream.setDefaultStream(me.oldStream);
			end
		end
		
		% ===================================================================
		%> @brief Do the randomisation
		%>
		%> Do the randomisation
		% ===================================================================
		function randomiseStimuli(me)
			if me.nVars > 0 %no need unless we have some variables
				if me.verbose==true;rSTime = tic;end
				me.currentState=me.taskStream.State;
				nLevels = zeros(me.nVars_, 1);
				for f = 1:me.nVars_
					nLevels(f) = length(me.nVar(f).values);
				end
				me.minBlocks = prod(nLevels);
				if me.addBlank
					me.minBlocks = me.minBlocks + 1;
				end
				if isempty(me.minBlocks)
					me.minBlocks = 1;
				end
				if me.minBlocks > 255
					warning('WARNING: You are exceeding the number of stimulus numbers in an 8bit strbed word!')
				end
				
				% ---- deal with block level variable randomisation
				if isempty(me.blockVar.values)
					me.outBlock = {};
				elseif ~isempty(length(me.blockVar.values)) && length(me.blockVar) > me.nBlocks
					warning('Your block variables are greater than the number of blocks!')
					me.outBlock = cell(me.nBlocks,1);
					for i = 1:me.nBlocks
						me.outBlock{i} = me.blockVar.values{1};
					end
				else
					me.outBlock = cell(me.nBlocks,1);
					divBlock = floor(me.nBlocks / length(me.blockVar.values));
					a = 1;
					block = {};
					for i = 1:length(me.blockVar.values)
						block = [block; repmat(me.blockVar.values(i),divBlock,1)];
					end
					randb = rand(length(block),1);
					[~,idx] = sort(randb);
					block = block(idx);
					while length(block) < me.nBlocks
						block{end+1} = me.blockVar.values(randi(length(me.blockVar.values)));
					end
				end
				
				% initialize cell array that will hold balanced variables
				Vars = cell(me.nBlocks, me.nVars_);
				Vals = cell(me.nBlocks*me.minBlocks, me.nVars_);
				Indx = [];
				% the following initializes and runs the main loop in the function, which
				% generates enough repetitions of each factor, ensuring a balanced design,
				% and randomizes them
				for i = 1:me.nBlocks
					if me.randomise == true
						[~, index] = sort(rand(me.minBlocks, 1));
					else
						index = (1:me.minBlocks)';
					end
					Indx = [Indx; index];
					if me.addBlank
						pos1 = me.minBlocks - 1;
					else
						pos1 = me.minBlocks;
					end
					pos2 = 1;
					for f = 1:me.nVars_
						pos1 = pos1 / nLevels(f);
						if size(me.nVar(f).values, 1) ~= 1
							% ensure that factor levels are arranged in one row
							me.nVar(f).values = reshape(me.nVar(f).values, 1, numel(me.nVar(f).values));
						end
						% this is the critical line: it ensures there are enough repetitions
						% of the current factor in the correct order
						mb = me.minBlocks;
						if me.addBlank; mb = mb - 1; end
						Vars{i,f} = repmat(reshape(repmat(me.nVar(f).values, pos1, pos2), mb, 1), me.nVars_, 1);
						Vars{i,f} = Vars{i,f}(index);
						pos2 = pos2 * nLevels(f);
						if me.addBlank
							if iscell(Vars{i,f})
								Vars{i,f}{index==max(index)} = NaN;
							else
								Vars{i,f}(index==max(index)) = NaN;
							end
						end
					end
				end
				
				% generate me.outValues
				offset = 0;
				for i = 1:size(Vars,1)
					for j = 1:size(Vars,2)
						for k = 1:length(Vars{i,j})
							if iscell(Vars{i,j})
								Vals{offset+k,j} = Vars{i,j}{k};
							else
								Vals{offset+k,j} = Vars{i,j}(k);
							end
						end
					end
					offset = offset + me.minBlocks;
				end
				
				% assign to properties
				me.outVars = Vars;
				me.outValues = Vals;
				me.outIndex = Indx;
				
				% generate outMap
				me.outMap=zeros(size(me.outValues));
				for f = 1:me.nVars_
					for g = 1:length(me.nVar(f).values)
						for hh = 1:length(me.outValues(:,f))
							if iscell(me.nVar(f).values(g))
								if (ischar(me.nVar(f).values{g}) && ischar(me.outValues{hh,f})) && strcmpi(me.outValues{hh,f},me.nVar(f).values{g})
									me.outMap(hh,f) = g;
								elseif (isnumeric(me.nVar(f).values{g}) && isnumeric(me.outValues{hh,f})) && isequal(me.outValues{hh,f}, me.nVar(f).values{g})
									me.outMap(hh,f) = g;
									%elseif ~ischar(me.nVar(f).values{g}) && isequal(me.outValues{hh,f}, me.nVar(f).values{g})
									%	me.outMap(hh,f) = g;
								end
							else
								if me.outValues{hh,f} == me.nVar(f).values(g)
									me.outMap(hh,f) = g;
								end
							end
						end
					end
				end
				if me.verbose; me.salutation(sprintf('randomiseStimuli took %g ms\n',toc(rSTime)*1000)); end
			else
				me.outIndex = 1; %there is only one stimulus, no variables
				me.outValues = [];
				me.outVars = {};
				me.outMap = [];
				me.outBlock = {};
				me.varLabels = {};
				me.varList = {};
				me.taskInitialised = false;
				me.taskFinished = false;
			end
		end
		
		% ===================================================================
		%> @brief Initialise the variables and task together
		%>
		% ===================================================================
		function initialise(me)
			me.randomiseStimuli();
			me.initialiseTask();
			fprintf('---> stimulusSequence.initialise: Randomised and Initialised!\n');
		end
		
		% ===================================================================
		%> @brief Initialise the properties used to track the run
		%>
		%> Initialise the properties used to track the run. These are dynamic
		%> props.
		% ===================================================================
		function initialiseTask(me)
			resetTask(me);
			t = me.tProp;
			for i = 1:2:length(t)
				if isempty(me.findprop(t{i}))
					p = me.addprop(t{i}); %add new dynamic property
				end
				me.(t{i}) = t{i+1}; %#ok<*MCNPR>
			end
			me.taskInitialised = true;
			me.makeLabels();
			randomiseTimes(me);
		end
		
		% ===================================================================
		%> @brief update the task with a response
		%>
		% ===================================================================
		function updateTask(me, thisResponse, runTime, info)
			if ~me.taskInitialised; warning('--->>> stimulusSequence not initialised, cannot update!');return; end
			if me.totalRuns > me.nRuns
				me.taskFinished = true;
				fprintf('---> stimulusSequence.updateTask: Task FINISHED, no more updates allowed\n');
				return
			end
			
			if nargin > 1
				if isempty(thisResponse); thisResponse = NaN; end
				if ~exist('runTime','var') || isempty(runTime); runTime = GetSecs; end
				if ~exist('info','var') || isempty(info); info = 'none'; end
				me.response(me.totalRuns) = thisResponse;
				me.responseInfo{me.totalRuns} = info;
				me.runTimeList(me.totalRuns) = runTime - me.startTime;
				if me.verbose
					me.salutation(sprintf('Task Run %i: response = %.2g @ %.2g secs',...
						me.totalRuns, thisResponse, me.runTimeList(me.totalRuns)));
				end
			end
			
			if me.totalRuns < me.nRuns
				me.totalRuns = me.totalRuns + 1;
				[me.thisBlock, me.thisRun] = findRun(me);
				randomiseTimes(me);
			elseif me.totalRuns == me.nRuns
				me.taskFinished = true;
				fprintf('---> stimulusSequence.updateTask: Task FINISHED, no more updates allowed\n');
			end
		end
		
		% ===================================================================
		%> @brief returns block and run from number of runs
		%>
		% ===================================================================
		function [block, run] = findRun(me, index)
			if ~exist('index','var') || isempty(index); index = me.totalRuns; end
			block = floor( (index - 1) / me.minBlocks ) + 1;
			run = index - (me.minBlocks * (block - 1));
		end
		
		% ===================================================================
		%> @brief the opposite of updateTask, step back one run
		%>
		% ===================================================================
		function rewindTask(me)
			if me.taskInitialised
				me.response(me.totalRuns) = [];
				me.responseInfo{me.totalRuns} = [];
				me.runTimeList(me.totalRuns) = [];
				me.totalRuns = me.totalRuns - 1;
				[me.thisBlock, me.thisRun] = findRun(me);
				fprintf('===!!! REWIND Run to %i:',me.totalRuns);
				
			end
		end
		
		% ===================================================================
		%> @brief we want to re-randomise the current run, replace it with
		%> another run in the same block. This adds some randomisation if a
		%> run needs to be rerun for a subject and you do not want the same
		%> stimulus repeatedly until there is a correct response...
		%>
		% ===================================================================
		function success = resetRun(me)
			success = false;
			if me.taskInitialised
				iLow = me.totalRuns; % select from this run...
				iHigh = me.thisBlock * me.minBlocks; %...to the last run in the current block
				iRange = (iHigh - iLow) + 1;
				if iRange < 2
					return
				end
				randomChoice = randi(iRange); %random from 0 to range
				trialToSwap = me.totalRuns + (randomChoice - 1);
				
				blockOffset = ((me.thisBlock-1) * me.minBlocks);
				blockSource = me.totalRuns - blockOffset;
				blockDestination = trialToSwap - blockOffset;
				
				%outValues
				aTrial = me.outValues(me.totalRuns,:);
				bTrial = me.outValues(trialToSwap,:);
				me.outValues(me.totalRuns,:) = bTrial;
				me.outValues(trialToSwap,:) = aTrial;
				
				%outVars
				for i = 1:me.nVars
					aVal = me.outVars{me.thisBlock,i}(blockSource);
					bVal = me.outVars{me.thisBlock,i}(blockDestination);
					me.outVars{me.thisBlock,i}(blockSource) = bVal;
					me.outVars{me.thisBlock,i}(blockDestination) = aVal;
				end
				
				%outIndex
				aIdx = me.outIndex(me.totalRuns,1);
				bIdx = me.outIndex(trialToSwap,1);
				me.outIndex(me.totalRuns,1) = bIdx;
				me.outIndex(trialToSwap,1) = aIdx;
				
				%outMap
				aMap = me.outMap(me.totalRuns,:);
				bMap = me.outMap(trialToSwap,:);
				me.outMap(me.totalRuns,:) = bMap;
				me.outMap(trialToSwap,:) = aMap;
				
				%log this change
				if isempty(me.resetLog); myN = 1; else; myN = length(me.resetLog)+1; end
				me.resetLog(myN).randomChoice = randomChoice;
				me.resetLog(myN).totalRuns = me.totalRuns;
				me.resetLog(myN).trialToSwap = trialToSwap;
				me.resetLog(myN).blockSource = blockSource;
				me.resetLog(myN).blockDestination = blockDestination;
				me.resetLog(myN).aTrial = aTrial;
				me.resetLog(myN).bTrial = bTrial;
				me.resetLog(myN).aIdx = aIdx;
				me.resetLog(myN).bIdx = bIdx;
				success = true;
				if me.verbose;fprintf('--->>> stimulusSequence.resetRun() Task %i(v=%i): swap with = %i(v=%i) (random choice=%i)\n',me.totalRuns, aIdx, trialToSwap, bIdx, randomChoice);end
			end
		end
		
		% ===================================================================
		%> @brief set method for the nVar structure
		%>
		%> Check we have a minimal nVar structure and deals new values
		%> appropriately.
		% ===================================================================
		function set.nVar(me,invalue)
			if ~exist('invalue','var')
				return
			end
			if isempty(me.nVar) || isempty(invalue) || length(fieldnames(me.nVar)) ~= length(fieldnames(me.varTemplate))
				me.nVar = me.varTemplate;
			end
			if ~isempty(invalue) && isstruct(invalue)
				idx = length(invalue);
				fn = fieldnames(invalue);
				fnTemplate = fieldnames(me.varTemplate); %#ok<*MCSUP>
				fnOut = intersect(fn,fnTemplate);
				for ii = 1:idx
					for i = 1:length(fnOut)
						if ~isempty(invalue(ii).(fn{i}))
							me.nVar(ii).(fn{i}) = invalue(ii).(fn{i});
						end
					end
					% if isempty(me.nVar(idx).(fnTemplate{1})) || me.nVar(idx).(fnTemplate{2}) == 0 || isempty(me.nVar(idx).(fnTemplate{3}))
					%  	fprintf('---> Variable %g is not properly formed!!!\n',idx);
					% end
				end
			end
		end
		
		% ===================================================================
		%> @brief Dependent property nVars get method
		%>
		%> Dependent property nVars get method
		% ===================================================================
		function nVars = get.nVars(me)
			nVars = 0;
			if length(me.nVar) > 0 && ~isempty(me.nVar(1).name) %#ok<ISMT>
				nVars = length(me.nVar);
			end
			me.nVars_ = nVars; %cache value
		end
		
		% ===================================================================
		%> @brief Dependent property nRuns get method
		%>
		%> Dependent property nruns get method
		% ===================================================================
		function nRuns = get.nRuns(me)
			nRuns = me.minBlocks*me.nBlocks;
		end
		
		% ===================================================================
		%> @brief Dependent property nFrames get method
		%>
		%> Dependent property nFrames get method
		% ===================================================================
		function nFrames = get.nFrames(me)
			nSecs = (me.nRuns * me.trialTime) + (me.minBlocks-1 * me.isTime) + (me.nBlocks-1 * me.ibTime);
			nFrames = ceil(nSecs) * ceil(me.fps); %be a bit generous in defining how many frames the task will take
		end
		
		% ===================================================================
		%> @brief showLog
		%>
		%> Generates a table with the randomised stimulus values
		% ===================================================================
		function showLog(me)
			me.makeLabels();
			me.h = struct();
			build_gui();
			outvals = me.outValues;
			data = cell(size(outvals,1),size(outvals,2)+2);
			for i = 1:size(outvals,1)
				for j = 1:me.nVars
					if iscell(outvals{i,j})
						data{i,j} = num2str(outvals{i,j}{1},'%2.3g ');
					elseif length(outvals{i,j}) > 1
						data{i,j} = num2str(outvals{i,j},'%2.3g ');
					else
						data{i,j} = outvals{i,j};
					end
				end
				data{i,me.nVars+1} = me.outIndex(i);
				for k = 1:size(me.outMap,2)
					data{i,me.nVars+(k+1)} = me.outMap(i,k);
				end
			end
			if isempty(data)
				data = 'No variables!';
			end
			cnames = cell(me.nVars,1);
			for ii = 1:me.nVars
				cnames{ii} = [me.nVar(ii).name num2str(me.nVar(ii).stimulus,'-%i')];
			end
			cnames{end+1} = 'outIndex';
			for ii = 1:size(me.outMap,2)
				cnames{end+1} = ['Var' num2str(ii) 'Index'];
			end
			data = cell2table(data,'VariableNames',cnames);
			set(me.h.uitable1,'Data',data);
			
			function build_gui()
				fsmall = 12;
				if ismac
					mfont = 'menlo';
				elseif ispc
					mfont = 'consolas';
				else %linux
					mfont = 'Liberation Mono';
				end
				me.h.figure1 = uifigure( ...
					'Tag', 'sSLog', ...
					'Units', 'normalized', ...
					'Position', [0 0.2 0.25 0.7], ...
					'Name', ['Log: ' me.fullName], ...
					'MenuBar', 'none', ...
					'NumberTitle', 'off', ...
					'Color', [0.94 0.94 0.94], ...
					'Resize', 'on');
				me.h.uitable1 = uitable( ...
					'Parent', me.h.figure1, ...
					'Tag', 'uitable1', ...
					'Units', 'normalized', ...
					'Position', [0 0 1 1], ...
					'FontName', mfont, ...
					'FontSize', fsmall, ...
					'BackgroundColor', [1 1 1;0.95 0.95 0.95], ...
					'RowStriping','on', ...
					'ColumnEditable', [], ...
					'ColumnWidth', {'auto'});
			end
		end
		
		% ===================================================================
		%> @brief get a meta matrix compatible with vs parsed data,
		%  unwrapping cell arrays
		%>
		%> Generates a table with the randomised stimulus values
		% ===================================================================
		function [meta, key] = getMeta(me)
			meta = [];
			vals = me.outValues;
			idx = me.outMap;
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
				meta = me.outValues;
			end
		end
		
		% ===================================================================
		%> @brief get a meta matrix compatible with vs parsed data,
		%  unwrapping cell arrays
		%>
		%> Generates a table with the randomised stimulus values
		% ===================================================================
		function [labels, list] = getLabels(me)
			labels = [];
			list = [];
			me.makeLabels()
			if ~isempty(me.varLabels); labels = me.varLabels; end
			if ~isempty(me.varList); list = me.varList; end
		end
		
		% ===================================================================
		%> @brief validate the stimulusSequence is ok
		%>
		%> Check we have a minimal task structure
		% ===================================================================
		function validate(me)
			if me.nVars == 0
				me.outIndex = 1; %there is only one stimulus, no variables
				me.varLabels = {};
				me.varList = {};
			else
				vin = me.nVar;
				vout = vin;
				me.nVar = [];
				shift = 0;
				for i = 1:length(vin)
					if isempty(vin(i).name) || isempty(vin(i).values) || isempty(vin(i).stimulus)
						vout(i + shift) = [];
						shift = shift-1;
					end
				end
				me.nVar = vout;
				clear vin vout shift
				makeLabels(me);
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
		function makeLabels(me)
			if ~me.taskInitialised || me.nVars == 0; return; end
			varIndex = sort(unique(me.outIndex));
			list = cell(length(varIndex),me.nVars+2);
			for i = 1:length(varIndex)
				st = '';
				idx = find(me.outIndex==varIndex(i));
				list{i,1} = varIndex(i);
				list{i,2} = idx;
				idx = idx(1);
				for j = 1:me.nVars
					if iscell(me.outValues{i,j})
						st = [st ' | ' me.nVar(j).name ':' num2str([me.outValues{idx,j}{:}])];
						list{i,j+2} = me.outValues{idx,j}{:};
					else
						st = [st ' | ' me.nVar(j).name ':' num2str(me.outValues{idx,j})];
						list{i,j+2} = me.outValues{idx,j};
					end
				end
				st = regexprep(st,'^\s+\|\s+','');
				str{i} = [num2str(varIndex(i)) ' = ' st];
			end
			[~,res] = sort(varIndex);
			str = str(res);
			if size(str,1) < size(str,2); str = str'; end
			me.varLabels = str;
			me.varList = list;
		end
		
		% ===================================================================
		%> @brief reset dynamic task properties
		%>
		%>
		% ===================================================================
		function resetTask(me)
			t = me.tProp;
			for i = 1:2:length(t)
				p = me.findprop(t{i});
				if ~isempty(p)
					delete(p);
				end
			end
			me.resetLog = [];
			me.taskInitialised = false;
			me.taskFinished = false;
		end
		
		% ===================================================================
		%> @brief reset dynamic task properties
		%>
		%>
		% ===================================================================
		function randomiseTimes(me)
			if ~me.taskInitialised;return;end
			if length(me.isTime) == 2 %randomise isTime within a range
				t = me.isTime;
				me.isTimeNow = (rand * (t(2)-t(1))) + t(1);
				me.isTimeNow = round(me.isTimeNow*100)/100;
			end
			if length(me.ibTime) == 2 %randomise ibTime within a range
				t = me.ibTime;
				me.ibTimeNow = (rand * (t(2)-t(1))) + t(1);
				me.ibTimeNow = round(me.ibTimeNow*100)/100;
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
