% ========================================================================
%> @brief eyelinkManager wraps around the eyelink toolbox functions
%> offering a simpler interface
%>
% ========================================================================
classdef eyelinkAnalysis < optickaCore
	
	properties
		file@char = ''
		dir@char = ''
		verbose = false
		pixelsPerCm@double = 32
		distance@double = 57.3
		rtStartMessage@char = 'END_FIX'
		rtEndMessage@char = 'END_RT'
		varList@double = []
	end
	
	properties (SetAccess = private, GetAccess = public)
		%> raw data
		raw@struct
		%inidividual trials
		trials@struct
		trialList@double
		cidx@double
		cSaccTimes@double
		display@double
		devList@double
		vars
	end
	
	properties (SetAccess = private, GetAccess = private)
		%> allowed properties passed to object upon construction
		allowedProperties@char = 'file|dir|verbose'
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
			fprintf('Loading EDF Files took %g ms\n',round(toc*1000));
		end
		
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function parse(obj)
			tic
			isTrial = false;
			tri = 1;
			obj.trials = struct;
			obj.cidx = [];
			obj.cSaccTimes = [];
	
			for i = 1:length(obj.raw.FEVENT)
				isMessage = false;
				evt = obj.raw.FEVENT(i);
				
				while 1 %this while is what our breaks break out of
					if strcmpi(evt.codestring,'MESSAGEEVENT')
						isMessage = true;
					end
					if isMessage && ~isTrial
						no = regexpi(evt.message,'^(?<NO>!cal|Validate|Reccfg|elclcfg)','names'); %ignore these first
						if ~isempty(no)  && ~isempty(no.NO)
							break
						end
						
						rt = regexpi(evt.message,'^(?<d>V_RT MESSAGE) (?<a>\w+) (?<b>\w+)','names');
						if ~isempty(rt) && ~isempty(rt.a) && ~isempty(rt.b)
							obj.rtStartMessage = rt.a;
							obj.rtEndMessage = rt.b;
							break
						end

						xy = regexpi(evt.message,'^DISPLAY_COORDS \d? \d? (?<x>\d+) (?<y>\d+)','names');
						if ~isempty(xy)  && ~isempty(xy.x)
							obj.display = [str2num(xy.x)+1 str2num(xy.y)+1];
							break
						end

						id = regexpi(evt.message,'^(?<TAG>TRIALID) (?<ID>\d?)','names');
						if ~isempty(id) && ~isempty(id.TAG)
							if isempty(id.ID) %we have a bug in early EDF files with an empty TRIALID!!!
								id.ID = '1010';
							end
							isTrial = true;
							obj.trials(tri).id = str2double(id.ID);
							obj.trials(tri).time = double(evt.time);
							obj.trials(tri).sttime = double(evt.sttime);
							obj.trials(tri).rt = false;
							obj.trials(tri).rtstarttime = double(evt.sttime);
							obj.trials(tri).fixations = [];
							obj.trials(tri).saccades = [];
							obj.trials(tri).saccadeTimes = [];
							obj.trials(tri).rttime = [];
							break
						end
					end

					if isTrial 

						if strcmpi(evt.codestring,'STARTSAMPLES')
							obj.trials(tri).startsampletime = double(evt.sttime);
							break
						end

						if strcmpi(evt.codestring,'ENDFIX')
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
							fixa.sttime = double(evt.sttime);
							fixa.entime = double(evt.entime);
							fixa.time = fixa.sttime - rel;
							fixa.length = fixa.entime - fixa.sttime;
							fixa.rel = rel;
							fixa.gstx = evt.gstx;
							fixa.gsty = evt.gsty;
							fixa.genx = evt.genx;
							fixa.geny = evt.geny;
							fixa.x = evt.gavx;
							fixa.y = evt.gavy;
							
							if fix == 1
								obj.trials(tri).fixations = fixa;
							else
								obj.trials(tri).fixations(fix) = fixa;
							end
							obj.trials(tri).nfix = fix;
							break
						end

						if strcmpi(evt.codestring,'ENDSACC')
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
							sacc.sttime = double(evt.sttime);
							sacc.entime = double(evt.entime);
							sacc.time = sacc.sttime - rel;
							sacc.length = sacc.entime - sacc.sttime;
							sacc.rel = rel;
							sacc.gstx = evt.gstx;
							sacc.gsty = evt.gsty;
							sacc.genx = evt.genx;
							sacc.geny = evt.geny;
							sacc.x = sacc.genx - sacc.gstx;
							sacc.y = sacc.geny - sacc.gsty;
							
							if fix == 1
								obj.trials(tri).saccades = sacc;
							else
								obj.trials(tri).saccades(fix) = sacc;
							end
							obj.trials(tri).nsacc = fix;
							if sacc.rt == true
								obj.trials(tri).saccadeTimes = [obj.trials(tri).saccadeTimes sacc.time];
							end
							break
						end

						if strcmpi(evt.codestring,'ENDSAMPLES')
							obj.trials(tri).endsampletime = double(evt.sttime);

							obj.trials(tri).times = double(obj.raw.FSAMPLE.time( ...
								obj.raw.FSAMPLE.time >= obj.trials(tri).startsampletime & ...
								obj.raw.FSAMPLE.time <= obj.trials(tri).endsampletime));
							obj.trials(tri).times = obj.trials(tri).times - obj.trials(tri).rtstarttime;
							obj.trials(tri).gx = obj.raw.FSAMPLE.gx(1, ...
								obj.raw.FSAMPLE.time >= obj.trials(tri).startsampletime & ...
								obj.raw.FSAMPLE.time <= obj.trials(tri).endsampletime);
							obj.trials(tri).gx = obj.trials(tri).gx - obj.display(1)/2;
							obj.trials(tri).gy = obj.raw.FSAMPLE.gy(1, ...
								obj.raw.FSAMPLE.time >= obj.trials(tri).startsampletime & ...
								obj.raw.FSAMPLE.time <= obj.trials(tri).endsampletime);
							obj.trials(tri).gy = obj.trials(tri).gy - obj.display(2)/2;
							obj.trials(tri).hx = obj.raw.FSAMPLE.hx(1, ...
								obj.raw.FSAMPLE.time >= obj.trials(tri).startsampletime & ...
								obj.raw.FSAMPLE.time <= obj.trials(tri).endsampletime);
							obj.trials(tri).hy = obj.raw.FSAMPLE.hy(1, ...
								obj.raw.FSAMPLE.time >= obj.trials(tri).startsampletime & ...
								obj.raw.FSAMPLE.time <= obj.trials(tri).endsampletime);
							break
						end

						if isMessage
							uuid = regexpi(evt.message,'^UUID (?<UUID>[\w]+)','names');
							if ~isempty(uuid) && ~isempty(uuid.UUID)
								obj.trials(tri).uuid = uuid.UUID;
								break
							end

							endfix = regexpi(evt.message,['^' obj.rtStartMessage],'names');
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
								break
							end

							endrt = regexpi(evt.message,['^' obj.rtEndMessage],'names');
							if ~isempty(endrt)
								obj.trials(tri).rtendtime = double(evt.sttime);
								if isfield(obj.trials,'rtstarttime')
									obj.trials(tri).rttime = obj.trials(tri).rtendtime - obj.trials(tri).rtstarttime;
								end
								break
							end		

							id = regexpi(evt.message,'^TRIAL_RESULT (?<ID>\d+)','names');
							if ~isempty(id) && ~isempty(id.ID)
								obj.trials(tri).entime = double(evt.sttime);
								obj.trials(tri).result = str2num(id.ID);
								if obj.trials(tri).result == 1
									obj.trials(tri).correct = true;
									obj.cidx = [obj.cidx tri];
									obj.trialList(tri) = obj.trials(tri).id;
									if ~isempty(obj.trials(tri).saccadeTimes)
										sT = obj.trials(tri).saccadeTimes;
										if max(sT(sT>0)) > 0
											sT = min(sT(sT>0)); %shortest RT after END_FIX
										else
											sT = sT(1); %simply the first time
										end
										obj.cSaccTimes = [obj.cSaccTimes sT];
									else
										obj.cSaccTimes = [obj.cSaccTimes -Inf];
									end
								else
									obj.trials(tri).correct = false;
									obj.trialList(tri) = -obj.trials(tri).id;
								end
								obj.trials(tri).deltaT = obj.trials(tri).entime - obj.trials(tri).sttime;
								isTrial = false;
								tri = tri + 1;
								break
							end
						end
					end
					break
				end	%WHILE 1
			end
			
			parseAsVars(obj);
			
			fprintf('Parsing EDF Trials took %g ms\n',round(toc*1000));
		end
		
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function plot(obj)
			h=figure;
			set(gcf,'Color',[1 1 1]);
			figpos(1,[1200 1200])
			p = panel(h);
			p.pack(2,2);
			
			a = 1;
			stdex = [];
			stdey = [];
			early = 0;
			
			map = [0 0 1.0000;...
				0 0.5000 0;...
				1.0000 0 0;...
				0 0.7500 0.7500;...
				0.7500 0 0.7500;...
				1 0.7500 0;...
				0.2500 0.2500 0.2500;...
				0 0.2500 0.7500;...
				0 0 0;...
				0 0.6000 1.0000;...
				1.0000 0.5000 0.25;...
				0.6000 0 0.3000;...
				1 0 1;...
				1 0.5 0.5];
	
			for i = obj.cidx
				tr = obj.trials(i);
				if tr.id == 1010 %early edf files were broken, 1010 signifies this
					c = rand(1,3);
				else
					c = map(tr.id,:);
				end
				
				t = tr.times;
				idx = find((t >= -400) & (t <= 800));
				t=t(idx);
				x = tr.gx(idx);
				y = tr.gy(idx);
				
				if min(x) < -2000 || max(x) > 2000 || min(y) < -2000 || max(y) > 2000
					obj.devList = [obj.devList i];
					x(x<0) = -2000;
					x(x>2000) = 2000;
					y(y<0) = -2000;
					y(y>2000) = 2000;
				end
				
				p(1,1).select();
				
				p(1,1).hold('on')
				plot(x, y,'k-o','Color',c,'MarkerSize',5,'MarkerEdgeColor',[0 0 0], 'MarkerFaceColor',c);
				
				p(1,2).select();
				p(1,2).hold('on');
				plot(t,abs(x),'k-o','Color',c,'MarkerSize',5,'MarkerEdgeColor',[0 0 0], 'MarkerFaceColor',c);
				plot(t,abs(y),'k-o','Color',c,'MarkerSize',5,'MarkerEdgeColor',[0 0 0], 'MarkerFaceColor',c);

				p(2,1).select();
				p(2,1).hold('on');
				plot(mean(x(1:10)), mean(y(1:10)),'ko','Color',c,'MarkerSize',5,'MarkerEdgeColor',[0 0 0], 'MarkerFaceColor',c);
				stdex = [stdex std(x(1:10))];
				stdey = [stdey std(y(1:10))];

				p(2,2).select();
				p(2,2).hold('on');
				plot3(mean(x(1:10)), mean(y(1:10)),a,'ko','Color',c,'MarkerSize',5,'MarkerEdgeColor',[0 0 0], 'MarkerFaceColor',c);
				a = a + 1;
			end
			
			p(1,1).select();
			grid on
			box on
			axis([-obj.display(1)/2 obj.display(1)/2 -obj.display(2)/2 obj.display(2)/2])
			axis square
			title('X vs. Y Eye Position in Degrees')
			xlabel('X Pixels')
			ylabel('Y Pixels')
			
			p(1,2).select();
			grid on
			box on
			axis([-200 500 0 500])
			title(sprintf('X and Y Position vs. time | Early = %g / %g', sum(early),length(early)))
			xlabel('Time (s)')
			ylabel('Pixels')
			
			p(2,1).select();
			grid on
			box on
			axis square
			title(sprintf('Average X vs. Y Position for first 150ms STDX: %g | STDY: %g',mean(stdex),mean(stdey)))
			xlabel('X Pixels')
			ylabel('Y Pixels')
			
			p(2,2).select();
			grid on
			box on
			axis square
			title('Average X vs. Y Position for first 150ms Over Time')
			xlabel('X Pixels')
			ylabel('Y Pixels')
			zlabel('Trial')
		end
		
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function parseAsVars(obj)
			
			obj.vars = struct();
			if ~isempty(obj.varList)
				varList = obj.varList; %#ok<*PROP>
			else
				varList = obj.trialList(obj.cidx);
			end
			if length(varList) ~= length(obj.cidx)
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
				idx = obj.cidx(i);
				trial = obj.trials(idx);
				
				sT = trial.saccadeTimes(trial.saccadeTimes > 0);
				sT = min(sT);
				
				obj.vars(var).name = '';
				obj.vars(var).trial = [obj.vars(var).trial; trial];
				obj.vars(var).idx = [obj.vars(var).idx idx];
				obj.vars(var).uuid = [obj.vars(var).uuid, trial.uuid];
				obj.vars(var).id = [obj.vars(var).id var];
				obj.vars(var).sTime = [obj.vars(var).sTime obj.cSaccTimes(i)];
				obj.vars(var).sT = [obj.vars(var).sT sT];
			end
			
		end
		
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function spikeCorrelation(obj)
			global data
			
			[e,vals] = finderror(data);
			
			
		end
		
		
		
	end%-------------------------END PUBLIC METHODS--------------------------------%
	
	%=======================================================================
	methods (Access = private) %------------------PRIVATE METHODS
	%=======================================================================
		
		
		
	end
	
end

