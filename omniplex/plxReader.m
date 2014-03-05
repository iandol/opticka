classdef plxReader < optickaCore
%> PLXREADER Reads in Plexon .plx and .pl2 files along with metadata and
%> eyelink data. Parses the trial event structure.
	
	%------------------PUBLIC PROPERTIES----------%
	properties
		%> plx/pl2 file name
		file@char
		%> file directory
		dir@char
		%> the opticka mat file name
		matfile@char
		%> the opticka mat file directory
		matdir@char
		%> edf file name
		edffile@char
		%> used for legacy cell channel mapping (SMRs only have 6 channels)
		cellmap@double
		%> use the event on/off markers if empty, or a timerange around the event on otherwise
		eventWindow@double = []
		%> the window to check before/after trial end for behavioural marker
		eventSearchWindow@double = 0.2
		%> used by legacy spikes to allow negative time offsets
		startOffset@double = 0
		%> verbose?
		verbose	= false
	end
	
	%------------------VISIBLE PROPERTIES----------%
	properties (SetAccess = private, GetAccess = public)
		%> info formatted in cellstrings for display
		info@cell
		%> event list parsed
		eventList@struct
		%> parsed spikes
		tsList@struct
		%> metadata
		meta@struct
		%> the experimental run object (loaded from matfile)
		rE@runExperiment
		%> the eyelink data (loaded from edffile)
		eA@eyelinkAnalysis
		%> the raw pl2 structure if this is a pl2 file
		pl2@struct
	end
	
	%------------------DEPENDENT PROPERTIES--------%
	properties (SetAccess = private, Dependent = true)
		%> is this a PL2 file?
		isPL2@logical
		%> is an EDF eyelink file present?
		isEDF@logical
		%> is trodal?
		trodality@double
	end
	
	%------------------PRIVATE PROPERTIES----------%
	properties (SetAccess = private, GetAccess = private)
		%> info cache to speed up generating info{}
		ic@struct = struct()
		%> allowed properties passed to object upon construction
		allowedProperties@char = 'file|dir|matfile|matdir|edffile|startOffset|cellmap|verbose|eventWindow'
	end
	
	%=======================================================================
	methods %------------------PUBLIC METHODS
	%=======================================================================

		%===================================================================
		%> @brief Constructor
		%>
		%> @param varargin
		%> @return
		%===================================================================
		function obj = plxReader(varargin)
			if nargin == 0; varargin.name = 'plxReader'; end
			if nargin>0; obj.parseArgs(varargin, obj.allowedProperties); end
			if isempty(obj.name); obj.name = 'plxReader'; end
			if isempty(obj.file);
				getFiles(obj,false);
			end
		end
		
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function parse(obj)
			if isempty(obj.file)
				getFiles(obj, true);
				if isempty(obj.file); warning('No plexon file selected'); return; end
			end
			if isempty(obj.matfile)
				getFiles(obj);
				if isempty(obj.matfile); warning('No behavioural mat file selected'); return; end
			end
			obj.paths.oldDir = pwd;
			cd(obj.dir);
			readMat(obj);
			readSpikes(obj);
			getEvents(obj);
			if obj.isEDF == true
				loadEDF(obj);
			end
			parseSpikes(obj);
			generateInfo(obj);
			integrateEyeData(obj);
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
			getEvents(obj);
			parseSpikes(obj);
			generateInfo(obj);
			integrateEyeData(obj);
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function parseEvents(obj)
			cd(obj.dir);
			getEvents(obj);
			generateInfo(obj);
			if isa(obj.ea,'eyelinkAnalysis')
				integrateEyeData(obj);
			end
		end
		
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function LFPs = readLFPs(obj)
			cd(obj.dir);
			if isempty(obj.eventList); 
				getEvents(obj); 
			end
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
				if ~isempty(regexp(cname,'FP', 'once')) %check we have a FP name field
					num = str2num(regexp(cname,'\d*','match','once')); %what channel number
					if num < 21
						LFPs(aa).name = cname;
						LFPs(aa).index = raw(idx(j)); LFPs(aa).channel = num;
						LFPs(aa).count = map(idx(j));
						LFPs(aa).reparse = false;
						LFPs(aa).trials = struct([]); LFPs(aa).vars = struct([]); %#ok<*AGROW>
						aa = aa + 1;
					end
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
					time = ts(end) : tbase : (ts(end)+(tbase*(fn(end)-1)))';
					time = time(1:length(data));
					LFPs(j).usedtimeStamp = ts(end);
				elseif length(fn) == 1 %no gaps
					data = ad(fn+1:end);
					time = ts : tbase : (ts+(tbase*fn-1))';
					time = time(1:length(data));
					LFPs(j).usedtimeStamp = ts;
				else
					return;
				end
				LFPs(j).data = data;
				LFPs(j).time = time';
				LFPs(j).eventSample = round(LFPs(j).usedtimeStamp * 40e3);
				LFPs(j).sample = round(LFPs(j).usedtimeStamp * LFPs(j).recordingFrequency);
				LFPs(j).nTrials = obj.eventList.nTrials;
				LFPs(j).nVars = obj.eventList.nVars;
			end
			
			fprintf('Loading LFPs took %g ms\n',round(toc*1000));
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
		
		% ===================================================================
		%> @brief 
		%> @param
		%> @return 
		% ===================================================================
		function isEDF = get.isEDF(obj)
			isEDF = false;
			if ~isempty(obj.edffile)
				isEDF = true;
			end
		end
		
		% ===================================================================
		%> @brief 
		%> @param
		%> @return 
		% ===================================================================
		function isPL2 = get.isPL2(obj)
			isPL2 = false;
			if ~isempty(regexpi(obj.file,'pl2'))
				isPL2 = true;
			end
		end
		
		% ===================================================================
		%> @brief 
		%> @param
		%> @return 
		% ===================================================================
		function trodality = get.trodality(obj)
			if ~isfield(obj.ic,'Trodalness') || ~isempty(obj.ic.Trodalness)
				[~,~,~,~,obj.ic.Trodalness]=plx_information(obj.file);
			end
			trodality = max(obj.ic.Trodalness);
			if isempty(trodality); trodality = 0; end
		end
		
		% ===================================================================
		%> @brief Constructor
		%>
		%> @param varargin
		%> @return
		% ===================================================================
		function getFiles(obj, force)
			if ~exist('force','var')
				force = false;
			end
			if force == true || isempty(obj.file)
				[f,p] = uigetfile({'*.plx;*.pl2';'PlexonFiles'},'Load Plexon File');
				if ischar(f) && ~isempty(f)
					obj.file = f;
					obj.dir = p;
						obj.paths.oldDir = pwd;
					cd(obj.dir);
				else
					return
				end
			end
			if force == true || isempty(obj.matfile)
				[obj.matfile, obj.matdir] = uigetfile('*.mat','Load Behaviour MAT File');
			end
			if force == true || isempty(obj.edffile)
				cd(obj.matdir)
				[~,f,~] = fileparts(obj.matfile);
				f = [f '.edf'];
				ff = regexprep(f,'^[a-zA-Z]+\-','','ignorecase');
				ff = regexprep(ff,'\.edf','FIX\.edf','ignorecase');
				if ~exist(f, 'file') && ~exist(ff,'file')
					[an, ~] = uigetfile('*.edf','Load Eyelink EDF File');
					if ischar(an)
						obj.edffile = an;
					else
						obj.edffile = '';
					end
				elseif exist(f, 'file')
					obj.edffile = f;
				elseif exist(ff, 'file')
					obj.edffile = ff;
				end
			end
		end
		
		% ===================================================================
		%> @brief 
		%>
			%> @param
		%> @return
		% ===================================================================
		function spike = getFTSpikes(obj)
			dat = obj.tsList.tsParse;
			spike.label = obj.tsList.names;
			spike.nUnits = obj.tsList.nUnits;
			spike.timestamp = cell(1,spike.nUnits);
			spike.unit = cell(1,spike.nUnits);
			spike.hdr = [];
			spike.hdr.FileHeader.Frequency = 40e3;
			spike.hdr.FileHeader.Beg = 0;
			spike.hdr.FileHeader.End = Inf;
			spike.dimord = '{chan}_lead_time_spike';
			spike.time = cell(1,spike.nUnits);
			spike.trial = cell(1,spike.nUnits);
			spike.trialtime = [];
			spike.cfg = struct;
			spike.cfg.dataset = obj.file;
			spike.cfg.headerformat = 'plexon_plx_v2';
			spike.cfg.dataformat = spike.cfg.headerformat;
			spike.cfg.eventformat = spike.cfg.headerformat;
			spike.cfg.trl = [];
			fs = spike.hdr.FileHeader.Frequency;
			for j = 1:length(dat{1}.trials)
				for k = 1:spike.nUnits
					t = dat{k}.trials{j};
					s = t.spikes';
					spike.timestamp{k} = [spike.timestamp{k} s*fs];
					spike.time{k} = [spike.time{k} s-t.base];
					spike.trial{k} = [spike.trial{k} ones(1,length(s))*j];
					spike.trialtime(j,:) = [t.rStart t.rEnd];
					spike.cfg.trl(j,:) = [spike.trialtime(j,:) t.rStart*fs t.name t.isCorrect];
				end
			end
		end
		
		% ===================================================================
		%> @brief 
		%> @param
		%> @return 
		% ===================================================================
		function integrateEyeData(obj)
			tic
			plxList = [obj.eventList.trials.name]'; %var order list
			edfTrials = obj.eA.trials;
			edfTrials(obj.eA.incorrect.idx) = []; %remove incorrect trials
			edfList = [edfTrials.id]';
			c1 = [obj.eventList.trials.isCorrect]';
			c2 = [edfTrials.correct]';
			if isequal(plxList,edfList) || isequal(c1,c2) %check our variable list orders are equal
				for i = 1:length(plxList)
					obj.eventList.trials(i).eye = edfTrials(i);
					sT = edfTrials(i).saccadeTimes/1e3;
					fS = min(sT(sT>0));
					obj.eventList.trials(i).saccadeTimes = sT;
					if ~isempty(fS)
						obj.eventList.trials(i).firstSaccade = fS;
					else
						obj.eventList.trials(i).firstSaccade = NaN;
					end
				end
			else
				warning('Integrating eyelink trials into plxReader trials failed...');
			end
			fprintf('Integrating eye data into event data took %g ms\n',round(toc*1000));
		end
		
		
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function drawEvents(obj,h)
			if ~exist('h','var')
				hh=figure;figpos(1,[2000 800]);set(gcf,'Color',[1 1 1]);
				h = axes;
				set(hh,'CurrentAxes',h);
			end
			axes(h);
			title(['EVENT PLOT: File:' obj.file]);
			xlabel('Time (s)');
			hold on
			color = rand(3,obj.eventList.nVars);
			for j = 1:obj.eventList.nTrials
				trl = obj.eventList.trials(j);
				var = trl.name;
				line([trl.t1 trl.t1],[-.4 .4],'Color',color(:,var),'LineWidth',1);
				line([trl.t2 trl.t2],[-.4 .4],'Color',color(:,var),'LineWidth',1);
				text(trl.t1,.41,['VAR: ' num2str(var) '\newlineTRL: ' num2str(j)],'FontSize',10);
				text(trl.t1,-.41,['SAC: ' num2str(trl.firstSaccade) '\newlineCOR: ' num2str(trl.isCorrect)],'FontSize',10);
			end
			plot(obj.eventList.startFix,zeros(size(obj.eventList.startFix)),'c.','MarkerSize',15);
			plot(obj.eventList.correct,zeros(size(obj.eventList.correct)),'g.','MarkerSize',15);
			plot(obj.eventList.breakFix,zeros(size(obj.eventList.breakFix)),'b.','MarkerSize',15);
			plot(obj.eventList.incorrect,zeros(size(obj.eventList.incorrect)),'r.','MarkerSize',15);
			axis([0 10 -.5 .5])
			hold off;
			box on;
			pan xon;
			uicontrol('Style', 'pushbutton', 'String', '<<',...
				'Position',[1 1 50 20],'Callback',@backPlot);
			uicontrol('Style', 'pushbutton', 'String', '>>',...
				'Position',[52 1 50 20],'Callback',@forwardPlot);
			
			function forwardPlot(src, ~)
				if ~exist('src','var')
					return
				end
				ax = axis(gca);
				ax(1) = ax(1) + 10;
				ax(2) = ax(1) + 10;
				axis(ax);
			end
			function backPlot(src, ~)
				if ~exist('src','var')
					return
				end
				ax = axis(gca);
				ax(1) = ax(1) - 10;
				ax(2) = ax(1) + 10;
				axis(ax);
			end
		end
		
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function handles = infoBox(obj, info)
			%[left bottom width height]
			if ~exist('info','var'), info = obj.info; end
			scr=get(0,'ScreenSize');
			width=scr(3);
			height=scr(4);
			handles.root = figure('Units','pixels','Position',[0 0 width/4 height],'Tag','PLXInfoFigure',...
				'Color',[0.9 0.9 0.9]);
			handles.display = uicontrol('Style','edit','Units','normalized','Position',[0 0.55 1 0.45],...
				'BackgroundColor',[0.3 0.3 0.3],'ForegroundColor',[1 1 0],'Max',1000,...
				'FontSize',12,'FontWeight','bold','FontName','Helvetica Neue','HorizontalAlignment','left');
			handles.comments = uicontrol('Style','edit','Units','normalized','Position',[0 0.5 1 0.05],...
				'BackgroundColor',[0.8 0.8 0.8],'ForegroundColor',[.1 .1 .1],'Max',1000,...
				'FontSize',12,'FontWeight','bold','FontName','Helvetica Neue','HorizontalAlignment','left',...
				'Callback',@editComment);
			handles.axis = axes('Units','normalized','Position',[0.05 0.05 0.9 0.4]);
			if ~isempty(obj.eventList)
				drawEvents(obj,handles.axis);
			end
			set(handles.display,'String',info,'FontSize',12);
			set(handles.comments,'String',obj.comment,'FontSize',11);
			
			function editComment(src, ~)
				if ~exist('src','var');	return; end
				s = get(src,'String');
				if ~isempty(s)
					obj.comment = s;
				end
			end
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
				clear obj;
			end
			if ~isa(rE,'runExperiment')
				warning('The behavioural file doesn''t contain a runExperiment object!!!');
				return
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
			fprintf('Parsing Behavioural files took %g ms\n', round(toc*1000))
			cd(oldd);
		end
	end
	
	%=======================================================================
	methods ( Access = private ) %-------PRIVATE METHODS-----%
	%===== ==================================================================
	
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
			if exist(obj.edffile,'file')
				oldd=pwd;
				cd(pn);
				if ~isempty(obj.eA) && isa(obj.eA,'eyelinkAnalysis')
					obj.eA.file = obj.edffile;
					obj.eA.dir = pn;
					obj.eA.trialOverride = obj.eventList.trials;
				else
					in = struct('file',obj.edffile,'dir',pn,...
						'trialOverride',obj.eventList.trials);
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
				load(obj.eA);
				parse(obj.eA);
				fixVarNames(obj.eA);
				cd(oldd)
			end
		end
		
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function readMat(obj,override)
			if ~exist('override','var'); override = false; end
			if override == true || isempty(obj.rE)
				if exist(obj.matdir, 'dir')
					[obj.meta, obj.rE] = obj.loadMat(obj.matfile, obj.matdir);
				else
					[obj.meta, obj.rE] = obj.loadMat(obj.matfile, obj.dir);
				end
			end
		end
			
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function generateInfo(obj)
			tic
			if ~isfield(obj.ic, 'Freq')
				[obj.ic.OpenedFileName, obj.ic.Version, obj.ic.Freq, obj.ic.Comment, obj.ic.Trodalness,...
					obj.ic.NPW, obj.ic.PreThresh, obj.ic.SpikePeakV, obj.ic.SpikeADResBits,...
					obj.ic.SlowPeakV, obj.ic.SlowADResBits, obj.ic.Duration, obj.ic.DateTime] = plx_information(obj.file);
				if exist('plx_mexplex_version','file')
					obj.ic.sdkversion = plx_mexplex_version();
				else
					obj.ic.sdkversion = -1;
				end
			end
			obj.info = {};
			if obj.isPL2
				if isempty(obj.pl2); obj.pl2 = PL2GetFileIndex(obj.file); end
				obj.info{1} = sprintf('PL2 File : %s', obj.ic.OpenedFileName);
				obj.info{end+1} = sprintf('\tPL2 File Length : %d', obj.pl2.FileLength);
				obj.info{end+1} = sprintf('\tPL2 Creator : %s %s', obj.pl2.CreatorSoftwareName, obj.pl2.CreatorSoftwareVersion);
			else
				obj.info{1} = sprintf('PLX File : %s', obj.ic.OpenedFileName);
			end
			obj.info{end+1} = sprintf('Behavioural File : %s', obj.matfile);
			obj.info{end+1} = ' ';
			obj.info{end+1} = sprintf('Behavioural File Comment : %s', obj.meta.comments);
			obj.info{end+1} = ' ';
			obj.info{end+1} = sprintf('Plexon File Comment : %s', obj.ic.Comment);
			obj.info{end+1} = sprintf('Version : %g', obj.ic.Version);
			obj.info{end+1} = sprintf('SDK Version : %g', obj.ic.sdkversion);
			obj.info{end+1} = sprintf('Frequency : %g Hz', obj.ic.Freq);
			obj.info{end+1} = sprintf('Plexon Date/Time : %s', num2str(obj.ic.DateTime));
			obj.info{end+1} = sprintf('Duration : %g seconds', obj.ic.Duration);
			obj.info{end+1} = sprintf('Num Pts Per Wave : %g', obj.ic.NPW);
			obj.info{end+1} = sprintf('Num Pts Pre-Threshold : %g', obj.ic.PreThresh);
			
			switch obj.trodality
				case 1
					obj.info{end+1} = sprintf('Data type : Single Electrode');
				case 2
					obj.info{end+1} = sprintf('Data type : Stereotrode');
				case 4
					obj.info{end+1} = sprintf('Data type : Tetrode');
				otherwise
					obj.info{end+1} = sprintf('Data type : Unknown');
			end
			obj.info{end+1} = sprintf('Spike Peak Voltage (mV) : %g', obj.ic.SpikePeakV);
			obj.info{end+1} = sprintf('Spike A/D Resolution (bits) : %g', obj.ic.SpikeADResBits);
			obj.info{end+1} = sprintf('Slow A/D Peak Voltage (mV) : %g', obj.ic.SlowPeakV);
			obj.info{end+1} = sprintf('Slow A/D Resolution (bits) : %g', obj.ic.SlowADResBits);
			
			if isa(obj.rE,'runExperiment')
				obj.info{end+1} = ' ';
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
				obj.info{end+1} = sprintf('Variable Names : %s', names(5:end));
				obj.info{end+1} = sprintf('Variable Values : %s', vals(5:end));
				names = '';
				for i = 1:rE.stimuli.n
					names = [names ' | ' rE.stimuli{i}.name ':' rE.stimuli{i}.family];
				end
				obj.info{end+1} = sprintf('Stimulus Names : %s', names(4:end));
			end
			if ~isempty(obj.eventList)
				obj.info{end+1} = ' ';
				obj.info{end+1} = sprintf('Number of Strobed Variables : %g', obj.eventList.nVars);
				obj.info{end+1} = sprintf('Total # Correct Trials :  %g', length(obj.eventList.correct));
				obj.info{end+1} = sprintf('Total # BreakFix Trials :  %g', length(obj.eventList.breakFix));
				obj.info{end+1} = sprintf('Total # Incorrect Trials :  %g', length(obj.eventList.incorrect));
				obj.info{end+1} = sprintf('Minimum # of Trials per variable :  %g', obj.eventList.minRuns);
				obj.info{end+1} = sprintf('Maximum # of Trials per variable :  %g', obj.eventList.maxRuns);
				obj.info{end+1} = sprintf('Shortest Trial Time (all/correct):  %g / %g s', obj.eventList.tMin,obj.eventList.tMinCorrect);
				obj.info{end+1} = sprintf('Longest Trial Time (all/correct):  %g / %g s', obj.eventList.tMax,obj.eventList.tMaxCorrect);
			end
			if ~isempty(obj.tsList)
				obj.info{end+1} = ' ';
				obj.info{end+1} = ['Total Channel list : ' num2str(obj.tsList.chMap)];
				obj.info{end+1} = ['Trodality Reduction : ' num2str(obj.tsList.trodreduction)];
				obj.info{end+1} = ['Number of Active channels : ' num2str(obj.tsList.nCh)];
				obj.info{end+1} = ['Number of Active units : ' num2str(obj.tsList.nUnits)];
				for i=1:obj.tsList.nCh
					obj.info{end+1} = ['Channel ' num2str(obj.tsList.chMap(i)) ' unit list (0=unsorted) : ' num2str(obj.tsList.unitMap(i).units)];
				end
				obj.info{end+1} = ['Ch/Unit Names : ' obj.tsList.namelist];
				obj.info{end+1} = sprintf('Number of Parsed Spike Trials : %g', length(obj.tsList.tsParse{1}.trials));
				obj.info{end+1} = sprintf('Data window around event : %s ', num2str(obj.eventWindow));
				obj.info{end+1} = sprintf('Start Offset : %g ', obj.startOffset);
			end
			if ~isempty(obj.eA)
				saccs = [obj.eA.trials.firstSaccade];
				saccs(isnan(saccs)) = [];
				saccs(saccs<0) = [];
				mins = min(saccs);
				maxs = max(saccs);
				[avgs,es] = stderr(saccs);
				ns = length(saccs);
				obj.info{end+1} = ' ';
				obj.info{end+1} = ['Eyelink data Parsed trial total : ' num2str(length(obj.eA.trials))];
				obj.info{end+1} = ['Eyelink trial bug override : ' num2str(obj.eA.needOverride)];
				obj.info{end+1} = sprintf('Valid First Post-Stimulus Saccades (#%g): %.4g ± %.3g (range %g:%g )',ns,avgs/1e3,es/1e3,mins/1e3,maxs/1e3);
			end
			fprintf('Generating info took %g ms\n',round(toc*1000))
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
			readMat(obj); %make sure we've loaded the behavioural file first
			tic
			[~,eventNames] = plx_event_names(obj.file);
			[~,eventIndex] = plx_event_chanmap(obj.file);
			eventNames = cellstr(eventNames);
			
			idx = strcmpi(eventNames,'Strobed');
			[a, b, c] = plx_event_ts(obj.file,eventIndex(idx));
			if isempty(a) || a == 0
				obj.eventList = struct();
				warning('No strobe events detected!!!');
				return
			end
			idx = find(c < 1); %check for zer or lower event numbers, remove
			if ~isempty(idx)
				c(idx)=[];
				b(idx) = [];
			end
			idx = find(c > obj.rE.task.minBlocks & c < 32700); %check for invalid event numbers, remove
			if ~isempty(idx)
				c(idx)=[];
				b(idx) = [];
			end
			if c(end) < 32700 %prune a trial at the end if it is not a stopstrobe!
				a = a - 1;
				c(end)=[];
				b(end) = [];
			end
			a = length(b); %readjust our strobed # count
			
			idx = strcmpi(eventNames, 'Start');
			[~,start] = plx_event_ts(obj.file,eventIndex(idx)); %start event
			idx = strcmpi(eventNames, 'Stop');
			[~,stop] = plx_event_ts(obj.file,eventIndex(idx)); %stop event
			idx = strcmpi(eventNames, 'EVT19'); 
			[~,b19] = plx_event_ts(obj.file,eventIndex(idx)); %currently 19 is fix start
			idx = strcmpi(eventNames, 'EVT20');
			[~,b20] = plx_event_ts(obj.file,eventIndex(idx)); %20 is correct
			idx = strcmpi(eventNames, 'EVT21');
			[~,b21] = plx_event_ts(obj.file,eventIndex(idx)); %21 is breakfix
			idx = strcmpi(eventNames, 'EVT22');
			[~,b22] = plx_event_ts(obj.file,eventIndex(idx)); %22 is incorrect

			eL = struct();
			eL.eventNames = eventNames;
			eL.eventIndex = eventIndex;
			eL.n = a;
			eL.nTrials = a/2; %we hope our strobe # even
			eL.times = b;
			eL.values = c;
			eL.start = start;
			eL.stop = stop;
			eL.startFix = b19;
			eL.correct = b20;
			eL.breakFix = b21;
			eL.incorrect = b22;
			eL.varOrder = eL.values(eL.values<32000);
			eL.varOrderCorrect = zeros(length(eL.correct),1);
			eL.varOrderBreak = zeros(length(eL.breakFix),1);
			eL.varOrderIncorrect = zeros(length(eL.incorrect),1);
			eL.unique = unique(c);
			eL.nVars = length(eL.unique)-1;
			eL.minRuns = Inf;
			eL.maxRuns = 0;
			eL.tMin = Inf;
			eL.tMax = 0;
			eL.tMinCorrect = Inf;
			eL.tMaxCorrect = 0;
			eL.trials = struct('name',[],'index',[]);
			eL.trials(eL.nTrials,1).name = [];
			eL.vars = struct('name',[],'nRepeats',[],'index',[],'responseIndex',[],'t1',[],'t2',[],...
				'nCorrect',[],'nBreakFix',[],'nIncorrect',[],'t1correct',[],'t2correct',[],...
				't1breakfix',[],'t2breakfix',[],'t1incorrect',[],'t2incorrect',[]);
			eL.vars(eL.nVars,1).name = [];
			
			aa = 1; cidx = 1; bidx = 1; iidx = 1;
			
			for i = 1:2:eL.n % iterate through all trials
				
				var = eL.values(i);
				eL.trials(aa).name = var; 
				eL.trials(aa).index = aa;				
				eL.trials(aa).t1 = eL.times(i);
				eL.trials(aa).t2 = eL.times(i+1);
				eL.trials(aa).tDelta = eL.trials(aa).t2 - eL.trials(aa).t1;
				
				if isempty(eL.vars(var).name)
					eL.vars(var).name = var;
					idx = find(eL.values == var);
					idxend = idx+1;
					while (length(idx) > length(idxend)) %prune incomplete trials
						idx = idx(1:end-1);
					end
					eL.vars(var).nRepeats = length(idx);
					eL.vars(var).index = idx;
					eL.vars(var).t1 = eL.times(idx);
					eL.vars(var).t2 = eL.times(idxend);
					eL.vars(var).tDelta = eL.vars(var).t2 - eL.vars(var).t1;
					eL.vars(var).tMin = min(eL.vars(var).tDelta);
					eL.vars(var).tMax = max(eL.vars(var).tDelta);
					eL.vars(var).nCorrect = 0;
					eL.vars(var).nBreakFix = 0;
					eL.vars(var).nIncorrect = 0;
				end
				
				tc = eL.correct > eL.trials(aa).t2 - obj.eventSearchWindow & eL.correct < eL.trials(aa).t2 + obj.eventSearchWindow;
				tb = eL.breakFix > eL.trials(aa).t2 - obj.eventSearchWindow & eL.breakFix < eL.trials(aa).t2 + obj.eventSearchWindow;
				ti = eL.incorrect > eL.trials(aa).t2 - obj.eventSearchWindow & eL.incorrect < eL.trials(aa).t2 + obj.eventSearchWindow;
				
				if max(tc) == 1
					eL.trials(aa).isCorrect = true; eL.trials(aa).isBreak = false; eL.trials(aa).isIncorrect = false;
					eL.varOrderCorrect(cidx) = var; %build the correct trial list
					eL.vars(var).nCorrect = eL.vars(var).nCorrect + 1;
					eL.vars(var).responseIndex(end+1,:) = [true, false,false];
					cidx = cidx + 1;
				elseif max(tb) == 1
					eL.trials(aa).isCorrect = false; eL.trials(aa).isBreak = true; eL.trials(aa).isIncorrect = false;
					eL.varOrderBreak(bidx) = var; %build the break trial list
					eL.vars(var).nBreakFix = eL.vars(var).nBreakFix + 1;
					eL.vars(var).responseIndex(end+1,:) = [false, true, false];
					bidx = bidx + 1;
				elseif max(ti) == 1
					eL.trials(aa).isCorrect = false; eL.trials(aa).isBreak = false; eL.trials(aa).isIncorrect = true;
					eL.varOrderIncorrect(iidx) = var; %build the incorrect trial list
					eL.vars(var).nIncorrect = eL.vars(var).nIncorrect + 1;
					eL.vars(var).responseIndex(end+1,:) = [false, false, true];
					iidx = iidx + 1;
				else
					error('plxReader Problem Finding Correct Strobes!!!!!')
				end	
				
				if eL.trials(aa).isCorrect
					eL.vars(var).t1correct = [eL.vars(var).t1correct; eL.trials(aa).t1];
					eL.vars(var).t2correct = [eL.vars(var).t2correct; eL.trials(aa).t2];
					eL.vars(var).tDeltacorrect = eL.vars(var).t2correct - eL.vars(var).t1correct;
					eL.vars(var).tMinCorrect = min(eL.vars(var).tDeltacorrect);
					eL.vars(var).tMaxCorrect = max(eL.vars(var).tDeltacorrect);
				elseif eL.trials(aa).isBreak
					eL.vars(var).t1breakfix = [eL.vars(var).t1breakfix; eL.trials(aa).t1];
					eL.vars(var).t2breakfix = [eL.vars(var).t2breakfix; eL.trials(aa).t2];
					eL.vars(var).tDeltabreakfix = eL.vars(var).t2breakfix - eL.vars(var).t1breakfix;
				elseif eL.trials(aa).isIncorrect
					eL.vars(var).t1incorrect = [eL.vars(var).t1incorrect; eL.trials(aa).t1];
					eL.vars(var).t2incorrect = [eL.vars(var).t2incorrect; eL.trials(aa).t2];
					eL.vars(var).tDeltaincorrect = eL.vars(var).t2incorrect - eL.vars(var).t1incorrect;
				end
				aa = aa + 1;
			end
			
			eL.minRuns = min([eL.vars(:).nCorrect]);
			eL.maxRuns = max([eL.vars(:).nCorrect]);
			eL.tMin = min([eL.trials(:).tDelta]);
			eL.tMax = max([eL.trials(:).tDelta]);
			eL.tMinCorrect = min([eL.vars(:).tMinCorrect]);
			eL.tMaxCorrect = max([eL.vars(:).tMaxCorrect]);
			eL.correctIndex = [eL.trials(:).isCorrect]';
			eL.breakIndex = [eL.trials(:).isBreak]';
			eL.incorrectIndex = [eL.trials(:).isIncorrect]';
			obj.eventList = eL;
			fprintf('Loading all event markers took %g ms\n',round(toc*1000))

			obj.meta.modtime = floor(obj.eventList.tMaxCorrect * 10000);
			obj.meta.trialtime = obj.meta.modtime;
			m = [obj.rE.task.outIndex obj.rE.task.outMap getMeta(obj.rE.task)];
			m = m(1:obj.eventList.nVars,:);
			[~,ix] = sort(m(:,1),1);
			m = m(ix,:);
			obj.meta.matrix = m;	
			clear eL m
		end
		
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function readSpikes(obj)
			tic
			[tscounts, wfcounts, evcounts, slowcounts] = plx_info(obj.file,1);
			[~,chnames] = plx_chan_names(obj.file);
			[~,chmap]=plx_chanmap(obj.file);
			chnames = cellstr(chnames);
			[nunits1, nchannels1] = size( tscounts );
			obj.tsList = struct();
			[a,b]=ind2sub(size(tscounts),find(tscounts>0)); %finds row and columns of nonzero values
			obj.tsList.chMap = unique(b)';
			a = 1;
			obj.tsList.trodreduction = false;
			prevcount = inf;
			nCh = 0;
			nUnit = 0;
			for i = 1:length(obj.tsList.chMap)
				units = find(tscounts(:,obj.tsList.chMap(i))>0)';
				n = length(units);
				counts = tscounts(units,obj.tsList.chMap(i))';
				units = units - 1; %fix the index as plxuses 0 as unsorted
				if a == 1 || (obj.trodality > 1 && ~isequal(counts, prevcount));
					obj.tsList.unitMap(a).units = units;
					obj.tsList.unitMap(a).n = n;
					obj.tsList.unitMap(a).counts = counts;
					prevcount = counts;
					nCh = a;
					nUnit = nUnit + n;
					a = a + 1;
				end
			end
			if obj.trodality > 1 && a < i
				obj.tsList.trodreduction = true;	
				disp('---! Removed tetrode channels with identical spike numbers !---');
			end
			obj.tsList.chMap = obj.tsList(1).chMap - 1; %fix the index as plx_info add 1 to channels
			obj.tsList.chIndex = obj.tsList.chMap; %fucking pain channel number is different to ch index!!!
			obj.tsList.chMap = chmap(obj.tsList(1).chMap); %set proper ch number
			obj.tsList.nCh = nCh;
			obj.tsList.nUnits = nUnit;
			obj.tsList.namelist = ''; a = 1; list = 'Uabcdefghijklmnopqrstuvwxyz';
			for ich = 1:obj.tsList.nCh
				name = chnames{obj.tsList.chIndex(ich)};
				unitN = obj.tsList.unitMap(ich).n;
				for iunit = 1:unitN
					t = '';
					t = [num2str(a) ':' name list(iunit) '=' num2str(obj.tsList.unitMap(ich).counts(iunit))];
					obj.tsList.names{a} = t;
					obj.tsList.namelist = [obj.tsList.namelist ' ' t];
					a = a + 1;
				end
			end
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
					a = a + 1;
				end
			end
			fprintf('Loading all spike channels took %g ms\n',round(toc*1000));
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
				trials = cell(obj.eventList.nTrials,1);
				vars = cell(obj.eventList.nVars,1);
				for trl = 1:obj.eventList.nTrials
					%===process the trial
					trial = obj.eventList.trials(trl);
					trials{trl} = trial;
					trials{trl}.startOffset = obj.startOffset;
					trials{trl}.eventWindow = obj.eventWindow;
					if isempty(obj.eventWindow) %use event markers and startOffset
						trials{trl}.tStart = trial.t1 + obj.startOffset;
						trials{trl}.tEnd = trial.t2;
						trials{trl}.rStart = obj.startOffset;
						trials{trl}.rEnd = trial.t2 - trial.t1;
						trials{trl}.base = trial.t1;
						trials{trl}.basetime = trials{trl}.tStart; %make offset invisible for systems that can't handle -time
						trials{trl}.modtimes = trials{trl}.tStart;
					else
						trials{trl}.tStart = trial.t1 - obj.eventWindow;
						trials{trl}.tEnd = trial.t1 + obj.eventWindow;
						trials{trl}.rStart = -obj.eventWindow;
						trials{trl}.rEnd = obj.eventWindow;
						trials{trl}.base = trial.t1;
						trials{trl}.basetime = trial.t1; % basetime > tStart
						trials{trl}.modtimes = trial.t1;
					end
					idx = spikes >= trials{trl}.tStart & spikes <= trials{trl}.tEnd;
					trials{trl}.spikes = spikes(idx);
					%===process the variable run
					var = trial.name;
					if isempty(vars{var})
						vars{var} = obj.eventList.vars(var);
						vars{var}.nTrials = 0;
						vars{var}.run = struct([]);
					end
					vars{var}.nTrials = vars{var}.nTrials + 1;
					vars{var}.run(vars{var}.nTrials).eventWindow = trials{trl}.eventWindow;
					if isempty(obj.eventWindow)
						vars{var}.run(vars{var}.nTrials).basetime = trial.t1 + obj.startOffset;
						vars{var}.run(vars{var}.nTrials).modtimes = trial.t1 + obj.startOffset;
					else
						vars{var}.run(vars{var}.nTrials).basetime = trial.t1;
						vars{var}.run(vars{var}.nTrials).modtimes = trial.t1;
					end
					vars{var}.run(vars{var}.nTrials).spikes = trials{trl}.spikes;
					vars{var}.run(vars{var}.nTrials).tDelta = trials{trl}.tDelta;
					vars{var}.run(vars{var}.nTrials).isCorrect = trials{trl}.isCorrect;
					vars{var}.run(vars{var}.nTrials).isBreak = trials{trl}.isBreak;
					vars{var}.run(vars{var}.nTrials).isIncorrect = trials{trl}.isIncorrect;
				end
				obj.tsList.tsParse{ps}.trials = trials;
				obj.tsList.tsParse{ps}.var = vars;
			end
			fprintf('Parsing spikes into trials/variables took %g ms\n',round(toc*1000))
			if obj.startOffset ~= 0
				obj.info{end+1} = sprintf('START OFFSET ACTIVE : %g', obj.startOffset);
			end
		end
		
	end
	
end

