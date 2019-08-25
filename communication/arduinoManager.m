classdef arduinoManager < optickaCore
	%ARDUINOMANAGER Connects and manages arduino communication, uses matlab
	%hardware package
	properties
		port				= ''
		board				= ''
		silentMode		= false %this allows us to be called even if no arduino is attached
		verbose			= true
		openGUI			= true
		mode				= 'original' %original is built-in, otherwise needs matlab hardware package
		rewardPin		= 2
		rewardTime		= 150
		availablePins = {2,3,4,5,6,7,8,9,10,11,12,13}; %UNO board
	end
	properties (SetAccess = private, GetAccess = public)
		ports
		isOpen logical = false
		device = []
		deviceID = ''
	end
	properties (SetAccess = private, GetAccess = private)
		handles = []
		allowedProperties='mode|port|silentMode|verbose'
	end
	methods%------------------PUBLIC METHODS--------------%
		
		%==============CONSTRUCTOR============%
		function me = arduinoManager(varargin)
			if nargin>0
				me.parseArgs(varargin,me.allowedProperties);
			end
			if isempty(me.port)
				me.ports = seriallist;
				if ~isempty(me.ports)
					me.port = char(me.ports(1));
					fprintf('Ports available: %s\n',me.ports);
				else
					fprintf('No Serial Ports are available, going into silemt mode\n');
					me.silentMode = true;
				end
			end
			switch me.mode
				case 'original'
					if ~exist('arduinoLegacy','file')
						me.comment = 'Cannot find arduinoLegacy, check opticka path!';
						warning(me.comment)
						me.silentMode = true;
					end
				otherwise
					if ~exist('arduino','file')
						me.comment = 'You need to Install Arduino Support files!';
						warning(me.comment)
						me.silentMode = true;
					end
			end
		end
		
		%===============OPEN DEVICE================%
		function open(me)
			close(me);
			if me.silentMode==false && isempty(me.device)
				try
					switch me.mode
						case 'original'
							if ~isempty(me.port)
								me.device = arduinoLegacy(me.port);
							else
								error('Please specify the port to use!')
							end
							me.board = 'Generic';
							me.deviceID = me.port;
							me.availablePins = {2,3,4,5,6,7,8,9,10,11,12,13}; %UNO board
							for i = me.availablePins{1} : me.availablePins{end}
								me.device.pinMode(i,'output');
								me.device.digitalWrite(i,0);
							end
							me.isOpen = true;
						otherwise
							if ~isempty(me.port)
								me.device = arduino(me.port);
							else
								me.device = arduino;
							end
							me.port = me.device.Port;
							me.board = me.device.Board;
							me.deviceID = me.device.Port;
							me.availablePins = me.device.AvailablePins;
							for i = 2:13
								configurePin(me.device,['D' num2str(i)],'unset')
								writeDigitalPin(me.device,['D' num2str(i)],0);
							end
							me.isOpen = true;
					end
					if me.openGUI; GUI(me); end
					me.silentMode = false;
				catch ME
					me.silentMode = true; me.isOpen = false;
					fprintf('\n\nCouldn''t open Arduino, try a valid name?')
					getReport(ME)
				end
			elseif ~isempty(me.device)
				fprintf('--->>> arduinoManager: arduino appears open already...\n');
			end
		end
		
		%===============SEND TTL (legacy)================%
		function sendTTL(me, line, time)
			timedTTL(me, line, time)
		end
		
		%===============TIMED TTL================%
		function timedTTL(me, line, time)
			if me.silentMode==false
				if ~exist('line','var') || isempty(line); line = me.rewardPin; end
				if ~exist('time','var') || isempty(time); time = me.rewardTime; end
				if ~strcmp(me.mode,'original')
					time = time - 30; %there is an arduino 30ms delay
				end
				if time < 0; time = 0; end
				switch me.mode
					case 'original'
						digitalWrite(me.device, line, 1);
						WaitSecs(time/1e3);
						digitalWrite(me.device, line, 0);
					otherwise
						writeDigitalPin(me.device,['D' num2str(line)],1);
						WaitSecs(time/1e3);
						writeDigitalPin(me.device,['D' num2str(line)],0);
				end	
				if me.verbose;fprintf('===>>> REWARD GIVEN: pin %i for %i ms\n',line,time);end
			else
				if me.verbose;fprintf('===>>> REWARD GIVEN: Silent Mode\n');end
			end
		end
		
		%===============TIMED DOUBLE TTL================%
		function timedDoubleTTL(me, line, time)
			if me.silentMode==false
				if ~exist('line','var') || isempty(line); line = me.rewardPin; end
				if ~exist('time','var') || isempty(time); time = me.rewardTime; end
				if ~strcmp(me.mode,'original')
					time = time - 30; %there is an arduino 30ms delay
				end
				if time < 0; time = 0;end
				switch me.mode
					case 'original'
						digitalWrite(me.device, line, 1);
						WaitSecs(0.01);
						digitalWrite(me.device, line, 0);
						WaitSecs(time/1e3);
						digitalWrite(me.device, line, 1);
						WaitSecs(0.01);
						digitalWrite(me.device, line, 0);
					otherwise
						writeDigitalPin(me.device,['D' num2str(line)],1);
						WaitSecs(0.03);
						writeDigitalPin(me.device,['D' num2str(line)],0);
						WaitSecs(time/1e3);
						writeDigitalPin(me.device,['D' num2str(line)],1);
						WaitSecs(0.03);
						writeDigitalPin(me.device,['D' num2str(line)],0);
				end
				
				if me.verbose;fprintf('===>>> REWARD GIVEN: pin %i for %i ms\n',line,time);end
			else
				if me.verbose;fprintf('===>>> REWARD GIVEN: Silent Mode\n');end
			end
		end
		
		%===============TEST TTL================%
		function test(me,line)
			if me.silentMode==false && ~isempty(me.device)
				if ~exist('line','var') || isempty(line); line = 2; end
				switch me.mode
					case 'original'
						digitalWrite(me.device, line, 0);
						for ii = 1:20
							digitalWrite(me.device, line, mod(ii,2));
						end
					otherwise
						writeDigitalPin(me.device,['D' num2str(line)],0);
						for ii = 1:20
							writeDigitalPin(me.device,['D' num2str(line)],mod(ii,2));
						end
				end
			end
		end
		
		%===============Manual Reward GUI================%
		function GUI(me)
			if ~isempty(me.handles) && isfield(me.handles,'parent') && ishandle(me.handles.parent)
				disp('--->>> arduinoManager: GUI already open...\n')
				return;
			end
			handles.parent = figure('Tag','aFig',...
				'Name', 'arduinoManager GUI', ...
				'MenuBar', 'none', ...
				'Position',[0 0 200 140],...
				'NumberTitle', 'off');
			
			bgcolor = [0.91 0.91 0.91];
			bgcoloredit = [0.95 0.95 0.95];
			if ismac
				SansFont = 'avenir next';
				MonoFont = 'menlo';
			elseif ispc
				SansFont = 'calibri';
				MonoFont = 'consolas';
			else %linux
				SansFont = 'Liberation Sans'; %get(0,'defaultAxesFontName');
				MonoFont = 'Fira Code';
			end
			
			handles.value = uicontrol('Style','edit',...
				'Parent',handles.parent,...
				'Tag','RewardValue',...
				'String',200,...
				'FontName',MonoFont,...
				'FontSize', 12,...
				'Position',[5 110 195 20],...
				'BackgroundColor',bgcoloredit);
			
			handles.menu = uicontrol('Style','popupmenu',...
				'Parent',handles.parent,...
				'Tag','TTLMethod',...
				'String',{'Single TTL','Double TTL'},...
				'Value',2,...
				'Position',[5 80 195 20],...
				'BackgroundColor',bgcolor);
			
			handles.readButton = uicontrol('Style','pushbutton',...
				'Parent',handles.parent,...
				'Tag','goButtosn',...
				'Callback',@doReward,...
				'FontName',SansFont,...
				'ForegroundColor',[1 0 0],...
				'FontSize',20,...
				'Position',[5 5 195 60],...
				'String','REWARD!');
			
			me.handles = handles;
			
			function doReward(varargin)
				if me.silentMode;disp('Not open!');return;end
				val = str2num(get(me.handles.value,'String'));
				method = get(me.handles.menu,'Value');
				if method == 1
					try
						me.timedTTL(me.rewardPin,val);
					end
				elseif method == 2
					try
						me.timedDoubleTTL(me.rewardPin,val);
					end
				end
			end
		end
		
		%===============CLOSE PORT================%
		function close(me)
			try;close(me.handles.parent);me.handles=[];end
			me.device = [];
			me.deviceID = '';
			me.availablePins = '';
			me.isOpen = false;
			me.silentMode = false;
		end
		
	end
	
	methods ( Access = private ) %----------PRIVATE METHODS---------%
		
		%===========Delete Method==========%
		function delete(me)
			fprintf('arduinoManager Delete method will automagically close connection if open...\n');
			me.close;
		end
		
	end
	
end