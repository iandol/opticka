classdef plxReader < optickaCore
%> PLXREADER Reads in Plexon .plx and .pl2 files along with metadata and
%> eyelink EDF files. Parses the trial event / behaviour structure. 
%> Integrates EDF events and raw X/Y data into trial LFP/spike structures.
%> Converts into Fieldtrip and custom structures.
	
	%------------------PUBLIC PROPERTIES----------%
	properties
		%> plx/pl2 file name
		file@char
		%> file directory
		dir@char
		%> the opticka experimental filename
		matfile@char
		%> the opticka file directory
		matdir@char
		%> Eyelink edf file name (should be same directory as opticka file).
		edffile@char
		%> use the event on/off markers if empty, or a timerange around the event on otherwise
		eventWindow@double			= []
		%> the window to check before/after trial end for behavioural marker
		eventSearchWindow@double	= 0.2
		%> used by legacy spikes to allow negative time offsets
		startOffset@double			= 0
		%> Use first saccade to realign time 0 for data?
		saccadeRealign@logical		= false
		%> reduce the duplicate tetrode channels?
		channelReduction@logical	= true
		%> verbose?
		verbose							= false
	end
	
	%------------------HIDDEN PROPERTIES----------%
	properties (Hidden = true)
		%> used for legacy cell channel mapping (SMRs only have 6 channels)
		cellmap@double
	end
	
	%------------------VISIBLE PROPERTIES----------%
	properties (SetAccess = {?analysisCore}, GetAccess = public)
		%> info formatted in cellstrings for display
		info@cell
		%> event list parsed
		eventList@struct
		%> timestamped parsed spikes
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
	properties (SetAccess = protected, Dependent = true)
		%> is this a PL2 file?
		isPL2@logical
		%> is an EDF eyelink file present?
		isEDF@logical
		%> is trodal?
		trodality@double
	end
	
	%------------------PRIVATE PROPERTIES----------%
	properties (SetAccess = private, GetAccess = private)
		%>info box handles
		ibhandles@struct				= struct()
		%> info cache to speed up generating info{}
		ic@struct						= struct()
		%> allowed properties passed to object upon construction, see optickaCore.parseArgs()
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
		function me = plxReader(varargin)
			if nargin == 0; varargin.name = 'plxReader'; end
			me=me@optickaCore(varargin); %superclass constructor
			if nargin>0; me.parseArgs(varargin, me.allowedProperties); end
			if isempty(me.name); me.name = 'plxReader'; end
			if isempty(me.file);
				getFiles(me,false);
			end
		end
		
		% ===================================================================
		%> @brief parse all data denovo and sync plx / behaviour / eyelink info
		%>
		%> @param
		%> @return
		% ===================================================================
		function parse(me)
			if isempty(me.file)
				getFiles(me, true);
				if isempty(me.file); warning('No plexon file selected'); return; end
			end
			if isempty(me.matfile)
				getFiles(me);
				if isempty(me.matfile); warning('No behavioural mat file selected'); return; end
			end
			checkPaths(me);
			me.paths.oldDir = pwd;
			cd(me.dir);
			readMat(me);
			readSpikes(me);
			getEvents(me);
			if me.isEDF == true
				loadEDF(me);
				integrateEyeData(me);
			end
			parseSpikes(me);
			generateInfo(me);
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
			%> @return
		% ===================================================================
		function reparse(me)
			me.paths.oldDir = pwd;
			cd(me.dir);
			getEvents(me);
			if me.isEDF == true
				parse(me.eA); fixVarNames(me.eA);
				integrateEyeData(me);
			end
			parseSpikes(me);
			generateInfo(me);
		end
		
		% ===================================================================
		%> @brief only parse the behavioural events and EDF, used by LFPAnalysis
		%>
		%> @param
		%> @return
		% ===================================================================
		function parseEvents(me)
			cd(me.dir);
			if ~isa(me.rE,'runExperiment') || isempty(me.rE)
				readMat(me);
			end
			getEvents(me);
			if me.isEDF == true
				if isempty(me.eA) && me.isEDF == true
					loadEDF(me);
				end
				integrateEyeData(me);
			end
			generateInfo(me);
		end
		
		% ===================================================================
		%> @brief only parse what needs parsing
		%>
		%> @param
		%> @return
		% ===================================================================
		function lazyParse(me)
			if isempty(me.file)
				getFiles(me, true);
				if isempty(me.file); warning('No plexon file selected'); return; end
			end
			if isempty(me.matfile)
				getFiles(me);
				if isempty(me.matfile); warning('No behavioural mat file selected'); return; end
			end
			me.paths.oldDir = pwd;
			cd(me.dir);
			if ~isa(me.rE,'runExperiment') || isempty(me.rE)
				readMat(me);
			end
			if isempty(me.tsList)
				readSpikes(me);
			end
			if isempty(me.eventList)
				getEvents(me);
			end
			if isempty(me.eA) && me.isEDF == true
				loadEDF(me);
			end
			if ~isempty(me.eventList) && ~isempty(me.eA)
				integrateEyeData(me);
			end
			if ~isfield(me.tsList.tsParse,'trials')
				parseSpikes(me);
			end
			generateInfo(me);
		end
		
		% ===================================================================
		%> @brief read continuous LFP from PLX/PL2 file into a structure
		%>
		%> @param
		%> @return
		% ===================================================================
		function LFPs = readLFPs(me)
			cd(me.dir);
			if isempty(me.eventList); 
				getEvents(me); 
			end
			tlfp = tic;
			[~, names] = plx_adchan_names(me.file);
			[~, map] = plx_adchan_samplecounts(me.file);
			[~, raw] = plx_ad_chanmap(me.file);
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
						LFPs(aa).index = raw(idx(j)); 
						LFPs(aa).channel = num;
						LFPs(aa).count = map(idx(j));
						LFPs(aa).reparse = false;
						LFPs(aa).trials = struct([]); 
						LFPs(aa).vars = struct([]); %#ok<*AGROW>
						aa = aa + 1;
					end
				end
			end
			
			for j = 1:length(LFPs)
				[adfreq, ~, ts, fn, ad] = plx_ad_v(me.file, LFPs(j).index);

				tbase = 1 / adfreq;
				
				LFPs(j).recordingFrequency = adfreq;
				LFPs(j).timebase = tbase;
				LFPs(j).totalTimeStamps = ts;
				LFPs(j).totalDataPoints = fn;	
				
				time = single([]);
				sample = int32([]);
				
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
				LFPs(j).nTrials = me.eventList.nTrials;
				LFPs(j).nVars = me.eventList.nVars;
			end
			
			fprintf('<strong>:#:</strong> Loading raw LFP data took <strong>%g ms</strong>\n',round(toc(tlfp)*1000));
		end
		
		
		% ===================================================================
		%> @brief 
		%> @param
		%> @return 
		% ===================================================================
		function isEDF = get.isEDF(me)
			isEDF = false;
			if ~isempty(me.edffile) && exist([me.matdir filesep me.edffile],'file');
				isEDF = true;
			end
		end
		
		% ===================================================================
		%> @brief 
		%> @param
		%> @return 
		% ===================================================================
		function isPL2 = get.isPL2(me)
			isPL2 = false;
			if ~isempty(regexpi(me.file,'\.pl2$'))
				isPL2 = true;
			end
		end
		
		% ===================================================================
		%> @brief 
		%> @param
		%> @return 
		% ===================================================================
		function trodality = get.trodality(me)
			trodality = [];
			try
				if ~isfield(me.ic,'Trodalness') || ~isempty(me.ic.Trodalness)
					[~,~,~,~,me.ic.Trodalness]=plx_information(me.file);
				end
				trodality = max(me.ic.Trodalness);
			end
			if isempty(trodality); trodality = 0; end
		end
		
		% ===================================================================
		%> @brief Create a FieldTrip spike structure
		%>
		%> @param
		%> @return
		% ===================================================================
		function spike = getFieldTripSpikes(me)
			tft = tic;
			dat								= me.tsList.tsParse;
			spike.label						= me.tsList.names;
			spike.nUnits					= me.tsList.nUnits; 
			bCell								= cell(1,spike.nUnits);
			spike.timestamp				= bCell;
			spike.waveform					= bCell;
			spike.time						= bCell;
			spike.trial						= bCell;
			spike.unit						= bCell;
			spike.hdr						= [];
			spike.hdr.FileHeader.Frequency = 40e3;
			spike.hdr.FileHeader.Beg	= 0;
			spike.hdr.FileHeader.End	= Inf;
			spike.dimord					= '{chan}_lead_time_spike';
			spike.trialtime				= [];
			spike.sampleinfo				= [];
			spike.saccadeRealign			= me.saccadeRealign;
			spike.cfg						= struct;
			spike.cfg.dataset				= me.file;
			spike.cfg.headerformat		= 'plexon_plx_v2';
			spike.cfg.dataformat			= spike.cfg.headerformat;
			spike.cfg.eventformat		= spike.cfg.headerformat;
			spike.cfg.trl					= [];
			fs									= spike.hdr.FileHeader.Frequency;
			for j = 1:length(dat{1}.trials)
				for k = 1:spike.nUnits
					t									= dat{k}.trials{j};
					s									= t.spikes';
					w									= t.waves';
					spike.trial{k}					= [spike.trial{k} ones(1,length(s))*j];
					if me.saccadeRealign && isfield(me.eventList.trials,'firstSaccade')
						fS								= me.eventList.trials(j).firstSaccade;
						if isnan(fS); fS = 0; end
						spike.firstSaccade(j)	= fS;
						spike.timestamp{k}		= [spike.timestamp{k} s*fs];
						spike.waveform{k}			= [spike.waveform{k}, w];
						spike.time{k}				= [spike.time{k} (s - t.base) - fS];
						spike.trialtime(j,:)		= [t.rStart-fS t.rEnd-fS];
						spike.sampleinfo(j,:)	= [t.tStart*fs t.tEnd*fs];
					else
						spike.timestamp{k}		= [spike.timestamp{k} s*fs];
						spike.waveform{k}			= [spike.waveform{k}, w];
						spike.time{k}				= [spike.time{k} s-t.base];
						spike.trialtime(j,:)		= [t.rStart t.rEnd];
						spike.sampleinfo(j,:)	= [t.tStart*fs t.tEnd*fs];
					end
					spike.cfg.trl(j,:)			= [spike.trialtime(j,:) t.rStart*fs t.variable t.isCorrect];
				end
			end
			for k = 1:spike.nUnits
				clear w;
				w(1,:,:) = spike.waveform{k};
				spike.waveform{k} = w;
			end
			fprintf('<strong>:#:</strong> Converting spikes to fieldtrip format took <strong>%g ms</strong>\n',round(toc(tft)*1000));
		end
		
		% ===================================================================
		%> @brief 
		%> @param
		%> @return 
		% ===================================================================
		function integrateEyeData(me)
			ted = tic;
			plxList = [me.eventList.trials.variable]'; %var order list
			edfTrials = me.eA.trials;
			edfTrials(me.eA.incorrect.idx) = []; %remove incorrect trials
			edfList = [edfTrials.variable]';
			c1 = plxList([me.eventList.trials.isCorrect]');
			c2 = edfList([edfTrials.correct]);
			if length(edfList) > length(plxList)
				edfList = edfList(1:length(plxList));
			end
			if length(c2) > length(c1)
				c2 = c2(1:length(c1));
			end
			if isequal(plxList,edfList) || isequal(c1,c2) %check our variable list orders are equal
				for i = 1:length(plxList)
					if edfTrials(i).correctedIndex == me.eventList.trials(i).index
						me.eventList.trials(i).eye = edfTrials(i);
						me.eventList.trials(i).saccadeTimes = edfTrials(i).saccadeTimes/1e3;
						if isfield(edfTrials,'firstSaccade')
							me.eventList.trials(i).firstSaccade = edfTrials(i).firstSaccade / 1e3;
						else
							sT = me.eventList.trials(i).saccadeTimes;
							fS = min(sT(sT>0));
							if ~isempty(fS)
								me.eventList.trials(i).firstSaccade = fS;
							else
								me.eventList.trials(i).firstSaccade = NaN;
							end
						end
						if isfield(edfTrials,'sampleSaccades')
							me.eventList.trials(i).sampleSaccades = edfTrials(i).sampleSaccades;
						else
							me.eventList.trials(i).sampleSaccades = NaN;
						end
						if isfield(edfTrials,'microSaccades')
							me.eventList.trials(i).microSaccades = edfTrials(i).microSaccades;
						else
							me.eventList.trials(i).microSaccades = NaN;
						end
					else
						warning(['integrateEyeData: Trial ' num2str(i) ' Variable' num2str(plxList(i)) ' FAILED']);
					end
				end
			else
				warning('Integrating eyelink trials into plxReader trials failed...');
			end
			fprintf('<strong>:#:</strong> Integrating eye data into event data took <strong>%g ms</strong>\n',round(toc(ted)*1000));
		end
		
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function handles = infoBox(me, info)
			fs = 10;
% 			if ismac
% 				[s,c]=system('system_profiler SPDisplaysDataType');
% 				if s == 0
% 					if ~isempty(regexpi(c,'Retina LCD'))
% 						fs = 7;
% 					end
% 				end
% 			end
			if ~exist('info','var')
				me.generateInfo();
				info = me.info; 
			end
			scr=get(0,'ScreenSize');%[left bottom width height]
			width=scr(3);
			height=scr(4);
			handles.root = figure('Units','pixels','Position',[0 0 width/4 height],'Tag','PLXInfoFigure',...
				'Color',[0.9 0.9 0.9],'Toolbar','none','Name', me.file);
			handles.display = uicontrol('Style','edit','Units','normalized','Position',[0 0.35 1 0.65],...
				'BackgroundColor',[0.3 0.3 0.3],'ForegroundColor',[1 1 0],'Max',500,...
				'FontSize',fs,'FontWeight','bold','FontName','Helvetica','HorizontalAlignment','left');
			handles.comments = uicontrol('Style','edit','Units','normalized','Position',[0 0.3 1 0.05],...
				'BackgroundColor',[0.8 0.8 0.8],'ForegroundColor',[.1 .1 .1],'Max',500,...
				'FontSize',fs,'FontWeight','bold','FontName','Helvetica','HorizontalAlignment','left',...
				'Callback',@editComment);%,'ButtonDownFcn',@editComment,'KeyReleaseFcn',@editComment);
			handles.axis = axes('Units','normalized','Position',[0.05 0.05 0.9 0.2],...
				'ButtonDownFcn',@deferDraw,'UserData','empty');
			title(handles.axis,'Click Axis to draw Event Data');
			set(handles.display,'String',info,'FontSize',fs);
			set(handles.comments,'String',me.comment,'FontSize',fs);
			me.ibhandles = handles;
			
			function deferDraw(src, ~)
				title(me.ibhandles.axis,'Please wait...');
				drawnow;
				hh = get(me.ibhandles.axis,'UserData');
				if strcmpi(hh,'empty')
					if ~isempty(me.eventList)
						drawEvents(me,me.ibhandles.axis);
					end
				end
			end
			
			function editComment(src, ~)
				if ~exist('src','var');	return; end
				s = get(src,'String');
				if ~isempty(s)
					me.comment = s;
				end
			end
		end
		
	end %---END PUBLIC METHODS---%
	
	%=======================================================================
	methods ( Hidden = true) %-------HIDDEN METHODS-----%
	%=======================================================================
	
		% ===================================================================
		%> @brief generate text info about loaded data
		%>
		%> @param
		%> @return
		% ===================================================================
		function info = generateInfo(me)
			infoTic=tic;
			oldInfo = me.info;
			me.info = {};
			try
				if ~isfield(me.ic, 'Freq')
					cd(me.dir);
					[me.ic.OpenedFileName, me.ic.Version, me.ic.Freq, me.ic.Comment, me.ic.Trodalness,...
						me.ic.NPW, me.ic.PreThresh, me.ic.SpikePeakV, me.ic.SpikeADResBits,...
						me.ic.SlowPeakV, me.ic.SlowADResBits, me.ic.Duration, me.ic.DateTime] = plx_information(me.file);
					if exist('plx_mexplex_version','file')
						me.ic.sdkversion = plx_mexplex_version();
					else
						me.ic.sdkversion = -1;
					end
				end
				if me.isPL2
					if isempty(me.pl2); me.pl2 = PL2GetFileIndex(me.file); end
					me.info{1} = sprintf('PL2 File : %s', me.ic.OpenedFileName);
					me.info{end+1} = sprintf('\tPL2 File Length : %d', me.pl2.FileLength);
					me.info{end+1} = sprintf('\tPL2 Creator : %s %s', me.pl2.CreatorSoftwareName, me.pl2.CreatorSoftwareVersion);
				else
					me.info{1} = sprintf('PLX File : %s', me.ic.OpenedFileName);
				end
				me.info{end+1} = sprintf('Behavioural File : %s', me.matfile);
				me.info{end+1} = ' ';
				if isfield(me.meta,'comment'); me.info{end+1} = sprintf('Behavioural File Comment : %s', me.meta.comments); me.info{end+1} = ' '; end
				me.info{end+1} = sprintf('Plexon File Comment : %s', me.ic.Comment);
				me.info{end+1} = sprintf('Version : %g', me.ic.Version);
				me.info{end+1} = sprintf('SDK Version : %g', me.ic.sdkversion);
				me.info{end+1} = sprintf('Frequency : %g Hz', me.ic.Freq);
				me.info{end+1} = sprintf('Plexon Date/Time : %s', num2str(me.ic.DateTime));
				me.info{end+1} = sprintf('Duration : %g seconds', me.ic.Duration);
				me.info{end+1} = sprintf('Num Pts Per Wave : %g', me.ic.NPW);
				me.info{end+1} = sprintf('Num Pts Pre-Threshold : %g', me.ic.PreThresh);
			catch
				if ~isempty(oldInfo)
					me.info = oldInfo;
					fprintf('Not properly parsed yet, info generation took <strong>%g ms</strong>\n',round(toc(infoTic)*1000))
					return
				end
			end
			
			switch me.trodality
				case 1
					me.info{end+1} = sprintf('Data type : Single Electrode');
				case 2
					me.info{end+1} = sprintf('Data type : Stereotrode');
				case 4
					me.info{end+1} = sprintf('Data type : Tetrode');
				otherwise
					me.info{end+1} = sprintf('Data type : Unknown');
			end
			me.info{end+1} = sprintf('Spike Peak Voltage (mV) : %g', me.ic.SpikePeakV);
			me.info{end+1} = sprintf('Spike A/D Resolution (bits) : %g', me.ic.SpikeADResBits);
			me.info{end+1} = sprintf('Slow A/D Peak Voltage (mV) : %g', me.ic.SlowPeakV);
			me.info{end+1} = sprintf('Slow A/D Resolution (bits) : %g', me.ic.SlowADResBits);

			if ~isempty(me.eventList)
				generateMeta(me);
				me.info{end+1} = ' ';
				me.info{end+1} = sprintf('Number of Strobed Variables : %g', me.eventList.nVars);
				me.info{end+1} = sprintf('Total # Correct Trials :  %g', length(me.eventList.correct));
				me.info{end+1} = sprintf('Total # BreakFix Trials :  %g', length(me.eventList.breakFix));
				me.info{end+1} = sprintf('Total # Incorrect Trials :  %g', length(me.eventList.incorrect));
				me.info{end+1} = sprintf('Minimum # of Trials per variable :  %g', me.eventList.minRuns);
				me.info{end+1} = sprintf('Maximum # of Trials per variable :  %g', me.eventList.maxRuns);
				me.info{end+1} = sprintf('Shortest Trial Time (all/correct):  %g / %g s', me.eventList.tMin,me.eventList.tMinCorrect);
				me.info{end+1} = sprintf('Longest Trial Time (all/correct):  %g / %g s', me.eventList.tMax,me.eventList.tMaxCorrect);
			end
			if isa(me.rE,'runExperiment') && ~isempty(me.rE)
				me.info{end+1} = ' ';
				rE = me.rE; %#ok<*PROP>
				me.info{end+1} = sprintf('# of Stimulus Variables : %g', rE.task.nVars);
				me.info{end+1} = sprintf('Total # of Variable Values: %g', rE.task.minBlocks);
				me.info{end+1} = sprintf('Random Seed : %g', rE.task.randomSeed);
				names = '';
				vals = '';
				for i = 1:rE.task.nVars
					names = [names '  <|>  ' rE.task.nVar(i).name];
					if iscell(rE.task.nVar(i).values)
						val = '';
						for jj = 1:length(rE.task.nVar(i).values)
							v=num2str(rE.task.nVar(i).values{jj});
							v=regexprep(v,'\s+',' ');
							if isempty(val)
								val = [v];
							else
								val = [val ' / ' v];
							end
						end
						vals = [vals '  <|>  ' val];
					else
						vals = [vals '  <|>  ' num2str(rE.task.nVar(i).values)];
					end
				end
				me.info{end+1} = sprintf('Variable Names : %s', names(6:end));
				me.info{end+1} = sprintf('Variable Values : %s', vals(6:end));
				names = '';
				for i = 1:rE.stimuli.n
					names = [names ' | ' rE.stimuli{i}.name ':' rE.stimuli{i}.family];
				end
				me.info{end+1} = sprintf('Stimulus Names : %s', names(4:end));
			end
			if isfield(me.meta,'matrix')
				me.info{end+1} = ' ';
				me.info{end+1} = 'Variable Map (Variable Index1 Index2 Index 3 Value1 Value2 Value3):';
				me.info{end+1} = num2str(me.meta.matrix);
			end
			if ~isempty(me.tsList)
				me.info{end+1} = ' ';
				me.info{end+1} = ['Total Channel list : ' num2str(me.tsList.chMap)];
				me.info{end+1} = ['Trodality Reduction : ' num2str(me.tsList.trodreduction)];
				me.info{end+1} = ['Number of Active channels : ' num2str(me.tsList.nCh)];
				me.info{end+1} = ['Number of Active units : ' num2str(me.tsList.nUnits)];
				for i=1:me.tsList.nCh
					me.info{end+1} = ['Channel ' num2str(me.tsList.chMap(i)) ' unit list (0=unsorted) : ' num2str(me.tsList.unitMap(i).units)];
				end
				me.info{end+1} = ['Ch/Unit Names : ' me.tsList.namelist];
				me.info{end+1} = sprintf('Number of Parsed Spike Trials : %g', length(me.tsList.tsParse{1}.trials));
				me.info{end+1} = sprintf('Data window around event : %s ', num2str(me.eventWindow));
				me.info{end+1} = sprintf('Start Offset : %g ', me.startOffset);
			end
			if ~isempty(me.eA)
				saccs = [me.eA.trials.firstSaccade];
				saccs(isnan(saccs)) = [];
				saccs(saccs<0) = [];
				mins = min(saccs);
				maxs = max(saccs);
				[avgs,es] = analysisCore.stderr(saccs);
				ns = length(saccs);
				me.info{end+1} = ' ';
				me.info{end+1} = ['Eyelink data Parsed trial total : ' num2str(length(me.eA.trials))];
				me.info{end+1} = ['Eyelink trial bug override : ' num2str(me.eA.needOverride)];
				me.info{end+1} = sprintf('Valid First Post-Stimulus Saccades (#%g): %.4g ± %.3g (range %g:%g )',ns,avgs/1e3,es/1e3,mins/1e3,maxs/1e3);
			end
			fprintf('<strong>:#:</strong> Generating info for %s took <strong>%g ms</strong>\n',me.fullName,round(toc(infoTic)*1000))
			me.info{end+1} = ' ';
			me.info = me.info';
			info = me.info;
			me.meta(1).info = me.info;
		end
		
		% ===================================================================
		%> @brief exportToRawSpikes for legacy spikes support
		%>
		%> @param
		%> @return x spike data structure for spikes.m to read.
		% ===================================================================
		function x = exportToRawSpikes(me, var, firstunit, StartTrial, EndTrial, trialtime, modtime, cuttime)
			if ~isempty(me.cellmap)
				fprintf('Extracting Var=%g for Cell %g from PLX unit %g\n', var, firstunit, me.cellmap(firstunit));
				raw = me.tsList.tsParse{me.cellmap(firstunit)};
			else
				fprintf('Extracting Var=%g for Cell %g from PLX unit %g \n', var, firstunit, firstunit);
				raw = me.tsList.tsParse{firstunit};
			end
			if var > length(raw.var)
				errordlg('This Plexon File seems to be Incomplete, check filesize...')
			end
			raw = raw.var{var};
			v = num2str(me.meta.matrix(var,:));
			v = regexprep(v,'\s+',' ');
			x.name = ['PLX#' num2str(var) '|' v];
			x.raw = raw;
			x.totaltrials = me.eventList.minRuns;
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
			x.maxtime = me.eventList.tMaxCorrect * x.conversion;
			a = 1;
			for tr = x.starttrial:x.endtrial
				x.trial(a).basetime = round(raw.run(tr).basetime * x.conversion); %convert from seconds to 0.1ms as that is what VS used
				x.trial(a).modtimes = 0;
				x.trial(a).mod{1} = round(raw.run(tr).spikes * x.conversion) - x.trial(a).basetime;
				a=a+1;
			end
			x.isPLX = true;
			x.tDelta = me.eventList.vars(var).tDeltacorrect(x.starttrial:x.endtrial);
			x.startOffset = me.startOffset;
			
		end
	
		% ===================================================================
		%> @brief allows data from another plxReader object to be used,
		%> useful for example when you load LFP data in 1 plxReader and
		%> spikes in another but they are using the same behaviour files etc.
		%>
		%> @param inplx another plxReader instance for syncing to
		%> @param exclude a regex of properties to exclude from syncing
		%> @return
		% ===================================================================
		function syncData(me, inplx, exclude)
			if ~exist('exclude','var') || ~ischar(exclude); exclude = ''; end
			if isa(inplx,'plxReader')
				if strcmpi(me.uuid, inplx.uuid)
					fprintf('\tThe two plxReader objects are identical, skipping syncing...\n');
					return
				end
				if ~strcmpi(me.matfile, inplx.matfile)
					warning('Different Behaviour mat files, can''t sync plxReaders');
					return
				end
				%our list of syncable properties, only sync is destination is empty and not excluded
				prop = {'eventList','tsList','meta','rE','eA','info'};
				for i = 1:length(prop)
					if isempty(me.(prop{i})) && ~isempty(inplx.(prop{i})) && isempty(regexpi(prop{i}, exclude))
						me.(prop{i}) = inplx.(prop{i});
					end
				end
			end
		end
		
		% ===================================================================
		%> @brief drawEvents plot a timeline of all event data
		%>
		%> @param h an existing axis handle, otherwise make new figure
		%> @return
		% ===================================================================
		function drawEvents(me,h)
			if ~exist('h','var')
				hh=figure;figpos(1,[2000 800]);set(gcf,'Color',[1 1 1]);
				h = axes;
				set(hh,'CurrentAxes',h);
			end
			axes(h);
			if ~strcmpi(get(gca,'UserData'),'empty'); return; end
			title(['EVENT PLOT: File:' me.file]);
			xlabel('Time (s)');
			set(gca,'XGrid','on','XMinorGrid','on','Layer','bottom');
			hold on
			color = rand(3,me.eventList.nVars);
			for j = 1:me.eventList.nTrials
				trl = me.eventList.trials(j);
				var = trl.variable;
				hl=line([trl.t1 trl.t1],[-.4 .4],'Color',color(:,var),'LineWidth',1);
				set(get(get(hl,'Annotation'),'LegendInformation'),'IconDisplayStyle','off'); % Exclude line from legend
				hl=line([trl.t2 trl.t2],[-.4 .4],'Color',color(:,var),'LineWidth',1);
				set(get(get(hl,'Annotation'),'LegendInformation'),'IconDisplayStyle','off'); % Exclude line from legend
				text(trl.t1,.41,['VAR: ' num2str(var) '\newlineTRL: ' num2str(j)],'FontSize',10);
				if isfield(trl,'firstSaccade'); sT = trl.firstSaccade; else sT = NaN; end
				text(trl.t1,-.41,['SAC: ' num2str(sT) '\newlineCOR: ' num2str(trl.isCorrect)],'FontSize',10);
			end
			plot(me.eventList.startFix,zeros(size(me.eventList.startFix)),'c.','MarkerSize',18);
			plot(me.eventList.correct,zeros(size(me.eventList.correct)),'g.','MarkerSize',18);
			plot(me.eventList.breakFix,zeros(size(me.eventList.breakFix)),'b.','MarkerSize',18);
			plot(me.eventList.incorrect,zeros(size(me.eventList.incorrect)),'r.','MarkerSize',18);
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
			
			function forwardPlot(~, ~)
				ax = axis(gca);
				ax(1) = ax(1) + 10;
				ax(2) = ax(1) + 10;
				axis(ax);
			end
			function backPlot(~, ~)
				ax = axis(gca);
				ax(1) = ax(1) - 10;
				ax(2) = ax(1) + 10;
				axis(ax);
			end
		end
		
		% ===================================================================
		%> @brief Constructor
		%>
		%> @param varargin
		%> @returnscr
		% ===================================================================
		function getFiles(me, force)
			if ~exist('force','var')
				force = false;
			end
			if force == true || isempty(me.file)
				[f,p] = uigetfile({'*.plx;*.pl2';'PlexonFiles'},'Load Plexon File');
				if ischar(f) && ~isempty(f)
					me.file = f;
					me.dir = p;
						me.paths.oldDir = pwd;
					cd(me.dir);
				else
					return
				end
			end
			if force == true || isempty(me.matfile)
				[me.matfile, me.matdir] = uigetfile('*.mat',['Load Behaviour MAT File for ' me.file]);
			end
			if force == true || isempty(me.edffile)
				cd(me.matdir)
				[~,f,~] = fileparts(me.matfile);
				f = [f '.edf'];
				ff = regexprep(f,'\.edf','FIX\.edf','ignorecase');
				fff = regexprep(ff,'^[a-zA-Z]+\-','','ignorecase');
				if ~exist(f, 'file') && ~exist(ff,'file') && ~exist(fff,'file')
					[an, ~] = uigetfile('*.edf',['Load Eyelink EDF File for ' me.matfile]);
					if ischar(an)
						me.edffile = an;
					else
						me.edffile = '';
					end
				elseif exist(f, 'file')
					me.edffile = f;
				elseif exist(ff, 'file')
					me.edffile = ff;
				elseif exist(fff, 'file')
					me.edffile = fff;
				end
			end
		end
		
		% ===================================================================
		%> @brief Constructor remove the raw wave matrices etc to reduce memory
		%>
		%> @param varargin
		%> @returnscr
		% ===================================================================
		function optimiseSize(me)
			if isfield(me.tsList, 'nUnits') && me.tsList.nUnits > 0
				blank = cell(me.tsList.nUnits,1);
				if isfield(me.tsList,'ts')
					me.tsList.ts = blank;
				end
				if isfield(me.tsList,'tsN')
					me.tsList.tsN = blank;
				end
				if isfield(me.tsList,'tsW')
					me.tsList.tsW = blank;
				end
				if isfield(me.tsList,'wave')
					me.tsList.wave = blank;
				end
			end
			if ~isempty(me.rE)
				for i = 1: me.rE.stimuli.n
					reset(me.rE.stimuli{i})
				end
			end
		end
	
	end
	
	%=======================================================================
	methods ( Static = true) %-------STATIC METHODS-----%
	%=======================================================================
	
		% ===================================================================
		%> @brief 
		%> This needs to be static as it may load data called "me" which
		%> will conflict with the me object in the class.
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
			var = cell(rE.task.nVars,1);
			for i=1:rE.task.nVars
				var{i}.title = rE.task.nVar(i).name;
				var{i}.nvalues = length(rE.task.nVar(i).values);
				var{i}.range = var{i}.nvalues;
				if iscell(rE.task.nVar(i).values)
					vals = rE.task.nVar(i).values;
					num = 1:var{i}.range;
					var{i}.values = num;
					var{i}.keystring = [];
					for jj = var{i}.range
						k = vals{jj};
						var{i}.key{jj} = num2str(k);
						var{i}.keystring = {var{i}.keystring var{i}.key{jj}};
					end
				else
					var{i}.values = rE.task.nVar(i).values;
					var{i}.key = '';
				end
			end
			meta.var = var;
			meta.repeats = rE.task.nBlocks;
			meta.cycles = 1;
			meta.modtime = 500;
			meta.trialtime = 500;
			meta.matrix = [];
			fprintf('<strong>:#:</strong> Parsing Behavioural files took <strong>%g ms</strong>\n', round(toc*1000))
			cd(oldd);
		end
	end
	
	%=======================================================================
	methods ( Access = private ) %-------PRIVATE METHODS-----%
	%=======================================================================
		
		% ===================================================================
		%> @brief load and parse (via eyelinkAnalysis) the Eyelink EDF file
		%>
		%> @param pn path to EDF file
		%> @return
		% ===================================================================
		function loadEDF(me,pn)
			if ~exist('pn','var')
				if exist(me.matdir,'dir')
					pn = me.matdir;
				else
					pn = me.dir;
				end
			end
			oldd=pwd;
			cd(pn);
			if exist(me.edffile,'file')
				if ~isempty(me.eA) && isa(me.eA,'eyelinkAnalysis')
					me.eA.file = me.edffile;
					me.eA.dir = pn;
					me.eA.trialOverride = me.eventList.trials;
				else
					in = struct('file',me.edffile,'dir',pn,...
						'trialOverride',me.eventList.trials);
					me.eA = eyelinkAnalysis(in);
				end
				if isa(me.rE.screen,'screenManager')
					me.eA.pixelsPerCm = me.rE.screen.pixelsPerCm;
					me.eA.distance = me.rE.screen.distance;
					me.eA.xCenter = me.rE.screen.xCenter;
					me.eA.yCenter = me.rE.screen.yCenter;
				end
				if isstruct(me.rE.tS)
					me.eA.tS = me.rE.tS;
				end
				load(me.eA);
				parse(me.eA);
				fixVarNames(me.eA);
			else
				warning('Couldn''t find EDF file...')				
			end
			cd(oldd)
		end
		
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function readMat(me,override)
			if ~exist('override','var'); override = false; end
			if override == true || isempty(me.rE)
				if exist(me.matdir, 'dir')
					[me.meta, me.rE] = me.loadMat(me.matfile, me.matdir);
				else
					[me.meta, me.rE] = me.loadMat(me.matfile, me.dir);
				end
			end
		end
		
		% ===================================================================
		%> @brief get event markers from the plexon PLX/PL2 file
		%>
		%> @param
		%> @return
		% ===================================================================
		function getEvents(me)
			readMat(me); %make sure we've loaded the behavioural file first
			tic
			[~,eventNames] = plx_event_names(me.file);
			[~,eventIndex] = plx_event_chanmap(me.file);
			eventNames = cellstr(eventNames);
			
			idx = strcmpi(eventNames,'Strobed');
			[a, b, c] = plx_event_ts(me.file,eventIndex(idx));
			if isempty(a) || a == 0
				me.eventList = struct();
				warning('No strobe events detected!!!');
				return
			end
			idx = find(c < 1); %check for zer or lower event numbers, remove
			if ~isempty(idx)
				c(idx)=[];
				b(idx) = [];
			end
			idx = find(c > me.rE.task.minBlocks & c < 32767); %check for invalid event numbers, remove
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
			[~,start] = plx_event_ts(me.file,eventIndex(idx)); %start event
			idx = strcmpi(eventNames, 'Stop');
			[~,stop] = plx_event_ts(me.file,eventIndex(idx)); %stop event
			idx = strcmpi(eventNames, 'EVT19'); 
			[~,b19] = plx_event_ts(me.file,eventIndex(idx)); %currently 19 is fix start
			idx = strcmpi(eventNames, 'EVT20');
			[~,b20] = plx_event_ts(me.file,eventIndex(idx)); %20 is correct
			idx = strcmpi(eventNames, 'EVT21');
			[~,b21] = plx_event_ts(me.file,eventIndex(idx)); %21 is breakfix
			idx = strcmpi(eventNames, 'EVT22');
			[~,b22] = plx_event_ts(me.file,eventIndex(idx)); %22 is incorrect

			eL = struct();
			eL.eventNames = eventNames;
			eL.eventIndex = eventIndex;
			eL.n = a;
			eL.nTrials = a/2; %we hope our strobe # even
			eL.times = single(b);
			eL.values = int32(c);
			eL.start = start;
			eL.stop = stop;
			eL.startFix = single(b19);
			eL.correct = single(b20);
			eL.breakFix = single(b21);
			eL.incorrect = single(b22);
			eL.varOrder = eL.values(eL.values<32767);
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
				
				tc = eL.correct > eL.trials(aa).t2 - me.eventSearchWindow & eL.correct < eL.trials(aa).t2 + me.eventSearchWindow;
				tb = eL.breakFix > eL.trials(aa).t2 - me.eventSearchWindow & eL.breakFix < eL.trials(aa).t2 + me.eventSearchWindow;
				ti = eL.incorrect > eL.trials(aa).t2 - me.eventSearchWindow & eL.incorrect < eL.trials(aa).t2 + me.eventSearchWindow;
				
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
			me.eventList = eL;
			fprintf('<strong>:#:</strong> Loading all event markers took <strong>%g ms</strong>\n',round(toc*1000))
			generateMeta(me);
			clear eL
		end
		
		% ===================================================================
		%> @brief meta is used by the old spikes analysis routines
		%>
		%> @param
		%> @return
		% ===================================================================
		function generateMeta(me)
			me.meta.modtime = floor(me.eventList.tMaxCorrect * 10000);
			me.meta.trialtime = me.meta.modtime;
			m = [me.rE.task.outIndex me.rE.task.outMap getMeta(me.rE.task)];
			m = m(1:me.eventList.nVars,:);
			[~,ix] = sort(m(:,1),1);
			m = m(ix,:);
			me.meta.matrix = m;	
		end
		
		% ===================================================================
		%> @brief read raw spke data from plexon PLX/PL2 file
		%>
		%> @param
		%> @return
		% ===================================================================
		function readSpikes(me)
			rsT = tic;
			me.tsList = struct();
			[tscounts, wfcounts, evcounts, slowcounts]	= plx_info(me.file,1);
			[~,chnames]												= plx_chan_names(me.file);
			[~,chmap]												= plx_chanmap(me.file);
			chnames = cellstr(chnames);
			
			%!!!WARNING tscounts column 1 is empty, read plx_info for details
			%we remove the first column here so we don't have the idx-1 issue
			tscounts = tscounts(:,2:end);
			
			[a,b]=ind2sub(size(tscounts),find(tscounts>0)); %finds row and columns of nonzero values
			me.tsList.chMap = unique(b)';
			if isempty(me.tsList.chMap);
				warning('---! No units seem to be present in the data... !---');
			end
			a = 1;
			me.tsList.trodreduction = false;
			prevcount = inf;
			nCh = 0;
			nUnit = 0;
			for i = 1:length(me.tsList.chMap)
				units = find(tscounts(:,me.tsList.chMap(i))>0)';
				n = length(units);
				counts = tscounts(units,me.tsList.chMap(i))';
				units = units - 1; %fix the index as plx uses 0 as unsorted
				if ~isequal(counts, prevcount) || me.channelReduction == false 
					me.tsList.unitMap(a).units = units; 
					me.tsList.unitMap(a).ch = chmap(me.tsList.chMap(i));
					me.tsList.unitMap(a).chIdx = me.tsList.chMap(i);
					me.tsList.unitMap(a).n = n;
					me.tsList.unitMap(a).counts = counts;
					prevcount = counts;
					nCh = a;
					nUnit = nUnit + n;
					a = a + 1;
				end
			end
			if me.trodality > 1 && a < i
				me.tsList.trodreduction = true;	
				fprintf('---! Removing tetrode channels with identical spike numbers (use channelReduction=TRUE/FALSE to control this) !---\n');
			end
			me.tsList.chMap = me.tsList(1).chMap;
			me.tsList.chIndex = me.tsList.chMap; 
			me.tsList.chMap = chmap(me.tsList.chMap); %fucking pain channel number is different to ch index!!!
			me.tsList.activeChIndex = [me.tsList.unitMap(:).chIdx]; %just the active channels
			me.tsList.activeCh = chmap(me.tsList.activeChIndex); %mapped to the channel numbers
			me.tsList.nCh = nCh; 
			me.tsList.nUnits = nUnit;

			me.tsList.ts = cell(me.tsList.nUnits, 1);
			me.tsList.tsN = me.tsList.ts;
			me.tsList.tsParse = me.tsList.ts;
			me.tsList.namelist = ''; list = 'UabcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRST';
			a = 1;
			for ich = 1:length(me.tsList.activeCh)
				ch = me.tsList.activeCh(ich);
				name = chnames{me.tsList.activeChIndex(ich)};
				unitN = me.tsList.unitMap(ich).n;
				for iunit = 1:unitN
					
					unit = me.tsList.unitMap(ich).units(iunit);
					[tsN,ts] = plx_ts(me.file, ch, unit);
					[twN, npw, tsW, wave] = plx_waves_v(me.file, ch, unit);
					if ~isequal(tsN,me.tsList.unitMap(ich).counts(iunit))
						error('SPIKE PARSING COUNT ERROR!!!')
					end
					me.tsList.tsN{a} = tsN;
					me.tsList.ts{a} = ts;
					if twN == tsN
						me.tsList.tsW{a} = ts;
						me.tsList.wave{a} = single(wave);
					end
					
					t = '';
					t = [num2str(a) ':' name '.' num2str(ch) list(iunit) '=' num2str(tsN)];
					me.tsList.names{a} = t;
					me.tsList.namelist = [me.tsList.namelist ' ' t];
					
					a = a + 1;
				end
			end
			fprintf('<strong>:#:</strong> Loading all spike channels took <strong>%g ms</strong>\n',round(toc(rsT)*1000));
		end

		% ===================================================================
		%> @brief parse raw spikes into trials and variables
		%>
		%> @param
		%> @return
		% ===================================================================
		function parseSpikes(me)
			psT = tic;
			for ps = 1:me.tsList.nUnits
				spikes = me.tsList.ts{ps}; 
				waves = me.tsList.wave{ps};
				trials = cell(me.eventList.nTrials,1);
				vars = cell(me.eventList.nVars,1);
				for trl = 1:me.eventList.nTrials
					%===process the trial
					trial = me.eventList.trials(trl);
					trials{trl} = trial;
					trials{trl}.startOffset = me.startOffset;
					trials{trl}.eventWindow = me.eventWindow;
					if isempty(me.eventWindow) %use event markers and startOffset
						trials{trl}.tStart = trial.t1 + me.startOffset;
						trials{trl}.tEnd = trial.t2;
						trials{trl}.rStart = me.startOffset;
						trials{trl}.rEnd = trial.t2 - trial.t1;
						trials{trl}.base = trial.t1;
						trials{trl}.basetime = trials{trl}.tStart; %make offset invisible for systems that can't handle -time
						trials{trl}.modtimes = trials{trl}.tStart;
					else
						trials{trl}.tStart = trial.t1 - me.eventWindow;
						trials{trl}.tEnd = trial.t1 + me.eventWindow;
						trials{trl}.rStart = -me.eventWindow;
						trials{trl}.rEnd = me.eventWindow;
						trials{trl}.base = trial.t1;
						trials{trl}.basetime = trial.t1; % basetime > tStart
						trials{trl}.modtimes = trial.t1;
					end
					idx = spikes >= trials{trl}.tStart & spikes <= trials{trl}.tEnd;
					trials{trl}.spikes = spikes(idx); 
					trials{trl}.waves = waves(idx,:);
					%===process the variable run
					var = trial.variable;
					if isempty(vars{var})
						vars{var} = me.eventList.vars(var);
						vars{var}.nTrials = 0;
						vars{var}.run = struct([]);
					end
					vars{var}.nTrials = vars{var}.nTrials + 1;
					vars{var}.run(vars{var}.nTrials).eventWindow = trials{trl}.eventWindow;
					if isempty(me.eventWindow)
						vars{var}.run(vars{var}.nTrials).basetime = trial.t1 + me.startOffset;
						vars{var}.run(vars{var}.nTrials).modtimes = trial.t1 + me.startOffset;
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
				me.tsList.tsParse{ps}.trials = trials;
				me.tsList.tsParse{ps}.var = vars;
				clear spikes waves trials vars
			end
			fprintf('<strong>:#:</strong> Parsing spikes into trials/variables took <strong>%g ms</strong>\n',round(toc(psT)*1000))
			if me.startOffset ~= 0
				me.info{end+1} = sprintf('START OFFSET ACTIVE : %g', me.startOffset);
			end
		end
		
	end
	
end

