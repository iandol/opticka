function revCor(s)

% get prefs if available
if ispref('revCor','stimSizes')
	try stimSizes	= getpref('revCor','stimSizes'); catch stimSizes = 10;end
	blockSize	= getpref('revCor','blockSize');
	nTrials		= getpref('revCor','nTrials');
	nSeconds	= getpref('revCor','nSeconds');
	nFrames		= getpref('revCor','nFrames');
	strobeValue = getpref('revCor','strobeValue');
	iti			= getpref('revCor','iti');
else
	stimSizes		= 10; % visual degrees
	blockSize		= 1; % the size of each block of the noise
	nTrials			= 10; %repeat times
	nSeconds		= 5;
	nFrames			= 2; %how many frames to show the same texture?
	strobeValue		= '1 255';
	iti				= 1; % intertrial interval
end

mtitle   = 'Opticka Reverse Correlation Module';
options  = { ['t|' num2str(stimSizes)],'Stimulus Sizes (deg):';...
	['t|' num2str(blockSize)],'Size of Pixel Blocks (deg):';...
	['t|' num2str(nTrials)],'Number of Trials:';...
	['t|' num2str(nSeconds)],'Number of Seconds (secs):';...
	['t|' num2str(nFrames)],'Number of Repeat Flips to show Frame:';...
	['t|' strobeValue],'Values to send on LabJack (ON/OFF):';...
	['t|' num2str(iti)],'Inter-trial Interval (secs):';...
	'r|¤Trinary|Binary','White Noise Type:';...
	'r|¤Off|On','Debug mode:';...
	'r|¤Nearest Neighbour|Bilinear','Texture Scaling:';...
	'r|¤8bit|16bit|32bit','Texture Resolution:';...
  };
sel = menuN(mtitle, options);
if ~iscell(sel);warning('User cancelled!');return;end
stimSizes		= sel{1}; % visual degrees
blockSize		= sel{2}; % the size of each block of the noise
nTrials			= sel{3}; %repeat times
nSeconds		= sel{4};
nFrames			= sel{5}; %how many frames to show the same texture?
strobeValue		= sel{6};
iti				= sel{7};
noiseType		= sel{8};
debug			= logical(sel{9}-1);
filterMode		= sel{10}-1;
floatPrecision	= sel{11}-1;


setpref('revCor','stimSizes',stimSizes);
setpref('revCor','blockSize',blockSize);
setpref('revCor','nTrials',nTrials);
setpref('revCor','nSeconds',nSeconds);
setpref('revCor','nFrames',nFrames);
setpref('revCor','strobeValue',num2str(strobeValue));
setpref('revCor','iti',iti);

if ~exist('s','var') || ~isa(s,'screenManager')
	s = screenManager('distance',57.3,'pixelsPerCm',32,'bitDepth','8bit');
end

if ~s.isOpen; open(s); end
sv = s.screenVals;

saveName = [s.paths.savedData filesep 'RevCor-' s.initialiseSaveFile '.mat'];

data.name = saveName;
data.date = datetime('now');
data.options = options;
data.sel = sel;
data.s = s;
data.computer = Screen('Computer');
data.version = Screen('Version');

lJ = labJackT;
if ~lJ.isOpen;open(lJ);end

drawPhotoDiodeSquare(s,[0 0 0]);
drawText(s,'Press ESCAPE key to start...');
flip(s);
KbWait;

try

	%====================================================
	% Next we actually show our textures
	for nTr=1:nTrials
		%====================================================
		% First we make our textures
		% a texture array is made for each stimulus size
		blockpx = blockSize * s.ppd;
		data.scale = blockpx;
		data.comment = 'scale is by how much the data.matrix is scaled to show in matlab';
		nStimuli = round(nSeconds*round(sv.fps/nFrames));
		data.nStimuli = nStimuli;
		texture = [];
		for nSt=1:length(stimSizes)
			pxLength = round(stimSizes(nSt) * (1/blockSize));
			mx = rand(pxLength,pxLength,nStimuli);
			if noiseType == 1
				mx(mx < (1/3)) = 0;
				mx(mx > 0 & mx < (2/3)) = 0.5;
				mx(mx > 0.5 ) = 1;
			else
				mx(mx < 0.5) = 0;
				mx(mx > 0) = 1;
			end
			% Screen('MakeTexture', WindowIndex, imageMatrix [, optimizeForDrawAngle=0] [, specialFlags=0]
			% [, floatprecision] [, textureOrientation=0] [, textureShader=0]);
			data.stimuli{nTr,nSt} = mx;
			for i = 1:nStimuli
				texture{nSt}(i) = Screen('MakeTexture', sv.win, mx(:,:,i), [], [], floatPrecision);
			end
		end
	
		% random select a size
		sizeOrder = randperm(length(stimSizes));
		data.sizeOrder{nTr} = sizeOrder;
		% for each size
		for nSt = sizeOrder
			thisSize = stimSizes(nSt);
			data.trials(nTr,nSt) = thisSize;
			if isempty(texture) || isempty(texture{nSt});error('Texture is empty!!!');end
			tx = texture{nSt};
			
			% here is our trial per-frame randomisation
			%thisOrder = randperm(length(tx));
			thisOrder = 1:length(tx);
			data.order{nTr,nSt} = thisOrder;

			% scale our texture via a rect
			rect = Screen('Rect',tx(1));
			rect = ScaleRect(rect,round(blockpx),round(blockpx));
			rect = CenterRectOnPointd(rect, sv.xCenter+(s.screenXOffset*s.ppd), sv.yCenter+(s.screenYOffset*s.ppd));
			
			% prepare our frame before stim ON
			drawPhotoDiodeSquare(s,[0 0 0]);
			lastvbl = flip(s); 
			a = 1;
			for i = thisOrder
				for j = 1:nFrames % repeat the same texture nFrames times
					% Screen('DrawTexture', windowPointer, texturePointer [,sourceRect] [,destinationRect]
					% [,rotationAngle] [, filterMode] [, globalAlpha] [, modulateColor] [, textureShader] [, specialFlags] [, auxParameters]);	
					Screen('DrawTexture', sv.win, tx(i), [], rect, [], filterMode);
					if debug;drawGrid(s);end
					drawPhotoDiodeSquare(s,[1 1 1]);
					vbl = flip(s, lastvbl + sv.halfisi); lastvbl = vbl;
					if a == 1 && j == 1; sendStrobe(lJ,strobeValue(1)); startT = vbl;end
					a = a + 1;
				end
			end
			drawPhotoDiodeSquare(s,[0 0 0]);
			vbl = flip(s, vbl + sv.halfisi);
			sendStrobe(lJ,strobeValue(2));
			data.times.trialLength(nTr,nSt) = vbl-startT;
			fprintf('--->>>Stimulus presentation took: %s secs\n', vbl-startT);
		end

		WaitSecs(iti);

		% lets clean up this trials textures
		for nSt = 1:length(stimSizes)
			tx = texture{nSt};
			for i = 1:length(tx)
				try Screen('Close', tx(i)); end %#ok<*TRYNC> 
			end
			texture = [];
		end
	end
	drawPhotoDiodeSquare(s,[0 0 0]);
	drawTextNow(s,'Finished!');
	WaitSecs(1);
	close(s);
	close(lJ);
catch ME
	try close(s); end
	try close(lJ); end
	data.error = ME.message;
	sca;
	getReport(ME);
end

fprintf('\n\n#####################\n===>>> <strong>SAVED DATA to: %s</strong>\n#####################\n\n',saveName)
save(saveName,'data');
WaitSecs(0.5);

end