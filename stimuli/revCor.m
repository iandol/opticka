function revCor(s)

mtitle   = 'Opticka Reverse Correlation Module';
options  = { 't|10','Stimulus Sizes (deg):';...
	't|1','Size of Pixel Blocks (deg):';...
	't|5','Number of Trials:';...
	't|5','Number of Seconds (secs):';...
	't|2','Number of Frames to show texture:';...
	'r|¤Trinary|Binary','White Noise Type:';...
	't|255','Value to send on LabJack:';...
	'r|Off|¤On','Debug mode:';...
	'r|¤Nearest Neighbour|Bilinear|BilinearMipmap|Trilinear|NNMipmap|NNInterp','Texture Scaling:';...
	'r|¤8bit|16bit|32bit','Texture Resolution:';...
  };
sel = menuN(mtitle, options);
if ~iscell(sel);warning('User cancelled!');return;end
stimSizes		= sel{1}; % visual degrees
blockSize		= sel{2}; % the size of each block of the noise
nTrials			= sel{3}; %repeat times
nSeconds		= sel{4};
nFrames			= sel{5}; %how many frames to show the same texture?
noiseType		= sel{6};
strobeValue		= sel{7};
debug			= logical(sel{8}-1);
filterMode		= sel{9}-1;
floatPrecision	= sel{10}-1;

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
	blockpx = blockSize * s.ppd;
	data.scale = blockpx;
	data.comment = 'scale is by how much the data.matrix is scaled to show in matlab';
	nStimuli = round(nSeconds*round(sv.fps/nFrames));
	data.nStimuli = nStimuli;
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
		data.stimuli{nSt} = mx;
		texture = [];
		for i = 1:nStimuli
			texture{nSt}(i) = Screen('MakeTexture', sv.win, mx(:,:,i), [], [], floatPrecision);
		end
	end
	
	for nTr=1:nTrials
		for nSt=1:length(stimSizes)
			tx = texture{nSt};
			% scale our texture via a rect
			rect = Screen('Rect',tx(1));
			rect = ScaleRect(rect,round(blockpx),round(blockpx));
			rect = CenterRectOnPointd(rect, sv.xCenter+(s.screenXOffset*s.ppd), sv.yCenter+(s.screenYOffset*s.ppd));
			% present stimulation
			% Screen('DrawTexture', windowPointer, texturePointer [,sourceRect] [,destinationRect]
			% [,rotationAngle] [, filterMode] [, globalAlpha] [, modulateColor] [, textureShader] [, specialFlags] [, auxParameters]);
			t=tic;
			drawPhotoDiodeSquare(s,[0 0 0]);
			lastvbl = flip(s); 
			for i = 1:length(tx)
				for j = 1:nFrames
					Screen('DrawTexture', sv.win, tx(i), [], rect, [], filterMode);
					if debug;drawGrid(s);end
					drawPhotoDiodeSquare(s,[1 1 1]);
					vbl = flip(s, lastvbl + sv.halfisi);
					lastvbl = vbl;
					if i == 1 && j == 1; sendStrobe(lJ,strobeValue); startT = vbl;end
				end
			end
			drawPhotoDiodeSquare(s,[0 0 0]);
			vbl = flip(s, vbl + sv.halfisi);
			data.times.trialLength(nTr,nSt) = vbl-startT;
			fprintf('--->>>Stimulus presentation took: %s secs\n', vbl-startT);
			WaitSecs(1);
		end
	end
	drawPhotoDiodeSquare(s,[0 0 0]);
	drawTextNow(s,'Finished!');
	
	for nSt = 1:length(stimSizes)
	tx = texture{nSt};
		for i = 1:length(tx)
			try Screen('Close', texture(i)); end %#ok<*TRYNC> 
		end
	end
	WaitSecs(1);
	close(s);
	close(lJ);
catch 
	try close(s); end
	sca;
	psychrethrow(psychlasterror);
end

fprintf('\n\nSaving DATA to %s\n\n',saveName);
save(saveName,'data');


function pixs=deg2pix(degree,cm,pwidth,vdist)
	screenWidth = cm/sqrt(1+9/16);
	pix=screenWidth/pwidth;
	pixs = round(2*tan((degree/2)*pi/180) * vdist / pix);
end
end