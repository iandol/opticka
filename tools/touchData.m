classdef touchData < optickaCore

	properties
		subject
		data struct
		info struct
		verbose = true
	end

	properties (GetAccess = public, SetAccess = protected)
		nData
		nSessions
	end

	properties (Access = protected)
		dataTemplate = struct('date',[],'startTime',NaN,'comment',[],'phase',[],'time',[],...
			'trials',[],'value',[],'result',[],'rt',[],'stimulus',[],'timeOut',[],'random',0,'rewards',0,...
			'info',{},'xAll',{},'yAll',{},'tAll',{},'xLast',[],'yLast',[]);
		allowedProperties = {'subject','verbose'}
	end

	methods

		function me = touchData(varargin)
			args = optickaCore.addDefaults(varargin,struct('name','touchData'));
			me = me@optickaCore(args); %superclass constructor
			me.parseArgs(args, me.allowedProperties);

			if isempty(me.data)
				me.data = me.dataTemplate;
				me.nData = 0;
			end

		end

		function update(me,result,phase,trials,rt,stimulus,info,xAll,yAll,tAll,value)
			if ~exist('result','var'); return; end
			if me.nData == 0
				if isempty(me.data); me.data = me.dataTemplate; end
				me.data(1).date = clock;
				me.data(1).time = GetSecs;
				n = 1;
			else
				n = me.nData + 1;
			end
			me.data.time(n) = GetSecs;
			me.data.result(n) = result;
			if exist('phase','var') && ~isempty(phase); me.data.phase(n) = phase; end
			if exist('trials','var') && ~isempty(trials); me.data.trials(n) = trials; end
			if exist('rt','var') && ~isempty(rt); me.data.rt(n) = rt; end
			if exist('stimulus','var') && ~isempty(stimulus); me.data.stimulus(n) = stimulus; end
			if exist('info','var') && ~isempty(info); me.data.info{n} = info; end
			if exist('xAll','var') && ~isempty(xAll); me.data.xAll{n} = xAll; end
			if exist('yAll','var') && ~isempty(yAll); me.data.yAll{n} = yAll; end
			if exist('yAll','var') && ~isempty(tAll); me.data.tAll{n} = tAll; end
			if exist('value','var') && ~isempty(value); me.data.value(n) = value; end
			me.nData = n;
		end

		function plotData(me)
			touchData.plot(me);
		end

	end

	methods (Static = true)
		function plot(in)
			if ~exist('in','var'); return; end
			if isfield(in,'className') && ~strcmp(in.className, 'touchData'); return; end
			if isempty(in.data.trials); disp('---> No trials in this datafile!'); return; end
			if isfield(in.data,'startTime')
				time = in.data.time - in.data.startTime;
			else
				time = in.data.time - in.data.time(1);
			end
			[~,f,e] = fileparts(in.name);
			tit = [f e];
			f = figure("Name",tit);
			tl = tiledlayout(f);
			nexttile;
			plot(in.data.trials,in.data.result,'ko-','MarkerFaceColor',[0 0 0]);
			ylim([-0.2 1.2]);
			yticks([0 1]);
			yticklabels({'incorrect','correct'});
			ytickangle(45);
			xlim([0 max(in.data.trials)]);
			title("Performance");
			xlabel('Trial Number');
			ylabel('Response');
			box on; grid on;
			nexttile;
			plot(in.data.trials,in.data.rt,'ko-','MarkerFaceColor',[0 0 0]);
			xlim([0 max(in.data.trials)]);
			xlabel('Trial Number');
			ylabel('Reaction Time (s)');
			title('Reaction Time');
			box on; grid on;

			plotPhase = false;
			if length(unique(in.data.phase)) > 1
				plotPhase = true;
				nexttile;
				plot(time,in.data.phase,'ko-','MarkerFaceColor',[0 0 0]);
				ylim([0 max(in.data.phase)+1]);
				xlim([0 max(time)]);
				xlabel('Task Time (s)');
				ylabel('Task Phase / Step');
				box on; grid on;
			end

			if ~isempty(in.data.xAll) && iscell(in.data.xAll)
				if plotPhase
					nexttile;
				else
					nexttile(3,[1 2]);
				end
				hold on
				for ii = 1:length(in.data.xAll)
					x = in.data.xAll{ii};
					y = in.data.yAll{ii};
					z = in.data.tAll{ii};
					if ~isempty(x) && ~isempty(y) && ~isempty(z)
						scatter3(x,y,z,'filled');
					end
				end
				xlabel('X Position (deg)');
				ylabel('Y Position (deg)');
				zlabel('Time (s)');
				view(30,30)
				title('Touch Positions (color = trial)');
				box on; grid on; axis equal
				hold off
			end
		end
	end

end
