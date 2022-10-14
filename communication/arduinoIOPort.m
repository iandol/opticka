% ========================================================================
classdef arduinoIOPort < handle
%> @class arduinoIOPort
%> @brief arduinoIOPort - modified legacy ardino interface using PTB IOPort
%> interface for serial communication and adding a new timedTTL function for
%> asynchronous TTL output (i.e. returns immediately to MATLAB even if the
%> TTL is for a long time).
%
%> This class defines an "arduino" object, MATLAB Legacy toolbox.
%> Giampiero Campa, Aug 2013, Copyright 2013 The MathWorks, Inc.
%
%% Modified for use with PTB
%> This version uses IOPort from PTB, as it is faster:
%>   https://psychtoolbox.discourse.group/t/serial-port-interface-code-a-performance-comparison/3781
%
%> Also added a timedTTL function, which performs the TTL timing on the arduino
%> and allows PTB to continue its display loop without interupption.
%> Requires a compatible arduino sketch: 
%>   https://github.com/iandol/opticka/blob/master/communication/arduino/adio/adio.ino
%>
%> We also define a startPin and endPin so we can use it with other boards
%> like the Xiao which has a different pin number...
% ========================================================================
	
	properties (SetAccess=public,GetAccess=public)
		port   % The assigned port
		endPin   = 13 % Number of controllable pins (arduino=13 (however analog pins are 14+, xiao=10 or 13 (incl LEDS))
		startPin = 2 % First addressable pin (arduino=2,xiao=0)
		params = 'BaudRate=115200 ReadTimeout=0.5' % parameters to pass to IOPort
		verbose = false
	end

	properties (SetAccess=private,GetAccess=public)
		conn   % IOPort connection number
		pinn   % Pin numbers
		pins   % Pin status vector
		srvs   % Servo status vector
		mspd   % DC motors speed status
		sspd   % Stepper motors speed status
		encs   % Encoders status
		sktc   % Which sketch is running on the Arduino board?
		isDemo = false
		allPorts = []
		avPorts = []
	end
	
	methods
		%%==========================================CONSTRUCTOR
		function a=arduinoIOPort(port,endPin,startPin)
			% check nargin
			if nargin<1
				port='DEMO';
				a.isDemo = true;
				disp('Note: a DEMO connection will be created');
				disp('Use a com port, e.g. ''/dev/ttyACM0'' as first input argument to connect to a real board');
			elseif nargin == 2
				a.endPin = endPin;
			elseif nargin == 3
				a.endPin = endPin;
				a.startPin = startPin;
			end
			% check port
			if ~ischar(port)
				error('The input argument must be a string, e.g. ''/dev/ttyACM0'' ');
			end
			if strcmpi(port,'DEMO')
				a.isDemo = true;
				return
			end
			if ~verLessThan('matlab','9.7')	% use the nice serialport list command
				a.allPorts = sort(serialportlist('all'));
				a.avPorts = sort(serialportlist('available'));
				fprintf('===> All possible serial ports: ');
				fprintf(' %s ',a.allPorts); fprintf('\n');
				if any(strcmpi(a.allPorts, port))
					fprintf('===> Your specified port %s is present\n', port)
				else
					error('===> No port %s is present on the system!', port);
				end
				if any(strcmpi(a.avPorts, port))
					fprintf('===> Your specified port %s is available\n', port)
				else
					error('===> The port is occupied, please release it first!');
				end
			else
				a.allPorts = seriallist; a.avPorts = []; %#ok<*SERLL> 
				if any(strcmpi(a.allPorts, port))
					fprintf('===> Your specified port %s is present\n', port)
				else
					error('===> No port %s is present on the system!', port);
				end
			end
			% define IOPort serial object
			oldv = IOPort('Verbosity',0);
			[a.conn, err] = IOPort('OpenSerialPort', port, a.params);
			IOPort('Verbosity',oldv)
			if a.conn == -1
				warning('===>! Port CANNOT be opened: %s',err);
				a.isDemo = true;
				a.conn = [];
				return
			end
			% test connection
			try
				IOPort('Flush',a.conn);
			catch ME
				disp(ME.message)
				delete(a.conn);
				delete(a);
				error(['Could not use port: ' port]);
			end
			% query sketch type
			r = []; tout = []; t = GetSecs;
			while isempty(r) && GetSecs < t+2
				IOPort('Write',a.conn,'99'); % our command to query the sketch type, should return 48 ('0' as a char).
				WaitSecs('YieldSecs',0.01);
				if IOPort('BytesAvailable',a.conn) > 0
					r = IOPort('Read',a.conn);
					if r(1) ~= 48
						r = [];
					else
						tout = GetSecs - t;
					end
				end
			end
			% exit if there was no answer
			if isempty(r)
				IOPort('CloseAll');
				try delete(a.conn); end
				try delete(a); end
				error('Connection unsuccessful, please make sure that the board is powered on, running a sketch provided with the package, and connected to the indicated serial port. You might also try to unplug and re-plug the USB cable before attempting a reconnection.');
			end
			a.sktc = r(1)-48; %-48 to get the numeric value from the ASCII one [char(48)==0]
			fprintf('===> It took %.3f secs to establish response: %i...\n',tout,a.sktc);
			% check returned value
			if a.sktc==0
				disp('===> Basic Analog and Digital I/O (adio.ino) sketch detected !');
			elseif a.sktc==1
				disp('===> Analog & Digital I/O + Encoders (adioe.ino) sketch detected !');
			elseif a.sktc==2
				disp('===> Analog & Digital I/O + Encoders + Servos (adioes.ino) sketch detected !');
			elseif a.sktc==3
				disp('===> Motor Shield V1 (plus adioes.ino functions) sketch detected !');
			elseif a.sktc==4
				disp('===> Motor Shield V2 (plus adioes.ino functions) sketch detected !');
			else
				IOPort('CloseAll')
				error('Unknown sketch. Please make sure that a sketch provided with the package is running on the board');
			end
			% pin numbers for arduino
			a.pinn=a.startPin:a.endPin;
			% initialize pin vector (-1 is unassigned, 0 is input, 1 is output)
			a.pins=-1*ones(1,length(a.pinn));
			% initialize servo vector (0 is detached, 1 is attached)
			a.srvs=0*ones(1,length(a.pinn));
			% initialize encoder vector (0 is detached, 1 is attached)
			a.encs=0*ones(1,3);
			% initialize motor vector (0 to 255 is the speed)
			a.mspd=0*ones(1,4);
			% initialize stepper vector (0 to 255 is the speed)
			a.sspd=0*ones(1,2);
			% notify successful installation
			a.port = port;
			disp(['===> Arduino successfully connected to port: ' a.port '!']);
			purge(a);
		end % arduino

		%==========================================PIN MODE
		function pinMode(a, pin, str)
			% pinMode(a,pin,str); reads or sets the I/O mode of a digital pin.
			% The first argument, a, is the arduino object.
			% The second argument, pin, is the number of the digital pin (2 to a.endPin).
			% The third argument, str, is a string that can be 'input' or 'output',
			% Called as pinMode(a,pin) it returns the mode of the digital pin,
			% called as pinMode(a), it prints the mode of all the digital pins.
			% Note that in the Arduino Uno board the digital pins from 0 to 13
			% are located on the upper right part of the board,
			% while the digital pins from 14 to 19 are better known as
			% "analog input" pins (in fact are often referred to with an
			% analog pin number from 0 to 5) and are located in the lower
			% right corner of the board.
			%
			% Examples:
			% pinMode(a,11,'output') % sets digital pin #11 as output
			% pinMode(a,10,'input')  % sets digital pin #10 as input
			% a.pinMode(10,'input')  % same as pinMode(a,10,'input')
			% val=pinMode(a,10);     % returns the status of digital pin #10
			% pinMode(a,5);          % prints the status of digital pin #5
			% pinMode(a);            % prints the status of all pins
			%
			%%%%%%%%%%%%%%%%%%%%%%%%% ARGUMENT CHECKING %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
			if a.isDemo; return; end
			if exist('pin','var') && (pin < a.startPin || pin > a.endPin); warning('Pin is not in range!!!');return;end
			mode={'UNASSIGNED','set as INPUT','set as OUTPUT'};
			if nargin == 3
				if ischar(str)
					if lower(str(1))=='o'; val = 1; else; val = 0; end
				else
					if str(1) == 1; val = 1; else; val = 0; end
				end
				IOPort('Write',a.conn,uint8([48 97+pin 48+val]),1);
				a.pins(a.pinn==pin)=val;
			elseif nargin == 2
				disp(['Digital Pin ' num2str(pin) ' is currently ' mode{2+a.pins(a.pinn==pin)}]);
			else
				for i=a.pinn
					disp(['Digital Pin ' num2str(i,'%02d') ' is currently ' mode{2+a.pins(a.pinn==i)}]);
				end
			end
		end % pinmode
		
		%==========================================DIGITAL READ
		function val = digitalRead(a,pin)
			% val=digitalRead(a,pin); performs digital input on a given arduino pin.
			% The first argument, a, is the arduino object.
			% The second argument, pin, is the number of the digital pin 
			% where the digital input needs to be performed. On the Arduino Uno
			% the digital pins from 0 to 13 are located on the upper right part
			% while the digital pins from 14 to 19 are better known as "analog input"
			% pins and are located in the lower right corner of the board
			% (in fact are often referred to as "analog pins from 0 to 5").
			%
			% Examples:
			% val=digitalRead(a,4); % reads pin #4
			% val=a.digitalRead(4); % just as above (reads pin #4)
			%
			if a.isDemo; return; end
			purge(a);
			n = IOPort('Write',a.conn,uint8([49 97+pin]),2);
			if n ~= 2; warning('arduinoIOPort.digitalRead() WRITE command went wrong?'); end
			[val, ~, err] = IOPort('Read',a.conn,1,3);
			if isempty(val)
				val = NaN;
				if ~isempty(err)
					warning('arduinoIOPort.digitalRead() failed: %s', err); 
				else
					warning('arduinoIOPort.digitalRead() was empty');
				end
			else
				val = val(1) - 48; %returns a byte value, char(48) = '0'
			end
		end % digitalread
		
		%==========================================DIGITAL WRITE
		function digitalWrite(a,pin,val)
			% digitalWrite(a,pin,val); performs digital output on a given pin.
			% The first argument, a, is the arduino object.
			% The second argument, pin, is the number of the digital pin
			% (2 to a.endPin) where the digital output value needs to be written.
			% The third argument, val, is the output value (either 0 or 1).
			% On the Arduino Uno  the digital pins from 0 to 13 are located
			% on the upper right part of the board, while the digital pins
			% from 14 to 19 are better known as "analog input" pins and are
			% located in the lower right corner of the board  (in fact are
			% often referred to as "analog pins from 0 to 5").
			%
			% Examples:
			% digitalWrite(a,13,1); % sets pin #13 high
			% digitalWrite(a,13,0); % sets pin #13 low
			% a.digitalWrite(13,0); % just as above (sets pin #13 to low)
			%
			if a.isDemo; return; end
			if pin < a.startPin || pin > a.endPin; warning('Pin is not in range!!!');end
			IOPort('Write',a.conn,uint8([50 97+pin 48+val]),1);
		end % digitalwrite

		%===================================================ANALOG READ
		function val = analogRead(a,pin)
			% val=analogRead(a,pin); Performs analog input on a given arduino pin.
			% The first argument, a, is the arduino object. The second argument,
			% pin, is the number of the analog input pin (0 to 15) from which the
			% analog value needs to be read. The returned value, val, ranges from
			% 0 to 1023, with 0 corresponding to an input voltage of 0 volts,
			% and 1023 to a reference value that is typically 5 volts (this voltage can
			% be set up by the analogReference function). Therefore, assuming a range
			% from 0 to 5 V the resolution is .0049 volts (4.9 mV) per unit.
			% Note that in the Arduino Uno board the analog input pins 0 to 5 are also
			% the digital pins from 14 to 19, and are located on the lower right corner.
			% Specifically, analog input pin 0 corresponds to digital pin 14, and analog
			% input pin 5 corresponds to digital pin 19. Performing analog input does
			% not affect the digital state (high, low, digital input) of the pin.
			%
			% Examples:
			% val=analogRead(a,0); % reads analog input pin # 0
			% val=a.analogRead(0); % just as above, reads analog input pin # 0
			%
			if a.isDemo; return; end
			purge(a); %make sure we remove any stale data
			n = IOPort('Write',a.conn,uint8([51 97+pin]),1);
			if n ~= 2; warning('arduinoIOPort.analogRead() WRITE command went wrong?'); end
			val = [];
			nBytes = Inf;
			% we do not know how many bytes the arduino will return; it
			% could be 3 to 6 so we have to use a loop to read bytes
			% one-by-one until the queue is empty...
			while nBytes > 0
				val(end+1) = IOPort('Read',a.conn,1,1);
				nBytes = bytesAvailable(a);
			end
			val = a.cleanup(val); %remove CR (13) and NL (10)
			val = str2double(char(val));
		end % analogread
		
		%===================================================ANALOG WRITE
		function analogWrite(a,pin,val)
			% analogWrite(a,pin,val); Performs analog output on a given arduino pin.
			% The first argument, a, is the arduino object. The second argument,
			% pin, is the number of the DIGITAL pin where the analog (PWM) output
			% needs to be performed. Allowed pins for AO on the Mega board
			% are 2 to 13 and 44 to 46, (3,5,6,9,10,11 on the Uno board).
			% The second argument, val, is the value from 0 to 255 for the level of
			% analog output. Note that the digital pins from 0 to 13 are located on the
			% upper right part of the board.
			%
			% Examples:
			% analogWrite(a,11,90); % sets pin #11 to 90/255
			% a.analogWrite(3,10); % sets pin #3 to 10/255
			%
			if a.isDemo; return; end
			if pin<a.startPin || pin > a.endPin;warning('Pin may not be in range!!!');end
			IOPort('Write',a.conn,uint8([52 97+pin val]),1);
		end % analogwrite
		
		%===================================================timedTTL
		function timedTTL(a,pin,time)
			% timedTTL(a, pin, time) -- this method allows us to send a
			% long low-high-low transition time (in ms, max=65535ms) interval without 
			% blocking matlab, using modified adio sketch code.
			if a.isDemo; return; end
			if pin < a.startPin || pin > a.endPin; warning('Pin is not in range!!!');end
			if time <= 0; return; end
			if time > 2^16-1; time = 2^16-1; end
			time = typecast(uint16(time),'uint8'); %convert to 2 uint8 bytes
			% send mode and pin
			IOPort('Write',a.conn,uint8([53 97+pin time(1) time(2)]),1);
		end % timedTTL
		
		%===================================================strobeWord
		function strobeWord(a,value)
			% strobeWord(a, value) -- send a byte [0-255] value to the 8 pins
			% 2-9 as a 1ms strobed word.
			if a.isDemo; return; end
			if value < 0; value = 0; end
			if value > 255; value = 255; end
			% send mode and pin
			IOPort('Write',a.conn,uint8([54 value]),1);
		end % strobeWord
		
		%===================================================function analog reference
		function analogReference(a,str)
			% analogReference(a,str); Changes voltage reference on analog input pins
			% The first argument, a, is the arduino object. The second argument,
			% str, is one of these strings: 'default', 'internal' or 'external'.
			% This sets the reference voltage used at the top of the input ranges.
			%
			% Examples:
			% analogReference(a,'default'); % sets default reference
			% analogReference(a,'internal'); % sets internal reference
			% analogReference(a,'external'); % sets external reference
			% a.analogReference('external'); % just as above (sets external reference)
			%
			if a.isDemo; return; end
			if lower(str(1))=='e', num=2;
			elseif lower(str(1))=='i', num=1;
			else; num=0;
			end
			% send mode, pin and value
			IOPort('Write',a.conn,uint8([82 48+num]),1);
		end % analogreference
		
		%===================================================round trip
		function val=roundTrip(a,byte,verbose)
			% roundTrip(a,byte); sends something to the arduino and back
			% The first argument, a, is the arduino object.
			% The second argument, byte, is any integer from 0 to 255.
			% The output is the same byte, which was received from the
			% arduino and sent back along the serial connection unchanged.
			%
			% This is provided as an example for people that want to add
			% their own code to this arduino class (the section handling
			% this dummy function in the pde file is handled as "case 400:",
			% one might take the parameter, perform some potentially useful
			% operation, and then send any result back via serial connection).
			%
			% Examples:
			% roundTrip(a,48); % sends '48' to the arduino and back.
			% a.roundTrip(53); % sends '53' to the arduino and back.
			%
			if a.isDemo; return; end
			val = [];
			if ~exist('byte','var') || isempty(byte); byte=uint8(33);end
			if ~exist('verbose','var'); verbose = false; end
			if ischar(byte); byte = uint8(byte(1)); end
			if ~isa(byte,'uint8');byte=uint8(byte); end
			flush(a);
			nl=0;
			tin=GetSecs;
			IOPort('Write',a.conn,[uint8(88) byte],1);
			while isempty(val) && GetSecs < tin + 0.5
				nl = nl + 1;
				if IOPort('BytesAvailable',a.conn) > 0
					val=IOPort('Read',a.conn);
				end
			end
			if verbose;fprintf('Roundtrip for value:%i took %i loops & %.4f ms\n',val,nl,(GetSecs-tin)*1e3);end
		end % roundtrip
		
		%%==========================================CONFIGURE
		function configure(a,params)
			if a.isDemo; return; end
			if ~exist('params','var') || isempty(params); params = a.params; end
			IOPort('ConfigureSerialPort',a.conn,params)
		end

		%%==========================================DESTRUCTOR
		function delete(a)
			try
				for i=a.pinn
					a.pinMode(i,'output');
					a.digitalWrite(i,0);
				end
				IOPort('CloseAll');
			catch ME
				% disp but proceed anyway
				IOPort('CloseAll');
				disp(ME.message);
				disp('Proceeding to deletion anyway');
			end
		end % delete
		function close(a)
			delete(a);
		end
		
		%%==========================================DISPLAY
		function disp(a)
			% disp(a) or a.disp, displays the arduino object properties
			% The first and only argument is the arduino object, there is no
			% output, but the basic information and properties of the arduino
			% object are displayed on the screen.
			% This function is called when just the name of the arduino object
			% is typed on the command line, followed by enter. The command
			% str=evalc('a.disp'), (or str=evalc('a')), can be used to capture
			% the output in the string 'str'.
			if a.isDemo; disp('Arduino is in DEMO mode');return;end
			fprintf('===>>> Arduino object connected to %s with %i pins\n',a.port,length(a.pinn));
			fprintf('===>>> Start pin: %i | end pin: %i\n',a.startPin,a.endPin);
			if a.sktc==4
				disp('===>>> Motor Shield sketch V2 (plus adioes.pde functions) running on the board');
				disp(' ');
				disp('===>>> Servo Methods: <a href="matlab:help servoStatus">servoStatus</a> <a href="matlab:help servoAttach">servoAttach</a> <a href="matlab:help servoDetach">servoDetach</a> <a href="matlab:help servoRead">servoRead</a> <a href="matlab:help servoWrite">servoWrite</a>');
				disp(' ');
				disp('===>>> Encoder Methods: <a href="matlab:help encoderStatus">encoderStatus</a> <a href="matlab:help encoderAttach">encoderAttach</a> <a href="matlab:help encoderDetach">encoderDetach</a> <a href="matlab:help encoderRead">encoderRead</a> <a href="matlab:help encoderReset">encoderReset</a>');
				disp(' ');
				disp('===>>> DC Motor and Steppers Methods: <a href="matlab:help motorSpeed">motorSpeed</a> <a href="matlab:help motorRun">motorRun</a> <a href="matlab:help stepperSpeed">stepperSpeed</a> <a href="matlab:help stepperStep">stepperStep</a>');
				disp(' ');
				disp('===>>> Serial port and other Methods: <a href="matlab:help serial">serial</a> <a href="matlab:help flush">flush</a> <a href="matlab:help roundTrip">roundTrip</a>');
			elseif a.sktc==3
				disp('===>>> Motor Shield sketch V1 (plus adioes.pde functions) running on the board');
				disp(' ');
				disp('===>>> Servo Methods: <a href="matlab:help servoStatus">servoStatus</a> <a href="matlab:help servoAttach">servoAttach</a> <a href="matlab:help servoDetach">servoDetach</a> <a href="matlab:help servoRead">servoRead</a> <a href="matlab:help servoWrite">servoWrite</a>');
				disp(' ');
				disp('===>>> Encoder Methods: <a href="matlab:help encoderStatus">encoderStatus</a> <a href="matlab:help encoderAttach">encoderAttach</a> <a href="matlab:help encoderDetach">encoderDetach</a> <a href="matlab:help encoderRead">encoderRead</a> <a href="matlab:help encoderReset">encoderReset</a>');
				disp(' ');
				disp('===>>> DC Motor and Steppers Methods: <a href="matlab:help motorSpeed">motorSpeed</a> <a href="matlab:help motorRun">motorRun</a> <a href="matlab:help stepperSpeed">stepperSpeed</a> <a href="matlab:help stepperStep">stepperStep</a>');
				disp(' ');
				disp('===>>> Serial port and other Methods: <a href="matlab:help serial">serial</a> <a href="matlab:help flush">flush</a> <a href="matlab:help roundTrip">roundTrip</a>');
			elseif a.sktc==2
				disp('===>>> Analog & Digital I/O + Encoders + Servos (adioes.pde) sketch running on the board');
				disp(' ');
				disp('===>>> Pin IO Methods: <a href="matlab:help pinMode">pinMode</a> <a href="matlab:help digitalRead">digitalRead</a> <a href="matlab:help digitalWrite">digitalWrite</a> <a href="matlab:help analogRead">analogRead</a> <a href="matlab:help analogWrite">analogWrite</a> <a href="matlab:help analogReference">analogReference</a>');
				disp(' ');
				disp('===>>> Servo Methods: <a href="matlab:help servoStatus">servoStatus</a> <a href="matlab:help servoAttach">servoAttach</a> <a href="matlab:help servoDetach">servoDetach</a> <a href="matlab:help servoRead">servoRead</a> <a href="matlab:help servoWrite">servoWrite</a>');
				disp(' ');
				disp('===>>> Encoder Methods: <a href="matlab:help encoderStatus">encoderStatus</a> <a href="matlab:help encoderAttach">encoderAttach</a> <a href="matlab:help encoderDetach">encoderDetach</a> <a href="matlab:help encoderRead">encoderRead</a> <a href="matlab:help encoderReset">encoderReset</a>');
				disp(' ');
				disp('===>>> Serial port and other Methods: <a href="matlab:help serial">serial</a> <a href="matlab:help flush">flush</a> <a href="matlab:help roundTrip">roundTrip</a>');
			elseif a.sktc==1
				disp('===>>> Analog & Digital I/O + Encoders (adioe.pde) sketch running on the board');
				disp(' ');
				a.pinMode
				disp(' ');
				disp('===>>> Pin IO Methods: <a href="matlab:help pinMode">pinMode</a> <a href="matlab:help digitalRead">digitalRead</a> <a href="matlab:help digitalWrite">digitalWrite</a> <a href="matlab:help analogRead">analogRead</a> <a href="matlab:help analogWrite">analogWrite</a> <a href="matlab:help analogReference">analogReference</a>');
				disp(' ');
				disp('===>>> Encoder Methods: <a href="matlab:help encoderStatus">encoderStatus</a> <a href="matlab:help encoderAttach">encoderAttach</a> <a href="matlab:help encoderDetach">encoderDetach</a> <a href="matlab:help encoderRead">encoderRead</a> <a href="matlab:help encoderReset">encoderReset</a>');
				disp(' ');
				disp('===>>> Serial port and other Methods: <a href="matlab:help serial">serial</a> <a href="matlab:help flush">flush</a> <a href="matlab:help roundTrip">roundTrip</a>');
			else
				disp('===>>> Basic Analog & Digital I/O sketch (adio.pde) running on the board');
				disp(' ');
				a.pinMode
				disp(' ');
				disp('===>>> Pin IO Methods: <a href="matlab:help pinMode">pinMode</a> <a href="matlab:help digitalRead">digitalRead</a> <a href="matlab:help digitalWrite">digitalWrite</a> <a href="matlab:help analogRead">analogRead</a> <a href="matlab:help analogWrite">analogWrite</a> <a href="matlab:help timedTTL">timedTTL</a> <a href="matlab:help strobeWord">strobeWord</a> <a href="matlab:help analogReference">analogReference</a>');
				disp('===>>> Serial port and other Methods: <a href="matlab:help flush">flush</a> <a href="matlab:help roundTrip">roundTrip</a>');
			end
		end

		%===================================================
		function val = checkSketch(a)
			% checkSketch(a); checks what type of sketch is running on the
			% arduino. 0 is the standard adio sketch.
			if a.isDemo; return; end
			val = [];
			flush(a);
			IOPort('Write',a.conn,'99',1); % our command to query the sketch type
			while isempty(val)
				if IOPort('BytesAvailable',a.conn) > 0
					val = IOPort('Read',a.conn);
					val = val(1)-48;
				end
			end
		end
		
		%===================================================
		function val = rawCommand(a,str)
			% rawCommand(a); send a raw command (e.g.'2c1')
			if a.isDemo; return; end
			val = [];
			flush(a);
			if ~ischar(str);str=char(str);end
			IOPort('Flush');
			IOPort('Write',a.conn,str,1);
			while isempty(val)
				if IOPort('BytesAvailable',a.conn) > 0
					val=IOPort('Read',a.conn);
					val = char(val(1));
				end
			end
		end
		
		%===================================================
		function val = serialRead(a)
			% serialRead(a); read a value from the serial interface
			if a.isDemo; return; end
			val = []; i = 1;
			while bytesAvailable(a) > 0
				val{i} = IOPort('Read',a.conn,1,1);
				i = i + 1;
			end
		end
		
		%===================================================
		function n = bytesAvailable(a)
			% bytesAvailable(a); check how many bytes are available to read
			if a.isDemo; return; end
			n = IOPort('BytesAvailable',a.conn);
		end

		%===================================================flush
		function val = purge(a)
			%Purge all data queued for reading or writing from/to device specified 
			% by 'handle'. All unread or unwritten data is discarded.
			if a.isDemo; return; end
			IOPort('Purge',a.conn);
		end

		%===================================================flush
		function val = flush(a)
			% val=flush(a) (or val=a.flush) reads all the bytes available
			% (if any) in the computer's serial port buffer, therefore
			% clearing said buffer.
			% The first and only argument is the arduino object, the
			% output is a vector of bytes that were still in the buffer.
			if a.isDemo; return; end
			IOPort('Flush',a.conn);
			val=bytesAvailable(a);
			data = IOPort('Read',a.conn,1,val);
			if a.verbose;disp('Data in read buffer:');disp(data); end
		end  % flush

	end % methods

	methods (Access = private) 
		
	end 
	
	methods (Static) % static methods
		function out = cleanup(in)
			in(in==13) = [];
			in(in==10) = [];
			out = in;
		end
	end % static methods
	
end % class def
