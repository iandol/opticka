classdef plxReader < optickaCore
	%TIMELOG Simple class used to store the timing data from an experiment
	%   timeLogger stores timing data for a taskrun and optionally graphs the
	%   result.
	
	properties
		verbose	= true
		file@char
		dir@char
		matfile@char
		cellmap@double
		startOffset@double = 0
	end
	
	properties (SetAccess = private, GetAccess = public)
		info@cell
		eventList@struct
		tsList@struct
		strobeList@struct
		meta@struct
		rE
	end
	
	properties (SetAccess = private, GetAccess = private)
		oldDir@char
		%> allowed properties passed to object upon construction
		allowedProperties@char = 'startOffset|file|matfile|dir|verbose'
	end
	
	%=======================================================================
	methods %------------------PUBLIC METHODS
	%=======================================================================

		% ===================================================================
		%> @brief Constructor
		%>
		%> @param varargin
		%> @return
		% ===================================================================
		function obj=plxReader(varargin)
			if nargin == 0; varargin.name = 'plxReader';end
			if nargin>0; obj.parseArgs(varargin,obj.allowedProperties); end
			if isempty(obj.name);obj.name = 'plxReader'; end
			if isempty(obj.file) || isempty(obj.dir)
				[obj.file, obj.dir] = uigetfile('*.plx','Load Plexon File');
			end
			if isempty(obj.matfile)
				obj.paths.oldDir = pwd;
				cd(obj.dir);
				[obj.matfile, ~] = uigetfile('*.mat','Load Behaviour MAT File');
				%cd(obj.paths.oldDir);
			end
		end
		
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function parse(obj)
			obj.paths.oldDir = pwd;
			cd(obj.dir);
			[obj.meta, obj.rE] = obj.loadMat(obj.matfile,obj.dir);
			generateInfo(obj);
			getSpikes(obj);
			getStrobes(obj);
			parseSpikes(obj);
			%disp(obj.info);
			%cd(obj.paths.oldDir);
		end
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function reparse(obj)
			obj.paths.oldDir = pwd;
			cd(obj.dir);
			%[obj.meta, obj.rE] = obj.loadMat(obj.matfile,obj.dir);
			generateInfo(obj);
			%getSpikes(obj);
			%getStrobes(obj);
			parseSpikes(obj);
			%disp(obj.info);
			%cd(obj.paths.oldDir);
			reparseInfo(obj);
		end
		
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function x = exportToRawSpikes(obj, var, firstunit, StartTrial, EndTrial, trialtime, modtime, cuttime)
			if ~isempty(obj.cellmap)
				raw = obj.tsList.tsParse{obj.cellmap(firstunit)};
			else
				raw = obj.tsList.tsParse{firstunit};
			end
			raw = raw.var{var};
			x.name = ['PLXVar.' num2str(var)];
			x.raw = raw;
			x.totaltrials = obj.strobeList.minRuns;
			x.nummods = 1;
			x.error = [];
			if StartTrial < 1 || StartTrial > EndTrial
				StartTrial = 1;
			end
			if EndTrial > x.totaltrials
				EndTrial = x.totaltrials;
			end
			x.numtrials = (EndTrial - StartTrial)+1;
			x.starttrial = StartTrial;
			x.endtrial =  EndTrial;
			x.startmod = 1;
			x.endmod = 1;
			x.maxtime = obj.strobeList.tMaxCorrect * 1e4;
			a = 1;
			for tr = x.starttrial:x.endtrial
				x.trial(a).basetime = raw.run(tr).basetime * 1e4; %convert from seconds to 0.1ms as that is what VS used
				x.trial(a).modtimes = raw.run(tr).basetime * 1e4;
				x.trial(a).mod{1} = raw.run(tr).spikes * 1e4;
				a=a+1;
			end
				
		end
		
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function generateInfo(obj)
			[OpenedFileName, Version, Freq, Comment, Trodalness,...
				NPW, PreThresh, SpikePeakV, SpikeADResBits,...
				SlowPeakV, SlowADResBits, Duration, DateTime] = plx_information(obj.file);
			obj.info = {};
			obj.info{1} = sprintf('PLX File : %s', OpenedFileName);
			obj.info{end+1} = sprintf('Behavioural File : %s', obj.matfile);
			obj.info{end+1} = sprintf('Behavioural File Comment : %s', obj.meta.comments);
			obj.info{end+1} = sprintf('Plexon File Comment : %s', Comment);
			obj.info{end+1} = sprintf('Version : %g', Version);
			obj.info{end+1} = sprintf('Frequency : %g Hz', Freq);
			obj.info{end+1} = sprintf('Plexon Date/Time : %s', num2str(DateTime));
			obj.info{end+1} = sprintf('Duration : %g seconds', Duration);
			obj.info{end+1} = sprintf('Num Pts Per Wave : %g', NPW);
			obj.info{end+1} = sprintf('Num Pts Pre-Threshold : %g', PreThresh);
			% some of the information is only filled if the plx file version is >102
			if ( Version > 102 )
				if ( Trodalness < 2 )
					obj.info{end+1} = sprintf('Data type : Single Electrode');
				elseif ( Trodalness == 2 )
					obj.info{end+1} = sprintf('Data type : Stereotrode');
				elseif ( Trodalness == 4 )
					obj.info{end+1} = sprintf('Data type : Tetrode');
				else
					obj.info{end+1} = sprintf('Data type : Unknown');
				end

				obj.info{end+1} = sprintf('Spike Peak Voltage (mV) : %g', SpikePeakV);
				obj.info{end+1} = sprintf('Spike A/D Resolution (bits) : %g', SpikeADResBits);
				obj.info{end+1} = sprintf('Slow A/D Peak Voltage (mV) : %g', SlowPeakV);
				obj.info{end+1} = sprintf('Slow A/D Resolution (bits) : %g', SlowADResBits);
			end
			obj.info = obj.info';
			obj.meta.info = obj.info;
		end
		
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function getStrobes(obj)
			tic
			[a,b,c] = plx_event_ts(obj.file,257);
			[~,b19] = plx_event_ts(obj.file,19);
			[~,b20] = plx_event_ts(obj.file,20);
			[~,b21] = plx_event_ts(obj.file,21);
			[~,b22] = plx_event_ts(obj.file,22);
			[d,e] = plx_event_names(obj.file);
			[f,g] = plx_event_chanmap(obj.file);
			if a > 0
				obj.strobeList = struct();
				obj.strobeList(1).n = a;
				obj.strobeList.startFix = b19;
				obj.strobeList.correct = b20;
				obj.strobeList.breakFix = b21;
				obj.strobeList.incorrect = b22;
				obj.strobeList.times = b;
				obj.strobeList.values = c;
				obj.strobeList.unique = unique(c);
				obj.strobeList.nVars = length(obj.strobeList.unique)-1;
				obj.strobeList.minRuns = Inf;
				obj.strobeList.maxRuns = 0;
				obj.strobeList.tMin = Inf;
				obj.strobeList.tMax = 0;
				obj.strobeList.tMinCorrect = Inf;
				obj.strobeList.tMaxCorrect = 0;
				for i = 1:obj.strobeList.nVars
					obj.strobeList.vars(i).name = obj.strobeList.unique(i);
					idx = find(obj.strobeList.values == obj.strobeList.unique(i));
					idxend = idx+1;
					while (length(idx) > length(idxend)) %prune incomplete trials
						idx = idx(1:end-1);
					end
					obj.strobeList.vars(i).nRepeats = length(idx);
					obj.strobeList.vars(i).index = idx;
					obj.strobeList.vars(i).t1 = obj.strobeList.times(idx);
					obj.strobeList.vars(i).t2 = obj.strobeList.times(idxend);
					obj.strobeList.vars(i).tDelta = obj.strobeList.vars(i).t2 - obj.strobeList.vars(i).t1;
					obj.strobeList.vars(i).tMin = min(obj.strobeList.vars(i).tDelta);
					obj.strobeList.vars(i).tMax = max(obj.strobeList.vars(i).tDelta);
					
					for nr = 1:obj.strobeList.vars(i).nRepeats
						tend = obj.strobeList.vars(i).t2(nr);
						tc = obj.strobeList.correct > tend-0.1 & obj.strobeList.correct < tend+0.1;
						tb = obj.strobeList.breakFix > tend-0.1 & obj.strobeList.breakFix < tend+0.1;
						ti = obj.strobeList.incorrect > tend-0.1 & obj.strobeList.incorrect < tend+0.1;
						if max(tc) == 1
							obj.strobeList.vars(i).responseIndex(nr,1) = true;
							obj.strobeList.vars(i).responseIndex(nr,2) = false;
							obj.strobeList.vars(i).responseIndex(nr,3) = false;
						elseif max(tb) == 1
							obj.strobeList.vars(i).responseIndex(nr,1) = false;
							obj.strobeList.vars(i).responseIndex(nr,2) = true;
							obj.strobeList.vars(i).responseIndex(nr,3) = false;
						elseif max(ti) == 1
							obj.strobeList.vars(i).responseIndex(nr,1) = false;
							obj.strobeList.vars(i).responseIndex(nr,2) = false;
							obj.strobeList.vars(i).responseIndex(nr,3) = true;
						else
							error('Problem Finding Correct Strobes!!!!! plxReader')
						end
					end
					obj.strobeList.vars(i).nCorrect = sum(obj.strobeList.vars(i).responseIndex(:,1));
					obj.strobeList.vars(i).nBreakFix = sum(obj.strobeList.vars(i).responseIndex(:,2));
					obj.strobeList.vars(i).nIncorrect = sum(obj.strobeList.vars(i).responseIndex(:,3));
					
					if obj.strobeList.minRuns > obj.strobeList.vars(i).nCorrect
						obj.strobeList.minRuns = obj.strobeList.vars(i).nCorrect;
					end
					if obj.strobeList.maxRuns < obj.strobeList.vars(i).nCorrect
						obj.strobeList.maxRuns = obj.strobeList.vars(i).nCorrect;
					end
					
					if obj.strobeList.tMin > obj.strobeList.vars(i).tMin
						obj.strobeList.tMin = obj.strobeList.vars(i).tMin;
					end
					if obj.strobeList.tMax < obj.strobeList.vars(i).tMax
						obj.strobeList.tMax = obj.strobeList.vars(i).tMax;
					end
					
					
					obj.strobeList.vars(i).t1correct = obj.strobeList.vars(i).t1(obj.strobeList.vars(i).responseIndex(:,1));
					obj.strobeList.vars(i).t2correct = obj.strobeList.vars(i).t2(obj.strobeList.vars(i).responseIndex(:,1));
					obj.strobeList.vars(i).tDeltacorrect = obj.strobeList.vars(i).tDelta(obj.strobeList.vars(i).responseIndex(:,1));
					obj.strobeList.vars(i).tMinCorrect = min(obj.strobeList.vars(i).tDeltacorrect);
					obj.strobeList.vars(i).tMaxCorrect = max(obj.strobeList.vars(i).tDeltacorrect);
					if obj.strobeList.tMinCorrect > obj.strobeList.vars(i).tMinCorrect
						obj.strobeList.tMinCorrect = obj.strobeList.vars(i).tMinCorrect;
					end
					if obj.strobeList.tMaxCorrect < obj.strobeList.vars(i).tMaxCorrect
						obj.strobeList.tMaxCorrect = obj.strobeList.vars(i).tMaxCorrect;
					end
					
					obj.strobeList.vars(i).t1breakfix = obj.strobeList.vars(i).t1(obj.strobeList.vars(i).responseIndex(:,2));
					obj.strobeList.vars(i).t2breakfix = obj.strobeList.vars(i).t2(obj.strobeList.vars(i).responseIndex(:,2));
					obj.strobeList.vars(i).tDeltabreakfix = obj.strobeList.vars(i).tDelta(obj.strobeList.vars(i).responseIndex(:,2));
					
					obj.strobeList.vars(i).t1incorrect = obj.strobeList.vars(i).t1(obj.strobeList.vars(i).responseIndex(:,3));
					obj.strobeList.vars(i).t2incorrect = obj.strobeList.vars(i).t2(obj.strobeList.vars(i).responseIndex(:,3));
					obj.strobeList.vars(i).tDeltaincorrect = obj.strobeList.vars(i).tDelta(obj.strobeList.vars(i).responseIndex(:,3));
					
				end
				
				obj.info{end+1} = sprintf('Number of Variables : %g', obj.strobeList.nVars);
				obj.info{end+1} = sprintf('Total # Correct Trials :  %g', length(obj.strobeList.correct));
				obj.info{end+1} = sprintf('Total # BreakFix Trials :  %g', length(obj.strobeList.breakFix));
				obj.info{end+1} = sprintf('Total # Incorrect Trials :  %g', length(obj.strobeList.incorrect));
				obj.info{end+1} = sprintf('Minimum # of Trials :  %g', obj.strobeList.minRuns);
				obj.info{end+1} = sprintf('Maximum # of Trials :  %g', obj.strobeList.maxRuns);
				obj.info{end+1} = sprintf('Shortest Trial Time (all/correct):  %g / %g s', obj.strobeList.tMin,obj.strobeList.tMinCorrect);
				obj.info{end+1} = sprintf('Longest Trial Time (all/correct):  %g / %g s', obj.strobeList.tMax,obj.strobeList.tMaxCorrect);
				
				obj.meta.modtime = floor(obj.strobeList.tMaxCorrect * 10000);
				obj.meta.trialtime = floor(obj.strobeList.tMaxCorrect * 10000);
				m = [obj.rE.task.outIndex obj.rE.task.outMap obj.rE.task.outValues];
				m = m(1:obj.strobeList.nVars,:);
				[~,ix] = sort(m(:,1),1);
				m = m(ix,:);
				obj.meta.matrix = m;
				
			else
				obj.strobeList = struct();
			end
			fprintf('Loading all events took %s seconds\n',toc)
		end
		
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function getSpikes(obj)
			tic
			[tscounts, wfcounts, evcounts, slowcounts] = plx_info(obj.file,1);
			[nunits1, nchannels1] = size( tscounts );
			obj.tsList = struct();
			obj.tsList(1).chMap = find(sum(tscounts) > 0);
			obj.tsList(1).chMap = obj.tsList(1).chMap - 1; %fix the index as plx_info add 1 to channels
			obj.tsList.unitMap = find(sum(tscounts,2) > 0);
			obj.tsList(1).unitMap = obj.tsList(1).unitMap' - 1; %fix the index as plx_info add 1 to channels
			obj.tsList.nCh = length(obj.tsList.chMap);
			obj.tsList.nUnit = length(obj.tsList.unitMap);
			obj.info{end+1} = ['Number of Active channels : ' num2str(obj.tsList.nCh)];
			obj.info{end+1} = ['Number of Active units : ' num2str(obj.tsList.nUnit)];
			obj.info{end+1} = ['Channel list : ' num2str(obj.tsList.chMap)];
			obj.info{end+1} = ['Unit list (0=unsorted) : ' num2str(obj.tsList.unitMap)];
			obj.tsList.ts = cell(obj.tsList.nUnit, obj.tsList.nCh); 
			obj.tsList.tsN = obj.tsList.ts;
			obj.tsList.tsParse = obj.tsList.ts;
			for ich = 1:obj.tsList.nCh
				for iunit = 1:obj.tsList.nUnit
					[obj.tsList.tsN{iunit,ich}, obj.tsList.ts{iunit,ich}] = plx_ts(obj.file, obj.tsList.chMap(ich) , obj.tsList.unitMap(iunit) );
				end
			end
			fprintf('Loading all spikes took %s seconds\n',toc)
		end
		
		
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function parseSpikes(obj)
			tic
			for ps = 1:(obj.tsList.nCh * obj.tsList.nUnit)
				spikes = obj.tsList.ts{ps};
				obj.tsList.tsParse{ps}.var = cell(obj.strobeList.nVars,1);
				for nv = 1:obj.strobeList.nVars
					var = obj.strobeList.vars(nv);
					obj.tsList.tsParse{ps}.var{nv}.run = struct();
					for nc = 1:var.nCorrect
						idx =  spikes >= var.t1correct(nc)+obj.startOffset & spikes <= var.t2correct(nc);
						obj.tsList.tsParse{ps}.var{nv}.run(nc).basetime = var.t1correct(nc) + obj.startOffset;
						obj.tsList.tsParse{ps}.var{nv}.run(nc).modtimes = var.t1correct(nc) + obj.startOffset;
						obj.tsList.tsParse{ps}.var{nv}.run(nc).spikes = spikes(idx);
					end					
				end
			end
			if obj.startOffset ~= 0
				obj.info{end+1} = sprintf('START OFFSET ACTIVE : %g', obj.startOffset);
			end
			fprintf('Parsing all spikes took %s seconds\n',toc)
		end
		
	end %---END PUBLIC METHODS---%
	
	%=======================================================================
	methods ( Static = true) %-------STATIC METHODS-----%
	%=======================================================================
	
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function [meta, rE] = loadMat(fn,pn)
			if isempty(fn)
				[fn, pn] = uigetfile('*.mat','Load Behaviour MAT File');
				cd(pn);
			end
			tic
			load(fn);
			rE = obj;
			meta.filename = [pn fn];
			meta.protocol = 'Figure Ground';
			meta.description = 'Figure Ground';
			meta.comments = rE.comment;
			meta.date = rE.savePrefix;
			meta.numvars = rE.task.nVars;
			for i=1:rE.task.nVars
				meta.var{i}.title = rE.task.nVar(i).name;
				meta.var{i}.nvalues = length(rE.task.nVar(i).values);
				meta.var{i}.values = rE.task.nVar(i).values;
				meta.var{i}.range = length(rE.task.nVar(i).values);
			end
			meta.repeats = rE.task.nBlocks;
			meta.cycles = 1;
			meta.modtime = 500;
			meta.trialtime = 500;
			meta.matrix = [];
			fprintf('Parsing Behavioural files took %s seconds\n',toc)
		end
	end
	
	
	%=======================================================================
	methods ( Access = private ) %-------PRIVATE METHODS-----%
	%=======================================================================
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function reparseInfo(obj)
			
			obj.info{end+1} = sprintf('Number of Variables : %g', obj.strobeList.nVars);
			obj.info{end+1} = sprintf('Total # Correct Trials :  %g', length(obj.strobeList.correct));
			obj.info{end+1} = sprintf('Total # BreakFix Trials :  %g', length(obj.strobeList.breakFix));
			obj.info{end+1} = sprintf('Total # Incorrect Trials :  %g', length(obj.strobeList.incorrect));
			obj.info{end+1} = sprintf('Minimum # of Trials :  %g', obj.strobeList.minRuns);
			obj.info{end+1} = sprintf('Maximum # of Trials :  %g', obj.strobeList.maxRuns);
			obj.info{end+1} = sprintf('Shortest Trial Time (all/correct):  %g / %g s', obj.strobeList.tMin,obj.strobeList.tMinCorrect);
			obj.info{end+1} = sprintf('Longest Trial Time (all/correct):  %g / %g s', obj.strobeList.tMax,obj.strobeList.tMaxCorrect);
			obj.info{end+1} = ['Number of Active channels : ' num2str(obj.tsList.nCh)];
			obj.info{end+1} = ['Number of Active units : ' num2str(obj.tsList.nUnit)];
			obj.info{end+1} = ['Channel list : ' num2str(obj.tsList.chMap)];
			obj.info{end+1} = ['Unit list (0=unsorted) : ' num2str(obj.tsList.unitMap)];

		end
	end
	
end

