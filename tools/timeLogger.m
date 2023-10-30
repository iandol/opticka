classdef timeLogger < optickaCore
	%TIMELOGGER Simple class used to store the timing data from an experiment
	%  timeLogger stores timing data for a taskrun and optionally graphs the
	%  result.
	
	properties
		timer			= @GetSecs
		verbose			= true
		stimStateNames	= {'stimulus','onestep','twostep'}
		t				= struct('vbl',[],'show',[],'flip',[],...
							'miss',[],'stimTime',[])
		screenLog		= struct()
		missvbls		= 0
		tick			= 0
		lastvbl			= 0
		tickInfo		= 0
		startTime		= 0
		startRun		= 0
	end

	properties (Hidden)
		vbl				= 0
		show			= 0
		flip			= 0
		miss			= 0
		stimTime		= 0
	end
	
	properties (SetAccess = private, GetAccess = public)
		messages struct	= struct('tick',[],'vbl',[],'message',{})
		missImportant
		nMissed
	end
	
	properties (SetAccess = private, GetAccess = private)
		%> allowed properties passed to object upon construction
		allowedProperties = {'stimStateNames','timer','verbose'}
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
		%> @brief Preallocate array: a bit more efficient
		%>
		%> @param varargin
		%> @return
		% ===================================================================
		function preAllocate(me,n)
			if isprop(me,'t')
				me.t.vbl = zeros(1,n);
				me.t.show = me.vbl;
				me.t.flip = me.vbl;
				me.t.miss = me.vbl;
				me.t.stimTime = me.vbl;
			else
				me.vbl = zeros(1,n);
				me.show = me.vbl;
				me.flip = me.vbl;
				me.miss = me.vbl;
				me.stimTime = me.vbl;
			end
		end
		
		% ===================================================================
		%> @brief if we preallocated, remove empty 0 values
		%>
		%> @param
		%> @return
		% ===================================================================
		function removeEmptyValues(me)
			if isprop(me,'t')
				if isempty(me.t.vbl);return;end
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
		end
		
		% ===================================================================
		%> @brief print Log of the frame timings
		% ===================================================================
		function plot(me)
			printRunLog(me);
			if ~isempty(me.messages); plotMessages(me);end
		end
		
		% ===================================================================
		%> @brief 
		% ===================================================================
		function logStim(me, name, tick)
			if matches(name, me.stimStateNames)
				me.t.stimTime(tick) = 1;
			else
				me.t.stimTime(tick) = 0;
			end
		end
		
		% ===================================================================
		%> @brief 
		% ===================================================================
		function addMessage(me, tick, vbl, message)
			if ~exist('message','var'); return; end
			if ~exist('tick','var') || isempty(tick); tick = me.tick; end
			if (~exist('vbl','var') || isempty(vbl)) && ~isempty(me.lastvbl)
				vbl = me.lastvbl; 
			else
				vbl = GetSecs;
			end
			if isempty(me.messages); N = 1; else; N = length(me.messages)+1; end
			me.messages(N).tick = tick;
			if ~isempty(me.stimTime) && length(me.stimTime)<=tick
				try 
					me.messages(N).stimTime = me.stimTime(tick); 
				catch
					me.messages(N).stimTime = NaN;
				end
			else
				me.messages(N).stimTime = NaN;
			end
			me.messages(N).vbl = vbl;
			me.messages(N).message = message;
		end
		
		% ===================================================================
		%> @brief print Log of the frame timings
		%>
		%> @param
		%> @return
		% ===================================================================
		function printRunLog(me)
			if length(me.t.vbl) <= 5
				disp('No timing data available...')
				return
			end
			
			removeEmptyValues(me)
			
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
			figure('Name',me.name,'NumberTitle','off','Color',[1 1 1],...
				'Position', [10 1 round(ssz(3)/2.5) ssz(4)]);
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
		%> @brief print messages
		%>
		%> @param
		%> @return
		% ===================================================================
		function plotMessages(me)
			if isempty(me.messages);return;end

			msgs = cell(length(me.messages),4);
			for i = 1:length(me.messages)
				msgs{i,1} = me.messages(i).tick;
				msgs{i,2} = me.messages(i).vbl - me.startTime;
				if isfield(me.messages,'stimeTime');msgs{i,3} = me.messages(i).stimTime;end
				msgs{i,4} = me.messages(i).message;
			end
			msgs = cell2table(msgs,'VariableNames',{'Tick','Time','Stimulus State','Message'});

			h = build_gui();
			
			set(h.uitable1,'Data',msgs);

			function h = build_gui()
				fsmall = 12;
				h.figure1 = uifigure( ...
					'Tag', 'msglog', ...
					'Units', 'normalized', ...
					'Position', [0.6 0 0.4 0.5], ...
					'Name', ['Log: ' me.fullName], ...
					'MenuBar', 'none', ...
					'NumberTitle', 'off', ...
					'Color', [0.94 0.94 0.94], ...
					'Resize', 'on');
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
					'ColumnWidth', {'fit','fit','fit','4x'});
			end
		end
		
		% ===================================================================
		%> @brief calculate genuine missed stim frames
		%>
		%> @param
		%> @return
		% ===================================================================
		function calculateMisses(me,miss,stimTime)
			removeEmptyValues(me)
			if nargin < 3; stimTime = me.t.stimTime;end
			if nargin < 2; miss = me.t.miss;end
			me.missImportant = miss;
			me.missImportant(me.missImportant <= 0) = -inf;
			me.missImportant(stimTime < 1) = -inf;
			me.missImportant(1) = -inf; %ignore first frame
			me.nMissed = length(find(me.missImportant > 0));
		end
	end %---END PUBLIC METHODS---%
	
	%=======================================================================
	methods ( Access = private ) %-------PRIVATE METHODS-----%
	%=======================================================================
		
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function [avg,err] = stderr(me,data)
			avg=mean(data);
			err=std(data);
			err=sqrt(err.^2/length(data));
		end
		
	end

	%=======================================================================
	methods ( Static ) %-------STATIC METHODS-----%
	%=======================================================================
		
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================

		function me = loadobj(s)
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

