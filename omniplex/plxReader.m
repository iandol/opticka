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
		function ego = plxReader(varargin)
			if nargin == 0; varargin.name = 'plxReader'; end
			if nargin>0; ego.parseArgs(varargin, ego.allowedProperties); end
			if isempty(ego.name); ego.name = 'plxReader'; end
			if isempty(ego.file);
				getFiles(ego,false);
			end
		end
		
		% ===================================================================
		%> @brief parse all data and sync plx / behaviour / eyelink info
		%>
		%> @param
		%> @return
		% ===================================================================
		function parse(ego)
			if isempty(ego.file)
				getFiles(ego, true);
				if isempty(ego.file); warning('No plexon file selected'); return; end
			end
			if isempty(ego.matfile)
				getFiles(ego);
				if isempty(ego.matfile); warning('No behavioural mat file selected'); return; end
			end
			ego.paths.oldDir = pwd;
			cd(ego.dir);
			readMat(ego);
			readSpikes(ego);
			getEvents(ego);
			if ego.isEDF == true
				loadEDF(ego);
			end
			parseSpikes(ego);
			generateInfo(ego);
			integrateEyeData(ego);
		end
		
		% ===================================================================
		%> @brief only parse what needs parsing
		%>
		%> @param
		%> @return
		% ===================================================================
		function lazyParse(ego)
			if isempty(ego.file)
				getFiles(ego, true);
				if isempty(ego.file); warning('No plexon file selected'); return; end
			end
			if isempty(ego.matfile)
				getFiles(ego);
				if isempty(ego.matfile); warning('No behavioural mat file selected'); return; end
			end
			ego.paths.oldDir = pwd;
			cd(ego.dir);
			if ~isa(ego.rE,'runExperiment')
				readMat(ego);
			end
			if isempty(ego.tsList)
				readSpikes(ego);
			end
			if isempty(ego.eventList)
				getEvents(ego);
			end
			if isempty(ego.eA) && ego.isEDF == true
				loadEDF(ego);
			end
			if ~isfield(ego.tsList.tsParse,'trials')
				parseSpikes(ego);
			end
			if isempty(ego.info)
				generateInfo(ego);
			end
			if ~isempty(ego.eventList) && ~isempty(ego.eA)
				integrateEyeData(ego);
			end
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function reparse(ego)
			ego.paths.oldDir = pwd;
			cd(ego.dir);
			getEvents(ego);
			parseSpikes(ego);
			generateInfo(ego);
			integrateEyeData(ego);
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function parseEvents(ego)
			cd(ego.dir);
			getEvents(ego);
			generateInfo(ego);
			if isa(ego.eA,'eyelinkAnalysis')
				integrateEyeData(ego);
			end
		end
		
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function LFPs = readLFPs(ego)
			cd(ego.dir);
			if isempty(ego.eventList); 
				getEvents(ego); 
			end
			tic
			[~, names] = plx_adchan_names(ego.file);
			[~, map] = plx_adchan_samplecounts(ego.file);
			[~, raw] = plx_ad_chanmap(ego.file);
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
				[adfreq, ~, ts, fn, ad] = plx_ad_v(ego.file, LFPs(j).index);

				tbase = 1 / adfreq;
				
				LFPs(j).recordingFrequency = adfreq;
				LFPs(j).timebase = tbase;
				LFPs(j).totalTimeStamps = ts;
				LFPs(j).totalDataPoints = fn;	
				
				time = [];
				sample = [];
				
				for i = 1:length(ts) % join each fragment together
					timefragment = linspace(ts(i), ts(i) + ( (fn(i)-1) * tbase ), fn(i)); %generate out times
					startsample = round(ts(i) * LFPs(j).recordingFrequency);
					samplefragment = linspace(startsample, startsample+fn(i)-1,fn(i)); %sample number
					time = [time timefragment];
					sample = [sample samplefragment];
					LFPs(j).usedtimeStamp(i) = ts(i);
					LFPs(j).eventSample(i) = round(LFPs(j).usedtimeStamp(i) * 40e3);
					LFPs(j).sample(i) = startsample;
				end
				if ~isequal(length(time), length(ad)); error('Reading LFP fragments from plexon file failed!'); end
				LFPs(j).data = ad;
				LFPs(j).time = time';
				LFPs(j).sample = sample';
				LFPs(j).nTrials = ego.eventList.nTrials;
				LFPs(j).nVars = ego.eventList.nVars;
			end
			
			fprintf('Loading LFPs took %g ms\n',round(toc*1000));
		end
		
		% ===================================================================
		%> @brief exportToRawSpikes 
		%>
		%> @param
		%> @return x spike data structure for spikes.m to read.
		% ===================================================================
		function x = exportToRawSpikes(ego, var, firstunit, StartTrial, EndTrial, trialtime, modtime, cuttime)
			if ~isempty(ego.cellmap)
				fprintf('Extracting Var=%g for Cell %g from PLX unit %g\n', var, firstunit, ego.cellmap(firstunit));
				raw = ego.tsList.tsParse{ego.cellmap(firstunit)};
			else
				fprintf('Extracting Var=%g for Cell %g from PLX unit %g \n', var, firstunit, firstunit);
				raw = ego.tsList.tsParse{firstunit};
			end
			if var > length(raw.var)
				errordlg('This Plexon File seems to be Incomplete, check filesize...')
			end
			raw = raw.var{var};
			v = num2str(ego.meta.matrix(var,:));
			v = regexprep(v,'\s+',' ');
			x.name = ['PLX#' num2str(var) '|' v];
			x.raw = raw;
			x.totaltrials = ego.eventList.minRuns;
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
			x.maxtime = ego.eventList.tMaxCorrect * x.conversion;
			a = 1;
			for tr = x.starttrial:x.endtrial
				x.trial(a).basetime = round(raw.run(tr).basetime * x.conversion); %convert from seconds to 0.1ms as that is what VS used
				x.trial(a).modtimes = 0;
				x.trial(a).mod{1} = round(raw.run(tr).spikes * x.conversion) - x.trial(a).basetime;
				a=a+1;
			end
			x.isPLX = true;
			x.tDelta = ego.eventList.vars(var).tDeltacorrect(x.starttrial:x.endtrial);
			x.startOffset = ego.startOffset;
			
		end
		
		% ===================================================================
		%> @brief 
		%> @param
		%> @return 
		% ===================================================================
		function isEDF = get.isEDF(ego)
			isEDF = false;
			if ~isempty(ego.edffile)
				isEDF = true;
			end
		end
		
		% ===================================================================
		%> @brief 
		%> @param
		%> @return 
		% ===================================================================
		function isPL2 = get.isPL2(ego)
			isPL2 = false;
			if ~isempty(regexpi(ego.file,'\.pl2$'))
				isPL2 = true;
			end
		end
		
		% ===================================================================
		%> @brief 
		%> @param
		%> @return 
		% ===================================================================
		function trodality = get.trodality(ego)
			if ~isfield(ego.ic,'Trodalness') || ~isempty(ego.ic.Trodalness)
				[~,~,~,~,ego.ic.Trodalness]=plx_information(ego.file);
			end
			trodality = max(ego.ic.Trodalness);
			if isempty(trodality); trodality = 0; end
		end
		
		% ===================================================================
		%> @brief Constructor
		%>
		%> @param varargin
		%> @return
		% ===================================================================
		function getFiles(ego, force)
			if ~exist('force','var')
				force = false;
			end
			if force == true || isempty(ego.file)
				[f,p] = uigetfile({'*.plx;*.pl2';'PlexonFiles'},'Load Plexon File');
				if ischar(f) && ~isempty(f)
					ego.file = f;
					ego.dir = p;
						ego.paths.oldDir = pwd;
					cd(ego.dir);
				else
					return
				end
			end
			if force == true || isempty(ego.matfile)
				[ego.matfile, ego.matdir] = uigetfile('*.mat',['Load Behaviour MAT File for ' ego.file]);
			end
			if force == true || isempty(ego.edffile)
				cd(ego.matdir)
				[~,f,~] = fileparts(ego.matfile);
				f = [f '.edf'];
				ff = regexprep(f,'\.edf','FIX\.edf','ignorecase');
				fff = regexprep(ff,'^[a-zA-Z]+\-','','ignorecase');
				if ~exist(f, 'file') && ~exist(ff,'file') && ~exist(fff,'file')
					[an, ~] = uigetfile('*.edf',['Load Eyelink EDF File for ' ego.matfile]);
					if ischar(an)
						ego.edffile = an;
					else
						ego.edffile = '';
					end
				elseif exist(f, 'file')
					ego.edffile = f;
				elseif exist(ff, 'file')
					ego.edffile = ff;
				elseif exist(fff, 'file')
					ego.edffile = fff;
				end
			end
		end
		
		% ===================================================================
		%> @brief Create a FieldTrip spike structure
		%>
		%> @param
		%> @return
		% ===================================================================
		function spike = getFieldTripSpikes(ego)
			dat = ego.tsList.tsParse;
			spike.label = ego.tsList.names;
			spike.nUnits = ego.tsList.nUnits;
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
			spike.sampleinfo = [];
			spike.cfg = struct;
			spike.cfg.dataset = ego.file;
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
					spike.sampleinfo(j,:) = [t.tStart*fs t.tEnd*fs];
					spike.cfg.trl(j,:) = [spike.trialtime(j,:) t.rStart*fs t.variable t.isCorrect];
				end
			end
			fprintf('Coverting spikes to fieldtrip format took %g ms\n',round(toc*1000));
		end
		
		% ===================================================================
		%> @brief 
		%> @param
		%> @return 
		% ===================================================================
		function integrateEyeData(ego)
			tic
			plxList = [ego.eventList.trials.variable]'; %var order list
			edfTrials = ego.eA.trials;
			edfTrials(ego.eA.incorrect.idx) = []; %remove incorrect trials
			edfList = [edfTrials.variable]';
			c1 = plxList([ego.eventList.trials.isCorrect]');
			c2 = edfList([edfTrials.correct]);
			if isequal(plxList,edfList) || isequal(c1,c2) %check our variable list orders are equal
				for i = 1:length(plxList)
					if plxList(i) == edfList(i)
						ego.eventList.trials(i).eye = edfTrials(i);
						sT = edfTrials(i).saccadeTimes/1e3;
						fS = min(sT(sT>0));
						ego.eventList.trials(i).saccadeTimes = sT;
						if ~isempty(fS)
							ego.eventList.trials(i).firstSaccade = fS;
						else
							ego.eventList.trials(i).firstSaccade = NaN;
						end
					else
						warning(['integrateEyeData: Trial ' num2str(i) ' Variable' num2str(plxList(i)) ' FAILED']);
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
		function handles = infoBox(ego, info)
			%[left bottom width height]
			if ~exist('info','var'), info = ego.info; end
			scr=get(0,'ScreenSize');
			width=scr(3);
			height=scr(4);
			handles.root = figure('Units','pixels','Position',[0 0 width/4 height],'Tag','PLXInfoFigure',...
				'Color',[0.9 0.9 0.9],'Toolbar','none','Name', ego.file);
			handles.display = uicontrol('Style','edit','Units','normalized','Position',[0 0.45 1 0.55],...
				'BackgroundColor',[0.3 0.3 0.3],'ForegroundColor',[1 1 0],'Max',500,...
				'FontSize',12,'FontWeight','bold','FontName','Helvetica','HorizontalAlignment','left');
			handles.comments = uicontrol('Style','edit','Units','normalized','Position',[0 0.4 1 0.05],...
				'BackgroundColor',[0.8 0.8 0.8],'ForegroundColor',[.1 .1 .1],'Max',500,...
				'FontSize',12,'FontWeight','bold','FontName','Helvetica','HorizontalAlignment','left',...
				'Callback',@editComment);%,'ButtonDownFcn',@editComment,'KeyReleaseFcn',@editComment);
			handles.axis = axes('Units','normalized','Position',[0.05 0.05 0.9 0.3]);
			if ~isempty(ego.eventList)
				drawEvents(ego,handles.axis);
			end
			set(handles.display,'String',info,'FontSize',12);
			set(handles.comments,'String',ego.comment,'FontSize',11);
			
			function editComment(src, ~)
				if ~exist('src','var');	return; end
				s = get(src,'String');
				if ~isempty(s)
					ego.comment = s;
				end
			end
		end
		
	end %---END PUBLIC METHODS---%
	
	%=======================================================================
	methods ( Hidden = true) %-------HIDDEN METHODS-----%
	%=======================================================================
	
		% ===================================================================
		%> @brief allows data from another plxReader object to be used,
		%> useful for example when you load LFP data in 1 plxReader and
		%> spikes in another but they are using the same behaviour files etc.
		%>
		%> @param
		%> @return
		% ===================================================================
		function syncData(ego, data)
			if isa(data,'plxReader')
				if strcmpi(ego.uuid, data.uuid)
					disp('Two plxReader objects are identical, skip syncing');
					return
				end
				if ~strcmpi(ego.matfile, data.matfile)
					warning('Different Behaviour mat files, can''t sync plxReaders');
					return
				end
				if isempty(ego.eventList) && ~isempty(data.eventList)
					ego.eventList = data.eventList;
				end
				if isempty(ego.tsList) && ~isempty(data.tsList)
					ego.tsList = data.tsList;
				end
				if isempty(ego.meta) && ~isempty(data.meta)
					ego.meta = data.meta;
				end
				if isempty(ego.rE) && ~isempty(data.rE)
					ego.rE = data.rE;
				end
				if isempty(ego.eA) && ~isempty(data.eA)
					ego.eA = data.eA;
				end
				if isempty(ego.info) && ~isempty(data.info)
					ego.info = data.info;
				end
			end
		end
		
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function drawEvents(ego,h)
			if ~exist('h','var')
				hh=figure;figpos(1,[2000 800]);set(gcf,'Color',[1 1 1]);
				h = axes;
				set(hh,'CurrentAxes',h);
			end
			axes(h);
			title(['EVENT PLOT: File:' ego.file]);
			xlabel('Time (s)');
			set(gca,'XGrid','on','XMinorGrid','on','Layer','bottom');
			hold on
			color = rand(3,ego.eventList.nVars);
			for j = 1:ego.eventList.nTrials
				trl = ego.eventList.trials(j);
				var = trl.variable;
				hl=line([trl.t1 trl.t1],[-.4 .4],'Color',color(:,var),'LineWidth',1);
				set(get(get(hl,'Annotation'),'LegendInformation'),'IconDisplayStyle','off'); % Exclude line from legend
				hl=line([trl.t2 trl.t2],[-.4 .4],'Color',color(:,var),'LineWidth',1);
				set(get(get(hl,'Annotation'),'LegendInformation'),'IconDisplayStyle','off'); % Exclude line from legend
				text(trl.t1,.41,['VAR: ' num2str(var) '\newlineTRL: ' num2str(j)],'FontSize',10);
				if isfield(trl,'firstSaccade'); sT = trl.firstSaccade; else sT = NaN; end
				text(trl.t1,-.41,['SAC: ' num2str(sT) '\newlineCOR: ' num2str(trl.isCorrect)],'FontSize',10);
			end
			plot(ego.eventList.startFix,zeros(size(ego.eventList.startFix)),'c.','MarkerSize',18);
			plot(ego.eventList.correct,zeros(size(ego.eventList.correct)),'g.','MarkerSize',18);
			plot(ego.eventList.breakFix,zeros(size(ego.eventList.breakFix)),'b.','MarkerSize',18);
			plot(ego.eventList.incorrect,zeros(size(ego.eventList.incorrect)),'r.','MarkerSize',18);
			axis([0 10 -.5 .5])
			name = {};
			name{end+1} = 'start fixation';
			name{end+1} = 'correct';
			name{end+1} = 'break fix';
			name{end+1} = 'incorrect';
			legend(name,'Location','NorthWest')
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
	
	end
	
	%=======================================================================
	methods ( Static = true) %-------STATIC METHODS-----%
	%=======================================================================
	
		% ===================================================================
		%> @brief 
		%> This needs to be static as it may load data called "ego" which
		%> will conflict with the ego object in the class.
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
		function loadEDF(ego,pn)
			if ~exist('pn','var')
				if exist(ego.matdir,'dir')
					pn = ego.matdir;
				else
					pn = ego.dir;
				end
			end
			if exist(ego.edffile,'file')
				oldd=pwd;
				cd(pn);
				if ~isempty(ego.eA) && isa(ego.eA,'eyelinkAnalysis')
					ego.eA.file = ego.edffile;
					ego.eA.dir = pn;
					ego.eA.trialOverride = ego.eventList.trials;
				else
					in = struct('file',ego.edffile,'dir',pn,...
						'trialOverride',ego.eventList.trials);
					ego.eA = eyelinkAnalysis(in);
				end
				if isa(ego.rE.screen,'screenManager')
					ego.eA.pixelsPerCm = ego.rE.screen.pixelsPerCm;
					ego.eA.distance = ego.rE.screen.distance;
					ego.eA.xCenter = ego.rE.screen.xCenter;
					ego.eA.yCenter = ego.rE.screen.yCenter;
				end
				if isstruct(ego.rE.tS)
					ego.eA.tS = ego.rE.tS;
				end
				load(ego.eA);
				parse(ego.eA);
				fixVarNames(ego.eA);
				cd(oldd)
			end
		end
		
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function readMat(ego,override)
			if ~exist('override','var'); override = false; end
			if override == true || isempty(ego.rE)
				if exist(ego.matdir, 'dir')
					[ego.meta, ego.rE] = ego.loadMat(ego.matfile, ego.matdir);
				else
					[ego.meta, ego.rE] = ego.loadMat(ego.matfile, ego.dir);
				end
			end
		end
			
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function generateInfo(ego)
			tic
			if ~isfield(ego.ic, 'Freq')
				[ego.ic.OpenedFileName, ego.ic.Version, ego.ic.Freq, ego.ic.Comment, ego.ic.Trodalness,...
					ego.ic.NPW, ego.ic.PreThresh, ego.ic.SpikePeakV, ego.ic.SpikeADResBits,...
					ego.ic.SlowPeakV, ego.ic.SlowADResBits, ego.ic.Duration, ego.ic.DateTime] = plx_information(ego.file);
				if exist('plx_mexplex_version','file')
					ego.ic.sdkversion = plx_mexplex_version();
				else
					ego.ic.sdkversion = -1;
				end
			end
			ego.info = {};
			if ego.isPL2
				if isempty(ego.pl2); ego.pl2 = PL2GetFileIndex(ego.file); end
				ego.info{1} = sprintf('PL2 File : %s', ego.ic.OpenedFileName);
				ego.info{end+1} = sprintf('\tPL2 File Length : %d', ego.pl2.FileLength);
				ego.info{end+1} = sprintf('\tPL2 Creator : %s %s', ego.pl2.CreatorSoftwareName, ego.pl2.CreatorSoftwareVersion);
			else
				ego.info{1} = sprintf('PLX File : %s', ego.ic.OpenedFileName);
			end
			ego.info{end+1} = sprintf('Behavioural File : %s', ego.matfile);
			ego.info{end+1} = ' ';
			ego.info{end+1} = sprintf('Behavioural File Comment : %s', ego.meta.comments);
			ego.info{end+1} = ' ';
			ego.info{end+1} = sprintf('Plexon File Comment : %s', ego.ic.Comment);
			ego.info{end+1} = sprintf('Version : %g', ego.ic.Version);
			ego.info{end+1} = sprintf('SDK Version : %g', ego.ic.sdkversion);
			ego.info{end+1} = sprintf('Frequency : %g Hz', ego.ic.Freq);
			ego.info{end+1} = sprintf('Plexon Date/Time : %s', num2str(ego.ic.DateTime));
			ego.info{end+1} = sprintf('Duration : %g seconds', ego.ic.Duration);
			ego.info{end+1} = sprintf('Num Pts Per Wave : %g', ego.ic.NPW);
			ego.info{end+1} = sprintf('Num Pts Pre-Threshold : %g', ego.ic.PreThresh);
			
			switch ego.trodality
				case 1
					ego.info{end+1} = sprintf('Data type : Single Electrode');
				case 2
					ego.info{end+1} = sprintf('Data type : Stereotrode');
				case 4
					ego.info{end+1} = sprintf('Data type : Tetrode');
				otherwise
					ego.info{end+1} = sprintf('Data type : Unknown');
			end
			ego.info{end+1} = sprintf('Spike Peak Voltage (mV) : %g', ego.ic.SpikePeakV);
			ego.info{end+1} = sprintf('Spike A/D Resolution (bits) : %g', ego.ic.SpikeADResBits);
			ego.info{end+1} = sprintf('Slow A/D Peak Voltage (mV) : %g', ego.ic.SlowPeakV);
			ego.info{end+1} = sprintf('Slow A/D Resolution (bits) : %g', ego.ic.SlowADResBits);
			
			if isa(ego.rE,'runExperiment')
				ego.info{end+1} = ' ';
				rE = ego.rE; %#ok<*PROP>
				ego.info{end+1} = sprintf('# of Stimulus Variables : %g', rE.task.nVars);
				ego.info{end+1} = sprintf('Total # of Variable Values: %g', rE.task.minBlocks);
				ego.info{end+1} = sprintf('Random Seed : %g', rE.task.randomSeed);
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
				ego.info{end+1} = sprintf('Variable Names : %s', names(5:end));
				ego.info{end+1} = sprintf('Variable Values : %s', vals(5:end));
				names = '';
				for i = 1:rE.stimuli.n
					names = [names ' | ' rE.stimuli{i}.name ':' rE.stimuli{i}.family];
				end
				ego.info{end+1} = sprintf('Stimulus Names : %s', names(4:end));
			end
			if ~isempty(ego.eventList)
				ego.info{end+1} = ' ';
				ego.info{end+1} = sprintf('Number of Strobed Variables : %g', ego.eventList.nVars);
				ego.info{end+1} = sprintf('Total # Correct Trials :  %g', length(ego.eventList.correct));
				ego.info{end+1} = sprintf('Total # BreakFix Trials :  %g', length(ego.eventList.breakFix));
				ego.info{end+1} = sprintf('Total # Incorrect Trials :  %g', length(ego.eventList.incorrect));
				ego.info{end+1} = sprintf('Minimum # of Trials per variable :  %g', ego.eventList.minRuns);
				ego.info{end+1} = sprintf('Maximum # of Trials per variable :  %g', ego.eventList.maxRuns);
				ego.info{end+1} = sprintf('Shortest Trial Time (all/correct):  %g / %g s', ego.eventList.tMin,ego.eventList.tMinCorrect);
				ego.info{end+1} = sprintf('Longest Trial Time (all/correct):  %g / %g s', ego.eventList.tMax,ego.eventList.tMaxCorrect);
			end
			if ~isempty(ego.tsList)
				ego.info{end+1} = ' ';
				ego.info{end+1} = ['Total Channel list : ' num2str(ego.tsList.chMap)];
				ego.info{end+1} = ['Trodality Reduction : ' num2str(ego.tsList.trodreduction)];
				ego.info{end+1} = ['Number of Active channels : ' num2str(ego.tsList.nCh)];
				ego.info{end+1} = ['Number of Active units : ' num2str(ego.tsList.nUnits)];
				for i=1:ego.tsList.nCh
					ego.info{end+1} = ['Channel ' num2str(ego.tsList.chMap(i)) ' unit list (0=unsorted) : ' num2str(ego.tsList.unitMap(i).units)];
				end
				ego.info{end+1} = ['Ch/Unit Names : ' ego.tsList.namelist];
				ego.info{end+1} = sprintf('Number of Parsed Spike Trials : %g', length(ego.tsList.tsParse{1}.trials));
				ego.info{end+1} = sprintf('Data window around event : %s ', num2str(ego.eventWindow));
				ego.info{end+1} = sprintf('Start Offset : %g ', ego.startOffset);
			end
			if ~isempty(ego.eA)
				saccs = [ego.eA.trials.firstSaccade];
				saccs(isnan(saccs)) = [];
				saccs(saccs<0) = [];
				mins = min(saccs);
				maxs = max(saccs);
				[avgs,es] = stderr(saccs);
				ns = length(saccs);
				ego.info{end+1} = ' ';
				ego.info{end+1} = ['Eyelink data Parsed trial total : ' num2str(length(ego.eA.trials))];
				ego.info{end+1} = ['Eyelink trial bug override : ' num2str(ego.eA.needOverride)];
				ego.info{end+1} = sprintf('Valid First Post-Stimulus Saccades (#%g): %.4g ± %.3g (range %g:%g )',ns,avgs/1e3,es/1e3,mins/1e3,maxs/1e3);
			end
			fprintf('Generating info took %g ms\n',round(toc*1000))
			ego.info{end+1} = ' ';
			ego.info = ego.info';
			ego.meta.info = ego.info;
		end
		
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function getEvents(ego)
			readMat(ego); %make sure we've loaded the behavioural file first
			tic
			[~,eventNames] = plx_event_names(ego.file);
			[~,eventIndex] = plx_event_chanmap(ego.file);
			eventNames = cellstr(eventNames);
			
			idx = strcmpi(eventNames,'Strobed');
			[a, b, c] = plx_event_ts(ego.file,eventIndex(idx));
			if isempty(a) || a == 0
				ego.eventList = struct();
				warning('No strobe events detected!!!');
				return
			end
			idx = find(c < 1); %check for zer or lower event numbers, remove
			if ~isempty(idx)
				c(idx)=[];
				b(idx) = [];
			end
			idx = find(c > ego.rE.task.minBlocks & c < 32700); %check for invalid event numbers, remove
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
			[~,start] = plx_event_ts(ego.file,eventIndex(idx)); %start event
			idx = strcmpi(eventNames, 'Stop');
			[~,stop] = plx_event_ts(ego.file,eventIndex(idx)); %stop event
			idx = strcmpi(eventNames, 'EVT19'); 
			[~,b19] = plx_event_ts(ego.file,eventIndex(idx)); %currently 19 is fix start
			idx = strcmpi(eventNames, 'EVT20');
			[~,b20] = plx_event_ts(ego.file,eventIndex(idx)); %20 is correct
			idx = strcmpi(eventNames, 'EVT21');
			[~,b21] = plx_event_ts(ego.file,eventIndex(idx)); %21 is breakfix
			idx = strcmpi(eventNames, 'EVT22');
			[~,b22] = plx_event_ts(ego.file,eventIndex(idx)); %22 is incorrect

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
			eL.trials = struct('variable',[],'index',[]);
			eL.trials(eL.nTrials,1).variable = [];
			eL.vars = struct('name',[],'nRepeats',[],'index',[],'responseIndex',[],'t1',[],'t2',[],...
				'nCorrect',[],'nBreakFix',[],'nIncorrect',[],'t1correct',[],'t2correct',[],...
				't1breakfix',[],'t2breakfix',[],'t1incorrect',[],'t2incorrect',[]);
			eL.vars(eL.nVars,1).variable = [];
			
			aa = 1; cidx = 1; bidx = 1; iidx = 1;
			
			for i = 1:2:eL.n % iterate through all trials
				
				var = eL.values(i);
				eL.trials(aa).variable = var; 
				eL.trials(aa).index = aa;				
				eL.trials(aa).t1 = eL.times(i);
				eL.trials(aa).t2 = eL.times(i+1);
				eL.trials(aa).tDelta = eL.trials(aa).t2 - eL.trials(aa).t1;
				
				if isempty(eL.vars(var).variable)
					eL.vars(var).variable = var;
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
				
				tc = eL.correct > eL.trials(aa).t2 - ego.eventSearchWindow & eL.correct < eL.trials(aa).t2 + ego.eventSearchWindow;
				tb = eL.breakFix > eL.trials(aa).t2 - ego.eventSearchWindow & eL.breakFix < eL.trials(aa).t2 + ego.eventSearchWindow;
				ti = eL.incorrect > eL.trials(aa).t2 - ego.eventSearchWindow & eL.incorrect < eL.trials(aa).t2 + ego.eventSearchWindow;
				
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
			ego.eventList = eL;
			fprintf('Loading all event markers took %g ms\n',round(toc*1000))

			ego.meta.modtime = floor(ego.eventList.tMaxCorrect * 10000);
			ego.meta.trialtime = ego.meta.modtime;
			m = [ego.rE.task.outIndex ego.rE.task.outMap getMeta(ego.rE.task)];
			m = m(1:ego.eventList.nVars,:);
			[~,ix] = sort(m(:,1),1);
			m = m(ix,:);
			ego.meta.matrix = m;	
			clear eL m
		end
		
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function readSpikes(ego)
			tic
			ego.tsList = struct();
			[tscounts, wfcounts, evcounts, slowcounts]	= plx_info(ego.file,1);
			[~,chnames]												= plx_chan_names(ego.file);
			[~,chmap]												= plx_chanmap(ego.file);
			chnames = cellstr(chnames);
			
			%!!!WARNING tscounts column 1 is empty, read plx_info for details
			%we remove the first column here so we don't have the idx-1 issue
			tscounts = tscounts(:,2:end);
			
			[a,b]=ind2sub(size(tscounts),find(tscounts>0)); %finds row and columns of nonzero values
			ego.tsList.chMap = unique(b)';
			a = 1;
			ego.tsList.trodreduction = false;
			prevcount = inf;
			nCh = 0;
			nUnit = 0;
			for i = 1:length(ego.tsList.chMap)
				units = find(tscounts(:,ego.tsList.chMap(i))>0)';
				n = length(units);
				counts = tscounts(units,ego.tsList.chMap(i))';
				units = units - 1; %fix the index as plxuses 0 as unsorted
				if a == 1 || ~isequal(counts, prevcount);
					ego.tsList.unitMap(a).units = units; 
					ego.tsList.unitMap(a).ch = chmap(ego.tsList.chMap(i));
					ego.tsList.unitMap(a).chIdx = ego.tsList.chMap(i);
					ego.tsList.unitMap(a).n = n;
					ego.tsList.unitMap(a).counts = counts;
					prevcount = counts;
					nCh = a;
					nUnit = nUnit + n;
					a = a + 1;
				end
			end
			if ego.trodality > 1 && a < i
				ego.tsList.trodreduction = true;	
				disp('---! Removed tetrode channels with identical spike numbers !---');
				end
			ego.tsList.chMap = ego.tsList(1).chMap;
			ego.tsList.chIndex = ego.tsList.chMap; 
			ego.tsList.chMap = chmap(ego.tsList(1).chMap); %fucking pain channel number is different to ch index!!!
			ego.tsList.activeChIndex = [ego.tsList.unitMap(:).ch]; %just the active channels
			ego.tsList.activeCh = chmap(ego.tsList.activeChIndex); %mapped to the channel numbers
			ego.tsList.nCh = nCh; 
			ego.tsList.nUnits = nUnit;

			ego.tsList.ts = cell(ego.tsList.nUnits, 1);
			ego.tsList.tsN = ego.tsList.ts;
			ego.tsList.tsParse = ego.tsList.ts;
			ego.tsList.namelist = ''; list = 'UabcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRST';
			a = 1; 
			for ich = 1:length(ego.tsList.activeCh)
				ch = ego.tsList.activeCh(ich);
				name = chnames{ego.tsList.activeChIndex(ich)};
				unitN = ego.tsList.unitMap(ich).n;
				for iunit = 1:unitN
					
					unit = ego.tsList.unitMap(ich).units(iunit);
					[tsN,ts] = plx_ts(ego.file, ch, unit);
					if ~isequal(tsN,ego.tsList.unitMap(ich).counts(iunit))
						error('SPIKE PARSING COUNT ERROR!!!')
					end
					ego.tsList.tsN{a} = tsN;
					ego.tsList.ts{a} = ts;
					
					t = '';
					t = [num2str(a) ':' name list(iunit) '=' num2str(tsN)];
					ego.tsList.names{a} = t;
					ego.tsList.namelist = [ego.tsList.namelist ' ' t];
					
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
		function parseSpikes(ego)
			tic
			for ps = 1:ego.tsList.nUnits
				spikes = ego.tsList.ts{ps};
				trials = cell(ego.eventList.nTrials,1);
				vars = cell(ego.eventList.nVars,1);
				for trl = 1:ego.eventList.nTrials
					%===process the trial
					trial = ego.eventList.trials(trl);
					trials{trl} = trial;
					trials{trl}.startOffset = ego.startOffset;
					trials{trl}.eventWindow = ego.eventWindow;
					if isempty(ego.eventWindow) %use event markers and startOffset
						trials{trl}.tStart = trial.t1 + ego.startOffset;
						trials{trl}.tEnd = trial.t2;
						trials{trl}.rStart = ego.startOffset;
						trials{trl}.rEnd = trial.t2 - trial.t1;
						trials{trl}.base = trial.t1;
						trials{trl}.basetime = trials{trl}.tStart; %make offset invisible for systems that can't handle -time
						trials{trl}.modtimes = trials{trl}.tStart;
					else
						trials{trl}.tStart = trial.t1 - ego.eventWindow;
						trials{trl}.tEnd = trial.t1 + ego.eventWindow;
						trials{trl}.rStart = -ego.eventWindow;
						trials{trl}.rEnd = ego.eventWindow;
						trials{trl}.base = trial.t1;
						trials{trl}.basetime = trial.t1; % basetime > tStart
						trials{trl}.modtimes = trial.t1;
					end
					idx = spikes >= trials{trl}.tStart & spikes <= trials{trl}.tEnd;
					trials{trl}.spikes = spikes(idx);
					%===process the variable run
					var = trial.variable;
					if isempty(vars{var})
						vars{var} = ego.eventList.vars(var);
						vars{var}.nTrials = 0;
						vars{var}.run = struct([]);
					end
					vars{var}.nTrials = vars{var}.nTrials + 1;
					vars{var}.run(vars{var}.nTrials).eventWindow = trials{trl}.eventWindow;
					if isempty(ego.eventWindow)
						vars{var}.run(vars{var}.nTrials).basetime = trial.t1 + ego.startOffset;
						vars{var}.run(vars{var}.nTrials).modtimes = trial.t1 + ego.startOffset;
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
				ego.tsList.tsParse{ps}.trials = trials;
				ego.tsList.tsParse{ps}.var = vars;
			end
			fprintf('Parsing spikes into trials/variables took %g ms\n',round(toc*1000))
			if ego.startOffset ~= 0
				ego.info{end+1} = sprintf('START OFFSET ACTIVE : %g', ego.startOffset);
			end
		end
		
	end
	
end

