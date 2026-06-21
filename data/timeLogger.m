classdef timeLogger < optickaCore
	%> @brief Log frame timing and event annotations for a task run.
	%>
	%> The class stores per-frame timing values such as VBL, draw, flip, miss,
	%> and stimulus state, together with timestamped messages that can include
	%> time type metadata and optional HED annotations. The logged data can be
	%> normalised, plotted, and exported as a table for later inspection.
	%> We use pre-allocated arrays as this is much faster...
	
	properties
		% which timer to use, GetSecs from PTB is preferred
		timer function_handle	= @GetSecs
		% which experiment state names are considered stimulus presentation
		stimStateNames cell		= {'stimulus','onestep','twostep'}
		% for logging PTB Flip values
		t struct				= struct('vbl', [], 'show', [], 'flip',[],...
								'miss', [], 'stimTime', [])
		% how big an array to preallocate for PTB t arrays
		preallocateTimes double	= 1e5;
		% how big an array to preallocate for addMessage() messages
		preallocateMessages	double = 1e4;
		% general PTB screen setup times
		screenLog struct		= struct()
		% the global start time for all subsequent logging
		startTime double		= NaN
		% the last vbl time from a screen flip
		lastvbl double			= NaN
		% accumulated missed flips
		missvbls double			= 0
		% the current tick from the experiment, this is usually the index
		% into e.g. which frame-time to add: timeLogger.t.vbl(timeLogger.tick)=xxx
		tick double				= NaN
		%
		tickInfo double			= NaN
		startRun double			= NaN
		verbose					= true

	end

	properties (Hidden)
		vbl						= NaN
		show					= NaN
		flip					= NaN
		miss					= NaN
		stimTime				= NaN
	end

	properties (SetAccess = private, GetAccess = public)
		% messages stored via addMessage()
		messages struct			= struct('time', [], 'exitTime', [], 'tick', [],...
								'stimTime', [], 'message', "", 'type', "", 'HED', "")
		% number of actual messages
		messageN double			= 0
		% did we preallocate?
		isAllocated				= false
		missImportant
		nMissed
	end
	
	properties (SetAccess = private, GetAccess = private)
		%> allowed properties passed to object upon construction
		allowedProperties = {'stimStateNames', 'timer', 'verbose', 'preallocateTimes', 'preallocateMessages'}
	end
	
	%=======================================================================
	methods %------------------PUBLIC METHODS
	%=======================================================================

		% ===================================================================
		%> @brief Constructor
		%>
		%> @param varargin
		%> @return
		% ===================================================================
		function me=timeLogger(varargin)
			args = optickaCore.addDefaults(varargin,struct('name','timeLog'));
			me = me@optickaCore(args); %superclass constructor
			me.parseArgs(args,me.allowedProperties);
			if ~exist('GetSecs','file')
				me.timer = @now;
			end
			me.screenLog.construct = me.timer();
		end
		
		% ===================================================================
		%> @brief Preallocate timing and message storage.
		%>
		%> This avoids repeated array growth during a run and resets the message
		%> write index to the start of the buffers.
		%>
		%> @param n Number of frame timing entries to reserve.
		%> @param m Number of message entries to reserve.
		% ===================================================================
		function preAllocate(me,n,m)
			arguments
				me
				n (1,1) double {mustBeInteger,mustBePositive} = me.preallocateTimes
				m (1,1) double {mustBeInteger,mustBePositive} = me.preallocateMessages
			end
			if isprop(me,'t')
				me.t.vbl = zeros(1,n);
				me.t.show = me.t.vbl;
				me.t.flip = me.t.vbl;
				me.t.miss = me.t.vbl;
				me.t.stimTime = me.t.vbl;
			else
				me.vbl = zeros(1,n);
				me.show = me.vbl;
				me.flip = me.vbl;
				me.miss = me.vbl;
				me.stimTime = me.vbl;
			end
			try 
				me.messages(1).time = nan(1,m);
				me.messages.exitTime = me.messages.time;
				me.messages.tick = me.messages.time;
				me.messages.stimTime = me.messages.time;
				me.messages.message = repmat("",1,m);
				me.messages.type = me.messages.message;
				me.messages.HED = me.messages.message;
			end
			me.messageN = 0;
			me.isAllocated = true;
		end
		
		% ===================================================================
		%> @brief Plot timing summaries and, when present, the message log.
		% ===================================================================
		function plot(me)
			if ~desktop("inuse"); fprintf("No desktop, skiiping plot...\n"); return; end
			printRunLog(me);
			if ~isempty(me.messages); plotMessages(me);end
		end
		
		% ===================================================================
		%> @brief Mark whether the stimulus was active for a frame tick.
		%>
		%> @param name Stimulus state name for the current frame.
		%> @param tick Frame index to update.
		% ===================================================================
		function logStim(me, name, tick)
			arguments
				me
				name {mustBeTextScalar}
				tick (1,1) double {mustBeInteger,mustBeNonnegative}
			end
			if matches(name, me.stimStateNames)
				me.t.stimTime(tick) = 1;
			else
				me.t.stimTime(tick) = 0;
			end
		end
		
		% ===================================================================
		%> @brief Append a timestamped message to the event log.
		%>
		%> Empty timing inputs fall back to the most recent VBL time or the
		%> logger timer. HED payloads are normalised to a stored string path.
		%>
		%> @param tick Frame index associated with the message.
		%> @param startTime Timestamp of message onset.
		%> @param exitTime Timestamp of message completion.
		%> @param message Text message to store.
		%> @param timeType Label describing how the timestamp was generated.
		%> @param HED Optional HED tag or HED tag object.
		% ===================================================================
		function addMessage(me, tick, startTime, exitTime, message, timeType, HED)
			arguments
				me
				tick double			= NaN
				startTime double	= NaN
				exitTime double		= NaN
				message string		= missing
				timeType string		= missing
				HED string			= "Experimental-note"
			end

			if isempty(message) || any(ismissing(message)) || strlength(message) == 0; return; end
			message = replace(message(1), ["\t" "\n"], " "); %remove newlines from message text

			if isempty(tick) || isnan(tick); tick = me.tick; end

			if isempty(startTime) || isnan(startTime)
				if ~isempty(me.lastvbl) && me.lastvbl > 0
					startTime = me.lastvbl;
					timeType = "lastvbl";
				else
					startTime = me.timer();
					timeType = "getsecs";
				end
			end

			if isempty(exitTime); exitTime = NaN; end
			
			N = me.messageN + 1; me.messageN = N;
			me.messages(1).time(N) = startTime;
			me.messages(1).exitTime(N) = exitTime;
			me.messages(1).tick(N) = tick;
			if ~isnan(me.stimTime) && ~isempty(me.stimTime) && length(me.stimTime) <= tick
				me.messages(1).stimTime(N) = me.stimTime(tick); 
			else
				me.messages(1).stimTime(N) = NaN;
			end
			me.messages(1).message(N) = message;
			me.messages(1).type(N) = lower(timeType);
			me.messages(1).HED(N) = HED;
		end
		
		% ===================================================================
		%> @brief Plot raw timing, frame deltas, timing offsets, and misses.
		%>
		%> @return h Figure handle or empty when no timing data is available.
		% ===================================================================
		function h = printRunLog(me)
			if ~desktop("inuse"); fprintf("No desktop, skiiping plot...\n"); return; end
			h = [];
			removeEmptyValues(me)
			if isempty(me.t.vbl) || max(me.t.vbl) == 0 || length(me.t.vbl) <= 5
				disp('timeLogger: No VBL timing data available...'); return
			end
			if isprop(me,'t')
				vbl=me.t.vbl.*1e3; %#ok<*PROP>
				show=me.t.show.*1e3;
				flip=me.t.flip.*1e3; 
				miss=me.t.miss;
				stimTime=me.t.stimTime;
			else
				vbl=me.vbl.*1e3; %#ok<*PROP>
				show=me.show.*1e3;
				flip=me.flip.*1e3; 
				miss=me.miss;
				stimTime=me.stimTime;
			end
			l = length(vbl);
			vbl = vbl(1:l);
			show=show(1:l);
			flip=flip(1:l);
			stimTime=stimTime(1:l);
			x=1:l;
			
			calculateMisses(me,miss,stimTime)
			
			ssz = get(0,'ScreenSize');
			h = figure('Name',append('Opticka: ', me.name),'NumberTitle','off','tag','opticka',...
				'Position', [0 0 round(ssz(3)/2.5) ssz(4)]);
			if ~isMATLABReleaseOlderThan("R2025a"); theme(h,'light'); end
			tl = tiledlayout(4,1,'TileSpacing','compact','Padding','compact');

			ax1 = nexttile;
			hold on
			plot(x,vbl-vbl(1),'r-','MarkerFaceColor',[1 0 0]);
			plot(x,show-show(1),'b--');
			plot(x,miss-miss(1),'g-.');
			plot(x,(stimTime-min(stimTime))*mean(vbl-vbl(1)),'k-');
			xlim([1 length(x)]);
			legend('VBL','Show','Flip','STIMULUS');
			title('Raw Frame times')
			xlabel('Frame number');
			ylabel('Time (milliseconds)');
			box on; grid on; grid minor;

			ax2 = nexttile;
			hold on
			vv=diff(vbl);
			vv(vv>100)=100;
			plot(vv,'ro','MarkerFaceColor',[1 0 0])
			ss=diff(show);
			ss(ss>100)=100;
			plot(ss,'b--')
			ff = diff(flip);
			ff(ff>100)=100;
			plot(ff,'g-.')
			plot(stimTime(2:end)*100,'k-')
			hold off
			xlim([1 length(x)]);
			ylim([0 105])
			legend('VBL','Show','Flip','STIMULUS')
			[m,e]=me.stderr(diff(vbl));
			t=sprintf('DIFF: VBL mean=%.3f ± %.3f s.e.', m, e);
			[m,e]=me.stderr(diff(show));
			t=[t sprintf(' | Show mean=%.3f ± %.3f', m, e)];
			[m,e]=me.stderr(diff(flip));
			t=[t sprintf(' | Flip mean=%.3f ± %.3f', m, e)];
			title(t)
			xlabel('Frame number (difference between frames)');
			ylabel('Time (milliseconds)');
			box on; grid on; grid minor;
			
			ax3 = nexttile;
			hold on
			plot(x,show-vbl,'r')
			plot(x,show-flip,'g')
			plot(x,vbl-flip,'b-.')
			plot(x,stimTime-0.5,'k')
			legend('Show-VBL','Show-Flip','VBL-Flip','STIMULUS');
			hold off
			xlim([1 length(x)]);
			[m,e]=me.stderr(show-vbl);
			t=sprintf('Show-VBL=%.3f ± %.3f', m, e);
			[m,e]=me.stderr(show-flip);
			t=[t sprintf(' | Show-Flip=%.3f ± %.3f', m, e)];
			[m,e]=me.stderr(vbl-flip);
			t=[t sprintf(' | VBL-Flip=%.3f ± %.3f', m, e)];
			title(t);
			xlabel('Frame number');
			ylabel('Time (milliseconds)');
			box on; grid on; grid minor;
			
			ax4 = nexttile;
			hold on
			miss(miss > 0.05) = 0.05;
			stimTime = (stimTime / max(stimTime)) * max(miss);
			plot(x,miss,'g-');
			plot(x,me.missImportant,'ro','MarkerFaceColor',[1 0 0]);
			plot(x,stimTime,'k','linewidth',1);
			hold off
			xlim([1 length(x)]);
			ylim([min(miss) max([max(stimTime) max(miss)])]);
			title(['Missed frames = ' num2str(me.nMissed) ' (RED > 0 means missed frame)']);
			xlabel('Frame number');
			ylabel('Miss Value');
			box on; grid on; grid minor;

			linkaxes([ax1 ax2 ax3 ax4],'x');
			
			clear vbl show flip idx miss stimTime
		end

		% ===================================================================
		%> @brief Show the message log in a UI table.
		%>
		%> @return h Struct of UI handles, or empty when there are no messages.
		% ===================================================================
		function h = plotMessages(me)
			if ~desktop("inuse"); fprintf("No desktop, skiiping plot...\n"); return; end
			msgs = messageTable(me);
			if isempty(msgs); h = []; return; end

			h = build_gui();
			
			set(h.uitable1,'Data',msgs);

			function h = build_gui()
				fsmall = 12;
				h.figure1 = uifigure( ...
					'Tag', 'msglog', ...
					'Units', 'normalized', ...
					'Position', [0 0 0.5 0.5], ...
					'Name', "Opticka Log: " + me.fullName, ...
					'MenuBar', 'none', ...
					'NumberTitle', 'off', ...
					'Color', [0.94 0.94 0.94], ...
					'Resize', 'on');
				if ~isMATLABReleaseOlderThan("R2025a"); theme(h.figure1,'light'); end
				h.uitable1 = uitable( ...
					'Parent', h.figure1, ...
					'Tag', 'msglogtable', ...
					'Units', 'normalized', ...
					'Position', [0 0 1 1], ...
					'FontName', me.monoFont, ...
					'FontSize', fsmall, ...
					'RowName', 'numbered',...
					'BackgroundColor', [1 1 1;0.95 0.95 0.95], ...
					'RowStriping','on', ...
					'ColumnEditable', [], ...
					'ColumnWidth', {'fit','fit','fit','fit','fit','fit','3x','fit','3x'});
			end
		end

		% ===================================================================
		%> @brief Export the message log as a sorted table.
		%>
		%> The returned table contains onset, exit, relative time, duration,
		%> frame tick, stimulus state, free text message, time type, and HED tag.
		%>
		%> @return tbl Message log as a MATLAB table.
		% ===================================================================
		function tbl = messageTable(me)
			removeEmptyValues(me);
			tbl = [];
			if isempty(me.messages); return; end
			if isfield(me.messages,'type'); addType=true; else; addType=false; end
			msgs = cell(length(me.messages.time)+1,9);
			msgs{1,1} = toDateTime(me.startTime); msgs{1,2} = NaT; msgs{1,3} = 0;
			msgs{1,4} = NaT; msgs{1,5} = NaN; msgs{1,6} = NaN; msgs{1,7} = 'Start Time'; 
			msgs{1,8} = 'getsecs';
			msgs{1,9} = "Time-value";
			for i = 1:length(me.messages.time)
				msgs{i+1,1} = toDateTime(me.messages.time(i));
				if isfield(me.messages,'exitTime'); msgs{i+1,2} = toDateTime(me.messages.exitTime(i)); end
				msgs{i+1,3} = me.messages.time(i) - me.startTime;
				if ~isfield(me.messages,'exitTime') || isempty(me.messages.exitTime(i)) || ismissing(me.messages.exitTime(i))
					msgs{i+1,4} = NaT;
				else
					msgs{i+1,4} = seconds(msgs{i+1,2} - msgs{i+1,1});
				end
				msgs{i+1,5} = me.messages.tick(i);
				if isfield(me.messages,'stimTime'); msgs{i+1,6} = me.messages.stimTime(i); end
				if isfield(me.messages,'message');  msgs{i+1,7} = me.messages.message(i);  end
				if addType && isfield(me.messages,'type') && length(me.messages.type) >= i
					msgs{i+1,8} = me.messages.type(i);
				else
					msgs{i+1,8} = 'undefined';
				end
				if isfield(me.messages,'HED') && length(me.messages.HED) >= i
					msgs{i+1,9} = me.messages.HED(i);
				else
					msgs{i+1,9} = "";
				end
			end
			tbl = cell2table(msgs,'VariableNames',{'Onset','Exit','Accumulated Time','Duration','Tick','StimulusOn','Message','TimeType','HED'});
			tblt = table2timetable(tbl);
			tblt = sortrows(tblt);
			tbl = timetable2table(tblt);
			function out = toDateTime(posixT)
				if isempty(posixT); out = []; return; end
				out = datetime(posixT,'ConvertFrom','posixtime','TimeZone','local','Format','yyyy-MM-dd HH:mm:ss:SSSS');
			end
		end

	end %---END PUBLIC METHODS---%

	%=======================================================================
	methods ( Hidden = true ) %-------HIDDEN METHODS-----%
	%=======================================================================
		
		% ===================================================================
		%> @brief Count missed frames that occurred during stimulus display.
		%>
		%> @param miss Frame miss vector.
		%> @param stimTime Stimulus-on mask for each frame.
		% ===================================================================
		function calculateMisses(me,miss,stimTime)
			arguments
				me
				miss double = me.t.miss
				stimTime double = me.t.stimTime
			end
			removeEmptyValues(me)
			me.missImportant = miss;
			me.missImportant(me.missImportant <= 0) = -inf;
			me.missImportant(stimTime < 1) = -inf;
			me.missImportant(1) = -inf; %ignore first frame
			me.nMissed = length(find(me.missImportant > 0));
		end

		% ===================================================================
		%> @brief Trim unused preallocated values and normalise old log formats.
		%>
		%> This method collapses legacy message layouts into the current schema,
		%> removes missing entries, and ensures optional fields exist.
		% ===================================================================
		function removeEmptyValues(me)
			if isprop(me,'t')
				if me.tick > 1
					try
						me.t.vbl = me.t.vbl(1:me.tick-1);
						me.t.show = me.t.show(1:me.tick-1);
						me.t.flip = me.t.flip(1:me.tick-1);
						me.t.miss = me.t.miss(1:me.tick-1);
						me.t.stimTime = me.t.stimTime(1:me.tick-1);
					end
				end
				idx=min([length(me.t.vbl) length(me.t.flip) length(me.t.show) length(me.t.stimTime)]);
				try %#ok<*TRYNC> 
					me.t.vbl=me.t.vbl(1:idx);
					me.t.show=me.t.show(1:idx);
					me.t.flip=me.t.flip(1:idx);
					me.t.miss=me.t.miss(1:idx);
					me.t.stimTime=me.t.stimTime(1:idx);
				end
			else
				vbl = me.vbl;
				idx = find(vbl == 0);
				me.vbl(idx) = [];
				me.show(idx) = [];
				me.flip(idx) = [];
				me.miss(idx) = [];
				me.stimTime(idx) = [];
				idx=min([length(me.vbl) length(me.flip) length(me.show) length(me.stimTime)]);
				try %#ok<*TRYNC> 
					me.vbl=me.vbl(1:idx);
					me.show=me.show(1:idx);
					me.flip=me.flip(1:idx);
					me.miss=me.miss(1:idx);
					me.stimTime=me.stimTime(1:idx);
				end
			end
			% messages
			if isstruct(me.messages) && length(me.messages) > 1 % old format was struct(N), convert to struct.item(N)
				m = me.messages;
				mm = struct('time', [], 'exitTime', [], 'tick', [], 'stimTime', [],...
					'message', "", 'type', "", 'HED', "");
				for ii = 1:length(m)
					if isfield(m,'vbl'); mm(1).time(ii) = m(ii).vbl;
					elseif isfield(m,'time'); mm(1).time(ii) = m(ii).time; end
					if isfield(m,'exitTime'); mm.exitTime(ii) = m(ii).exitTime; end
					if isfield(m,'tick'); mm.tick(ii) = m(ii).tick; end
					if isfield(m,'stimTime'); mm.stimTime(ii) = m(ii).stimTime; end
					if isfield(m,'type'); mm.type(ii) = m(ii).type; end
					if isfield(m,'message'); mm.message(ii) = string(strip(m(ii).message)); end
					if isfield(m,'HED'); mm.HED(ii) = m(ii).HED; end
				end
				me.messages = mm;
			end
			if isfield(me.messages,'vbl'); me.messages.time = me.messages.vbl; end
			idx = find(ismissing(me.messages.time));
			try me.messages.time(idx) = []; end
			if ~isfield(me.messages,'exitTime'); me.messages.exitTime = nan(size(me.messages.time)); end
			try me.messages.exitTime(idx) = []; end
			try	me.messages.tick(idx) = []; end
			try	me.messages.stimTime(idx) = []; end
			try	me.messages.message(idx) = []; end
			if ~isfield(me.messages,'type'); me.messages.type = strings(size(me.messages.time)); end
			try	me.messages.type(idx) = []; end
			if ~isfield(me.messages,'HED'); me.messages.HED = strings(size(me.messages.time)); end
			try	me.messages.HED(idx) = []; end
		end
	end

	%=======================================================================
	methods ( Access = private ) %-------PRIVATE METHODS-----%
	%=======================================================================

		% ===================================================================
		%> @brief Compute the mean and standard error of a numeric vector.
		%>
		%> @param data Numeric values to summarise.
		%> @return avg Mean value.
		%> @return err Standard error of the mean.
		% ===================================================================
		function [avg,err] = stderr(~, data)
			arguments
				~
				data double
			end
			avg=mean(data);
			err=std(data);
			err=sqrt(err.^2/length(data));
		end
		
	end

	%=======================================================================
	methods ( Static ) %-------STATIC METHODS-----%
	%=======================================================================

		% ===================================================================
		%> @brief Rebuild a logger object after loading saved state.
		%>
		%> @param s Saved struct or already-instantiated logger.
		%> @return me Reconstructed timeLogger instance.
		% ===================================================================
		function me = loadobj(s)
			arguments
				s
			end
			if isstruct(s)
				newObj = timeLogger;
				newObj.name = s.name;
				if isfield(s,'vbl')
					newObj.t.vbl = s.vbl;
				end
				if isfield(s,'show')
					newObj.t.show = s.show;
				end
				if isfield(s,'flip')
					newObj.t.flip = s.flip;
				end
				if isfield(s,'miss')
					newObj.t.miss = s.miss;
				end
				if isfield(s,'stimTime')
					newObj.t.stimTime = s.stimTime;
				end
				me = newObj;
			else
				me = s;
				if ~isempty(me.vbl) && isempty(me.t.vbl)
					me.t.vbl = me.vbl; me.vbl = [];
					me.t.show = me.show; me.show = [];
					me.t.flip = me.flip; me.flip = [];
					me.t.miss = me.miss; me.miss = [];
					me.t.stimTime = me.stimTime; me.stimTime = [];
				end
			end
		end
	end
	
end

