% ========================================================================
%> @brief Arduino Manager > Connects and manages arduino communication. By
%> default it connects using arduinoIOPort (much faster than the MATLAB
%> serial port interface) and the adio.ino arduino sketch (the legacy
%> arduino interface by Mathworks), which provide much better performance
%> than MATLAB's current hardware package.
%>
%> Copyright ©2014-2022 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ========================================================================
classdef arduinoManager < optickaCore
	% ARDUINOMANAGER Connects and manages arduino communication. By default it
	% connects using arduinoIOPort and the adio.ino arduino sketch (the legacy
	% arduino interface by Mathworks), which provide much better performance
	% than MATLAB's hardware package.
	properties
		%> arduino port, if left empty it will make a guess during open
		port char				= ''
		%> board type; uno [default] is a generic arduino, xiao is the seeduino xiao
		board char {mustBeMember(board,{'Uno','Xiao'})}	= 'Uno' 
		%> run with no arduino attached, useful for debugging
		silentMode logical		= false
		%> output logging info
		verbose					= false
		%> open a GUI to drive a reward directly
		openGUI logical			= true
		%> which pin to trigger the reward TTL?
		rewardPin double		= 2
		%> time of the TTL sent?
		rewardTime double		= 300
		%> specify the available pins to use; 2-13 is the default for an Uno
		%> 0-10 for the xiao
		availablePins cell		= {2,3,4,5,6,7,8,9,10,11,12,13}
		%> the arduino device object,
		device					= []
	end
	properties (SetAccess = private, GetAccess = public)
		%> which ports are available
		ports
		%> could we succesfully open the arduino?
		isOpen logical			= false
		%> ID from device
		deviceID				= ''
	end
	properties (SetAccess = private, GetAccess = private, Transient = true)
		%> handles for the optional UI
		handles					= []
		%> a screen object to bind to
		screen screenManager
	end
	properties (SetAccess = private, GetAccess = private)
		allowedProperties char	= ['availablePins|rewardPin|rewardTime|openGUI|board|'...
			'port|silentMode|verbose']
	end
	
	methods%------------------PUBLIC METHODS--------------%
		
		%==============CONSTRUCTOR============%
		function me = arduinoManager(varargin)
		% arduinoManager Construct an instance of this class
			args = optickaCore.addDefaults(varargin,struct('name','arduino manager'));
			me=me@optickaCore(args); %we call the superclass constructor first
			me.parseArgs(args, me.allowedProperties);
			if isempty(me.port)
				if ~verLessThan('matlab','9.7')	% use the nice serialport list command
					me.ports = serialportlist('available');
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
			if ~exist('arduinoIOPort','file')
				me.comment = 'Cannot find arduinoIOPort, check opticka path!';
				warning(me.comment)
				me.silentMode = true;
			end
		end
		
		%===============OPEN DEVICE================%
		function open(me)
			if me.isOpen || ~isempty(me.device);disp('-->arduinoManager: Already open!');return;end
			if me.silentMode;disp('-->arduinoManager: In silent mode, try to close() then open()!');me.isOpen=false;return;end
			if isempty(me.port);warning('--->arduinoManager: Better specify the port to use; will try to select one from available ports!');return;end
			close(me); me.ports = serialportlist('available');
			try
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
						if isempty(me.availablePins);me.availablePins = {0,1,2,3,4,5,6,7,8,9,10,11,12,13};end
					otherwise
						if isempty(me.availablePins);me.availablePins = {2,3,4,5,6,7,8,9,10,11,12,13};end
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
					me.isOpen = true;
					setLow(me);
				end
				if me.openGUI; GUI(me); end
				me.silentMode = false;
			catch ME
				me.silentMode = true; me.isOpen = false;
				fprintf('\n\nCouldn''t open Arduino: %s\n',ME.message)
				getReport(ME)
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
			me.silentMode = false;
			if ~verLessThan('matlab','9.7')
				me.ports = serialportlist('available');
			else
				me.ports = seriallist;
			end
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
		
		%===============PIN MODE================%
		function pinMode(me, line, mode)
			if ~me.isOpen || me.silentMode; return; end
			if nargin == 3 && ischar(mode)
				pinMode(me.device, line, mode);
			elseif nargin == 2
				pinMode(me.device, line);
			else
				pinMode(me.device)
			end
		end
		
		%===============ANALOG READ================%
		function value = analogRead(me, line)
			if ~me.isOpen || me.silentMode; return; end
			if ~exist('line','var') || isempty(line); line = me.rewardPin; end
			value = analogRead(me.device, line);
			if me.verbose;fprintf('===>>> ANALOGREAD: pin %i = %i \n',line,value);end
		end

		%===============ANALOG WRITE================%
		function analogWrite(me, line, value)
			if ~me.isOpen || me.silentMode; return; end
			if ~exist('line','var') || isempty(line); line = me.rewardPin; end
			if ~exist('value','var') || isempty(value); value = 128; end
			analogWrite(me.device, line, value);
			if me.verbose;fprintf('===>>> ANALOGWRITE: pin %i = %i \n',line,value);end
		end

		%===============DIGITAL READ================%
		function value = digitalRead(me, line)
			if ~me.isOpen || me.silentMode; return; end
			if ~exist('line','var') || isempty(line); line = me.rewardPin; end
			value = analogRead(me.device, line);
			if me.verbose;fprintf('===>>> DIGREAD: pin %i = %i \n',line,value);end
		end
		
		%===============DIGITAL WRITE================%
		function digitalWrite(me, line, value)
			if ~me.isOpen || me.silentMode; return; end
			if ~exist('line','var') || isempty(line); line = me.rewardPin; end
			if ~exist('value','var') || isempty(value); value = 0; end
			digitalWrite(me.device, line, value);
			if me.verbose;fprintf('===>>> DIGWRITE: pin %i = %i \n',line,value);end
		end
		
		%===============SEND TTL (legacy)================%
		function sendTTL(me, line, time)
			timedTTL(me, line, time)
		end
		
		%===============TIMED TTL================%
		function timedTTL(me, line, time)
			if ~me.isOpen; return; end
			if ~me.silentMode
				if ~exist('line','var') || isempty(line); line = me.rewardPin; end
				if ~exist('time','var') || isempty(time); time = me.rewardTime; end
				timedTTL(me.device, line, time);
				if me.verbose;fprintf('===>>> timedTTL: TTL pin %i for %i ms\n',line,time);end
			else
				if me.verbose;fprintf('===>>> timedTTL: Silent Mode\n');end
			end
		end
		
		%===============STROBED WORD================%
		function strobeWord(me, value)
			if ~me.isOpen; return; end
			if ~me.silentMode
				strobeWord(me.device, value);
				if me.verbose;fprintf('===>>> STROBED WORD: %i sent to pins 2-8\n',value);end
			end
		end
		
		%===============TIMED DOUBLE TTL================%
		function timedDoubleTTL(me, line, time)
			if ~me.silentMode
				if ~exist('line','var') || isempty(line); line = me.rewardPin; end
				if ~exist('time','var') || isempty(time); time = me.rewardTime; end
				if time < 0; time = 0;end
				timedTTL(me.device, line, 10);
				WaitSecs('Yieldsecs',time/1e3);
				timedTTL(me.device, line, 10);
				if me.verbose;fprintf('===>>> timedTTL: double TTL pin %i for %i ms\n',line,time);end
			else
				if me.verbose;fprintf('===>>> timedTTL: Silent Mode\n');end
			end
		end
		
		%===============TEST TTL================%
		function test(me,line)
			if me.silentMode || isempty(me.device); return; end
			if ~exist('line','var') || isempty(line); line = 2; end
			digitalWrite(me.device, line, 0);
			for ii = 1:20
				digitalWrite(me.device, line, mod(ii,2));
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
				'String',me.rewardTime,...
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
				'String',me.rewardPin,...
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
			
			% internal function to engage timedTTL
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
			
			% simple loop controlled using bluetooth keyboard
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
				fInc = 6;
				tick = 0;
				kTick = 0;
				ListenChar(-1);
				while doLoop
					tick = tick + 1;
					[~, keyCode] = KbWait(-1);
					if any(keyCode)
						rchar = KbName(keyCode); if iscell(rchar);rchar=rchar{1};end
						switch lower(rchar)
							case {'q','0','0)','-_','-'}
								doLoop = false;
							case{'1','1!'}
								if tick > kTick
									me.timedTTL(pin,250);
									kTick = tick + fInc;
								end
							case{'2','2@'}
								if tick > kTick
									me.timedTTL(pin,300);
									kTick = tick + fInc;
								end
							case{'3','3#'}
								if tick > kTick
									me.timedTTL(pin,400);
									kTick = tick + fInc;
								end
							case{'4','4$'}
								if tick > kTick
									me.timedTTL(pin,500);
									kTick = tick + fInc;
								end
							case{'5','5%'}
								if tick > kTick
									me.timedTTL(pin,600);
									kTick = tick + fInc;
								end
							case{'6','6^'}
								if tick > kTick
									me.timedTTL(pin,700);
									kTick = tick + fInc;
								end
							case{'7'}
								if tick > kTick
									me.timedTTL(pin,800);
									kTick = tick + fInc;
								end
							case{'8'}
								if tick > kTick
									me.timedTTL(pin,900);
									kTick = tick + fInc;
								end
						end
					end
					WaitSecs(0.02);
				end
				ListenChar(0);
				fprintf('===>>> Exit pressed!!!\n');
				RestrictKeysForKbCheck([]);
				set(me.handles.loopButton,'ForegroundColor',[1 0.5 0]);
			end
			
			% training loop with stimulus controlled using keyboard
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
				
				global aM
				if isempty(aM) || ~isa('aM','audioManager')
					aM = audioManager();aM.close();
				end
				if IsLinux
					aM.device = [];
				elseif IsWin
					aM.device = 6;
				end
				aM.open();aM.loadSamples();
				
				mv = movieStimulus();
				mv.setup(sM);
				
				fInc = 6;
				tick = 0;
				kTick = 1;
				
				ListenChar(-1);
				while doLoop
					tick = tick + 1;
					[isDown, ~, keyCode] = KbCheck(-1);
					if isDown
						rchar = KbName(keyCode); if iscell(rchar);rchar=rchar{1};end
						switch lower(rchar)
							case {'q','0','0)','-_','-'}
								doLoop = false;
							case{'1','1!','kp_end'}
								if tick > kTick
									mv.xPositionOut = 0;
									mv.yPositionOut = 0;
									update(mv);
									start = flip(sM); vbl = start;
									play(aM);
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
									kTick = tick + fInc;
								end
							case{'2','2@','kp_down'}
								mv.xPositionOut = 16;
								mv.yPositionOut = 10;
								update(mv);
								start = flip(sM); vbl = start;
								play(aM);
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
								play(aM);
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
								play(aM);
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
								play(aM);
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
								if tick > kTick
									me.timedTTL(pin,val);
									kTick = tick + fInc;
								end
							case{'7','7&','kp_home'}
								if tick > kTick
									me.timedTTL(pin,val);
									kTick = tick + fInc;
								end
							case{'8','8*','kp_up'}
								if tick > kTick
									me.timedTTL(pin,val);
									kTick = tick + fInc;
								end
						end

					end
					flip(sM);
				end
				ListenChar(0);
				aM.close; mv.reset;
				sM.close;
				fprintf('===>>> Exit pressed!!!\n');
				RestrictKeysForKbCheck([]);
				set(me.handles.loop2Button,'ForegroundColor',[1 0.5 0]);
			end
		end	
	end
	
	methods ( Access = private ) %----------PRIVATE METHODS---------%
		
		%===========setLow Method==========%
		function setLow(me)
			if me.silentMode || ~me.isOpen; return; end
			for i = me.availablePins{1} : me.availablePins{end}
				me.device.pinMode(i,'output');
				me.device.digitalWrite(i,0);
			end
		end

		%===========setHigh Method==========%
		function setHigh(me)
			if me.silentMode || ~me.isOpen; return; end
			for i = me.availablePins{1} : me.availablePins{end}
				me.device.pinMode(i,'output');
				me.device.digitalWrite(i,0);
			end
		end

		%===========Delete Method==========%
		function delete(me)
			fprintf('arduinoManager Delete method will automagically close connection if open...\n');
			me.close;
		end
		
	end
	
end