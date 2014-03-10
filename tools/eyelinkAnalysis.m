% ========================================================================
%> @brief eyelinkManager wraps around the eyelink toolbox functions
%> offering a simpler interface
%>
% ========================================================================
classdef eyelinkAnalysis < analysisCore
	
	properties
		%> file name
		file@char = ''
		%> directory
		dir@char = ''
		%> screen resolution
		pixelsPerCm@double = 32
		%> screen distance
		distance@double = 57.3
		%> screen X center in pixels
		xCenter@double = 640
		%> screen Y center in pixels
		yCenter@double = 512
		%> the EDF message name to start measuring stimulus presentation
		rtStartMessage@char = 'END_FIX'
		%> EDF message name to end the stimulus presentation
		rtEndMessage@char = 'END_RT'
		%> trial list from the saved behavioural data, used to fix trial name bug old files
		trialOverride@struct
		%> the temporary experiement structure which contains the eyePos recorded from opticka
		tS@struct
		%> these are used for spikes spike saccade time correlations
		rtLimits@double
		rtDivision@double
		%> region of interest?
		ROI@double = [ ]
		%> time of interest?
		TOI@double = [5 5 2]
		%> verbose output?
		verbose = false
	end
	
	properties (SetAccess = private, GetAccess = public)
		%> have we parsed the EDF yet?
		isParsed@logical = false
		%> raw data
		raw@struct
		%> inidividual trials
		trials@struct
		%> eye data parsed into invdividual variables
		vars@struct
		%> the trial variable identifier, negative values were breakfix/incorrect trials
		trialList@double
		%> correct indices
		correct@struct = struct()
		%> breakfix indices
		breakFix@struct = struct()
		%> incorrect indices
		incorrect@struct = struct()
		%> the display dimensions parsed from the EDF
		display@double
		%> for some early EDF files, there is no trial variable ID so we
		%> recreate it from the other saved data
		needOverride@logical = false;
		%>roi info
		ROIInfo
		%> does the trial variable list match the other saved data?
		validation@struct
	end
	
	properties (Dependent = true, SetAccess = private)
		%> pixels per degree calculated from pixelsPerCm and distance
		ppd
	end
	
	properties (SetAccess = private, GetAccess = private)
		%>57.3 bug override
		override573 = true;
		%> pixels per degree calculated from pixelsPerCm and distance (cache)
		ppd_
		%> allowed properties passed to object upon construction
		allowedProperties@char = 'file|dir|verbose|pixelsPerCm|distance|xCenter|yCenter|rtStartMessage|rtEndMessage|trialOverride|rtDivision|rtLimits|tS|ROI'
	end
	
	methods
		% ===================================================================
		%> @brief
		%>
		% ===================================================================
		function ego = eyelinkAnalysis(varargin)
			if nargin == 0; varargin.name = ''; end
			ego=ego@analysisCore(varargin); %superclass constructor
			if nargin>0; ego.parseArgs(varargin, ego.allowedProperties); end
			if isempty(ego.file) || isempty(ego.dir)
				[ego.file, ego.dir] = uigetfile('*.edf','Load EDF File:');
			end
			ego.ppd; %cache our initial ppd_
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function load(ego)
			tic
			if ~isempty(ego.file)
				oldpath = pwd;
				cd(ego.dir)
				ego.raw = edfmex(ego.file);
				fprintf('\n');
				cd(oldpath)
			end
			fprintf('Loading Raw EDF Data took %g ms\n',round(toc*1000));
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function parse(ego)
			ego.isParsed = false;
			tic
			isTrial = false;
			tri = 1; %current trial that is being parsed
			tri2 = 1; %trial ignoring incorrects
			eventN = 0;
			ego.comment = ego.raw.HEADER;
			ego.trials = struct();
			ego.correct.idx = [];
			ego.correct.saccTimes = [];
			ego.correct.fixations = [];
			ego.breakFix = ego.correct;
			ego.incorrect = ego.correct;
			ego.trialList = [];
			
			ego.ppd; %faster to cache this now (dependant property sets ppd_ too)
			
			sample = ego.raw.FSAMPLE.gx(:,100); %check which eye
			if sample(1) == -32768 %only use right eye if left eye data is not present
				eyeUsed = 2; %right eye index for FSAMPLE.gx;
			else
				eyeUsed = 1; %left eye index
			end
			
			for i = 1:length(ego.raw.FEVENT)
				isMessage = false;
				evt = ego.raw.FEVENT(i);
				
				if evt.type == 24 %strcmpi(evt.codestring,'MESSAGEEVENT')
					isMessage = true;
					no = regexpi(evt.message,'^(?<NO>!cal|!mode|Validate|Reccfg|elclcfg|Gaze_coords|thresholds|elcl_)','names'); %ignore these first
					if ~isempty(no)  && ~isempty(no.NO)
						continue
					end
				end
				
				if isMessage && ~isTrial
					rt = regexpi(evt.message,'^(?<d>V_RT MESSAGE) (?<a>\w+) (?<b>\w+)','names');
					if ~isempty(rt) && ~isempty(rt.a) && ~isempty(rt.b)
						ego.rtStartMessage = rt.a;
						ego.rtEndMessage = rt.b;
						continue
					end
					
					xy = regexpi(evt.message,'^DISPLAY_COORDS \d? \d? (?<x>\d+) (?<y>\d+)','names');
					if ~isempty(xy)  && ~isempty(xy.x)
						ego.display = [str2num(xy.x)+1 str2num(xy.y)+1];
						continue
					end
					
					id = regexpi(evt.message,'^(?<TAG>TRIALID)(\s*)(?<ID>\d*)','names');
					if ~isempty(id) && ~isempty(id.TAG)
						if isempty(id.ID) %we have a bug in early EDF files with an empty TRIALID!!!
							id.ID = '1010';
						end
						isTrial = true;
						eventN=1;
						ego.trials(tri).variable = str2double(id.ID);
						ego.trials(tri).idx = tri;
						ego.trials(tri).correctedIndex = [];
						ego.trials(tri).time = double(evt.time);
						ego.trials(tri).sttime = double(evt.sttime);
						ego.trials(tri).rt = false;
						ego.trials(tri).rtstarttime = double(evt.sttime);
						ego.trials(tri).fixations = [];
						ego.trials(tri).saccades = [];
						ego.trials(tri).saccadeTimes = [];
						ego.trials(tri).rttime = [];
						ego.trials(tri).uuid = [];
						ego.trials(tri).correct = false;
						ego.trials(tri).breakFix = false;
						ego.trials(tri).incorrect = false;
						continue
					end
				end
				
				if isTrial
					
					if ~isMessage
						
						if strcmpi(evt.codestring,'STARTSAMPLES')
							ego.trials(tri).startsampletime = double(evt.sttime);
							continue
						end
						
						if evt.type == 8 %strcmpi(evt.codestring,'ENDFIX')
							fixa = [];
							if isempty(ego.trials(tri).fixations)
								fix = 1;
							else
								fix = length(ego.trials(tri).fixations)+1;
							end
							if ego.trials(tri).rt == true
								rel = ego.trials(tri).rtstarttime;
								fixa.rt = true;
							else
								rel = ego.trials(tri).sttime;
								fixa.rt = false;
							end
							fixa.n = eventN;
							fixa.ppd = ego.ppd_;
							fixa.sttime = double(evt.sttime);
							fixa.entime = double(evt.entime);
							fixa.time = fixa.sttime - rel;
							fixa.length = fixa.entime - fixa.sttime;
							fixa.rel = rel;

							[fixa.gstx, fixa.gsty]  = toDegrees(ego, [evt.gstx, evt.gsty]);
							[fixa.genx, fixa.geny]  = toDegrees(ego, [evt.genx, evt.geny]);
							[fixa.x, fixa.y]		= toDegrees(ego, [evt.gavx, evt.gavy]);
							[fixa.theta, fixa.rho]	= cart2pol(fixa.x, fixa.y);
							fixa.theta = rad2ang(fixa.theta);
							
							if fix == 1
								ego.trials(tri).fixations = fixa;
							else
								ego.trials(tri).fixations(fix) = fixa;
							end
							ego.trials(tri).nfix = fix;
							eventN = eventN + 1;
							continue
						end
						
						if evt.type == 6 % strcmpi(evt.codestring,'ENDSACC')
							sacc = [];
							if isempty(ego.trials(tri).saccades)
								fix = 1;
							else
								fix = length(ego.trials(tri).saccades)+1;
							end
							if ego.trials(tri).rt == true
								rel = ego.trials(tri).rtstarttime;
								sacc.rt = true;
							else
								rel = ego.trials(tri).sttime;
								sacc.rt = false;
							end
							sacc.n = eventN;
							sacc.ppd = ego.ppd_;
							sacc.sttime = double(evt.sttime);
							sacc.entime = double(evt.entime);
							sacc.time = sacc.sttime - rel;
							sacc.length = sacc.entime - sacc.sttime;
							sacc.rel = rel;

							[sacc.gstx, sacc.gsty]	= toDegrees(ego, [evt.gstx evt.gsty]);
							[sacc.genx, sacc.geny]	= toDegrees(ego, [evt.genx evt.geny]);
							[sacc.x, sacc.y]		= deal((sacc.genx - sacc.gstx), (sacc.geny - sacc.gsty));
							[sacc.theta, sacc.rho]	= cart2pol(sacc.x, sacc.y);
							sacc.theta = rad2ang(sacc.theta);
							
							if fix == 1
								ego.trials(tri).saccades = sacc;
							else
								ego.trials(tri).saccades(fix) = sacc;
							end
							ego.trials(tri).nsacc = fix;
							if sacc.rt == true
								ego.trials(tri).saccadeTimes = [ego.trials(tri).saccadeTimes sacc.time];
							end
							eventN = eventN + 1;
							continue
						end
						
						if evt.type == 16 %strcmpi(evt.codestring,'ENDSAMPLES')
							ego.trials(tri).endsampletime = double(evt.sttime);
							
							ego.trials(tri).times = double(ego.raw.FSAMPLE.time( ...
								ego.raw.FSAMPLE.time >= ego.trials(tri).startsampletime & ...
								ego.raw.FSAMPLE.time <= ego.trials(tri).endsampletime));
							ego.trials(tri).times = ego.trials(tri).times - ego.trials(tri).rtstarttime;
							ego.trials(tri).gx = ego.raw.FSAMPLE.gx(eyeUsed, ...
								ego.raw.FSAMPLE.time >= ego.trials(tri).startsampletime & ...
								ego.raw.FSAMPLE.time <= ego.trials(tri).endsampletime);
							ego.trials(tri).gx = ego.trials(tri).gx - ego.display(1)/2;
							ego.trials(tri).gy = ego.raw.FSAMPLE.gy(eyeUsed, ...
								ego.raw.FSAMPLE.time >= ego.trials(tri).startsampletime & ...
								ego.raw.FSAMPLE.time <= ego.trials(tri).endsampletime);
							ego.trials(tri).gy = ego.trials(tri).gy - ego.display(2)/2;
							ego.trials(tri).hx = ego.raw.FSAMPLE.hx(eyeUsed, ...
								ego.raw.FSAMPLE.time >= ego.trials(tri).startsampletime & ...
								ego.raw.FSAMPLE.time <= ego.trials(tri).endsampletime);
							ego.trials(tri).hy = ego.raw.FSAMPLE.hy(eyeUsed, ...
								ego.raw.FSAMPLE.time >= ego.trials(tri).startsampletime & ...
								ego.raw.FSAMPLE.time <= ego.trials(tri).endsampletime);
							ego.trials(tri).pa = ego.raw.FSAMPLE.pa(eyeUsed, ...
								ego.raw.FSAMPLE.time >= ego.trials(tri).startsampletime & ...
								ego.raw.FSAMPLE.time <= ego.trials(tri).endsampletime);
							continue
						end
						
					else
						uuid = regexpi(evt.message,'^UUID (?<UUID>[\w]+)','names');
						if ~isempty(uuid) && ~isempty(uuid.UUID)
							ego.trials(tri).uuid = uuid.UUID;
							continue
						end
						
						endfix = regexpi(evt.message,['^' ego.rtStartMessage],'match');
						if ~isempty(endfix)
							ego.trials(tri).rtstarttime = double(evt.sttime);
							ego.trials(tri).rt = true;
							if ~isempty(ego.trials(tri).fixations)
								for lf = 1 : length(ego.trials(tri).fixations)
									ego.trials(tri).fixations(lf).time = ego.trials(tri).fixations(lf).sttime - ego.trials(tri).rtstarttime;
									ego.trials(tri).fixations(lf).rt = true;
								end
							end
							if ~isempty(ego.trials(tri).saccades)
								for lf = 1 : length(ego.trials(tri).saccades)
									ego.trials(tri).saccades(lf).time = ego.trials(tri).saccades(lf).sttime - ego.trials(tri).rtstarttime;
									ego.trials(tri).saccades(lf).rt = true;
									ego.trials(tri).saccadeTimes(lf) = ego.trials(tri).saccades(lf).time;
								end
							end
							continue
						end
						
						endrt = regexpi(evt.message,['^' ego.rtEndMessage],'match');
						if ~isempty(endrt)
							ego.trials(tri).rtendtime = double(evt.sttime);
							if isfield(ego.trials,'rtstarttime')
								ego.trials(tri).rttime = ego.trials(tri).rtendtime - ego.trials(tri).rtstarttime;
							end
							continue
						end
						
						id = regexpi(evt.message,'^TRIAL_RESULT (?<ID>(\-|\+|\d)+)','names');
						if ~isempty(id) && ~isempty(id.ID)
							ego.trials(tri).entime = double(evt.sttime);
							ego.trials(tri).result = str2num(id.ID);
							ego.trials(tri).firstSaccade = [];
							sT = ego.trials(tri).saccadeTimes;
							if max(sT(sT>0)) > 0
								sT = min(sT(sT>0)); %shortest RT after END_FIX
							elseif ~isempty(sT)
								sT = sT(1); %simply the first time
							else
								sT = NaN;
							end
							ego.trials(tri).firstSaccade = sT;
							if ego.trials(tri).result == 1
								ego.trials(tri).correct = true;
								ego.correct.idx = [ego.correct.idx tri];
								ego.trialList(tri) = ego.trials(tri).variable;
								if ~isempty(sT) && sT > 0
									ego.correct.saccTimes = [ego.correct.saccTimes sT];
								else
									ego.correct.saccTimes = [ego.correct.saccTimes NaN];
								end
								ego.trials(tri).correctedIndex = tri2;
								tri2 = tri2 + 1;
							elseif ego.trials(tri).result == -1
								ego.trials(tri).breakFix = true;
								ego.breakFix.idx = [ego.breakFix.idx tri];
								ego.trialList(tri) = -ego.trials(tri).variable;
								if ~isempty(sT) && sT > 0
									ego.breakFix.saccTimes = [ego.breakFix.saccTimes sT];
								else
									ego.breakFix.saccTimes = [ego.breakFix.saccTimes NaN];
								end
								ego.trials(tri).correctedIndex = tri2;
								tri2 = tri2 + 1;
							elseif ego.trials(tri).result == 0
								ego.trials(tri).incorrect = true;
								ego.incorrect.idx = [ego.incorrect.idx tri];
								ego.trialList(tri) = -ego.trials(tri).variable;
								if ~isempty(sT) && sT > 0
									ego.incorrect.saccTimes = [ego.incorrect.saccTimes sT];
								else
									ego.incorrect.saccTimes = [ego.incorrect.saccTimes NaN];
								end
								ego.trials(tri).correctedIndex = NaN;
							end
							ego.trials(tri).deltaT = ego.trials(tri).entime - ego.trials(tri).sttime;
							isTrial = false;
							tri = tri + 1;
							continue
						end
					end
				end
			end
			
			if max(abs(ego.trialList)) == 1010 && min(abs(ego.trialList)) == 1010
				ego.needOverride = true;
				ego.salutation('','---> TRIAL NAME BUG OVERRIDE NEEDED!\n',true);
			else
				ego.needOverride = false;
			end
			
			ego.isParsed = true;
			
			parseAsVars(ego);
			parseSecondaryEyePos(ego);
			parseFixationPositions(ego);
			parseROI(ego);
			%parseTOI(ego);

			fprintf('Parsing EDF Trials took %g ms\n',round(toc*1000));
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function plot(ego,select,type,seperateVars)
			if ~exist('select','var') || ~isnumeric(select); select = []; end
			if ~exist('type','var') || isempty(type); type = 'correct'; end
			if ~exist('seperateVars','var') || ~islogical(seperateVars); seperateVars = false; end
			if length(select) > 1;
				idx = select;
				idxInternal = false;
			else
				switch lower(type)
					case 'correct'
						idx = ego.correct.idx;
					case 'breakfix'
						idx = ego.breakFix.idx;
					case 'incorrect'
						idx = ego.incorrect.idx;
				end
				idxInternal = true;
			end
			if seperateVars == true && isempty(select)
				vars = unique([ego.trials(idx).id]);
				for j = vars
					ego.plot(j,type,false);
					drawnow;
				end
				return
			end
			h=figure;
			set(gcf,'Color',[1 1 1]);
			figpos(1,[1200 1200]);
			p = panel(h);
			p.margin = [20 20 10 15]; %left bottom right top
			p.fontsize = 12;
			p.pack('v',{2/3, []});
			q = p(1);
			q.pack(2,2);
			a = 1;
			stdex = [];
			meanx = [];
			meany = [];
			stdey = [];
			xvals = [];
			yvals = [];
			tvals = [];
			medx = [];
			medy = [];
			early = 0;
			
			map = [0 0 1.0000;...
				0 0.5000 0;...
				1.0000 0 0;...
				0 0.7500 0.7500;...
				0.7500 0 0.7500;...
				1 0.7500 0;...
				0.4500 0.2500 0.2500;...
				0 0.2500 0.7500;...
				0 0 0;...
				0 0.6000 1.0000;...
				1.0000 0.5000 0.25;...
				0.6000 0 0.3000;...
				1 0 1;...
				1 0.5 0.5;...
				0.25 0.45 0.65];

			if isempty(select)
				thisVarName = 'ALL VARS ';
			elseif length(select) > 1
				thisVarName = 'SELECT TRIALS ';
			else
				thisVarName = ['VAR' num2str(select) ' '];
			end
			
			maxv = 1;
			ppd = ego.ppd;
			
			for i = idx
				if idxInternal == true %we're using the eyelin index which includes incorrects
					f = i;
				else %we're using an external index which excludes incorrects
					f = find([ego.trials.correctedIndex] == i);
				end
				if isempty(f); continue; end
				thisTrial = ego.trials(f(1));
				if thisTrial.variable == 1010 %early edf files were broken, 1010 signifies this
					c = rand(1,3);
				else
					c = map(thisTrial.variable,:);
				end
				
				if isempty(select) || length(select) > 1 || ~isempty(intersect(select,thisTrial.variable));
				else
					continue
				end
				t = thisTrial.times;
				ix = find((t >= -400) & (t <= 800));
				t=t(ix);
				x = thisTrial.gx(ix);
				y = thisTrial.gy(ix);
				x = x / ppd;
				y = y / ppd;

				if min(x) < -65 || max(x) > 65 || min(y) < -65 || max(y) > 65
					x(x<0) = -20;
					x(x>2000) = 20;
					y(y<0) = -20;
					y(y>2000) = 20;
				end

				q(1,1).select();

				q(1,1).hold('on')
				plot(x, y,'k-o','Color',c,'MarkerSize',4,'MarkerEdgeColor',[0 0 0],...
					'MarkerFaceColor',c,'UserData',[thisTrial.idx thisTrial.correctedIndex thisTrial.variable],'ButtonDownFcn', @clickMe);

				q(1,2).select();
				q(1,2).hold('on');
				plot(t,abs(x),'k-o','Color',c,'MarkerSize',4,'MarkerEdgeColor',[0 0 0],...
					'MarkerFaceColor',c,'UserData',[thisTrial.idx thisTrial.correctedIndex thisTrial.variable],'ButtonDownFcn', @clickMe);
				plot(t,abs(y),'k-x','Color',c,'MarkerSize',4,'MarkerEdgeColor',[0 0 0],...
					'MarkerFaceColor',c,'UserData',[thisTrial.idx thisTrial.correctedIndex thisTrial.variable],'ButtonDownFcn', @clickMe);
				maxv = max([maxv, max(abs(x)), max(abs(y))]) + 0.1;

				p(2).select();
				p(2).hold('on')
				for fix=1:length(thisTrial.fixations)
					f=thisTrial.fixations(fix);
					plot3([f.time f.time+f.length],[f.gstx f.genx],[f.gsty f.geny],'k-o',...
						'LineWidth',1,'MarkerSize',5,'MarkerEdgeColor',[0 0 0],...
						'MarkerFaceColor',c,'UserData',[thisTrial.idx thisTrial.correctedIndex thisTrial.variable],'ButtonDownFcn', @clickMe)
				end
				for sac=1:length(thisTrial.saccades)
					s=thisTrial.saccades(sac);
					plot3([s.time s.time+s.length],[s.gstx s.genx],[s.gsty s.geny],'r-o',...
						'LineWidth',1.5,'MarkerSize',5,'MarkerEdgeColor',[1 0 0],...
						'MarkerFaceColor',c,'UserData',[thisTrial.idx thisTrial.correctedIndex thisTrial.variable],'ButtonDownFcn', @clickMe)
				end
				p(2).margin = 50;

				idxt = find(t >= 0 & t <= 100);

				tvals{a} = t(idxt);
				xvals{a} = x(idxt);
				yvals{a} = y(idxt);

				meanx = [meanx mean(x(idxt))];
				meany = [meany mean(y(idxt))];
				medx = [medx median(x(idxt))];
				medy = [medy median(y(idxt))];
				stdex = [stdex std(x(idxt))];
				stdey = [stdey std(y(idxt))];

				q(2,1).select();
				q(2,1).hold('on');
				plot(meanx(end), meany(end),'ko','Color',c,'MarkerSize',6,'MarkerEdgeColor',[0 0 0],...
					'MarkerFaceColor',c,'UserData',[thisTrial.idx thisTrial.correctedIndex thisTrial.variable],'ButtonDownFcn', @clickMe);

				q(2,2).select();
				q(2,2).hold('on');
				plot3(meanx(end), meany(end),a,'ko','Color',c,'MarkerSize',6,'MarkerEdgeColor',[0 0 0],...
					'MarkerFaceColor',c,'UserData',[thisTrial.idx thisTrial.correctedIndex thisTrial.variable],'ButtonDownFcn', @clickMe);
				a = a + 1;
	
			end
			
			display = ego.display / ppd;
			
			q(1,1).select();
			grid on
			box on
			axis(round([-display(1)/3 display(1)/3 -display(2)/3 display(2)/3]))
			%axis square
			title(q(1,1),[thisVarName upper(type) ': X vs. Y Eye Position in Degrees'])
			xlabel(q(1,1),'X Degrees')
			ylabel(q(1,1),'Y Degrees')
			
			q(1,2).select();
			grid on
			box on
			axis tight;
			ax = axis;
			if maxv > 10; maxv = 10; end
			axis([-200 400 0 maxv])
			t=sprintf('ABS Mean/SD 100ms: X=%.2g / %.2g | Y=%.2g / %.2g', mean(abs(meanx)), mean(abs(stdex)), ...
				mean(abs(meany)), mean(abs(stdey)));
			t2 = sprintf('ABS Median/SD 100ms: X=%.2g / %.2g | Y=%.2g / %.2g', median(abs(medx)), median(abs(stdex)), ...
				median(abs(medy)), median(abs(stdey)));
			h=title(sprintf('X(square) & Y(circle) Position vs. Time\n%s\n%s', t,t2));
			set(h,'BackgroundColor',[1 1 1]);
			xlabel(q(1,2),'Time (s)')
			ylabel(q(1,2),'Degrees')
			
			p(2).select();
			grid on;
			box on;
			axis tight;
			axis([-100 400 -10 10 -10 10]);
			view([5 5]);
			xlabel(p(2),'Time (ms)')
			ylabel(p(2),'X Position')
			zlabel(p(2),'Y Position')
			h=title([thisVarName upper(type) ': Saccades (red) and Fixation (black) Events']);
			set(h,'BackgroundColor',[1 1 1]);
			
			
			q(2,1).select();
			grid on
			box on
			axis tight;
			axis([-1 1 -1 1])
			h=title(sprintf('X & Y First 100ms MD/MN/STD: \nX : %.2g / %.2g / %.2g | Y : %.2g / %.2g / %.2g', ... 
				mean(meanx), median(medx),mean(stdex),mean(meany),median(medy),mean(stdey)));			
			set(h,'BackgroundColor',[1 1 1]);
			xlabel(q(2,1),'X Degrees')
			ylabel(q(2,1),'Y Degrees')
			
			q(2,2).select();
			grid on
			box on
			axis tight;
			axis([-1 1 -1 1])
			%axis square
			view(47,15)
			title(q(2,2),[thisVarName upper(type) ':Average X vs. Y Position for first 150ms Over Time'])
			xlabel(q(2,2),'X Degrees')
			ylabel(q(2,2),'Y Degrees')
			zlabel(q(2,2),'Trial')
			
			p(2).margintop = 20;
			
			assignin('base','xvals',xvals)
			assignin('base','yvals',yvals)
			
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
					disp(['TRIAL | CORRECTED | VAR = ' num2str(ud)]);
					disp(ego.trials(ud(1)));
				end
			end
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function parseROI(ego)
			if isempty(ego.ROI)
				disp('No ROI specified!!!')
				return
			end
			ppd = ego.ppd;
			fixationX = ego.ROI(1);
			fixationY = ego.ROI(2);
			fixationRadius = ego.ROI(3);
			for i = 1:length(ego.trials)
				ego.ROIInfo(i).variable = ego.trials(i).variable;
				ego.ROIInfo(i).idx = i;
				ego.ROIInfo(i).correctedIndex = ego.trials(i).correctedIndex;
				ego.ROIInfo(i).uuid = ego.trials(i).uuid;
				ego.ROIInfo(i).fixationX = fixationX;
				ego.ROIInfo(i).fixationY = fixationY;
				ego.ROIInfo(i).fixationRadius = fixationRadius;
				x = ego.trials(i).gx / ppd;
				y = ego.trials(i).gy  / ppd;
				times = ego.trials(i).times;
				f = find(times > 0); % we only check ROI post 0 time
				r = sqrt((x - fixationX).^2 + (y - fixationY).^2); 
				r=r(f);
				window = find(r < fixationRadius);
				if any(window)
					ego.ROIInfo(i).enteredROI = true;
				else
					ego.ROIInfo(i).enteredROI = false;
				end	
				ego.trials(i).enteredROI = ego.ROIInfo(i).enteredROI;
				ego.ROIInfo(i).x = x;
				ego.ROIInfo(i).y = y;
				ego.ROIInfo(i).times = times/1e3;
				ego.ROIInfo(i).correct = ego.trials(i).correct;
				ego.ROIInfo(i).breakFix = ego.trials(i).breakFix;
				ego.ROIInfo(i).incorrect = ego.trials(i).incorrect;
			end
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function parseTOI(ego)
			if isempty(ego.TOI)
				disp('No TOI specified!!!')
				return
			end
			ppd = ego.ppd;
			fixationX = ego.ROI(1);
			fixationY = ego.ROI(2);
			fixationRadius = ego.ROI(3);
			for i = 1:length(ego.trials)
				ego.ROIInfo(i).variable = ego.trials(i).variable;
				ego.ROIInfo(i).idx = i;
				ego.ROIInfo(i).correctedIndex = ego.trials(i).correctedIndex;
				ego.ROIInfo(i).uuid = ego.trials(i).uuid;
				ego.ROIInfo(i).fixationX = fixationX;
				ego.ROIInfo(i).fixationY = fixationY;
				ego.ROIInfo(i).fixationRadius = fixationRadius;
				x = ego.trials(i).gx / ppd;
				y = ego.trials(i).gy  / ppd;
				times = ego.trials(i).times;
				f = find(times > 0); % we only check ROI post 0 time
				r = sqrt((x - fixationX).^2 + (y - fixationY).^2); 
				r=r(f);
				window = find(r < fixationRadius);
				if any(window)
					ego.ROIInfo(i).enteredROI = true;
				else
					ego.ROIInfo(i).enteredROI = false;
				end	
				ego.trials(i).enteredROI = ego.ROIInfo(i).enteredROI;
				ego.ROIInfo(i).x = x;
				ego.ROIInfo(i).y = y;
				ego.ROIInfo(i).times = times/1e3;
				ego.ROIInfo(i).correct = ego.trials(i).correct;
				ego.ROIInfo(i).breakFix = ego.trials(i).breakFix;
				ego.ROIInfo(i).incorrect = ego.trials(i).incorrect;
			end
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function plotROI(ego)
			if ~isempty(ego.ROIInfo)
				h=figure;figpos(1,[2000 1000]);set(h,'Color',[1 1 1],'Name',ego.file);
				
				x1 = ego.ROI(1) - ego.ROI(3);
				x2 = ego.ROI(1) + ego.ROI(3);
				xmin = min([abs(x1), abs(x2)]);
				xmax = max([abs(x1), abs(x2)]);
				y1 = ego.ROI(2) - ego.ROI(3);
				y2 = ego.ROI(2) + ego.ROI(3);
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
				yes = logical([ego.ROIInfo.enteredROI]);
				no = ~yes;
				yesROI = ego.ROIInfo(yes);
				noROI	= ego.ROIInfo(no);
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
				p(1,1).title(['ROI PLOT for ' num2str(ego.ROI) ' (entered = ' num2str(sum(yes)) ' | did not = ' num2str(sum(no)) ')']);
				p(1,1).xlabel('X Position (degs)')
				p(1,1).ylabel('Y Position (degs)')
				axis square
				axis([-10 10 -10 10]);
				p(1,2).select();
				p(1,2).hold('off');
				box on
				grid on
				p(1,2).title(['ROI PLOT for ' num2str(ego.ROI) ' (entered = ' num2str(sum(yes)) ' | did not = ' num2str(sum(no)) ')']);
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
		function ppd = get.ppd(ego)
			if ego.distance == 57.3 && ego.override573 == true
				ppd = round( ego.pixelsPerCm * (67 / 57.3)); %set the pixels per degree, note this fixes some older files where 57.3 was entered instead of 67cm
			else
				ppd = round( ego.pixelsPerCm * (ego.distance / 57.3)); %set the pixels per degree
			end
			ego.ppd_ = ppd;
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function fixVarNames(ego)
			if ego.needOverride == true
				if isempty(ego.trialOverride)
					warning('No replacement trials available!!!')
					return
				end
				trials = ego.trialOverride;
				if  max([ego.trials.correctedIndex]) ~= length(trials)
					warning('TRIAL ID LENGTH MISMATCH!');
					return
				end
				a = 1;
				for j = 1:length(ego.trials)
					if ego.trials(j).incorrect ~= true
						ego.trials(j).oldid = ego.trials(j).variable;
						ego.trials(j).variable = trials(a).variable;
						ego.trialList(j) = ego.trials(j).variable;
						if ego.trials(j).breakFix == true
							ego.trialList(j) = -[ego.trialList(j)];
						end
						a = a + 1;
					end
				end
				disp('---> Trial name override in place!!!')
			end
		end
		
	end%-------------------------END PUBLIC METHODS--------------------------------%
	
	%=======================================================================
	methods (Access = private) %------------------PRIVATE METHODS
	%=======================================================================
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function parseAsVars(ego)
			ego.vars = struct();
			ego.vars(1).name = '';
			ego.vars(1).variable = [];
			ego.vars(1).idx = [];
			ego.vars(1).correctedidx = [];
			ego.vars(1).trial = [];
			ego.vars(1).sTime = [];
			ego.vars(1).sT = [];
			ego.vars(1).uuid = {};
			for i = 1:length(ego.trials)
				trial = ego.trials(i);
				var = trial.variable;
				if trial.incorrect == true
					continue
				end
				if trial.variable == 1010
					continue
				end
				ego.vars(var).name = num2str(var);
				ego.vars(var).trial = [ego.vars(var).trial; trial];
				ego.vars(var).idx = [ego.vars(var).idx i];
				ego.vars(var).correctedidx = [ego.vars(var).correctedidx i];
				ego.vars(var).uuid = [ego.vars(var).uuid, trial.uuid];
				ego.vars(var).variable = [ego.vars(var).variable var];
				if ~isempty(trial.saccadeTimes)
					ego.vars(var).sTime = [ego.vars(var).sTime trial.saccadeTimes(1)];
				else
					ego.vars(var).sTime = [ego.vars(var).sTime NaN];
				end
				ego.vars(var).sT = [ego.vars(var).sT trial.firstSaccade];
			end
		end
		
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function parseSecondaryEyePos(ego)
			if ego.isParsed && isstruct(ego.tS)
				f=fieldnames(ego.tS.eyePos); %get fieldnames
				re = regexp(f,'^CC','once'); %regexp over the cell
				idx = cellfun(@(c)~isempty(c),re); %check which regexp returned true
				f = f(idx); %use this index
				ego.validation(1).uuids = f;
				ego.validation.lengthCorrect = length(f);
			end
		end
		
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function parseFixationPositions(ego)
			if ego.isParsed
				for i = 1:length(ego.trials)
					t = ego.trials(i);
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
					if isempty(ego.(bname).fixations)
						ego.(bname).fixations = f;
					else
						ego.(bname).fixations(end+1) = f;
					end
				end
				
			end
			
		end
		
		% ===================================================================
		%> @brief
		%>
		% ===================================================================
		function [outx, outy] = toDegrees(ego,in)
			if length(in)==2
				outx = (in(1) - ego.xCenter) / ego.ppd_;
				outy = (in(2) - ego.yCenter) / ego.ppd_;
			else
				outx = [];
				outy = [];
			end
		end
		
		% ===================================================================
		%> @brief
		%>
		% ===================================================================
		function [outx, outy] = toPixels(ego,in)
			if length(in)==2
				outx = (in(1) * ego.ppd_) + ego.xCenter;
				outy = (in(2) * ego.ppd_) + ego.yCenter;
			else
				outx = [];
				outy = [];
			end
		end
		
	end
	
end

