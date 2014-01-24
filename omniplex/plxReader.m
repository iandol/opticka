classdef plxReader < optickaCore
%PLXREADER Reads in Plexon .plx and .pl2 files along with metadata and
%eyelink data. Parses the trial event structure.
	
	properties
		file@char
		dir@char
		matfile@char
		matdir@char
		edffile@char
		cellmap@double
		startOffset@double = 0
		verbose	= true
		doLFP@logical = false 
	end
	
	properties (SetAccess = private, GetAccess = public)
		info@cell
		eventList@struct
		tsList@struct
		LFPs@struct
		meta@struct
		rE@runExperiment
		eA@eyelinkAnalysis
		isPL2@logical = false
		isEDF@logical = false
		pl2@struct
	end
	
	properties (SetAccess = private, GetAccess = private)
		oldDir@char
		%> allowed properties passed to object upon construction
		allowedProperties@char = 'file|dir|matfile|matdir|edffile|startOffset|cellmap|verbose|doLFP'
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
				[obj.file, obj.dir] = uigetfile({'*.plx;*.pl2';'PlexonFiles'},'Load Plexon File');
				obj.paths.oldDir = pwd;
				cd(obj.dir);
			end
			if isempty(obj.matfile)
				[obj.matfile, obj.matdir] = uigetfile('*.mat','Load Behaviour MAT File');
			end
			if isempty(obj.edffile)
				[an, ~] = uigetfile('*.edf','Load Eyelink EDF File');
				if ischar(an)
					obj.edffile = an;
					obj.isEDF = true;
				else
					obj.edffile = '';
					obj.isEDF = false;
				end
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
			if exist(obj.matdir','dir')
				[obj.meta, obj.rE] = obj.loadMat(obj.matfile,obj.matdir);
			else
				[obj.meta, obj.rE] = obj.loadMat(obj.matfile,obj.dir);
			end
			generateInfo(obj);
			getSpikes(obj);
			getEvents(obj);
			parseSpikes(obj);
			if obj.isEDF == true
				loadEDF(obj);
			end
			if obj.doLFP == true
				loadLFPs(obj)
				plotLFPs(obj)
			end
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
			%loadEDF(obj);
			generateInfo(obj);
			%getSpikes(obj);
			getEvents(obj);
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
		function parseLFPs(obj)
			loadLFPs(obj)
			plotLFPs(obj)
		end
		
		% ===================================================================
		%> @brief exportToRawSpikes 
		%>
		%> @param
		%> @return x spike data structure for spikes.m to read.
		% ===================================================================
		function x = exportToRawSpikes(obj, var, firstunit, StartTrial, EndTrial, trialtime, modtime, cuttime)
			if ~isempty(obj.cellmap)
				fprintf('Extracting Var=%g for Cell %g from PLX unit %g\n', var, firstunit, obj.cellmap(firstunit));
				raw = obj.tsList.tsParse{obj.cellmap(firstunit)};
			else
				fprintf('Extracting Var=%g for Cell %g from PLX unit %g \n', var, firstunit, firstunit);
				raw = obj.tsList.tsParse{firstunit};
			end
			if var > length(raw.var)
				errordlg('This Plexon File seems to be Incomplete, check filesize...')
			end
			raw = raw.var{var};
			v = num2str(obj.meta.matrix(var,:));
			v = regexprep(v,'\s+',' ');
			x.name = ['PLX#' num2str(var) '|' v];
			x.raw = raw;
			x.totaltrials = obj.eventList.minRuns;
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
			x.conversion = 1e4;
			x.maxtime = obj.eventList.tMaxCorrect * x.conversion;
			a = 1;
			for tr = x.starttrial:x.endtrial
				x.trial(a).basetime = round(raw.run(tr).basetime * x.conversion); %convert from seconds to 0.1ms as that is what VS used
				x.trial(a).modtimes = 0;
				x.trial(a).mod{1} = round(raw.run(tr).spikes * x.conversion) - x.trial(a).basetime;
				a=a+1;
			end
			x.isPLX = true;
			x.tDelta = obj.eventList.vars(var).tDeltacorrect(x.starttrial:x.endtrial);
			x.startOffset = obj.startOffset;
			
		end
		
	end %---END PUBLIC METHODS---%
	
	%=======================================================================
	methods ( Static = true) %-------STATIC METHODS-----%
	%=======================================================================
	
		% ===================================================================
		%> @brief 
		%> This needs to be static as it may load data called "obj" which
		%> will conflict with the obj object in the class.
		%> @param
		%> @return
		% ===================================================================
		function [meta, rE] = loadMat(fn,pn)
			oldd=pwd;
			cd(pn);
			tic
			load(fn);
			if ~exist('rE','var') && exist('obj','var')
				rE = obj;
			end
			if ~isa(rE,'runExperiment')
				error('The behavioural file doesn''t contain a runExperiment object!!!');
			end
			if isempty(rE.tS) && exist('tS','var'); rE.tS = tS; end
			meta.filename = [pn fn];
			if ~isfield(tS,'name'); meta.protocol = 'FigureGround';	meta.description = 'FigureGround'; else
				meta.protocol = tS.name; meta.description = tS.name; end
			meta.comments = rE.comment;
			meta.date = rE.savePrefix;
			meta.numvars = rE.task.nVars;
			for i=1:rE.task.nVars
				meta.var{i}.title = rE.task.nVar(i).name;
				meta.var{i}.nvalues = length(rE.task.nVar(i).values);
				meta.var{i}.range = meta.var{i}.nvalues;
				if iscell(rE.task.nVar(i).values)
					vals = rE.task.nVar(i).values;
					num = 1:meta.var{i}.range;
					meta.var{i}.values = num;
					meta.var{i}.keystring = [];
					for jj = 1:meta.var{i}.range
						k = vals{jj};
						meta.var{i}.key{jj} = num2str(k);
						meta.var{i}.keystring = {meta.var{i}.keystring meta.var{i}.key{jj}};
					end
				else
					meta.var{i}.values = rE.task.nVar(i).values;
					meta.var{i}.key = '';
				end
			end
			meta.repeats = rE.task.nBlocks;
			meta.cycles = 1;
			meta.modtime = 500;
			meta.trialtime = 500;
			meta.matrix = [];
			fprintf('Parsing Behavioural files took %g ms\n',round(toc*1000))
			cd(oldd);
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
		function LFPs = loadLFPs(obj)
			tic
			[~, names] = plx_adchan_names(obj.file);
			[~, map] = plx_adchan_samplecounts(obj.file);
			[~, raw] = plx_ad_chanmap(obj.file);
			names = cellstr(names);
			idx = find(map > 0);
			aa=1;
			LFPs = [];
			for j = 1:length(idx)
				cname = names{idx(j)};
				if ~isempty(regexp(cname,'FP', 'once'))
					LFPs(aa).name = cname;
					LFPs(aa).index = raw(idx(j));
					LFPs(aa).count = map(idx(j));
					LFPs(aa).reparse = false;
					LFPs(aa).vars = struct([]); %#ok<*AGROW>
					aa = aa + 1;
				end
			end
			
			for j = 1:length(LFPs)
				[adfreq, ~, ts, fn, ad] = plx_ad_v(obj.file, LFPs(j).index);

				tbase = 1 / adfreq;
				
				LFPs(j).recordingFrequency = adfreq;
				LFPs(j).timebase = tbase;
				LFPs(j).totalTimeStamps = ts;
				LFPs(j).totalDataPoints = fn;			
				
				if length(fn) == 2 %1 gap, choose last data block
					data = ad(fn(1)+1:end);
					time = ts(end) : tbase : (ts(end)+(tbase*(fn(end)-1)));
					time = time(1:length(data));
					LFPs(j).usedtimeStamp = ts(end);
				elseif length(fn) == 1 %no gaps
					data = ad(fn+1:end);
					time = ts : tbase : (ts+(tbase*fn-1));
					time = time(1:length(data));
					LFPs(j).usedtimeStamp = ts;
				else
					return;
				end
				LFPs(j).data = data;
				LFPs(j).time = time;
				LFPs(j).eventSample = round(LFPs(j).usedtimeStamp * 40e3);
				LFPs(j).sample = round(LFPs(j).usedtimeStamp * LFPs(j).recordingFrequency);
				
				LFPs(j).nVars = obj.eventList.nVars;
				
				for k = 1:LFPs(j).nVars
					times = [obj.eventList.vars(k).t1correct,obj.eventList.vars(k).t2correct];
					LFPs(j).vars(k).times = times;
					LFPs(j).vars(k).nTrials = length(times);
					minL = Inf;
					maxL = 0;
					window = 0.2;
					winsteps = window/1e-3;
					for l = 1:LFPs(j).vars(k).nTrials
						[idx1, val1, dlta1] = obj.findNearest(time,times(l,1));
						[idx2, val2, dlta2] = obj.findNearest(time,times(l,2));
						LFPs(j).vars(k).trial(l).startTime = val1;
						LFPs(j).vars(k).trial(l).startIndex = idx1;
						LFPs(j).vars(k).trial(l).endTime = val2;
						LFPs(j).vars(k).trial(l).endIndex = idx2;
						LFPs(j).vars(k).trial(l).startDelta = dlta1;
						LFPs(j).vars(k).trial(l).endDelta = dlta2;
						LFPs(j).vars(k).trial(l).data = data(idx1-winsteps:idx1+winsteps);
						LFPs(j).vars(k).trial(l).time = [-window:1e-3:window]';
						LFPs(j).vars(k).trial(l).abstime = LFPs(j).vars(k).trial(l).time + (val1-window);
						minL = min([length(LFPs(j).vars(k).trial(l).data) minL]);
						maxL = max([length(LFPs(j).vars(k).trial(l).data) maxL]);
					end
					LFPs(j).vars(k).time = LFPs(j).vars(k).trial(1).time;
					LFPs(j).vars(k).alldata = [LFPs(j).vars(k).trial(:).data];
					[LFPs(j).vars(k).average, LFPs(j).vars(k).error] = stderr(LFPs(j).vars(k).alldata');
					LFPs(j).vars(k).minL = minL;
					LFPs(j).vars(k).maxL = maxL;
				end
			end
			
			fprintf('Parsing LFPs took %g ms\n',round(toc*1000));
			
			cuttrials = '{';	
			for i = 1:LFPs(j).nVars
				cuttrials = [cuttrials ''''','];
			end
			cuttrials = cuttrials(1:end-1);
			cuttrials = [cuttrials '}'];
			
			options.Resize='on';
			options.WindowStyle='normal';
			options.Interpreter='tex';
			prompt = {'Choose PLX variables to merge (ground):','Choose PLX variables to merge (figure):','Choose PLX variables to merge (figure 2):','Enter Trials to exclude'};
			dlg_title = ['REPARSE ' num2str(LFPs(1).nVars) ' DATA VARIABLES'];
			num_lines = [1 120];
			def = {'1 2 3 4 5 6','7 8','',cuttrials};
			answer = inputdlg(prompt,dlg_title,num_lines,def,options);
			drawnow;
			map = cell(1,3);
			if isempty(answer)
				map{1} = []; map{2}=[]; map{3}=[]; cuttrials = {''};
			else
				map{1} = str2num(answer{1}); map{2} = str2num(answer{2}); map{3} = str2num(answer{3}); 
				if ~isempty(answer{4}) && strcmpi(answer{4}(1),'{')
					cuttrials = eval(answer{4});
				else
					cuttrials = {''};
				end
			end
			
			if ~isempty(map{1}) && ~isempty(map{2})
				tic
				for j = 1:length(LFPs)
					
					vars = LFPs(j).vars;
					nvars = vars(1);
					nvars(1).times = [];
					nvars(1).nTrials = 0;
					nvars(1).trial = [];
					nvars(1).time = [];
					nvars(1).alldata = [];
					nvars(1).average = [];
					nvars(1).error = [];
					nvars(1).minL = [];
					nvars(1).maxL = [];
					vartemplate = nvars(1);
					
					if isempty(map{3})
						repn=[1 2];
						nvars(2) = vartemplate;
					else
						repn = [1 2 3];
						nvars(2) = vartemplate;
						nvars(3) = vartemplate;
					end
					
					for n = repn

						for k = 1:length(map{n})
							thisVar = map{n}(k);
							if (length(cuttrials) >= thisVar) && ~isempty(cuttrials{thisVar}) %trial removal
								cut = cuttrials{thisVar};
								vars(thisVar).times(cut,:) = [];
								vars(thisVar).alldata(:,cut) = [];
								vars(thisVar).trial(cut) = [];
								vars(thisVar).nTrials = length(vars(thisVar).trial);
							end
							nvars(n).times = [nvars(n).times;vars(thisVar).times];
							nvars(n).nTrials = nvars(n).nTrials + vars(thisVar).nTrials;
							nvars(n).trial = [nvars(n).trial, vars(thisVar).trial];
							nvars(n).alldata = [nvars(n).alldata, vars(thisVar).alldata];
						end
						nvars(n).time = vars(1).time;
						[nvars(n).average, nvars(n).error] = stderr(nvars(n).alldata','CIMEAN');
						nvars(n).minL = vars(1).minL;
						nvars(n).maxL = vars(1).maxL;
					
					end
					
					LFPs(j).oldvars = LFPs(j).vars;
					LFPs(j).vars = nvars;
					LFPs(j).reparse = true;
				end
				fprintf('Reparsing LFP variables took %g ms\n',round(toc*1000));
			end
			
			if ~isempty(LFPs(1).vars)
				obj.LFPs = LFPs;
			end	
		end

		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function plotLFPs(obj)
			LFPs = obj.LFPs;
			if isempty(LFPs);
				return
			end
			
			figure;figpos(1,[2000 1000]);set(gcf,'Color',[1 1 1]);
			title(['RAW LFP & EVENT PLOT: File:' obj.file ' | Channel:' LFPs(1).name ' | LFP: All']);
			xlabel('Time (s)');
 			ylabel('LFP Raw Amplitude (mV)');
			hold on
			for j = 1:length(LFPs)
				h(j)=plot(LFPs(j).time, LFPs(j).data);
				name{j} = ['LFP ' num2str(j)];
				[av,sd] = stderr(LFPs(j).data,'SD');
				line([LFPs(j).time(1) LFPs(j).time(end)],[av-(2*sd) av-(2*sd)],'Color',get(h(j),'Color'),'LineWidth',2);
				line([LFPs(j).time(1) LFPs(j).time(end)],[av+(2*sd) av+(2*sd)],'Color',get(h(j),'Color'),'LineWidth',2);
			end
			axis([0 30 -.5 .5])
			legend(h,name,'Location','NorthWest')
			for j = 1:obj.eventList.nVars
				color = rand(1,3);
				var = obj.eventList.vars(j);
				for k = 1:length(var.t1correct)
					line([var.t1correct(k) var.t1correct(k)],[-.4 .4],'Color',color);
					line([var.t2correct(k) var.t2correct(k)],[-.4 .4],'Color',color);
					text(var.t1correct(k),.4,['VAR:' num2str(j) ' TRL:' num2str(k)]);
				end
			end
			hold off
			pan xon
			
			for j = 1:length(LFPs(1).vars)
				figure;figpos(1,[1000 1000]);set(gcf,'Color',[1 1 1]);
				title(['LFP & EVENT PLOT: File:' obj.file ' | Channel:' LFPs(1).name ' | PLXVar:' num2str(j)]);
				xlabel('Time (s)');
 				ylabel('LFP Raw Amplitude (mV)');
				hold on
				plot(LFPs(1).vars(j).time, LFPs(1).vars(j).alldata);
				areabar(LFPs(1).vars(j).time, LFPs(1).vars(j).average,LFPs(1).vars(j).error,[0.7 0.7 0.7],0.7,'k-o','MarkerFaceColor',[0 0 0],'LineWidth',2);
				hold off
				axis([-0.1 0.2 -inf inf])
			end
			
			if LFPs(1).reparse == true;
				for j = 1: length(LFPs)
					figure;figpos(1,[1000 1000]);set(gcf,'Color',[1 1 1]);
					title(['FIGURE vs. GROUND Reparse: File:' obj.file ' | Channel:' LFPs(j).name ' | LFP:' num2str(j)]);
					xlabel('Time (s)');
					ylabel('LFP Raw Amplitude (mV)');
					hold on
					areabar(LFPs(j).vars(1).time, LFPs(j).vars(1).average,LFPs(j).vars(1).error,[0.7 0.7 0.7],0.6,'k-o','MarkerFaceColor',[0 0 0],'LineWidth',2);
					areabar(LFPs(j).vars(2).time, LFPs(j).vars(2).average,LFPs(j).vars(2).error,[0.7 0.5 0.5],0.6,'r-o','MarkerFaceColor',[1 0 0],'LineWidth',2);
					if length(LFPs(j).vars)>2
						areabar(LFPs(j).vars(3).time, LFPs(j).vars(3).average,LFPs(j).vars(3).error,[0.5 0.5 0.7],0.6,'b-o','MarkerFaceColor',[0 0 1],'LineWidth',2);
						legend('95% CI','Ground','95% CI','Figure','95% CI','Figure 2');
					else
						legend('95% CI','Ground','95% CI','Figure');
					end
					hold off
					axis([-0.1 0.2 -inf inf]);
				end
			end
		end
	
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function loadEDF(obj,pn)
			if ~exist('pn','var')
				if exist(obj.matdir,'dir')
					pn = obj.matdir;
				else
					pn = obj.dir;
				end
			end
			oldd=pwd;
			cd(pn);
			if exist(obj.edffile,'file')
				if ~isempty(obj.eA) && isa(obj.eA,'eyelinkAnalysis')
					obj.eA.file = obj.edffile;
					obj.eA.dir = pn;
				else
					in = struct('file',obj.edffile,'dir',pn);
					obj.eA = eyelinkAnalysis(in);
				end
				if isa(obj.rE.screen,'screenManager')
					obj.eA.pixelsPerCm = obj.rE.screen.pixelsPerCm;
					obj.eA.distance = obj.rE.screen.distance;
					obj.eA.xCenter = obj.rE.screen.xCenter;
					obj.eA.yCenter = obj.rE.screen.yCenter;
				end
				if isstruct(obj.rE.tS)
					obj.eA.tS = obj.rE.tS;
				end
				obj.eA.varList = obj.eventList.varOrderCorrect;
				load(obj.eA);
				parse(obj.eA);				
			end
			cd(oldd)
		end
			
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function generateInfo(obj)
			checkPL2(obj);
			[OpenedFileName, Version, Freq, Comment, Trodalness,...
				NPW, PreThresh, SpikePeakV, SpikeADResBits,...
				SlowPeakV, SlowADResBits, Duration, DateTime] = plx_information(obj.file);
			if exist('plx_mexplex_version','file')
				sdkversion = plx_mexplex_version();
			else
				sdkversion = -1;
			end
			
			obj.info = {};
			if obj.isPL2
				obj.pl2 = PL2GetFileIndex(obj.file);
				obj.info{1} = sprintf('PL2 File : %s', OpenedFileName);
				obj.info{end+1} = sprintf('\tPL2 File Length : %d', obj.pl2.FileLength);
				obj.info{end+1} = sprintf('\tPL2 Creator : %s %s', obj.pl2.CreatorSoftwareName, obj.pl2.CreatorSoftwareVersion);
			else
				obj.info{1} = sprintf('PLX File : %s', OpenedFileName);
			end
			obj.info{end+1} = sprintf('Behavioural File : %s', obj.matfile);
			obj.info{end+1} = ' ';
			obj.info{end+1} = sprintf('Behavioural File Comment : %s', obj.meta.comments);
			obj.info{end+1} = ' ';
			obj.info{end+1} = sprintf('Plexon File Comment : %s', Comment);
			obj.info{end+1} = sprintf('Version : %g', Version);
			obj.info{end+1} = sprintf('SDK Version : %g', sdkversion);
			obj.info{end+1} = sprintf('Frequency : %g Hz', Freq);
			obj.info{end+1} = sprintf('Plexon Date/Time : %s', num2str(DateTime));
			obj.info{end+1} = sprintf('Duration : %g seconds', Duration);
			obj.info{end+1} = sprintf('Num Pts Per Wave : %g', NPW);
			obj.info{end+1} = sprintf('Num Pts Pre-Threshold : %g', PreThresh);
			% some of the information is only filled if the plx file version is >102
			if exist('Trodalness','var')
				Trodalness = max(Trodalness);
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
			obj.info{end+1} = ' ';
			if isa(obj.rE,'runExperiment')
				rE = obj.rE; %#ok<*PROP>
				obj.info{end+1} = sprintf('# of Stimulus Variables : %g', rE.task.nVars);
				obj.info{end+1} = sprintf('Total # of Variable Values: %g', rE.task.minBlocks);
				obj.info{end+1} = sprintf('Random Seed : %g', rE.task.randomSeed);
				names = '';
				vals = '';
				for i = 1:rE.task.nVars
					names = [names ' || ' rE.task.nVar(i).name];
					if iscell(rE.task.nVar(i).values)
						val = '';
						for jj = 1:length(rE.task.nVar(i).values)
							v=num2str(rE.task.nVar(i).values{jj});
							v=regexprep(v,'\s+',' ');
							val = [val v '/'];
						end
						vals = [vals ' || ' val];
					else
						vals = [vals ' || ' num2str(rE.task.nVar(i).values)];
					end
				end
				obj.info{end+1} = sprintf('Variable Names : %s', names(4:end));
				obj.info{end+1} = sprintf('Variable Values : %s', vals(4:end));
				names = '';
				for i = 1:rE.stimuli.n
					names = [names ' | ' rE.stimuli{i}.name ':' rE.stimuli{i}.family];
				end
				obj.info{end+1} = sprintf('Stimulus Names : %s', names(4:end));
			end
			obj.info{end+1} = ' ';
			obj.info = obj.info';
			obj.meta.info = obj.info;
		end
		
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function getEvents(obj)
			tic
			[~,eventNames] = plx_event_names(obj.file);
			[~,eventIndex] = plx_event_chanmap(obj.file);
			eventNames = cellstr(eventNames);
			idx = strcmpi(eventNames,'Strobed');
			[a,b,c] = plx_event_ts(obj.file,eventIndex(idx)); %257 is the strobed word channel
			idx = find(c < 1);
			if ~isempty(idx)
				c(idx)=[];
				b(idx) = [];
			end
			idx = find(c > obj.rE.task.minBlocks & c < 32700);
			if ~isempty(idx)
				c(idx)=[];
				b(idx) = [];
			end
			if c(end) < 32700 %prune a trial at the end if it is not a stopstrobe!
				a = a - 1;
				c(end)=[];
				b(end) = [];
			end
			idx = strcmpi(eventNames, 'Start');
			[~,start] = plx_event_ts(obj.file,eventIndex(idx)); %currently 19 is fix start
			idx = strcmpi(eventNames, 'Stop');
			[~,stop] = plx_event_ts(obj.file,eventIndex(idx)); %currently 19 is fix start
			idx = strcmpi(eventNames, 'EVT19');
			[~,b19] = plx_event_ts(obj.file,eventIndex(idx)); %currently 19 is fix start
			idx = strcmpi(eventNames, 'EVT20');
			[~,b20] = plx_event_ts(obj.file,eventIndex(idx)); %20 is correct
			idx = strcmpi(eventNames, 'EVT21');
			[~,b21] = plx_event_ts(obj.file,eventIndex(idx));
			idx = strcmpi(eventNames, 'EVT22');
			[~,b22] = plx_event_ts(obj.file,eventIndex(idx));
			if a > 0
				obj.eventList = struct();
				obj.eventList(1).n = a;
				obj.eventList.eventNames = eventNames;
				obj.eventList.eventIndex = eventIndex;
				obj.eventList.start = start;
				obj.eventList.stop = stop;
				obj.eventList.startFix = b19;
				obj.eventList.correct = b20;
				obj.eventList.breakFix = b21;
				obj.eventList.incorrect = b22;
				obj.eventList.times = b;
				obj.eventList.values = c;
				obj.eventList.varOrder = obj.eventList.values(obj.eventList.values<32000);
				obj.eventList.varOrderCorrect = zeros(length(obj.eventList.correct),1);
				obj.eventList.unique = unique(c);
				obj.eventList.nVars = length(obj.eventList.unique)-1;
				obj.eventList.minRuns = Inf;
				obj.eventList.maxRuns = 0;
				obj.eventList.tMin = Inf;
				obj.eventList.tMax = 0;
				obj.eventList.tMinCorrect = Inf;
				obj.eventList.tMaxCorrect = 0;
				
				for i = 1:obj.eventList.nVars
					obj.eventList.vars(i).name = obj.eventList.unique(i);
					idx = find(obj.eventList.values == obj.eventList.unique(i));
					idxend = idx+1;
					while (length(idx) > length(idxend)) %prune incomplete trials
						idx = idx(1:end-1);
					end
					obj.eventList.vars(i).nRepeats = length(idx);
					obj.eventList.vars(i).index = idx;
					obj.eventList.vars(i).t1 = obj.eventList.times(idx);
					obj.eventList.vars(i).t2 = obj.eventList.times(idxend);
					obj.eventList.vars(i).tDelta = obj.eventList.vars(i).t2 - obj.eventList.vars(i).t1;
					obj.eventList.vars(i).tMin = min(obj.eventList.vars(i).tDelta);
					obj.eventList.vars(i).tMax = max(obj.eventList.vars(i).tDelta);				
					for nr = 1:obj.eventList.vars(i).nRepeats
						tend = obj.eventList.vars(i).t2(nr);
						tc = obj.eventList.correct > tend-0.2 & obj.eventList.correct < tend+0.2;
						tb = obj.eventList.breakFix > tend-0.2 & obj.eventList.breakFix < tend+0.2;
						ti = obj.eventList.incorrect > tend-0.2 & obj.eventList.incorrect < tend+0.2;
						if max(tc) == 1
							obj.eventList.vars(i).responseIndex(nr,1) = true;
							obj.eventList.vars(i).responseIndex(nr,2) = false;
							obj.eventList.vars(i).responseIndex(nr,3) = false;
							obj.eventList.varOrderCorrect(tc==1) = i; %build the correct trial list
						elseif max(tb) == 1
							obj.eventList.vars(i).responseIndex(nr,1) = false;
							obj.eventList.vars(i).responseIndex(nr,2) = true;
							obj.eventList.vars(i).responseIndex(nr,3) = false;
						elseif max(ti) == 1
							obj.eventList.vars(i).responseIndex(nr,1) = false;
							obj.eventList.vars(i).responseIndex(nr,2) = false;
							obj.eventList.vars(i).responseIndex(nr,3) = true;
						else
							error('Problem Finding Correct Strobes!!!!! plxReader')
						end
					end
					obj.eventList.vars(i).nCorrect = sum(obj.eventList.vars(i).responseIndex(:,1));
					obj.eventList.vars(i).nBreakFix = sum(obj.eventList.vars(i).responseIndex(:,2));
					obj.eventList.vars(i).nIncorrect = sum(obj.eventList.vars(i).responseIndex(:,3));
					
					if obj.eventList.minRuns > obj.eventList.vars(i).nCorrect
						obj.eventList.minRuns = obj.eventList.vars(i).nCorrect;
					end
					if obj.eventList.maxRuns < obj.eventList.vars(i).nCorrect
						obj.eventList.maxRuns = obj.eventList.vars(i).nCorrect;
					end
					
					if obj.eventList.tMin > obj.eventList.vars(i).tMin
						obj.eventList.tMin = obj.eventList.vars(i).tMin;
					end
					if obj.eventList.tMax < obj.eventList.vars(i).tMax
						obj.eventList.tMax = obj.eventList.vars(i).tMax;
					end
					
					obj.eventList.vars(i).t1correct = obj.eventList.vars(i).t1(obj.eventList.vars(i).responseIndex(:,1));
					obj.eventList.vars(i).t2correct = obj.eventList.vars(i).t2(obj.eventList.vars(i).responseIndex(:,1));
					obj.eventList.vars(i).tDeltacorrect = obj.eventList.vars(i).tDelta(obj.eventList.vars(i).responseIndex(:,1));
					obj.eventList.vars(i).tMinCorrect = min(obj.eventList.vars(i).tDeltacorrect);
					obj.eventList.vars(i).tMaxCorrect = max(obj.eventList.vars(i).tDeltacorrect);
					if obj.eventList.tMinCorrect > obj.eventList.vars(i).tMinCorrect
						obj.eventList.tMinCorrect = obj.eventList.vars(i).tMinCorrect;
					end
					if obj.eventList.tMaxCorrect < obj.eventList.vars(i).tMaxCorrect
						obj.eventList.tMaxCorrect = obj.eventList.vars(i).tMaxCorrect;
					end
					
					obj.eventList.vars(i).t1breakfix = obj.eventList.vars(i).t1(obj.eventList.vars(i).responseIndex(:,2));
					obj.eventList.vars(i).t2breakfix = obj.eventList.vars(i).t2(obj.eventList.vars(i).responseIndex(:,2));
					obj.eventList.vars(i).tDeltabreakfix = obj.eventList.vars(i).tDelta(obj.eventList.vars(i).responseIndex(:,2));
					
					obj.eventList.vars(i).t1incorrect = obj.eventList.vars(i).t1(obj.eventList.vars(i).responseIndex(:,3));
					obj.eventList.vars(i).t2incorrect = obj.eventList.vars(i).t2(obj.eventList.vars(i).responseIndex(:,3));
					obj.eventList.vars(i).tDeltaincorrect = obj.eventList.vars(i).tDelta(obj.eventList.vars(i).responseIndex(:,3));
					
				end
				
				obj.info{end+1} = sprintf('Number of Strobed Variables : %g', obj.eventList.nVars);
				obj.info{end+1} = sprintf('Total # Correct Trials :  %g', length(obj.eventList.correct));
				obj.info{end+1} = sprintf('Total # BreakFix Trials :  %g', length(obj.eventList.breakFix));
				obj.info{end+1} = sprintf('Total # Incorrect Trials :  %g', length(obj.eventList.incorrect));
				obj.info{end+1} = sprintf('Minimum # of Trials :  %g', obj.eventList.minRuns);
				obj.info{end+1} = sprintf('Maximum # of Trials :  %g', obj.eventList.maxRuns);
				obj.info{end+1} = sprintf('Shortest Trial Time (all/correct):  %g / %g s', obj.eventList.tMin,obj.eventList.tMinCorrect);
				obj.info{end+1} = sprintf('Longest Trial Time (all/correct):  %g / %g s', obj.eventList.tMax,obj.eventList.tMaxCorrect);
				
				
				obj.meta.modtime = floor(obj.eventList.tMaxCorrect * 10000);
				obj.meta.trialtime = obj.meta.modtime;
				m = [obj.rE.task.outIndex obj.rE.task.outMap getMeta(obj.rE.task)];
				m = m(1:obj.eventList.nVars,:);
				[~,ix] = sort(m(:,1),1);
				m = m(ix,:);
				obj.meta.matrix = m;
				
			else
				obj.eventList = struct();
			end
			fprintf('Loading all event markers took %g ms\n',round(toc*1000))
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
			[~,chnames] = plx_chan_names(obj.file);
			[~,chmap]=plx_chanmap(obj.file);
			chnames = cellstr(chnames);
			[nunits1, nchannels1] = size( tscounts );
			obj.tsList = struct();
			[a,b]=ind2sub(size(tscounts),find(tscounts>0)); %finds row and columns of nonzero values
			obj.tsList(1).chMap = unique(b)';
			for i = 1:length(obj.tsList.chMap)
				obj.tsList.unitMap(i).units = find(tscounts(:,obj.tsList.chMap(i))>0)';
				obj.tsList.unitMap(i).n = length(obj.tsList.unitMap(i).units);
				obj.tsList.unitMap(i).counts = tscounts(obj.tsList.unitMap(i).units,obj.tsList.chMap(i))';
				obj.tsList.unitMap(i).units = obj.tsList.unitMap(i).units - 1; %fix the index as plxuses 0 as unsorted
			end
			obj.tsList.chMap = obj.tsList(1).chMap - 1; %fix the index as plx_info add 1 to channels
			obj.tsList.chIndex = obj.tsList.chMap; %fucking pain channel number is different to ch index!!!
			obj.tsList.chMap = chmap(obj.tsList(1).chMap); %set proper ch number
			obj.tsList.nCh = length(obj.tsList.chMap);
			obj.tsList.nUnits = length(b);
			namelist = '';
			a = 1;
			list = 'Uabcdefghijklmnopqrstuvwxyz';
			for ich = 1:obj.tsList.nCh
				name = chnames{obj.tsList.chIndex(ich)};
				unitN = obj.tsList.unitMap(ich).n;
				for iunit = 1:unitN
					t = '';
					t = [num2str(a) ':' name list(iunit) '=' num2str(obj.tsList.unitMap(ich).counts(iunit))];
					obj.tsList.names{a} = t;
					namelist = [namelist ' ' t];
					a=a+1;
				end
			end
			obj.info{end+1} = ['Number of Active channels : ' num2str(obj.tsList.nCh)];
			obj.info{end+1} = ['Number of Active units : ' num2str(obj.tsList.nUnits)];
			obj.info{end+1} = ['Channel list : ' num2str(obj.tsList.chMap)];
			for i=1:obj.tsList.nCh
				obj.info{end+1} = ['Channel ' num2str(obj.tsList.chMap(i)) ' unit list (0=unsorted) : ' num2str(obj.tsList.unitMap(i).units)];
			end
			obj.info{end+1} = ['Ch/Unit Names : ' namelist];
			obj.tsList.ts = cell(obj.tsList.nUnits, 1);
			obj.tsList.tsN = obj.tsList.ts;
			obj.tsList.tsParse = obj.tsList.ts;
			a = 1;
			for ich = 1:obj.tsList.nCh
				unitN = obj.tsList.unitMap(ich).n;
				ch = obj.tsList.chMap(ich);
				for iunit = 1:unitN
					unit = obj.tsList.unitMap(ich).units(iunit);
					[obj.tsList.tsN{a}, obj.tsList.ts{a}] = plx_ts(obj.file, ch , unit);
					a = a+1;
				end
			end
			fprintf('Loading all spikes took %g ms\n',round(toc*1000));
		end
				
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function parseSpikes(obj)
			tic
			for ps = 1:obj.tsList.nUnits
				spikes = obj.tsList.ts{ps};
				obj.tsList.tsParse{ps}.var = cell(obj.eventList.nVars,1);
				for nv = 1:obj.eventList.nVars
					var = obj.eventList.vars(nv);
					obj.tsList.tsParse{ps}.var{nv}.run = struct();
					obj.tsList.tsParse{ps}.var{nv}.name = var.name;
					for nc = 1:var.nCorrect
						idx =  spikes >= var.t1correct(nc)+obj.startOffset & spikes <= var.t2correct(nc);
						obj.tsList.tsParse{ps}.var{nv}.run(nc).basetime = var.t1correct(nc) + obj.startOffset;
						obj.tsList.tsParse{ps}.var{nv}.run(nc).modtimes = var.t1correct(nc) + obj.startOffset;
						obj.tsList.tsParse{ps}.var{nv}.run(nc).spikes = spikes(idx);
						obj.tsList.tsParse{ps}.var{nv}.run(nc).name = var.name;
						obj.tsList.tsParse{ps}.var{nv}.run(nc).tDelta = var.tDeltacorrect(nc);
					end					
				end
			end
			if obj.startOffset ~= 0
				obj.info{end+1} = sprintf('START OFFSET ACTIVE : %g', obj.startOffset);
			end
			fprintf('Parsing spikes into trials took %g ms\n',round(toc*1000))
		end
		
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function reparseInfo(obj)

			obj.info{end+1} = sprintf('Number of Strobed Variables : %g', obj.eventList.nVars);
			obj.info{end+1} = sprintf('Total # Correct Trials :  %g', length(obj.eventList.correct));
			obj.info{end+1} = sprintf('Total # BreakFix Trials :  %g', length(obj.eventList.breakFix));
			obj.info{end+1} = sprintf('Total # Incorrect Trials :  %g', length(obj.eventList.incorrect));
			obj.info{end+1} = sprintf('Minimum # of Trials :  %g', obj.eventList.minRuns);
			obj.info{end+1} = sprintf('Maximum # of Trials :  %g', obj.eventList.maxRuns);
			obj.info{end+1} = sprintf('Shortest Trial Time (all/correct):  %g / %g s', obj.eventList.tMin,obj.eventList.tMinCorrect);
			obj.info{end+1} = sprintf('Longest Trial Time (all/correct):  %g / %g s', obj.eventList.tMax,obj.eventList.tMaxCorrect);
			obj.info{end+1} = ['Number of Active channels : ' num2str(obj.tsList.nCh)];
			obj.info{end+1} = ['Number of Active units : ' num2str(obj.tsList.nUnit)];
			obj.info{end+1} = ['Channel list : ' num2str(obj.tsList.chMap)];
			obj.info{end+1} = ['Unit list (0=unsorted) : ' num2str(obj.tsList.unitMap)];

		end
		
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function checkPL2(obj)
			if isempty(regexpi(obj.file,'pl2'))
				obj.isPL2 = false;
			else
				obj.isPL2 = true;
			end
		end
		
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function [idx,val,delta]=findNearest(obj,in,value)
			tmp = abs(in-value);
			[~,idx] = min(tmp);
			val = in(idx);
			delta = abs(value - val);
		end
		
	end
	
end

