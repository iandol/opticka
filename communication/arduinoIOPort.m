classdef arduinoIOPort < handle
	
	% This class defines an "arduino" object
	% Giampiero Campa, Aug 2013, Copyright 2013 The MathWorks, Inc.
	% Modified for use with PTB
	% This version uses IOPort from PTB.
	% Also added a timedTTL function, requiring
	% a compatible arduino sketch: adio.ino
	
	properties (SetAccess=private,GetAccess=public)
		startPin = 2 % first addressable pin (
		endPin = 13 % number of controllable pins
		port   % the assigned port
		conn   % Serial Connection
		pinn   % pin number
		pins   % Pin Status Vector
		srvs   % Servo Status Vector
		mspd   % DC Motors Speed Status
		sspd   % Stepper Motors Speed Status
		encs   % Encoders Status
		sktc   % Motor Server Running on the Arduino Board
		isDemo = false
	end
	
	properties (SetAccess=private,GetAccess=private)
		
	end
	
	methods
		
		% constructor, connects to the board and creates an arduino object
		function a=arduinoIOPort(port,endPin,startPin)
			% check nargin
			if nargin<1
				port='DEMO';
				a.isDemo = true;
				disp('Note: a DEMO connection will be created');
				disp('Use a com port, e.g. ''/dev/ttyACM0'' as input argument to connect to the real board');
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
			if strcmp(port,'DEMO')
				a.isDemo = true;
				return
			end
			if ~verLessThan('matlab','9.7')	% use the nice serialport list command
				allPorts = serialportlist('all');
				avPorts = serialportlist('available');
				fprintf('===> All possible serial ports: ');
				fprintf(' %s ',allPorts); fprintf('\n');
				if any(strcmpi(allPorts,port))
					fprintf('===> Your specified port is present\n')
				else
					warning('===> No port with the specified name is present on the system!');
				end
				if any(strcmpi(avPorts,port))
					fprintf('===> Your specified port is available\n')
				else
					warning('===> The port is occupied, please release it first!');
				end
			end
			% define serial object
			a.conn=IOPort('OpenSerialPort',port,'BaudRate=115200');
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
				IOPort('Write',a.conn,'99'); % our command to query the sketch type
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
				delete(a.conn);
				delete(a);
				error('Connection unsuccessful, please make sure that the board is powered on, running a sketch provided with the package, and connected to the indicated serial port. You might also try to unplug and re-plug the USB cable before attempting a reconnection.');
			end
			a.sktc = r(1)-48; %-48 to get the numeric value from the ASCII one
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
			a.flush();
			for i=a.pinn
				a.pinMode(i,'output');
				a.digitalWrite(i,0);
			end
			% notify successful installation
			a.port = port;
			disp(['===> Arduino successfully connected to port: ' a.port '!']);
			
		end % arduino
		
		% destructor, deletes the object
		function close(a)
			delete(a);
		end
		
		% destructor, deletes the object
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
		
		% disp, displays the object
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
				disp('Motor Shield sketch V2 (plus adioes.pde functions) running on the board');
				disp(' ');
				disp('Servo Methods: <a href="matlab:help servoStatus">servoStatus</a> <a href="matlab:help servoAttach">servoAttach</a> <a href="matlab:help servoDetach">servoDetach</a> <a href="matlab:help servoRead">servoRead</a> <a href="matlab:help servoWrite">servoWrite</a>');
				disp(' ');
				disp('Encoder Methods: <a href="matlab:help encoderStatus">encoderStatus</a> <a href="matlab:help encoderAttach">encoderAttach</a> <a href="matlab:help encoderDetach">encoderDetach</a> <a href="matlab:help encoderRead">encoderRead</a> <a href="matlab:help encoderReset">encoderReset</a>');
				disp(' ');
				disp('DC Motor and Steppers Methods: <a href="matlab:help motorSpeed">motorSpeed</a> <a href="matlab:help motorRun">motorRun</a> <a href="matlab:help stepperSpeed">stepperSpeed</a> <a href="matlab:help stepperStep">stepperStep</a>');
				disp(' ');
				disp('Serial port and other Methods: <a href="matlab:help serial">serial</a> <a href="matlab:help flush">flush</a> <a href="matlab:help roundTrip">roundTrip</a>');
			elseif a.sktc==3
				disp('Motor Shield sketch V1 (plus adioes.pde functions) running on the board');
				disp(' ');
				disp('Servo Methods: <a href="matlab:help servoStatus">servoStatus</a> <a href="matlab:help servoAttach">servoAttach</a> <a href="matlab:help servoDetach">servoDetach</a> <a href="matlab:help servoRead">servoRead</a> <a href="matlab:help servoWrite">servoWrite</a>');
				disp(' ');
				disp('Encoder Methods: <a href="matlab:help encoderStatus">encoderStatus</a> <a href="matlab:help encoderAttach">encoderAttach</a> <a href="matlab:help encoderDetach">encoderDetach</a> <a href="matlab:help encoderRead">encoderRead</a> <a href="matlab:help encoderReset">encoderReset</a>');
				disp(' ');
				disp('DC Motor and Steppers Methods: <a href="matlab:help motorSpeed">motorSpeed</a> <a href="matlab:help motorRun">motorRun</a> <a href="matlab:help stepperSpeed">stepperSpeed</a> <a href="matlab:help stepperStep">stepperStep</a>');
				disp(' ');
				disp('Serial port and other Methods: <a href="matlab:help serial">serial</a> <a href="matlab:help flush">flush</a> <a href="matlab:help roundTrip">roundTrip</a>');
			elseif a.sktc==2
				disp('Analog & Digital I/O + Encoders + Servos (adioes.pde) sketch running on the board');
				disp(' ');
				disp('Pin IO Methods: <a href="matlab:help pinMode">pinMode</a> <a href="matlab:help digitalRead">digitalRead</a> <a href="matlab:help digitalWrite">digitalWrite</a> <a href="matlab:help analogRead">analogRead</a> <a href="matlab:help analogWrite">analogWrite</a> <a href="matlab:help analogReference">analogReference</a>');
				disp(' ');
				disp('Servo Methods: <a href="matlab:help servoStatus">servoStatus</a> <a href="matlab:help servoAttach">servoAttach</a> <a href="matlab:help servoDetach">servoDetach</a> <a href="matlab:help servoRead">servoRead</a> <a href="matlab:help servoWrite">servoWrite</a>');
				disp(' ');
				disp('Encoder Methods: <a href="matlab:help encoderStatus">encoderStatus</a> <a href="matlab:help encoderAttach">encoderAttach</a> <a href="matlab:help encoderDetach">encoderDetach</a> <a href="matlab:help encoderRead">encoderRead</a> <a href="matlab:help encoderReset">encoderReset</a>');
				disp(' ');
				disp('Serial port and other Methods: <a href="matlab:help serial">serial</a> <a href="matlab:help flush">flush</a> <a href="matlab:help roundTrip">roundTrip</a>');
			elseif a.sktc==1
				disp('Analog & Digital I/O + Encoders (adioe.pde) sketch running on the board');
				disp(' ');
				a.pinMode
				disp(' ');
				disp('Pin IO Methods: <a href="matlab:help pinMode">pinMode</a> <a href="matlab:help digitalRead">digitalRead</a> <a href="matlab:help digitalWrite">digitalWrite</a> <a href="matlab:help analogRead">analogRead</a> <a href="matlab:help analogWrite">analogWrite</a> <a href="matlab:help analogReference">analogReference</a>');
				disp(' ');
				disp('Encoder Methods: <a href="matlab:help encoderStatus">encoderStatus</a> <a href="matlab:help encoderAttach">encoderAttach</a> <a href="matlab:help encoderDetach">encoderDetach</a> <a href="matlab:help encoderRead">encoderRead</a> <a href="matlab:help encoderReset">encoderReset</a>');
				disp(' ');
				disp('Serial port and other Methods: <a href="matlab:help serial">serial</a> <a href="matlab:help flush">flush</a> <a href="matlab:help roundTrip">roundTrip</a>');
			else
				disp('===>>> Basic Analog & Digital I/O sketch (adio.pde) running on the board');
				disp(' ');
				a.pinMode
				disp(' ');
				disp('===>>> Pin IO Methods: <a href="matlab:help pinMode">pinMode</a> <a href="matlab:help digitalRead">digitalRead</a> <a href="matlab:help digitalWrite">digitalWrite</a> <a href="matlab:help analogRead">analogRead</a> <a href="matlab:help analogWrite">analogWrite</a> <a href="matlab:help analogReference">analogReference</a>');
				disp('===>>> Serial port and other Methods: <a href="matlab:help serial">serial</a> <a href="matlab:help flush">flush</a> <a href="matlab:help roundTrip">roundTrip</a>');
			end
		end
		
		% serial, returns the serial port
		function str=serial(a)
			if a.isDemo 
				str='DEMO';
			elseif ~isempty(a.port)
				str=a.port;
			else
				str='Invalid';
			end
		end  % serial
		
		% flush, clears the pc's serial port buffer
		function val=flush(a)
			% val=flush(a) (or val=a.flush) reads all the bytes available
			% (if any) in the computer's serial port buffer, therefore
			% clearing said buffer.
			% The first and only argument is the arduino object, the
			% output is a vector of bytes that were still in the buffer.
			% The value '-1' is returned if the buffer was already empty.
			if a.isDemo; return; end
			val=IOPort('BytesAvailable',a.conn);
			if val > 0; IOPort('Read',a.conn); end
			IOPort('Flush',a.conn);
		end  % flush
		
		% pin mode, changes pin mode
		function pinMode(a,pin,str)
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
			if nargin == 3
				if ischar(str)
					if lower(str(1))=='o'; val = 1; else; val = 0; end
				else
					if str(1) == 1; val = 1; else; val = 0; end
				end
				IOPort('Write',a.conn,uint8([48 97+pin 48+val]),1);
				a.pins(a.pinn==pin)=val;
			elseif nargin == 2
				mode={'UNASSIGNED','set as INPUT','set as OUTPUT'};
				disp(['Digital Pin ' num2str(pin) ' is currently ' mode{2+a.pins(a.pinn==pin)}]);
			else
				mode={'UNASSIGNED','set as INPUT','set as OUTPUT'};
				for i=a.pinn
					disp(['Digital Pin ' num2str(i,'%02d') ' is currently ' mode{2+a.pins(a.pinn==i)}]);
				end
			end
		end % pinmode
		
		% digital read
		function val=digitalRead(a,pin)
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
			val = [];
			IOPort('Write',a.conn,uint8([49 97+pin]),1);
			val=IOPort('Read',a.conn); val = str2double(char(val(1)));
		end % digitalread
		
		%==========================================digital write
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
			IOPort('Write',a.conn,uint8([50 97+pin 48+val]),1);
		end % digitalwrite
		
		%===================================================timedTTL
		function timedTTL(a,pin,time)
			% timedTTL(a, pin, time) -- this method allows us to send a
			% long low-high-low transition time (in ms) interval without blocking
			% matlab, using modified adio code.
			if a.isDemo; return; end
			if time < 0; time = 0; end
			if time > 65536; time = 65536; end
			time = typecast(uint16(time),'uint8');
			% send mode and pin
			IOPort('Write',a.conn,uint8([53 97+pin time(1) time(2)]),1);
		end % timedTTL
		
		% analog read
		function val=analogRead(a,pin)
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
			IOPort('Write',a.conn,uint8([51 97+pin]),1);
			val=IOPort('Read',a.conn,1,1);
		end % analogread
		
		% function analog write
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
			IOPort('Write',a.conn,uint8([52 97+pin val]),1);
		end % analogwrite
		
		% function analog reference
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
		
		% round trip
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
			tin=GetSecs;
			nl=0;
			IOPort('Write',a.conn,[uint8(88) byte],1);
			while isempty(val) && GetSecs < tin + 0.5
				nl = nl + 1;
				if IOPort('BytesAvailable',a.conn) > 0
					val=IOPort('Read',a.conn);
				end
			end
			if verbose;fprintf('Roundtrip %i took %.4f ms\n',nl,(GetSecs-tin)*1e3);end
		end % roundtrip
		
		function val=checkSketch(a)
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
		
		function val=rawCommand(a,str)
			if a.isDemo; return; end
			val = [];
			flush(a);
			if ~ischar(str);str=char(str);end
			IOPort('Write',a.conn,str,1);
			while isempty(val)
				if IOPort('BytesAvailable',a.conn) > 0
					val=IOPort('Read',a.conn);
					val = char(val(1));
				end
			end
		end
		
		function val = serialRead(a)
			if a.isDemo; return; end
			val = [];
			if IOPort('BytesAvailable',a.conn) > 0
				val=IOPort('Read',a.conn);
			end
		end
		
		function n = bytesAvailable(a)
			if a.isDemo; return; end
			n = IOPort('BytesAvailable',a.conn);
		end
	end % methods
	
	methods (Static) % static methods
		
	end % static methods
	
end % class def