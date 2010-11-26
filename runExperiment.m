classdef runExperiment < dynamicprops
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
		srcMode = 'GL_SRC_ALPHA' %GL_ONE %src mode
		dstMode = 'GL_ONE_MINUS_SRC_ALPHA' %GL_ONE % dst mode
		fixationPoint = 1 %show a fixation spot?
		photoDiode = 1 %show a white square to trigger a photodiode attached to screen
		serialPortName = 'dummy' %name of serial port to send TTL out on, if set to 'dummy' then ignore
		useLabJack = 0
	end
	
	properties (SetAccess = private, GetAccess = public)
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
		lJack %LabJack object
		xCenter %computed X center
		yCenter %computed Y center
		win %the handle returned by opening a PTB window
		winRect %the window rectangle
		photoDiodeRect %the photoDiode rectangle
	end
	
	methods
		%-------------------CONSTRUCTOR----------------------%
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
	
		%-------------------------Main Grating----------------------------%
		function run(obj)
			
			%initialise timeLog for this run
			obj.timeLog.date=clock;
			obj.timeLog.startrun=GetSecs;
			obj.timeLog.vbl=zeros(100000,1);
			obj.timeLog.show=zeros(100000,1);
			obj.timeLog.flip=zeros(100000,1);
			obj.timeLog.miss=zeros(100000,1);
			obj.timeLog.stimTime=zeros(100000,1);
			
			%HideCursor; %hide mouse
			
			if obj.hideFlash==1 && obj.windowed==0
				obj.screenVals.oldGamma = Screen('LoadNormalizedGammaTable', obj.screen, repmat(obj.screenVals.gammaTable(128,:), 256, 1));
			end
			
			obj.serialP=sendSerial(struct('name',obj.serialPortName,'openNow',1,'verbosity',obj.verbose));
			obj.serialP.setDTR(0);
			
			if obj.useLabJack == 1
				strct = struct('openNow',1,'name','default','verbosity',obj.verbose);
			else
				strct = struct('openNow',0,'name','null','verbosity',0,'silentMode',1);
			end
			obj.lJack = labJack(strct);
			obj.lJack.strobeWord([255,255,255],[255,255,255]);
			
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
				if obj.windowed==1
					[obj.win, obj.winRect] = PsychImaging('OpenWindow', obj.screen, obj.backgroundColour,[1 1 801 601], [], obj.doubleBuffer+1,[],obj.antiAlias);
				else
					[obj.win, obj.winRect] = PsychImaging('OpenWindow', obj.screen, obj.backgroundColour,[], [], obj.doubleBuffer+1,[],obj.antiAlias);
				end
				
				obj.timeLog.postOpenWindow=GetSecs;
				obj.timeLog.deltaOpenWindow=(obj.timeLog.postOpenWindow-obj.timeLog.preOpenWindow)*1000;
				
				Priority(9); %(MaxPriority(obj.win)); %bump our priority to maximum allowed
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
				Priority(9);
				
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
					if any(buttons) % break out of loop
						break;
					end;
					
					obj.updateTask;
					
					%======= Show it at next retrace: ========%
					[obj.timeLog.vbl(obj.task.tick+1),obj.timeLog.show(obj.task.tick+1),obj.timeLog.flip(obj.task.tick+1),obj.timeLog.miss(obj.task.tick+1)] = Screen('Flip', obj.win, (obj.timeLog.vbl(obj.task.tick)+obj.screenVals.halfisi));
					%=========================================%
					
					if obj.task.switched == 1
						switch obj.task.isBlank
							case 1
								obj.serialP.setDTR(0);
								obj.lJack.strobeWord([255,255,255],[255,255,255]);
								%obj.lJack.setFIO4(0);
							case 0
								obj.lJack.strobeWord([224,255,255],[255,255,255]);
								obj.serialP.setDTR(1);
								%obj.lJack.setFIO4(1);
						end
					end
					
					if obj.task.tick==1
						obj.timeLog.startflip=obj.timeLog.vbl(obj.task.tick) + obj.screenVals.halfisi;
						obj.timeLog.start=obj.timeLog.show(obj.task.tick+1);
						obj.lJack.strobeWord([240,255,255],[255,255,255]);
						obj.serialP.setDTR(1);
						%obj.lJack.setFIO4(1);
					end
					
					if obj.task.isBlank==0
						obj.timeLog.stimTime(obj.task.tick+1)=1+obj.task.switched;
					else
						obj.timeLog.stimTime(obj.task.tick+1)=0-obj.task.switched;
					end
					
					obj.task.tick=obj.task.tick+1;
					
				end
				
				%---------------------------------------------Finished
				
				Screen('Flip', obj.win);
				obj.timeLog.afterDisplay=GetSecs;
				obj.serialP.setDTR(0);
				obj.lJack.setFIO4(0);
				
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
				
				if obj.hideFlash == 1 || obj.windowed == 1
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
		
		
% 		function set.verbose(obj,value)
% 			for i = 1:obj.sList.n
% 				ts = obj.stimulus.(obj.sList.list(i));
	% 			end
% 		end


	end
	
	%-------------------------END PUBLIC METHODS--------------------------------%
	
	methods ( Access = protected ) %----------PRIVATE METHODS-------------------%
		
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
			obj.task.startTime=0;
			
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
							case {'grating','bar', 'spot'}
								obj.sVals(ix(j)).dstRect=Screen('Rect',obj.sVals(ix(j)).texture);
								obj.sVals(ix(j)).dstRect=CenterRectOnPoint(obj.sVals(ix(j)).dstRect,obj.xCenter,obj.yCenter);
								obj.sVals(ix(j)).dstRect=OffsetRect(obj.sVals(ix(j)).dstRect,obj.sVals(ix(j)).xPosition*obj.ppd,obj.sVals(ix(j)).yPosition*obj.ppd);
								obj.sVals(ix(j)).mvRect=obj.sVals(ix(j)).dstRect;
							case {'dots'}
								
						end
						
					end
				elseif (strcmp(name,'angle')||strcmp(name,'moveAngle'))
					for j=1:length(ix)
						ts = obj.stimulus.(obj.sList.list(ix(j)))(obj.sList.index(ix(j)));
						switch obj.sVals(ix(j)).family
							case {'grating','bar', 'spot'}
								[obj.sVals(ix(j)).dX obj.sVals(ix(j)).dY]=obj.updatePosition(obj.sVals(ix(j)).delta,obj.sVals(ix(j)).angle);
							case {'dots'}
								ts.updateDots(obj.sVals(ix(j)).coherence,obj.sVals(ix(j)).angle);
								obj.sVals(ix(j)).xy = ts.xy;
								obj.sVals(ix(j)).dxdy = ts.dxdy;
						end
					end
				elseif strcmp(name,'coherence')
					for j=1:length(ix)
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
						[dx dy]=pol2cart(obj.d2r(obj.sVals(ix(j)).angle),obj.sVals(ix(j)).startPosition);
						obj.sVals(ix(j)).mvRect=OffsetRect(obj.sVals(ix(j)).dstRect,dx*obj.ppd,dy*obj.ppd);
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
			end
			
			if  obj.task.timeNow <= (obj.task.startTime+obj.task.switchTime) %we haven't hit a time trigger yet
				obj.task.switched = 0;
				if obj.task.isBlank == 0 %not in an interstimulus time, need to update drift, motion and pulsation
					
					for i=1:length(obj.task.stimIsDrifting) %only update those stimuli which are drifting
						ix=obj.task.stimIsDrifting(i);
						obj.sVals(ix).phase=obj.sVals(ix).phase+obj.sVals(ix).phaseincrement;
					end
					
					for i=1:length(obj.task.stimIsMoving) %only update those stimuli which are moving
						ix=obj.task.stimIsMoving(i);
						obj.sVals(ix).mvRect=OffsetRect(obj.sVals(ix).mvRect,obj.sVals(ix).dX,obj.sVals(ix).dY);
					end
					
					for i=1:length(obj.task.stimIsDots) %only update those stimuli which are moving
						ix=obj.task.stimIsDots(i);
						t=obj.stimulus.(obj.sList.list(ix))(obj.sList.index(ix));
						t.updateDots;
						obj.sVals(ix).xy=t.xy;
					end
					
					for i=1:length(obj.task.stimIsFlashing)
						ix=obj.task.stimIsFlashing(i);
					end
					
				else %blank stimulus, we don't need to update anything
					
				end
				
			else %need to switch to next trial or blank
				obj.task.switched = 1;
				if obj.task.isBlank == 0 %we come from showing a stimulus
					
					%obj.logMe('IntoBlank');
					obj.task.isBlank = 1;
					
					if ~mod(obj.task.thisRun,obj.task.minTrials) %are we within a trial block or not? we add the required time to our switch timer
						obj.task.switchTime=obj.task.switchTime+obj.task.itTime;
					else
						obj.task.switchTime=obj.task.switchTime+obj.task.isTime;
					end
					
					%now update our stimuli, we do it in the blank as less
					%critical timingwise
					for i=1:length(obj.task.stimIsMoving) %reset the motion rect back to the default
						ix=obj.task.stimIsMoving(i);
						obj.sVals(ix).mvRect=obj.sVals(ix).dstRect;
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
					%obj.logMe('OutaBlank');
					
				else %we have to show the new run on the next flip
					
					%obj.logMe('IntoTrial');
					obj.task.switchTime=obj.task.switchTime+obj.task.trialTime; %update our timer
					obj.task.isBlank = 0;
					if ~mod(obj.task.thisRun,obj.task.minTrials) %are we rolling over into a new trial?
						obj.task.thisTrial=obj.task.thisTrial+1;
						obj.task.thisRun = 1;
					else
						obj.task.thisRun = obj.task.thisRun + 1;
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
			obj.lJack.setFIO4(1);
			obj.lJack.setFIO4(0);
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
			for i=1:8
				a(i)=GetSecs;
			end
			obj.timeLog.deltaGetSecs=mean(diff(a))*1000; %what overhead does GetSecs have in milliseconds?
			WaitSecs(0.01); %preload function
			
			Screen('Preference', 'TextRenderer', 0); %fast text renderer
			
			obj.makeGrid;
			
			obj.photoDiodeRect(:,1)=[0 0 50 50]';
			
			obj.updatesList;
			
		end
		
		%--------------------Configure grating specific variables-----------%
		function setupGrating(obj,i)
			ts = obj.stimulus.(obj.sList.list(i))(obj.sList.index(i));
			
			obj.sVals(i).doDots = [];
			obj.sVals(i).doMation = [];
			obj.sVals(i).doDrift = [];
			obj.sVals(i).family = ts.family;
			
			if ts.rotationMethod==1
				obj.sVals(i).rotateMode = kPsychUseTextureMatrixForRotation;
			else
				obj.sVals(i).rotateMode = [];
			end
			
			obj.sVals(i).gabor=ts.gabor;
			if obj.sVals(i).gabor==0
				obj.sVals(i).scaledown=1;
				obj.sVals(i).scaleup=1;
			else
				obj.sVals(i).scaledown=1; %scaling gabors does weird things!!!
				obj.sVals(i).scaleup=1;
			end
			obj.sVals(i).gratingSize = round(obj.ppd*ts.size);
			obj.sVals(i).sf = (ts.sf/obj.ppd)*obj.sVals(i).scaledown;
			obj.sVals(i).tf = ts.tf;
			obj.sVals(i).contrast = ts.contrast;
			if ts.gabor
				obj.sVals(i).contrast = obj.sVals(i).contrast*100;
			end
			obj.sVals(i).angle = ts.angle;
			obj.sVals(i).phase = ts.phase;
			obj.sVals(i).colour = ts.colour;
			obj.sVals(i).alpha = ts.alpha;
			obj.sVals(i).xPosition = ts.xPosition;
			obj.sVals(i).yPosition = ts.yPosition;
			obj.sVals(i).speed = ts.speed;
			obj.sVals(i).spatialConstant = ts.spatialConstant*obj.ppd;
			obj.sVals(i).startPosition=ts.startPosition;
			obj.sVals(i).contrastMult = ts.contrastMult;
			obj.sVals(i).disableNorm = ts.disableNorm;
			obj.sVals(i).aspectRatio = ts.aspectRatio;
			obj.sVals(i).phaseincrement = (obj.sVals(i).tf * 360) * obj.screenVals.ifi;
			obj.sVals(i).delta = (ts.speed*obj.ppd) * obj.screenVals.ifi;
			[obj.sVals(i).dX obj.sVals(i).dY] = obj.updatePosition(obj.sVals(i).delta,obj.sVals(i).angle);
			
			if ts.driftDirection < 1
				obj.sVals(i).phaseincrement = -obj.sVals(i).phaseincrement;
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

			obj.sVals(i).res = [obj.sVals(i).gratingSize obj.sVals(i).gratingSize]*obj.sVals(i).scaleup;
			
			if ts.mask>0
				obj.sVals(i).mask = (floor((obj.ppd*ts.size)/2)*obj.sVals(i).scaleup);
			else
				obj.sVals(i).mask = [];
			end
			
			if length(obj.sVals(i).colour) == 3
				obj.sVals(i).colour = [obj.sVals(i).colour obj.sVals(i).alpha];
			end
			
			if ts.gabor==0
				obj.sVals(i).texture = CreateProceduralSineGrating(obj.win, obj.sVals(i).res(1),...
					obj.sVals(i).res(2), obj.sVals(i).colour, obj.sVals(i).mask);
			else
				if obj.sVals(i).aspectRatio == 1
					nonSymmetric = 0;
				else
					nonSymmetric = 1;
				end
				obj.sVals(i).texture = CreateProceduralGabor(obj.win, obj.sVals(i).res(1),...
					obj.sVals(i).res(2), nonSymmetric, obj.sVals(i).colour,obj.sVals(i).disableNorm,...
					obj.sVals(i).contrastMult);
			end
			
			obj.sVals(i).dstRect=Screen('Rect',obj.sVals(i).texture);
			obj.sVals(i).dstRect=ScaleRect(obj.sVals(i).dstRect,obj.sVals(i).scaledown,obj.sVals(i).scaledown);
			obj.sVals(i).dstRect=CenterRectOnPoint(obj.sVals(i).dstRect,obj.xCenter,obj.yCenter);
			obj.sVals(i).dstRect=OffsetRect(obj.sVals(i).dstRect,(obj.sVals(i).xPosition)*obj.ppd,(obj.sVals(i).yPosition)*obj.ppd);
			obj.sVals(i).mvRect=obj.sVals(i).dstRect;
		end
		
		%--------------------Configure grating specific variables-----------%
		function setupBar(obj,i)
			ts=obj.stimulus.(obj.sList.list(i))(obj.sList.index(i));
			
			obj.sVals(i).doDots = [];
			obj.sVals(i).doMation = [];
			obj.sVals(i).doDrift = [];
			obj.sVals(i).family = ts.family;

			obj.sVals(i).barWidth=ts.barWidth;
			obj.sVals(i).barLength=ts.barLength;
			obj.sVals(i).angle = ts.angle;
			obj.sVals(i).speed = ts.speed;
			obj.sVals(i).delta = (ts.speed*obj.ppd) * obj.screenVals.ifi;
			obj.sVals(i).type = ts.type;
			obj.sVals(i).startPosition = ts.startPosition;
			
			obj.sVals(i).colour = ts.colour;
			obj.sVals(i).alpha = ts.alpha;
			obj.sVals(i).xPosition = ts.xPosition;
			obj.sVals(i).yPosition = ts.yPosition;
			
			ts.constructMatrix(obj.ppd) %make our matrix
			obj.sVals(i).matrix=ts.matrix;
			obj.sVals(i).texture=Screen('MakeTexture',obj.win,obj.sVals(i).matrix,1,[],2);
			
			[obj.sVals(i).dX obj.sVals(i).dY] = obj.updatePosition(obj.sVals(i).delta,obj.sVals(i).angle);
			
			if obj.sVals(i).speed>0 %we need to say this needs animating
				obj.sVals(i).doMotion=1;
 				obj.task.stimIsMoving=[obj.task.stimIsMoving i];
			else
				obj.sVals(i).doMotion=0;
			end
			
			if length(obj.sVals(i).colour) == 3
				obj.sVals(i).colour = [obj.sVals(i).colour obj.sVals(i).alpha];
			end
			
			obj.sVals(i).dstRect=Screen('Rect',obj.sVals(i).texture);
			obj.sVals(i).dstRect=CenterRectOnPoint(obj.sVals(i).dstRect,obj.xCenter,obj.yCenter);
			obj.sVals(i).dstRect=OffsetRect(obj.sVals(i).dstRect,(obj.sVals(i).xPosition)*obj.ppd,(obj.sVals(i).yPosition)*obj.ppd);
			obj.sVals(i).mvRect=obj.sVals(i).dstRect;
		end
		
		%-------------------Setup dots-------------------%
		function setupDots(obj,i)
			ts=obj.stimulus.(obj.sList.list(i))(obj.sList.index(i));
			
			obj.sVals(i).doDots = [];
			obj.sVals(i).doMation = [];
			obj.sVals(i).doDrift = [];
			obj.sVals(i).family = ts.family;
			
			obj.sVals(i).nDots = ts.nDots;
			obj.sVals(i).angle = ts.angle;
			obj.sVals(i).speed = ts.speed;
			obj.sVals(i).size = ts.size*obj.ppd;
			obj.sVals(i).delta = obj.sVals(i).speed * obj.ppd * obj.screenVals.ifi;
			obj.sVals(i).alpha = ts.alpha;
			obj.sVals(i).dotType = ts.dotType;
			obj.sVals(i).dotSize = ts.dotSize*obj.ppd;
			obj.sVals(i).coherence = ts.coherence;
			obj.sVals(i).colour = ts.colour;
			obj.sVals(i).xPosition = ts.xPosition;
			obj.sVals(i).yPosition = ts.yPosition;
			obj.sVals(i).startPosition=0;
			obj.sVals(i).colourType = ts.colourType;
			
			if obj.sVals(i).speed>0 %we need to say this needs animating
				obj.sVals(i).doDots=1;
 				obj.task.stimIsDots=[obj.task.stimIsDots i];
			else
				obj.sVals(i).doDots=0;
			end
			
			if length(obj.sVals(i).colour) == 3
				obj.sVals(i).colour = [obj.sVals(i).colour obj.sVals(i).alpha];
			end
			
			in.ppd = obj.ppd;
			in.ifi = obj.screenVals.ifi;
			ts.initialiseDots(in);
			
			obj.sVals(i).xy=ts.xy;
			obj.sVals(i).dxdy=ts.dxdy;
			obj.sVals(i).colours=ts.colours;
		end
		
		%-------------------Setup dots-------------------%
		function setupSpot(obj,i)
			
			obj.sVals(i).doDots = [];
			
			ts=obj.stimulus.(obj.sList.list(i))(obj.sList.index(i));
			obj.sVals(i).angle = ts.angle;
			obj.sVals(i).speed = ts.speed;
			obj.sVals(i).size = ts.size*obj.ppd;
			obj.sVals(i).delta = obj.sVals(i).speed * obj.ppd * obj.screenVals.ifi;
			obj.sVals(i).alpha = ts.alpha;
			obj.sVals(i).colour = ts.colour;
			obj.sVals(i).xPosition = obj.xCenter+(ts.xPosition*obj.ppd);
			obj.sVals(i).yPosition = obj.xCenter+(ts.yPosition*obj.ppd);
			
			if obj.sVals(i).speed>0 %we need to say this needs animating
				obj.sVals(i).doMotion=1;
 				obj.task.stimIsMoving=[obj.task.stimIsMoving i];
			else
				obj.sVals(i).doMotion=0;
			end
			
		end
		
		%-------------------Draw the grating-------------------%
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
		
		%-------------------Draw the bar-------------------%
		function drawBar(obj,i)
			Screen('DrawTexture',obj.win,obj.sVals(i).texture,[],obj.sVals(i).mvRect,obj.sVals(i).angle);
		end
		
		%-------------------Draw the dots-------------------%
		function drawDots(obj,i)
			
			x = obj.xCenter+(obj.sVals(i).xPosition*obj.ppd);
			y = obj.yCenter+(obj.sVals(i).yPosition*obj.ppd);
			Screen('DrawDots',obj.win,obj.sVals(i).xy,obj.sVals(i).dotSize,obj.sVals(i).colours,...
				[x y],obj.sVals(i).dotType);
			
		end
		
		function drawSpot(obj,i)
			Screen('gluDisk',obj.win,obj.sVals(i).colour,obj.sVals(i).xPosition,obj.sVals(i).yPosition,obj.sVals(i).size);
		end
		
		%--------------------Draw Fixation spot-------------%
		function drawFixationPoint(obj)
			Screen('gluDisk',obj.win,[1 0 1 1],obj.xCenter,obj.yCenter,3);
		end
		
		%------------------------------------------------------------
		function drawGrid(obj)
			Screen('DrawDots',obj.win,obj.grid,2,[1 0 0 1],[obj.xCenter obj.yCenter]);
		end
		
		%--------------------Draw Info text-------------------%
		function infoText(obj)
			t=sprintf('T: %i | R: %i | isBlank: %i | Time: %3.3f',obj.task.thisTrial,...
			obj.task.thisRun,obj.task.isBlank,(obj.timeLog.vbl(obj.task.tick)-obj.task.startTime)); 
			for i=1:obj.task.nVars
				t=[t sprintf('\n\n\t\t%s = %2.2f',obj.task.nVar(i).name,obj.task.outVars{obj.task.thisTrial,i}(obj.task.thisRun))];
			end
			Screen('DrawText',obj.win,t,50,0);
		end
		
		%--------------------Draw photodiode block-------------%
		function drawPhotoDiodeSquare(obj,colour)
			Screen('FillRect',obj.win,colour,obj.photoDiodeRect);
		end
		
		%--------------------Draw background-------------%
		function drawBackground(obj)
			Screen('FillRect',obj.win,obj.backgroundColour,[]);
		end
		
		%--------------------Print time log-------------------%
		function printLog(obj)
			obj.timeLog.vbl=obj.timeLog.vbl(obj.timeLog.vbl>0)*1000;
			obj.timeLog.show=obj.timeLog.show(obj.timeLog.show>0)*1000;
			obj.timeLog.flip=obj.timeLog.flip(obj.timeLog.flip>0)*1000;
			index=min([length(obj.timeLog.vbl) length(obj.timeLog.flip) length(obj.timeLog.show)]);
			obj.timeLog.vbl=obj.timeLog.vbl(1:index);
			obj.timeLog.show=obj.timeLog.show(1:index);
			obj.timeLog.flip=obj.timeLog.flip(1:index);
			obj.timeLog.miss=obj.timeLog.miss(1:index);
			obj.timeLog.stimTime=obj.timeLog.stimTime(1:index);
			
			figure
			plot(1:index-2,diff(obj.timeLog.vbl(2:end)),'ro:')
			hold on
			plot(1:index-2,diff(obj.timeLog.show(2:end)),'b--')
			plot(1:index-2,diff(obj.timeLog.flip(2:end)),'g-.')
			legend('VBL','Show','Flip')
			[m,e]=stderr(diff(obj.timeLog.vbl),'SE');
			t=sprintf('VBL mean=%2.2f+-%2.2f s.e.', m, e);
			[m,e]=stderr(diff(obj.timeLog.show),'SE');
			t=[t sprintf(' | Show mean=%2.2f+-%2.2f', m, e)];
			[m,e]=stderr(diff(obj.timeLog.flip),'SE');
			t=[t sprintf(' | Flip mean=%2.2f+-%2.2f', m, e)];
			title(t)
			xlabel('Frame number (difference between frames)');
			ylabel('Time (milliseconds)');
			hold off
			
			figure
			hold on
			plot(obj.timeLog.show(2:index)-obj.timeLog.vbl(2:index),'r')
			plot(obj.timeLog.show(2:index)-obj.timeLog.flip(2:index),'g')
			plot(obj.timeLog.vbl(2:index)-obj.timeLog.flip(2:index),'b')
			plot(obj.timeLog.stimTime(2:index)*10,'k');
			title('VBL - Flip time in ms')
			legend('Show-VBL','Show-Flip','VBL-Flip')
			xlabel('Frame number');
			ylabel('Time (milliseconds)');
			
			figure
			hold on
			plot(obj.timeLog.miss,'r.-')
			plot(obj.timeLog.stimTime/50,'k');
			title('Missed frames')
		end
		
		%-------------------blah blah blah-----------------------------------
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
		
		function r = d2r(obj,degrees)
			r=degrees*(pi/180);
			return
		end
		
		function degrees=r2d(obj,radians)
			degrees=radians*(180/pi);
		end
		
		function distance=findDistance(obj,x1,y1,x2,y2)
			dx = x2 - x1;
			dy = y2 - y1;
			distance=sqrt(dx^2 + dy^2);
		end
		
		function [dX dY] = updatePosition(obj,delta,angle)
			dX = delta * cos(obj.d2r(angle));
			dY = delta * sin(obj.d2r(angle));
		end
		
		function logMe(obj,tag)
			if obj.verbose==1
				if ~exist('tag','var')
					tag='#';
				end
				fprintf('%s -- T: %i | R: %i | B: %i | Tick: %i | Time: %5.5g\n',tag,obj.task.thisTrial,obj.task.thisRun,obj.task.isBlank,obj.task.tick,obj.task.timeNow-obj.task.startTime);
			end
		end
		
	end
end