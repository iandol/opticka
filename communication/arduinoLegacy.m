classdef arduinoLegacy < handle
    
    % This class defines an "arduino" object
    % Giampiero Campa, Aug 2013, Copyright 2013 The MathWorks, Inc.
    
    properties (SetAccess=private,GetAccess=public)
        aser   % Serial Connection
        pins   % Pin Status Vector
        srvs   % Servo Status Vector
        mspd   % DC Motors Speed Status
        sspd   % Stepper Motors Speed Status
        encs   % Encoders Status
        sktc   % Motor Server Running on the Arduino Board
    end
    
    properties (Hidden=true)
        chks = false;  % Checks serial connection before every operation
        chkp = true;   % Checks parameters before every operation
    end
    
    methods
        
        % constructor, connects to the board and creates an arduino object
        function a=arduinoLegacy(comPort)
            
            % check nargin
            if nargin<1
                comPort='DEMO';
                disp('Note: a DEMO connection will be created');
                disp('Use a the com port, e.g. ''COM5'' as input argument to connect to the real board');
            end
            
            % check port
            if ~ischar(comPort)
                error('The input argument must be a string, e.g. ''COM8'' ');
            end
            
            % check if we are already connected
            if isa(a.aser,'serial') && isvalid(a.aser) && strcmpi(get(a.aser,'Status'),'open')
                disp(['It looks like a board is already connected to port ' comPort ]);
                disp('Delete the object to force disconnection');
                disp('before attempting a connection to a different port.');
                return;
            end
            
            % check whether serial port is currently used by MATLAB
            if ~isempty(instrfind({'Port'},{comPort}))
                disp(['The port ' comPort ' is already used by MATLAB']);
                disp(['If you are sure that the board is connected to ' comPort]);
                disp('then delete the object, execute:');
                disp(['  delete(instrfind({''Port''},{''' comPort '''}))']);
                disp('to delete the port, disconnect the cable, reconnect it,');
                disp('and then create a new arduino object');
                error(['Port ' comPort ' already used by MATLAB']);
            end
            
            % define serial object
            a.aser=serial(comPort,'BaudRate',115200);
            
            % connection
            if strcmpi(get(a.aser,'Port'),'DEMO')
                % handle demo mode
                
                fprintf(1,'Demo mode connection .');
                for i=1:6
                    pause(1);
                    fprintf(1,'.');
                end
                fprintf(1,'\n');
                
                % chk is equal to 4, (more general server running)
                a.sktc=4;
                
            else
                % actual connection
                
                % open port
                try
                    fopen(a.aser);
                catch ME
                    disp(ME.message)
                    delete(a);
                    error(['Could not open port: ' comPort]);
                end
                
                % it takes several seconds before any operation could be attempted
                fprintf(1,'Attempting connection .');
                for i=1:8
                    pause(0.8);
                    fprintf(1,'.');
                end
                fprintf(1,'\n');
                
                % flush serial buffer before sending anything
                flush(a);
                
                % query sketch type
                fwrite(a.aser,[57 57],'uchar');
                a.sktc=fscanf(a.aser,'%d');
                
                % exit if there was no answer
                if isempty(a.sktc)
                    delete(a);
                    error('Connection unsuccessful, please make sure that the board is powered on, running a sketch provided with the package, and connected to the indicated serial port. You might also try to unplug and re-plug the USB cable before attempting a reconnection.');
                end
                
            end
            
            % check returned value
            if a.sktc==0
                disp('Basic Analog and Digital I/O (adio.pde) sketch detected !');
            elseif a.sktc==1
                disp('Analog & Digital I/O + Encoders (adioe.pde) sketch detected !');
            elseif a.sktc==2
                disp('Analog & Digital I/O + Encoders + Servos (adioes.pde) sketch detected !');
            elseif a.sktc==3
                disp('Motor Shield V1 (plus adioes.pde functions) sketch detected !');
            elseif a.sktc==4
                disp('Motor Shield V2 (plus adioes.pde functions) sketch detected !');
            else
                delete(a);
                error('Unknown sketch. Please make sure that a sketch provided with the package is running on the board');
            end
            
            % set a.aser tag
            a.aser.Tag='ok';
            
            % initialize pin vector (-1 is unassigned, 0 is input, 1 is output)
            a.pins=-1*ones(1,69);
            
            % initialize servo vector (0 is detached, 1 is attached)
            a.srvs=0*ones(1,69);
            
            % initialize encoder vector (0 is detached, 1 is attached)
            a.encs=0*ones(1,3);
            
            % initialize motor vector (0 to 255 is the speed)
            a.mspd=0*ones(1,4);
            
            % initialize stepper vector (0 to 255 is the speed)
            a.sspd=0*ones(1,2);
            
            % notify successful installation
            disp('Arduino successfully connected !');
            
        end % arduino
        
        % destructor, deletes the object
        function delete(a)

            % Use delete(a) or a.delete to delete the arduino object
            
            % if it is a serial, valid and open then close it
            if isa(a.aser,'serial') && isvalid(a.aser) && strcmpi(get(a.aser,'Status'),'open'),
                if ~isempty(a.aser.Tag)
                    try
                        % trying to leave it in a known unharmful state
                        for i=2:69
                            a.pinMode(i,'output');
                            a.digitalWrite(i,0);
                            a.pinMode(i,'input');
                        end
                    catch ME
                        % disp but proceed anyway
                        disp(ME.message);
                        disp('Proceeding to deletion anyway');
                    end
                    
                end
                fclose(a.aser);
            end
            
            % if it's an object delete it
            if isobject(a.aser)
                delete(a.aser);
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
            
            if isvalid(a)
                if isa(a.aser,'serial') && isvalid(a.aser)
                    disp(['<a href="matlab:help arduino">arduino</a> object connected to ' a.aser.port ' port']);
                    if a.sktc==4
                        disp('Motor Shield sketch V2 (plus adioes.pde functions) running on the board');
                        disp(' ');
                        a.servoStatus
                        disp(' ');
                        disp('Servo Methods: <a href="matlab:help servoStatus">servoStatus</a> <a href="matlab:help servoAttach">servoAttach</a> <a href="matlab:help servoDetach">servoDetach</a> <a href="matlab:help servoRead">servoRead</a> <a href="matlab:help servoWrite">servoWrite</a>');
                        disp(' ');
                        a.encoderStatus
                        disp(' ');
                        disp('Encoder Methods: <a href="matlab:help encoderStatus">encoderStatus</a> <a href="matlab:help encoderAttach">encoderAttach</a> <a href="matlab:help encoderDetach">encoderDetach</a> <a href="matlab:help encoderRead">encoderRead</a> <a href="matlab:help encoderReset">encoderReset</a>');
                        disp(' ');
                        a.motorSpeed
                        a.stepperSpeed
                        disp(' ');
                        disp('DC Motor and Steppers Methods: <a href="matlab:help motorSpeed">motorSpeed</a> <a href="matlab:help motorRun">motorRun</a> <a href="matlab:help stepperSpeed">stepperSpeed</a> <a href="matlab:help stepperStep">stepperStep</a>');
                        disp(' ');
                        disp('Serial port and other Methods: <a href="matlab:help serial">serial</a> <a href="matlab:help flush">flush</a> <a href="matlab:help roundTrip">roundTrip</a>');
                    elseif a.sktc==3
                        disp('Motor Shield sketch V1 (plus adioes.pde functions) running on the board');
                        disp(' ');
                        a.servoStatus
                        disp(' ');
                        disp('Servo Methods: <a href="matlab:help servoStatus">servoStatus</a> <a href="matlab:help servoAttach">servoAttach</a> <a href="matlab:help servoDetach">servoDetach</a> <a href="matlab:help servoRead">servoRead</a> <a href="matlab:help servoWrite">servoWrite</a>');
                        disp(' ');
                        a.encoderStatus
                        disp(' ');
                        disp('Encoder Methods: <a href="matlab:help encoderStatus">encoderStatus</a> <a href="matlab:help encoderAttach">encoderAttach</a> <a href="matlab:help encoderDetach">encoderDetach</a> <a href="matlab:help encoderRead">encoderRead</a> <a href="matlab:help encoderReset">encoderReset</a>');
                        disp(' ');
                        a.motorSpeed
                        a.stepperSpeed
                        disp(' ');
                        disp('DC Motor and Steppers Methods: <a href="matlab:help motorSpeed">motorSpeed</a> <a href="matlab:help motorRun">motorRun</a> <a href="matlab:help stepperSpeed">stepperSpeed</a> <a href="matlab:help stepperStep">stepperStep</a>');
                        disp(' ');
                        disp('Serial port and other Methods: <a href="matlab:help serial">serial</a> <a href="matlab:help flush">flush</a> <a href="matlab:help roundTrip">roundTrip</a>');
                    elseif a.sktc==2
                        disp('Analog & Digital I/O + Encoders + Servos (adioes.pde) sketch running on the board');
                        disp(' ');
                        a.pinMode
                        disp(' ');
                        disp('Pin IO Methods: <a href="matlab:help pinMode">pinMode</a> <a href="matlab:help digitalRead">digitalRead</a> <a href="matlab:help digitalWrite">digitalWrite</a> <a href="matlab:help analogRead">analogRead</a> <a href="matlab:help analogWrite">analogWrite</a> <a href="matlab:help analogReference">analogReference</a>');
                        disp(' ');
                        a.servoStatus
                        disp(' ');
                        disp('Servo Methods: <a href="matlab:help servoStatus">servoStatus</a> <a href="matlab:help servoAttach">servoAttach</a> <a href="matlab:help servoDetach">servoDetach</a> <a href="matlab:help servoRead">servoRead</a> <a href="matlab:help servoWrite">servoWrite</a>');
                        disp(' ');
                        a.encoderStatus
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
                        a.encoderStatus
                        disp(' ');
                        disp('Encoder Methods: <a href="matlab:help encoderStatus">encoderStatus</a> <a href="matlab:help encoderAttach">encoderAttach</a> <a href="matlab:help encoderDetach">encoderDetach</a> <a href="matlab:help encoderRead">encoderRead</a> <a href="matlab:help encoderReset">encoderReset</a>');
                        disp(' ');
                        disp('Serial port and other Methods: <a href="matlab:help serial">serial</a> <a href="matlab:help flush">flush</a> <a href="matlab:help roundTrip">roundTrip</a>');
                    else
                        disp('Basic Analog & Digital I/O sketch (adio.pde) running on the board');
                        disp(' ');
                        a.pinMode
                        disp(' ');
                        disp('Pin IO Methods: <a href="matlab:help pinMode">pinMode</a> <a href="matlab:help digitalRead">digitalRead</a> <a href="matlab:help digitalWrite">digitalWrite</a> <a href="matlab:help analogRead">analogRead</a> <a href="matlab:help analogWrite">analogWrite</a> <a href="matlab:help analogReference">analogReference</a>');
                        disp(' ');
                        disp('Serial port and other Methods: <a href="matlab:help serial">serial</a> <a href="matlab:help flush">flush</a> <a href="matlab:help roundTrip">roundTrip</a>');
                    end
                    disp(' ');
                else
                    disp('<a href="matlab:help arduino">arduino</a> object connected to an invalid serial port');
                    disp('Please delete the arduino object');
                    disp(' ');
                end
            else
                disp('Invalid <a href="matlab:help arduino">arduino</a> object');
                disp('Please clear the object and instantiate another one');
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
            
            if isvalid(a.aser)
                str=a.aser.port;
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
            
            val=-1;
            if a.aser.BytesAvailable>0
                val=fread(a.aser,a.aser.BytesAvailable);
            end
        end  % flush
        
        % pin mode, changes pin mode
        function pinMode(a,pin,str)
            
            % pinMode(a,pin,str); reads or sets the I/O mode of a digital pin.
            % The first argument, a, is the arduino object.
            % The second argument, pin, is the number of the digital pin (2 to 69).
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
            
            % check arguments if a.chkp is true
            if a.chkp
                
                % check nargin
                if nargin>3
                    error('This function cannot have more than 3 arguments, object, pin and str');
                end
                
                % if pin argument is there check it
                if nargin>1
                    errstr=arduinoLegacy.checknum(pin,'pin number',2:69);
                    if ~isempty(errstr), error(errstr); end
                end
                
                % if str argument is there check it
                if nargin>2
                    errstr=arduinoLegacy.checkstr(str,'pin mode',{'input','output'});
                    if ~isempty(errstr), error(errstr); end
                end
                
            end
            
            % perform the requested action
            if nargin==3
                
                % check a.aser for validity if a.chks is true
                if a.chks
                    errstr=arduinoLegacy.checkser(a.aser,'valid');
                    if ~isempty(errstr), error(errstr); end
                end
                
                %%%%%%%%%%%%%%%%%%%%%%%%% CHANGE PIN MODE %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                
                % assign value
                if lower(str(1))=='o', val=1; else val=0; end
                
                if strcmpi(get(a.aser,'Port'),'DEMO')
                    % handle demo mode here
                    
                    % minimum digital output delay
                    pause(0.0014);
                    
                else
                    % do the actual action here
                    
                    % check a.aser for openness if a.chks is true
                    if a.chks
                        errstr=arduinoLegacy.checkser(a.aser,'open');
                        if ~isempty(errstr), error(errstr); end
                    end
                    
                    % send mode, pin and value
                    fwrite(a.aser,[48 97+pin 48+val],'uchar');
                    
                end
                
                % silently detach servos on the correspinding pin
                tmp=a.chkp;
                a.chkp=0;
                a.servoDetach(pin);
                a.chkp=tmp;
                
                % store 0 for input and 1 for output
                a.pins(pin)=val;
                
            elseif nargin==2
                % print pin mode for the requested pin
                
                mode={'UNASSIGNED','set as INPUT','set as OUTPUT'};
                disp(['Digital Pin ' num2str(pin) ' is currently ' mode{2+a.pins(pin)}]);
                
            else
                % print pin mode for each pin
                
                mode={'UNASSIGNED','set as INPUT','set as OUTPUT'};
                for i=2:69
                    disp(['Digital Pin ' num2str(i,'%02d') ' is currently ' mode{2+a.pins(i)}]);
                end
                
            end
            
        end % pinmode
        
        % digital read
        function val=digitalRead(a,pin)
            
            % val=digitalRead(a,pin); performs digital input on a given arduino pin.
            % The first argument, a, is the arduino object.
            % The second argument, pin, is the number of the digital pin (2 to 69)
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

            %%%%%%%%%%%%%%%%%%%%%%%%% ARGUMENT CHECKING %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            % check arguments if a.chkp is true
            if a.chkp
                
                % check nargin
                if nargin~=2
                    error('Function must have the "pin" argument');
                end
                
                % check pin
                errstr=arduinoLegacy.checknum(pin,'pin number',2:69);
                if ~isempty(errstr), error(errstr); end
                
            end
            
            % check a.aser for validity if a.chks is true
            if a.chks
                errstr=arduinoLegacy.checkser(a.aser,'valid');
                if ~isempty(errstr), error(errstr); end
            end
            
            %%%%%%%%%%%%%%%%%%%%%%%%% PERFORM DIGITAL INPUT %%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            if strcmpi(get(a.aser,'Port'),'DEMO')
                % handle demo mode
                
                % minimum digital input delay
                pause(0.0074);
                
                % output 0 or 1 randomly
                val=round(rand);
                
            else
                
                % check a.aser for openness if a.chks is true
                if a.chks
                    errstr=arduinoLegacy.checkser(a.aser,'open');
                    if ~isempty(errstr), error(errstr); end
                end
                
                % send mode and pin
                fwrite(a.aser,[49 97+pin],'uchar');
                
                % get value
                val=fscanf(a.aser,'%d');
                
            end
            
        end % digitalread
        
        %==========================================digital write
        function digitalWrite(a,pin,val)
            % digitalWrite(a,pin,val); performs digital output on a given pin.
            % The first argument, a, is the arduino object.
            % The second argument, pin, is the number of the digital pin 
            % (2 to 69) where the digital output value needs to be written.
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
            
            %%%%%%%%%%%%%%%%%%%%%%%%% ARGUMENT CHECKING %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % check arguments if a.chkp is true
            if a.chkp 
                % check nargin
                if nargin~=3
                    error('Function must have the "pin" and "val" arguments');
					 end
                % check pin
                errstr=arduinoLegacy.checknum(pin,'pin number',2:69);
                if ~isempty(errstr), error(errstr); end
                % check val
                errstr=arduinoLegacy.checknum(val,'value',0:1);
                if ~isempty(errstr), error(errstr); end
                % get object name
                if isempty(inputname(1)), name='object'; else name=inputname(1); end
                % pin should be configured as output
                if a.pins(pin)~=1
                    warning('MATLAB:Arduino:digitalWrite',['If digital pin ' num2str(pin) ' is set as input, digital output takes place only after using ' name' '.pinMode(' num2str(pin) ',''output''); ']);
					 end
            end
            
            % check a.aser for validity if a.chks is true
            if a.chks
                errstr=arduinoLegacy.checkser(a.aser,'valid');
                if ~isempty(errstr), error(errstr); end
            end
            
            %%%%%%%%%%%%%%%%%%%%%%%%% PERFORM DIGITAL OUTPUT %%%%%%%%%%%%%%%%%%%%%%%%%%
            if strcmpi(get(a.aser,'Port'),'DEMO')
                % handle demo mode      
                % minimum digital output delay
                pause(0.0014); 
				else    
                % check a.aser for openness if a.chks is true
                if a.chks
                    errstr=arduinoLegacy.checkser(a.aser,'open');
                    if ~isempty(errstr), error(errstr); end
					 end
                % send mode, pin and value
                fwrite(a.aser,[50 97+pin 48+val],'uchar');
				end 
        end % digitalwrite
		  
		  %===================================================timedTTL
		  function timedTTL(a,pin,time)
			  %timedTTL(a, pin, time)
			  if a.chkp
				  if ~exist('pin','var') || isempty(pin); pin = 13;end
				  if ~exist('time','var') || isempty(time); time = 500;end
				  % check pin
				  errstr=arduinoLegacy.checknum(pin,'analog input pin number',0:15);
				  if ~isempty(errstr), error(errstr); end
			  end
			  % check a.aser for validity if a.chks is true
			  if a.chks
				  errstr=arduinoLegacy.checkser(a.aser,'valid');
				  if ~isempty(errstr), error(errstr); end
			  end
			  %%%%%%%%%%%%%%%%%%%%%%%%% PERFORM DIGITAL OUTPUT %%%%%%%%%%%%%%%%%%%%%%%%%%%%
			  if strcmpi(get(a.aser,'Port'),'DEMO')
				  % handle demo mode
				  % minimum analog input delay
				  pause(0.0074);
				  % output a random value between 0 and 1023
				  val=round(1023*rand);
			  else
				  % check a.aser for openness if a.chks is true
				  if a.chks
					  errstr=arduinoLegacy.checkser(a.aser,'open');
					  if ~isempty(errstr), error(errstr); end
				  end
				  if time < 0; time = 0; end
				  if time > 2550; time = 2550; end
				  time = round(time/10);
				  % send mode and pin
				  fwrite(a.aser,[53 97+pin time],'uchar');
			  end
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
            
            % check arguments if a.chkp is true
            if a.chkp
                
                % check nargin
                if nargin~=2
                    error('Function must have the "pin" argument');
                end
                
                % check pin
                errstr=arduinoLegacy.checknum(pin,'analog input pin number',0:15);
                if ~isempty(errstr), error(errstr); end
                
            end
            
            % check a.aser for validity if a.chks is true
            if a.chks
                errstr=arduinoLegacy.checkser(a.aser,'valid');
                if ~isempty(errstr), error(errstr); end
            end
            
            %%%%%%%%%%%%%%%%%%%%%%%%% PERFORM ANALOG INPUT %%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            if strcmpi(get(a.aser,'Port'),'DEMO')
                % handle demo mode
                
                % minimum analog input delay
                pause(0.0074);
                
                % output a random value between 0 and 1023
                val=round(1023*rand);
                
            else
                
                % check a.aser for openness if a.chks is true
                if a.chks
                    errstr=arduinoLegacy.checkser(a.aser,'open');
                    if ~isempty(errstr), error(errstr); end
                end
                
                % send mode and pin
                fwrite(a.aser,[51 97+pin],'uchar');
                
                % get value
                val=fscanf(a.aser,'%d');
                
            end
            
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
            
            %%%%%%%%%%%%%%%%%%%%%%%%% ARGUMENT CHECKING %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            % check arguments if a.chkp is true
            if a.chkp
                
                % check nargin
                if nargin~=3
                    error('Function must have the "pin" and "val" arguments');
                end
                
                % check pin
                errstr=arduinoLegacy.checknum(pin,'pwm pin number',[2:13 44:46]);
                if ~isempty(errstr), error(errstr); end
                
                % check val
                errstr=arduinoLegacy.checknum(val,'analog output level',0:255);
                if ~isempty(errstr), error(errstr); end
                
            end
            
            % check a.aser for validity if a.chks is true
            if a.chks
                errstr=arduinoLegacy.checkser(a.aser,'valid');
                if ~isempty(errstr), error(errstr); end
            end
            
            %%%%%%%%%%%%%%%%%%%%%%%%% PERFORM ANALOG OUTPUT %%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            if strcmpi(get(a.aser,'Port'),'DEMO')
                % handle demo mode
                
                % minimum analog output delay
                pause(0.0014);
                
            else
                
                % check a.aser for openness if a.chks is true
                if a.chks
                    errstr=arduinoLegacy.checkser(a.aser,'open');
                    if ~isempty(errstr), error(errstr); end
                end
                
                % send mode, pin and value
                fwrite(a.aser,[52 97+pin val],'uchar');
                
            end
            
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
            
            % check a.aser for validity if a.chks is true
            if a.chks,
                errstr=arduinoLegacy.checkser(a.aser,'valid');
                if ~isempty(errstr), error(errstr); end
            end
            
            %%%%%%%%%%%%%%%%%%%% CHANGE ANALOG INPUT REFERENCE %%%%%%%%%%%%%%%%%%%%%%%%%
            
            if strcmpi(get(a.aser,'Port'),'DEMO'),
                % handle demo mode
                
                % minimum analog output delay
                pause(0.0014);
                
            else
                
                % check a.aser for openness if a.chks is true
                if a.chks,
                    errstr=arduinoLegacy.checkser(a.aser,'open');
                    if ~isempty(errstr), error(errstr); end
                end
                
                if lower(str(1))=='e', num=2;
                elseif lower(str(1))=='i', num=1;
                else num=0;
                end
                
                % send mode, pin and value
                fwrite(a.aser,[82 48+num],'uchar');
                
            end
            
            
        end % analogreference
        
        % servo attach
        function servoAttach(a,pin)
            
            % servoAttach(a,pin); or a.servoAttach(pin); attaches a servo to a pin.
            % The first argument, a, is the arduino object. The second argument, 
            % pin, is the number of the pwm pin where the servo must be attached 
            % (a servo has three pins, a central red one which goes to +5V,
            % a black or brown one which goes to ground, and a white or orange one 
            % which must be connected to an analog output (PWM) pin on the Arduino).
            %
            % Earlier versions of both Arduino boards and Arduino IO package supported
            % only pwm pins 9 and 10, now up to 12 different pins are supported on most
            % Arduino boards, and 48 on the Mega. Note that on boards other than the Mega,
            % use of the servos disables analogWrite() functionality on pins 9 and 10,
            % whether or not there is a Servo on those pins. On the Mega, up to 12 servos
            % can be used without interfering with PWM; use of 12 to 23 servos will
            % disable PWM on pins 11 and 12.
            % 
            % Note that motor shields typically have their own servo connectors,
            % For example the Adafruit Motor Shield V1 has 2 servo connector on
            % its top left corner, the one labeled "SER1" uses pin #10, 
            % while the one labeled "SERVO_2" uses the pin #9.
            % 
            % Examples:
            % servoAttach(a,10); % attaches servo on pin #10
            % a.servoAttach(10); % same as above (attaches servo on pin #10)
            %
            
            %%%%%%%%%%%%%%%%%%%%%%%%% ARGUMENT CHECKING %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            % check arguments if a.chkp is true
            if a.chkp,
                
                % check nargin
                if nargin~=2,
                    error('Function must have the "pin" argument');
                end
                
                % check pin
                errstr=arduinoLegacy.checknum(pin,'servo number',2:69);
                if ~isempty(errstr), error(errstr); end
                
            end
            
            % check a.aser for validity if a.chks is true
            if a.chks,
                errstr=arduinoLegacy.checkser(a.aser,'valid');
                if ~isempty(errstr), error(errstr); end
            end
            
            % warning if sketch is inadequate and a.chkp is true
            if a.chkp && a.sktc<2
                disp('Warning: the sketch running on the Arduino does not support servos');
                disp('No operation will be performed on the Arduino board');
            end
            
            %%%%%%%%%%%%%%%%%%%%%%%%% ATTACH SERVO %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            if strcmpi(get(a.aser,'Port'),'DEMO') || a.sktc<2,
                % handle demo mode
                
                % minimum digital output delay
                pause(0.0014);
                
            else
                
                % check a.aser for openness if a.chks is true
                if a.chks,
                    errstr=arduinoLegacy.checkser(a.aser,'open');
                    if ~isempty(errstr), error(errstr); end
                end
                
                % send mode, pin and value (1 for attach)
                fwrite(a.aser,[54 97+pin 48+1],'uchar');
                
            end
            
            % store the servo status
            a.srvs(pin)=1;
            
            % update pin status to unassigned
            a.pins(pin)=-1;
            
        end % servoattach
        
        % servo detach
        function servoDetach(a,pin)
            
            % servoDetach(a,pin); detaches a servo from its corresponding pwm pin.
            % The first argument, a, is the arduino object. The second argument, 
            % pin, is the number of the pin where the servo is attached
            % Earlier versions supported only pins 9 and 10, now up to 12 different 
            % pins are supported on most Arduino boards, and 48 on the Mega. 
            % Note that on boards other than the Mega, using the servos disables 
            % analogWrite() functionality on pins 9 and 10, whether or not there 
            % is a Servo on those pins. On the Mega, up to 12 servos can be used 
            % without interfering with PWM; use of 12 to 23 servos will 
            % disable PWM on pins 11 and 12.            
            %
            % Examples:
            % servoDetach(a,10); % detaches a servo attached on pin 10
            % a.servoDetach(10); % detaches a servo attached on pin 10
            %
            
            %%%%%%%%%%%%%%%%%%%%%%%%% ARGUMENT CHECKING %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            % check arguments if a.chkp is true
            if a.chkp,
                
                % check nargin
                if nargin~=2,
                    error('Function must have the "pin" argument');
                end
                
                % check servo number
                errstr=arduinoLegacy.checknum(pin,'servo number',2:69);
                if ~isempty(errstr), error(errstr); end
                
            end
            
            % check a.aser for validity if a.chks is true
            if a.chks,
                errstr=arduinoLegacy.checkser(a.aser,'valid');
                if ~isempty(errstr), error(errstr); end
            end
            
            % warning if sketch is inadequate and a.chkp is true
            if a.chkp && a.sktc<2
                disp('Warning: the sketch running on the Arduino does not support servos');
                disp('No operation will be performed on the Arduino board');
            end
            
            %%%%%%%%%%%%%%%%%%%%%%%%% DETACH SERVO %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            if strcmpi(get(a.aser,'Port'),'DEMO') || a.sktc<2,
                % handle demo mode
                
                % minimum digital output delay
                pause(0.0014);
                
            else
                
                % check a.aser for openness if a.chks is true
                if a.chks,
                    errstr=arduinoLegacy.checkser(a.aser,'open');
                    if ~isempty(errstr), error(errstr); end
                end
                
                % send mode, pin and value (0 for detach)
                fwrite(a.aser,[54 97+pin 48+0],'uchar');
                
            end
            
            a.srvs(pin)=0;
            
        end % servodetach
        
        % servo status
        function val=servoStatus(a,pin)
            
            % servoStatus(a,pin); Reads the status of a servo (attached/detached).
            % The first argument, a, is the arduino object. The second argument, 
            % pin, is the number of the pin where the servo is attached
            % Earlier versions supported only pins 9 and 10, now up to 12 different 
            % pins are supported on most Arduino boards, and 48 on the Mega.
            % The returned value is either 1 (servo attached) or 0 (servo detached).
            % Called without output arguments, the function prints a string specifying
            % the status of the servo. Called without input arguments, the function
            % either returns the status vector or prints the status of each servo.
            %
            % Examples:
            % val=servoStatus(a,10); % return the status of servo on pin #10
            % servoStatus(a,10); % prints the status of servo on pin #10
            % servoStatus(a); % prints the status of all servos
            % a.servoStatus; % prints the status of all servos
            %
            
            %%%%%%%%%%%%%%%%%%%%%%%%% ARGUMENT CHECKING %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            % check nargin if a.chkp is true
            if a.chkp,
                if nargin>2,
                    error('Function cannot have more than one argument (servo number) beyond the object name');
                end
            end
            
            % with no arguments calls itself recursively for all servos
            if nargin==1,
                if nargout>0,
                    val=zeros(69,1);
                    for i=2:69,
                        val(i)=a.servoStatus(i);
                    end
                    return
                else
                    for i=2:69,
                        a.servoStatus(i);
                    end
                    return
                end
            end
            
            % check servo number if a.chkp is true
            if a.chkp,
                errstr=arduinoLegacy.checknum(pin,'servo number',2:69);
                if ~isempty(errstr), error(errstr); end
            end
            
            % check a.aser for validity if a.chks is true
            if a.chks,
                errstr=arduinoLegacy.checkser(a.aser,'valid');
                if ~isempty(errstr), error(errstr); end
            end
            
            % warning if sketch is inadequate and a.chkp is true
            if a.chkp && a.sktc<2
                disp('Warning: the sketch running on the Arduino does not support servos');
                disp('No operation will be performed on the Arduino board');
            end
            
            %%%%%%%%%%%%%%%%%%%%%%%%% ASK SERVO STATUS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            if strcmpi(get(a.aser,'Port'),'DEMO') || a.sktc<2,
                % handle demo mode
                
                % minimum digital input delay
                pause(0.0074);
                
                % gets value from the servo state vector
                val=a.srvs(pin);
                
            else
                
                % check a.aser for openness if a.chks is true
                if a.chks,
                    errstr=arduinoLegacy.checkser(a.aser,'open');
                    if ~isempty(errstr), error(errstr); end
                end
                
                % send mode and pin
                fwrite(a.aser,[53 97+pin],'uchar');
                
                % get value
                val=fscanf(a.aser,'%d');
                
            end
            
            % updates the servo state vector
            a.srvs(pin)=val;
            
            if nargout==0,
                str={'DETACHED','ATTACHED'};
                disp(['Servo ' num2str(pin) ' is ' str{1+val}]);
                clear val
                return
            end
            
        end % servostatus
        
        % servo read
        function val=servoRead(a,pin)
            
            % val=servoRead(a,pin); reads the angle of a given servo.
            % The first argument, a, is the arduino object.
            % The second argument, pin, is the number of the pin where the servo is attached
            % Earlier versions supported only pins 9 and 10, now up to 12 different pins are
            % supported on most Arduino boards, and 48 on the Mega.
            % The returned value is the angle in degrees, typically from 0 to 180.
            % 
            % Note that this function returns random values in DEMO mode, 
            % or when a sketch that does not support servos is running on 
            % the Arduino board.
            %
            % Examples:
            % val=servoRead(a,10); % reads angle from servo on pin #10
            % val=a.servoRead(9); % reads angle from servo on pin #9
            %
            
            %%%%%%%%%%%%%%%%%%%%%%%%% ARGUMENT CHECKING %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            % check arguments if a.chkp is true
            if a.chkp,
                
                % check nargin
                if nargin~=2,
                    error('Function must have the servo number argument');
                end
                
                % check servo number
                errstr=arduinoLegacy.checknum(pin,'servo number',2:69);
                if ~isempty(errstr), error(errstr); end
                
                % get object name
                if isempty(inputname(1)), name='object'; else name=inputname(1); end
                
                % check status
                if a.srvs(pin)~=1,
                    error(['Servo ' num2str(pin) ' is not attached, please use ' name' '.servoAttach(' num2str(pin) ') to attach it']);
                end
                
            end
            
            % check a.aser for validity if a.chks is true
            if a.chks,
                errstr=arduinoLegacy.checkser(a.aser,'valid');
                if ~isempty(errstr), error(errstr); end
            end
            
            % warning if sketch is inadequate and a.chkp is true
            if a.chkp && a.sktc<2
                disp('Warning: the sketch running on the Arduino does not support servos');
                disp('A random value will be returned');
            end
            
            %%%%%%%%%%%%%%%%%%%%%%%%% READ SERVO ANGLE %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            if strcmpi(get(a.aser,'Port'),'DEMO') || a.sktc<2,
                % handle demo mode
                
                % minimum analog input delay
                pause(0.0074);
                
                % output a random value between 0 and 180
                val=round(180*rand);
                
            else
                
                % check a.aser for openness if a.chks is true
                if a.chks,
                    errstr=arduinoLegacy.checkser(a.aser,'open');
                    if ~isempty(errstr), error(errstr); end
                end
                
                % send mode and pin
                fwrite(a.aser,[55 97+pin],'uchar');
                
                % get value
                val=fscanf(a.aser,'%d');
                
            end
            
        end % servoread
        
        % servo write
        function servoWrite(a,pin,val)
            
            % servoWrite(a,pin,val); writes an angle on a given servo.
            % The first argument, a, is the arduino object.
            % The second argument, pin, is the number of the pin where the servo is attached
            % Earlier versions supported only pins 9 and 10, now up to 12 different pins are
            % supported on most Arduino boards, and 48 on the Mega.
            % The third argument is the angle in degrees, typically from 0 to 180.
            % 
            % Examples:
            % servoWrite(a,10,45); % rotates servo on pin #10 to 45 degrees
            % a.servoWrite(10,70); % rotates servo on pin #9 to 70 degrees
            %
            
            %%%%%%%%%%%%%%%%%%%%%%%%% ARGUMENT CHECKING %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            % check arguments if a.chkp is true
            if a.chkp,
                
                % check nargin
                if nargin~=3,
                    error('Function must have the servo number and angle arguments');
                end
                
                % check servo number
                errstr=arduinoLegacy.checknum(pin,'servo number',2:69);
                if ~isempty(errstr), error(errstr); end
                
                % check angle value
                errstr=arduinoLegacy.checknum(val,'angle',0:180);
                if ~isempty(errstr), error(errstr); end
                
                % get object name
                if isempty(inputname(1)), name='object'; else name=inputname(1); end
                
                % check status
                if a.srvs(pin)~=1,
                    error(['Servo ' num2str(pin) ' is not attached, please use ' name' '.servoAttach(' num2str(pin) ') to attach it']);
                end
                
            end
            
            % check a.aser for validity if a.chks is true
            if a.chks,
                errstr=arduinoLegacy.checkser(a.aser,'valid');
                if ~isempty(errstr), error(errstr); end
            end
            
            % warning if sketch is inadequate and a.chkp is true
            if a.chkp && a.sktc<2
                disp('Warning: the sketch running on the Arduino does not support servos');
                disp('No operation will be performed on the Arduino board');
            end
            
            %%%%%%%%%%%%%%%%%%%%%%%%% WRITE ANGLE TO SERVO %%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            if strcmpi(get(a.aser,'Port'),'DEMO') || a.sktc<2,
                % handle demo mode
                
                % minimum analog output delay
                pause(0.0014);
                
            else
                
                % check a.aser for openness if a.chks is true
                if a.chks,
                    errstr=arduinoLegacy.checkser(a.aser,'open');
                    if ~isempty(errstr), error(errstr); end
                end
                
                % send mode, pin and value
                fwrite(a.aser,[56 97+pin val],'uchar');
                
            end
            
        end % servowrite
        
        % encoder attach
        function encoderAttach(a,enc,pinA,pinB)
            
            % encoderAttach(a,enc,pinA,pinB); attaches an encoder to 2 pins.
            % The first argument, a, is the arduino object.
            % The second argument is the encoder's number, either 0,1 or 2.
            % The third and fourth arguments, pinA and pinB, are the number of 
            % the pins where the encoder's pinA and pinB are attached (the
            % "common" pin a.k.a. pinC should be attached to the ground).
            % 
            % Note that, since this methods relies on attaching interrupt
            % service routines to the specified pins, the allowed pins for
            % encoder attachment are only 2,3,18,19,20,21 (see also
            % http://arduino.cc/it/Reference/AttachInterrupt for details).
            % Also note that, to avoid interferences, this function disables
            % any output and servo functionality for the attached pins.
            %
            % Examples:
            % encoderAttach(a,0,2,3); % attaches encoder #0 on pins 2 and 3
            % a.encoderAttach(1,18,19); % attaches encoder #1 on pins 18 and 19
            %
            
            %%%%%%%%%%%%%%%%%%%%%%%%% ARGUMENT CHECKING %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            % check arguments if a.chkp is true
            if a.chkp,
                
                % check nargin
                if nargin~=4,
                    error('Function must have the encoder number, pin A and pin B arguments');
                end
                
                % check encoder number
                errstr=arduinoLegacy.checknum(enc,'encoder number',0:2);
                if ~isempty(errstr), error(errstr); end
                
                % check pin A
                errstr=arduinoLegacy.checknum(pinA,'pin A',[2 3 19 18 21 20]);
                if ~isempty(errstr), error(errstr); end
                
                % check pin B
                errstr=arduinoLegacy.checknum(pinB,'pin B',[2 3 19 18 21 20]);
                if ~isempty(errstr), error(errstr); end
                
            end
            
            % check a.aser for validity if a.chks is true
            if a.chks,
                errstr=arduinoLegacy.checkser(a.aser,'valid');
                if ~isempty(errstr), error(errstr); end
            end
            
            % warning if sketch is inadequate and a.chkp is true
            if a.chkp && a.sktc<1
                disp('Warning: the sketch running on the Arduino does not support encoders');
                disp('No operation will be performed on the Arduino board');
            end
            
            % silently detach servos on the correspinding pins
            tmp=a.chkp;
            a.chkp=0;
            a.servoDetach(pinA);
            a.servoDetach(pinB);
            a.chkp=tmp;
            
            %%%%%%%%%%%%%%%%%%%%%%%%% ATTACH ENCODER %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            if strcmpi(get(a.aser,'Port'),'DEMO') || a.sktc<1,
                % handle demo mode
                
                % minimum analog write delay
                pause(0.0014);
                
            else
                
                % check a.aser for openness if a.chks is true
                if a.chks,
                    errstr=arduinoLegacy.checkser(a.aser,'open');
                    if ~isempty(errstr), error(errstr); end
                end
                
                % send mode, encoder and pins
                fwrite(a.aser,[69 48+enc 97+pinA 97+pinB],'uchar');
                
            end
            
            % store the encoder status
            a.encs(1+enc)=1;
            
            % update pin status to input
            a.pins([pinA pinB])=[0 0];
            
        end % encoderattach
        
        % encoder detach
        function encoderDetach(a,enc)
            
            % encoderDetach(a,enc); detaches an encoder from its pins.
            % The first argument before the function name, a, is the arduino object.
            % The second argument, enc, is the number of the encoder to
            % be detached (0, 1, or 2). This also detaches any interrupt
            % routine previously attached to the specified pins.
            %
            % Examples:
            % encoderDetach(a,0); % detach encoder #0
            % a.encoderDetach(1); % detach encoder #1
            %
            
            %%%%%%%%%%%%%%%%%%%%%%%%% ARGUMENT CHECKING %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            % check arguments if a.chkp is true
            if a.chkp,
                
                % check nargin
                if nargin~=2,
                    error('Function must have the encoder number argument');
                end
                
                % check encoder number
                errstr=arduinoLegacy.checknum(enc,'encoder number',0:2);
                if ~isempty(errstr), error(errstr); end
                
            end
            
            % check a.aser for validity if a.chks is true
            if a.chks,
                errstr=arduinoLegacy.checkser(a.aser,'valid');
                if ~isempty(errstr), error(errstr); end
            end
            
            % warning if sketch is inadequate and a.chkp is true
            if a.chkp && a.sktc<1
                disp('Warning: the sketch running on the Arduino does not support encoders');
                disp('No operation will be performed on the Arduino board');
            end
            
            %%%%%%%%%%%%%%%%%%%%%%%%% DETACH ENCODER %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            if strcmpi(get(a.aser,'Port'),'DEMO') || a.sktc<1,
                % handle demo mode
                
                % minimum digital output delay
                pause(0.0014);
                
            else
                
                % check a.aser for openness if a.chks is true
                if a.chks,
                    errstr=arduinoLegacy.checkser(a.aser,'open');
                    if ~isempty(errstr), error(errstr); end
                end
                
                % send mode, encoder and value
                fwrite(a.aser,[70 48+enc],'uchar');
                
            end
            
            a.encs(1+enc)=0;
            
        end % encoderdetach
        
        % encoder status
        function val=encoderStatus(a,enc)
            
            % encoderStatus(a,enc); Reads the status of an encoder (attached/detached).
            % The first argument, a, is the arduino object. The second argument, enc, 
            % is the number of the encoder (0 to 2) which status needs to be read.
            % The returned value is either 1 (encoder attached) or 0 (encoder detached).
            % Called without output arguments, the function prints a string specifying
            % the status of the encoder. Called without input arguments, the function
            % either returns the status vector or prints the status of each encoder.
            %
            % Examples:
            % val=encoderStatus(a,0); % return the status of encoder #0
            % encoderStatus(a,2); % prints the status of encoder #2
            % encoderStatus(a); % prints the status of all encoders
            % a.encoderStatus; % prints the status of all encoders
            %
            
            %%%%%%%%%%%%%%%%%%%%%%%%% ARGUMENT CHECKING %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            % check nargin if a.chkp is true
            if a.chkp,
                if nargin>2,
                    error('Function cannot have more than one argument (encoder number) beyond the object name');
                end
            end
            
            % with no arguments calls itself recursively for all encoders
            if nargin==1,
                if nargout>0,
                    val=zeros(3,1);
                    for i=0:2,
                        val(i+1)=a.encoderStatus(i);
                    end
                    return
                else
                    for i=0:2,
                        a.encoderStatus(i);
                    end
                    return
                end
            end
            
            % check encoder number if a.chkp is true
            if a.chkp,
                errstr=arduinoLegacy.checknum(enc,'encoder number',0:2);
                if ~isempty(errstr), error(errstr); end
            end
            
            % gets value from the encoder state vector
            val=a.encs(1+enc);
            
            if nargout==0,
                str={'DETACHED','ATTACHED'};
                disp(['Encoder ' num2str(enc) ' is ' str{1+val}]);
                clear val
                return
            end
            
        end % encoderstatus
        
        % encoder read
        function val=encoderRead(a,enc)
            
            % val=encoderRead(a,enc); reads the position of a given encoder.
            % The first argument, a, is the arduino object.
            % The second argument, enc, is the encoder number (0 to 2).
            % The returned value is the position in steps, where clockwise
            % rotation are assumed positive by convention.
            % 
            % Note that this function returns random values in DEMO mode, 
            % or when a sketch that does not support encoders is running on 
            % the Arduino board.
            %
            % Examples:
            % val=encoderRead(a,2); % reads angle from encoder #2
            % val=a.encoderRead(0); % reads angle from encoder #0
            %
            
            %%%%%%%%%%%%%%%%%%%%%%%%% ARGUMENT CHECKING %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            % check arguments if a.chkp is true
            if a.chkp,
                
                % check nargin
                if nargin~=2,
                    error('Function must have the encoder number argument');
                end
                
                % check encoder number
                errstr=arduinoLegacy.checknum(enc,'encoder number',0:2);
                if ~isempty(errstr), error(errstr); end
                
                % get object name
                if isempty(inputname(1)), name='object'; else name=inputname(1); end
                
                % check status
                if a.encs(1+enc)~=1,
                    error(['Encoder ' num2str(enc) ' is not attached, please use ' name' '.encoderAttach(' num2str(enc) ') to attach it']);
                end
                
            end
            
            % check a.aser for validity if a.chks is true
            if a.chks,
                errstr=arduinoLegacy.checkser(a.aser,'valid');
                if ~isempty(errstr), error(errstr); end
            end
            
            % warning if sketch is inadequate and a.chkp is true
            if a.chkp && a.sktc<1
                disp('Warning: the sketch running on the Arduino does not support encoders');
                disp('A random value will be returned');
            end
            
            %%%%%%%%%%%%%%%%%%%%%%%%% READ ENCODER POSITION %%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            if strcmpi(get(a.aser,'Port'),'DEMO') || a.sktc<1,
                % handle demo mode
                
                % minimum analog input delay
                pause(0.0074);
                
                % output a random value between -32768 to 32767
                val=round(2*32768*rand-32768);
                
            else
                
                % check a.aser for openness if a.chks is true
                if a.chks,
                    errstr=arduinoLegacy.checkser(a.aser,'open');
                    if ~isempty(errstr), error(errstr); end
                end
                
                % send mode and enc
                fwrite(a.aser,[71 48+enc],'uchar');
                
                % get value
                val=fscanf(a.aser,'%d');
                
            end
            
        end % encoderread
        
        % encoder reset
        function encoderReset(a,enc)
            
            % encoderReset(a,enc); resets the position of a given encoder.
            % The first argument, a, is the arduino object.
            % The second argument, enc, is the number of the encoder (0 to 2).
            %
            % Examples:
            % encoderReset(a,1); % resets encoder #1
            % a.encoderReset(2); % resets encoder #2
            %
            
            %%%%%%%%%%%%%%%%%%%%%%%%% ARGUMENT CHECKING %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            % check arguments if a.chkp is true
            if a.chkp,
                
                % check nargin
                if nargin~=2,
                    error('Function must have the encoder number argument');
                end
                
                % check encoder number
                errstr=arduinoLegacy.checknum(enc,'encoder number',0:2);
                if ~isempty(errstr), error(errstr); end
                
                % get object name
                if isempty(inputname(1)), name='object'; else name=inputname(1); end
                
                % check status
                if a.encs(1+enc)~=1,
                    error(['Encoder ' num2str(enc) ' is not attached, please use ' name' '.encoderAttach(' num2str(enc) ') to attach it']);
                end
                
            end
            
            % check a.aser for validity if a.chks is true
            if a.chks,
                errstr=arduinoLegacy.checkser(a.aser,'valid');
                if ~isempty(errstr), error(errstr); end
            end
            
            % warning if sketch is inadequate and a.chkp is true
            if a.chkp && a.sktc<1
                disp('Warning: the sketch running on the Arduino does not support encoders');
                disp('No operation will be performed on the Arduino board');
            end
            
            %%%%%%%%%%%%%%%%%%%%%%%%% RESET ENCODER POSITION %%%%%%%%%%%%%%%%%%%%%%%%%%
            
            if strcmpi(get(a.aser,'Port'),'DEMO') || a.sktc<1,
                % handle demo mode
                
                % minimum analog output delay
                pause(0.0014);
                
            else
                
                % check a.aser for openness if a.chks is true
                if a.chks,
                    errstr=arduinoLegacy.checkser(a.aser,'open');
                    if ~isempty(errstr), error(errstr); end
                end
                
                % send mode and encoder number
                fwrite(a.aser,[72 48+enc],'uchar');
                
            end
            
        end % encoderreset
        
        % encoder attach
        function encoderDebounce(a,enc,del)
            
            % encoderDebounce(a,enc,del); sets debounce delay for an encoder.
            % The first argument, a, is the arduino object.
            % The second argument is the encoder's number, either 0,1 or 2.
            % The third argument, del, is the debounce delay (in units of
            % approximately 0.1 ms each) between the instant in which an 
            % interrupt is triggered on either pinA or pinB and the instant
            % in which the status (HIGH or LOW) of the corresponding pin is
            % actually read to understand the rotation direction.
            % 
            % Note that this delay will limit the maximum rotation rate that
            % can be detected, so use it only if you know what you are doing.
            % Possible values go from 0 (no delay) to 69 (6.9 ms). In general, 
            % it is suggested to keep this value no higher than 20 (2 ms). 
            %
            % Examples:
            % encoderDebounce(a,0,20); % sets a delay of 20 for encoder #0
            % a.encoderDebounce(1,17); % sets a delay of 17 for encoder #1
            %
            
            %%%%%%%%%%%%%%%%%%%%%%%%% ARGUMENT CHECKING %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            % check arguments if a.chkp is true
            if a.chkp,
                
                % check nargin
                if nargin~=3,
                    error('Function must have both the encoder number and the delay value as arguments');
                end
                
                % check encoder number
                errstr=arduinoLegacy.checknum(enc,'encoder number',0:2);
                if ~isempty(errstr), error(errstr); end
                
                % check delay value
                errstr=arduinoLegacy.checknum(del,'del',0:69);
                if ~isempty(errstr), error(errstr); end
                
                % get object name
                if isempty(inputname(1)), name='object'; else name=inputname(1); end
                
                % check status
                if a.encs(1+enc)~=1,
                    error(['Encoder ' num2str(enc) ' is not attached, please use ' name' '.encoderAttach(' num2str(enc) ') to attach it']);
                end
                                
            end
            
            % check a.aser for validity if a.chks is true
            if a.chks,
                errstr=arduinoLegacy.checkser(a.aser,'valid');
                if ~isempty(errstr), error(errstr); end
            end
            
            % warning if sketch is inadequate and a.chkp is true
            if a.chkp && a.sktc<1
                disp('Warning: the sketch running on the Arduino does not support encoders');
                disp('No operation will be performed on the Arduino board');
            end
            
            %%%%%%%%%%%%%%%%%%%%%%%%% SETS DEBOUNCE DELAY %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            if strcmpi(get(a.aser,'Port'),'DEMO') || a.sktc<1,
                % handle demo mode
                
                % minimum analog write delay
                pause(0.0014);
                
            else
                
                % check a.aser for openness if a.chks is true
                if a.chks
                    errstr=arduinoLegacy.checkser(a.aser,'open');
                    if ~isempty(errstr), error(errstr); end
                end
                
                % send mode, encoder and pins
                fwrite(a.aser,[73 48+enc 97+del],'uchar');
                
            end
            
        end % encoderdebounce

        % round trip
        function val=roundTrip(a,byte)
            
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
            
            %%%%%%%%%%%%%%%%%%%%%%%%% ARGUMENT CHECKING %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            % check arguments if a.chkp is true
            if a.chkp
                
                % check nargin
                if nargin~=2
                    error('Function must have one argument');
                end
                
                % check argument (must be a byte)
                errstr=arduinoLegacy.checknum(byte,'byte',0:255);
                if ~isempty(errstr), error(errstr); end
                
            end
            
            % check a.aser for validity if a.chks is true
            if a.chks
                errstr=arduinoLegacy.checkser(a.aser,'valid');
                if ~isempty(errstr), error(errstr); end
            end
            
            %%%%%%%%%%%%%%%%%%%%%%%%% SEND ARGUMENT ALONG %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            if strcmpi(get(a.aser,'Port'),'DEMO')
                % handle demo mode
                
                % minimum analog output delay
                pause(0.0014);
                
                % sets the output
                val=byte;
                
            else
                
                % check a.aser for openness if a.chks is true
                if a.chks,
                    errstr=arduinoLegacy.checkser(a.aser,'open');
                    if ~isempty(errstr), error(errstr); end
                end
                
                % send mode and byte
                fwrite(a.aser,[88 byte],'uchar');
                
                % get value back
                val=fscanf(a.aser,'%d');
                
            end
            
        end % roundtrip
        
        % motor speed
        function val=motorSpeed(a,num,val)
            
            % val=motorSpeed(a,num,val); sets the speed of a DC motor.
            % The first argument, a, is the arduino object.
            % The second argument, num, is the number of the motor, which can go
            % from 1 to 4 (the motor ports are numbered on the motor shield).
            % The third argument is the speed from 0 (stopped) to 255 (maximum), note
            % that depending on the motor speeds of at least 60 might be necessary
            % to actually run it. Called as motorSpeed(a,num), it returns 
            % the speed at which the given motor is set to run. If there
            % is no output argument it prints the speed of the motor.
            % Called as motorSpeed(a), it prints the speed of each motor.
            % Note that you must use the motorRun function to actually run
            % the motor at the given speed, either forward or backwards.
            % Note that this function returns random values in DEMO mode, 
            % or when a sketch that does not support the Adafruit motor
            % shield is running on the Arduino board.
            %
            % Examples:
            % motorSpeed(a,4,200)      % sets speed of motor 4 as 200/255
            % val=motorSpeed(a,1);     % returns the speed of motor 1
            % motorSpeed(a,3);         % prints the speed of motor 3
            % motorSpeed(a);           % prints the speed of all motors
            % a.motorSpeed;            % prints the speed of all motors
            %
            
            %%%%%%%%%%%%%%%%%%%%%%%%% ARGUMENT CHECKING %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            % check arguments if a.chkp is true
            if a.chkp,
                
                % check nargin
                if nargin>3,
                    error('This function cannot have more than 3 arguments, arduino object, motor number and speed');
                end
                
                % if motor number is there check it
                if nargin>1,
                    errstr=arduinoLegacy.checknum(num,'motor number',1:4);
                    if ~isempty(errstr), error(errstr); end
                end
                
                % if speed argument is there check it
                if nargin>2,
                    errstr=arduinoLegacy.checknum(val,'speed',0:255);
                    if ~isempty(errstr), error(errstr); end
                end
                
            end
            
            % perform the requested action
            if nargin==3,
                
                % check a.aser for validity if a.chks is true
                if a.chks,
                    errstr=arduinoLegacy.checkser(a.aser,'valid');
                    if ~isempty(errstr), error(errstr); end
                end
                
                % warning if sketch is inadequate and a.chkp is true
                if a.chkp && a.sktc<3
                    disp('Warning: the sketch running on the Arduino does not support the motor shield');
                    disp('No operation will be performed on the Arduino board');
                end

                %%%%%%%%%%%%%%%%%%%%%%%%% SET MOTOR SPEED %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                
                if strcmpi(get(a.aser,'Port'),'DEMO') || a.sktc<3,
                    % handle demo mode
                    
                    % minimum analog output delay
                    pause(0.0014);
                    
                else
                    
                    % check a.aser for openness if a.chks is true
                    if a.chks,
                        errstr=arduinoLegacy.checkser(a.aser,'open');
                        if ~isempty(errstr), error(errstr); end
                    end
                    
                    % send mode, num and value
                    fwrite(a.aser,[65 48+num val],'uchar');
                    
                end
                
                % store speed value in case it needs to be retrieved
                a.mspd(num)=val;
                
                % clear val if is not needed as output
                if nargout==0,
                    clear val;
                end
                
            elseif nargin==2,
                
                if nargout==0,
                    % print speed value
                    disp(['The speed of motor number ' num2str(num) ' is set to: ' num2str(a.mspd(num)) ' over 255']);
                else
                    % return speed value
                    val=a.mspd(num);
                end
                
            else
                
                if nargout==0,
                    % print speed value for each motor
                    for num=1:4,
                        disp(['The speed of motor number ' num2str(num) ' is set to: ' num2str(a.mspd(num)) ' over 255']);
                    end
                else
                    % return speed values
                    val=a.mspd;
                end
                
            end
            
        end % motorspeed
        
        % motor run
        function motorRun(a,num,dir)
            
            % motorRun(a,num,dir); runs a given DC motor.
            % The first argument, a, is the arduino object.
            % The second argument, num, is the number of the motor, which can go
            % from 1 to 4 (the motor ports are numbered on the motor shield).
            % The third argument, dir, should be a string that can be 'forward'
            % (runs the motor forward) 'backward' (runs the motor backward)
            % or 'release', (stops the motor). Note that since version 3.0,
            % a +1 is interpreted as 'forward', a 0 is interpreted
            % as 'release', and a -1 is interpreted as 'backward'.
            %
            % Examples:
            % motorRun(a,1,'forward');      % runs motor 1 forward
            % motorRun(a,3,'backward');     % runs motor 3 backward
            % motorRun(a,2,-1);             % runs motor 2 backward
            % motorRun(a,1,'release');      % releases motor 1
            % a.motorRun(2,'release');      % releases motor 2
            %
            
            %%%%%%%%%%%%%%%%%%%%%%%%% ARGUMENT CHECKING %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            % check arguments if a.chkp is true
            if a.chkp,
                
                % check nargin
                if nargin~=3,
                    error('Function must have 3 arguments, object, motor number and direction');
                end
                
                % check motor number
                errstr=arduinoLegacy.checknum(num,'motor number',1:4);
                if ~isempty(errstr), error(errstr); end
                
            end
            
            % allows for direction to be set by 1,0,-1
            if isnumeric(dir) && isscalar(dir),
                switch dir
                    case 1,
                        dir='forward';
                    case 0,
                        dir='release';
                    case -1,
                        dir='backward';
                end
            end
            
            % check direction if a.chkp is true
            if a.chkp,
                errstr=arduinoLegacy.checkstr(dir,'direction',{'forward','backward','release'});
                if ~isempty(errstr), error(errstr); end
            end
            
            % check a.aser for validity if a.chks is true
            if a.chks,
                errstr=arduinoLegacy.checkser(a.aser,'valid');
                if ~isempty(errstr), error(errstr); end
            end
            
            % warning if sketch is inadequate and a.chkp is true
            if a.chkp && a.sktc<3
                disp('Warning: the sketch running on the Arduino does not support the motor shield');
                disp('No operation will be performed on the Arduino board');
            end

            %%%%%%%%%%%%%%%%%%%%%%%%% RUN THE MOTOR %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            if strcmpi(get(a.aser,'Port'),'DEMO') || a.sktc<3,
                % handle demo mode
                
                % minimum analog output delay
                pause(0.0014);
                
            else
                
                % check a.aser for openness if a.chks is true
                if a.chks,
                    errstr=arduinoLegacy.checkser(a.aser,'open');
                    if ~isempty(errstr), error(errstr); end
                end
                
                % send mode, num and value
                fwrite(a.aser,[66 48+num abs(dir(1))],'uchar');
                
            end
            
        end % motorrun
        
        % stepper speed
        function val=stepperSpeed(a,num,val)
            
            % val=stepperSpeed(a,num,val); sets the speed of a given stepper motor
            % The first argument, a, is the arduino object.
            % The second argument, num, is the number of the stepper motor,
            % which can go from 1 to 4 (the motor ports are numbered on the motor shield).
            % The third argument is the RPM speed from 1 (minimum) to 255 (maximum).
            % Called as stepperSpeed(a,num), it returns the speed at which 
            % the given motor is set to run. If there is no output
            % argument it prints the speed of the stepper motor.
            % Called as stepperSpeed(a), it prints the speed of each stepper motor.
            % Note that you must use the stepperStep function to actually run
            % the motor at the given speed, either forward or backwards (or release
            % it). Note that this function returns random values in DEMO mode, 
            % or when a sketch that does not support the Adafruit motor
            % shield is running on the Arduino board.
            %
            % Examples:
            % stepperSpeed(a,2,50)      % sets speed of stepper 2 as 50 rpm
            % val=stepperSpeed(a,1);    % returns the speed of stepper 1
            % stepperSpeed(a,2);        % prints the speed of stepper 2
            % stepperSpeed(a);          % prints the speed of both steppers
            % a.stepperSpeed;           % prints the speed of both steppers
            %
            
            %%%%%%%%%%%%%%%%%%%%%%%%% ARGUMENT CHECKING %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            % check arguments if a.chkp is true
            if a.chkp,
                
                % check nargin
                if nargin>3,
                    error('This function cannot have more than 3 arguments, object, stepper number and speed');
                end
                
                % if stepper number is there check it
                if nargin>1,
                    errstr=arduinoLegacy.checknum(num,'stepper number',1:2);
                    if ~isempty(errstr), error(errstr); end
                end
                
                % if speed argument is there check it
                if nargin>2,
                    errstr=arduinoLegacy.checknum(val,'speed',0:255);
                    if ~isempty(errstr), error(errstr); end
                end
                
            end
            
            % perform the requested action
            if nargin==3,
                
                % check a.aser for validity if a.chks is true
                if a.chks,
                    errstr=arduinoLegacy.checkser(a.aser,'valid');
                    if ~isempty(errstr), error(errstr); end
                end
                
                % warning if sketch is inadequate and a.chkp is true
                if a.chkp && a.sktc<3
                    disp('Warning: the sketch running on the Arduino does not support the motor shield');
                    disp('No operation will be performed on the Arduino board');
                end

                %%%%%%%%%%%%%%%%%%%%%%%%% SET STEPPER SPEED %%%%%%%%%%%%%%%%%%%%%%%%%%%
                
                if strcmpi(get(a.aser,'Port'),'DEMO') || a.sktc<3,
                    % handle demo mode
                    
                    % minimum analog output delay
                    pause(0.0014);
                    
                else
                    
                    % check a.aser for openness if a.chks is true
                    if a.chks,
                        errstr=arduinoLegacy.checkser(a.aser,'open');
                        if ~isempty(errstr), error(errstr); end
                    end
                    
                    % send mode, num and value
                    fwrite(a.aser,[67 48+num val],'uchar');
                    
                end
                
                % store speed value in case it needs to be retrieved
                a.sspd(num)=val;
                
                % clear val if is not needed as output
                if nargout==0,
                    clear val;
                end
                
            elseif nargin==2,
                
                if nargout==0,
                    % print speed value
                    disp(['The speed of stepper number ' num2str(num) ' is set to: ' num2str(a.sspd(num)) ' over 255']);
                else
                    % return speed value
                    val=a.sspd(num);
                end
                
            else
                
                if nargout==0,
                    % print speed value for each stepper
                    for num=1:2,
                        disp(['The speed of stepper number ' num2str(num) ' is set to: ' num2str(a.sspd(num)) ' over 255']);
                    end
                else
                    % return speed values
                    val=a.sspd;
                end
                
            end
            
        end % stepperspeed
        
        % stepper step
        function stepperStep(a,num,dir,sty,steps)
            
            % stepperStep(a,num,dir,sty,steps); rotates a given stepper motor
            % The first argument, a, is the arduino object. The second argument, 
            % num, is the number of the stepper motor, which is either 1 or 2. 
            % The third argument, the direction, is a string that can be 'forward'
            % (runs the motor forward), 'backward' (runs the motor backward),
            % or 'release', (stops and releases the motor). Note that since version 3.0,
            % a +1 is interpreted as 'forward', a 0 is interpreted as 'release',
            % and a -1 is interpreted as 'backward'. Unless the direction is 'release',
            % then two more argument are needed: the fourth one is the style,
            % which is a string specifying the style of the motion, and can be 'single'
            % (only one coil activated at a time), 'double' (2 coils activated, gives
            % an higher torque and power consumption) 'interleave', (alternates between
            % single and double to get twice the resolution and half the speed), and
            % 'microstep' (the coils are driven in PWM for a smoother motion).
            % The final argument is the number of steps that the motor has
            % to complete.
            %
            % Examples:
            % % rotates stepper 1 forward of 100 steps in interleave mode
            % stepperStep(a,1,'forward','double',100);
            % % rotates stepper 2 forward of 50 steps in double mode
            % stepperStep(a,1,'forward','double',50);
            % % rotates stepper 2 backward of 50 steps in single mode
            % stepperStep(a,2,'backward','single',50);
            % % rotates stepper 2 backward of 50 steps in interleave mode
            % a.stepperStep(2,'backward','interleave',50);
            %
            
            %%%%%%%%%%%%%%%%%%%%%%%%% ARGUMENT CHECKING %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            % check arguments if a.chkp is true
            if a.chkp,
                
                % check nargin
                if nargin>5 || nargin <3,
                    error('Function must have at least 3 and no more than 5 arguments');
                end
                
                % check stepper number
                errstr=arduinoLegacy.checknum(num,'stepper number',1:2);
                if ~isempty(errstr), error(errstr); end
                
            end
            
            % allows for direction to be set by 1,0,-1
            if isnumeric(dir) && isscalar(dir),
                switch dir
                    case 1,
                        dir='forward';
                    case 0,
                        dir='release';
                    case -1,
                        dir='backward';
                end
            end
            
            % check arguments if a.chkp is true
            if a.chkp,
                
                % check direction
                errstr=arduinoLegacy.checkstr(dir,'direction',{'forward','backward','release'});
                if ~isempty(errstr), error(errstr); end
                
                % if it is not released must have all arguments
                if ~strcmpi(dir,'release') && nargin~=5,
                    error('Either the motion style or the number of steps are missing');
                end
                
                % can't move forward or backward if speed is set to zero
                if ~strcmpi(dir,'release') && a.stepperSpeed(num)<1,
                    error('The stepper speed has to be greater than zero for the stepper to move');
                end
                
                % check motion style
                if nargin>3,
                    % check direction
                    errstr=arduinoLegacy.checkstr(sty,'motion style',{'single','double','interleave','microstep'});
                    if ~isempty(errstr), error(errstr); end
                else
                    sty='single';
                end
                
                % check number of steps
                if nargin==5,
                    errstr=arduinoLegacy.checknum(steps,'number of steps',0:255);
                    if ~isempty(errstr), error(errstr); end
                else
                    steps=0;
                end
                
            end
            
            % check a.aser for validity if a.chks is true
            if a.chks,
                errstr=arduinoLegacy.checkser(a.aser,'valid');
                if ~isempty(errstr), error(errstr); end
            end
            
            % warning if sketch is inadequate and a.chkp is true
            if a.chkp && a.sktc<3
                disp('Warning: the sketch running on the Arduino does not support the motor shield');
                disp('No operation will be performed on the Arduino board');
            end

            %%%%%%%%%%%%%%%%%%%%%%%%% ROTATE THE STEPPER %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            if strcmpi(get(a.aser,'Port'),'DEMO') || a.sktc<3,
                % handle demo mode
                
                % minimum analog output delay
                pause(0.0014);
                
            else
                
                % check a.aser for openness if a.chks is true
                if a.chks,
                    errstr=arduinoLegacy.checkser(a.aser,'open');
                    if ~isempty(errstr), error(errstr); end
                end
                
                % send mode, num and value
                fwrite(a.aser,[68 48+num abs(dir(1)) abs(sty(1)) steps],'uchar');
                
            end
            
        end % stepperstep
        
    end % methods
    
    methods (Static) % static methods
        
        function errstr=checknum(num,description,allowed)
            
            % errstr=arduinoLegacy.checknum(num,description,allowed); Checks numeric argument.
            % This function checks the first argument, num, described in the string
            % given as a second argument, to make sure that it is real, scalar,
            % and that it is equal to one of the entries of the vector of allowed
            % values given as a third argument. If the check is successful then the
            % returned argument is empty, otherwise it is a string specifying
            % the type of error.
            
            % initialize error string
            errstr=[];
            
            % check num for type
            if ~isnumeric(num)
                errstr=['The ' description ' must be numeric'];
                return
            end
            
            % check num for size
            if numel(num)~=1
                errstr=['The ' description ' must be a scalar'];
                return
            end
            
            % check num for realness
            if ~isreal(num)
                errstr=['The ' description ' must be a real value'];
                return
            end
            
            % check num against allowed values
            if ~any(allowed==num)
                
                % form right error string
                if numel(allowed)==1
                    errstr=['Unallowed value for ' description ', the value must be exactly ' num2str(allowed(1))];
                elseif numel(allowed)==2
                    errstr=['Unallowed value for ' description ', the value must be either ' num2str(allowed(1)) ' or ' num2str(allowed(2))];
                elseif max(diff(allowed))==1
                    errstr=['Unallowed value for ' description ', the value must be an integer going from ' num2str(allowed(1)) ' to ' num2str(allowed(end))];
                else
                    errstr=['Unallowed value for ' description ', the value must be one of the following: ' mat2str(allowed)];
                end
                
            end
            
        end % checknum
        
        function errstr=checkstr(str,description,allowed)
            
            % errstr=arduinoLegacy.checkstr(str,description,allowed); Checks string argument.
            % This function checks the first argument, str, described in the string
            % given as a second argument, to make sure that it is a string, and that
            % its first character is equal to one of the entries in the cell of
            % allowed characters given as a third argument. If the check is successful
            % then the returned argument is empty, otherwise it is a string specifying
            % the type of error.
            
            % initialize error string
            errstr=[];
            
            % check string for type
            if ~ischar(str)
                errstr=['The ' description ' argument must be a string'];
                return
            end
            
            % check string for size
            if numel(str)<1
                errstr=['The ' description ' argument cannot be empty'];
                return
            end
            
            % check str against allowed values
            if ~any(strcmpi(str,allowed))
                
                % make sure this is a hozizontal vector
                allowed=allowed(:)';
                
                % add a comma at the end of each value
                for i=1:length(allowed)-1
                    allowed{i}=['''' allowed{i} ''', '];
                end
                
                % form error string
                errstr=['Unallowed value for ' description ', the value must be either: ' allowed{1:end-1} 'or ''' allowed{end} ''''];
                return
            end
            
        end % checkstr
        
        function errstr=checkser(ser,chk)
            
            % errstr=arduinoLegacy.checkser(ser,chk); Checks serial connection argument.
            % This function checks the first argument, ser, to make sure that either:
            % 1) it is a valid serial connection (if the second argument is 'valid')
            % 3) it is open (if the second argument is 'open')
            % If the check is successful then the returned argument is empty,
            % otherwise it is a string specifying the type of error.
            
            % initialize error string
            errstr=[];
            
            % check serial connection
            switch lower(chk)
                
                case 'valid'
                    
                    % make sure is valid
                    if ~isvalid(ser)
                        disp('Serial connection invalid, please recreate the object to reconnect to a serial port.');
                        errstr='Serial connection invalid';
                        return
                    end
                    
                case 'open'
                    
                    % check openness
                    if ~strcmpi(get(ser,'Status'),'open')
                        disp('Serial connection not opened, please recreate the object to reconnect to a serial port.');
                        errstr='Serial connection not opened';
                        return
                    end
                    
                    
                otherwise
                    
                    % complain
                    error('second argument must be either ''valid'' or ''open''');
                    
            end
            
        end % chackser
        
    end % static methods
    
end % class def