% ========================================================================
%> @brief eyelinkManager wraps around the eyelink toolbox functions
%> offering a simpler interface
%>
% ========================================================================
classdef eyelinkAnalysis < optickaCore
	
	properties
		%> file name
		file@char = ''
		%> directory
		dir@char = ''
		%> verbose output?
		verbose = false
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
		%> variable list from the saved data
		varList@double
		%> the temporary experiement structure which contains the eyePos recorded from opticka
		tS@struct
		%> these are used for spikes spike saccade time correlations
		rtLimits@double
		rtDivision@double
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
		%> the trial variable identifier, negative values were incorrect trials
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
		%> does the trial variable list match the other saved data?
		validation@struct
	end
	
	properties (Dependent = true, SetAccess = private)
		%> pixels per degree calculated from pixelsPerCm and distance
		ppd
	end
	
	properties (SetAccess = private, GetAccess = private)
		%> allowed properties passed to object upon construction
		allowedProperties@char = 'file|dir|verbose|pixelsPerCm|distance|xCenter|yCenter|rtStartMessage|rtEndMessage|varList|rtDivision|rtLimits|tS'
	end
	
	methods
		% ===================================================================
		%> @brief
		%>
		% ===================================================================
		function obj = eyelinkAnalysis(varargin)
			if nargin == 0; varargin.name = 'eyelinkAnalysis';end
			if nargin>0
				obj.parseArgs(varargin,obj.allowedProperties);
			end
			if isempty(obj.file) || isempty(obj.dir)
				[obj.file, obj.dir] = uigetfile('*.edf','Load EDF File:');
			end
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function load(obj)
			tic
			if ~isempty(obj.file)
				oldpath = pwd;
				cd(obj.dir)
				obj.raw = edfmex(obj.file);
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
		function parse(obj)
			obj.isParsed = false;
			tic
			isTrial = false;
			tri = 1; %current trial that is being parsed
			eventN = 0;
			obj.comment = obj.raw.HEADER;
			obj.trials = struct();
			obj.correct.idx = [];
			obj.correct.saccTimes = [];
			obj.correct.fixations = [];
			obj.breakFix = obj.correct;
			obj.incorrect = obj.correct;
			obj.trialList = [];
			
			sample = obj.raw.FSAMPLE.gx(:,100); %check which eye
			if sample(1) == -32768 %only use right eye if left eye data is not present
				eyeUsed = 2; %right eye index for FSAMPLE.gx;
			else
				eyeUsed = 1; %left eye index
			end
			
			for i = 1:length(obj.raw.FEVENT)
				isMessage = false;
				evt = obj.raw.FEVENT(i);
				
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
						obj.rtStartMessage = rt.a;
						obj.rtEndMessage = rt.b;
						continue
					end
					
					xy = regexpi(evt.message,'^DISPLAY_COORDS \d? \d? (?<x>\d+) (?<y>\d+)','names');
					if ~isempty(xy)  && ~isempty(xy.x)
						obj.display = [str2num(xy.x)+1 str2num(xy.y)+1];
						continue
					end
					
					id = regexpi(evt.message,'^(?<TAG>TRIALID)(\s*)(?<ID>\d*)','names');
					if ~isempty(id) && ~isempty(id.TAG)
						if isempty(id.ID) %we have a bug in early EDF files with an empty TRIALID!!!
							id.ID = '1010';
						end
						isTrial = true;
						eventN=1;
						obj.trials(tri).id = str2double(id.ID);
						obj.trials(tri).time = double(evt.time);
						obj.trials(tri).sttime = double(evt.sttime);
						obj.trials(tri).rt = false;
						obj.trials(tri).rtstarttime = double(evt.sttime);
						obj.trials(tri).fixations = [];
						obj.trials(tri).saccades = [];
						obj.trials(tri).saccadeTimes = [];
						obj.trials(tri).rttime = [];
						obj.trials(tri).uuid = [];
						obj.trials(tri).correct = false;
						obj.trials(tri).breakFix = false;
						obj.trials(tri).incorrect = false;
						continue
					end
				end
				
				if isTrial
					
					if ~isMessage
						
						if strcmpi(evt.codestring,'STARTSAMPLES')
							obj.trials(tri).startsampletime = double(evt.sttime);
							continue
						end
						
						if evt.type == 8 %strcmpi(evt.codestring,'ENDFIX')
							fixa = [];
							if isempty(obj.trials(tri).fixations)
								fix = 1;
							else
								fix = length(obj.trials(tri).fixations)+1;
							end
							if obj.trials(tri).rt == true
								rel = obj.trials(tri).rtstarttime;
								fixa.rt = true;
							else
								rel = obj.trials(tri).sttime;
								fixa.rt = false;
							end
							fixa.n = eventN;
							fixa.ppd = obj.ppd;
							fixa.sttime = double(evt.sttime);
							fixa.entime = double(evt.entime);
							fixa.time = fixa.sttime - rel;
							fixa.length = fixa.entime - fixa.sttime;
							fixa.rel = rel;

							[fixa.gstx, fixa.gsty]  = toDegrees(obj, [evt.gstx, evt.gsty]);
							[fixa.genx, fixa.geny]  = toDegrees(obj, [evt.genx, evt.geny]);
							[fixa.x, fixa.y]		= toDegrees(obj, [evt.gavx, evt.gavy]);
							[fixa.theta, fixa.rho]	= cart2pol(fixa.x, fixa.y);
							fixa.theta = rad2ang(fixa.theta);
							
							if fix == 1
								obj.trials(tri).fixations = fixa;
							else
								obj.trials(tri).fixations(fix) = fixa;
							end
							obj.trials(tri).nfix = fix;
							eventN = eventN + 1;
							continue
						end
						
						if evt.type == 6 % strcmpi(evt.codestring,'ENDSACC')
							sacc = [];
							if isempty(obj.trials(tri).saccades)
								fix = 1;
							else
								fix = length(obj.trials(tri).saccades)+1;
							end
							if obj.trials(tri).rt == true
								rel = obj.trials(tri).rtstarttime;
								sacc.rt = true;
							else
								rel = obj.trials(tri).sttime;
								sacc.rt = false;
							end
							sacc.n = eventN;
							sacc.ppd = obj.ppd;
							sacc.sttime = double(evt.sttime);
							sacc.entime = double(evt.entime);
							sacc.time = sacc.sttime - rel;
							sacc.length = sacc.entime - sacc.sttime;
							sacc.rel = rel;

							[sacc.gstx, sacc.gsty]	= toDegrees(obj, [evt.gstx evt.gsty]);
							[sacc.genx, sacc.geny]	= toDegrees(obj, [evt.genx evt.geny]);
							[sacc.x, sacc.y]		= deal((sacc.genx - sacc.gstx), (sacc.geny - sacc.gsty));
							[sacc.theta, sacc.rho]	= cart2pol(sacc.x, sacc.y);
							sacc.theta = rad2ang(sacc.theta);
							
							if fix == 1
								obj.trials(tri).saccades = sacc;
							else
								obj.trials(tri).saccades(fix) = sacc;
							end
							obj.trials(tri).nsacc = fix;
							if sacc.rt == true
								obj.trials(tri).saccadeTimes = [obj.trials(tri).saccadeTimes sacc.time];
							end
							eventN = eventN + 1;
							continue
						end
						
						if evt.type == 16 %strcmpi(evt.codestring,'ENDSAMPLES')
							obj.trials(tri).endsampletime = double(evt.sttime);
							
							obj.trials(tri).times = double(obj.raw.FSAMPLE.time( ...
								obj.raw.FSAMPLE.time >= obj.trials(tri).startsampletime & ...
								obj.raw.FSAMPLE.time <= obj.trials(tri).endsampletime));
							obj.trials(tri).times = obj.trials(tri).times - obj.trials(tri).rtstarttime;
							obj.trials(tri).gx = obj.raw.FSAMPLE.gx(eyeUsed, ...
								obj.raw.FSAMPLE.time >= obj.trials(tri).startsampletime & ...
								obj.raw.FSAMPLE.time <= obj.trials(tri).endsampletime);
							obj.trials(tri).gx = obj.trials(tri).gx - obj.display(1)/2;
							obj.trials(tri).gy = obj.raw.FSAMPLE.gy(eyeUsed, ...
								obj.raw.FSAMPLE.time >= obj.trials(tri).startsampletime & ...
								obj.raw.FSAMPLE.time <= obj.trials(tri).endsampletime);
							obj.trials(tri).gy = obj.trials(tri).gy - obj.display(2)/2;
							obj.trials(tri).hx = obj.raw.FSAMPLE.hx(eyeUsed, ...
								obj.raw.FSAMPLE.time >= obj.trials(tri).startsampletime & ...
								obj.raw.FSAMPLE.time <= obj.trials(tri).endsampletime);
							obj.trials(tri).hy = obj.raw.FSAMPLE.hy(eyeUsed, ...
								obj.raw.FSAMPLE.time >= obj.trials(tri).startsampletime & ...
								obj.raw.FSAMPLE.time <= obj.trials(tri).endsampletime);
							obj.trials(tri).pa = obj.raw.FSAMPLE.pa(eyeUsed, ...
								obj.raw.FSAMPLE.time >= obj.trials(tri).startsampletime & ...
								obj.raw.FSAMPLE.time <= obj.trials(tri).endsampletime);
							continue
						end
						
					else
						uuid = regexpi(evt.message,'^UUID (?<UUID>[\w]+)','names');
						if ~isempty(uuid) && ~isempty(uuid.UUID)
							obj.trials(tri).uuid = uuid.UUID;
							continue
						end
						
						endfix = regexpi(evt.message,['^' obj.rtStartMessage],'match');
						if ~isempty(endfix)
							obj.trials(tri).rtstarttime = double(evt.sttime);
							obj.trials(tri).rt = true;
							if ~isempty(obj.trials(tri).fixations)
								for lf = 1 : length(obj.trials(tri).fixations)
									obj.trials(tri).fixations(lf).time = obj.trials(tri).fixations(lf).sttime - obj.trials(tri).rtstarttime;
									obj.trials(tri).fixations(lf).rt = true;
								end
							end
							if ~isempty(obj.trials(tri).saccades)
								for lf = 1 : length(obj.trials(tri).saccades)
									obj.trials(tri).saccades(lf).time = obj.trials(tri).saccades(lf).sttime - obj.trials(tri).rtstarttime;
									obj.trials(tri).saccades(lf).rt = true;
									obj.trials(tri).saccadeTimes(lf) = obj.trials(tri).saccades(lf).time;
								end
							end
							continue
						end
						
						endrt = regexpi(evt.message,['^' obj.rtEndMessage],'match');
						if ~isempty(endrt)
							obj.trials(tri).rtendtime = double(evt.sttime);
							if isfield(obj.trials,'rtstarttime')
								obj.trials(tri).rttime = obj.trials(tri).rtendtime - obj.trials(tri).rtstarttime;
							end
							continue
						end
						
						id = regexpi(evt.message,'^TRIAL_RESULT (?<ID>(\-|\+|\d)+)','names');
						if ~isempty(id) && ~isempty(id.ID)
							obj.trials(tri).entime = double(evt.sttime);
							obj.trials(tri).result = str2num(id.ID);
							if obj.trials(tri).result == 1
								obj.trials(tri).correct = true;
								obj.correct.idx = [obj.correct.idx tri];
								obj.trialList(tri) = obj.trials(tri).id;
								if ~isempty(obj.trials(tri).saccadeTimes)
									sT = obj.trials(tri).saccadeTimes;
									if max(sT(sT>0)) > 0
										sT = min(sT(sT>0)); %shortest RT after END_FIX
									else
										sT = sT(1); %simply the first time
									end
									obj.correct.saccTimes = [obj.correct.saccTimes sT];
								else
									obj.correct.saccTimes = [obj.correct.saccTimes -Inf];
								end
							elseif obj.trials(tri).result == -1
								obj.trials(tri).breakFix = true;
								obj.breakFix.idx = [obj.breakFix.idx tri];
								obj.trialList(tri) = -obj.trials(tri).id;
								if ~isempty(obj.trials(tri).saccadeTimes)
									sT = obj.trials(tri).saccadeTimes;
									if max(sT(sT>0)) > 0
										sT = min(sT(sT>0)); %shortest RT after END_FIX
									else
										sT = sT(1); %simply the first time
									end
									obj.breakFix.saccTimes = [obj.breakFix.saccTimes sT];
								else
									obj.breakFix.saccTimes = [obj.breakFix.saccTimes -Inf];
								end
							elseif obj.trials(tri).result == 0
								obj.trials(tri).incorrect = true;
								obj.incorrect.idx = [obj.incorrect.idx tri];
								obj.trialList(tri) = -obj.trials(tri).id;
								if ~isempty(obj.trials(tri).saccadeTimes)
									sT = obj.trials(tri).saccadeTimes;
									if max(sT(sT>0)) > 0
										sT = min(sT(sT>0)); %shortest RT after END_FIX
									else
										sT = sT(1); %simply the first time
									end
									obj.incorrect.saccTimes = [obj.incorrect.saccTimes sT];
								else
									obj.incorrect.saccTimes = [obj.incorrect.saccTimes -Inf];
								end
								
							end
							obj.trials(tri).deltaT = obj.trials(tri).entime - obj.trials(tri).sttime;
							isTrial = false;
							tri = tri + 1;
							continue
						end
					end
				end
			end
			
			if max(abs(obj.trialList)) == 1010 && min(abs(obj.trialList)) == 1010
				obj.needOverride = true;
				obj.salutation('','---> TRIAL NAME BUG OVERRIDE IN PLACE!\n',true);
			else
				obj.needOverride = false;
			end
			
			obj.isParsed = true;
			
			parseAsVars(obj);
			parseSecondaryEyePos(obj);
			parseFixationPositions(obj);

			fprintf('Parsing EDF Trials took %g ms\n',round(toc*1000));
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function plot(obj,select,type,seperateVars)
			if ~exist('select','var') || ~isnumeric(select); select = []; end
			if ~exist('type','var') || isempty(type); type = 'correct'; end
			if ~exist('seperateVars','var') || ~islogical(seperateVars); seperateVars = false; end
			switch type
				case 'correct'
					idx = obj.correct.idx;
				case 'breakFix'
					idx = obj.breakFix.idx;
				case 'incorrect'
					idx = obj.incorrect.idx;
			end
			if seperateVars == true && isempty(select)
				vars = unique([obj.trials(idx).id]);
				for j = vars
					obj.plot(j,type,false);
					drawnow;
				end
				return
			end
			h=figure;
			set(gcf,'Color',[1 1 1]);
			figpos(1,[1200 1200]);
			p = panel(h);
			p.margintop = 10;
			p.fontsize = 8;
			p.pack('v',{2/3, []});
			q = p(1);
			q.pack(2,2);
			if obj.distance == 57.3
				ppd = round( obj.pixelsPerCm * (67 / 57.3)); %set the pixels per degree
			else
				ppd = round( obj.pixelsPerCm * (obj.distance / 57.3)); %set the pixels per degree
			end
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
				1 0.5 0.5];

			if isempty(select)
				thisVarName = 'ALL VARS ';
			else
				thisVarName = ['VAR' num2str(select) ' '];
			end
			
			maxv = 1;
			
			for i = idx
				thisTrial = obj.trials(i);
				if thisTrial.id == 1010 %early edf files were broken, 1010 signifies this
					c = rand(1,3);
				else
					c = map(thisTrial.id,:);
				end
				
				if isempty(select) || ~isempty(intersect(select,thisTrial.id));
					doplot= true;
				else
					doplot = false;
				end
				
				if doplot == true
					t = thisTrial.times;
					idx = find((t >= -400) & (t <= 800));
					t=t(idx);
					x = thisTrial.gx(idx);
					y = thisTrial.gy(idx);
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
						'MarkerFaceColor',c,'UserData',i,'ButtonDownFcn', @clickMe);
					
					q(1,2).select();
					q(1,2).hold('on');
					plot(t,abs(x),'k-o','Color',c,'MarkerSize',4,'MarkerEdgeColor',[0 0 0],...
						'MarkerFaceColor',c,'UserData',i,'ButtonDownFcn', @clickMe);
					plot(t,abs(y),'k-x','Color',c,'MarkerSize',4,'MarkerEdgeColor',[0 0 0],...
						'MarkerFaceColor',c,'UserData',i,'ButtonDownFcn', @clickMe);
					maxv = max([maxv, max(abs(x)), max(abs(y))]) + 0.1;
					
					p(2).select();
					p(2).hold('on')
					for fix=1:length(thisTrial.fixations)
						f=thisTrial.fixations(fix);
						plot3([f.time f.time+f.length],[f.gstx f.genx],[f.gsty f.geny],'k-o',...
							'LineWidth',1,'MarkerSize',5,'MarkerEdgeColor',[0 0 0],...
							'MarkerFaceColor',c,'UserData',i,'ButtonDownFcn', @clickMe)
					end
					for sac=1:length(thisTrial.saccades)
						s=thisTrial.saccades(sac);
						plot3([s.time s.time+s.length],[s.gstx s.genx],[s.gsty s.geny],'r-o',...
							'LineWidth',1.5,'MarkerSize',5,'MarkerEdgeColor',[1 0 0],...
							'MarkerFaceColor',c,'UserData',i,'ButtonDownFcn', @clickMe)
					end
					p(2).margin = 50;
					
					idxt = find(t>0 & t < 100);
					
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
						'MarkerFaceColor',c,'UserData',i,'ButtonDownFcn', @clickMe);
					
					q(2,2).select();
					q(2,2).hold('on');
					plot3(meanx(end), meany(end),a,'ko','Color',c,'MarkerSize',6,'MarkerEdgeColor',[0 0 0],...
						'MarkerFaceColor',c,'UserData',i,'ButtonDownFcn', @clickMe);
					a = a + 1;
				end
			end
			
			display = obj.display / ppd;
			
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
					disp(['TRIAL = ' num2str(ud) ' | VAR = ' num2str(obj.trials(ud).id)]);
					disp(obj.trials(ud));
				end
			end
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function fixVarNames(obj,trials)
			if obj.needOverride == true
				a = 1;
				for j = 1:length(obj.trials)
					if obj.trials(j).incorrect ~= true
						obj.trials(j).oldid = obj.trials(j).id;
						obj.trials(j).id = trials(a).name;
						obj.trialList(j) = obj.trials(j).id;
						if obj.trials(j).breakFix == true
							obj.trialList(j) = -[obj.trialList(j)];
						end
						a = a + 1;
					end
				end
			end
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function parseAsVars(obj)
			
			obj.vars = struct();
			if ~isempty(obj.varList) && obj.needOverride == true
				varList = obj.varList; %#ok<*PROP>
			else
				varList = obj.trialList(obj.correct.idx);
				if ~isempty(setdiff(obj.trialList(obj.correct.idx)', obj.varList))
					obj.salutation('TRIAL NAMES DIFFERENT!','',true);
					return
				end
			end
			if length(varList) ~= length(obj.correct.idx)
				obj.salutation('TRIAL NAME BUG FIX FAILED!','',true);
				warndlg('TRIAL NAME BUG FIX FAILED DURING SACCADE PARSING')
				return
			end
			
			obj.vars(1).name = '';
			obj.vars(1).id = [];
			obj.vars(1).idx = [];
			obj.vars(1).trial = [];
			obj.vars(1).sTime = [];
			obj.vars(1).sT = [];
			obj.vars(1).uuid = {};
			
			for i = 1:length(varList)
				var = varList(i);
				idx = obj.correct.idx(i);
				trial = obj.trials(idx);
				
				sT = min( trial.saccadeTimes(trial.saccadeTimes > 0) );
				
				obj.vars(var).name = num2str(var);
				obj.vars(var).trial = [obj.vars(var).trial; trial];
				obj.vars(var).idx = [obj.vars(var).idx idx];
				obj.vars(var).uuid = [obj.vars(var).uuid, trial.uuid];
				obj.vars(var).id = [obj.vars(var).id var];
				obj.vars(var).sTime = [obj.vars(var).sTime obj.correct.saccTimes(i)];
				obj.vars(var).sT = [obj.vars(var).sT sT];
			end
			
		end
		
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function parseSecondaryEyePos(obj)
			if obj.isParsed && isstruct(obj.tS)
				f=fieldnames(obj.tS.eyePos); %get fieldnames
				re = regexp(f,'^CC','once'); %regexp over the cell
				idx = cellfun(@(c)~isempty(c),re); %check which regexp returned true
				f = f(idx); %use this index
				obj.validation(1).uuids = f;
				obj.validation.lengthCorrect = length(f);
			end
		end
		
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function parseFixationPositions(obj)
			
			if obj.isParsed && ~isempty(obj.correct.idx)
				obj.correct.fixations(1).isFix = false;
				obj.correct.fixations(1).idx = -1;
				obj.correct.fixations(1).times = -1;
				obj.correct.fixations(1).x = -1;
				obj.correct.fixations(1).y = -1;
				for i = 1:length(obj.correct.idx)
					idx = obj.correct.idx(i);
					t = obj.trials(idx);
					times = [t.fixations.time];
					f = find(times > 100);
					if ~isempty(f)
						obj.correct.fixations(i).isFix = true;
						obj.correct.fixations(i).idx = idx;
						for jj = 1:length(f)
							fx =  t.fixations(f(jj));
							obj.correct.fixations(i).times(jj) = fx.time;
							obj.correct.fixations(i).x(jj) = fx.x;
							obj.correct.fixations(i).y(jj) = fx.y;
						end
					else
						obj.correct.fixations(i).isFix = false;
					end
					
				end
				
			end
			
		end
		
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function ppd = get.ppd(obj)
			ppd = round( obj.pixelsPerCm * (obj.distance / 57.3)); %set the pixels per degree
		end
		
	end%-------------------------END PUBLIC METHODS--------------------------------%
	
	%=======================================================================
	methods (Access = private) %------------------PRIVATE METHODS
	%=======================================================================
		
		% ===================================================================
		%> @brief
		%>
		% ===================================================================
		function [outx, outy] = toDegrees(obj,in)
			if length(in)==2
				outx = (in(1) - obj.xCenter) / obj.ppd;
				outy = (in(2) - obj.yCenter) / obj.ppd;
			else
				outx = [];
				outy = [];
			end
		end
		
		% ===================================================================
		%> @brief
		%>
		% ===================================================================
		function [outx, outy] = toPixels(obj,in)
			if length(in)==2
				outx = (in(1) * obj.ppd) + obj.xCenter;
				outy = (in(2) * obj.ppd) + obj.yCenter;
			else
				outx = [];
				outy = [];
			end
		end
		
	end
	
end

