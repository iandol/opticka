function revCor(s)

mtitle   = 'Opticka Reverse Correlation Module';
options  = { 't|10','Stimulus Sizes (deg):';...
	't|1','Size of Pixel Blocks (deg):';...
	't|2','Number of Trials:';...
	't|5','Number of Seconds (secs):';...
	't|2','Number of Frames to show texture:';...
	'r|¤Trinary|Binary','White Noise Type:';...
	't|255','Value to send on LabJack:';...
	'r|Off|¤On','Debug mode:';...
	'r|¤Nearest Neighbour|Bilinear|BilinearMipmap|Trilinear|NNMipmap|NNInterp','Texture Scaling:';...
	'r|¤8bit|16bit|32bit','Texture Resolution:';...
  };
sel = menuN(mtitle, options);
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
drawPhotoDiodeSquare(s,[0 0 0]);s.flip;
sv = s.screenVals;

saveName = [s.paths.savedData filesep 'RevCor-' s.initialiseSaveFile '.mat'];

lJ = labJackT;
if ~lJ.isOpen;open(lJ);end

try
	blockpx = blockSize * s.ppd;
	randomdegreea11 = zeros(nTrials,length(stimSizes));

	for irp=1:nTrials

		randomdegreeindex=randperm(length(stimSizes)); % generate a random sequence of visual degrees
		
		for ivd=1:length(stimSizes)
			t=tic;

			nStimuli = round(nSeconds*round(sv.fps/nFrames));
			pxLength = round(stimSizes(randomdegreeindex(ivd)) * (1/blockSize));
			mx = rand(pxLength,pxLength,nStimuli);

			if noiseType == 1
				mx(mx < (1/3)) = 10;
				mx(mx < (2/3)) = 20;
				mx(mx <= 1) = 30;
				mx(mx == 10) = 0;
				mx(mx == 20) = 0.5;
				mx(mx == 30) = 1;
			else
				mx(mx < 0.5) = 0;
				mx(mx > 0) = 1;
			end
			fprintf('--->>>Matrix construction took: %.2f secs\n',toc(t));

			% Screen('MakeTexture', WindowIndex, imageMatrix [, optimizeForDrawAngle=0] [, specialFlags=0]
			% [, floatprecision] [, textureOrientation=0] [, textureShader=0]);
			t=tic;
			texture = [];
			for i = 1:nStimuli
				texture(i) = Screen('MakeTexture', sv.win, mx(:,:,i), [], [], floatPrecision);
			end
			fprintf('--->>>Texture construction took: %.2f secs\n',toc(t));

			rect = Screen('Rect',texture(1));
			rect = ScaleRect(rect,round(blockpx),round(blockpx));
			rect = CenterRectOnPointd(rect, sv.xCenter, sv.yCenter);

			% present stimulation
			% Screen('DrawTexture', windowPointer, texturePointer [,sourceRect] [,destinationRect]
			% [,rotationAngle] [, filterMode] [, globalAlpha] [, modulateColor] [, textureShader] [, specialFlags] [, auxParameters]);

			drawPhotoDiodeSquare(s,[0 0 0]);
			vbl = flip(s); 
			for i = 1:length(texture)
				for j = 1:nFrames
					Screen('DrawTexture', sv.win, texture(i), [], rect, [], filterMode);
					if debug;drawGrid(s);end
					drawPhotoDiodeSquare(s,[1 1 1]);
					vbl = flip(s, vbl + sv.halfisi);
					if i == 1 && j == 1; sendStrobe(lJ,strobeValue); startT = vbl;end
				end
			end
			drawPhotoDiodeSquare(s,[0 0 0]);
			vbl = flip(s, vbl + sv.halfisi);
			fprintf('--->>>Stimulus presentation took: %s secs\n', vbl-startT);
			
			for i = 1:length(texture)
				try Screen('Close', texture(i)); end %#ok<*TRYNC> 
			end
			WaitSecs(1);
		end
		randomdegreea11(irp,:)=randomdegreeindex;
	end
	drawPhotoDiodeSquare(s,[0 0 0]);
	drawTextNow(s,'Finished!');
	WaitSecs(1);
	close(s);
	close(lJ);
catch 
	try close(s); end
	sca;
	psychrethrow(psychlasterror);
end

fprintf('\n\nSaving DATA to %s\n\n',saveName);
save(saveName,'randomdegreea11');


function pixs=deg2pix(degree,cm,pwidth,vdist)
	screenWidth = cm/sqrt(1+9/16);
	pix=screenWidth/pwidth;
	pixs = round(2*tan((degree/2)*pi/180) * vdist / pix);
end
end