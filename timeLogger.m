classdef timeLogger < optickaCore
	%TIMELOG Simple class used to store the timing data from an experiment
	%   timeLogger stores timing data for a taskrun and optionally graphs the
	%   result.
	
	properties
		screenLog	= struct()
		runLog		= struct()
		trainingLog	= struct()
		timer		= @GetSecs
		vbl			= 0
		show		= 0
		flip		= 0
		miss		= 0
		stimTime	= 0
		startTime	= 0
		startRun	= 0
		verbose		= true
	end
	
	properties (SetAccess = private, GetAccess = public)
		missImportant
		nMissed
	end
	
	properties (SetAccess = private, GetAccess = private)
		%> allowed properties passed to object upon construction
		allowedProperties = 'timer'
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
		function obj=timeLogger(varargin)
			if nargin == 0; varargin.name = 'timeLog';end
			if nargin>0; obj.parseArgs(varargin,obj.allowedProperties); end
			if isempty(obj.name);obj.name = 'timeLog'; end
			if ~exist('GetSecs','file')
				obj.timer = @now;
			end
			obj.screenLog.construct = obj.timer();
		end
		
		% ===================================================================
		%> @brief print Log of the frame timings
		%>
		%> @param
		%> @return
		% ===================================================================
		function printRunLog(obj)
			if length(obj.vbl) <= 2
				disp('No timing data available...')
				return
			end
			vbl=obj.vbl*1000;
			show=obj.show*1000;
			flip=obj.flip*1000;
			index=min([length(vbl) length(flip) length(show)]);
			vbl=vbl(1:index);
			show=show(1:index);
			flip=flip(1:index);
			miss=obj.miss(1:index);
			stimTime=obj.stimTime(1:index);
			
			calculateMisses(obj)
			
			figure;
			
			p = panel('defer');
			p.pack(3,1)
			
			scnsize = get(0,'ScreenSize');
			pos=get(gcf,'Position');
			
			p(1,1).select();
			hold on
			plot(diff(vbl),'ro:')
			plot(diff(show),'b--')
			plot(diff(flip),'g-.')
			plot(stimTime(2:end)*100,'k-')
			hold off
			legend('VBL','Show','Flip','Stim ON')
			[m,e]=obj.stderr(diff(vbl));
			t=sprintf('VBL mean=%2.2f+-%2.2f s.e.', m, e);
			[m,e]=obj.stderr(diff(show));
			t=[t sprintf(' | Show mean=%2.2f+-%2.2f', m, e)];
			[m,e]=obj.stderr(diff(flip));
			t=[t sprintf(' | Flip mean=%2.2f+-%2.2f', m, e)];
			p(1,1).title(t)
			p(1,1).xlabel('Frame number (difference between frames)');
			p(1,1).ylabel('Time (milliseconds)');
			
			
			p(2,1).select();
			x = 1:length(show);
			hold on
			plot(x,show-vbl,'r')
			plot(x,show-flip,'g')
			plot(x,vbl-flip,'b-.')
			plot(x,stimTime-0.5,'k')
			legend('Show-VBL','Show-Flip','VBL-Flip','Simulus ON/OFF');
			hold off
% 			ax1=gca;
% 			ax2 = axes('Position',get(ax1,'Position'),...
% 				'XAxisLocation','top',...
% 				'YAxisLocation','right',...
% 				'Color','none',...
% 				'XColor','k','YColor','k');
% 			hl2 = line(x,stimTime,'Color','k','Parent',ax2);
% 			set(ax2,'YLim',[-1 2])
% 			set(ax2,'YTick',[-1 0 1 2])
% 			set(ax2,'YTickLabel',{'','BLANK','STIMULUS',''})
% 			linkprop([ax1 ax2],'Position');
			[m,e]=obj.stderr(show-vbl);
			t=sprintf('Show-VBL=%2.2f+-%2.2f', m, e);
			[m,e]=obj.stderr(show-flip);
			t=[t sprintf(' | Show-Flip=%2.2f+-%2.2f', m, e)];
			[m,e]=obj.stderr(vbl-flip);
			t=[t sprintf(' | VBL-Flip=%2.2f+-%2.2f', m, e)];
			p(2,1).title(t);
			p(2,1).xlabel('Frame number');
			p(2,1).ylabel('Time (milliseconds)');
			
			p(3,1).select();
			hold on
			miss(miss > 0.05) = 0.05;
			plot(miss,'k.-');
			plot(obj.missImportant,'ro','MarkerFaceColor',[1 0 0]);
			plot(stimTime/100,'k');
			hold off
			p(3,1).title(['Missed frames = ' num2str(obj.nMissed) ' (RED > 0 means missed frame)']);
			p(3,1).xlabel('Frame number');
			p(3,1).ylabel('Miss Value');
			
			newpos = [pos(1) 1 pos(3) scnsize(4)];
			set(gcf,'Position',newpos);
			p.refresh();
			clear vbl show flip index miss stimTime
		end
		
		% ===================================================================
		%> @brief calculate genuine missed stim frames
		%>
		%> @param
		%> @return
		% ===================================================================
		function calculateMisses(obj)
			index=min([length(obj.vbl) length(obj.flip) length(obj.show)]);
			miss=obj.miss(1:index); %#ok<*PROP>
			stimTime=obj.stimTime(1:index);
			
			obj.missImportant = miss;
			obj.missImportant(obj.missImportant <= 0) = -inf;
			obj.missImportant(stimTime < 1) = -inf;
			obj.missImportant(1:2) = -inf; %ignore first frame
			obj.nMissed = length(find(obj.missImportant > 0));
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
		function [avg,err] = stderr(obj,data)
			avg=mean(data);
			err=std(data);
			err=sqrt(err.^2/length(data));
		end
		
	end
	
end

