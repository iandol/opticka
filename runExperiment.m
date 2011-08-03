% ========================================================================
%> @brief runExperiment is the main Experiment object; Inherits from Handle
%>
%>RUNEXPERIMENT The main class which accepts a task and stimulus object
%>and runs the stimuli based on the task object passed. The class
%>controls the fundamental configuration of the screen (calibration, size
%>etc.), and manages communication to the DAQ system using TTL pulses out
%>and communication over a UDP client<->server socket.
%>  Stimulus must be a stimulus class, i.e. gratingStimulus and friends,
%>  so for example:
%>
%>  gs.g=gratingStimulus(struct('mask',1,'sf',1));
%>  ss=runExperiment(struct('stimulus',gs,'windowed',1));
%>  ss.run;
%>
%>	will run a minimal experiment showing a 1c/d circularly masked grating
% ========================================================================
classdef (Sealed) runExperiment < handle
	
	properties
		%> MBP 1440x900 is 33.2x20.6cm so approx 44px/cm, Flexscan is 32px/cm @1280 26px/cm @ 1024
		pixelsPerCm = 44
		%> distance of subject from CRT -- rad2ang(2*(atan((0.5*1cm)/57.3cm))) equals 1deg
		distance = 57.3
		%> set of stimulus classes passed from gratingStulus and friends
		stimulus
		%> the stimulusSequence object(s) for the task
		task
		%> which screen to display on, [] means use max screen
		screen = []
		%> windowed: if 1 useful for debugging, but remember timing will be poor
		windowed = 0
		%>show command logs and a time log after stimlus presentation
		verbose = false
		%> hide the black flash as PTB tests it refresh timing, uses a gamma trick
		hideFlash = false
		%> change the parameters for poorer temporal fidelity during debugging
		debug = false
		%> shows the info text and position grid during stimulus presentation
		visualDebug = true
		%> normally should be left at 1 (1 is added to this number so doublebuffering is enabled)
		doubleBuffer = 1
		%>bitDepth of framebuffer
		bitDepth = 'FloatingPoint32BitIfPossible'
		%> multisampling sent to the graphics card, try values []=disabled, 4, 8 and 16
		antiAlias = []
		%> background of display during stimulus presentation
		backgroundColour = [0.5 0.5 0.5 0]
		%> shunt screen center by X degrees
		screenXOffset = 0
		%> shunt screen center by Y degrees
		screenYOffset = 0
		%> use OpenGL blending mode
		blend = false
		%> GL_ONE %src mode
		srcMode = 'GL_ONE'
		%> GL_ONE % dst mode
		dstMode = 'GL_ZERO'
		%> show a fixation spot?
		fixationPoint = false
		%> show a white square to trigger a photodiode attached to screen
		photoDiode = false
		%> name of serial port to send TTL out on, if set to 'dummy' then ignore
		serialPortName = 'dummy'
		%> use LabJack for digital output?
		useLabJack = false
		%> LabJack object
		lJack
		%> settings for movie output
		movieSettings = []
		%> gamma correction info saved as a calibrateLuminance object
		gammaTable
		%> this lets the UI leave commands
		uiCommand = ''
		%> log all frame times, gets slow for > 1e6 frames
		logFrames = true
	end
	
	properties (SetAccess = private, GetAccess = public, Dependent = true)
		%> dependent property calculated from distance and pixelsPerCm
		ppd
	end
	
	properties (SetAccess = private, GetAccess = public)
		%> the handle returned by opening a PTB window
		win
		%> computed X center
		xCenter
		%> computed Y center
		yCenter
		%> set automatically on construction
		maxScreen
		%> ?
		info
		%> general computer info
		computer
		%> PTB info
		ptb
		%> gamma tables and the like
		screenVals
		%> log times during display
		timeLog
		%> calculated stimulus values for display
		sVals
		%> detailed info as the experiment runs
		taskLog
		%> for heterogenous stimuli, we need a way to index into the stimulus so
		%> we don't waste time doing this on each iteration
		sList
		%> info on the current run
		currentInfo
	end
	
	properties (SetAccess = private, GetAccess = private)
		%> black index
		black = 0
		%> white index
		white = 1
		%> properties allowed to be modified during construction
		allowedPropertiesBase='^(pixelsPerCm|distance|screen|windowed|stimulus|task|serialPortName|backgroundColor|screenXOffset|screenYOffset|blend|fixationPoint|srcMode|dstMode|antiAlias|debug|photoDiode|verbose|hideFlash)$'
		%> serial port object opened
		serialP
		%> the window rectangle
		winRect
		%> the photoDiode rectangle
		photoDiodeRect = [0;0;50;50]
		%> the values comuted to draw the 1deg dotted grid in debug mode
		grid
		%> the movie pointer
		moviePtr = []
	end
	
	events
		runInfo
		abortRun
		endRun
	end
	
	%=======================================================================
	methods %------------------PUBLIC METHODS
		%=======================================================================
		
		% ===================================================================
		%> @brief Class constructor
		%>
		%> More detailed description of what the constructor does.
		%>
		%> @param args are passed as a structure of properties which is
		%> parsed.
		%> @return instance of the class.
		% ===================================================================
		function obj = runExperiment(args)
			obj.timeLog.construct=GetSecs;
			if exist('args','var');obj.set(args);end
			obj.prepareScreen;
		end
		
		% ===================================================================
		%> @brief The main run loop
		%>
		%> @param obj required class object
		% ===================================================================
		function run(obj)
			%initialise timeLog for this run
			obj.timeLog = [];
			obj.timeLog.date = clock;
			obj.timeLog.startrun = GetSecs;
			%if obj.logFrames == false %preallocating these makes opticka drop frames when nFrames ~ 1e6
			obj.timeLog.vbl = 0;
			obj.timeLog.show = 0;
			obj.timeLog.flip = 0;
			obj.timeLog.miss = 0;
			obj.timeLog.stimTime = 0;
			%else
			%	obj.timeLog.vbl=zeros(obj.task.nFrames,1);
			%	obj.timeLog.show=zeros(obj.task.nFrames,1);
			%	obj.timeLog.flip=zeros(obj.task.nFrames,1);
			%	obj.timeLog.miss=zeros(obj.task.nFrames,1);
			%	obj.timeLog.stimTime=zeros(obj.task.nFrames,1);
			%end
			
			obj.screenVals.resetGamma = false;
			%if obj.windowed(1)==0 && obj.debug == false;HideCursor;end
			
			% This is the trick Mario told us to "hide" th colour changes as PTB
			% intialises -- we could use backgroundcolour here to be even better
			if obj.hideFlash == true && obj.windowed(1) == 0
				if isa(obj.gammaTable,'calibrateLuminance') && (obj.gammaTable.choice > 0)
					obj.screenVals.oldGamma = Screen('LoadNormalizedGammaTable', obj.screen, repmat(obj.gammaTable.gammaTable{obj.gammaTable.choice}(128,:), 256, 3));
					obj.screenVals.resetGamma = true;
				else
					obj.screenVals.oldGamma = Screen('LoadNormalizedGammaTable', obj.screen, repmat(obj.screenVals.gammaTable(128,:), 256, 1));
					obj.screenVals.resetGamma = true;
				end
			end
			
			%-------Set up serial line and LabJack for this run...
			%obj.serialP=sendSerial(struct('name',obj.serialPortName,'openNow',1,'verbosity',obj.verbose));
			%obj.serialP.setDTR(0);
			
			if obj.useLabJack == true
				strct = struct('openNow',1,'name','default','verbosity',obj.verbose);
			else
				strct = struct('openNow',0,'name','null','verbosity',0,'silentMode',1);
			end
			obj.lJack = labJack(strct);
			%-----------------------------------------------------
			
			%---------This is our main TRY CATCH experiment display loop
			try
				if obj.debug == true || obj.windowed(1)>0
					Screen('Preference', 'SkipSyncTests', 2);
					Screen('Preference', 'VisualDebugLevel', 0);
					Screen('Preference', 'Verbosity', 2);
					Screen('Preference', 'SuppressAllWarnings', 0);
				else
					Screen('Preference', 'SkipSyncTests', 0);
					Screen('Preference', 'VisualDebugLevel', 3);
					Screen('Preference', 'Verbosity', 4); %errors and warnings
					Screen('Preference', 'SuppressAllWarnings', 0);
				end
				
				PsychImaging('PrepareConfiguration');
				PsychImaging('AddTask', 'General', 'UseFastOffscreenWindows');
				if ischar(obj.bitDepth) && ~strcmpi(obj.bitDepth,'8bit')
					PsychImaging('AddTask', 'General', obj.bitDepth);
				end
				PsychImaging('AddTask', 'General', 'NormalizedHighresColorRange'); %we always want 0-1 colourrange!
				
				obj.timeLog.preOpenWindow=GetSecs;
				
				if obj.windowed(1)==0
					[obj.win, obj.winRect] = PsychImaging('OpenWindow', obj.screen, obj.backgroundColour,[], [], obj.doubleBuffer+1,[],obj.antiAlias);
				else
					if length(obj.windowed)==1;obj.windowed=[800 600];end
					[obj.win, obj.winRect] = PsychImaging('OpenWindow', obj.screen, obj.backgroundColour,[1 1 obj.windowed(1)+1 obj.windowed(2)+1], [], obj.doubleBuffer+1,[],obj.antiAlias);
				end
				
				obj.timeLog.postOpenWindow=GetSecs;
				obj.timeLog.deltaOpenWindow=(obj.timeLog.postOpenWindow-obj.timeLog.preOpenWindow)*1000;
				
				Priority(MaxPriority(obj.win)); %bump our priority to maximum allowed
				
				%find our fps if not defined before
				obj.screenVals.ifi = Screen('GetFlipInterval', obj.win);
				if obj.screenVals.fps==0
					obj.screenVals.fps=round(1/obj.screenVals.ifi);
				end
				obj.screenVals.halfisi=obj.screenVals.ifi/2;
				
				Priority(0); %be lazy for a while and let other things get done
				
				if obj.hideFlash == true && isempty(obj.gammaTable)
					Screen('LoadNormalizedGammaTable', obj.screen, obj.screenVals.gammaTable);
					obj.screenVals.resetGamma = false;
				elseif isa(obj.gammaTable,'calibrateLuminance') && (obj.gammaTable.choice > 0)
					choice = obj.gammaTable.choice;
					obj.screenVals.resetGamma = true;
					gTmp = repmat(obj.gammaTable.gammaTable{choice},1,3);
					Screen('LoadNormalizedGammaTable', obj.screen, gTmp);
					fprintf('\nSET GAMMA CORRECTION using: %s\n', obj.gammaTable.modelFit{choice}.method);
				else
					Screen('LoadNormalizedGammaTable', obj.screen, obj.screenVals.gammaTable);
					%obj.screenVals.oldCLUT = LoadIdentityClut(obj.win);
					obj.screenVals.resetGamma = false;
				end
				
				AssertGLSL;
				
				obj.lJack.setDIO([2,0,0]);WaitSecs(0.01);obj.lJack.setDIO([0,0,0]); %Trigger the omniplex (FIO1) into paused mode
				
				% Enable alpha blending.
				if obj.blend==1
					Screen('BlendFunction', obj.win, obj.srcMode, obj.dstMode);
				end
				
				%get the center of our screen, along with user defined offsets
				[obj.xCenter, obj.yCenter] = RectCenter(obj.winRect);
				obj.xCenter=obj.xCenter+(obj.screenXOffset*obj.ppd);
				obj.yCenter=obj.yCenter+(obj.screenYOffset*obj.ppd);
				
				
				obj.black = BlackIndex(obj.win);
				obj.white = WhiteIndex(obj.win);
				
				obj.initialiseTask; %set up our task structure for this run
				
				for j=1:obj.sList.n %parfor doesn't seem to help here...
					obj.stimulus{j}.setup(obj); %call setup and pass it the runExperiment object
				end
				
				% Set up the movie settings
				if obj.movieSettings.record == 1
					obj.movieSettings.outsize=CenterRect([0 0 obj.movieSettings.size(1) obj.movieSettings.size(2)],obj.winRect);
					disp(num2str(obj.movieSettings.outsize));
					disp('---');
					obj.movieSettings.loop=1;
					if ismac || isunix
						oldp = cd('~');
						homep = pwd;
						cd(oldp);
					else
						homep = 'c:';
					end
					if ~exist([homep '/MatlabFiles/Movie/'],'dir')
						mkdir([homep '/MatlabFiles/Movie/'])
					end
					switch obj.movieSettings.type
						case 1
							if ispc || isunix || isempty(obj.movieSettings.codec)
								settings = 'EncodingQuality=1';
							else
								settings = ['EncodingQuality=1; CodecFOURCC=' obj.movieSettings.codec];
							end
							obj.moviePtr = Screen('CreateMovie', obj.win,...
								[homep '/MatlabFiles/Movie/Movie' datestr(clock) '.mov'],...
								obj.movieSettings.size(1), obj.movieSettings.size(2), ...
								obj.screenVals.fps, settings);
						case 2
							mimg = zeros(obj.movieSettings.size(2),obj.movieSettings.size(1),3,obj.movieSettings.nFrames);
					end
				end
				
				obj.updateVars; %set the variables for the very first run;
				
				KbReleaseWait; %make sure keyboard keys are all released
				
				Priority(MaxPriority(obj.win)); %bump our priority to maximum allowed
				%--------------this is RSTART (FIO0->Pin 24), unpausing the omniplex
				if obj.useLabJack == true
					obj.lJack.setDIO([1,0,0],[1,0,0])
					WaitSecs(0.2);
				end
				
				obj.task.tick = 1;
				obj.task.switched = 1;
				obj.timeLog.beforeDisplay = GetSecs;
				
				
				if obj.photoDiode == true;obj.drawPhotoDiodeSquare([0 0 0 1]);end
				vbl=Screen('Flip', obj.win);
				if obj.photoDiode == true;obj.drawPhotoDiodeSquare([0 0 0 1]);end
				if obj.logFrames == true
					obj.timeLog.stimTime(1) = 1;
					obj.timeLog.vbl(1) = Screen('Flip', obj.win,vbl+0.001);
				else
					obj.timeLog.vbl = Screen('Flip', obj.win,vbl+0.001);
				end
				obj.timeLog.startTime = obj.timeLog.vbl(1);

				%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
				%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
				% Our main display loop
				%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
				%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
				while obj.task.thisTrial <= obj.task.nTrials
					if obj.task.isBlank == true
						if obj.photoDiode == true
							obj.drawPhotoDiodeSquare([0 0 0 1]);
						end
					else
						if ~isempty(obj.backgroundColour)
							obj.drawBackground;
						end
						for j=1:obj.sList.n
							obj.stimulus{j}.draw();
						end
						if obj.photoDiode == true
							obj.drawPhotoDiodeSquare([1 1 1 1]);
						end
						if obj.fixationPoint == true
							obj.drawFixationPoint;
						end
					end
					if obj.visualDebug == true
						obj.drawGrid;
						obj.infoText;
					end
					
					Screen('DrawingFinished', obj.win); % Tell PTB that no further drawing commands will follow before Screen('Flip')
					
					[~, ~, buttons]=GetMouse(obj.screen);
					if buttons(2)==1;notify(obj,'abortRun');break;end; %break on any mouse click, needs to change
					if strcmp(obj.uiCommand,'stop');break;end
					%if KbCheck;notify(obj,'abortRun');break;end;
						
					obj.updateTask(); %update our task structure
					
					%======= FLIP: Show it at correct retrace: ========%
					nextvbl = obj.timeLog.vbl(end) + obj.screenVals.halfisi;
					if obj.logFrames == true
						[obj.timeLog.vbl(obj.task.tick),obj.timeLog.show(obj.task.tick),obj.timeLog.flip(obj.task.tick),obj.timeLog.miss(obj.task.tick)] = Screen('Flip', obj.win, nextvbl);
					else
						obj.timeLog.vbl = Screen('Flip', obj.win, nextvbl);
					end
					%==================================================%
					if obj.task.strobeThisFrame == true
						obj.lJack.strobeWord; %send our word out to the LabJack
					end
					
					if obj.task.tick == 1
						obj.timeLog.startTime=obj.timeLog.vbl(1); %respecify this with actual stimulus vbl
					end
					
					if obj.logFrames == true
						if obj.task.isBlank == false
							obj.timeLog.stimTime(obj.task.tick)=1+obj.task.switched;
						else
							obj.timeLog.stimTime(obj.task.tick)=0-obj.task.switched;
						end
					end
					
					obj.task.tick=obj.task.tick+1;
					
					if obj.movieSettings.record == true
						if obj.task.isBlank == false && obj.movieSettings.loop <= obj.movieSettings.nFrames
							switch obj.movieSettings.type
								case 1
									Screen('AddFrameToMovie', obj.win, obj.movieSettings.outsize, 'frontBuffer', obj.movieSettings.quality, 3);
								case 2
									mimg(:,:,:,obj.movieSettings.loop)=Screen('GetImage', obj.win, obj.movieSettings.outsize, 'frontBuffer', obj.movieSettings.quality, 3);
							end
							obj.movieSettings.loop=obj.movieSettings.loop+1;
						end
					end
					
				end
				
				%---------------------------------------------Finished display loop
				obj.drawBackground;
				vbl=Screen('Flip', obj.win);
				%obj.lJack.prepareStrobe(2047,[],1);
				obj.timeLog.afterDisplay=vbl;
				obj.lJack.setDIO([0,0,0],[1,0,0]); %this is RSTOP, pausing the omniplex
				notify(obj,'endRun');
				
				obj.timeLog.deltaDispay=obj.timeLog.afterDisplay - obj.timeLog.beforeDisplay;
				obj.timeLog.deltaUntilDisplay=obj.timeLog.startTime - obj.timeLog.beforeDisplay;
				obj.timeLog.deltaToFirstVBL=obj.timeLog.vbl(1) - obj.timeLog.beforeDisplay;
				
				obj.info = Screen('GetWindowInfo', obj.win);
				
				if obj.screenVals.resetGamma == true
					Screen('LoadNormalizedGammaTable', obj.screen, obj.screenVals.gammaTable);
				end
				
				if obj.movieSettings.record == 1 
					switch obj.movieSettings.type
						case 1
							if ~isempty(obj.moviePtr)
								Screen('FinalizeMovie', obj.moviePtr);
							end
						case 2
							if ~exist('~/Desktop/Movie/','dir')
								mkdir('~/Desktop/Movie/')
							end
							save(['~/Desktop/Movie/Movie' datestr(clock) '.mat'],'mimg');
					end
					obj.moviePtr = [];
				end
				
				Screen('Close');
				Screen('CloseAll');
				
				obj.win=[];
				Priority(0);
				ShowCursor;
				obj.lJack.setDIO([2,0,0]);WaitSecs(0.05);obj.lJack.setDIO([0,0,0]); %we stop recording mode completely
				obj.lJack.close;
				obj.lJack=[];
				
				if obj.movieSettings.record == 1  && exist('implay','file') && exist('mimg','var')
					implay(mimg);
				end
				
			catch ME
				
				obj.lJack.setDIO([0,0,0]);
				if obj.screenVals.resetGamma == true
					fprintf('\nRESET GAMMA\n');
					Screen('LoadNormalizedGammaTable', obj.screen, obj.screenVals.gammaTable);
				end
				if obj.hideFlash == true || obj.windowed(1) ~= 1
					Screen('LoadNormalizedGammaTable', obj.screen, obj.screenVals.gammaTable);
				end
				if obj.movieSettings.record == true 
					switch obj.movieSettings.type
						case 1
							if ~isempty(obj.moviePtr)
								Screen('FinalizeMovie', obj.moviePtr);
							end
						case 2
							clear mimg;
					end
					obj.moviePtr = [];
				end
				Screen('Close');
				Screen('CloseAll');
				obj.win=[];
				Priority(0);
				ShowCursor;
				%obj.serialP.close;
				obj.lJack.close;
				obj.lJack=[];
				rethrow(ME)
				
			end
			
			if obj.verbose==1
				obj.printLog;
			end
		end
		
		% ===================================================================
		%> @brief Set method for distance
		%>
		%> @param
		% ===================================================================
		function set.distance(obj,value)
			if ~(value > 0)
				value = 57.3;
			end
			obj.distance = value;
			obj.makeGrid;
			%obj.salutation(['set distance: ' num2str(obj.distance) '|ppd: ' num2str(obj.ppd)],'Custom set method')
		end
		
		% ===================================================================
		%> @brief Set method for pixelsPerCm
		%>
		%> @param
		% ===================================================================
		function set.pixelsPerCm(obj,value)
			if ~(value > 0)
				value = 44;
			end
			obj.pixelsPerCm = value;
			obj.makeGrid;
			%obj.salutation(['set pixelsPerCm: ' num2str(obj.pixelsPerCm) '|ppd: ' num2str(obj.ppd)],'Custom set method')
		end
		
		% ===================================================================
		%> @brief Get method for ppd (a dependent property)
		%>
		%> @param
		% ===================================================================
		function ppd = get.ppd(obj)
			ppd=round(obj.pixelsPerCm*(obj.distance/57.3)); %set the pixels per degree
		end
		
		% ===================================================================
		%> @brief getTimeLog Prints out the frame time plots from a run
		%>
		%> @param
		% ===================================================================
		function getTimeLog(obj)
			obj.printLog;
		end
		
		% ===================================================================
		%> @brief getTimeLog Prints out the frame time plots from a run
		%>
		%> @param
		% ===================================================================
		function deleteTimeLog(obj)
			%obj.timeLog = [];
		end
		
		% ===================================================================
		%> @brief getTimeLog Prints out the frame time plots from a run
		%>
		%> @param
		% ===================================================================
		function restoreTimeLog(obj,tLog)
			if isstruct(tLog);obj.timeLog = tLog;end
		end
		
		% ===================================================================
		%> @brief refresh the screen values stored in the object
		%>
		%> @param
		% ===================================================================
		function refreshScreen(obj)
			obj.prepareScreen;
		end
		
		% ===================================================================
		%> @brief updatesList
		%> Updates the list of stimuli current in the object
		%> @param
		% ===================================================================
		function updatesList(obj)
			if isempty(obj.stimulus) || isstruct(obj.stimulus{1}) %stimuli should be class not structure, reset
				obj.stimulus = [];
			end
			obj.sList.n = 0;
			obj.sList.list = [];
			obj.sList.index = [];
			obj.sList.gN = 0;
			obj.sList.bN = 0;
			obj.sList.dN = 0;
			obj.sList.sN = 0;
			obj.sList.uN = 0;
			if ~isempty(obj.stimulus)
				sn=length(obj.stimulus);
				obj.sList.n=sn;
				for i=1:sn
					obj.sList.index = [obj.sList.index i];
					switch obj.stimulus{i}.family
						case 'grating'
							obj.sList.list = [obj.sList.list 'g'];
							obj.sList.gN = obj.sList.gN + 1;
						case 'bar'
							obj.sList.list = [obj.sList.list 'b'];
							obj.sList.bN = obj.sList.bN + 1;
						case 'dots'
							obj.sList.list = [obj.sList.list 'd'];
							obj.sList.dN = obj.sList.dN + 1;
						case 'spot'
							obj.sList.list = [obj.sList.list 's'];
							obj.sList.sN = obj.sList.sN + 1;
						otherwise
							obj.sList.list = [obj.sList.list 'u'];
							obj.sList.uN = obj.sList.uN + 1;
					end
				end
			end
		end
		
	end%-------------------------END PUBLIC METHODS--------------------------------%
	
	%=======================================================================
	methods (Access = private) %------------------PRIVATE METHODS
		%=======================================================================
		
		% ===================================================================
		%> @brief InitialiseTask
		%> Sets up the task structure with dynamic properties
		%> @param
		% ===================================================================
		function initialiseTask(obj)
			
			if isempty(obj.task) %we have no task setup, so we generate one.
				obj.task=stimulusSequence;
				obj.task.nTrials=1;
				obj.task.nSegments = 1;
				obj.task.trialTime = 2;
				obj.task.randomiseStimuli;
			end
			%find out how many stimuli there are, wrapped in the obj.stimulus
			%structure
			obj.updatesList;
			
			%Set up the task structures needed
			
			if isempty(obj.task.findprop('tick'))
				obj.task.addprop('tick'); %add new dynamic property
			end
			obj.task.tick=0;
			
			if isempty(obj.task.findprop('thisRun'))
				obj.task.addprop('thisRun'); %add new dynamic property
			end
			obj.task.thisRun=1;
			
			if isempty(obj.task.findprop('thisTrial'))
				obj.task.addprop('thisTrial'); %add new dynamic property
			end
			obj.task.thisTrial=1;
			
			if isempty(obj.task.findprop('totalRuns'))
				obj.task.addprop('totalRuns'); %add new dynamic property
			end
			obj.task.totalRuns=1;
			
			if isempty(obj.task.findprop('isBlank'))
				obj.task.addprop('isBlank'); %add new dynamic property
			end
			obj.task.isBlank = false;
			
			if isempty(obj.task.findprop('switched'))
				obj.task.addprop('switched'); %add new dynamic property
			end
			obj.task.switched = false;
			
			if isempty(obj.task.findprop('strobeThisFrame'))
				obj.task.addprop('strobeThisFrame'); %add new dynamic property
			end
			obj.task.strobeThisFrame = false;
			
			if isempty(obj.task.findprop('doUpdate'))
				obj.task.addprop('doUpdate'); %add new dynamic property
			end
			obj.task.doUpdate = false;
			
			if isempty(obj.task.findprop('startTime'))
				obj.task.addprop('startTime'); %add new dynamic property
			end
			obj.task.startTime=0;
			
			if isempty(obj.task.findprop('switchTime'))
				obj.task.addprop('switchTime'); %add new dynamic property
			end
			obj.task.switchTime=0;
			
			if isempty(obj.task.findprop('switchTick'))
				obj.task.addprop('switchTick'); %add new dynamic property
			end
			obj.task.switchTick=0;
			
			if isempty(obj.task.findprop('timeNow'))
				obj.task.addprop('timeNow'); %add new dynamic property
			end
			obj.task.timeNow=0;
			
			if isempty(obj.task.findprop('stimIsDrifting'))
				obj.task.addprop('stimIsDrifting'); %add new dynamic property
			end
			obj.task.stimIsDrifting=[];
			
			if isempty(obj.task.findprop('stimIsMoving'))
				obj.task.addprop('stimIsMoving'); %add new dynamic property
			end
			obj.task.stimIsMoving=[];
			
			if isempty(obj.task.findprop('stimIsDots'))
				obj.task.addprop('stimIsDots'); %add new dynamic property
			end
			obj.task.stimIsDots=[];
			
			if isempty(obj.task.findprop('stimIsFlashing'))
				obj.task.addprop('stimIsFlashing'); %add new dynamic property
			end
			obj.task.stimIsFlashing=[];
			
		end
		
		% ===================================================================
		%> @brief updateVars
		%> Updates the stimulus objects with the current variable set
		%> @param thisTrial is the current trial
		%> @param thisRun is the current run
		% ===================================================================
		function updateVars(obj,thisTrial,thisRun)
			
			%As we change variables in the blank, we optionally send the
			%values for the next stimulus
			if ~exist('thisTrial','var') || ~exist('thisRun','var')
				thisTrial=obj.task.thisTrial;
				thisRun=obj.task.thisRun;
			end
			
			if thisTrial > obj.task.nTrials
				return %we've reached the end of the experiment, no need to update anything!
			end
			
			%start looping through out variables
			for i=1:obj.task.nVars
				ix = obj.task.nVar(i).stimulus; %which stimulus
				value=obj.task.outVars{thisTrial,i}(thisRun);
				name=[obj.task.nVar(i).name 'Out']; %which parameter
				offsetix = obj.task.nVar(i).offsetstimulus;
				offsetvalue = obj.task.nVar(i).offsetvalue;
				
				if ~isempty(offsetix)
					obj.stimulus{offsetix}.(name)=value+offsetvalue;
					if thisTrial ==1 && thisRun == 1 %make sure we update if this is the first run, otherwise the variables may not update properly
						obj.stimulus{offsetix}.update;
					end
				end
				
				for j = ix %loop through our stimuli references for this variable
					obj.stimulus{j}.(name)=value;
					if thisTrial == 1 && thisRun == 1 %make sure we update if this is the first run, otherwise the variables may not update properly
						obj.stimulus{j}.update;
					end
				end
			end
		end
		
		% ===================================================================
		%> @brief updateTask
		%> Updates the stimulus run state; update the stimulus values for the
		%> current trial and increments the switchTime and switchTick timer
		% ===================================================================
		function updateTask(obj)
			obj.task.timeNow = GetSecs;
			if obj.task.tick==1 %first frame
				obj.task.isBlank = false;
				obj.task.startTime = obj.task.timeNow;
				obj.task.switchTime = obj.task.trialTime; %first ever time is for the first trial
				obj.task.switchTick = obj.task.trialTime*ceil(obj.screenVals.fps);
				obj.lJack.prepareStrobe(obj.task.outIndex(obj.task.totalRuns));
				obj.task.strobeThisFrame = true;
			end
			
			%-------------------------------------------------------------------
			if obj.task.realTime == true %we measure real time
				trigger = obj.task.timeNow <= (obj.task.startTime+obj.task.switchTime);
			else %we measure frames, prone to error build-up
				trigger = obj.task.tick < obj.task.switchTick;
			end
			
			if trigger == true

				if obj.task.isBlank == false %showing stimulus, need to call animate for each stimulus
					% because the update happens before the flip, but the drawing of the update happens
					% only in the next loop, we have to send the strobe one loop after we set switched
					% to true
					if obj.task.switched == true; 
						obj.task.strobeThisFrame = true;
					else
						obj.task.strobeThisFrame = false;
					end
					
					%if obj.verbose==true;tic;end
					for i = 1:obj.sList.n %parfor appears faster here for 6 stimuli at least
						obj.stimulus{i}.animate;
					end
					%if obj.verbose==true;fprintf('\nStimuli animation: %g seconds',toc);end
					
				else %this is a blank stimulus
					%this causes the update of the stimuli, which may take more than one refresh, to
					%occur during the second blank flip, thus we don't lose any timing.
					if obj.task.switched == false && obj.task.strobeThisFrame == true
						obj.task.doUpdate = true;
					end
					% because the update happens before the flip, but the drawing of the update happens
					% only in the next loop, we have to send the strobe one loop after we set switched
					% to true
					if obj.task.switched == true; 
						obj.task.strobeThisFrame = true;
					else
						obj.task.strobeThisFrame = false;
					end
					% now update our stimuli, we do it after the first blank as less
					% critical timingwise
					if obj.task.doUpdate == true
						%if obj.verbose==true;tic;end
						if ~mod(obj.task.thisRun,obj.task.minTrials) %are we rolling over into a new trial?
							mT=obj.task.thisTrial+1;
							mR = 1;
						else
							mT=obj.task.thisTrial;
							mR = obj.task.thisRun + 1;
						end
						%obj.uiCommand;
						obj.updateVars(mT,mR);
						for i = 1:obj.sList.n
							obj.stimulus{i}.update;
						end
						obj.task.doUpdate = false;
						%if obj.verbose==true;fprintf('\nStimuli update: %g seconds',toc);end
					end
					
				end
				obj.task.switched = false;
				
				%-------------------------------------------------------------------
			else %need to switch to next trial or blank
				obj.task.switched = true;
				if obj.task.isBlank == false %we come from showing a stimulus
					
					%obj.logMe('IntoBlank');
					obj.task.isBlank = true;
					
					if ~mod(obj.task.thisRun,obj.task.minTrials) %are we within a trial block or not? we add the required time to our switch timer
						obj.task.switchTime=obj.task.switchTime+obj.task.itTime;
						obj.task.switchTick=obj.task.switchTick+(obj.task.itTime*ceil(obj.screenVals.fps));
					else
						obj.task.switchTime=obj.task.switchTime+obj.task.isTime;
						obj.task.switchTick=obj.task.switchTick+(obj.task.isTime*ceil(obj.screenVals.fps));
					end
					
					obj.lJack.prepareStrobe(2047); %get the strobe word to signify stimulus OFF ready
					%obj.logMe('OutaBlank');
					
				else %we have to show the new run on the next flip
					
					%obj.logMe('IntoTrial');
					if obj.task.thisTrial <= obj.task.nTrials
						obj.task.switchTime=obj.task.switchTime+obj.task.trialTime; %update our timer
						obj.task.switchTick=obj.task.switchTick+(obj.task.trialTime*round(obj.screenVals.fps)); %update our timer
						obj.task.isBlank = false;
						obj.task.totalRuns = obj.task.totalRuns + 1;
						if ~mod(obj.task.thisRun,obj.task.minTrials) %are we rolling over into a new trial?
							obj.task.thisTrial=obj.task.thisTrial+1;
							obj.task.thisRun = 1;
						else
							obj.task.thisRun = obj.task.thisRun + 1;
						end
						if obj.task.totalRuns <= length(obj.task.outIndex)
							obj.lJack.prepareStrobe(obj.task.outIndex(obj.task.totalRuns)); %get the strobe word ready
						else
							
						end
					else
						obj.task.thisTrial = obj.task.nTrials + 1;
					end
					%obj.logMe('OutaTrial');
					
				end
			end
		end
		
		% ===================================================================
		%> @brief prepare the Screen values on the local machine
		%>
		%> @param
		%> @return
		% ===================================================================
		function prepareScreen(obj)
			
			obj.maxScreen=max(Screen('Screens'));
			
			if isempty(obj.screen) || obj.screen > obj.maxScreen
				obj.screen = obj.maxScreen;
			end
			
			obj.movieSettings.record = 0;
			obj.movieSettings.size = [400 400];
			obj.movieSettings.quality = 0;
			obj.movieSettings.nFrames = 100;
			obj.movieSettings.type = 1;
			obj.movieSettings.codec = 'rle ';
			
			%get the gammatable and dac information
			[obj.screenVals.gammaTable,obj.screenVals.dacBits,obj.screenVals.lutSize]=Screen('ReadNormalizedGammaTable', obj.screen);
			
			%get screen dimensions
			rect=Screen('Rect',obj.screen);
			obj.screenVals.width=rect(3);
			obj.screenVals.height=rect(4);
			
			obj.screenVals.fps=Screen('FrameRate',obj.screen);
			if obj.screenVals.fps == 0;obj.screenVals.fps = 60;end
			obj.screenVals.ifi=1/obj.screenVals.fps;
			
			%make sure we load up and test the serial port
			%obj.serialP=sendSerial(struct('name',obj.serialPortName,'openNow',1));
			%obj.serialP.toggleDTRLine;
			%obj.serialP.close;
			
			obj.lJack = labJack(struct('name','labJack','openNow',1,'verbosity',1));
			obj.lJack.prepareStrobe(0,[0,255,255],1);
			obj.lJack.close;
			obj.lJack=[];
			
			try
				AssertOpenGL;
			catch ME
				error('OpenGL is required for Opticka!');
			end
			
			obj.computer=Screen('computer');
			obj.ptb=Screen('version');
			
			obj.timeLog.prepTime=GetSecs-obj.timeLog.construct;
			a=zeros(20,1);
			for i=1:20
				a(i)=GetSecs;
			end
			obj.timeLog.deltaGetSecs=mean(diff(a))*1000; %what overhead does GetSecs have in milliseconds?
			WaitSecs(0.01); %preload function
			
			Screen('Preference', 'TextRenderer', 0); %fast text renderer
			
			obj.makeGrid;
			
			%obj.photoDiodeRect(:,1)=[0 0 50 50]';
			
			obj.updatesList;
			
		end
		
		% ===================================================================
		%> @brief Configure grating specific variables
		%>
		%> @param i
		%> @return
		% ===================================================================
		function drawFixationPoint(obj)
			Screen('gluDisk',obj.win,[1 0 1 1],obj.xCenter,obj.yCenter,2);
		end
		
		% ===================================================================
		%> @brief Configure grating specific variables
		%>
		%> @param i
		%> @return
		% ===================================================================
		function drawGrid(obj)
			Screen('DrawDots',obj.win,obj.grid,1,[1 0 1 1],[obj.xCenter obj.yCenter],1);
		end
		
		% ===================================================================
		%> @brief infoText - draws text about frame to screen
		%>
		%> @param
		%> @return
		% ===================================================================
		function infoText(obj)
			if obj.logFrames == true && obj.task.tick > 1
				t=sprintf('T: %i | R: %i [%i/%i] | isBlank: %i | Time: %3.3f (%i)',obj.task.thisTrial,...
					obj.task.thisRun,obj.task.totalRuns,obj.task.nRuns,obj.task.isBlank, ...
					(obj.timeLog.vbl(obj.task.tick-1)-obj.timeLog.startTime),obj.task.tick);
			else
				t=sprintf('T: %i | R: %i [%i/%i] | isBlank: %i | Time: %3.3f (%i)',obj.task.thisTrial,...
					obj.task.thisRun,obj.task.totalRuns,obj.task.nRuns,obj.task.isBlank, ...
					(obj.timeLog.vbl-obj.timeLog.startTime),obj.task.tick);
			end
			for i=1:obj.task.nVars
				t=[t sprintf(' -- %s = %2.2f',obj.task.nVar(i).name,obj.task.outVars{obj.task.thisTrial,i}(obj.task.thisRun))];
			end
			Screen('DrawText',obj.win,t,50,1,[1 1 1 1],[0 0 0 1]);
		end
		
		% ===================================================================
		%> @brief infoText - draws text about frame to screen
		%>
		%> @param
		%> @return
		% ===================================================================
		function infoTextUI(obj)
			t=sprintf('T: %i | R: %i [%i/%i] | isBlank: %i | Time: %3.3f (%i)',obj.task.thisTrial,...
				obj.task.thisRun,obj.task.totalRuns,obj.task.nRuns,obj.task.isBlank, ...
				(obj.timeLog.vbl(obj.task.tick)-obj.task.startTime),obj.task.tick);
			for i=1:obj.task.nVars
				t=[t sprintf(' -- %s = %2.2f',obj.task.nVar(i).name,obj.task.outVars{obj.task.thisTrial,i}(obj.task.thisRun))];
			end
		end
		
		% ===================================================================
		%> @brief Configure grating specific variables
		%>
		%> @param i
		%> @return
		% ===================================================================
		function drawPhotoDiodeSquare(obj,colour)
			Screen('FillRect',obj.win,colour,obj.photoDiodeRect);
		end
		
		% ===================================================================
		%> @brief Draw the background colour
		%>
		%> @param
		%> @return
		% ===================================================================
		function drawBackground(obj)
			Screen('FillRect',obj.win,obj.backgroundColour,[]);
		end
		
		% ===================================================================
		%> @brief print Log of the frame timings
		%>
		%> @param
		%> @return
		% ===================================================================
		function printLog(obj)
			if obj.logFrames == false || ~isfield(obj.timeLog,'date')
				disp('No timing data available')
				return
			end
			vbl=obj.timeLog.vbl*1000;
			show=obj.timeLog.show*1000;
			flip=obj.timeLog.flip*1000;
			index=min([length(vbl) length(flip) length(show)]);
			vbl=vbl(1:index);
			show=show(1:index);
			flip=flip(1:index);
			miss=obj.timeLog.miss(1:index);
			stimTime=obj.timeLog.stimTime(1:index);
			
			figure;
			
			p = panel('defer');
			p.pack(3,1)
			
			scnsize = get(0,'ScreenSize');
			pos=get(gcf,'Position');
			
			p(1,1).select();
			plot(diff(vbl),'ro:')
			hold on
			plot(diff(show),'b--')
			plot(diff(flip),'g-.')
			hold off
			legend('VBL','Show','Flip')
			[m,e]=stderr(diff(vbl),'SE');
			t=sprintf('VBL mean=%2.2f+-%2.2f s.e.', m, e);
			[m,e]=stderr(diff(show),'SE');
			t=[t sprintf(' | Show mean=%2.2f+-%2.2f', m, e)];
			[m,e]=stderr(diff(flip),'SE');
			t=[t sprintf(' | Flip mean=%2.2f+-%2.2f', m, e)];
			p(1,1).title(t)
			p(1,1).xlabel('Frame number (difference between frames)');
			p(1,1).ylabel('Time (milliseconds)');
			
			
			p(2,1).select();
			hold on
			plot(show-vbl,'r')
			plot(show-flip,'g')
			plot(vbl-flip,'b')
			plot(stimTime*2,'k');
			hold off
			legend('Show-VBL','Show-Flip','VBL-Flip');
			[m,e]=stderr(show-vbl,'SE');
			t=sprintf('Show-VBL=%2.2f+-%2.2f', m, e);
			[m,e]=stderr(show-flip,'SE');
			t=[t sprintf(' | Show-Flip=%2.2f+-%2.2f', m, e)];
			[m,e]=stderr(vbl-flip,'SE');
			t=[t sprintf(' | VBL-Flip=%2.2f+-%2.2f', m, e)];
			p(2,1).title(t);
			p(2,1).xlabel('Frame number');
			p(2,1).ylabel('Time (milliseconds)');
			
			p(3,1).select();
			hold on
			plot(miss,'r.-')
			plot(stimTime/100,'k');
			hold off
			p(3,1).title('Missed frames (> 0 means missed frame)');
			p(3,1).xlabel('Frame number');
			p(3,1).ylabel('Miss Value');
			
			newpos = [pos(1) 1 pos(3) scnsize(4)];
			set(gcf,'Position',newpos);
			p.refresh();
			clear vbl show flip index miss stimTime
		end
		
		% ===================================================================
		%> @brief Prints messages dependent on verbosity
		%>
		%> Prints messages dependent on verbosity
		%> @param in the calling function
		%> @param message the message that needs printing to command window
		% ===================================================================
		function salutation(obj,in,message)
			if obj.verbose==1
				if ~exist('in','var')
					in = 'random user';
				end
				if exist('message','var')
					fprintf([message ' | ' in '\n']);
				else
					fprintf(['\nHello from ' obj.screen ' stimulus, ' in '\n\n']);
				end
			end
		end
		
		% ===================================================================
		%> @brief Logs the run loop parameters along with a calling tag
		%>
		%> Logs the run loop parameters along with a calling tag
		%> @param tag the calling function
		% ===================================================================
		function logMe(obj,tag)
			if obj.verbose == 1 && obj.debug == 1
				if ~exist('tag','var')
					tag='#';
				end
				fprintf('%s -- T: %i | R: %i [%i] | B: %i | Tick: %i | Time: %5.8g\n',tag,obj.task.thisTrial,obj.task.thisRun,obj.task.totalRuns,obj.task.isBlank,obj.task.tick,obj.task.timeNow-obj.task.startTime);
			end
		end
		
		% ===================================================================
		%> @brief Makes a 5x5 1deg dot grid for debug mode
		%>
		% ===================================================================
		function makeGrid(obj)
			obj.grid=[];
			for i=-5:5
				obj.grid=horzcat(obj.grid,[-5 -4 -3 -2 -1 0 1 2 3 4 5;i i i i i i i i i i i]);
			end
			obj.grid=obj.grid.*obj.ppd;
		end
		
		% ===================================================================
		%> @brief Sets properties from a structure, ignores invalid properties
		%>
		%> @param args input structure
		% ===================================================================
		function set(obj,args)
			fnames = fieldnames(args); %find our argument names
			for i=1:length(fnames);
				if regexp(fnames{i},obj.allowedPropertiesBase) %only set if allowed property
					obj.salutation(fnames{i},'Configuring setting');
					obj.(fnames{i})=args.(fnames{i}); %we set up the properies from the arguments as a structure
				end
			end
		end
		
	end
end