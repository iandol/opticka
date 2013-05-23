% ========================================================================
%> @brief eyelinkManager wraps around the eyelink toolbox functions
%> offering a simpler interface
%>
% ========================================================================
classdef eyelinkAnalysis < optickaCore
	
	properties
		file@char = ''
		dir@char = ''
		verbose = true
		pixelsPerCm@double = 32
		distance@double = 57.3
	end
	
	properties (SetAccess = private, GetAccess = public)
		%> raw data
		raw@struct
		%inidividual trials
		trials@struct
		triallist@double
		FSAMPLE@struct
		FEVENT@struct
		cidx@double
		display@double
		devlist@double
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
			if ~isempty(obj.file)
				oldpath = pwd;
				cd(obj.dir)
				obj.raw = edfmex(obj.file);
				cd(oldpath)
				obj.FEVENT = obj.raw.FEVENT;
				obj.FSAMPLE = obj.raw.FSAMPLE;
			end
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
	
			for i = 1:length(obj.raw.FEVENT)
				isMessage = false;
				evt = obj.raw.FEVENT(i);
				
				while 1 %this while is what our breaks break out of
					if strcmpi(evt.codestring,'MESSAGEEVENT')
						isMessage = true;
					end
					if isMessage && ~isTrial

						xy = regexpi(evt.message,'^DISPLAY_COORDS \d? \d? (?<x>\d+) (?<y>\d+)','names');
						if ~isempty(xy)  && ~isempty(xy.x)
							obj.display = [str2num(xy.x)+1 str2num(xy.y)+1];
							break
						end

						id = regexpi(evt.message,'^TRIALID (?<ID>\d+)','names');
						if ~isempty(id)  && ~isempty(id.ID)
							isTrial = true;
							obj.trials(tri).id = str2num(id.ID);
							obj.trials(tri).time = double(evt.time);
							obj.trials(tri).sttime = double(evt.sttime);
							break
						end
					end

					if isTrial 

						if strcmpi(evt.codestring,'STARTSAMPLES')
							obj.trials(tri).startsampletime = double(evt.sttime);
							break
						end

						if strcmpi(evt.codestring,'STARTFIX')
							obj.trials(tri).startfixtime = double(evt.sttime);
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

							endfix = regexpi(evt.message,'^END_FIX','names');
							if ~isempty(endfix)
								obj.trials(tri).rtstarttime = double(evt.sttime);
								break
							end

							endrt = regexpi(evt.message,'^END_RT','names');
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
									obj.triallist(tri) = obj.trials(tri).id;
								else
									obj.trials(tri).correct = false;
									obj.triallist(tri) = -obj.trials(tri).id;
								end
								obj.trials(tri).deltaT = obj.trials(tri).entime - obj.trials(tri).sttime;
								isTrial = false;
								tri = tri + 1;
								break
							end
						end
					end
					break
				end	
			end
			fprintf('Parsing EDF Trials took %g ms\n',toc*1000);
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
			
			map = pmkmp(8);
			
			for i = obj.cidx
				tr = obj.trials(i);
				%c = rand(1,3);
				c = map(tr.id,:);
				
				t = tr.times;
				idx = find((t >= -400) & (t <= 800));
				t=t(idx);
				x = tr.gx(idx);
				y = tr.gy(idx);
				
				if min(x) < -2000 || max(x) > 2000 || min(y) < -2000 || max(y) > 2000
					obj.devlist = [obj.devlist i];
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
		
		
	end%-------------------------END PUBLIC METHODS--------------------------------%
	
	%=======================================================================
	methods (Access = private) %------------------PRIVATE METHODS
	%=======================================================================
		
		
		
	end
	
end

