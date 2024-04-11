% ========================================================================
%> @brief iRecAnalysis offers a set of methods to load, parse & plot raw CSV files. It
%> understands opticka trials (where CSV messages INT start a trial and 255
%> ends a trial by default) so can parse eye data and plot it for trial groups. You
%> can also manually find microsaccades, and perform ROI/TOI filtering on the eye
%> movements.
%>
%> Copyright ©2014-2022 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ========================================================================
classdef iRecAnalysis < analysisCore
	% iRecAnalysis offers a set of methods to load, parse & plot raw CSV files.
	properties
		%> file name
		fileName char								= ''
		%> which message contains the trial start tag
		trialStartMessageName						= []
		%> which message contains the variable name or value
		variableMessageName							= 'number'
		%> message name to signal end of the trial
		trialEndMessage								= 0
		%> the CSV message name to start measuring stimulus presentation,
		%> and this is the 0 time in the analysis by default, can be
		%> overridden by send SYNCTIME or rtOverrideMessage
		rtStartMessage char							= -1500
		%> CSV message name to end the stimulus presentation or subject repsonse
		rtEndMessage char							= -1501
		%> override the rtStart time with a custom message?
		rtOverrideMessage char						= -1000
		%> minimum saccade distance in degrees
		minSaccadeDistance double					= 1.0
		%> relative velocity threshold
		VFAC double									= 5
		%> minimum saccade duration
		MINDUR double								= 2  %equivalent to 6 msec at 500Hz sampling rate  (cf E&R 2006)
		%> the temporary experiement structure which contains the eyePos recorded from opticka
		tS struct
		%> exclude incorrect trials when indexing (trials contain an idx and correctedIdx value and you can use either)
		excludeIncorrect logical					= false
		%> region of interest?
		ROI double									= [ ]
		%> time of interest?
		TOI double									= [ ]
		%> verbose output?
		verbose										= false
		%> screen resolution
		pixelsPerCm double							= 32
		%> screen distance
		distance double								= 57.3
		%> screen resolution
		resolution									= [ 1920 1080 ]
		%> For Dee's analysis edit these settings
		ETparams
		%> Is measure range relative to start and end markers or absolute
		%> to start marker?
		relativeMarkers								= false
	end

	properties
		SYNCTIME									= -1499
		END_FIX										= -1500
		END_RT										= -1501
		END_EXP										= -500
	end

	

	properties (Hidden = true)
		%TRIAL_RESULT message values, optional but tags trials with these identifiers.
		correctValue double							= 1
		incorrectValue double						= -5
		breakFixValue double						= -1
		%occasionally we have some trials in the CSV not in the plx, this prunes them out
		trialsToPrune double						= []
		%> these are used for spikes spike saccade time correlations
		rtLimits double
		rtDivision double
		%> trial list from the saved behavioural data, used to fix trial name bug in old files
		trialOverride struct
		%> screen X center in pixels
		xCenter double								= 640
		%> screen Y center in pixels
		yCenter double								= 512
		%>57.3 bug override
		override573									= false
		%> downsample the data for plotting
		downSample logical							= true
		excludeTrials								= []
	end

	properties (SetAccess = private, GetAccess = public)
		%> have we parsed the CSV yet?
		isParsed logical							= false
		%> sample rate
		sampleRate double							= 500
		%> raw data
		raw table
		%> markers
		markers table
		%> inidividual trials
		trials struct
		%> eye data parsed into invdividual variables
		vars struct
		%> the trial variable identifier, negative values were breakfix/incorrect trials
		trialList double
		%> correct trials indices
		correct struct								= struct()
		%> breakfix trials indices
		breakFix struct								= struct()
		%> incorrect trials indices
		incorrect struct							= struct()
		%> unknown trials indices
		unknown struct								= struct()
		%> the display dimensions parsed from the CSV
		display double
		%> other display info parsed from the CSV
		otherinfo struct							= struct()
		%> for some early CSV files, there is no trial variable ID so we
		%> recreate it from the other saved data
		needOverride logical						= false;
		%>ROI info
		ROIInfo
		%>TOI info
		TOIInfo
		%> does the trial variable list match the other saved data?
		validation struct
	end

	properties (Dependent = true, SetAccess = private)
		%> pixels per degree calculated from pixelsPerCm and distance
		ppd
	end

	properties (Constant, Hidden = true)
		
	end

	properties (SetAccess = private, GetAccess = private)
		%> pixels per degree calculated from pixelsPerCm and distance (cache)
		ppd_
		%> allowed properties passed to object upon construction
		allowedProperties = {'correctValue', 'incorrectValue', 'breakFixValue', ...
			'trialStartMessageName', 'variableMessageName', 'trialEndMessage', 'file', 'dir', ...
			'verbose', 'pixelsPerCm', 'distance', 'xCenter', 'yCenter', 'rtStartMessage', 'minSaccadeDistance', ...
			'rtEndMessage', 'trialOverride', 'rtDivision', 'rtLimits', 'tS', 'ROI', 'TOI', 'VFAC', 'MINDUR'}
		trialsTemplate = {'variable','variableMessageName','idx','correctedIndex','time',...
			'rt','rtoverride','fixations','nfix','saccades','nsacc','saccadeTimes',...
			'firstSaccade','uuid','result','invalid','correct','breakFix','incorrect','unknown',...
			'messages','sttime','entime','totaltime','startsampletime','endsampletime',...
			'timeRange','rtstarttime','rtstarttimeOLD','rtendtime','synctime','deltaT',...
			'rttime','times','gx','gy','hx','hy','pa','msacc','sampleSaccades',...
			'microSaccades','radius'}
	end

	methods
		% ===================================================================
		%> @brief
		%>
		% ===================================================================
		function me = iRecAnalysis(varargin)
			if nargin == 0; varargin.name = ''; end
			me=me@analysisCore(varargin); %superclass constructor
			if all(me.measureRange == [0.1 0.2]) %use a different default to superclass
				me.measureRange = [-0.5 1.0];
			end
			if nargin>0; me.parseArgs(varargin, me.allowedProperties); end
			me.ppd; %cache our initial ppd_
			x = which('defaultParameters.m');
			if isempty(x)
				warning('Please add NystromHolmqvist2010 to the path for full functionality!')
			else
				p = fileparts(x);
				addpath(genpath([p filesep 'function_library']));
				addpath(genpath([p filesep 'post-process']));
			end
			if isempty(me.ETparams)
				me.ETparams = defaultParameters;
				% settings for code specific to Niehorster, Siu & Li (2015)
				me.ETparams.extraCut    = [0 0];        % extra ms of data to cut before and after saccade.
				me.ETparams.qInterpMissingPos   = true; % interpolate using straight lines to replace missing position signals?
				% settings for the saccade cutting (see cutSaccades.m for documentation)
				me.ETparams.cutPosTraceMode     = 1;
				me.ETparams.cutVelTraceMode     = 1;
				me.ETparams.cutSaccadeSkipWindow= 1;  % don't cut during first x seconds
				me.ETparams.samplingFreq = me.sampleRate;
				me.ETparams.screen.resolution              = [ me.resolution(1) me.resolution(2) ];
				me.ETparams.screen.size                    = [ me.resolution(1)/me.pixelsPerCm/100 me.resolution(2)/me.pixelsPerCm/100 ];
				me.ETparams.screen.viewingDist             = me.distance/100;
				me.ETparams.screen.dataCenter              = [ me.resolution(1)/2 me.resolution(2)/2 ];  % center of screen has these coordinates in data
				me.ETparams.screen.subjectStraightAhead    = [ me.resolution(1)/2 me.resolution(2)/2 ];  % Specify the screen coordinate that is straight ahead of the subject. Just specify the middle of the screen unless its important to you to get this very accurate!
				% change some defaults as needed for this analysis:
				me.ETparams.data.alsoStoreComponentDerivs  = true;
				me.ETparams.data.detrendWithMedianFilter   = true;
				me.ETparams.data.applySaccadeTemplate      = true;
				me.ETparams.data.minDur                    = 100;
				me.ETparams.fixation.doClassify            = true;
				me.ETparams.blink.replaceWithInterp        = true;
				me.ETparams.blink.replaceVelWithNan        = true;
			end
		end

		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function load(me, force)
			if ~exist('force','var'); force = false;end
			if isempty(me.fileName)
				[f,p]=uigetfile('*.csv','Load Main CSV File:');
				if ischar(f); me.fileName = f; me.dir = p; end
			end
			if isempty(me.fileName)
				warning('No CSV file specified...');
				return
			end
			if ~isempty(me.raw) && force == false; disp('Data loaded previously, skipping loading...');return; end
			me.raw = []; me.markers = [];
			tmain = tic;
			oldpath = pwd;
			[p,f,e] = fileparts(me.fileName);
            if ~isempty(p); me.dir = p; end
			cd(me.dir);
			me.raw = readtable([f e],'ReadVariableNames',true);
			me.markers = readtable([f 'net' e],'ReadVariableNames',true);
			
			me.sampleRate = 1/mean(diff(me.raw.time));

			cd(oldpath)
			if isempty(me.raw) || isempty(me.markers)
				fprintf('<strong>:#:</strong> Loading Raw CSV Data failed...\n');
			else
				fprintf('<strong>:#:</strong> Loading Raw CSV Data @ %.2fHz took <strong>%.2f secs</strong>\n',me.sampleRate,toc(tmain));
			end
		end

		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function parseSimple(me)
			tmain = tic;
			if isempty(me.raw); me.load(); end
			me.isParsed = false;
			parseEvents(me);
			parseAsVars(me);
			if isempty(me.trials)
				warning('---> iRecAnalysis.parseSimple: Could not parse!')
				me.isParsed = false;
			else
				me.isParsed = true;
			end
			fprintf('Simple Parsing of CSV Trials took <strong>%.2f secs</strong>\n',toc(tmain));
		end

		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function parse(me)
			tmain = tic;
			if isempty(me.raw); me.load(); end
			me.isParsed = false;
			parseEvents(me);
			if ~isempty(me.trialsToPrune)
				me.pruneTrials(me.trialsToPrune);
			end
			parseAsVars(me);
			parseSecondaryEyePos(me);
			parseFixationPositions(me);
			parseSaccades(me);
			me.isParsed = true;
			fprintf('\tOverall Parsing of CSV Data took <strong>%.2f secs</strong>\n',toc(tmain));
		end

		% ===================================================================
		%> @brief parse saccade related data
		%>
		%> @param
		%> @return
		% ===================================================================
		function parseSaccades(me)
			parseROI(me);
			parseTOI(me);
			computeMicrosaccades(me);
			computeFullSaccades(me);
		end

		% ===================================================================
		%> @brief remove trials from correct list that did not use a rt start or end message
		%>
		%> @param
		%> @return
		% ===================================================================
		function pruneNonRTTrials(me)
			for i = 1:length(me.trials)
				if isnan(me.trials(i).rtstarttime) || isnan(me.trials(i).rtendtime)
					me.trials(i).correct = false;
					me.trials(i).incorrect = true;
				end
			end
			me.correct.idx = find([me.trials.correct] == true);
			me.correct.saccTimes = [me.trials(me.correct.idx).firstSaccade];
			tr = [me.trials(me.correct.idx).timeRange];
			tr = reshape(tr,[2,length(me.correct.idx)])';
			me.correct.timeRange = tr;
			me.incorrect.idx = find([me.trials.incorrect] == true);
			me.incorrect.saccTimes = [me.trials(me.incorrect.idx).firstSaccade];
		end

		% ===================================================================
		%> @brief update correct index list
		%>
		%> @param
		%> @return
		% ===================================================================
		function updateCorrectIndex(me,idx)
			if max(idx) > length(me.trials)
				warning('Your custom index exceeds the number of trials!')
				return
			end
			if min(idx) < 1
				warning('Your custom index includes values less than 1!')
				return
			end

			me.correct.idx = idx;
			me.correct.saccTimes = [me.trials(me.correct.idx).firstSaccade];
			tr = [me.trials(me.correct.idx).timeRange];
			tr = reshape(tr,[2,length(me.correct.idx)])';
			me.correct.timeRange = tr;
			me.correct.isCustomIdx = true;

			for i = me.correct.idx
				me.trials(i).correct = true;
				me.trials(i).incorrect = false;
			end
		end

		% ===================================================================
		%> @brief prunetrials -- very rarely (n=1) we lose a trial strobe in the plexon data and
		%> thus when we try to align the plexon trial index and CSV trial index they are off-by-one,
		%> this function is used once the index of the trial is know to prune it out of the CSV data
		%> set and recalculate the indexes.
		%>
		%> @param
		%> @return
		% ===================================================================
		function pruneTrials(me,num)
			me.trials(num) = [];
			me.trialList(num) = [];
			me.correct.idx = find([me.trials.correct] == true);
			me.correct.saccTimes = [me.trials(me.correct.idx).firstSaccade];
			tr = [me.trials(me.correct.idx).timeRange];
			tr = reshape(tr,[2,length(me.correct.idx)])';
			me.correct.timeRange = tr;
			me.breakFix.idx = find([me.trials.breakFix] == true);
			me.breakFix.saccTimes = [me.trials(me.breakFix.idx).firstSaccade];
			me.incorrect.idx = find([me.trials.incorrect] == true);
			me.incorrect.saccTimes = [me.trials(me.incorrect.idx).firstSaccade];
			for i = num:length(me.trials)
				me.trials(i).correctedIndex = me.trials(i).correctedIndex - 1;
			end
			fprintf('Pruned %i trials from CSV trial data \n',num)
		end

		% ===================================================================
		%> @brief give a list of trials and it will plot both the raw eye position and the
		%> events
		%>
		%> @param
		%> @return
		% ===================================================================
		function handle = plot(me,select,type,seperateVars,name,handle)
			% plot(me,select,type,seperateVars,name)
			if ~exist('select','var') || ~isnumeric(select); select = []; end
			if ~exist('type','var') || isempty(type); type = 'correct'; end
			if ~exist('seperateVars','var') || ~islogical(seperateVars); seperateVars = false; end
			if ~exist('name','var') || isempty(name)
				if isnumeric(select) && length(select) > 1
					name = [me.fileName ' | Select: ' num2str(length(select)) ' trials'];
				else
					name = [me.fileName ' | Select: ' num2str(select)];
				end
			end
			if ~exist('handle','var'); handle = []; end
			if isnumeric(select) && ~isempty(select)
				idx = select;
				type = '';
				idxInternal = false;
			else
				switch lower(type)
					case 'correct'
						idx = me.correct.idx;
					case 'breakfix'
						idx = me.breakFix.idx;
					case 'incorrect'
						idx = me.incorrect.idx;
					otherwise
						idx = 1:length(me.trials);
				end
				idxInternal = true;
			end
			idx = setdiff(idx, me.excludeTrials);
			if isempty(idx)
				fprintf('No trials were selected to plot...\n')
				return
			end
			if seperateVars == true && isempty(select)
				vars = unique([me.trials(idx).id]);
				for j = vars
					me.plot(j,type,false);
					drawnow;
				end
				return
			end
			
			a = 1;
			stdex = [];
			meanx = [];
			meany = [];
			stdey = [];
			sacc = [];
			xvals = [];
			yvals = [];
			tvals = {};
			medx = [];
			medy = [];
			early = 0;
			mS = [];

			map = me.optimalColours(length(me.vars));
			for i = 1:length(me.vars)
				varidx(i) = str2num(me.vars(i).name);
			end

			if isempty(select)
				thisVarName = 'ALL';
			elseif length(select) > 1
				thisVarName = 'SELECTION';
			else
				thisVarName = ['VAR' num2str(select)];
			end

			maxv = 1;
			me.ppd;
			if ~isempty(me.TOI)
				t1 = me.TOI(1); t2 = me.TOI(2);
			else
				t1 = me.baselineWindow(1); t2 = me.baselineWindow(2);
			end

			for i = idx
				if ~exist('didplot','var'); didplot = false; end
				if idxInternal == true %we're using the eyelink index which includes incorrects
					f = i;
				elseif me.excludeIncorrect %we're using an external index which excludes incorrects
					f = find([me.trials.correctedIndex] == i);
				else
					f = find([me.trials.idx] == i);
				end
				if isempty(f); continue; end

				thisTrial = me.trials(f(1));
				
				if thisTrial.invalid 
					continue; 
				end

				tidx = find(varidx==thisTrial.variable);

				if thisTrial.variable == 1010 || isempty(me.vars) %early CSV files were broken, 1010 signifies this
					c = rand(1,3);
				else
					c = map(tidx,:);
				end

				if isempty(select) || length(select) > 1 || ~isempty(intersect(select,idx))

				else
					continue
				end

				t = thisTrial.times; %convert to seconds
				ix = find((t >= me.measureRange(1)) & (t <= me.measureRange(2)));
				ip = find((t >= me.plotRange(1)) & (t <= me.plotRange(2)));
				tm = t(ix);
				tp = t(ip);
				xa = thisTrial.gx;
				ya = thisTrial.gy;
				if all(isnan(xa)) && all(isnan(ya)); continue; end
				lim = 60; %max degrees in data
				xa(xa < -lim) = -lim; xa(xa > lim) = lim; 
				ya(ya < -lim) = -lim; ya(ya > lim) = lim;
				pupilAll = thisTrial.pa;
				
				%x = xa(ix);
				%y = ya(ix);
				%pupilMeasure = pupilAll(ix);
				
				xp = xa(ip);
				yp = ya(ip);
				xmin = min(xp); xmax = max(xp);
				ymin = min(yp); ymax = max(yp);
				pupilPlot = pupilAll(ip);
				
				if me.downSample && me.sampleRate > 500
					ds = floor(me.sampleRate/200);
					idx = circshift(logical(mod(1:length(tp), ds)), -(ds-1)); %downsample every N as less points to draw
					tp(idx) = [];
					xp(idx) = [];
					yp(idx) = [];
					pupilPlot(idx) = [];
				end

				if isempty(handle)
					handle=figure('Name',name,'Color',[1 1 1],'NumberTitle','off',...
						'Papertype','a4','PaperUnits','centimeters',...
						'PaperOrientation','landscape','Renderer','painters');
					figpos(1,[0.6 0.9],1,'%');
					p = tiledlayout(3,2,'TileSpacing','compact','Padding','compact');
				end
				figure(handle);
				
				sz = 100;
				ax = nexttile(1);
				hold on;
				if isfield(thisTrial,'sampleSaccades') & ~isnan(thisTrial.sampleSaccades) & ~isempty(thisTrial.sampleSaccades)
					for jj = 1: length(thisTrial.sampleSaccades)
						if thisTrial.sampleSaccades(jj) >= me.plotRange(1) && thisTrial.sampleSaccades(jj) <= me.plotRange(2)
							midx = me.findNearest(tp,thisTrial.sampleSaccades(jj));
							scatter(xp(midx),yp(midx),sz,'^','filled','MarkerEdgeColor',[1 1 1],'MarkerFaceAlpha',0.5,...
								'MarkerFaceColor',[0 0 0],'UserData',[thisTrial.idx thisTrial.correctedIndex thisTrial.variable thisTrial.sampleSaccades(jj)],'ButtonDownFcn', @clickMe);
						end
					end
				end
				if isfield(thisTrial,'microSaccades') & ~isnan(thisTrial.microSaccades) & ~isempty(thisTrial.microSaccades)
					for jj = 1: length(thisTrial.microSaccades)
						if thisTrial.microSaccades(jj) >= me.plotRange(1) && thisTrial.microSaccades(jj) <= me.plotRange(2)
							midx = me.findNearest(tp,thisTrial.microSaccades(jj));
							scatter(xp(midx),yp(midx),sz,'o','filled','MarkerEdgeColor',[0 0 0],...
								'MarkerFaceColor',c,'UserData',[thisTrial.idx thisTrial.correctedIndex thisTrial.variable thisTrial.microSaccades(jj)],'ButtonDownFcn', @clickMe);
						end
					end
				end
				plot(xp, yp,'k-','Color',c,'LineWidth',1,'UserData',[thisTrial.idx thisTrial.correctedIndex thisTrial.variable],'ButtonDownFcn', @clickMe);
				
				ax = nexttile(2);
				hold on;
				plot(tp,abs(xp),'k-','Color',c,'MarkerSize',3,'MarkerEdgeColor',c,...
					'MarkerFaceColor',c,'UserData',[thisTrial.idx thisTrial.correctedIndex thisTrial.variable],'ButtonDownFcn', @clickMe);
				plot(tp,abs(yp),'k.-','Color',c,'MarkerSize',3,'MarkerEdgeColor',c,...
					'MarkerFaceColor',c,'UserData',[thisTrial.idx thisTrial.correctedIndex thisTrial.variable],'ButtonDownFcn', @clickMe);
				maxv = max([maxv, max(abs(xp)), max(abs(yp))]) + 0.1;
				if isfield(thisTrial,'sampleSaccades') & ~isnan(thisTrial.sampleSaccades) & ~isempty(thisTrial.sampleSaccades)
					if any(thisTrial.sampleSaccades >= me.plotRange(1) & thisTrial.sampleSaccades <= me.plotRange(2))
						scatter(thisTrial.sampleSaccades,-0.1,sz,'^','filled','MarkerEdgeColor',[1 1 1],'MarkerFaceAlpha',0.5,...
							'MarkerFaceColor',[0 0 0],'UserData',[thisTrial.idx thisTrial.correctedIndex thisTrial.variable],'ButtonDownFcn', @clickMe);
					end
				end
				if isfield(thisTrial,'microSaccades') & ~isnan(thisTrial.microSaccades) & ~isempty(thisTrial.microSaccades)
					if any(thisTrial.microSaccades >= me.plotRange(1) & thisTrial.microSaccades <= me.plotRange(2))
						scatter(thisTrial.microSaccades,-0.1,sz,'o','filled','MarkerEdgeColor',[0 0 0],...
							'MarkerFaceColor',c,'UserData',[thisTrial.idx thisTrial.correctedIndex thisTrial.variable],'ButtonDownFcn', @clickMe);
					end
				end

				ax = nexttile(5);
				hold on;
				for fix=1:length(thisTrial.fixations)
					f=thisTrial.fixations(fix);
					ti = double(f.time); le = double(f.length);
					if ti >= me.plotRange(1)-0.1 && ti+le <= me.plotRange(2)+0.1
						plot3([ti ti+le],[f.gstx f.genx],[f.gsty f.geny],'k-o',...
						'LineWidth',1,'MarkerSize',5,'MarkerEdgeColor',[0 0 0],...
						'MarkerFaceColor',c,'UserData',[thisTrial.idx thisTrial.correctedIndex thisTrial.variable],...
						'ButtonDownFcn', @clickMe)
					end
				end
				if ~isempty(thisTrial.saccades)
					for sac=1:length(thisTrial.saccades)
						s=thisTrial.saccades(sac);
						ti = double(s.time); le = double(s.length);
						if ti >= me.plotRange(1)-0.1 && ti+le <= me.plotRange(2)+0.1
							plot3([ti ti+le],[s.gstx s.genx],[s.gsty s.geny],'r-o',...
							'LineWidth',1.5,'MarkerSize',5,'MarkerEdgeColor',[1 0 0],...
							'MarkerFaceColor',c,'UserData',[thisTrial.idx thisTrial.correctedIndex thisTrial.variable],...
							'ButtonDownFcn', @clickMe)
						end
					end
				elseif ~isempty(thisTrial.msacc)
					for sac=1:length(thisTrial.msacc)
						s=thisTrial.msacc(sac);
						ti = s.time; le = s.endtime;
						if ti >= me.plotRange(1)-0.1 && le <= me.plotRange(2)+0.1
							plot3([ti le],[s.dx s.dX],[s.dy s.dY],'r-o',...
							'LineWidth',1.5,'MarkerSize',5,'MarkerEdgeColor',[1 0 0],...
							'MarkerFaceColor',c,'UserData',[thisTrial.idx thisTrial.correctedIndex thisTrial.variable],...
							'ButtonDownFcn', @clickMe)
						end
					end
				end
				
				ax = nexttile(6);
				hold on;
				plot(tp,pupilPlot,'Color',c, 'UserData',[thisTrial.idx thisTrial.correctedIndex thisTrial.variable],'ButtonDownFcn', @clickMe);
				
				idxt = find(t >= t1 & t <= t2);

				tvals{a} = t(idxt);
				xvals{a} = xa(idxt);
				yvals{a} = ya(idxt);
				if isfield(thisTrial,'firstSaccade') && thisTrial.firstSaccade > 0
					sacc = [sacc double(thisTrial.firstSaccade)/1e3];
				end
				meanx = [meanx mean(xa(idxt))];
				meany = [meany mean(ya(idxt))];
				medx = [medx median(xa(idxt))];
				medy = [medy median(ya(idxt))];
				stdex = [stdex std(xa(idxt))];
				stdey = [stdey std(ya(idxt))];

				udt = [thisTrial.idx thisTrial.correctedIndex thisTrial.variable];
				
				ax = nexttile(3);
				hold on;
				plot(meanx(end), meany(end),'ko','Color',c,'MarkerSize',6,'MarkerEdgeColor',[0 0 0],...
					'MarkerFaceColor',c,'UserData', udt,'ButtonDownFcn', @clickMe);

				ax = nexttile(4);
				hold on;
				plot3(meanx(end), meany(end),a,'ko','Color',c,'MarkerSize',6,'MarkerEdgeColor',[0 0 0],...
					'MarkerFaceColor',c,'UserData', udt,'ButtonDownFcn', @clickMe);
				a = a + 1;
				didplot = true;

			end

			if ~didplot 
				close(handle); 
				return; 
			end

			colormap(map);

			display = [80 80];

			ah = nexttile(1);
			ah.ButtonDownFcn = @spawnMe;
			ah.DataAspectRatio = [1 1 1];
			axis equal;
			axis ij;
			grid on;
			box on;
			xlim([xmin xmax]); ylim([ymin ymax]);
			title(ah,[thisVarName upper(type) ': X vs. Y Eye Position']);
			xlabel(ah,'X°');
			ylabel(ah,'Y°');

			ah = nexttile(2);
			ah.ButtonDownFcn = @spawnMe;
			grid on;
			box on;
			axis tight;
			axis([me.plotRange(1) me.plotRange(2) -0.2 maxv+1])
			ti=sprintf('ABS Mean/SD %.2f - %.2f s: X=%.2f / %.2f | Y=%.2f / %.2f', t1,t2,...
				mean(abs(meanx)), mean(abs(stdex)), ...
				mean(abs(meany)), mean(abs(stdey)));
			ti2 = sprintf('ABS Median/SD %.2f - %.2f s: X=%.2f / %.2f | Y=%.2f / %.2f', t1,t2,median(abs(medx)), median(abs(stdex)), ...
				median(abs(medy)), median(abs(stdey)));
			h=title(sprintf('X & Y(dot) Position vs. Time\n%s\n%s', ti,ti2));
			set(h,'BackgroundColor',[1 1 1]);
			xlabel(ah,'Time (s)');
			ylabel(ah,'°');

			ah = nexttile(5);
			ah.ButtonDownFcn = @spawnMe;
			grid on;
			box on;
			axis([me.plotRange(1) me.plotRange(2) -10 10 -10 10]);
			view([35 20]);
			set(gca,'PlotBoxAspectRatio',[2 1 1])
			xlabel(ah,'Time (ms)');
			ylabel(ah,'X Position');
			zlabel(ah,'Y Position');
			[mn,er] = me.stderr(sacc,'SD');
			md = nanmedian(sacc);
			h=title(sprintf('%s %s: Saccades (red) & Fixation (black) | First Saccade mean/median: %.2f / %.2f +- %.2f SD [%.2f <> %.2f]',...
				thisVarName,upper(type),mn,md,er,min(sacc),max(sacc)));
			set(h,'BackgroundColor',[1 1 1]);
			
			ah = nexttile(6);
			ah.ButtonDownFcn = @spawnMe;
			axis([me.plotRange(1) me.plotRange(2) -inf inf]);
			grid on;
			box on;
			title(ah,[thisVarName upper(type) ': Pupil Diameter']);
			xlabel(ah,'Time (s)');
			ylabel(ah,'Diameter');

			ah = nexttile(3);
			ah.ButtonDownFcn = @spawnMe;
			axis ij;
			grid on;
			box on;
			axis tight;
			axis square;
			%axis([-5 5 -5 5])
			h=title(sprintf('X & Y %.2f-%.2fs MD/MN/STD: \nX : %.2f / %.2f / %.2f | Y : %.2f / %.2f / %.2f', ...
				t1,t2,mean(meanx), median(medx),mean(stdex),mean(meany),median(medy),mean(stdey)));
			set(h,'BackgroundColor',[1 1 1]);
			xlabel(ah,'X°');
			ylabel(ah,'Y°');

			ah = nexttile(4);
			ah.ButtonDownFcn = @spawnMe;
			grid on;
			box on;
			axis tight;
			%axis([-5 5 -5 5]);
			%axis square
			view([50 30]);
			title(sprintf('%s %s Mean X & Y Pos %.2f-%.2fs over time',thisVarName,upper(type),t1,t2));
			xlabel(ah,'X°');
			ylabel(ah,'Y°');
			zlabel(ah,'Trial');

			assignin('base','xvals',xvals);
			assignin('base','yvals',yvals);

			function clickMe(src, ~)
				if ~exist('src','var')
					return
				end
				l=get(src,'LineWidth');
				if l > 1;src.LineWidth=1;else;src.LineWidth=3;end
				if isprop(src,'LineStyle')
					l=get(src,'LineStyle');
					if matches(l,'-');src.LineStyle=':';else;src.LineStyle='-';end
				end
				ud = get(src,'UserData');
				if ~isempty(ud)
					disp(me.trials(ud(1)));
					disp(['TRIAL | CORRECTED | VAR | microSaccade time = ' num2str(ud)]);
				end
			end
			function spawnMe(src, ~)
				fnew = figure('Color',[1 1 1]);
				na = copyobj(src,fnew);
				na.Position = [0.1 0.1 0.8 0.8];
			end
		end

		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function parseROI(me)
			if isempty(me.ROI)
				disp('No ROI specified...')
				return
			end
			tROI = tic;
			fixationX = me.ROI(1);
			fixationY = me.ROI(2);
			fixationRadius = me.ROI(3);
			for i = 1:length(me.trials)
				me.ROIInfo(i).variable = me.trials(i).variable;
				me.ROIInfo(i).idx = i;
				me.ROIInfo(i).correctedIndex = me.trials(i).correctedIndex;
				me.ROIInfo(i).uuid = me.trials(i).uuid;
				me.ROIInfo(i).fixationX = fixationX;
				me.ROIInfo(i).fixationY = fixationY;
				me.ROIInfo(i).fixationRadius = fixationRadius;
				x = me.trials(i).gx;
				y = me.trials(i).gy;
				times = me.trials(i).times;
				idx = find(times > 0); % we only check ROI post 0 time
				times = times(idx);
				x = x(idx);
				y = y(idx);
				r = sqrt((x - fixationX).^2 + (y - fixationY).^2);
				within = find(r < fixationRadius);
				if any(within)
					me.ROIInfo(i).enteredROI = true;
				else
					me.ROIInfo(i).enteredROI = false;
				end
				me.trials(i).enteredROI = me.ROIInfo(i).enteredROI;
				me.ROIInfo(i).x = x;
				me.ROIInfo(i).y = y;
				me.ROIInfo(i).times = times;
				me.ROIInfo(i).r = r;
				me.ROIInfo(i).within = within;
				me.ROIInfo(i).correct = me.trials(i).correct;
				me.ROIInfo(i).breakFix = me.trials(i).breakFix;
				me.ROIInfo(i).incorrect = me.trials(i).incorrect;
			end
			fprintf('<strong>:#:</strong> Parsing eyelink region of interest (ROI) took <strong>%g secs</strong>\n', round(toc(tROI)))
		end

		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function parseTOI(me)
			if isempty(me.TOI)
				disp('No TOI specified...')
				return
			end
			tTOI = tic;
			me.ppd;
			if length(me.TOI)==2 && ~isempty(me.ROI); me.TOI = [me.TOI me.ROI]; end
			t1 = me.TOI(1);
			t2 = me.TOI(2);
			fixationX = me.TOI(3);
			fixationY = me.TOI(4);
			fixationRadius = me.TOI(5);
			for i = 1:length(me.trials)
				times = me.trials(i).times;
				x = me.trials(i).gx;
				y = me.trials(i).gy;

				idx = intersect(find(times>=t1), find(times<=t2));
				times = times(idx);
				x = x(idx);
				y = y(idx);

				r = sqrt((x - fixationX).^2 + (y - fixationY).^2);

				within = find(r <= fixationRadius);
				if length(within) == length(r)
					me.TOIInfo(i).isTOI = true;
				else
					me.TOIInfo(i).isTOI = false;
				end
				me.trials(i).isTOI = me.TOIInfo(i).isTOI;
				me.TOIInfo(i).variable = me.trials(i).variable;
				me.TOIInfo(i).idx = i;
				me.TOIInfo(i).correctedIndex = me.trials(i).correctedIndex;
				me.TOIInfo(i).uuid = me.trials(i).uuid;
				me.TOIInfo(i).t1 = t1;
				me.TOIInfo(i).t2 = t2;
				me.TOIInfo(i).fixationX = fixationX;
				me.TOIInfo(i).fixationY = fixationY;
				me.TOIInfo(i).fixationRadius = fixationRadius;
				me.TOIInfo(i).times = times;
				me.TOIInfo(i).x = x;
				me.TOIInfo(i).y = y;
				me.TOIInfo(i).r = r;
				me.TOIInfo(i).within = within;
				me.TOIInfo(i).correct = me.trials(i).correct;
				me.TOIInfo(i).breakFix = me.trials(i).breakFix;
				me.TOIInfo(i).incorrect = me.trials(i).incorrect;
			end
			fprintf('<strong>:#:</strong> Parsing eyelink time of interest (TOI) took <strong>%g secs</strong>\n', round(toc(tTOI)))
		end

		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function plotROI(me)
			if ~isempty(me.ROIInfo)
				h=figure;figpos(1,[2000 1000]);set(h,'Color',[1 1 1],'Name',me.fileName);

				x1 = me.ROI(1) - me.ROI(3);
				x2 = me.ROI(1) + me.ROI(3);
				xmin = min([abs(x1), abs(x2)]);
				xmax = max([abs(x1), abs(x2)]);
				y1 = me.ROI(2) - me.ROI(3);
				y2 = me.ROI(2) + me.ROI(3);
				ymin = min([abs(y1), abs(y2)]);
				ymax = max([abs(y1), abs(y2)]);
				xp = [x1 x1 x2 x2];
				yp = [y1 y2 y2 y1];
				xpp = [xmin xmin xmax xmax];
				ypp = [ymin ymin ymax ymax];
				p=panel(h);
				p.pack(1,2);
				p.fontsize = 14;
				p.margin = [15 15 15 15];
				yes = logical([me.ROIInfo.enteredROI]);
				no = ~yes;
				yesROI = me.ROIInfo(yes);
				noROI	= me.ROIInfo(no);
				p(1,1).select();
				p(1,1).hold('on');
				patch(xp,yp,[1 1 0],'EdgeColor','none');
				p(1,2).select();
				p(1,2).hold('on');
				patch([0 1 1 0],xpp,[1 1 0],'EdgeColor','none');
				patch([0 1 1 0],ypp,[0.5 1 0],'EdgeColor','none');
				for i = 1:length(noROI)
					c = [0.7 0.7 0.7];
					if noROI(i).correct == true
						l = 'o-';
					else
						l = '.--';
					end
					t = noROI(i).times(noROI(i).times >= 0);
					x = noROI(i).x(noROI(i).times >= 0);
					y = noROI(i).y(noROI(i).times >= 0);
					if ~isempty(x)
						p(1,1).select();
						h = plot(x,y,l,'color',c,'MarkerFaceColor',c,'LineWidth',1);
						set(h,'UserData',[noROI(i).idx noROI(i).correctedIndex noROI(i).variable noROI(i).correct noROI(i).breakFix noROI(i).incorrect],'ButtonDownFcn', @clickMeROI);
						p(1,2).select();
						h = plot(t,abs(x),l,t,abs(y),l,'color',c,'MarkerFaceColor',c);
						set(h,'UserData',[noROI(i).idx noROI(i).correctedIndex noROI(i).variable noROI(i).correct noROI(i).breakFix noROI(i).incorrect],'ButtonDownFcn', @clickMeROI);
					end
				end
				for i = 1:length(yesROI)
					c = [0.7 0 0];
					if yesROI(i).correct == true
						l = 'o-';
					else
						l = '.--';
					end
					t = yesROI(i).times(yesROI(i).times >= 0);
					x = yesROI(i).x(yesROI(i).times >= 0);
					y = yesROI(i).y(yesROI(i).times >= 0);
					if ~isempty(x)
						p(1,1).select();
						h = plot(x,y,l,'color',c,'MarkerFaceColor',c);
						set(h,'UserData',[yesROI(i).idx yesROI(i).correctedIndex yesROI(i).variable yesROI(i).correct yesROI(i).breakFix yesROI(i).incorrect],'ButtonDownFcn', @clickMeROI);
						p(1,2).select();
						h = plot(t,abs(x),l,t,abs(y),l,'color',c,'MarkerFaceColor',c);
						set(h,'UserData',[yesROI(i).idx yesROI(i).correctedIndex yesROI(i).variable yesROI(i).correct yesROI(i).breakFix yesROI(i).incorrect],'ButtonDownFcn', @clickMeROI);
					end
				end
				hold off
				p(1,1).select();
				p(1,1).hold('off');
				box on
				grid on
				p(1,1).title(['ROI PLOT for ' num2str(me.ROI) ' (entered = ' num2str(sum(yes)) ' | did not = ' num2str(sum(no)) ')']);
				p(1,1).xlabel('X Position (degs)')
				p(1,1).ylabel('Y Position (degs)')
				axis square
				%axis([-10 10 -10 10]);
				p(1,2).select();
				p(1,2).hold('off');
				box on
				grid on
				p(1,2).title(['ROI PLOT for ' num2str(me.ROI) ' (entered = ' num2str(sum(yes)) ' | did not = ' num2str(sum(no)) ')']);
				p(1,2).xlabel('Time(s)')
				p(1,2).ylabel('Absolute X/Y Position (degs)')
				axis square
				%axis([0 0.5 0 10]);
			end
			function clickMeROI(src, ~)
				if ~exist('src','var')
					return
				end
				ud = get(src,'UserData');
				lw = get(src,'LineWidth');
				if lw < 1.8
					set(src,'LineWidth',2)
				else
					set(src,'LineWidth',1)
				end
				if ~isempty(ud)
					disp(['ROI Trial (idx correctidx var iscorrect isbreak isincorrect): ' num2str(ud)]);
				end
			end
		end

		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function plotTOI(me)
			if isempty(me.TOIInfo)
				disp('No TOI parsed!!!')
				return
			end
			h=figure;figpos(1,[2000 1000]);set(h,'Color',[1 1 1],'Name',me.fileName);

			t1 = me.TOI(1);
			t2 = me.TOI(2);
			x1 = me.TOI(3) - me.TOI(5);
			x2 = me.TOI(3) + me.TOI(5);
			xmin = min([abs(x1), abs(x2)]);
			xmax = max([abs(x1), abs(x2)]);
			y1 = me.TOI(4) - me.TOI(5);
			y2 = me.TOI(4) + me.TOI(5);
			ymin = min([abs(y1), abs(y2)]);
			ymax = max([abs(y1), abs(y2)]);
			xp = [x1 x1 x2 x2];
			yp = [y1 y2 y2 y1];
			xpp = [xmin xmin xmax xmax];
			ypp = [ymin ymin ymax ymax];
			p=panel(h);
			p.pack(1,2);
			p.fontsize = 14;
			p.margin = [15 15 15 15];
			yes = logical([me.TOIInfo.isTOI]);
			no = ~yes;
			yesTOI = me.TOIInfo(yes);
			noTOI	= me.TOIInfo(no);
			p(1,1).select();
			p(1,1).hold('on');
			patch(xp,yp,[1 1 0],'EdgeColor','none');
			p(1,2).select();
			p(1,2).hold('on');
			patch([t1 t2 t2 t1],xpp,[1 1 0],'EdgeColor','none');
			patch([t1 t2 t2 t1],ypp,[0.5 1 0],'EdgeColor','none');
			for i = 1:length(noTOI)
				if noTOI(i).incorrect == true; continue; end
				c = [0.7 0.7 0.7];
				if noTOI(i).correct == true
					l = 'o-';
				else
					l = '.--';
				end
				t = noTOI(i).times;
				x = noTOI(i).x;
				y = noTOI(i).y;
				if ~isempty(x)
					p(1,1).select();
					h = plot(x,y,l,'color',c,'MarkerFaceColor',c,'LineWidth',1);
					set(h,'UserData',[noTOI(i).idx noTOI(i).correctedIndex noTOI(i).variable noTOI(i).correct noTOI(i).breakFix noTOI(i).incorrect],'ButtonDownFcn', @clickMeTOI);
					p(1,2).select();
					h = plot(t,abs(x),l,t,abs(y),l,'color',c,'MarkerFaceColor',c);
					set(h,'UserData',[noTOI(i).idx noTOI(i).correctedIndex noTOI(i).variable noTOI(i).correct noTOI(i).breakFix noTOI(i).incorrect],'ButtonDownFcn', @clickMeTOI);
				end
			end
			for i = 1:length(yesTOI)
				if yesTOI(i).incorrect == true; continue; end
				c = [0.7 0 0];
				if yesTOI(i).correct == true
					l = 'o-';
				else
					l = '.--';
				end
				t = yesTOI(i).times;
				x = yesTOI(i).x;
				y = yesTOI(i).y;
				if ~isempty(x)
					p(1,1).select();
					h = plot(x,y,l,'color',c,'MarkerFaceColor',c);
					set(h,'UserData',[yesTOI(i).idx yesTOI(i).correctedIndex yesTOI(i).variable yesTOI(i).correct yesTOI(i).breakFix yesTOI(i).incorrect],'ButtonDownFcn', @clickMeTOI);
					p(1,2).select();
					h = plot(t,abs(x),l,t,abs(y),l,'color',c,'MarkerFaceColor',c);
					set(h,'UserData',[yesTOI(i).idx yesTOI(i).correctedIndex yesTOI(i).variable yesTOI(i).correct yesTOI(i).breakFix yesTOI(i).incorrect],'ButtonDownFcn', @clickMeTOI);
				end
			end
			hold off
			p(1,1).select();
			p(1,1).hold('off');
			box on
			grid on
			p(1,1).title(['TOI PLOT for ' num2str(me.TOI) ' (yes = ' num2str(sum(yes)) ' || no = ' num2str(sum(no)) ')']);
			p(1,1).xlabel('X Position (degs)')
			p(1,1).ylabel('Y Position (degs)')
			%axis([-4 4 -4 4]);
			axis square
			p(1,2).select();
			p(1,2).hold('off');
			box on
			grid on
			p(1,2).title(['TOI PLOT for ' num2str(me.TOI) ' (yes = ' num2str(sum(yes)) ' || no = ' num2str(sum(no)) ')']);
			p(1,2).xlabel('Time(s)')
			p(1,2).ylabel('Absolute X/Y Position (degs)')
			%axis([t1 t2 0 4]);
			axis square

			function clickMeTOI(src, ~)
				if ~exist('src','var')
					return
				end
				ud = get(src,'UserData');
				lw = get(src,'LineWidth');
				if lw < 1.8
					set(src,'LineWidth',2)
				else
					set(src,'LineWidth',1)
				end
				if ~isempty(ud)
					disp(['TOI Trial (idx correctidx var iscorrect isbreak isincorrect): ' num2str(ud)]);
				end
			end
		end

		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function ppd = get.ppd(me)
			if me.distance == 57.3 && me.override573 == true
				ppd = round( me.pixelsPerCm * (67 / 57.3)); %set the pixels per degree, note this fixes some older files where 57.3 was entered instead of 67cm
			else
				ppd = round( me.pixelsPerCm * (me.distance / 57.3)); %set the pixels per degree
			end
			me.ppd_ = ppd;
		end

		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function fixVarNames(me)
			if me.needOverride == true
				if isempty(me.trialOverride)
					warning('No replacement trials available!!!')
					return
				end
				trials = me.trialOverride; %#ok<*PROP>
				if  max([me.trials.correctedIndex]) ~= length(trials)
					warning('TRIAL ID LENGTH MISMATCH!');
					return
				end
				a = 1;
				me.trialList = [];
				for j = 1:length(me.trials)
					if me.trials(j).incorrect ~= true
						if a <= length(trials) && me.trials(j).correctedIndex == trials(a).index
							me.trials(j).oldid = me.trials(j).variable;
							me.trials(j).variable = trials(a).variable;
							me.trialList(j) = me.trials(j).variable;
							if me.trials(j).breakFix == true
								me.trialList(j) = -[me.trialList(j)];
							end
							a = a + 1;
						end
					end
				end
				parseAsVars(me); %need to redo this now
				warning('---> Trial name override in place!!!')
			else
				me.trialOverride = struct();
			end
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function removeRawData(me)
			
			me.raw = [];
			me.markers = [];
			
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function reparseVars(me)
			me.parseAsVars;
		end

		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function plotNH(me, trial, handle)
			if ~me.isParsed;return;end
			if ~exist('handle','var'); handle=[]; end
			try
				if isempty(handle)
					handle=figure('Name','Saccade Plots','Color',[1 1 1],'NumberTitle','off',...
						'Papertype','a4','PaperUnits','centimeters',...
						'PaperOrientation','landscape');
					figpos(1,[0.5 0.9],1,'%');
				end
				figure(handle);
				data = me.trials(trial).data;
				me.ETparams.screen.rect = struct('deg', [-5 -5 5 5]);
				plotClassification(data,'deg','vel',me.ETparams.samplingFreq,...
					me.ETparams.glissade.searchWindow,me.ETparams.screen.rect,...
					'title','Test','showSacInScan',true); 
			catch ME
				getReport(ME)
			end
		end

		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function explore(me, close)
			persistent ww hh fig figA figB N

			if exist('close','var') && close == true
				try delete(figB); end
				try delete(figA); end
				try delete(fig.f); end
				fig = []; figA = []; figB = [];
				return;
			end
			if isempty(N); N = 1; end
			if isempty(fig); fig.f = figure('Units','Normalized','Position',[0 0.8 0.05 0.2],'CloseRequestFcn',@exploreClose); end
			if isempty(figA); figA = figure('Units','Normalized','Position',[0.05 0 0.45 1],'CloseRequestFcn',@exploreClose); end
			if isempty(figB); figB = figure('Units','Normalized','Position',[0.5 0 0.5 1],'CloseRequestFcn',@exploreClose); end

			if isempty(fig.f.Children)|| ~ishandle(fig.f)
				fig.b0 = uicontrol('Parent',fig.f,'Units','Normalized',...
					'Style','text','String',['TRIAL: ' num2str(N)],'Position',[0.1 0.8 0.8 0.1]);
				fig.b1 = uicontrol('Parent',fig.f,'Units','Normalized',...
					'String','Next','Position',[0.1 0.1 0.8 0.3],...
					'Callback', @exploreNext);
				fig.b2 = uicontrol('Parent',fig.f,'Units','Normalized',...
					'String','Previous','Position',[0.1 0.5 0.8 0.3],...
					'Callback', @explorePrevious);
			end

			if isempty(figA.Children) ; N = 0; exploreNext(); end

			function exploreNext(src, ~)
				N = N + 1;
				if N > length(me.trials); N = 1; end
				clf(figA); clf(figB);
				plotNH(me,N,figB);
				plot(me,N,[],[],[],figA);
				fig.b0.String = ['TRIAL: ' num2str(N)];
			end
			function explorePrevious(src, ~)
				N = N - 1;
				if N < 1; N = length(me.trials); end
				clf(figA); clf(figB);
				plotNH(me,N,figB);
				plot(me,N,[],[],[],figA);
				fig.b0.String = ['TRIAL: ' num2str(N)];
			end
			function exploreClose(src, ~)
				me.explore(true);
			end

		end

	end%-------------------------END PUBLIC METHODS--------------------------------%

	%==============================================================================
	methods (Access = protected) %----------------------------------PRIVATE METHODS
	%==============================================================================

		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function closeUI(me, varargin)
			try delete(me.handles.parent); end %#ok<TRYNC>
			me.handles = struct();
			me.openUI = false;
		end

		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function makeUI(me, varargin)
			disp('Feature not finished yet...')
		end

		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function updateUI(me, varargin)

		end

		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function notifyUI(me, varargin)

		end

		% ===================================================================
		%> @brief main parse loop for CSV events, has to be one big serial loop
		%>
		%> @param
		%> @return
		% ===================================================================
		function parseEvents(me)
			isTrial = false;
			tri = 0; %current trial that is being parsed
			me.correct.idx = [];
			me.correct.saccTimes = [];
			me.correct.fixations = [];
			me.correct.timeRange = [];
			me.breakFix = me.correct;
			me.incorrect = me.correct;
			me.unknown = me.correct;
			me.trialList = [];

			tmain = tic;
			
			trialDef = getTrialDef(me);

			me.ppd; %faster to cache this now (dependant property sets ppd_ too)

			if ~isempty(me.markers) && ~isempty(me.raw)

				if matches(me.variableMessageName,'number')	
					me.trialStartMessageName = 0;
				end

				FEVENTN = height(me.markers);
				pb = textprogressbar(FEVENTN, 'startmsg', 'Parsing iRec Events: ',...
				'showactualnum', true,'updatestep', round(FEVENTN/(FEVENTN/20)));

				for ii = 1:FEVENTN
					m = me.markers.data(ii);
					if m == intmin('int32')
						continue;
					elseif m > me.trialStartMessageName
						if isTrial == true
							tri = tri - 1;
							isTrial = false;
							continue;
						end
						tri = tri + 1;
						isTrial = true;
						trial = trialDef;
						trial.variable = m;
						trial.idx = tri;
						trial.correctedIndex = trial.idx;
						trial.sttime = me.markers.time_cpu(ii);
						trial.rtstarttime = trial.sttime;
						trial.synctime = trial.sttime;
						trial.startsampletime = trial.sttime + me.measureRange(1);
					elseif m == me.SYNCTIME
						if isTrial
							trial.synctime = me.markers.time_cpu(ii);
						end
					elseif m == me.END_FIX
						if isTrial
							trial.endfix = me.markers.time_cpu(ii);
						end
					elseif m == me.END_RT
						if isTrial
							trial.rtendtime = me.markers.time_cpu(ii);
						end
					elseif m == me.END_EXP
						break;
					elseif m == me.trialEndMessage
						trial.entime = me.markers.time_cpu(ii);
						if isnan(trial.rtendtime);trial.rtendtime = trial.entime;end
						if me.relativeMarkers == true
							trial.endsampletime = trial.entime + me.measureRange(2);
						else
							if me.measureRange(2) <= 0
								trial.endsampletime = trial.entime;
							else
								trial.endsampletime = trial.synctime + me.measureRange(2);
							end
						end
						idx = find(me.raw.time >= trial.startsampletime & me.raw.time <= trial.endsampletime);
						trial.times = me.raw.time(idx) - trial.synctime;
						trial.timeRange = [min(trial.times) max(trial.times)];
						trial.gx = me.raw.x(idx);
						trial.gy = me.raw.y(idx);
						trial.pa = me.raw.pupil(idx);
						trial.pratio = me.raw.pratio(idx);
						trial.blink = me.raw.blink(idx);
						trial.deltaT = trial.entime - trial.sttime;
						if isempty(trial.gx)
							trial.invalid = true;
						else
							trial.correct = true;
						end
						if trial.endsampletime > trial.entime
							%warning('Sample beyond end marker on trial %i',tri);
						end
						if tri == 1
							me.trials = trial;
						else
							me.trials(tri) = trial;
						end
						isTrial = false;
					end
					pb(ii);
				end
				pb(ii);

				if isempty(me.trials)
					warning('---> iRecAnalysis.parseEvents: No trials could be parsed in this data!')
					return
				end

				%prune the end trial if invalid
				me.correct.idx = find([me.trials.correct] == true);
				me.breakFix.idx = find([me.trials.breakFix] == true);
				me.incorrect.idx = find([me.trials.incorrect] == true);
					
				% time range for correct trials
				tr = [me.trials(me.correct.idx).timeRange];
				tr = reshape(tr,[2,length(tr)/2])';
				me.correct.timeRange = tr;
				me.plotRange = [min(tr(:,1)) max(tr(:,2))];
				me.isParsed = true;

				fprintf('<strong>:#:</strong> Parsing CSV Events into %i Trials took <strong>%.2f secs</strong>\n',length(me.trials),toc(tmain));
		
			end	
		end

		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function parseAsVars(me)
			if isempty(me.trials)
				warning('---> eyelinkAnalysis.parseAsVars: No trials and therefore cannot extract variables!')
				return
			end
			me.vars = struct();
			me.vars(1).name = '';
			me.vars(1).var = [];
			me.vars(1).varidx = [];
			me.vars(1).variable = [];
			me.vars(1).idx = [];
			me.vars(1).idxcorrect = [];
			me.vars(1).correctedidx = [];
			me.vars(1).correct = [];
			me.vars(1).result = [];
			me.vars(1).trial = [];
			me.vars(1).sTime = [];
			me.vars(1).sT = [];
			me.vars(1).uuid = {};

			uniqueVars = sort(unique([me.trials.variable]));

			for i = 1:length(me.trials)
				trial = me.trials(i);
				var = trial.variable;
				if trial.incorrect == true
					continue
				end
				idx = find(uniqueVars==var);
				me.vars(idx).name = num2str(var);
				me.vars(idx).var = var;
				me.vars(idx).varidx = [me.vars(idx).varidx idx];
				me.vars(idx).variable = [me.vars(idx).variable var];
				me.vars(idx).idx = [me.vars(idx).idx i];
				me.vars(idx).correct = [me.vars(idx).correct trial.correct];
				if trial.correct > 0
					me.vars(idx).idxcorrect = [me.vars(idx).idxcorrect i];
				end
				me.vars(idx).result = [me.vars(idx).result trial.result];
				me.vars(idx).correctedidx = [me.vars(idx).correctedidx i];
				me.vars(idx).trial = [me.vars(idx).trial; trial];
				me.vars(idx).uuid = [me.vars(idx).uuid, trial.uuid];
				if ~isempty(trial.saccadeTimes)
					me.vars(idx).sTime = [me.vars(idx).sTime trial.saccadeTimes(1)];
				else
					me.vars(idx).sTime = [me.vars(idx).sTime NaN];
				end
				me.vars(idx).sT = [me.vars(idx).sT trial.firstSaccade];
			end
		end

		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function parseSecondaryEyePos(me)
			if me.isParsed && isstruct(me.tS) && ~isempty(me.tS)
				f=fieldnames(me.tS.eyePos); %get fieldnames
				re = regexp(f,'^CC','once'); %regexp over the cell
				idx = cellfun(@(c)~isempty(c),re); %check which regexp returned true
				f = f(idx); %use this index
				me.validation(1).uuids = f;
				me.validation.lengthCorrect = length(f);
				if length(me.correct.idx) == me.validation.lengthCorrect
					disp('Secondary Eye Position Data appears consistent with CSV parsed trials')
				else
					warning('Secondary Eye Position Data inconsistent with CSV parsed trials')
				end
			end
		end

		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function parseFixationPositions(me)
			if me.isParsed
				for i = 1:length(me.trials)
					t = me.trials(i);
					f(1).isFix = false;
					f(1).idx = -1;
					f(1).times = -1;
					f(1).x = -1;
					f(1).y = -1;
					if isfield(t.fixations,'time')
						times = [t.fixations.time];
						fi = find(times > 50);
						if ~isempty(fi)
							f(1).isFix = true;
							f(1).idx = i;
							for jj = 1:length(fi)
								fx =  t.fixations(fi(jj));
								f(1).times(jj) = fx.time;
								f(1).x(jj) = fx.x;
								f(1).y(jj) = fx.y;
							end
						end
					end
					if t.correct == true
						bname='correct';
					elseif t.breakFix == true
						bname='breakFix';
					else
						bname='incorrect';
					end
					if isempty(me.(bname).fixations)
						me.(bname).fixations = f;
					else
						me.(bname).fixations(end+1) = f;
					end
				end

			end

		end

		% ===================================================================
		%> @brief
		%>
		% ===================================================================
		function [outx, outy] = toDegrees(me,in)
			if length(in)==2
				outx = (in(1) - me.xCenter) / me.ppd_;
				outy = (in(2) - me.yCenter) / me.ppd_;
			else
				outx = [];
				outy = [];
			end
		end

		% ===================================================================
		%> @brief
		%>
		% ===================================================================
		function [outx, outy] = toPixels(me,in)
			if length(in)==2
				outx = (in(1) * me.ppd_) + me.xCenter;
				outy = (in(2) * me.ppd_) + me.yCenter;
			else
				outx = [];
				outy = [];
			end
		end

		% ===================================================================
		%> @brief
		%>
		% ===================================================================
		function computeFullSaccades(me)
			assert(exist('runNH2010Classification.m'),'Please add NystromHolmqvist2010 to path!');
			% load parameters for event classifier
			if isempty(me.ETparams)
				me.ETparams = defaultParameters;
				% settings for code specific to Niehorster, Siu & Li (2015)
				me.ETparams.extraCut    = [0 0];                       % extra ms of data to cut before and after saccade.
				me.ETparams.qInterpMissingPos   = true;                 % interpolate using straight lines to replace missing position signals?
				
				% settings for the saccade cutting (see cutSaccades.m for documentation)
				me.ETparams.cutPosTraceMode     = 1;
				me.ETparams.cutVelTraceMode     = 1;
				me.ETparams.cutSaccadeSkipWindow= 1;    % don't cut during first x seconds
				me.ETparams.screen.resolution              = [ me.resolution(1) me.resolution(2) ];
				me.ETparams.screen.size                    = [ me.resolution(1)/me.pixelsPerCm/100 me.resolution(2)/me.pixelsPerCm/100 ];
				me.ETparams.screen.viewingDist             = me.distance/100;
				me.ETparams.screen.dataCenter              = [ me.resolution(1)/2 me.resolution(2)/2 ];  % center of screen has these coordinates in data
				me.ETparams.screen.subjectStraightAhead    = [ me.resolution(1)/2 me.resolution(2)/2 ];  % Specify the screen coordinate that is straight ahead of the subject. Just specify the middle of the screen unless its important to you to get this very accurate!
				% change some defaults as needed for this analysis:
				me.ETparams.data.alsoStoreComponentDerivs  = true;
				me.ETparams.data.detrendWithMedianFilter   = true;
				me.ETparams.data.applySaccadeTemplate      = true;
				me.ETparams.data.minDur                    = 100;
				me.ETparams.fixation.doClassify            = true;
				me.ETparams.blink.replaceWithInterp        = true;
				me.ETparams.blink.replaceVelWithNan        = true;
			end
			me.ETparams.samplingFreq = me.sampleRate;
			
			% process params
			ETparams = prepareParameters(me.ETparams);

			for ii = 1:length(me.trials)
				fprintf('--->>> Full saccadic analysis of Trial %i:\n',ii);
				x = (me.trials(ii).gx * me.ppd) + ETparams.screen.dataCenter(1);
				y = (me.trials(ii).gy * me.ppd) + ETparams.screen.dataCenter(2);
				p = me.trials(ii).pa;
				t = me.trials(ii).times * 1e3;

				if length(x) < me.ETparams.data.minDur
					data = struct([]);
				else
					data = runNH2010Classification(x,y,p,ETparams,t);
					% replace missing data by linearly interpolating position and velocity
    				% between start and end of each missing interval (so, creating a ramp
    				% between start and end position/velocity).
    				data = replaceMissing(data,ETparams.qInterpMissingPos);
				end
    			
    			% desaccade velocity and/or position
    			%data = cutSaccades(data,ETparams,cutPosTraceMode,cutVelTraceMode,extraCut,cutSaccadeSkipWindow);
    			% construct saccade only traces
    			%data = cutPursuit(data,ETparams,1);

				me.trials(ii).data = data;

			end

		end

		% ===================================================================
		%> @brief
		%>
		% ===================================================================
		function computeMicrosaccades(me)
			VFAC=me.VFAC;
			MINDUR=me.MINDUR;
			sampleRate = me.sampleRate;
			pb = textprogressbar(length(me.trials),'startmsg','Loading trials to compute microsaccades: ','showactualnum',true);
			cms = tic;
			for jj = 1:length(me.trials)
				if me.trials(jj).invalid == true || me.trials(jj).unknown == true;	continue;	end
				samples = []; sac = []; radius = []; monol=[]; monor=[];
				me.trials(jj).msacc = struct();
				me.trials(jj).sampleSaccades = [];
				me.trials(jj).microSaccades = [];
				samples(:,1) = me.trials(jj).times;
				samples(:,2) = me.trials(jj).gx;
				samples(:,3) = me.trials(jj).gy;
				samples(:,4) = nan(size(samples(:,1)));
				samples(:,5) = samples(:,4);
				eye_used = 0;
				try
					switch eye_used
						case 0
							v = vecvel(samples(:,2:3),sampleRate,2);
							[sac, radius] = microsacc(samples(:,2:3),v,VFAC,MINDUR);
						case 1
							v = vecvel(samples(:,2:3),sampleRate,2);
							[sac, radius] = microsacc(samples(:,4:5),v,VFAC,MINDUR);
						case 2
							MSlcoords=samples(:,2:3);
							MSrcoords=samples(:,4:5);
							vl = vecvel(MSlcoords,sampleRate,2);
							vr = vecvel(MSrcoords,sampleRate,2);
							[sacl, radiusl] = microsacc(MSlcoords,vl,VFAC,MINDUR);
							[sacr, radiusr] = microsacc(MSrcoords,vr,VFAC,MINDUR);
							[bsac, monol, monor] = binsacc(sacl,sacr);
							sac = saccpar(bsac);
					end
					me.trials(jj).radius = radius;
					for ii = 1:size(sac,1)
						me.trials(jj).msacc(ii).n = round(sac(ii,1));
						me.trials(jj).msacc(ii).time = samples(sac(ii,1),1);
						me.trials(jj).msacc(ii).endtime = samples(sac(ii,2),1);
						me.trials(jj).msacc(ii).velocity = sac(ii,3);
						me.trials(jj).msacc(ii).dx = sac(ii,4);
						me.trials(jj).msacc(ii).dy = sac(ii,5);
						me.trials(jj).msacc(ii).dX = sac(ii,6);
						me.trials(jj).msacc(ii).dY = sac(ii,7);
						[theta,rho]=cart2pol(sac(ii,6),sac(ii,7));
						me.trials(jj).msacc(ii).theta = me.rad2ang(theta);
						me.trials(jj).msacc(ii).rho = rho;
						me.trials(jj).msacc(ii).isMicroSaccade = rho<=me.minSaccadeDistance;
					end
					if ~isempty(sac)
						me.trials(jj).sampleSaccades = [me.trials(jj).msacc(:).time];
						me.trials(jj).microSaccades = [me.trials(jj).sampleSaccades([me.trials(jj).msacc(:).isMicroSaccade])];
					else
						me.trials(jj).sampleSaccades = NaN;
						me.trials(jj).microSaccades = NaN;
					
					end
					if isempty(me.trials(jj).microSaccades); me.trials(jj).microSaccades = NaN; end
				catch ME
					getReport(ME)
				end
				pb(jj)
			end
			fprintf('<strong>:#:</strong> Parsing MicroSaccades took <strong>%g secs</strong>\n', round(toc(cms)))

			function v = vecvel(xx,SAMPLING,TYPE)
				%------------------------------------------------------------
				%  FUNCTION vecvel.m
				%  Calculation of eye velocity from position data
				%
				%  INPUT:
				%   xy(1:N,1:2)     raw data, x- and y-components of the time series
				%   SAMPLING        sampling rate (number of samples per second)
				%   TYPE            velocity type: TYPE=2 recommended
				%
				%  OUTPUT:
				%   v(1:N,1:2)      velocity, x- and y-components
				%-------------------------------------------------------------

				N = length(xx);            % length of the time series
				v = zeros(N,2);

				switch TYPE
					case 1
						v(2:N-1,:) = [xx(3:end,:) - xx(1:end-2,:)]*SAMPLING/2;
					case 2
						v(3:N-2,:) = [xx(5:end,:) + xx(4:end-1,:) - xx(2:end-3,:) - xx(1:end-4,:)]*SAMPLING/6;
						v(2,:)     = [xx(3,:) - xx(1,:)]*SAMPLING/2;
						v(N-1,:)   = [xx(end,:) - xx(end-2,:)]*SAMPLING/2;
				end
				return
			end

			function [sac, radius] = microsacc(x,vel,VFAC,MINDUR)
				%-------------------------------------------------------------------
				%  FUNCTION microsacc.m
				%  Detection of monocular candidates for microsaccades;
				%
				%  INPUT:
				%   x(:,1:2)         position vector
				%   vel(:,1:2)       velocity vector
				%   VFAC             relative velocity threshold
				%   MINDUR           minimal saccade duration
				%
				%  OUTPUT:
				%   radius         threshold velocity (x,y) used to distinguish microsaccs
				%   sac(1:num,1)   onset of saccade
				%   sac(1:num,2)   end of saccade
				%   sac(1:num,3)   peak velocity of saccade (vpeak)
				%   sac(1:num,4)   horizontal component     (dx)
				%   sac(1:num,5)   vertical component       (dy)
				%   sac(1:num,6)   horizontal amplitude     (dX)
				%   sac(1:num,7)   vertical amplitude       (dY)
				%---------------------------------------------------------------------
				% SDS... VFAC (relative velocity threshold) E&M 2006 use a value of VFAC=5

				% compute threshold
				% SDS... this is sqrt[median(x^2) - (median x)^2]
				msdx = sqrt( median(vel(:,1).^2,'omitnan') - (median(vel(:,1),'omitnan'))^2 );
				msdy = sqrt( median(vel(:,2).^2,'omitnan') - (median(vel(:,2),'omitnan'))^2 );
				if msdx<realmin
					msdx = sqrt( mean(vel(:,1).^2,'omitnan') - (mean(vel(:,1),'omitnan'))^2 );
					if msdx<realmin
						disp(['TRIAL: ' num2str(jj) ' msdx<realmin in eyelinkAnalysis.microsacc']);
					end
				end
				if msdy<realmin
					msdy = sqrt( mean(vel(:,2).^2,'omitnan') - (mean(vel(:,2),'omitnan'))^2 );
					if msdy<realmin
						disp(['TRIAL: ' num2str(jj) ' msdy<realmin in eyelinkAnalysis.microsacc']);
					end
				end
				radiusx = VFAC*msdx;
				radiusy = VFAC*msdy;
				radius = [radiusx radiusy];

				% compute test criterion: ellipse equation
				test = (vel(:,1)/radiusx).^2 + (vel(:,2)/radiusy).^2;
				indx = find(test>1);

				% determine saccades
				% SDS..  this loop reads through the index of above-threshold velocities,
				%        storing the beginning and end of each period (i.e. each saccade)
				%        as the position in the overall time series of data submitted
				%        to the analysis
				N = length(indx);
				sac = [];
				nsac = 0;
				dur = 1;
				a = 1;
				k = 1;
				while k<N
					if indx(k+1)-indx(k)==1     % looks 1 instant ahead of current instant
						dur = dur + 1;
					else
						if dur>=MINDUR
							nsac = nsac + 1;
							b = k;             % hence b is the last instant of the consecutive series constituting a microsaccade
							sac(nsac,:) = [indx(a) indx(b)];
						end
						a = k+1;
						dur = 1;
					end
					k = k + 1;
				end

				% check for minimum duration
				% SDS.. this just deals with the final set of above threshold
				%       velocities; adds it to the list if the duration is long enough
				if dur>=MINDUR
					nsac = nsac + 1;
					b = k;
					sac(nsac,:) = [indx(a) indx(b)];
				end

				% compute peak velocity, horizonal and vertical components
				for s=1:nsac
					% onset and offset
					a = sac(s,1);
					b = sac(s,2);
					% saccade peak velocity (vpeak)
					vpeak = max( sqrt( vel(a:b,1).^2 + vel(a:b,2).^2 ) );
					sac(s,3) = vpeak;
					% saccade vector (dx,dy)            SDS..  this is the difference between initial and final positions
					dx = x(b,1)-x(a,1);
					dy = x(b,2)-x(a,2);
					sac(s,4) = dx;
					sac(s,5) = dy;

					% saccade amplitude (dX,dY)         SDS.. this is the difference between max and min positions over the excursion of the msac
					i = sac(s,1):sac(s,2);
					[minx, ix1] = min(x(i,1));              %       dX > 0 signifies rightward  (if ix2 > ix1)
					[maxx, ix2] = max(x(i,1));              %       dX < 0 signifies  leftward  (if ix2 < ix1)
					[miny, iy1] = min(x(i,2));              %       dY > 0 signifies    upward  (if iy2 > iy1)
					[maxy, iy2] = max(x(i,2));              %       dY < 0 signifies  downward  (if iy2 < iy1)
					dX = sign(ix2-ix1)*(maxx-minx);
					dY = sign(iy2-iy1)*(maxy-miny);
					sac(s,6:7) = [dX dY];
				end

			end

			function [sac, monol, monor] = binsacc(sacl,sacr)
				%-------------------------------------------------------------------
				%  FUNCTION binsacc.m
				%
				%  INPUT: saccade matrices from FUNCTION microsacc.m
				%   sacl(:,1:7)       microsaccades detected from left eye
				%   sacr(:,1:7)       microsaccades detected from right eye
				%
				%  OUTPUT:
				%   sac(:,1:14)       binocular microsaccades (right eye/left eye)
				%   monol(:,1:7)      monocular microsaccades of the left eye
				%   monor(:,1:7)      monocular microsaccades of the right eye
				%---------------------------------------------------------------------
				% SDS.. The aim of this routine is to pair up msaccs in L & R eyes that are
				%       coincident in time. Some msaccs in one eye may not have a matching
				%       msacc in the other; the code also seems to allow for a msacc in one
				%       eye matching 2 events in the other eye - in which case the
				%       larger amplitude one is selected, and the other discarded.

				if size(sacr,1)*size(sacl,1)>0

					% determine saccade clusters
					TR = max(sacr(:,2));
					TL = max(sacl(:,2));
					T = max([TL TR]);
					s = zeros(1,T+1);
					for i=1:size(sacl,1)
						s(sacl(i,1)+1:sacl(i,2)) = 1;   % SDS.. creates time-series with 1 for duration of left eye  msacc events and 0 for duration of intervals
						% NB.   sacl(i,1)+1    the +1 is necessary for the diff function [line 219] to correctly pick out the start instants of msaccs
					end
					for i=1:size(sacr,1)
						s(sacr(i,1)+1:sacr(i,2)) = 1;   % SDS.. superimposes similar for right eye; hence a time-series of binocular events
					end                                 %   ... 'binocular' means that either L, R or both eyes moved
					s(1) = 0;
					s(end) = 0;
					m = find(diff(s~=0));   % SDS.. finds time series positions of start and ends of (binocular) m.saccd phases
					N = length(m)/2;        % SDS.. N = number of microsaccades
					m = reshape(m,2,N)';    % SDS.. col 1 is all sacc onsets; col 2 is all sacc end points

					% determine binocular saccades
					NB = 0;
					NR = 0;
					NL = 0;
					sac = [];
					monol = [];
					monor = [];
					% SDS..  the loop counts through each position in the binoc list
					for i=1:N                                               % ..  'find' operates on the sacl (& sacr) matrices;
						l = find( m(i,1)<=sacl(:,1) & sacl(:,2)<=m(i,2) );  % ..   finds position of msacc in L eye list to match the timing of each msacc in binoc list (as represented by 'm')
						r = find( m(i,1)<=sacr(:,1) & sacr(:,2)<=m(i,2) );  % ..   finds position of msacc in R eye list ...
						% ..   N.B. some 'binoc' msaccs will not match one or other of the monoc lists
						if length(l)*length(r)>0                            % SDS..   Selects binoc msaccs.  [use of 'length' function is a bit quaint..  l and r should not be vectors, but single values..?]
							ampr = sqrt(sacr(r,6).^2+sacr(r,7).^2);         % ..      is allowing for 2 (or more) discrete monocular msaccs coinciding with a single event in the 'binoc' list
							ampl = sqrt(sacl(l,6).^2+sacl(l,7).^2);
							[h ir] = max(ampr);                             % hence r(ir) in L241 is the position in sacr of the larger amplitude saccade (if there are 2 or more that occurence of binoc saccade)
							[h il] = max(ampl);                             % hence l(il) in L241 is the position in sacl of the larger amplitude saccade (if there are 2 or more that occurence of binoc saccade)
							NB = NB + 1;
							sac(NB,:) = [sacr(r(ir),:) sacl(l(il),:)];      % ..      the final compilation selects the larger amplitude msacc to represent the msacc in that eye
						else
							% determine monocular saccades
							if isempty(l)                                 % If no msacc in L eye
								NR = NR + 1;
								monor(NR,:) = sacr(r,:);                    %..  record R eye monoc msacc.
							end
							if isempty(r)                                 %If no msacc in R eye
								NL = NL + 1;
								monol(NL,:) = sacl(l,:);                    %..  record L eye monoc msacc
							end
						end
					end
				else
					% special cases of exclusively monocular saccades
					if size(sacr,1)==0
						sac = [];
						monor = [];
						monol = sacl;
					end
					if size(sacl,1)==0
						sac = [];
						monol = [];
						monor = sacr;
					end
				end
			end

			function sac = saccpar(bsac)
				%-------------------------------------------------------------------
				%  FUNCTION saccpar.m
				%  Calculation of binocular saccade parameters;
				%
				%  INPUT: binocular saccade matrix from FUNCTION binsacc.m
				%   sac(:,1:14)       binocular microsaccades
				%
				%  OUTPUT:
				%   sac(:,1:9)        parameters averaged over left and right eye data
				%---------------------------------------------------------------------
				if size(bsac,1)>0
					sacr = bsac(:,1:7);
					sacl = bsac(:,8:14);

					% 1. Onset
					a = min([sacr(:,1)'; sacl(:,1)'])';     % produces single column vector of ealier onset in L v R eye msaccs

					% 2. Offset
					b = max([sacr(:,2)'; sacl(:,2)'])';     % produces single column vector of later offset in L v R eye msaccs

					% 3. Duration
					DR = sacr(:,2)-sacr(:,1)+1;
					DL = sacl(:,2)-sacl(:,1)+1;
					D = (DR+DL)/2;

					% 4. Delay between eyes
					delay = sacr(:,1) - sacl(:,1);

					% 5. Peak velocity
					vpeak = (sacr(:,3)+sacl(:,3))/2;

					% 6. Saccade distance
					dist = (sqrt(sacr(:,4).^2+sacr(:,5).^2)+sqrt(sacl(:,4).^2+sacl(:,5).^2))/2;
					angle1 = atan2((sacr(:,5)+sacl(:,5))/2,(sacr(:,4)+sacl(:,4))/2);

					% 7. Saccade amplitude
					ampl = (sqrt(sacr(:,6).^2+sacr(:,7).^2)+sqrt(sacl(:,6).^2+sacl(:,7).^2))/2;
					angle2 = atan2((sacr(:,7)+sacl(:,7))/2,(sacr(:,6)+sacl(:,6))/2);        %SDS..  NB 'atan2'function operates on (y,x) - not (x,y)!

					sac = [a b D delay vpeak dist angle1 ampl angle2];
				else
					sac = [];
				end
			end

		end

		% ===================================================================
		%> @brief
		%>
		% ===================================================================
		function trialDef = getTrialDef(me)
			trialDef = cell2struct(repmat({[]},length(me.trialsTemplate),1),me.trialsTemplate);
			trialDef.rt = false;
			trialDef.rtoverride = false;
			trialDef.firstSaccade = NaN;
			trialDef.invalid = false;
			trialDef.correct = false;
			trialDef.breakFix = false;
			trialDef.incorrect = false;
			trialDef.unknown = false;
			trialDef.sttime = NaN;
			trialDef.entime = NaN;
			trialDef.totaltime = 0;
			trialDef.startsampletime = NaN;
			trialDef.endsampletime = NaN;
			trialDef.timeRange = [NaN NaN];
			trialDef.rtstarttime = NaN;
			trialDef.rtstarttimeOLD = NaN;
			trialDef.rtendtime = NaN;
			trialDef.synctime = NaN;
			trialDef.deltaT = NaN;
			trialDef.rttime = NaN;
		end

	end

end

