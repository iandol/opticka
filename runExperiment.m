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
		%>show command logs and a time log after stimlus presentation 1 = yes | 0 = no
		verbose = 0
		%> hide the black flash as PTB tests it refresh timing, uses a gamma trick 1 = yes | 0 = no
		hideFlash = 0
		%> change the parameters for poorer temporal fidelity during debugging 1 = yes | 0 = no
		debug = 1
		%> shows the info text and position grid during stimulus presentation 1 = yes | 0 = no
		visualDebug = 1
		%> normally should be left at 1 (1 is added to this number so doublebuffering is enabled)
		doubleBuffer = 1
		%> multisampling sent to the graphics card, try values []=disabled, 4, 8 and 16
		antiAlias = []
		%> background of display during stimulus presentation
		backgroundColour = [0.5 0.5 0.5 0]
		%> shunt screen center by X degrees
		screenXOffset = 0
		%> shunt screen center by Y degrees
		screenYOffset = 0
		%> use OpenGL blending mode 1 = yes | 0 = no
		blend = 0
		%> GL_ONE %src mode
		srcMode = 'GL_ONE'
		%> GL_ONE % dst mode
		dstMode = 'GL_ZERO'
		%> show a fixation spot?
		fixationPoint = 1
		%> show a white square to trigger a photodiode attached to screen
		photoDiode = 1
		%> name of serial port to send TTL out on, if set to 'dummy' then ignore
		serialPortName = 'dummy'
		useLabJack = 0
		%> LabJack object
		lJack
		%> settings for movie output
		movieSettings = []
		%> Choose the gamma correction table to use
		gammaTable
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
		allowedPropertiesBase='^(pixelsPerCm|distance|screen|windowed|stimulus|task|serialPortName|backgroundColor|screenXOffset|screenYOffset|blend|fixationPoint|srcMode|dstMode|antiAlias|debug|photoDiode|verbose|hideFlash)$'
		%> serial port object opened
		serialP
		%> the window rectangle
		winRect
		%> the photoDiode rectangle
		photoDiodeRect
		%> the values comuted to draw the 1deg dotted grid in debug mode
		grid
		%> the movie pointer
		moviePtr = []
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
			if nargin>0 && isstruct(args) %user passed some settings, we will parse through them and set them up
				if nargin>0 && isstruct(args)
					fnames = fieldnames(args); %find our argument names
					for i=1:length(fnames);
						if regexp(fnames{i},obj.allowedPropertiesBase) %only set if allowed property
							obj.salutation(fnames{i},'Configuring property in runExperiment constructor');
							obj.(fnames{i})=args.(fnames{i}); %we set up the properies from the arguments as a structure
						end
					end
				end
			end
			obj.prepareScreen;
		end
		
		% ===================================================================
		%> @brief The main run loop
		%>
		%> @param obj required class object
		% ===================================================================
		function run(obj)
			
			%initialise timeLog for this run (100,000 should be a 19min run)
			obj.timeLog.date=clock;
			obj.timeLog.startrun=GetSecs;
			obj.timeLog.vbl=zeros(obj.task.nFrames,1);
			obj.timeLog.show=zeros(obj.task.nFrames,1);
			obj.timeLog.flip=zeros(obj.task.nFrames,1);
			obj.timeLog.miss=zeros(obj.task.nFrames,1);
			obj.timeLog.stimTime=zeros(obj.task.nFrames,1);
			
			%if obj.windowed(1)==0;HideCursor;end
			
			if obj.hideFlash==1 && obj.windowed(1)==0
				obj.screenVals.oldGamma = Screen('LoadNormalizedGammaTable', obj.screen, repmat(obj.screenVals.gammaTable(128,:), 256, 1));
			end
			
			%-------Set up serial line and LabJack for this run...
			%obj.serialP=sendSerial(struct('name',obj.serialPortName,'openNow',1,'verbosity',obj.verbose));
			%obj.serialP.setDTR(0);
			
			if obj.useLabJack == 1
				strct = struct('openNow',1,'name','default','verbosity',obj.verbose);
			else
				strct = struct('openNow',0,'name','null','verbosity',0,'silentMode',1);
			end
			obj.lJack = labJack(strct);
			obj.lJack.setFIO6(1);WaitSecs(0.05);obj.lJack.setFIO6(0); %Trigger the omniplex into paused mode
			WaitSecs(0.5);
			%-----------------------------------------------------
			
			try
				if obj.debug==1 || obj.windowed(1)>0
					Screen('Preference', 'SkipSyncTests', 2);
					Screen('Preference', 'VisualDebugLevel', 0);
					Screen('Preference', 'Verbosity', 2);
					Screen('Preference', 'SuppressAllWarnings', 0);
				else
					Screen('Preference', 'SkipSyncTests', 0);
					Screen('Preference', 'VisualDebugLevel', 3);
					Screen('Preference', 'Verbosity', 3); %errors and warnings
					Screen('Preference', 'SuppressAllWarnings', 0);
				end
				
				PsychImaging('PrepareConfiguration');
				PsychImaging('AddTask', 'General', 'FloatingPoint32BitIfPossible');
				PsychImaging('AddTask', 'General', 'NormalizedHighresColorRange');
				
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
				obj.screenVals.ifi=Screen('GetFlipInterval', obj.win);
				if obj.screenVals.fps==0
					obj.screenVals.fps=round(1/obj.screenVals.ifi);
				end
				obj.screenVals.halfisi=obj.screenVals.ifi/2;
				
				Priority(0);
				
				if obj.hideFlash==1
					Screen('LoadNormalizedGammaTable', obj.screen, obj.screenVals.gammaTable);
				end
				
				AssertGLSL;
				
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
				
				for j=1:obj.sList.n
					obj.stimulus{j}.setup(obj); %call setup and pass it the runExperiment object
					if obj.stimulus{j}.doMotion == 1
						obj.task.stimIsMoving=[obj.task.stimIsMoving j];
					end
					if obj.stimulus{j}.doDots == 1
						obj.task.stimIsDots=[obj.task.stimIsDots j];
					end
					if obj.stimulus{j}.doDrift == 1
						obj.task.stimIsDrifting=[obj.task.stimIsDrifting j];
					end
					if obj.stimulus{j}.doFlash == 1
						obj.task.stimIsFlashing=[obj.task.stimIsFlashing j];
					end
				end
				
				if obj.movieSettings.record == 1
					obj.movieSettings.size=CenterRect([0 0 obj.movieSettings.size(1) obj.movieSettings.size(2)],obj.winRect);
					disp(num2str(obj.movieSettings.size));
					disp('---');
					switch obj.movieSettings.type
						case 1
							obj.moviePtr = Screen('CreateMovie', obj.win,...
								['/Users/opticka/Desktop/test' num2str(round(rand(1,1, 'double')*1e8)) '.mov'],[],[], ...
								obj.screenVals.fps, 'EncodingQuality=1; CodecFOURCC=rle ');
						case 2
							obj.movieSettings.loop=1;
							mimg = cell(obj.movieSettings.nFrames,1);
					end
				end
				
				obj.updateVars; %set the variables for the very first run;
				
				KbReleaseWait; %make sure keyboard keys are all released
				
				%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
				%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
				% Our main display loop
				%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
				%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
				obj.lJack.setFIO4(1) %this is RSTART, unpausing the omniplex
				WaitSecs(0.1);
				Priority(MaxPriority(obj.win)); %bump our priority to maximum allowed
				
				obj.task.tick=1;
				obj.timeLog.beforeDisplay=GetSecs;
				obj.timeLog.stimTime(1) = 1;
				[obj.timeLog.vbl(1),vbl.timeLog.show(1),obj.timeLog.flip(1),obj.timeLog.miss(1)] = Screen('Flip', obj.win);
				
				while obj.task.thisTrial <= obj.task.nTrials
					if obj.task.isBlank==1
						if obj.photoDiode==1
							obj.drawPhotoDiodeSquare([0 0 0 0]);
						end
					else
						if ~isempty(obj.backgroundColour)
							obj.drawBackground;
						end
						for j=1:obj.sList.n
							obj.stimulus{j}.draw();
						end
						if obj.photoDiode==1
							obj.drawPhotoDiodeSquare([1 1 1 1]);
						end
						if obj.fixationPoint==1
							obj.drawFixationPoint;
						end
					end
					if obj.visualDebug==1
						obj.drawGrid;
						obj.infoText;
					end
					
					Screen('DrawingFinished', obj.win); % Tell PTB that no further drawing commands will follow before Screen('Flip')
					
					[~, ~, buttons]=GetMouse(obj.screen);
					if any(buttons);break;end; %break on any mouse click, needs to change
					
					obj.updateTask(); %update our task structure
					
					%======= Show it at next retrace: ========%
					[obj.timeLog.vbl(obj.task.tick+1),obj.timeLog.show(obj.task.tick+1),obj.timeLog.flip(obj.task.tick+1),obj.timeLog.miss(obj.task.tick+1)] = Screen('Flip', obj.win, (obj.timeLog.vbl(obj.task.tick)+obj.screenVals.halfisi));
					%=========================================%
					if obj.task.switched == 1 || obj.task.tick == 1
						obj.lJack.strobeWord; %send our word out to the LabJack
					end
					
					if obj.task.tick==1
						obj.timeLog.startflip=obj.timeLog.vbl(obj.task.tick) + obj.screenVals.halfisi;
						obj.timeLog.start=obj.timeLog.show(obj.task.tick+1);
					end
					
					if obj.task.isBlank==0
						obj.timeLog.stimTime(obj.task.tick+1)=1+obj.task.switched;
					else
						obj.timeLog.stimTime(obj.task.tick+1)=0-obj.task.switched;
					end
					
					obj.task.tick=obj.task.tick+1;
					
					if obj.movieSettings.record == 1
						if obj.task.isBlank==0 && obj.movieSettings.loop <= obj.movieSettings.nFrames
							switch obj.movieSettings.type
								case 1
									Screen('AddFrameToMovie', obj.win, obj.movieSettings.size, 'frontBuffer', obj.movieSettings.quality, 3);
								case 2
									mimg{obj.movieSettings.loop}=Screen('GetImage', obj.win, obj.movieSettings.size, 'frontBuffer', obj.movieSettings.quality, 3);
									obj.movieSettings.loop=obj.movieSettings.loop+1;
							end
						end
					end
					
				end
				
				%---------------------------------------------Finished display loop
				obj.drawBackground;
				Screen('Flip', obj.win);
				obj.lJack.prepareStrobe(0,[],1);
				obj.timeLog.afterDisplay=GetSecs;
				WaitSecs(0.1);
				obj.lJack.setFIO4(0); %this is RSTOP, pausing the omniplex
				obj.lJack.setFIO5(0);
				
				obj.timeLog.deltaDispay=obj.timeLog.afterDisplay-obj.timeLog.beforeDisplay;
				obj.timeLog.deltaUntilDisplay=obj.timeLog.beforeDisplay-obj.timeLog.start;
				obj.timeLog.deltaToFirstVBL=obj.timeLog.vbl(1)-obj.timeLog.beforeDisplay;
				obj.timeLog.deltaStart=obj.timeLog.startflip-obj.timeLog.start;
				obj.timeLog.deltaUpdateDiff = obj.timeLog.start-obj.task.startTime;
				
				obj.info = Screen('GetWindowInfo', obj.win);
				
				Screen('Close');
				Screen('CloseAll');
				
				if obj.movieSettings.record == 1
					switch obj.movieSettings.type
						case 1
							Screen('FinalizeMovie', obj.moviePtr);
						case 2
							save('~/Desktop/movie.mat','mimg');
					end
				end
				
				obj.win=[];
				Priority(0);
				ShowCursor;
				obj.serialP.close;
				WaitSecs(0.5);
				obj.lJack.setFIO6(1);WaitSecs(0.05);obj.lJack.setFIO6(0); %we stop recording mode completely
				obj.lJack.close;
				obj.lJack=[];
				
			catch ME
				
				obj.lJack.setFIO4(0) %this is RSTOP, repausing the omniplex
				obj.lJack.setFIO5(0);
				obj.lJack.setFIO6(0);
				if obj.hideFlash == 1 || obj.windowed(1) ~= 1
					Screen('LoadNormalizedGammaTable', obj.screen, obj.screenVals.gammaTable);
				end
				if obj.movieSettings.record == 1
					switch obj.movieSettings.type
						case 1
							Screen('FinalizeMovie', obj.moviePtr);
						case 2
							clear mimg;
					end
				end
				Screen('Close');
				Screen('CloseAll');
				obj.win=[];
				Priority(0);
				ShowCursor;
				obj.serialP.close;
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
			obj.salutation(['set distance: ' num2str(obj.distance) '|ppd: ' num2str(obj.ppd)],'Custom set method')
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
			obj.salutation(['set pixelsPerCm: ' num2str(obj.pixelsPerCm) '|ppd: ' num2str(obj.ppd)],'Custom set method')
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
			obj.task.isBlank=0;
			
			if isempty(obj.task.findprop('switched'))
				obj.task.addprop('switched'); %add new dynamic property
			end
			obj.task.switched=0;
			
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
				name=obj.task.nVar(i).name; %which parameter
				
				for j=1:length(ix) %loop through our stimuli references for this variable
					obj.stimulus{ix(j)}.([name 'Out'])=value;
					if thisTrial ==1 && thisRun == 1 %make sure we update if this is the first run, otherwise the variables may not update properly
						obj.stimulus{ix(j)}.update;
					end
				end
			end
		end
		
		% ===================================================================
		%> @brief updateTask
		%> Updates the stimulus run state; update the stimulus values for the
		%> current trial and increments the switchTime timer
		% ===================================================================
		function updateTask(obj)
			obj.task.timeNow = GetSecs;
			if obj.task.tick==1 %first ever loop
				obj.task.isBlank = 0;
				obj.task.startTime = obj.task.timeNow;
				obj.task.switchTime = obj.task.trialTime; %first ever time is for the first trial
				obj.task.switchTick = obj.task.trialTime*ceil(obj.screenVals.fps);
				obj.lJack.prepareStrobe(obj.task.outIndex(obj.task.totalRuns));
			end
			
			%-------------------------------------------------------------------
			if obj.task.realTime == 1 %we measure real time
				trigger = obj.task.timeNow <= (obj.task.startTime+obj.task.switchTime);
			else %we measure frames, prone to error build-up
				trigger = obj.task.tick <= obj.task.switchTick;
			end
			if trigger
				
				if obj.task.isBlank == 0 %not in an interstimulus time, need to update drift, motion and pulsation
					
					for i = 1:obj.sList.n
						obj.stimulus{i}.animate;
					end
					
				else %blank stimulus, we don't need to update anything
					if ~mod(obj.task.thisRun,obj.task.minTrials) %are we rolling over into a new trial?
						mT=obj.task.thisTrial+1;
						mR = 1;
					else
						mT=obj.task.thisTrial;
						mR = obj.task.thisRun + 1;
					end
					%now update our stimuli, we do it in the blank as less
					%critical timingwise
					if obj.task.switched == 1
						obj.updateVars(mT,mR);
						for i = 1:obj.sList.n
							obj.stimulus{i}.update;
						end
					end
					
				end
				obj.task.switched = 0;
				
				%-------------------------------------------------------------------
			else %need to switch to next trial or blank
				obj.task.switched = 1;
				if obj.task.isBlank == 0 %we come from showing a stimulus
					
					%obj.logMe('IntoBlank');
					obj.task.isBlank = 1;
					
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
						obj.task.switchTick=obj.task.switchTick+(obj.task.trialTime*ceil(obj.screenVals.fps)); %update our timer
						obj.task.isBlank = 0;
						obj.task.totalRuns = obj.task.totalRuns + 1;
						if ~mod(obj.task.thisRun,obj.task.minTrials) %are we rolling over into a new trial?
							obj.task.thisTrial=obj.task.thisTrial+1;
							obj.task.thisRun = 1;
						else
							obj.task.thisRun = obj.task.thisRun + 1;
						end
						if obj.task.totalRuns < length(obj.task.outIndex)
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
			obj.movieSettings.type = 2;
			
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
			obj.serialP=sendSerial(struct('name',obj.serialPortName,'openNow',1));
			obj.serialP.toggleDTRLine;
			obj.serialP.close;
			
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
			for i=1:20
				a(i)=GetSecs;
			end
			obj.timeLog.deltaGetSecs=mean(diff(a))*1000; %what overhead does GetSecs have in milliseconds?
			WaitSecs(0.01); %preload function
			
			Screen('Preference', 'TextRenderer', 0); %fast text renderer
			
			obj.makeGrid;
			
			obj.photoDiodeRect(:,1)=[0 0 60 60]';
			
			obj.updatesList;
			
		end
		
		% ===================================================================
		%> @brief Configure grating specific variables
		%>
		%> @param i
		%> @return
		% ===================================================================
		function drawFixationPoint(obj)
			Screen('gluDisk',obj.win,[1 0 1 1],obj.xCenter,obj.yCenter,3);
		end
		
		% ===================================================================
		%> @brief Configure grating specific variables
		%>
		%> @param i
		%> @return
		% ===================================================================
		function drawGrid(obj)
			Screen('DrawDots',obj.win,obj.grid,1,[1 0 0 1],[obj.xCenter obj.yCenter],1);
		end
		
		% ===================================================================
		%> @brief infoText - draws text about frame to screen
		%>
		%> @param
		%> @return
		% ===================================================================
		function infoText(obj)
			t=sprintf('T: %i | R: %i [%i] | isBlank: %i | Time: %3.3f (%i)',obj.task.thisTrial,...
				obj.task.thisRun,obj.task.totalRuns,obj.task.isBlank,(obj.timeLog.vbl(obj.task.tick)-obj.task.startTime),obj.task.tick);
			for i=1:obj.task.nVars
				t=[t sprintf('\n\n\t\t%s = %2.2f',obj.task.nVar(i).name,obj.task.outVars{obj.task.thisTrial,i}(obj.task.thisRun))];
			end
			
			Screen('DrawText',obj.win,t,50,1,[1 1 1 1],[0 0 1]);
		end
		
		% ===================================================================
		%> @brief infoText - draws text about frame to screen
		%>
		%> @param
		%> @return
		% ===================================================================
		function infoTextUI(obj)
			t=sprintf('T: %i | R: %i [%i] | isBlank: %i | Time: %3.3f (%i)',obj.task.thisTrial,...
				obj.task.thisRun,obj.task.totalRuns,obj.task.isBlank,(obj.timeLog.vbl(obj.task.tick)-obj.task.startTime),obj.task.tick);
			for i=1:obj.task.nVars
				t=[t sprintf('\n\n\t\t%s = %2.2f',obj.task.nVar(i).name,obj.task.outVars{obj.task.thisTrial,i}(obj.task.thisRun))];
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
			if ~isfield(obj.timeLog,'date')
				warndlg('No timing data available')
				return
			end
			vbl=obj.timeLog.vbl(obj.timeLog.vbl>0)*1000;
			show=obj.timeLog.show(obj.timeLog.show>0)*1000;
			flip=obj.timeLog.flip(obj.timeLog.flip>0)*1000;
			index=min([length(vbl) length(flip) length(show)]);
			vbl=vbl(1:index);
			show=show(1:index);
			flip=flip(1:index);
			miss=obj.timeLog.miss(1:index);
			stimTime=obj.timeLog.stimTime(1:index);
			
			figure;
			
			scnsize = get(0,'ScreenSize');
			pos=get(gcf,'Position');
			
			subplot(3,1,1);
			plot(1:index-2,diff(vbl(2:end)),'ro:')
			hold on
			plot(1:index-2,diff(show(2:end)),'b--')
			plot(1:index-2,diff(flip(2:end)),'g-.')
			legend('VBL','Show','Flip')
			[m,e]=stderr(diff(vbl),'SE');
			t=sprintf('VBL mean=%2.2f+-%2.2f s.e.', m, e);
			[m,e]=stderr(diff(show),'SE');
			t=[t sprintf(' | Show mean=%2.2f+-%2.2f', m, e)];
			[m,e]=stderr(diff(flip),'SE');
			t=[t sprintf(' | Flip mean=%2.2f+-%2.2f', m, e)];
			title(t)
			xlabel('Frame number (difference between frames)');
			ylabel('Time (milliseconds)');
			hold off
			
			subplot(3,1,2)
			hold on
			plot(show(2:index)-vbl(2:index),'r')
			plot(show(2:index)-flip(2:index),'g')
			plot(vbl(2:index)-flip(2:index),'b')
			plot(stimTime(2:index)*10,'k');
			title('VBL - Flip time in ms')
			legend('Show-VBL','Show-Flip','VBL-Flip')
			xlabel('Frame number');
			ylabel('Time (milliseconds)');
			
			subplot(3,1,3)
			hold on
			plot(miss,'r.-')
			plot(stimTime/50,'k');
			title('Missed frames')
			
			newpos = [pos(1) 1 pos(3) scnsize(4)];
			set(gcf,'Position',newpos);
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
		
	end
end