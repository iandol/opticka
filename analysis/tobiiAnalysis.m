% ========================================================================
%> @brief eyelinkAnalysis offers a set of methods to load, parse & plot raw EDF files. It
%> understands opticka trials (where messages TRIALID start a trial and TRIAL_RESULT
%> ends a trial by default) so can parse eye data and plot it for trial groups. You
%> can also manually find microsaccades, and perform ROI/TOI filtering on the eye
%> movements.
%>
%> Copyright ©2014-2022 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ========================================================================
classdef tobiiAnalysis < analysisCore
	% eyelinkAnalysis offers a set of methods to load, parse & plot raw tobii files.
	properties
		%> file name
		fileName char								= ''
		%> which EDF message contains the trial start tag
		trialStartMessageName char					= 'TRIALID'
		%> which EDF message contains the variable name or value
		variableMessageName char					= 'TRIALID'
		%> the EDF message name to start measuring stimulus presentation
		rtStartMessage char							= 'END_FIX'
		%> EDF message name to end the stimulus presentation
		rtEndMessage char							= 'END_RT'
		%> EDF message name to signal end of the trial, also parses a passed number, so
		%> e.g. "TRIAL_RESULT -1" sets the trial.result to -1, these are used to label trials
		%> as correct, incorrect, breakfix etc.
		trialEndMessage char						= 'TRIAL_RESULT'
		%> override the rtStart time with a custom message?
		rtOverrideMessage char						= 'SYNCTIME'
		%> minimum saccade distance in degrees
		minSaccadeDistance double					= 0.99
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
		ETparams									= [ ]
		%> Is measure range relative to start and end markers or absolute
		%> to start marker?
		relativeMarkers								= false
		%> subtract the baseline for the pupil plot and average?
		baselinePupil								= true
		%> smooth the pupil signal for plot and average?
		smoothPupil									= true
	end

	properties (Hidden = true)
		%TRIAL_RESULT message values, optional but tags trials with these identifiers.
		correctValue double							= 1
		incorrectValue double						= 0
		breakFixValue double						= -1
		%occasionally we have some trials in the EDF not in the plx, this prunes them out
		trialsToPrune double						= []
		%> these are used for spikes spike saccade time correlations
		rtLimits double
		rtDivision double
		%> screen X center in pixels
		xCenter double								= 640
		%> screen Y center in pixels
		yCenter double								= 512
		%> downsample the data for plotting
		downSample logical							= true
		excludeTrials								= []
	end

	properties (SetAccess = private, GetAccess = public)
		%> have we parsed the MAT yet?
		isParsed logical							= false
		%> sample rate
		sampleRate double							= 250
		%> raw data
		raw struct
		exp 
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
		%> the display dimensions parsed from the EDF
		display double
		%> other display info parsed from the EDF
		otherinfo struct							= struct()
		%> for some early EDF files, there is no trial variable ID so we
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
		varLabels
		%> pixels per degree calculated from pixelsPerCm and distance (cache)
		ppd_
		%> allowed properties passed to object upon construction
		allowedProperties = {'correctValue', 'incorrectValue', 'breakFixValue', ...
			'trialStartMessageName', 'variableMessageName', 'trialEndMessage', 'file', 'dir', ...
			'verbose', 'pixelsPerCm', 'distance', 'xCenter', 'yCenter', 'rtStartMessage', 'minSaccadeDistance', ...
			'rtEndMessage', 'trialOverride', 'rtDivision', 'rtLimits', 'tS', 'ROI', 'TOI', 'VFAC', 'MINDUR',...
			'baselineWindow','measureRange','plotRange'}
		trialsTemplate = {'variable','variableMessageName','idx','correctedIndex','time',...
			'times','gx','gy','hx','hy','pa','valid',...
			'rt','rtoverride','fixations','nfix','saccades','nsacc','saccadeTimes',...
			'firstSaccade','uuid','result','invalid','correct','breakFix','incorrect','unknown',...
			'messages','sttime','entime','totaltime','startsampletime','endsampletime',...
			'timeRange','rtstarttime','rtstarttimeOLD','rtendtime','synctime','deltaT',...
			'rttime','msacc','sampleSaccades',...
			'microSaccades','radius','forcedend'}
	end

	methods
		% ===================================================================
		%> @brief
		%>
		% ===================================================================
		function me = tobiiAnalysis(varargin)
			args = optickaCore.addDefaults(varargin,struct('name','tobiiAnal',...
				'measureRange',[-0.4 1],'plotRange',[-0.5 1],...
				'baselineWindow',[]));
			me=me@analysisCore(args); %superclass constructor
			me.parseArgs(args, me.allowedProperties);
	
			if isempty(me.fileName)
				[f,d] = uigetfile('*.mat','Select Opticka Data MAT File:');
				if ~isnumeric(f); me.fileName = [d filesep f]; end
			end
		end

		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function load(me,force)
			if ~exist('force','var');force=false;end
			if isempty(me.fileName)
				[f,d] = uigetfile('*.mat','Select Opticka Data MAT File:');
				if ~isnumeric(f)
					me.fileName = [d filesep f];
				else
					warning('No Data file specified...');
					return
				end
			end
			tt=tic;
			if isempty(me.raw) || force == true
				oldpath = pwd;
				[p, f, e] = fileparts(me.fileName);
				cd(p)
				exp = load(me.fileName);
				if isstruct(exp) && isfield(exp,'rE') && isa(exp.rE,'runExperiment')% runExperiment data
					fprintf('<strong>...</strong> runExperiment (Opticka file) found\n');
					me.distance = exp.rE.screen.distance;
					me.pixelsPerCm = exp.rE.screen.pixelsPerCm;
					me.sampleRate = exp.rE.eyeTracker.sampleRate;
					if isa(exp.rE.eyeTracker,'tobiiManager')
						me.raw = exp.rE.eyeTracker.data;
						me.exp = exp;
					else
						warning('This is not a Tobii eyetracker file, choose another file!!!');
						me.raw = [];
						me.exp = [];
						return;
					end
				else
					warning('This is not an Opticka file, choose another file!!!');
					me.raw = [];
					me.exp = [];
					return;
				end
				cd(oldpath)
			end
			if ~isempty(me.exp) && isfield(me.exp,'tS') && isfield(me.exp,'rE')
				try 
					me.name = [me.exp.tS.name '-' me.exp.rE.name]; 
					me.comment = me.exp.rE.comment;
					fprintf('===>>> Experiment Details: name: %s | comment %s\n',...
						me.name,me.comment);
				end
				fprintf('===>>> Eytracker Data %s containing %i messages and %i samples\n',...
					me.exp.rE.eyeTracker.fullName,...
					size(me.raw.messages,1),...
					length(me.raw.data.gaze.deviceTimeStamp));
				if ~isempty(me.exp.rE.task.varLabels)
					me.varLabels = me.exp.rE.task.varLabels;
					fprintf('===>>> Variables contained in the task:\n');
					disp(me.varLabels);
				end
			end
			fprintf('<strong>:#:</strong> Loading Raw MAT Data took <strong>%g ms</strong>\n',round(toc(tt)*1e3));
		end

		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function parseSimple(me)
			if isempty(me.raw); me.load(); end
			me.isParsed = false;
			tmain = tic;
			parseEvents(me);
			parseAsVars(me);
			me.isParsed = true;
			fprintf('\tOverall Simple Parsing of EDF Trials took <strong>%g ms</strong>\n',round(toc(tmain)*1000));
		end

		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function parse(me)
			if isempty(me.raw); me.load(); end
			me.isParsed = false;
			tmain = tic;
			parseEvents(me);
			if ~isempty(me.trialsToPrune)
				me.pruneTrials(me.trialsToPrune);
			end
			parseAsVars(me);
			parseSecondaryEyePos(me);
			parseFixationPositions(me);
			parseSaccades(me);

			me.isParsed = true;
			fprintf('\tOverall Parsing of EDF Trials took <strong>%g ms</strong>\n',round(toc(tmain)*1000));
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
			me.correct.isCustomIdx = true;

			for i = me.correct.idx
				me.trials(i).correct = true;
				me.trials(i).incorrect = false;
			end
		end

		% ===================================================================
		%> @brief prunetrials -- very rarely (n=1) we lose a trial strobe in the plexon data and
		%> thus when we try to align the plexon trial index and EDF trial index they are off-by-one,
		%> this function is used once the index of the trial is know to prune it out of the EDF data
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
			me.breakFix.idx = find([me.trials.breakFix] == true);
			me.breakFix.saccTimes = [me.trials(me.breakFix.idx).firstSaccade];
			me.incorrect.idx = find([me.trials.incorrect] == true);
			me.incorrect.saccTimes = [me.trials(me.incorrect.idx).firstSaccade];
			for i = num:length(me.trials)
				me.trials(i).correctedIndex = me.trials(i).correctedIndex - 1;
			end
			fprintf('Pruned %i trials from EDF trial data \n',num)
		end

		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function data = saveChap(me)
			if ~me.isParsed; warning('You need to parse data first...');return;end
			t = double(me.raw.data.gaze.systemTimeStamp) / 1e3;
			data.timestamps = t';
			data.pupil_size = ((me.raw.data.gaze.left.pupil.diameter+me.raw.data.gaze.right.pupil.diameter)/2)';
			data.pupil_x = me.raw.data.gaze.left.gazePoint.onDisplayArea(1,:)';
			data.pupil_y = me.raw.data.gaze.left.gazePoint.onDisplayArea(2,:)';
			data.rate = me.sampleRate;
			data.name = me.fileName;
			data.file_name = data.name;
			tdata = {};
			vdata = {};
			for i = 1:length(me.trials)
				tdata{i,1} = me.trials(i).idx;
				tdata{i,2} = analysisCore.findNearest(t, me.trials(i).sttime);
				tdata{i,3} = analysisCore.findNearest(t, me.trials(i).entime);
				tdata{i,4} = tdata{i,3} - tdata{i,2};
				
				vdata{i,1} = ['VAR' num2str(me.trials(i).variable)];
				vdata{i,2} = ['' me.trials(i).variableMessageName];
				if me.trials(i).correct; ctxt = 'correct'; elseif me.trials(i).breakFix; ctxt='breakfix';else; ctxt='incorrect';end
				vdata{i,3} = ['' ctxt];
				vdata{i,4} = analysisCore.findNearest(t, me.trials(i).rtstarttime) - tdata{i,2};
				vdata{i,5} = tdata{i,4};
			end
			data.trial_data = cell2table(tdata,'VariableNames',{'trial_names','Trial_Onset_num','Trial_Offset_num','trial_length'});
			data.total_var_data_table = cell2table(vdata,'VariableNames',{'VAR','NAME','CORRECT','event_stimulus_onset','event_Trial_Offset'});
			data.event_data = [];
			data.events2 = [];
			data.vars2 = [];
		end

		% ===================================================================
		%> @brief give a list of trials and it will plot both the raw eye position and the
		%> events
		%>
		%> @param
		%> @return
		% ===================================================================
		function plot(me,select,type,seperateVars,name,handle)
			% plot(me,select,type,seperateVars,name)
			if ~me.isParsed; warning('You need to parse data first...');return;end
			if ~exist('select','var') || ~isnumeric(select); select = []; end
			if ~exist('type','var') || isempty(type); type = 'all'; end
			if ~exist('seperateVars','var') || ~islogical(seperateVars); seperateVars = false; end
			if ~exist('name','var') || isempty(name)
				if isnumeric(select)
					if length(select) > 1
						name = [me.fileName ' | Select: ' num2str(length(select)) ' trials'];
					elseif isempty(select)
						name = [me.fileName ' | Select: default'];
					else
						name = [me.fileName ' | Select: ' num2str(select)];
						ii = find(cellfun(@(x)ismember(select,x),{me.vars.idx}),1);
						if ~isempty(ii) && ii > 0
							name = [name '-' me.vars(ii).name];
						end
					end
				end
			end
			if seperateVars == true
				for j = 1:length(me.vars)
					me.plot(me.vars(j).idx,type,false,me.vars(j).name);
					drawnow;
				end
				return
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
			if isempty(idx)
				fprintf('No trials were selected to plot, adding all...\n');
				idx = 1:length(me.trials);
			end

			vars = sort(unique([me.trials.variable]));

			if isempty(handle)
				h1=figure('Name',name,'Color',[1 1 1],'NumberTitle','off',...
					'Papertype','a4','PaperUnits','centimeters',...
					'PaperOrientation','landscape','Renderer','painters');
				figpos(1,[0.6 0.9],1,'%');
			else
				figure(handle)
				h1=handle;
			end
			p = panel(h1);
			p.fontsize = 12;
			p.margin = [10 10 10 20]; %left bottom right top
			p.pack('v',{2/3, []});
			q = p(1);
			q.margin = [20 20 10 25]; %left bottom right top
			q.pack(2,2);
			qq = p(2);
			qq.margin = [20 20 10 25]; %left bottom right top
			qq.pack(1,2);
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

			map = me.optimalColours(length(vars));

			if isempty(select)
				thisVarName = 'ALL';
			elseif length(select) > 1
				thisVarName = 'SELECTION';
			else
				thisVarName = ['VAR' num2str(select)];
				ii = find(cellfun(@(x)ismember(select,x),{me.vars.idx}),1);
				thisVarName = [thisVarName '-' me.vars(ii).name];
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
				
				if isfield(thisTrial, 'invalid') && thisTrial.invalid 
					continue; 
				end

				tidx = find(vars==thisTrial.variable);

				if thisTrial.variable == 1010 || isempty(me.vars) %early CSV files were broken, 1010 signifies this
					c = rand(1,3);
				else
					c = map(tidx,:);
				end

				if isempty(select) || length(select) > 1 || ~isempty(intersect(select,idx))

				else
					continue
				end

				t = thisTrial.times / 1e3; %convert to seconds
				ix = (t >= me.measureRange(1)) & (t <= me.measureRange(2));
				ip = (t >= me.plotRange(1)) & (t <= me.plotRange(2));
				ib = [];
				if length(me.baselineWindow)==2
					ib = (t >= me.baselineWindow(1)) & (t <= me.baselineWindow(2));
				end
				tm = t(ix);
				tp = t(ip);
				xa = thisTrial.gx;
				ya = thisTrial.gy;
				pupilAll = thisTrial.pa;
				lim = 50; %max degrees in data
				xa(xa < -lim) = -lim; xa(xa > lim) = lim; 
				ya(ya < -lim) = -lim; ya(ya > lim) = lim;
				
				x = xa(ix);
				y = ya(ix);
				pupilMeasure = pupilAll(ix);
				
				xp = xa(ip);
				yp = ya(ip);
				pupilPlot = pupilAll(ip);
				if ~isempty(ib) && me.baselinePupil
					pb = nanmean(pupilAll(ib));
					if isnumeric(pb) 
						pupilPlot = pupilPlot - pb;
					end
				end

				if me.smoothPupil
					pupilPlot = smooth(pupilPlot);
				end

				q(1,1).select();
				q(1,1).hold('on')
				plot(xp, yp,'k-','Color',c,'LineWidth',1,'UserData',[thisTrial.idx thisTrial.correctedIndex thisTrial.variable],'ButtonDownFcn', @clickMe);
				if isfield(thisTrial,'microSaccades') & ~isnan(thisTrial.microSaccades) & ~isempty(thisTrial.microSaccades)
					for jj = 1: length(thisTrial.microSaccades)
						if thisTrial.microSaccades(jj) >= me.plotRange(1) && thisTrial.microSaccades(jj) <= me.plotRange(2)
							midx = me.findNearest(tp,thisTrial.microSaccades(jj));
							plot(xp(midx),yp(midx),'ko','Color',c,'MarkerSize',6,'MarkerEdgeColor',[0 0 0],...
								'MarkerFaceColor',c,'UserData',[thisTrial.idx thisTrial.correctedIndex thisTrial.variable thisTrial.microSaccades(jj)],'ButtonDownFcn', @clickMe);
						end
					end
				end
				
				q(1,2).select();
				q(1,2).hold('on');
				plot(tp,abs(xp),'k-','Color',c,'MarkerSize',3,'MarkerEdgeColor',c,...
					'MarkerFaceColor',c,'UserData',[thisTrial.idx thisTrial.correctedIndex thisTrial.variable],'ButtonDownFcn', @clickMe);
				plot(tp,abs(yp),'k.-','Color',c,'MarkerSize',3,'MarkerEdgeColor',c,...
					'MarkerFaceColor',c,'UserData',[thisTrial.idx thisTrial.correctedIndex thisTrial.variable],'ButtonDownFcn', @clickMe);
				maxv = max([maxv, max(abs(xp)), max(abs(yp))]) + 0.1;
				if isfield(thisTrial,'microSaccades') & ~isnan(thisTrial.microSaccades) & ~isempty(thisTrial.microSaccades)
					if any(thisTrial.microSaccades >= me.plotRange(1) & thisTrial.microSaccades <= me.plotRange(2))
						plot(thisTrial.microSaccades,-0.1,'ko','Color',c,'MarkerSize',4,'MarkerEdgeColor',[0 0 0],...
							'MarkerFaceColor',c,'UserData',[thisTrial.idx thisTrial.correctedIndex thisTrial.variable],'ButtonDownFcn', @clickMe);
					end
				end
				
				qq(1,2).select();
				qq(1,2).hold('on')
				plot(tp,pupilPlot,'Color',c, 'UserData',[thisTrial.idx thisTrial.correctedIndex thisTrial.variable],'ButtonDownFcn', @clickMe);
				
				idxt = find(t >= t1 & t <= t2);

				tvals{a} = t(idxt);
				xvals{a} = xa(idxt);
				yvals{a} = ya(idxt);
				if isfield(thisTrial,'firstSaccade') && thisTrial.firstSaccade > 0
					sacc = [sacc thisTrial.firstSaccade/1e3];
				end
				meanx = [meanx mean(xa(idxt))];
				meany = [meany mean(ya(idxt))];
				medx = [medx median(xa(idxt))];
				medy = [medy median(ya(idxt))];
				stdex = [stdex std(xa(idxt))];
				stdey = [stdey std(ya(idxt))];

				udt = [thisTrial.idx thisTrial.correctedIndex thisTrial.variable];
				q(2,1).select();
				q(2,1).hold('on');
				plot(meanx(end), meany(end),'ko','Color',c,'MarkerSize',6,'MarkerEdgeColor',[0 0 0],...
					'MarkerFaceColor',c,'UserData', udt,'ButtonDownFcn', @clickMe);

				q(2,2).select();
				q(2,2).hold('on');
				plot3(meanx(end), meany(end),a,'ko','Color',c,'MarkerSize',6,'MarkerEdgeColor',[0 0 0],...
					'MarkerFaceColor',c,'UserData', udt,'ButtonDownFcn', @clickMe);
				a = a + 1;

			end

			q(1,1).select();
			ah = gca; ah.ButtonDownFcn = @spawnMe;
			ah.DataAspectRatio = [1 1 1];
			axis ij; axis equal;
			grid on;
			box on;
			%axis(round([-display(1)/2 display(1)/2 -display(2)/2 display(2)/2]));
			title(q(1,1),[thisVarName upper(type) ': X vs. Y Eye Position']);
			xlabel(q(1,1),'X Deg');
			ylabel(q(1,1),'Y Deg');

			q(1,2).select();
			ah = gca; ah.ButtonDownFcn = @spawnMe;
			grid on;
			box on;
			axis tight;
			axis([me.plotRange(1) me.plotRange(2) -0.2 maxv])
			ti=sprintf('ABS Mean/SD %g - %g s: X=%.2g / %.2g | Y=%.2g / %.2g', t1,t2,...
				mean(abs(meanx)), mean(abs(stdex)), ...
				mean(abs(meany)), mean(abs(stdey)));
			ti2 = sprintf('ABS Median/SD %g - %g s: X=%.2g / %.2g | Y=%.2g / %.2g', t1,t2,median(abs(medx)), median(abs(stdex)), ...
				median(abs(medy)), median(abs(stdey)));
			h=title(sprintf('X & Y(dot) Position vs. Time\n%s\n%s', ti,ti2));
			set(h,'BackgroundColor',[1 1 1]);
			xlabel(q(1,2),'Time (s)');
			ylabel(q(1,2),'Degrees');

			
			qq(1,2).select();
			ah = gca; ah.ButtonDownFcn = @spawnMe;
			axis([me.plotRange(1) me.plotRange(2) -inf inf]);
			grid on;
			box on;
			title(qq(1,2),[thisVarName upper(type) ': Pupil Diameter']);
			xlabel(qq(1,2),'Time (s)');
			ylabel(qq(1,2),'Diameter');

			q(2,1).select();
			ah = gca; ah.ButtonDownFcn = @spawnMe;
			axis ij;
			grid on;
			box on;
			axis tight;
			axis([-1 1 -1 1])
			h=title(sprintf('X & Y %g-%gs MD/MN/STD: \nX : %.2g / %.2g / %.2g | Y : %.2g / %.2g / %.2g', ...
				t1,t2,mean(meanx), median(medx),mean(stdex),mean(meany),median(medy),mean(stdey)));
			set(h,'BackgroundColor',[1 1 1]);
			xlabel(q(2,1),'X Degrees');
			ylabel(q(2,1),'Y Degrees');

			q(2,2).select();
			ah = gca; ah.ButtonDownFcn = @spawnMe;
			grid on;
			box on;
			axis tight;
			axis([-1 1 -1 1]);
			%axis square
			view(47,15);
			title(sprintf('%s %s Mean X & Y Pos %g-%g-s over time',thisVarName,upper(type),t1,t2));
			xlabel(q(2,2),'X Degrees');
			ylabel(q(2,2),'Y Degrees');
			zlabel(q(2,2),'Trial');

			assignin('base','xvals',xvals);
			assignin('base','yvals',yvals);

			function clickMe(src, ~)
				if ~exist('src','var')
					return
				end
				l=get(src,'LineWidth');
				if l > 1
					set(src,'Linewidth', 1, 'LineStyle', '-');
				else
					set(src,'LineWidth',2, 'LineStyle', ':');
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
				times = me.trials(i).times / 1e3;
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
			fprintf('<strong>:#:</strong> Parsing eyelink region of interest (ROI) took <strong>%g ms</strong>\n', round(toc(tROI)*1000))
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
			t1 = me.TOI(1);
			t2 = me.TOI(2);
			fixationX = me.TOI(3);
			fixationY = me.TOI(4);
			fixationRadius = me.TOI(5);
			for i = 1:length(me.trials)
				times = me.trials(i).times / 1e3;
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
			fprintf('<strong>:#:</strong> Parsing eyelink time of interest (TOI) took <strong>%g ms</strong>\n', round(toc(tTOI)*1000))
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
						set(h,'UserData',[noROI(i).idx noROI(i).correctedIndex noROI(i).variable noROI(i).correct noROI(i).breakFix noROI(i).incorrect],'ButtonDownFcn', @clickMe);
						p(1,2).select();
						h = plot(t,abs(x),l,t,abs(y),l,'color',c,'MarkerFaceColor',c);
						set(h,'UserData',[noROI(i).idx noROI(i).correctedIndex noROI(i).variable noROI(i).correct noROI(i).breakFix noROI(i).incorrect],'ButtonDownFcn', @clickMe);
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
						set(h,'UserData',[yesROI(i).idx yesROI(i).correctedIndex yesROI(i).variable yesROI(i).correct yesROI(i).breakFix yesROI(i).incorrect],'ButtonDownFcn', @clickMe);
						p(1,2).select();
						h = plot(t,abs(x),l,t,abs(y),l,'color',c,'MarkerFaceColor',c);
						set(h,'UserData',[yesROI(i).idx yesROI(i).correctedIndex yesROI(i).variable yesROI(i).correct yesROI(i).breakFix yesROI(i).incorrect],'ButtonDownFcn', @clickMe);
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
				axis([-10 10 -10 10]);
				p(1,2).select();
				p(1,2).hold('off');
				box on
				grid on
				p(1,2).title(['ROI PLOT for ' num2str(me.ROI) ' (entered = ' num2str(sum(yes)) ' | did not = ' num2str(sum(no)) ')']);
				p(1,2).xlabel('Time(s)')
				p(1,2).ylabel('Absolute X/Y Position (degs)')
				axis square
				axis([0 0.5 0 10]);
			end
			function clickMe(src, ~)
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
					set(h,'UserData',[noTOI(i).idx noTOI(i).correctedIndex noTOI(i).variable noTOI(i).correct noTOI(i).breakFix noTOI(i).incorrect],'ButtonDownFcn', @clickMe);
					p(1,2).select();
					h = plot(t,abs(x),l,t,abs(y),l,'color',c,'MarkerFaceColor',c);
					set(h,'UserData',[noTOI(i).idx noTOI(i).correctedIndex noTOI(i).variable noTOI(i).correct noTOI(i).breakFix noTOI(i).incorrect],'ButtonDownFcn', @clickMe);
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
					set(h,'UserData',[yesTOI(i).idx yesTOI(i).correctedIndex yesTOI(i).variable yesTOI(i).correct yesTOI(i).breakFix yesTOI(i).incorrect],'ButtonDownFcn', @clickMe);
					p(1,2).select();
					h = plot(t,abs(x),l,t,abs(y),l,'color',c,'MarkerFaceColor',c);
					set(h,'UserData',[yesTOI(i).idx yesTOI(i).correctedIndex yesTOI(i).variable yesTOI(i).correct yesTOI(i).breakFix yesTOI(i).incorrect],'ButtonDownFcn', @clickMe);
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
			axis([-4 4 -4 4]);
			axis square
			p(1,2).select();
			p(1,2).hold('off');
			box on
			grid on
			p(1,2).title(['TOI PLOT for ' num2str(me.TOI) ' (yes = ' num2str(sum(yes)) ' || no = ' num2str(sum(no)) ')']);
			p(1,2).xlabel('Time(s)')
			p(1,2).ylabel('Absolute X/Y Position (degs)')
			axis([t1 t2 0 4]);
			axis square

			function clickMe(src, ~)
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
			ppd = round( me.pixelsPerCm * (me.distance / 57.3)); %set the pixels per degree
			me.ppd_ = ppd;
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

		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function [out,in,avg,err] = computePupilAverage(me, trials, sampleRate)
			if ~exist('trials','var') || isempty(trials); trials = me.correct.idx; end
			if ~exist('sampleRate','var'); sampleRate = 100; end
			in = {};
			a = 1;
			if ~isempty(me.excludeTrials)
				trials = setdiff(trials, me.excludeTrials);
				fprintf('===>>> Excluded trials: %s',num2str(me.excludeTrials));
			end
			for ii = trials
				tr = me.trials(ii);
				if isfield(tr,'data')
					t = milliseconds(tr.data.time/1e3);
					p = tr.data.pupil.size;
				else
					t = milliseconds(tr.times);
					p = tr.pa;
				end
				if me.baselinePupil
					tt = seconds(t);
					mp = mean(p(tt >= me.baselineWindow(1) & tt <= me.baselineWindow(2)));
					p = p - mp;
				end
				if me.smoothPupil
					p = smooth(p);
				end
				in{a} = timetable(t,p);
				a = a + 1;
			end

			out = synchronize(in{:},'regular','median','SampleRate',sampleRate);

			handle=figure('Name',me.name,'Color',[1 1 1],'NumberTitle','off',...
						'Papertype','a4','PaperUnits','centimeters',...
						'PaperOrientation','landscape','Renderer','painters');
			figpos(1,[0.5 0.5],1,'%');
			[avg, err] = analysisCore.stderr(out,'SE',false,0.05,2);
			analysisCore.areabar(seconds(out.t), avg, err,[0.8 0.4 0.4]);
			axis tight
			box on; grid on
			xlim(me.plotRange);
			ylabel('Pupil Diameter \pm SE');
			xlabel('Time (s)');
			title(sprintf('%s - %i trials',me.name,width(out)));
		end


	end%-------------------------END PUBLIC METHODS--------------------------------%

	%=======================================================================
	methods (Static = true) %------------------STATIC METHODS
		%=======================================================================
		% ===================================================================
		%> @brief we also collect eye position within the main PTB loop (sampled at every
		%> screen refresh) and this is a lower resolution backup of the eye position data if we
		%> need.
		%>
		%> @param
		%> @return
		% ===================================================================
		function plotSecondaryEyeLogs(tS)

			ifi = 0.013;
			tS = tS.eyePos;
			fn = fieldnames(tS);
			h=figure;
			set(gcf,'Color',[1 1 1]);
			figpos(1,[1200 1200]);
			p = panel(h);
			p.pack(2,2);
			a = 1;
			stdex = [];
			stdey = [];
			early = [];
			maxv = [];
			for i = 1:length(fn)-1
				if ~isempty(regexpi(fn{i},'^E')) && ~isempty(regexpi(fn{i+1},'^CC'))
					x = tS.(fn{i}).x;
					y = tS.(fn{i}).y;
					%if a < Inf%(max(x) < 16 && min(x) > -16) && (max(y) < 16 && min(y) > -16) && mean(abs(x(1:10))) < 1 && mean(abs(y(1:10))) < 1
					c = rand(1,3);
					p(1,1).select();
					p(1,1).hold('on')
					plot(x, y,'k-o','Color',c,'MarkerSize',5,'MarkerEdgeColor',[0 0 0], 'MarkerFaceColor',c);

					p(1,2).select();
					p(1,2).hold('on');
					t = 0:ifi:(ifi*length(x));
					t = t(1:length(x));
					plot(t,abs(x),'k-o','Color',c,'MarkerSize',5,'MarkerEdgeColor',[0 0 0], 'MarkerFaceColor',c);
					plot(t,abs(y),'k-o','Color',c,'MarkerSize',5,'MarkerEdgeColor',[0 0 0], 'MarkerFaceColor',c);
					maxv = max([maxv, max(abs(x)), max(abs(y))]);

					p(2,1).select();
					p(2,1).hold('on');
					plot(mean(x(1:10)), mean(y(1:10)),'ko','Color',c,'MarkerSize',5,'MarkerEdgeColor',[0 0 0], 'MarkerFaceColor',c);
					stdex = [stdex std(x(1:10))];
					stdey = [stdey std(y(1:10))];

					p(2,2).select();
					p(2,2).hold('on');
					plot3(mean(x(1:10)), mean(y(1:10)),a,'ko','Color',c,'MarkerSize',5,'MarkerEdgeColor',[0 0 0], 'MarkerFaceColor',c);

					if mean(x(14:16)) > 5 || mean(y(14:16)) > 5
						early(a) = 1;
					else
						early(a) = 0;
					end

					a = a + 1;

					%end
				end
			end

			p(1,1).select();
			grid on
			box on
			axis square; axis ij
			xlim([-10 10]); ylim([-10 10]);
			title('X vs. Y Eye Position in Degrees')
			xlabel('X Degrees')
			ylabel('Y Degrees')

			p(1,2).select();
			grid on
			box on
			if maxv > 10; maxv = 10; end
			axis([-0.01 0.4 0 maxv+0.1])
			title(sprintf('X and Y Position vs. time | Early = %g / %g', sum(early),length(early)))
			xlabel('Time (s)')
			ylabel('Degrees')

			p(2,1).select();
			grid on
			box on
			axis square; axis ij
			title(sprintf('Average X vs. Y Position for first 150ms STDX: %g | STDY: %g',mean(stdex),mean(stdey)))
			xlabel('X Degrees')
			ylabel('Y Degrees')

			p(2,2).select();
			grid on
			box on
			axis square; axis ij
			title('Average X vs. Y Position for first 150ms Over Time')
			xlabel('X Degrees')
			ylabel('Y Degrees')
			zlabel('Trial')
		end

	end

	%=======================================================================
	methods (Access = protected) %------------------PRIVATE METHODS
		%=======================================================================

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
		%> @brief main parse loop for EDF events, has to be one big serial loop
		%>
		%> @param
		%> @return
		% ===================================================================
		function parseEvents(me)
			tmain = tic;
			isTrial = false;
			tri = 1; %current trial that is being parsed
			me.trials = struct();
			me.correct.idx = [];
			me.correct.saccTimes = [];
			me.correct.fixations = [];
			me.breakFix = me.correct;
			me.incorrect = me.correct;
			me.unknown = me.correct;
			me.trialList = [];
			this.FrameRate = [];
			this.ppd = [];
			this.distance = [];
			this.pixelspercm = [];
			this.display = [];
			me.ppd; %faster to cache this now (dependant property sets ppd_ too)

			trialDef = getTrialDef(me);

			t1 = inf;
			t2 = -inf;

			xmod = me.exp.rE.screenVals.rightInDegrees;
			ymod = me.exp.rE.screenVals.bottomInDegrees;
			times = double(me.raw.data.gaze.systemTimeStamp) /1e3;
			nMessages = size(me.raw.messages,1);
			pb = textprogressbar(nMessages, 'startmsg', 'Parsing Tobii Experiment Events: ',...
				'showactualnum', true,'updatestep', round(nMessages/(nMessages/20)));
			for i = 1:nMessages

				evtT = double(me.raw.messages{i,1}) / 1e3;
				evt = me.raw.messages{i,2};
				
				if startsWith(evt,["WARMUP", "POINT ", "Calibration", "CALIBRATION", "START ", "STOP "])
					pb(i);
					continue;
				end

				if ~isTrial 

					% NEW TRIAL 
					if startsWith(evt, me.trialStartMessageName)
						id = regexpi(evt,['^(?<TAG>' me.trialStartMessageName ')(\s*)(?<ID>\d*)'],'names');
						if isempty(id.ID) 
							id.ID = '101010';
						end
						thisTrial = trialDef;
						thisTrial.variable = str2double(id.ID);
						if thisTrial.variable > 0 && thisTrial.variable <= length(me.varLabels)
							thisTrial.variableMessageName = me.varLabels{thisTrial.variable};
						end
						thisTrial.idx = tri;
						thisTrial.time = evtT;
						thisTrial.sttime = evtT;
						if tri > 1
							thisTrial.totaltime = thisTrial.sttime - me.trials(1).sttime;
						end
						thisTrial.rtstarttime = thisTrial.sttime;
						isTrial = true;
						continue
					end


				elseif isTrial

					% assume we are missing an end trial message, force one
					if startsWith(evt,"V_RT")
						evt = [me.trialEndMessage ' ' num2str(-101010)];
						thisTrial.forcedend = true;
					end

					% Reaction time start markers (normally start of stim
					% onset
					if startsWith(evt, me.rtStartMessage) || startsWith(evt, me.rtOverrideMessage)
						thisTrial.synctime = true;
						thisTrial.rtstarttime = evtT;
						continue
					end

					% Messages
					if startsWith(evt,"MSG:")
						msg = regexpi(evt,'^MSG:\s?(?<MSG>[\w]+)[ =]*(?<VAL>.*)','names');
						if ~isempty(msg) && ~isempty(msg.MSG)
							if isfield(thisTrial.messages,msg.MSG)
								thisTrial.messages.(msg.MSG){end+1} = msg.VAL;
								thisTrial.messages.([msg.MSG 'TIME']){end+1} = double(evt.sttime);
							else
								thisTrial.messages.(msg.MSG){1} = msg.VAL;
								thisTrial.messages.([msg.MSG 'TIME']){1} = double(evt.sttime);
							end
							if strcmpi(msg.MSG, me.rtOverrideMessage)
								thisTrial.rtstarttimeOLD = thisTrial.rtstarttime;
								thisTrial.rtstarttime = double(evt.sttime);
								thisTrial.rt = true;
								thisTrial.rtoverride = true;
							end
							continue
						end
					end

					% !V Messages
					if startsWith(evt,"!V")
						msg = regexpi(evt,'^!V (?<v>.+?) (?<n>.+?) (?<val>.+?)$','names');
						if ~isempty(msg) && isempty(msg.v) && ~isempty(msg.n) 
							tag = [msg.v '-' msg.n];
							if isfield(thisTrial.messages,tag)
								thisTrial.messages.(tag){end+1} = msg.val;
								thisTrial.messages.([tag 'TIME']){end+1} = double(evt.sttime);
							else
								thisTrial.messages.(tag){1} = msg.val;
								thisTrial.messages.([tag 'TIME']){1} = double(evt.sttime);
							end
							continue
						end
					end

					% UUID from state machine
					if startsWith(evt,"UUID")
						uuid = regexpi(evt,'^(MSG:)?UUID (?<UUID>[\w]+)','names');
						if ~isempty(uuid) && ~isempty(uuid.UUID)
							thisTrial.uuid = uuid.UUID;
						end
						continue
					end

					% trial END
					if startsWith(evt, me.trialEndMessage) || startsWith(evt, 'TRIALEND')
						if startsWith(evt, 'TRIALEND')
							id.ID = -101010;
						else
							id = regexpi(evt,['^' me.trialEndMessage ' (?<ID>(\-|\+|\d)+)'],'names');
						end
						if isempty(id.ID); id.ID = -101010; end
						thisTrial.entime = evtT;
						thisTrial.result = str2num(id.ID);
						if thisTrial.result == me.correctValue
							thisTrial.correct = true;
						elseif thisTrial.result == me.incorrectValue
							thisTrial.incorrect = true;
						elseif thisTrial.result == me.breakFixValue
							thisTrial.breakFix = true;
						end
						sT=[];
						thisTrial.deltaT = thisTrial.entime - thisTrial.sttime;
						if isempty(thisTrial.times)
							if isnan(thisTrial.startsampletime)
								thisTrial.startsampletime = thisTrial.sttime;
							end
							thisTrial.endsampletime = thisTrial.entime;
							idx = times >= thisTrial.startsampletime & ...
								times <= thisTrial.endsampletime;
							if ~isempty(idx)
								thisTrial.times = times(idx);
								thisTrial.times = thisTrial.times - thisTrial.rtstarttime;
								thisTrial.timeRange = [thisTrial.times(1) thisTrial.times(end)];
								thisTrial.gx = me.raw.data.gaze.left.gazePoint.onDisplayArea(1,idx);
								thisTrial.gx = (thisTrial.gx * (xmod*2)) - xmod;
								thisTrial.gy = me.raw.data.gaze.left.gazePoint.onDisplayArea(2,idx);
								thisTrial.gy = (thisTrial.gy * (ymod*2)) - ymod;
								thisTrial.hx = me.raw.data.gaze.left.gazePoint.inUserCoords(1,idx);
								thisTrial.hy = me.raw.data.gaze.left.gazePoint.inUserCoords(2,idx);
								thisTrial.pa = me.raw.data.gaze.left.pupil.diameter(idx);
								thisTrial.valid = me.raw.data.gaze.left.pupil.valid(idx);
								if thisTrial.times(1) < t1; t1 = thisTrial.times(1); end
								if thisTrial.times(end) > t2; t2 = thisTrial.times(end); end
							else
								thisTrial.result = -101010;
							end
							
						end
						if tri == 1
							me.trials = thisTrial;
						else
							me.trials(tri) = thisTrial;
						end
						isTrial = false; 
						clear thisTrial;
						tri = tri + 1;
						continue
					end
				end % END isTrial
				pb(i);
			end % END FOR
			pb(i);

			me.plotRange = [t1/1e3 t2/1e3];

			me.otherinfo = this;
			
			if isempty(me.trials)
				warning('---> eyelinkAnalysis.parseEvents: No trials could be parsed in this data!')
				return
			end

			%prune the end trial if invalid
			me.correct.idx = find([me.trials.correct] == true);
			me.breakFix.idx = find([me.trials.breakFix] == true);
			me.incorrect.idx = find([me.trials.incorrect] == true);
			
			fprintf('<strong>:#:</strong> Parsing Tobii Events into %i Trials took <strong>%.2f secs</strong> | min-t = %.2f max-t = %.2f\n',length(me.trials),toc(tmain), t1/1e3, t2/1e3);
		
		end

		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function parseAsVars(me)
			if isempty(me.exp)
				uniqueVars = sort(unique([me.trials.variable]));
				labels = [];
				warning('---> Vars are being parsed from trials directly...')
			else
				uniqueVars = [me.exp.rE.task.varList{:,1}];
				labels = me.exp.rE.task.varLabels;

			end
			nVars = length(uniqueVars);
			if isempty(me.trials)
				warning('---> eyelinkAnalysis.parseAsVars: No trials and therefore cannot extract variables!')
				return
			end
			me.vars = struct();
			me.vars(nVars).name = '';
			me.vars(nVars).var = [];
			me.vars(nVars).varidx = [];
			me.vars(nVars).variable = [];
			me.vars(nVars).idx = [];
			me.vars(nVars).correct = [];
			me.vars(nVars).idxcorrect = [];
			me.vars(nVars).result = [];
			me.vars(nVars).correctedidx = [];
			me.vars(nVars).trial = [];
			me.vars(nVars).sTime = [];
			me.vars(nVars).sT = [];
			me.vars(nVars).uuid = {};

			for i=uniqueVars
				if i <= length(labels); me.vars(i).name = labels{i}; end
				me.vars(i).var = uniqueVars(i);
			end

			for i = 1:length(me.trials)
				trial = me.trials(i);
				var = trial.variable;
				if trial.invalid == true
					continue
				end
				idx = find(uniqueVars==var);
				if ~isempty(labels) && idx <= length(labels)
					me.vars(idx).name = labels{idx};
				else
					me.vars(idx).name = num2str(var);
				end
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
				%me.vars(idx).trial = [me.vars(idx).trial; trial];
				me.vars(idx).uuid{end+1} = trial.uuid;
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
			if me.isParsed && isstruct(me.tS)
				f=fieldnames(me.tS.eyePos); %get fieldnames
				re = regexp(f,'^CC','once'); %regexp over the cell
				idx = cellfun(@(c)~isempty(c),re); %check which regexp returned true
				f = f(idx); %use this index
				me.validation(1).uuids = f;
				me.validation.lengthCorrect = length(f);
				if length(me.correct.idx) == me.validation.lengthCorrect
					disp('Secondary Eye Position Data appears consistent with EDF parsed trials')
				else
					warning('Secondary Eye Position Data inconsistent with EDF parsed trials')
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
				if any(isnan(me.trials(jj).timeRange)) || me.trials(jj).incorrect == true || me.trials(jj).breakFix == true || me.trials(jj).unknown == true;	continue;	end
				samples = []; sac = []; radius = []; monol=[]; monor=[];
				me.trials(jj).msacc = struct();
				me.trials(jj).sampleSaccades = [];
				me.trials(jj).microSaccades = [];
				samples(:,1) = me.trials(jj).times/1e3;
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
					%getReport(ME)
				end
				pb(jj)
			end
			fprintf('<strong>:#:</strong> Parsing MicroSaccades took <strong>%g ms</strong>\n', round(toc(cms)*1000))

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
				msdx = sqrt( median(vel(:,1).^2) - (median(vel(:,1)))^2 );
				msdy = sqrt( median(vel(:,2).^2) - (median(vel(:,2)))^2 );
				if msdx<realmin
					msdx = sqrt( mean(vel(:,1).^2) - (mean(vel(:,1)))^2 );
					if msdx<realmin
						disp(['TRIAL: ' num2str(jj) ' msdx<realmin in eyelinkAnalysis.microsacc']);
					end
				end
				if msdy<realmin
					msdy = sqrt( mean(vel(:,2).^2) - (mean(vel(:,2)))^2 );
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

