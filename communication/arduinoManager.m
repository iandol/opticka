classdef arduinoManager < optickaCore
	%ARDUINOMANAGER Connects and manages arduino communication, by default
	%it connects using arduinoIOPort and the adio.ino arduino sketch, which
	%provide much better performance than MATLAB's hardware package.
	properties
		port char				= ''
		board char				= 'Uno'
		silentMode logical		= false %this allows us to be called even if no arduino is attached
		verbose					= true
		openGUI logical			= true
		mode char				= 'original' %original is built-in, otherwise needs matlab hardware package
		rewardPin double		= 2
		rewardTime double		= 300
		availablePins cell
	end
	properties (SetAccess = private, GetAccess = public)
		ports
		isOpen logical			= false
		device					= []
		deviceID				= ''
	end
	properties (SetAccess = private, GetAccess = private, Transient = true)
		handles					= []
		screen screenManager
	end
	properties (SetAccess = private, GetAccess = private)
		allowedProperties char	= ['availablePins|rewardPin|rewardTime|openGUI|board|mode|'...
			'port|silentMode|verbose']
	end
	
	methods%------------------PUBLIC METHODS--------------%
		
		%==============CONSTRUCTOR============%
		function me = arduinoManager(varargin)
			args = optickaCore.addDefaults(varargin,struct('name','arduino manager'));
			me=me@optickaCore(args); %we call the superclass constructor first
			me.parseArgs(args, me.allowedProperties);
			if isempty(me.port)
				if ~verLessThan('matlab','9.7')	% use the nice serialport list command
					me.ports = serialportlist;
				else
					me.ports = seriallist;
				end
				if ~isempty(me.ports)
					fprintf('--->arduinoManager: Ports available: %s\n',me.ports);
					if isempty(me.port); me.port = char(me.ports{end}); end
				else
					me.comment = 'No Serial Ports are available, going into silent mode';
					fprintf('--->arduinoManager: %s\n',me.comment);
					me.silentMode = true;
				end
			end
			switch me.mode
				case 'original'
					if ~exist('arduinoSerialPort','file')
						me.comment = 'Cannot find arduinoSerialPort, check opticka path!';
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
			if me.isOpen;disp('-->arduinoManager: Already open!');return;end
			close(me); me.ports = seriallist;
			if me.silentMode==false && isempty(me.device)
				try
					switch me.mode
						case 'original'
							if ~isempty(me.port)
								if IsWin && ~isempty(regexp(me.port, '^/dev/', 'once'))
									warning('--->arduinoManager: Linux/macOS port specified but running on windows!')
									me.port = '';
								elseif (IsLinux||IsOSX) && ~isempty(regexp(me.port, '^COM', 'once'))
									warning('--->arduinoManager: Windows port specified but running on Linux/macOS!')
									me.port = '';
								end
								if isempty(me.board)
									me.board = 'Uno';
								end
								switch me.board
									case {'Xiao','xiao'}
										if isempty(me.availablePins)
											me.availablePins = {0,1,2,3,4,5,6,7,8,9,10}; %XIAO board
										end
									otherwise
										if isempty(me.availablePins)
											me.availablePins = {2,3,4,5,6,7,8,9,10,11,12,13}; %UNO board
										end
								end
								endPin = max(cell2mat(me.availablePins));
								startPin = min(cell2mat(me.availablePins));
								me.device = arduinoIOPort(me.port,endPin,startPin);
								if me.device.isDemo
									me.isOpen = false; me.silentMode = true;
									warning('--->arduinoManager: IOport couldn''t open the port, going into silent mode!');
									return
								else
									me.deviceID = me.port;
									me.isOpen = true;setLow(me);
								end
								
							else
								warning('--->arduinoManager: Please specify the port to use, going into silent mode!')
								me.isOpen = false; me.silentMode = true;
								return;
							end
							
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
							me.isOpen = true;setLow(me);
					end
					if me.openGUI; GUI(me); end
					me.silentMode = false;
				catch ME
					me.silentMode = true; me.isOpen = false;
					fprintf('\n\nCouldn''t open Arduino: %s\n',ME.message)
					getReport(ME)
				end
			elseif ~isempty(me.device)
				fprintf('--->>> arduinoManager: arduino appears open already...\n');
			else
				fprintf('--->>> arduinoManager open: silentMode engaged...\n');
				me.isOpen = false;
			end
		end
		
		%===============ANALOG WRITE================%
		function analogWrite(me,line,value)
			if ~me.isOpen || me.silentMode; return; end
			if ~exist('line','var') || isempty(line); line = me.rewardPin; end
			if ~exist('value','var') || isempty(value); value = 255; end
			analogWrite(me.device, line, value);
		end
		
		%===============SEND TTL (legacy)================%
		function sendTTL(me, line, time)
			timedTTL(me, line, time)
		end
		
		%===============TIMED TTL================%
		function timedTTL(me, line, time)
			if ~me.isOpen; return; end
			if me.silentMode == false
				if ~exist('line','var') || isempty(line); line = me.rewardPin; end
				if ~exist('time','var') || isempty(time); time = me.rewardTime; end
				switch me.mode
					case 'original'
						timedTTL(me.device, line, time);
					otherwise
						time = time - 30; %there is an arduino 30ms delay
						if time < 0; time = 0; end
						writeDigitalPin(me.device,['D' num2str(line)],1);
						WaitSecs(time/1e3);
						writeDigitalPin(me.device,['D' num2str(line)],0);
				end
				if me.verbose;fprintf('===>>> REWARD GIVEN: TTL pin %i for %i ms\n',line,time);end
			else
				if me.verbose;fprintf('===>>> REWARD GIVEN: Silent Mode\n');end
			end
		end
		
		function strobeWord(me, value)
			if ~me.isOpen; return; end
			if me.silentMode == false
				strobeWord(me.device, value);
				if me.verbose;fprintf('===>>> STROBE WORD: %i sent to pins 2-8\n',value);end
			end
		end
		
		%===============TIMED DOUBLE TTL================%
		function timedDoubleTTL(me, line, time)
			if me.silentMode == false
				if ~exist('line','var') || isempty(line); line = me.rewardPin; end
				if ~exist('time','var') || isempty(time); time = me.rewardTime; end
				if ~strcmp(me.mode,'original')
					time = time - 30; %there is an arduino 30ms delay
				end
				if time < 0; time = 0;end
				switch me.mode
					case 'original'
						timedTTL(me.device, line, 10);
						WaitSecs('Yieldsecs',time/1e3);
						timedTTL(me.device, line, 10);
					otherwise
						writeDigitalPin(me.device,['D' num2str(line)],1);
						WaitSecs(0.03);
						writeDigitalPin(me.device,['D' num2str(line)],0);
						WaitSecs(time/1e3);
						writeDigitalPin(me.device,['D' num2str(line)],1);
						WaitSecs(0.03);
						writeDigitalPin(me.device,['D' num2str(line)],0);
				end
				
				if me.verbose;fprintf('===>>> REWARD GIVEN: double TTL pin %i for %i ms\n',line,time);end
			else
				if me.verbose;fprintf('===>>> REWARD GIVEN: Silent Mode\n');end
			end
		end
		
		%===============TEST TTL================%
		function test(me,line)
			if me.silentMode || isempty(me.device); return; end
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
		
		%===============Manual Reward GUI================%
		function GUI(me)
			if me.silentMode || ~me.isOpen; return; end
			if ~isempty(me.handles) && isfield(me.handles,'parent') && ishandle(me.handles.parent)
				disp('--->>> arduinoManager: GUI already open...\n')
				return;
			end
			
			bgcolor = [0.91 0.91 0.91];
			bgcoloredit = [0.95 0.95 0.95];
			if ismac
				SansFont = 'Avenir next';
				MonoFont = 'Menlo';
				fontSize = 12;
			elseif ispc
				SansFont = 'Calibri';
				MonoFont = 'Consolas';
				fontSize = 12;
			else %linux
				SansFont = 'Liberation Sans';
				MonoFont = 'Liberation Mono';
				fontSize = 8;
			end
			
			handles.parent = figure('Tag','aFig',...
				'Name', 'arduinoManager GUI', ...
				'MenuBar', 'none', ...
				'Color', bgcolor, ...
				'Position',[0 0 255 150],...
				'NumberTitle', 'off');
			
			handles.value = uicontrol('Style','edit',...
				'Parent',handles.parent,...
				'Tag','RewardValue',...
				'String',300,...
				'FontName',MonoFont,...
				'FontSize', fontSize,...
				'Position',[5 115 95 25],...
				'BackgroundColor',bgcoloredit);
			
			handles.t1 = uicontrol('Style','text',...
				'Parent',handles.parent,...
				'String','Time (ms)',...
				'FontName',SansFont,...
				'FontSize', fontSize-3,...
				'Position',[10 95 90 20],...
				'BackgroundColor',bgcolor);
			
			handles.pin = uicontrol('Style','edit',...
				'Parent',handles.parent,...
				'Tag','RewardPin',...
				'String',2,...
				'FontName',MonoFont,...
				'FontSize', fontSize,...
				'Position',[140 115 95 25],...
				'BackgroundColor',bgcoloredit);
			
			handles.t1 = uicontrol('Style','text',...
				'Parent',handles.parent,...
				'String','Pin',...
				'FontName',SansFont,...
				'FontSize', fontSize-3,...
				'Position',[145 95 90 20],...
				'BackgroundColor',bgcolor);
			
			handles.menu = uicontrol('Style','popupmenu',...
				'Parent',handles.parent,...
				'Tag','TTLMethod',...
				'String',{'Single TTL','Double TTL'},...
				'Value',1,...
				'FontName',SansFont,...
				'FontSize', fontSize,...
				'Position',[5 80 240 20],...
				'BackgroundColor',bgcolor);
			
			handles.readButton = uicontrol('Style','pushbutton',...
				'Parent',handles.parent,...
				'Tag','goButton',...
				'Callback',@doReward,...
				'FontName',SansFont,...
				'ForegroundColor',[1 0 0],...
				'FontSize',fontSize+2,...
				'Position',[5 5 145 55],...
				'String','REWARD!');
			
			handles.loopButton = uicontrol('Style','pushbutton',...
				'Parent',handles.parent,...
				'Tag','l1Button',...
				'Callback',@doLoop,...
				'FontName',SansFont,...
				'ForegroundColor',[1 0.5 0],...
				'FontSize',fontSize+2,...
				'Position',[155 5 40 55],...
				'TooltipString','1-8 to give diff reward sizes, 0 to exit. Use bluetooth keyboard with manual training',...
				'String','L1');
			
			handles.loop2Button = uicontrol('Style','pushbutton',...
				'Parent',handles.parent,...
				'Tag','l2Button',...
				'Callback',@doLoop2,...
				'FontName',SansFont,...
				'ForegroundColor',[1 0.5 0],...
				'FontSize',fontSize+2,...
				'Position',[205 5 40 55],...
				'TooltipString','1-8 to show movie+reward, 0 to exit. Use bluetooth keyboard and manual training',...
				'String','L2');
			
			me.handles = handles;
			
			function doReward(varargin)
				if me.silentMode || ~me.isOpen; disp('Not open!'); return; end
				val = str2num(get(me.handles.value,'String'));
				pin = str2num(get(me.handles.pin,'String'));
				method = get(me.handles.menu,'Value');
				if method == 1
					try
						me.timedTTL(pin,val);
					end
				elseif method == 2
					try
						me.timedDoubleTTL(pin,val);
					end
				end
			end
			
			function doLoop(varargin)
				if me.silentMode || ~me.isOpen; disp('Not open!'); return; end
				fprintf('===>>> Entering Loop mode, press - to exit!!!\n');
				set(me.handles.loopButton,'ForegroundColor',[0.2 0.7 0]);drawnow;
				val = str2num(get(me.handles.value,'String'));
				pin = str2num(get(me.handles.pin,'String'));
				nl = [];
				for nn = 0:9
					nl = [nl KbName(num2str(nn))];
				end
				nl = [nl KbName('q') KbName('0)') KbName('-_') KbName('1!')];
				oldkeys=RestrictKeysForKbCheck(nl);
				doLoop = true;
				ListenChar(-1);
				while doLoop
					[~, keyCode] = KbWait(-1);
					if any(keyCode)
						rchar = KbName(keyCode); if iscell(rchar);rchar=rchar{1};end
						switch lower(rchar)
							case {'q','0','0)','-_','-'}
								doLoop = false;
							case{'1','1!'}
								me.timedTTL(pin,250);
							case{'2','2@'}
								me.timedTTL(pin,300);
							case{'3','3#'}
								me.timedTTL(pin,400);
							case{'4','4$'}
								me.timedTTL(pin,500);
							case{'5','5%'}
								me.timedTTL(pin,600);
							case{'6','6^'}
								me.timedTTL(pin,700);
							case{'7'}
								me.timedTTL(pin,800);
							case{'8'}
								me.timedTTL(pin,900);
						end
					end
					WaitSecs(0.2);
				end
				ListenChar(0);
				fprintf('===>>> Exit pressed!!!\n');
				RestrictKeysForKbCheck(oldkeys);
				set(me.handles.loopButton,'ForegroundColor',[1 0.5 0]);
			end
			
			function doLoop2(varargin)
				if me.silentMode || ~me.isOpen; disp('Not open!'); return; end
				PsychDefaultSetup(2);
				fprintf('===>>> Entering Loop mode, press - to exit!!!\n');
				set(me.handles.loop2Button,'ForegroundColor',[0.2 0.7 0]);drawnow;
				val = str2num(get(me.handles.value,'String'));
				pin = str2num(get(me.handles.pin,'String'));
				nl = [];
				for nn = 0:9
					nl = [nl KbName(num2str(nn))];
				end
				nl = [nl KbName('q') KbName('-') KbName('+') KbName('0)') KbName('-_') KbName('1!')];
				oldkeys=RestrictKeysForKbCheck(nl);
				doLoop = true;
				
				sM = screenManager();
				sM.backgroundColour = [0.1 0.1 0.1];
				sM.open();
				
				ad = audioManager();ad.close();
				if IsLinux
					ad.device = [];
				elseif IsWin
					ad.device = 6;
				end
				ad.setup();
				
				mv = movieStimulus();
				mv.setup(sM);
				
				ListenChar(2);
				while doLoop
					[isDown, ~, keyCode] = KbCheck(-1);
					if isDown
						rchar = KbName(keyCode); if iscell(rchar);rchar=rchar{1};end
						switch lower(rchar)
							case {'q','0','0)','-_','-'}
								doLoop = false;
							case{'1','1!','kp_end'}
								mv.xPositionOut = 0;
								mv.yPositionOut = 0;
								update(mv);
								start = flip(sM); vbl = start;
								play(ad);
								me.timedTTL(pin,val);
								i=1;
								while vbl < start + 2
									draw(mv); sM.drawCross([],[],0,0);
									finishDrawing(sM);
									vbl = flip(sM);
									if i == 60; me.timedTTL(pin,val); end
									i=i+1;
								end
								me.timedTTL(pin,val);
							case{'2','2@','kp_down'}
								mv.xPositionOut = 16;
								mv.yPositionOut = 10;
								update(mv);
								start = flip(sM); vbl = start;
								play(ad);
								me.timedTTL(pin,val);
								i=1;
								while vbl < start + 2
									draw(mv); sM.drawCross([],[],16,10);
									sM.finishDrawing;
									vbl = flip(sM);
									if i == 60; me.timedTTL(pin,val); end
									i=i+1;
								end
								me.timedTTL(pin,val);
							case{'3','3#','kp_next'}
								mv.xPositionOut = -16;
								mv.yPositionOut = -10;
								update(mv);
								start = flip(sM); vbl = start;
								play(ad);
								me.timedTTL(pin,val);
								i=1;
								while vbl < start + 2
									draw(mv); sM.drawCross([],[],-16,-10);
									sM.finishDrawing;
									vbl = flip(sM);
									if i == 60; me.timedTTL(pin,val); end
									i=i+1;
								end
								me.timedTTL(pin,val);
							case{'4','4$','kp_left'}
								mv.xPositionOut = 16;
								mv.yPositionOut = -10;
								update(mv);
								start = flip(sM); vbl = start;
								play(ad);
								me.timedTTL(pin,200);
								i=1;
								while vbl < start + 2
									draw(mv); sM.drawCross([],[],16,-10);
									sM.finishDrawing;
									vbl = flip(sM);
									if i == 60; me.timedTTL(pin,val); end
									i=i+1;
								end
								me.timedTTL(pin,val);
							case{'5','5%','kp_begin'}
								mv.xPositionOut = -16;
								mv.yPositionOut = 10;
								update(mv);
								start = flip(sM); vbl = start;
								play(ad);
								me.timedTTL(pin,200);
								i=1;
								while vbl < start + 2
									draw(mv); sM.drawCross([],[],-16,10);
									sM.finishDrawing;
									vbl = flip(sM);
									if i == 60; me.timedTTL(pin,val); end
									i=i+1;
								end
								me.timedTTL(pin,val);
							case{'6','6^','kp_right'}
								me.timedTTL(pin,val);
							case{'7','7&','kp_home'}
								me.timedTTL(pin,val);
							case{'8','8*','kp_up'}
								me.timedTTL(pin,val);
						end
					else
						flip(sM);
					end
				end
				ListenChar(0);
				ad.close;mv.reset;
				sM.close;
				fprintf('===>>> Exit pressed!!!\n');
				RestrictKeysForKbCheck(oldkeys);
				set(me.handles.loop2Button,'ForegroundColor',[1 0.5 0]);
			end
		end
		
		%===============CLOSE PORT================%
		function close(me)
			setLow(me);
			try close(me.handles.parent);me.handles=[];end
			me.device = [];
			me.deviceID = '';
			me.availablePins = '';
			me.isOpen = false;
			me.ports = seriallist;
		end
		
		%===============RESET================%
		function reset(me)
			close(me);
			me.silentMode = false;
			notinlist = true;
			if ~isempty(me.ports)
				for i = 1:length(me.ports)
					if strcmpi(me.port,me.ports{i})
						notinlist = false;
					end
				end
			end
			if notinlist && ~isempty(me.ports)
				me.port = me.ports{end};
			end
		end
		
	end
	
	methods ( Access = private ) %----------PRIVATE METHODS---------%
		
		%===========setLow Method==========%
		function setLow(me)
			if me.silentMode || ~me.isOpen; return; end
			switch me.mode
				case 'original'
					for i = me.availablePins{1} : me.availablePins{end}
						me.device.pinMode(i,'output');
						me.device.digitalWrite(i,0);
					end
				otherwise
					for i = me.availablePins{1} : me.availablePins{end}
						configurePin(me.device,['D' num2str(i)],'unset')
						writeDigitalPin(me.device,['D' num2str(i)],0);
					end
			end
		end

		%===========Delete Method==========%
		function delete(me)
			fprintf('arduinoManager Delete method will automagically close connection if open...\n');
			me.close;
		end
		
	end
	
end