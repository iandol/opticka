classdef (Sealed) runExperiment < dynamicprops
	%RUNEXPERIMENT The main class which accepts a task and stimulus object
	%and runs the stimuli based on the task object passed. The class
	%controls the fundamental configuration of the screen (calibration, size
	%etc.), and manages communication to the DAQ system using TTL pulses out
	%and communication over a UDP client<->server socket.
	%  Stimulus must be a stimulus class, i.e. gratingStimulus and friends,
	%  so for example: 
	%
	%  gs.g=gratingStimulus(struct('mask',1,'sf',1));
	%  ss=runExperiment(struct('stimulus',gs,'windowed',1));
	%  ss.run;
	%	
	%	will run a minimal experiment showing a 1c/d circularly masked grating, repeating the
	%	display indefinately
	
	properties
		pixelsPerCm = 44 %MBP 1440x900 is 33.2x20.6cm so approx 44px/cm, Flexscan is 32px/cm @1280 26px/cm @ 1024
		distance = 57.3 % rad2ang(2*(atan((0.5*1cm)/57.3cm))) equals 1deg
		stimulus %stimulus class passed from gratingStulus and friends
		task %the structure of the task, and any callbacks embedded
		screen = [] %which screen to display on, [] means use max screen
		windowed = 0 % if 1 useful for debugging, but remember timing will be poor
		verbose = 0 %show time log after stumlus presentation
		hideFlash = 0 %hide the black flash as PTB tests it refresh timing.
		debug = 1 % change the parameters for poorer temporal fidelity during debugging
		visualDebug = 1 %show the info text and position grid
		doubleBuffer = 1 %normally should be left at 1
		antiAlias = [] %multisampling sent to the graphics card, try values []=disabled, 4, 8 and 16
		backgroundColour = [0.5 0.5 0.5 0] % background of display during stimulus presentation
		screenXOffset = 0 %shunt screen center by X degrees
		screenYOffset = 0 %shunt screen center by Y degrees
		blend = 0 %use OpenGL blending mode
		srcMode = 'GL_ONE' %GL_ONE %src mode
		dstMode = 'GL_ZERO' %GL_ONE % dst mode
		fixationPoint = 1 %show a fixation spot?
		photoDiode = 1 %show a white square to trigger a photodiode attached to screen
		serialPortName = 'dummy' %name of serial port to send TTL out on, if set to 'dummy' then ignore
		useLabJack = 0
		lJack %LabJack object
	end
	
	properties (SetAccess = private, GetAccess = public)
		win %the handle returned by opening a PTB window
		xCenter %computed X center
		yCenter %computed Y center
		ppd %calculated from distance and pixelsPerCm
		maxScreen %set automatically on construction
		info %?
		computer %general computer info
		ptb %PTB info
		screenVals %gamma tables and the like
		timeLog %log times during display
		sVals %calculated stimulus values for display
		taskLog %detailed info as the experiment runs
		sList %for heterogenous stimuli, we need a way to index into the stimulus so we don't waste time doing this on each iteration
		grid
	end
	
	properties (SetAccess = private, GetAccess = private)
		black=0 %black index
		white=1 %white index
		allowedPropertiesBase='^(pixelsPerCm|distance|screen|windowed|stimulus|task|serialPortName|backgroundColor|screenXOffset|screenYOffset|blend|fixationPoint|srcMode|dstMode|antiAlias|debug|photoDiode|verbose|hideFlash)$'
		serialP %serial port object opened
		winRect %the window rectangle
		photoDiodeRect %the photoDiode rectangle
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
			
			%HideCursor; %hide mouse
			
			if obj.hideFlash==1 && obj.windowed==0
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
			obj.lJack.prepareStrobe(0,[],1);
			%-----------------------------------------------------
			
			try
				if obj.debug==1 || obj.windowed==1
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
					[obj.win, obj.winRect] = PsychImaging('OpenWindow', obj.screen, obj.backgroundColour,[1 1 obj.windowed(1)+1 obj.windowed(2)+1], [], obj.doubleBuffer+1,[],obj.antiAlias);
				end
				
				obj.timeLog.postOpenWindow=GetSecs;
				obj.timeLog.deltaOpenWindow=(obj.timeLog.postOpenWindow-obj.timeLog.preOpenWindow)*1000;
				
				Priority(MaxPriority(obj.win)); %bump our priority to maximum allowed
				%find our fps if not defined before  
				obj.screenVals.ifi=Screen('GetFlipInterval', obj.win);
				if obj.screenVals.fps==0
					obj.screenVals.fps=1/obj.screenVals.ifi;
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
				
				obj.sVals=[];
				for j=1:obj.sList.n
					switch obj.stimulus.(obj.sList.list(j))(obj.sList.index(j)).family %as our stimuli may be different structures, we need to use these indexes to cycle quickly through them
						case 'grating'
							obj.setupGrating(j);
						case 'bar'
							obj.setupBar(j);
						case 'dots'
							obj.setupDots(j);
						case 'spot'
							obj.setupSpot(j);
						case 'annulus'
							obj.setupAnnulus(j);
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
								switch obj.stimulus.(obj.sList.list(j))(obj.sList.index(j)).family
								case 'grating'
									obj.drawGrating(j);
								case 'bar'
									obj.drawBar(j);
								case 'dots'
									obj.drawDots(j);
								case 'spot'
									obj.drawSpot(j);
								case 'annulus'
									obj.drawAnnulus(j);
							end
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
					
					obj.updateTask; %update our task structure
					
					%======= Show it at next retrace: ========%
					[obj.timeLog.vbl(obj.task.tick+1),obj.timeLog.show(obj.task.tick+1),obj.timeLog.flip(obj.task.tick+1),obj.timeLog.miss(obj.task.tick+1)] = Screen('Flip', obj.win, (obj.timeLog.vbl(obj.task.tick)+obj.screenVals.halfisi));
					%=========================================%
					
					if obj.task.switched == 1
						obj.lJack.strobeWord; %send our word out to the LabJack
					end
					
					if obj.task.tick==1
						obj.timeLog.startflip=obj.timeLog.vbl(obj.task.tick) + obj.screenVals.halfisi;
						obj.timeLog.start=obj.timeLog.show(obj.task.tick+1);
						obj.logMe('IntoTrial');
					end
					
					if obj.task.isBlank==0
						obj.timeLog.stimTime(obj.task.tick+1)=1+obj.task.switched;
					else
						obj.timeLog.stimTime(obj.task.tick+1)=0-obj.task.switched;
					end
					
					obj.task.tick=obj.task.tick+1;
					
				end
				
				%---------------------------------------------Finished display loop
				
				Screen('Flip', obj.win);
				obj.timeLog.afterDisplay=GetSecs;
				obj.lJack.prepareStrobe(0,[],1);
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
				obj.win=[];
				Priority(0);
				ShowCursor;
				obj.serialP.close;
				obj.lJack.close;
				obj.lJack=[];
				
			catch ME
				
				obj.lJack.setFIO4(0) %this is RSTOP, unpausing the omniplex
				obj.lJack.setFIO5(0);
				if obj.hideFlash == 1 || obj.windowed(1) ~= 1
					Screen('LoadNormalizedGammaTable', obj.screen, obj.screenVals.gammaTable);
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
		
		%------------------Make sure pixelsPerDegree is also changed-----
		function set.distance(obj,value)
			if ~(value > 0)
				value = 57.3;
			end
			obj.distance = value;
			obj.ppd=obj.pixelsPerCm*(57.3/obj.distance); %set the pixels per degree
			obj.makeGrid;
			obj.salutation(['set distance: ' num2str(obj.distance) '|ppd: ' num2str(obj.ppd)],'Custom set method')
		end 
		%------------------Make sure pixelsPerDegree is also changed-----
		function set.pixelsPerCm(obj,value)
			if ~(value > 0)
				value = 44;
			end
			obj.pixelsPerCm = value;
			obj.ppd=obj.pixelsPerCm*(57.3/obj.distance); %set the pixels per degree
			obj.makeGrid;
			obj.salutation(['set pixelsPerCm: ' num2str(obj.pixelsPerCm) '|ppd: ' num2str(obj.ppd)],'Custom set method')
		end
		
		function getTimeLog(obj)
			obj.printlog;
		end
		
		% ===================================================================
		%> @brief updatesList
		%> Updates the list of stimuli current in the object
		%> @param 
		% ===================================================================
		function updatesList(obj)
			obj.sList.n=0;
			obj.sList.list = [];
			obj.sList.index = [];
			obj.sList.gN = 0;
			obj.sList.bN = 0;
			obj.sList.dN = 0;
			obj.sList.sN = 0;
			if ~isempty(obj.stimulus)
				obj.sList.fields = fieldnames(obj.stimulus);
				for i=1:length(obj.sList.fields)
					for j=1:length(obj.stimulus.(obj.sList.fields{i}))
						obj.sList.n = obj.sList.n+1;
						obj.sList.list = [obj.sList.list obj.sList.fields{i}];
						obj.sList.index = [obj.sList.index j];
						obj.sList.([obj.sList.fields{i} 'N']) = obj.sList.([obj.sList.fields{i} 'N']) + 1;
					end
				end
			else
				obj.sList.fields = '';
			end
		end

	end
	%-------------------------END PUBLIC METHODS--------------------------------%
	
	methods ( Access = private ) %----------PRIVATE METHODS-------------------%
		
		function makeGrid(obj)
			obj.grid=[];
			for i=-5:5
				obj.grid=horzcat(obj.grid,[-5 -4 -3 -2 -1 0 1 2 3 4 5;i i i i i i i i i i i]);
			end
			obj.grid=obj.grid.*obj.ppd;
		end
		
		%---------------Update the stimulus values for the current trial---------%
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
			
			%work out which stimuli have animaton parameters to update

		end
		
		%-------------set up variables from the task structure -------------------%
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
			for i=1:obj.task.nVars
				ix = obj.task.nVar(i).stimulus; %which stimulus
				value=obj.task.outVars{thisTrial,i}(thisRun);
				name=obj.task.nVar(i).name; %which parameter
				[obj.sVals(ix).(name)]=deal(value); %set our value(s) to current variable(s)
				
				if strcmp(name,'xPosition')||strcmp(name,'yPosition')
					for j=1:length(ix)
						switch obj.sVals(ix(j)).family
							case {'grating','bar'} %!!!!!!!!!this needs refactoring
								obj.sVals(ix(j)).dstRect=Screen('Rect',obj.sVals(ix(j)).texture);
								obj.sVals(ix(j)).dstRect=CenterRectOnPoint(obj.sVals(ix(j)).dstRect,obj.xCenter,obj.yCenter);
								obj.sVals(ix(j)).dstRect=OffsetRect(obj.sVals(ix(j)).dstRect,obj.sVals(ix(j)).xPosition*obj.ppd,obj.sVals(ix(j)).yPosition*obj.ppd);
								obj.sVals(ix(j)).mvRect=obj.sVals(ix(j)).dstRect;
							case {'spot'}
								
							case {'dots'}
								
						end
						
					end
				elseif (strcmp(name,'angle')||strcmp(name,'moveAngle'))
					for j=1:length(ix)
						ts = obj.stimulus.(obj.sList.list(ix(j)))(obj.sList.index(ix(j)));
						switch obj.sVals(ix(j)).family
							case {'grating','bar', 'spot'}
								[obj.sVals(ix(j)).dX obj.sVals(ix(j)).dY]=ts.updatePosition(obj.sVals(ix(j)).delta,obj.sVals(ix(j)).angle);
							case {'dots'}
								ts.updateDots(obj.sVals(ix(j)).coherence,obj.sVals(ix(j)).angle);
								obj.sVals(ix(j)).xy = ts.xy;
								obj.sVals(ix(j)).dxdy = ts.dxdy;
						end
					end
				elseif strcmp(name,'size')
					for j=1:length(ix)
						ts = obj.stimulus.(obj.sList.list(ix(j)))(obj.sList.index(ix(j)));
						switch obj.sVals(ix(j)).family
							case {'grating'}
							case {'bar'}
							case {'spot'}
								obj.sVals(ix(j)).size = (obj.sVals(ix(j)).size * obj.ppd) / 2;
							case {'dots'}
						end
					end
				elseif strcmp(name,'coherence')
					for j=1:length(ix)
						ts = obj.stimulus.(obj.sList.list(ix(j)))(obj.sList.index(ix(j)));
						switch obj.sVals(ix(j)).family
							case {'grating','bar', 'spot'}
								
							case {'dots'}
								ts.updateDots(obj.sVals(ix(j)).coherence,obj.sVals(ix(j)).angle);
								obj.sVals(ix(j)).xy = ts.xy;
								obj.sVals(ix(j)).dxdy = ts.dxdy;
						end
					end
				end
				for j=1:length(ix)
					if (obj.sVals(ix(j)).speed) > 0 && ~isempty(obj.sVals(ix(j)).startPosition) && (obj.sVals(ix(j)).startPosition ~= 0)
						[dx dy]=pol2cart(baseStimulus.d2r(obj.sVals(ix(j)).angle),obj.sVals(ix(j)).startPosition);
						switch obj.sVals(ix(j)).family
							case {'grating','bar'}
								obj.sVals(ix(j)).mvRect=OffsetRect(obj.sVals(ix(j)).dstRect,dx*obj.ppd,dy*obj.ppd);
							case {'spot'}
								obj.sVals(ix(j)).xT=obj.sVals(ix(j)).xPosition + round((dx * obj.ppd));
								obj.sVals(ix(j)).yT=obj.sVals(ix(j)).yPosition + round((dy * obj.ppd));
						end
					end
				end
			end
		end
		
		%---------------Reset variables like phase--------------------------%
		function resetVars(obj)
			for i=1:obj.sList.n
				ts = obj.stimulus.(obj.sList.list(i))(obj.sList.index(i));
				switch obj.sList.list(i)
					case 'g'
						obj.sVals(i).phase=ts.phase;
					case 'b'
						
				end
			end
		end
		
		%---------------Update the stimulus values for the current trial and increments the switchTime timer---------%
		function updateTask(obj)
			obj.task.timeNow = GetSecs;
			if obj.task.tick==1 %first ever loop
				obj.task.isBlank=0;
				obj.task.startTime=obj.task.timeNow;
				obj.task.switchTime=obj.task.trialTime; %first ever time is for the first trial
				obj.task.switchTick=obj.task.trialTime*ceil(obj.screenVals.fps);
			end
			
			%-------------------------------------------------------------------
			if  (obj.task.timeNow <= (obj.task.startTime+obj.task.switchTime)) || obj.task.tick <= obj.task.switchTick %we haven't hit a time trigger yet
				obj.task.switched = 0;
				if obj.task.isBlank == 0 %not in an interstimulus time, need to update drift, motion and pulsation
					
					for i=1:length(obj.task.stimIsDrifting) %only update those stimuli which are drifting
						ix=obj.task.stimIsDrifting(i);
						obj.sVals(ix).phase=obj.sVals(ix).phase+obj.sVals(ix).phaseincrement;
					end
					
					for i=1:length(obj.task.stimIsMoving) %only update those stimuli which are moving
						ix=obj.task.stimIsMoving(i);
						switch obj.sVals(ix).family
							case {'grating','bar','dots'}
								obj.sVals(ix).mvRect=OffsetRect(obj.sVals(ix).mvRect,obj.sVals(ix).dX,obj.sVals(ix).dY);
							case {'spot'}
								obj.sVals(ix).xT = obj.sVals(ix).xT + obj.sVals(ix).dX;
								obj.sVals(ix).yT = obj.sVals(ix).yT + obj.sVals(ix).dY;
						end
					end
					
					for i=1:length(obj.task.stimIsDots) %only update those stimuli which are moving
						ix=obj.task.stimIsDots(i);
						t=obj.stimulus.(obj.sList.list(ix))(obj.sList.index(ix));
						t.updateDots;
						obj.sVals(ix).xy=t.xy;
					end
					
					for i=1:length(obj.task.stimIsFlashing)
						%ix=obj.task.stimIsFlashing(i);
					end
					
				else %blank stimulus, we don't need to update anything
					
				end
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
					
					%now update our stimuli, we do it in the blank as less
					%critical timingwise
					for i=1:length(obj.task.stimIsMoving) %reset the motion rect back to the default
						ix=obj.task.stimIsMoving(i);
						switch obj.sVals(ix).family
							case {'grating','bar','dots'}
								obj.sVals(ix).mvRect = obj.sVals(ix).dstRect;
							case {'spot'}
								obj.sVals(ix).xT = obj.sVals(ix).xPosition;
								obj.sVals(ix).yT = obj.sVals(ix).yPosition;
						end
					end
					
					if ~mod(obj.task.thisRun,obj.task.minTrials) %are we rolling over into a new trial?
						mT=obj.task.thisTrial+1;
						mR = 1;
					else
						mT=obj.task.thisTrial;
						mR = obj.task.thisRun + 1;
					end
					
					obj.resetVars;
					obj.updateVars(mT,mR);
					obj.lJack.prepareStrobe(0); %get the strobe word ready
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
		
		%---------------Calculates the screen values----------------%
		function prepareScreen(obj)
			
			obj.ppd=round(obj.pixelsPerCm*(57.3/obj.distance)); %set the pixels per degree
			obj.maxScreen=max(Screen('Screens'));
			
			if isempty(obj.screen) || obj.screen > obj.maxScreen
				obj.screen = obj.maxScreen;
			end
			
			%get the gammatable and dac information
			[obj.screenVals.gammaTable,obj.screenVals.dacBits,obj.screenVals.lutSize]=Screen('ReadNormalizedGammaTable', obj.screen);
			
			%get screen dimensions
			rect=Screen('Rect',obj.screen);
			obj.screenVals.width=rect(3);
			obj.screenVals.height=rect(4);
			
			obj.screenVals.fps=Screen('FrameRate',obj.screen);
			
			%initialise 10,000 timeLog values
			obj.timeLog.vbl=zeros(10000,1);
			obj.timeLog.show=zeros(10000,1);
			obj.timeLog.flip=zeros(10000,1);
			obj.timeLog.miss=zeros(10000,1);
			
			%make sure we load up and test the serial port
			obj.serialP=sendSerial(struct('name',obj.serialPortName,'openNow',1));
			obj.serialP.toggleDTRLine;
			obj.serialP.close;
			
			obj.lJack = labJack(struct('name','labJack','openNow',1,'verbosity',1));
			obj.lJack.prepareStrobe([0,255,255],[0,255,255],1);
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
			
			obj.photoDiodeRect(:,1)=[20 20 70 70]';
			
			obj.updatesList;
			
		end
		
		% ===================================================================
		%> @brief Configure grating specific variables
		%>
		%> @param i
		%> @return 
		% ===================================================================
		%--------------------Configure grating specific variables-----------%
		function setupGrating(obj,i)
			ts = obj.stimulus.(obj.sList.list(i))(obj.sList.index(i));
			
			out = ts.setup(obj); %get the object to set itself up
			
			fn = fieldnames(out);
			for j=1:length(fn)
				obj.sVals(i).(fn{j}) = out.(fn{j});
			end
			
			if obj.sVals(i).tf>0 %we need to say this needs animating
				obj.sVals(i).doDrift=1;
				obj.task.stimIsDrifting=[obj.task.stimIsDrifting i];
			else
				obj.sVals(i).doDrift=0;
			end
			
			if obj.sVals(i).speed>0 %we need to say this needs animating
				obj.sVals(i).doMotion=1;
 				obj.task.stimIsMoving=[obj.task.stimIsMoving i];
			else
				obj.sVals(i).doMotion=0;
			end

		end
		
		% ===================================================================
		%> @brief Configure bar specific variables
		%>
		%> @param i
		%> @return 
		% ===================================================================
		function setupBar(obj,i)
			ts=obj.stimulus.(obj.sList.list(i))(obj.sList.index(i));
			
			out = ts.setup(obj); %get the object to set itself up
			
			fn = fieldnames(out);
			for j=1:length(fn)
				obj.sVals(i).(fn{j}) = out.(fn{j});
			end
			
			if obj.sVals(i).speed>0 %we need to say this needs animating
				obj.sVals(i).doMotion=1;
 				obj.task.stimIsMoving=[obj.task.stimIsMoving i];
			else
				obj.sVals(i).doMotion=0;
			end
		end
		
		% ===================================================================
		%> @brief Configure dots specific variables
		%>
		%> @param i
		%> @return 
		% ===================================================================
		function setupDots(obj,i)
			ts=obj.stimulus.(obj.sList.list(i))(obj.sList.index(i));
			
			out = ts.setup(obj); %get the object to set itself up
			
			fn = fieldnames(out);
			for j=1:length(fn)
				obj.sVals(i).(fn{j}) = out.(fn{j});
			end
			
			if obj.sVals(i).speed>0 %we need to say this needs animating
				obj.sVals(i).doDots=1;
 				obj.task.stimIsDots=[obj.task.stimIsDots i];
			else
				obj.sVals(i).doDots=0;
			end
		end
		
		% ===================================================================
		%> @brief Configure spot specific variables
		%>
		%> @param i
		%> @return 
		% ===================================================================
		function setupSpot(obj,i)
			
			ts=obj.stimulus.(obj.sList.list(i))(obj.sList.index(i));
			
			out = ts.setup(obj); %get the object to set itself up
			
			fn = fieldnames(out);
			for j=1:length(fn)
				obj.sVals(i).(fn{j}) = out.(fn{j});
			end
			
			if obj.sVals(i).speed>0 %we need to say this needs animating
				obj.sVals(i).doMotion=1;
 				obj.task.stimIsMoving=[obj.task.stimIsMoving i];
			else
				obj.sVals(i).doMotion=0;
			end
			
			if strcmp(obj.sVals(i).type,'flash')
				
			end
			
		end
		
		% ===================================================================
		%> @brief Configure grating specific variables
		%>
		%> @param i
		%> @return 
		% ===================================================================
		function drawGrating(obj,i)
			if obj.sVals(i).gabor==0
				Screen('DrawTexture', obj.win, obj.sVals(i).texture, [],obj.sVals(i).mvRect,...
					obj.sVals(i).angle, [], [], [], [],obj.sVals(i).rotateMode, [obj.sVals(i).phase,...
					obj.sVals(i).sf,obj.sVals(i).contrast, 0]);
			else
				Screen('DrawTexture', obj.win, obj.sVals(i).texture, [],...
					obj.sVals(i).mvRect, obj.sVals(i).angle, [], [], [], [], kPsychDontDoRotation,...
					[obj.sVals(i).phase, obj.sVals(i).sf, obj.sVals(i).spatialConstant, obj.sVals(i).contrast, obj.sVals(i).aspectRatio, 0, 0, 0]);
			end
		end
		
		% ===================================================================
		%> @brief Configure grating specific variables
		%>
		%> @param i
		%> @return 
		% ===================================================================
		function drawBar(obj,i)
			Screen('DrawTexture',obj.win,obj.sVals(i).texture,[],obj.sVals(i).mvRect,obj.sVals(i).angle);
		end
		
		% ===================================================================
		%> @brief Configure grating specific variables
		%>
		%> @param i
		%> @return 
		% ===================================================================
		function drawDots(obj,i)
			
			x = obj.xCenter+(obj.sVals(i).xPosition*obj.ppd);
			y = obj.yCenter+(obj.sVals(i).yPosition*obj.ppd);
			Screen('DrawDots',obj.win,obj.sVals(i).xy,obj.sVals(i).dotSize,obj.sVals(i).colours,...
				[x y],obj.sVals(i).dotType);
			
		end
		
		% ===================================================================
		%> @brief Configure grating specific variables
		%>
		%> @param i
		%> @return 
		% ===================================================================
		function drawSpot(obj,i)
			Screen('gluDisk',obj.win,obj.sVals(i).colour,obj.sVals(i).xT,obj.sVals(i).yT,obj.sVals(i).size);
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
			Screen('DrawDots',obj.win,obj.grid,2,[1 0 0 1],[obj.xCenter obj.yCenter]);
		end
		
		% ===================================================================
		%> @brief Configure grating specific variables
		%>
		%> @param i
		%> @return 
		% ===================================================================
		function infoText(obj)
			t=sprintf('T: %i | R: %i [%i] | isBlank: %i | Time: %3.3f',obj.task.thisTrial,...
			obj.task.thisRun,obj.task.totalRuns,obj.task.isBlank,(obj.timeLog.vbl(obj.task.tick)-obj.task.startTime)); 
			for i=1:obj.task.nVars
				t=[t sprintf('\n\n\t\t%s = %2.2f',obj.task.nVar(i).name,obj.task.outVars{obj.task.thisTrial,i}(obj.task.thisRun))];
			end
			Screen('DrawText',obj.win,t,50,1,[1 1 1 1],[0 0 1]);
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
		%> @brief Configure grating specific variables
		%>
		%> @param i
		%> @return 
		% ===================================================================
		function drawBackground(obj)
			Screen('FillRect',obj.win,obj.backgroundColour,[]);
		end
		
		% ===================================================================
		%> @brief Configure grating specific variables
		%>
		%> @param i
		%> @return 
		% ===================================================================
		function printLog(obj)
			vbl=obj.timeLog.vbl(obj.timeLog.vbl>0)*1000;
			show=obj.timeLog.show(obj.timeLog.show>0)*1000;
			flip=obj.timeLog.flip(obj.timeLog.flip>0)*1000;
			index=min([length(vbl) length(flip) length(show)]);
			vbl=vbl(1:index);
			show=show(1:index);
			flip=flip(1:index);
			miss=obj.timeLog.miss(1:index);
			stimTime=obj.timeLog.stimTime(1:index);
			
			figure
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
			
			figure
			hold on
			plot(show(2:index)-vbl(2:index),'r')
			plot(show(2:index)-flip(2:index),'g')
			plot(vbl(2:index)-flip(2:index),'b')
			plot(stimTime(2:index)*10,'k');
			title('VBL - Flip time in ms')
			legend('Show-VBL','Show-Flip','VBL-Flip')
			xlabel('Frame number');
			ylabel('Time (milliseconds)');
			
			figure
			hold on
			plot(miss,'r.-')
			plot(stimTime/50,'k');
			title('Missed frames')
			
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
			if obj.verbose==1
				if ~exist('tag','var')
					tag='#';
				end
				fprintf('%s -- T: %i | R: %i [%i] | B: %i | Tick: %i | Time: %5.5g\n',tag,obj.task.thisTrial,obj.task.thisRun,obj.task.totalRuns,obj.task.isBlank,obj.task.tick,obj.task.timeNow-obj.task.startTime);
			end
		end
		
	end
end