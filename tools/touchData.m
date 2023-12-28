classdef touchData < optickaCore

	properties
		subject
		data
	end

	properties (GetAccess = public, SetAccess = protected)
		nData
		nSessions
	end

	properties (Access = protected)
		dataTemplate = struct('date',[],'startTime',NaN,'comment',[],'phase',[],'time',[],...
			'trials',[],'result',[],'rt',[],'stimulus',[],'timeOut',[],'random',0,'rewards',0)
		allowedProperties = {'subject'}
	end

	methods

		function me = touchData(varargin)
			args = optickaCore.addDefaults(varargin,struct('name','touchManager'));
			me = me@optickaCore(args); %superclass constructor
			me.parseArgs(args, me.allowedProperties);

			if isempty(me.data)
				me.data = me.dataTemplate;
				me.nData = 0;
			end

		end

		function update(me,result,phase,trials,rt,stimulus)
			if ~exist('result','var'); return; end
			if me.nData == 0
				if isempty(me.data); me.data = me.dataTemplate; end
				me.data(1).date = clock;
				n = 1;
			else
				n = me.nData + 1;
			end
			me.data.time(n) = GetSecs;
			me.data.result(n) = result;
			if exist('phase','var'); me.data.phase(n) = phase; end
			if exist('phase','var'); me.data.phase(n) = phase; end
			if exist('trials','var'); me.data.trials(n) = trials; end
			if exist('rt','var'); me.data.rt(n) = rt; end
			if exist('stimulus','var'); me.data.stimulus(n) = stimulus; end
			me.nData = n;
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
			f = figure;
			subplot(3,1,1);
			plot(in.data.trials,in.data.result,'ko-','MarkerFaceColor',[0 0 0]);
			ylim([-0.2 1.2]);
			xlim([0 max(in.data.trials)]);
			title(in.fullName);
			xlabel('Trial Number');
			ylabel('Correct (1) / Incorrect (0)');
			subplot(3,1,2);
			plot(in.data.trials,in.data.rt,'ko-','MarkerFaceColor',[0 0 0]);
			xlim([0 max(in.data.trials)]);
			xlabel('Trial Number');
			ylabel('Reaction Time (s)');
			title('Reaction Time');
			subplot(3,1,3);
			plot(time,in.data.phase,'ko-','MarkerFaceColor',[0 0 0]);
			ylim([0 max(in.data.phase)+1]);
			xlim([0 max(time)]);
			xlabel('Task Time (s)');
			ylabel('Task Phase / Step');
		end
	end

end
