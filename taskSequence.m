% ========================================================================
classdef taskSequence < optickaCore & dynamicprops
%> @class taskSequence
%> @brief Block-based variable randomisation manager
%>
%> This class takes one or more variables, each with an array of values
%> and randomly interleves them into a randomised variable list each of
%> which has a unique index number. 
%> 
%> This example creates an `angle` varible that is randomised over 5
%> different values and will be applied to the first 3 stimuli; in addition,
%> the fourth stimulus will have the value offset by 45°:
%>
%> ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~{.matlab}
%> ts = taskSequence('nBlocks',10);
%> ts.nVar(1).name = 'angle';
%> ts.nVar(1).values = [ -90, -45, 0, 45, 90 ];
%> ts.nVar(1).stimulus = [1, 2, 3];
%> ts.nVar(1).offsetstimulus = 4;
%> ts.nVar(1).offsetvalue = 45
%> ts.randomiseTask;
%> ts.showLog;
%> ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
%>
%> @todo integrate carryoverCounterbalance() as an alternative to block
%>  randomisation...
%> 
%> Copyright ©2014-2022 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ========================================================================

	properties
		%> structure holding each independant stimulus variable name = name
		%> of the stimulus variable values = the values as a numerical or
		%> cell array stimulus = which stimulus to apply to? offsetstimulus
		%> = an offset can be applied to other stimuli offsetvalue = the
		%> value offset, e.g. 90 for angle will add 90 to any random angle
		%> value e.g. nVar(1) = struct('name','contrast','stimulus',[1
		%> 2],'values',[0 0.1 0.2],'offsetstimulus',[3],'offsetvalue',[0.1])
		nVar struct
		%> independent block level identifying factor, for example
		%> blockVar.values={'A','B'} + blockVar.probability = [0.6 0.4];
		%> will assign A and B to blocks with a 60:40 probability.
		blockVar struct
		%> independent trial level identifying factor
		%> trialVar.values={'YES','NO'} + trialVar.probability = [0.5 0.5];
		%> will assign YES and NO to trials with a 50:50 probability.
		trialVar struct
		%> number of repeated blocks to present
		nBlocks double			= 1
		% staircase manager, uses Palamedes PAL_AM* functions, pass the
		% output of the setupXX function to 'sc'. type = type of staircase:
		% UD=up/down RF=QUEST PM=Psi-Method, e.g. PAL_AMUD_updateUD = UD. 
		% invert = false means correct steps down, we can invert it to 
		% "step up" on correct.
		staircase				= struct('sc',[],'type','UD','invert',false);
		%> whether to randomise nVar (true) or run sequentially (false)
		randomise logical		= true
		%> insert a blank condition in each block?
		addBlank logical		= false
		%> do we follow real time or just number of ticks to get to a known time
		realTime logical		= true
		%> random seed value, we can use this to set the RNG to a known state
		%> default is empty to use the unique current date+time
		randomSeed double		= []
		%> mersenne twister default, see MATLAB docs for other options
		randomGenerator char	= 'mt19937ar'
		%> verbose or not
		verbose					= false
	end
	
	properties (Dependent = true,  SetAccess = private)
		%> number of independant variables
		nVars
		%> minimum number of trials within a block, depends on nVar values
		minTrials
		%> number of runs, blocks x trials
		nRuns
		%> estimate of the total number of frames this task may occupy,
		%> requires accurate fps and assumes a MOC task
		nFrames
	end
	
	properties (Hidden = true)
		%> used for dynamically estimating total number of frames
		fps double				= 60
		%> time stimulus trial is shown
		trialTime double		= 2
		%> inter stimulus trial time
		isTime double			= 1
		%> inter block time
		ibTime double			= 2
		%> original index before any resetRun()s
		startIndex
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
		%> block level randomised factor
		outBlock 
		%> trial level randomised factor
		outTrial
		%> variable labels
		varLabels
		%> variable list
		varList
		%> log of within block resets
		resetLog
		%> have we initialised the dynamic task properties?
		taskInitialised logical = false
		%> has task finished
		taskFinished logical	= false
		%> which seed values were used?
		thisSeed				= []
		usedSeeds				= []
		%> all indexes converted to a table for presentation
		dataTable
	end
	
	properties (SetAccess = private, GetAccess = public, Transient = true, Hidden = true)
		%> old random number stream
		oldStream
		%> current random number stream
		taskStream
		%> current random stream state
		currentState
	end

	properties (Transient = true, SetAccess = private, GetAccess = private)
		%> handles from me.showLog
		h
	end
	
	properties (SetAccess = private, GetAccess = private)
		%> cache value for nVars
		nVars_
		%> cache value for minTrials
		minTrials_
		%> used in calculatin mintrials
		nLevels
		%> properties allowed during initial construction
		allowedProperties = {'randomise','nVar','blockVar','trialVar','nBlocks',...
			'trialTime','isTime','ibTime','realTime','randomSeed','fps',...
			'randomGenerator','verbose','addBlank','staircase'}
		%> used to handle problems with dependant property nVar: the problem
		%> is that set.nVar gets called before static loadobj, and therefore
		%> we need to handle this differently. Initially set to empty, set
		%> to true when running loadobj() and false when not loading object.
		isLoading = []
		%> properties used by loadobj when a structure is passed during load.
		%> this stops loading old randstreams etc.
		loadProperties cell = {'randomise','nVar','nBlocks','trialTime','isTime','ibTime','verbose',...
			'realTime','randomSeed','randomGenerator','outValues','outVars','addBlank', ...
			'outIndex', 'outMap', 'minTrials','states','nState','name','staircase'}
		%> nVar template and default values
		varTemplate struct = struct('name','','stimulus',[],'values',[],'offsetstimulus',[],'offsetvalue',[])
		%> blockVar template and default values
		blockTemplate struct = struct('values',{{'none'}},'probability',[1],'comment','block level factor')
		%> blockVar template and default values
		trialTemplate struct = struct('values',{{'none'}},'probability',[1],'comment','trial level factor')
		%> Set up the task structures needed
		tProp cell = {'totalRuns',1,'thisBlock',1,'thisRun',1,'isBlank',false,...
			'isTimeNow',1,'ibTimeNow',1,'response',[],'responseInfo',{},'tick',0,'blankTick',0,...
			'switched',false,'strobeThisFrame',false,'doUpdate',false,'startTime',0,'switchTime',0,...
			'switchTick',0,'timeNow',0,'runTimeList',[],'stimIsDrifting',[],'stimIsMoving',[],...
			'stimIsDots',[],'stimIsFlashing',[]}
	end
	
	
	methods
		% ===================================================================
		function me = taskSequence(varargin)
		%> @fn taskSequence
		%> @brief Class constructor
		%>
		%> Initialises the class sending any parameters to parseArgs.
		%>
		%> @param varargin are passed as a structure of properties which is
		%> parsed.
		%> @return instance of the class.
		% ===================================================================
			args = optickaCore.addDefaults(varargin,struct('name','taskSequence'));
			me = me@optickaCore(args); %superclass constructor
			me.parseArgs(args,me.allowedProperties);
			
			me.nVar = me.varTemplate;
			me.blockVar = me.blockTemplate;
			me.trialVar = me.trialTemplate;
			me.isLoading = false;
			initialiseGenerator(me);
			
		end
		
		% ===================================================================
		function initialiseGenerator(me)
		%> @fn initialiseGenerator()
		%> @brief set up the random number generator
		%>
		%> set up the random number generator
		% ===================================================================
			if isempty(me.randomSeed)
				me.thisSeed=round(rand*sum(clock));
			else
				me.thisSeed = me.randomSeed;
			end
			me.usedSeeds(end+1) = me.thisSeed;
			if isempty(me.oldStream)
				if ~verLessThan('matlab','7.11')
					me.oldStream = RandStream.getGlobalStream;
				else
					me.oldStream = RandStream.getDefaultStream; %#ok<*GETRS>
				end
			end
			me.taskStream = RandStream.create(me.randomGenerator,'Seed',me.thisSeed);
			if ~verLessThan('matlab','7.11')
				RandStream.setGlobalStream(me.taskStream);
			else
				RandStream.setDefaultStream(me.taskStream); %#ok<*SETRS>
			end
		end
		
		% ===================================================================
		function resetRandom(me)
		%> @fn resetRandom
		%> @brief Reset the random number generator
		%>
		%> reset the random number generator
		% ===================================================================
			if ~verLessThan('matlab','7.11')
				RandStream.setGlobalStream(me.oldStream);
			else
				RandStream.setDefaultStream(me.oldStream);
			end
		end
		
		% ===================================================================
		function randomiseTask(me)
		%> @fn randomiseTask
		%> @brief Do the main randomisation
		%>
		%> This method will take the parameters in nVar, blockVar and
		%> trialVar and perform the randomisation and balancing.
		% ===================================================================
			if me.nVars == 0
				me.outIndex = 1; %there is only one stimulus, no variables
				me.outValues = [];
				me.outVars = {};
				me.outMap = [];
				me.outBlock = {};
				me.varLabels = {};
				me.varList = {};
				me.taskFinished = false;
				return
			end
			
			rSTime = tic;
			
			if me.minTrials > 255
				warning('WARNING: You are exceeding the number of variable numbers in an 8bit strobed word!')
			end

			initialiseGenerator(me);

			checkBlockTrialVars(me);
			% ---- deal with block level factor randomisation
			if isempty(me.blockVar.values)
				me.outBlock = {};
			elseif length(me.blockVar.values) > me.nBlocks
				error('Your block factors are greater than the number of blocks!')
			else 
				if sum(me.blockVar.probability) ~= 1 || length(me.blockVar.values) ~= length(me.blockVar.probability)
					warning('blockVar probability doesn''t sum to 100!'); 
					prob = [];
				else
					prob = me.blockVar.probability;
				end
				
				[~,b] = sort(me.blockVar.probability);
				p = me.blockVar.probability(b);
				v = me.blockVar.values(b);
				prob = cumsum(p); %cumulative sum
				
				Vals = cell(me.nBlocks, 1);
				for i = 1:length(Vals)
					thisR = rand();
					a = 1;
					while isempty(Vals{i}) && a <= length(prob)
						if thisR <= prob(a)
							Vals{i} = v{a};
						end
						a = a + 1;
					end
				end
				me.outBlock = Vals;
			end

			% ---- deal with trial level factor randomisation
			tVn = length(me.trialVar.values);
			if tVn == 0
				me.outTrial = {};
			else
				if sum(me.trialVar.probability) ~= 1 || tVn ~= length(me.trialVar.probability)
					error('blockVar probability doesn''t sum to 1!'); 
				end
				
				[~,b] = sort(me.trialVar.probability);
				p = me.trialVar.probability(b);
				v = me.trialVar.values(b);
				prob = cumsum(p); %cumulative sum
	
				Vals = cell(me.nRuns, 1);
				for i = 1:length(Vals)
					thisR = rand();
					a = 1;
					while isempty(Vals{i}) && a <= length(prob)
						if thisR <= prob(a)
							Vals{i} = v{a};
						end
						a = a + 1;
					end
				end
				me.outTrial = Vals;
			end

			% ---- initialize cell array that will hold balanced variables
			Vars = cell(me.nBlocks, me.nVars_);
			Vals = cell(me.nRuns, me.nVars_);
			Indx = [];
			% the following initializes and runs the main loop in the function, which
			% generates enough repetitions of each factor, ensuring a balanced design,
			% and randomizes them
			for i = 1:me.nBlocks
				if me.randomise == true
					[~, index] = sort(rand(me.minTrials, 1));
				else
					index = (1:me.minTrials)';
				end
				Indx = [Indx; index];
				if me.addBlank
					pos1 = me.minTrials - 1;
				else
					pos1 = me.minTrials;
				end
				pos2 = 1;
				for f = 1:me.nVars_
					pos1 = pos1 / me.nLevels(f);
					if size(me.nVar(f).values, 1) ~= 1
						% ensure that factor levels are arranged in one row
						me.nVar(f).values = reshape(me.nVar(f).values, 1, numel(me.nVar(f).values));
					end
					% this is the critical line: it ensures there are enough repetitions
					% of the current factor in the correct order
					mb = me.minTrials;
					if me.addBlank; mb = mb - 1; end
					Vars{i,f} = repmat(reshape(repmat(me.nVar(f).values, pos1, pos2), mb, 1), me.nVars_, 1);
					Vars{i,f} = Vars{i,f}(index);
					pos2 = pos2 * me.nLevels(f);
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
				offset = offset + me.minTrials;
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
			
			buildTable(me); %for display
			me.salutation('randomiseTask', sprintf('Took %.1f ms',toc(rSTime)*1000), true);
			
		end
		
		% ===================================================================
		function initialise(me, randomise)
		%> @fn initialise
		%> @brief Initialise the variables and task together
		%>
		%> @param randomise [default=false] do we force randomiseTask to be run
		% ===================================================================
			if ~exist('randomise','var'); randomise = false; end
			resetTask(me);
			if randomise || isempty(me.outIndex); randomiseTask(me); end
			t = me.tProp;
			for i = 1:2:length(t)
				if isempty(me.findprop(t{i}))
					p = me.addprop(t{i}); %add new dynamic property
				end
				me.(t{i}) = t{i+1}; %#ok<*MCNPR>
			end
			me.taskInitialised = true;
			makeLabels(me);
			randomiseTimes(me);
			backup(me);
			fprintf('---> taskSequence.initialise: Initialised!\n');
		end
		
		% ===================================================================
		function backup(me)
		%> @fn backup
		%> @brief Initialise the properties used to track the run
		%>
		%> Initialise the properties used to track the run. These are dynamic
		%> props.
		% ===================================================================
			me.startIndex = me.outIndex;
		end
		
		% ===================================================================
		function updateTask(me, thisResponse, runTime, info)
		%> @fn updateTask
		%> @brief update the task with a response
		%>
		%> This method allows us to update the task with a response, and
		%> will track when the task is finished: setting taskFinished==true
		% ===================================================================
			if ~me.taskInitialised; warning('--->>> taskSequence not initialised, cannot update!');return; end
			if me.totalRuns > me.nRuns
				me.taskFinished = true;
				fprintf('---> taskSequence.updateTask: Task FINISHED, no more updates allowed\n');
				return
			end
			if ~exist('thisResponse','var') || isempty(thisResponse); thisResponse = NaN; end
			if ~exist('runTime','var') || isempty(runTime); runTime = GetSecs; end
			if ~exist('info','var') || isempty(info); info = 'none'; end
			

			me.response(me.totalRuns) = thisResponse;
			me.responseInfo{me.totalRuns} = info;
			me.runTimeList(me.totalRuns) = runTime - me.startTime;

			if ~isempty(me.resetLog) && me.resetLog(end).totalRuns == me.totalRuns && me.resetLog(end).success == true
				me.responseInfo{me.totalRuns} = {me.resetLog(end).message, me.responseInfo{me.totalRuns}};
			end

			if me.verbose
				me.salutation(sprintf('Trial = %i Response = %.2g @ %.2g secs',...
					me.totalRuns, thisResponse, me.runTimeList(me.totalRuns)));
			end
			
			if me.totalRuns < me.nRuns
				me.totalRuns = me.totalRuns + 1;
				[me.thisBlock, me.thisRun] = findRun(me);
				randomiseTimes(me);
			elseif me.totalRuns >= me.nRuns
				me.taskFinished = true;
				fprintf('---> taskSequence.updateTask: Task FINISHED, no more updates allowed\n');
			end
		end

		% ===================================================================
		function updateStaircase(me, thisResponse, n)
		%> @fn updateTask
		%> @brief update the task with a response
		%>
		%> This method allows us to update the task with a response, and
		%> will track when the task is finished: setting taskFinished==true
		% ===================================================================
			if ~exist('thisResponse','var'); warning('taskSequence.updateStaircase() update needs a response value');return; end
			if ~exist('n','var'); n = 1; end
			if ~isempty(me.staircase) && isstruct(me.staircase) && isfield(me.staircase(n).sc,'xCurrent')
				if ~me.staircase(n).invert
					res = 1; 
				else
					res = 0; 
				end
				if thisResponse == true || thisResponse == 1
					response = res;
				else
					response = ~res;
				end
				sc = ['me.staircase(' num2str(n) ').sc'];
				ty = me.staircase(n).type;
				cmd = [sc ' = PAL_AM' ty '_update' ty '(' sc ', ' num2str(response) ');'];
				eval(cmd);
				if me.verbose;fprintf('--->>> taskSequence.updateStaircase() Staircase %i - Result %i:\n',n,response);end
				if me.staircase(n).sc.stop; fprintf('===>>> taskSequence Staircase %i has stopped...\n',n); end
			end
		end
		
		% ===================================================================
		function [block, run, var, index] = findRun(me, index)
		%> @fn [block, run, var] = findRun(me, index)
		%> @brief returns block and run from number of runs
		%>
		%> @param index the number of the trial
		%> @return block the block this trial is in
		%> @return run the number within the block
		%> @return var the variable number
		%> @return index the index used
		% ===================================================================
			if me.nVars == 0
				block = 1; run = 1; var = 1;
				return
			end
			if ~exist('index','var') || isempty(index); index = me.totalRuns; end
			block = floor( (index - 1) / me.minTrials ) + 1;
			run = index - (me.minTrials * (block - 1));
			var = me.outIndex(index);
		end
		
		% ===================================================================
		function rewindTask(me)
		%> @fn rewindTask
		%> @brief this steps back one run
		%>
		% ===================================================================
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
		function [success, message] = resetRun(me)
		%> @fn resetRun
		%> @brief re-randomise within the current block
		%>
		%> If the subject got a trial wrong, we want to try to show a
		%> different trial within the same block. This adds some
		%> randomisation if a run needs to be rerun for a subject and you do
		%> not want the same stimulus repeatedly until there is a correct
		%> response. Note the limitation is if this is the last trial in a
		%> block, the randomisation cannot do anything.
		%>
		%> @return success did we manage to randomise?
		%> @return message details of the swapped trials
		% ===================================================================
			success = false; message = '';
			if me.taskInitialised && me.nVars > 0
				[b,r,v,ix] = me.findRun;
				message = sprintf('--->>> taskSequence.resetRun() Blk/Run/Var/Idx %i/%i/%i/%i ',b,r,v,ix);
				iLow = me.totalRuns; % select from this run...
				iHigh = me.thisBlock * me.minTrials; %...to the last run in the current block
				iRange = (iHigh - iLow) + 1;
				if iRange < 2
					return
				end
				randomChoice = randi(iRange); %random from 0 to range
				trialToSwap = me.totalRuns + (randomChoice - 1);
				if trialToSwap == me.totalRuns
					message = sprintf('%s >>> no change made...',message);
					if isempty(me.resetLog); myN = 1; else; myN = length(me.resetLog)+1; end
					me.resetLog(myN).success = success;
					me.resetLog(myN).totalRuns = me.totalRuns;
					me.resetLog(myN).trialToSwap = trialToSwap;
					me.resetLog(myN).randomChoice = randomChoice;
					me.resetLog(myN).message = message;
					if me.verbose; disp(message); end
					return;
				end
				blockOffset = ((me.thisBlock-1) * me.minTrials);
				blockSource = me.totalRuns - blockOffset;
				blockDestination = trialToSwap - blockOffset;
				
				%outValues
				aValue = me.outValues(me.totalRuns,:);
				bValue = me.outValues(trialToSwap,:);
				me.outValues(me.totalRuns,:) = bValue;
				me.outValues(trialToSwap,:) = aValue;
				
				%outTrial
				aTrial = me.outTrial(me.totalRuns,:);
				bTrial = me.outTrial(trialToSwap,:);
				me.outTrial(me.totalRuns,:) = bTrial;
				me.outTrial(trialToSwap,:) = aTrial;
				
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
				success = true;
				if isempty(me.resetLog); myN = 1; else; myN = length(me.resetLog)+1; end
				me.resetLog(myN).success = success;
				me.resetLog(myN).totalRuns = me.totalRuns;
				me.resetLog(myN).trialToSwap = trialToSwap;
				me.resetLog(myN).randomChoice = randomChoice;
				me.resetLog(myN).blockSource = blockSource;
				me.resetLog(myN).blockDestination = blockDestination;
				me.resetLog(myN).aIdx = aIdx;
				me.resetLog(myN).bIdx = bIdx;
				me.resetLog(myN).aTrial = aTrial;
				me.resetLog(myN).bTrial = bTrial;
				me.resetLog(myN).newIndex = me.outIndex;
				[b,r,v,ix] = me.findRun;
				message = sprintf('%s >> %i/%i/%i/%i ',message,b,r,v,ix);
				message = sprintf('%s | Run=%i swap trial %i(v=%i) with %i(v=%i) : trialToSwap=%i (random choice trial %i)', ...
					message, me.totalRuns, blockSource, aIdx, blockDestination,...
					bIdx, trialToSwap, randomChoice);
				me.resetLog(myN).message = message;
				disp(message);
			end
		end
		
		% ===================================================================
		function set.nVar(me,invalue)
		%> @fn set.nVar
		%> @brief set method for the nVar structure
		%>
		%> Check we have a minimal nVar structure and deals new values
		%> appropriately.
		% ===================================================================
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
						me.nVar(ii).(fn{i}) = invalue(ii).(fn{i});
					end
					if isempty(me.nVar(ii).offsetstimulus)
						me.nVar(ii).offsetvalue = [];
					end
				end
			end
		end
		
		% ===================================================================
		function nVars = get.nVars(me)
		%> @fn get.nVars
		%> @brief Dependent property for how many variables we have
		%>
		%> Calculates ependent property nVars get method
		% ===================================================================
			nVars = 0;
			if length(me.nVar) > 0 && ~isempty(me.nVar(1).name) %#ok<ISMT>
				nVars = length(me.nVar);
			end
			me.nVars_ = nVars; %cache value
		end

		% ===================================================================
		function minTrials = get.minTrials(me)
		%> @fn get.minTrials
		%> @brief Dependent property for the minimum number of conditions based
		%> on the values in nVar.
		%>
		% ===================================================================
			me.nLevels = zeros(me.nVars, 1);
			for f = 1:me.nVars_
				me.nLevels(f) = length(me.nVar(f).values);
			end
			minTrials = prod(me.nLevels);
			if isempty(minTrials)
				minTrials = 0;
			end
			if me.addBlank
				minTrials = minTrials + 1;
			end
			me.minTrials_ = minTrials;
		end
		
		% ===================================================================
		function nRuns = get.nRuns(me)
		%> @fn get.nRuns
		%> @brief Dependent property nRuns get method
		%>
		%> Dependent property nruns get method
		% ===================================================================
			nRuns = me.minTrials * me.nBlocks;
		end

		% ===================================================================	
		function nFrames = get.nFrames(me)
		%> @fn get.nFrames
		%> @brief Dependent property nFrames get method
		%>
		%> Gives us an approximate number of frames this task may take
		% ===================================================================
			nSecs = (me.nRuns * me.trialTime) + (me.minTrials-1 * me.isTime) + (me.nBlocks-1 * me.ibTime);
			nFrames = ceil(nSecs) * ceil(me.fps); %be a bit generous in defining how many frames the task will take
		end
		
		function showLog(me)
			showTable(me);
		end
		% ===================================================================
		function showTable(me)
		%> @fn showTable
		%> @brief showTable
		%>
		%> Generates a table with the randomised stimulus values
		% ===================================================================
			me.makeLabels();
			me.h = struct();
			if me.nRuns > 17
				build_gui(0.7);
			elseif me.nRuns > 10
				build_gui(0.4);
			else
				build_gui(0.25);
			end

			buildTable(me);
			
			set(me.h.uitable1,'Data',me.dataTable);
			
			function build_gui(heightin)
				fsmall = 12;
				if ismac
					mfont = 'menlo';
				elseif ispc
					mfont = 'consolas';
				else %linux
					mfont = 'Ubuntu Mono';
				end
				me.h.figure1 = uifigure( ...
					'Tag', 'sSLog', ...
					'Units', 'normalized', ...
					'Position', [0.6 0 0.4 heightin], ...
					'Name', ['Table: ' me.fullName], ...
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
					'RowName', 'numbered',...
					'BackgroundColor', [1 1 1;0.95 0.95 0.95], ...
					'RowStriping','on', ...
					'ColumnEditable', [], ...
					'ColumnWidth', {'auto'});
			end
		end
		
		% ===================================================================
		function [meta, key] = getMeta(me)
		%> @fn getMeta
		%> @brief get a meta matrix compatible with VS parsed data,
		%> unwrapping cell arrays
		%>
		%> Generates a table with the randomised stimulus values
		% ===================================================================
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
		function [labels, list] = getLabels(me)
		%> @fn getLabels
		%> @brief get the labels for the variables
		% ===================================================================
			labels = [];
			list = [];
			me.makeLabels()
			if ~isempty(me.varLabels); labels = me.varLabels; end
			if ~isempty(me.varList); list = me.varList; end
		end
		
		% ===================================================================
		function validate(me)
		%> @fn validate
		%> @brief validate the taskSequence is ok
		%>
		%> Check we have a minimal task structure
		% ===================================================================
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
		function buildTable(me)
		%> @fn buildTable
		%> @brief buildTable builds a table of the variable trials + blocks
		%>
		% ===================================================================
			if me.nVars == 0
				me.dataTable = table({'No task variables set!'}, 'VariableNames', {'Independent Variable'});
				return
			end
			outvals = me.outValues;
			data = cell(size(outvals,1),(size(outvals,2)*2)+3);
			a = 1;
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
				data{i,end-1} = me.outTrial{i};
				if i > a * me.minTrials
					a = a + 1;
				end
				data{i,end} = me.outBlock{a};
			end
			cnames = cell(1,me.nVars);
			for ii = 1:me.nVars
				cnames{ii} = [me.nVar(ii).name num2str(me.nVar(ii).stimulus,'-%i')];
			end
			cnames{end+1} = 'outIndex';
			for ii = 1:size(me.outMap,2)
				cnames{end+1} = ['Var' num2str(ii) 'Index'];
			end
			cnames{end+1} = 'Trial Factors';
			cnames{end+1} = 'Block Factors';
			me.dataTable = cell2table(data,'VariableNames',cnames);
		end
		
		% ===================================================================
		function makeLabels(me)
		%> @fn makeLabels
		%> @brief make labels for variables
		%>
		%>
		% ===================================================================
		if isempty(me.outIndex); return; end
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
		function resetTask(me)
		%> @fn resetTask
		%> @brief reset dynamic task properties
		%>
		%>
		% ===================================================================
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
			initialiseGenerator(me);
		end
		
		% ===================================================================
		function randomiseTimes(me)
		%> @fn randomiseTimes
		%> @brief randomise the time intervals
		%>
		%>
		% ===================================================================
			if ~me.taskInitialised;return;end
			me.isTimeNow = me.isTime;
			me.ibTimeNow = me.ibTime;
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
		
		% ===================================================================
		function checkBlockTrialVars(me)
		%> @fn checkBlockTrialVars
		%> @brief validate blockVar and trialVar
		%>
		% ===================================================================
		me.blockTemplate = struct('values',{{'none'}},'probability',[1],'comment','block level factor');
			me.trialTemplate = struct('values',{{'none'}},'probability',[1],'comment','trial level factor');
			if ~isfield(me.blockVar,'values'); me.blockVar = me.blockTemplate; end
			if ~isfield(me.blockVar,'probability') || length(me.blockVar.values) ~= length(me.blockVar.probability)
				me.blockVar.probability = repmat((1/length(me.blockVar.values)),1,length(me.blockVar.values));
				warning('---! TaskSequence.blockVar not properly formatted — it should be a structure with ''values'' and ''probabilitiy'' of the same length! N values = %i, probability = %.2f',length(me.blockVar.values),me.blockVar.probability)
			end
			if ~isfield(me.trialVar,'values'); me.trialVar = me.trialTemplate; end
			if ~isfield(me.trialVar,'probability') || length(me.trialVar.values)~=length(me.trialVar.probability)
				me.trialVar.probability = repmat((1/length(me.trialVar.values)),1,length(me.trialVar.values));
				warning('---! TaskSequence.trialVar not properly formatted — it should be a structure with ''values'' and ''probabilitiy'' of the same length! N values = %i, probability = %.2f',length(me.trialVar.values),me.trialVar.probability)
				me.trialVar = me.trialTemplate;
			end
		end
	end
	
	%=======================================================================
	methods (Static) %------------------STATIC METHODS
	%=======================================================================
		
		% ===================================================================
		function out=cellStruct(in)
		%> @fn cellStruct
		%> @brief make a matrix from a cell array
		%>
		%>
		% ===================================================================
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
% 		function lobj=loadobj(in)
		%> @fn loadobj
		%> @brief loadobj handler
		%>
		%> The problem is we use set.nVar to allow robust setting of
		%> variables, but set.nVar also gets called on loading and will mangle
		%> older saved protocols during load. We need to specify we are loading
		%> and use a conditional in set.nVar to do the right thing.
		% ===================================================================
% 			if ~isa(in,'taskSequence') && isstruct(in)
% 				fprintf('---> taskSequence loadobj: Rebuilding  structure...\n');
% 				lobj = taskSequence;
% 				lobj.isLoading = true;
% 				fni = fieldnames(in);
% 				fn = intersect(lobj.loadProperties,fni);
% 				for i=1:length(fn)
% 					lobj.(fn{i}) = in.(fn{i});
% 				end
% 			elseif isa(in,'taskSequence')
% 				%fprintf('--->  taskSequence loadobj: Loading taskSequence object...\n');
% 				in.currentState = []; %lets strip the old random streams
% 				in.oldStream = [];
% 				in.taskStream = [];
% 				lobj = in;
% 			else
% 				fprintf('--->  taskSequence loadobj: Loading taskSequence FAILED...\n');
% 			end
% 			lobj.isLoading = false;
% 		end
		
	end
	
end
