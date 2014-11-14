function afterimagetest()

useEyeLink = false;
useStaircase = false;
backgroundColour = [0.5 0.5 0.5];
subject = 'Ian';
fixx = 0;
fixy = 0;
pixelsPerCm = 44; %32=Lab CRT -- 44=27"monitor or Macbook Pro
nBlocks = 10; %number of repeated blocks?
windowed = [800 800];

if useStaircase; type = 'STAIR'; else type = 'MOC'; end %#ok<*UNRCH>
name = ['AI_' type '_' subject];
c = sprintf(' %i',fix(clock()));
c = regexprep(c,' ','_');
name = [name c];

p=uigetdir(pwd,'Select Directory to Save Data and Screenshot:');
cd(p);

ontime = 1.0;
runtime = ontime * 2;

%-----spot stimulus
a = spotStimulus();
a.name = name;
a.size = 4;
a.speed = 0;
a.colour = [1 1 1];
a.xPosition = 4;
a.yPosition = 0;
a.offTime = ontime;

%-----grey mask
p = barStimulus();
p.yPosition = 0;
p.size = 1;
p.barWidth = 1;
p.barLength = 1;
p.speed = 0;
p.startPosition = 0;
p.colour = backgroundColour + 0.3;
p.xPosition = -4;
p.yPosition = 0;
p.delayTime = ontime;

%-----combine them into a single meta stimulus
stimuli = metaStimulus();
stimuli.name = name;

stimuli{1} = a;
stimuli{2} = p;

%-----Setup task
task						= stimulusSequence();
task.name				= name;
task.nBlocks			= 10;

task.nVar(1).name		= 'colourOut';
task.nVar(1).stimuli = 1;
task.nVar(1).values	= {[0 0 0],[.25 .25 .25],[.75 .75 .75],[1 1 1]};

task.nVar(2).name		= 'delayTimeOut';
task.nVar(2).stimuli = 2;
task.nVar(2).values	= {1, 1.01, 1.02, 1.03, 1.04, 1.2};

randomiseStimuli(task);
initialiseTask(task);

try %our main experimental try catch loop
	
	%-----open the PTB screens
	s = screenManager('verbose',false,'blend',true,'screen',0,'pixelsPerCm',pixelsPerCm,...
		'bitDepth','8bit','debug',true,'antiAlias',0,'nativeBeamPosition',0, ...
		'srcMode','GL_SRC_ALPHA','dstMode','GL_ONE_MINUS_SRC_ALPHA',...
		'windowed',windowed,'backgroundColour',[backgroundColour 0]); %use a temporary screenManager object
	screenVals = open(s); %open PTB screen
	setup(stimuli,s); %setup our stimulus object
	
	vbl = Screen('Flip',s.win);
	
	breakloop = false;
	loop = 1;
	response = [];
	
	while ~breakloop
		
		var1 = task.outValues{task.totalRuns,1};
		if iscell(var1); var1 = var1{1}; end
		var2 = task.outValues{task.totalRuns,2};
		if iscell(var2); var2 = var2{1}; end
		
		stimuli{1}.(task.nVar(1).name) = var1;
		stimuli{2}.(task.nVar(2).name) = var2;
		update(stimuli);
		t=sprintf('TRIAL: %i / %i | Disp: %g %g',task.totalRuns,task.nRuns,var1,var2);
		disp(t);
		
		fixated = '';
		
		drawSpot(s,0.2,[1 1 0],fixx,fixy);
		Screen('Flip',s.win); %flip the buffer
		WaitSecs(0.5);
		fixated = 'fix';
		
		%------Our main stimulus drawing loop
		if strcmpi(fixated,'fix') %initial fixation held
			draw(stimuli); %draw stimulus
			drawSpot(s,0.2,[1 1 0],fixx,fixy);
			vbls = Screen('Flip',s.win); %flip the buffer
			vbl=vbls;
			while GetSecs <= vbls+runtime
				draw(stimuli); %draw stimulus
				drawSpot(s,0.2,[1 1 0],fixx,fixy);
				Screen('DrawingFinished', s.win); %tell PTB/GPU to draw
				animate(stimuli); %animate stimulus, will be seen on next draw
				nextvbl = vbl + screenVals.halfisi;
				vbl = Screen('Flip',s.win, nextvbl); %flip the buffer
			end
			
			Screen('Drawtext', s.win, t, 10, 10);
			vbl = Screen('Flip',s.win);
			
			%-----get our response
			response = false;
			responseval = '';
			
			%-----check keyboard
			timeout = GetSecs+4;
			breakloopkey = false;
			quitkey = false;
			while ~breakloopkey
				[keyIsDown, ~, keyCode] = KbCheck(-1);
				if keyIsDown == 1
					rchar = KbName(keyCode);
					if iscell(rchar);rchar=rchar{1};end
					switch rchar
						case {'LeftArrow','left'}
							responseval = 'left';
							response = true;
							breakloopkey = true;
						case {'RightArrow','right'}
							responseval = 'right';
							response = true;
							breakloopkey = true;
						case {'q'}
							fprintf('\nQUIT!\n');
							quitkey = true;
							breakloop = true;
							breakloopkey = true;
						otherwise
							
					end
				end
				if timeout<=GetSecs; breakloopkey = true; end
			end
			
			if response
				task.response{task.totalRuns,1} = [var1, var2];
				task.response{task.totalRuns,2} = responseval;
				task.totalRuns = task.totalRuns + 1;
				t=sprintf('RESPONSE (%s) = %i', responseval, response);
				Screen('Drawtext', s.win, t,10,10);
				disp(t);
			else
				t=sprintf('RESPONSE EMPTY');
				Screen('Drawtext', s.win, t,10,10);
				disp(t);
			end
			
			if task.totalRuns > task.nRuns
				fprintf('\nTask finished!\n', response);
				breakloop = true;
			end
		end
	end
	Screen('Flip',s.win); %flip the buffer
	WaitSecs(0.5);

	%-----Cleanup
	Screen('Flip',s.win);
	Priority(0); ListenChar(0); ShowCursor;
	close(s); %close screen

	clear stimuli task eL s


catch ME
	ple(ME)
	Priority(0); ListenChar(0); ShowCursor;
	reset(stimuli);
	close(s); %close screen
	clear stimuli task eL s
	rethrow(ME);
end
end

