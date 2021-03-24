classdef arduinoIOPort < handle
	
	% This class defines an "arduino" object
	% Giampiero Campa, Aug 2013, Copyright 2013 The MathWorks, Inc.
	% Modified for use with PTB
	
	properties
		nPins = 13 % number of controllable pins
	end
	
	properties (SetAccess=private,GetAccess=public)
		port   % the assigned port
		conn   % Serial Connection
		pins   % Pin Status Vector
		srvs   % Servo Status Vector
		mspd   % DC Motors Speed Status
		sspd   % Stepper Motors Speed Status
		encs   % Encoders Status
		sktc   % Motor Server Running on the Arduino Board
		isDemo = false
	end
	
	methods
		
		% constructor, connects to the board and creates an arduino object
		function a=arduinoIOPort(port,nPins)
			
			% check nargin
			if nargin<1
				port='DEMO';
				a.isDemo = true;
				disp('Note: a DEMO connection will be created');
				disp('Use a com port, e.g. ''/dev/ttyACM0'' as input argument to connect to the real board');
			elseif nargin == 2
				a.nPins = nPins;
			end
			
			% check port
			if ~ischar(port)
				error('The input argument must be a string, e.g. ''/dev/ttyACM0'' ');
			end
			
			if strcmp(port,'DEMO')
				a.isDemo = true;
				return
			end
			
			allPorts = serialportlist('all');
			avPorts = serialportlist('available');

			fprintf('===> All possible serial ports:\n');
			fprintf('%s\n',allPorts);
			
			if any(strcmpi(allPorts,port))
				fprintf('===> Your specified port is present\n')
			else
				error('===> No port with the specified name is present on the system!');
			end
			
			if any(strcmpi(avPorts,port))
				fprintf('===> Your specified port is available\n')
			else
				error('===> The port is occupied, please release it first!');
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
			r = [];
			tout = [];
			t = GetSecs;
			while isempty(r) && GetSecs < t+1
				IOPort('Write',a.conn,'99'); % our command to query the sketch type
				pause(0.1);
				if IOPort('BytesAvailable',a.conn) > 0
					r = IOPort('Read',a.conn);
					tout = GetSecs - t;
				end
			end
			a.sktc = r(1);
			fprintf('===> It took %.3f secs to establish response: %i...\n',tout,a.sktc);
			
			% exit if there was no answer
			if isempty(a.sktc)
				IOPort('CloseAll');
				delete(a.conn);
				delete(a);
				error('Connection unsuccessful, please make sure that the board is powered on, running a sketch provided with the package, and connected to the indicated serial port. You might also try to unplug and re-plug the USB cable before attempting a reconnection.');
			end
				
			
			% check returned value
			if a.sktc==48
				disp('===> Basic Analog and Digital I/O (adio.pde) sketch detected !');
			elseif a.sktc==49
				disp('===> Analog & Digital I/O + Encoders (adioe.pde) sketch detected !');
			elseif a.sktc==50
				disp('===> Analog & Digital I/O + Encoders + Servos (adioes.pde) sketch detected !');
			elseif a.sktc==51
				disp('===> Motor Shield V1 (plus adioes.pde functions) sketch detected !');
			elseif a.sktc==52
				disp('===> Motor Shield V2 (plus adioes.pde functions) sketch detected !');
			else
				IOPort('CloseAll')
				error('Unknown sketch. Please make sure that a sketch provided with the package is running on the board');
			end
			
			% initialize pin vector (-1 is unassigned, 0 is input, 1 is output)
			a.pins=-1*ones(1,a.nPins);
			
			% initialize servo vector (0 is detached, 1 is attached)
			a.srvs=0*ones(1,a.nPins);
			
			% initialize encoder vector (0 is detached, 1 is attached)
			a.encs=0*ones(1,3);
			
			% initialize motor vector (0 to 255 is the speed)
			a.mspd=0*ones(1,4);
			
			% initialize stepper vector (0 to 255 is the speed)
			a.sspd=0*ones(1,2);
			
			a.flush();
			for i=2:a.nPins
				a.pinMode(i,'output');
				a.digitalWrite(i,0);
			end
			
			% notify successful installation
			a.port = port;
			disp(['===> Arduino successfully connected to port ' a.port '!']);
			
		end % arduino
		
		% destructor, deletes the object
		function delete(a)
			try
				for i=2:a.nPins
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

			disp(['Arduino object connected to ' a.port ' port']);
			if a.sktc==4
				disp('Motor Shield sketch V2 (plus adioes.pde functions) running on the board');
				disp(' ');
				disp(' ');
				disp('Servo Methods: <a href="matlab:help servoStatus">servoStatus</a> <a href="matlab:help servoAttach">servoAttach</a> <a href="matlab:help servoDetach">servoDetach</a> <a href="matlab:help servoRead">servoRead</a> <a href="matlab:help servoWrite">servoWrite</a>');
				disp(' ');
				disp(' ');
				disp('Encoder Methods: <a href="matlab:help encoderStatus">encoderStatus</a> <a href="matlab:help encoderAttach">encoderAttach</a> <a href="matlab:help encoderDetach">encoderDetach</a> <a href="matlab:help encoderRead">encoderRead</a> <a href="matlab:help encoderReset">encoderReset</a>');
				disp(' ');
				disp(' ');
				disp('DC Motor and Steppers Methods: <a href="matlab:help motorSpeed">motorSpeed</a> <a href="matlab:help motorRun">motorRun</a> <a href="matlab:help stepperSpeed">stepperSpeed</a> <a href="matlab:help stepperStep">stepperStep</a>');
				disp(' ');
				disp('Serial port and other Methods: <a href="matlab:help serial">serial</a> <a href="matlab:help flush">flush</a> <a href="matlab:help roundTrip">roundTrip</a>');
			elseif a.sktc==3
				disp('Motor Shield sketch V1 (plus adioes.pde functions) running on the board');
				disp(' ');
				disp(' ');
				disp('Servo Methods: <a href="matlab:help servoStatus">servoStatus</a> <a href="matlab:help servoAttach">servoAttach</a> <a href="matlab:help servoDetach">servoDetach</a> <a href="matlab:help servoRead">servoRead</a> <a href="matlab:help servoWrite">servoWrite</a>');
				disp(' ');
				disp(' ');
				disp('Encoder Methods: <a href="matlab:help encoderStatus">encoderStatus</a> <a href="matlab:help encoderAttach">encoderAttach</a> <a href="matlab:help encoderDetach">encoderDetach</a> <a href="matlab:help encoderRead">encoderRead</a> <a href="matlab:help encoderReset">encoderReset</a>');
				disp(' ');
				disp(' ');
				disp('DC Motor and Steppers Methods: <a href="matlab:help motorSpeed">motorSpeed</a> <a href="matlab:help motorRun">motorRun</a> <a href="matlab:help stepperSpeed">stepperSpeed</a> <a href="matlab:help stepperStep">stepperStep</a>');
				disp(' ');
				disp('Serial port and other Methods: <a href="matlab:help serial">serial</a> <a href="matlab:help flush">flush</a> <a href="matlab:help roundTrip">roundTrip</a>');
			elseif a.sktc==2
				disp('Analog & Digital I/O + Encoders + Servos (adioes.pde) sketch running on the board');
				disp(' ');
				disp(' ');
				disp('Pin IO Methods: <a href="matlab:help pinMode">pinMode</a> <a href="matlab:help digitalRead">digitalRead</a> <a href="matlab:help digitalWrite">digitalWrite</a> <a href="matlab:help analogRead">analogRead</a> <a href="matlab:help analogWrite">analogWrite</a> <a href="matlab:help analogReference">analogReference</a>');
				disp(' ');
				disp(' ');
				disp('Servo Methods: <a href="matlab:help servoStatus">servoStatus</a> <a href="matlab:help servoAttach">servoAttach</a> <a href="matlab:help servoDetach">servoDetach</a> <a href="matlab:help servoRead">servoRead</a> <a href="matlab:help servoWrite">servoWrite</a>');
				disp(' ');
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
				disp(' ');
				disp('Encoder Methods: <a href="matlab:help encoderStatus">encoderStatus</a> <a href="matlab:help encoderAttach">encoderAttach</a> <a href="matlab:help encoderDetach">encoderDetach</a> <a href="matlab:help encoderRead">encoderRead</a> <a href="matlab:help encoderReset">encoderReset</a>');
				disp(' ');
				disp('Serial port and other Methods: <a href="matlab:help serial">serial</a> <a href="matlab:help flush">flush</a> <a href="matlab:help roundTrip">roundTrip</a>');
			else
				disp('Basic Analog & Digital I/O sketch (adio.pde) running on the board');
				disp(' ');
				disp(' ');
			end
		end
		
		% serial, returns the serial port
		function str=serial(a)

			% serial(a) (or a.serial), returns the name of the serial port
			% The first and only argument is the arduino object, the output
			% is a string containing the name of the serial port to which
			% the arduino board is connected (e.g. 'COM9', 'DEMO', or
			% '/dev/ttyS101'). The string 'Invalid' is returned if
			% the serial port is invalid

			if ~isempty(a.port)
				str=a.port;
			else
				str='Invalid';
			end
			
		end  % serial
		
		% flush, clears the pc's serial port buffer
		function flush(a)
			% val=flush(a) (or val=a.flush) reads all the bytes available
			% (if any) in the computer's serial port buffer, therefore
			% clearing said buffer.
			% The first and only argument is the arduino object, the
			% output is a vector of bytes that were still in the buffer.
			% The value '-1' is returned if the buffer was already empty.
			IOPort('Flush',a.conn);
		end  % flush
		
		% pin mode, changes pin mode
		function pinMode(a,pin,str)
			% pinMode(a,pin,str); reads or sets the I/O mode of a digital pin.
			% The first argument, a, is the arduino object.
			% The second argument, pin, is the number of the digital pin (2 to a.nPins).
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
				
			if lower(str(1))=='o'; val = 1; else; val = 0; end
			IOPort('Write',a.conn,uint8([48 97+pin 48+val]),1);
			a.pins(pin)=val;
			
		end % pinmode
		
		% digital read
		function val=digitalRead(a,pin)
			
			% val=digitalRead(a,pin); performs digital input on a given arduino pin.
			% The first argument, a, is the arduino object.
			% The second argument, pin, is the number of the digital pin (2 to a.nPins)
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
				
			IOPort('Write',a.conn,uint8([49 97+pin]),1);
			val=IOPort('Read',a.conn,1,1);
			
		end % digitalread
		
		%==========================================digital write
		function digitalWrite(a,pin,val)
			% digitalWrite(a,pin,val); performs digital output on a given pin.
			% The first argument, a, is the arduino object.
			% The second argument, pin, is the number of the digital pin
			% (2 to a.nPins) where the digital output value needs to be written.
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
			
			IOPort('Write',a.conn,uint8([50 97+pin 48+val]),1);
			
		end % digitalwrite
		
		%===================================================timedTTL
		function timedTTL(a,pin,time)
			% timedTTL(a, pin, time) -- this method allows us to send a
			% long low-high-low transition time (in ms) interval without blocking
			% matlab, using modified adio code.
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
			%%%%%%%%%%%%%%%%%%%%%%%%% ARGUMENT CHECKING %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
			
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
	
			%%%%%%%%%%%%%%%%%%%%%%%%% PERFORM ANALOG OUTPUT %%%%%%%%%%%%%%%%%%%%%%%%%%%
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
			
			%%%%%%%%%%%%%%%%%%%%%%%%% ARGUMENT CHECKING %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
			
			% check arguments if a.chkp is true
			if a.chkp,
				
				% check nargin
				if nargin~=2,
					error('Function must have the "reference" argument');
				end
				
				% check val
				errstr=arduinoLegacy.checkstr(str,'reference',{'default','internal','external'});
				if ~isempty(errstr), error(errstr); end
				
			end
			
			%%%%%%%%%%%%%%%%%%%% CHANGE ANALOG INPUT REFERENCE %%%%%%%%%%%%%%%%%%%%%%%%%
			
			if strcmpi(get(a.conn,'Port'),'DEMO'),
				% handle demo mode
				
				% minimum analog output delay
				pause(0.0014);
				
			else
				
				% check a.conn for openness if a.chks is true
				if a.chks,
					errstr=arduinoLegacy.checkser(a.conn,'open');
					if ~isempty(errstr), error(errstr); end
				end
				
				if lower(str(1))=='e', num=2;
				elseif lower(str(1))=='i', num=1;
				else num=0;
				end
				
				% send mode, pin and value
				IOPort('Write',a.conn,[82 48+num],'char');
				
			end
			
			
		end % analogreference
		
	end % methods
	
	methods (Static) % static methods
		
	end % static methods
	
end % class def