function ianplaid

sf=0.01;
tf=2;
texsize=400;
angle=0;
drawmask=1;
gaus=texsize/2;
rotationstep=0.5;

try
	AssertOpenGL;
	screens=Screen('Screens');
	screenNumber=max(screens); 
	
	white=WhiteIndex(screenNumber);
	black=BlackIndex(screenNumber);
	gray=(white+black)/2;
	if round(gray)==white
		gray=black;
	end
	inc=white-gray;
	
	p=ceil(1/sf);  % pixels/cycle    
	fr=sf*2*pi;
	visiblesize=2*texsize+1;
	
	[x,y]=meshgrid(-2*texsize:2*texsize + p, -texsize:texsize);
	grating=gray + inc*cos(fr*x);
	
	% Create a single gaussian transparency mask and store it to a texture:
	mask=ones(2*texsize+1, 2*texsize+1, 2) * gray;
	[x,y]=meshgrid(-1*texsize:1*texsize,-1*texsize:1*texsize);
	mask(:, :, 2)=white * (1 - exp(-((x/gaus).^2)-((y/gaus).^2)));
	
	%PsychImaging('PrepareConfiguration');
	%PsychImaging('AddTask', 'General', 'FloatingPoint32BitIfPossible');
	
	Screen('Preference', 'VisualDebuglevel', 3); %manage the debug level
	[w screenRect]=Screen('OpenWindow',screenNumber, 0,[],32,2);
    Screen('BlendFunction', w, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
	%Screen('BlendFunction', w, GL_SRC_ALPHA, GL_ONE);
    Screen('FillRect',w, gray);
	Screen('Flip', w);
	
	gratingtex=Screen('MakeTexture', w, grating,[],[],2);
	
	masktex=Screen('MakeTexture', w, mask);
	
	% Query duration of monitor refresh interval:
	ifi=Screen('GetFlipInterval', w);

	waitframes = 1;
	waitduration = waitframes * ifi;
	
	% Translate requested speed of the grating (in cycles per second)
	% into a shift value in "pixels per frame", assuming given
	% waitduration: This is the amount of pixels to shift our "aperture" at
	% each redraw:
	shiftperframe= tf * p * waitduration;

	xoffset = 0;
	angle = 0;
	i=0;
	
	vbl=Screen('Flip', w);
	
	dstRect=[0 0 visiblesize visiblesize];
	dstRect = CenterRect(dstRect, screenRect);
	
	while(1)
        % Shift the grating by "shiftperframe" pixels per frame:
        xoffset = mod(i*shiftperframe,p);
        i=i+1;
        
        % Define shifted srcRect that cuts out the properly shifted rectangular
        % area from the texture:
        srcRect=[xoffset 0 xoffset + visiblesize visiblesize];
        
        % Draw grating texture, rotated by "angle":
		if mod(i,2)
			Screen('DrawTexture', w, gratingtex, srcRect, dstRect, angle);
		else
			Screen('DrawTexture', w, gratingtex, srcRect, dstRect, angle);
		end

        if drawmask==1
            % Draw gaussian mask over grating: We need to subtract 0.5 from
            % the real size to avoid interpolation artifacts that are
            % created by the gfx-hardware due to internal numerical
            % roundoff errors when drawing rotated images:
            Screen('DrawTexture', w, masktex, [0 0 visiblesize visiblesize], dstRect, angle);
        end;

        angle = angle + rotationstep;
        
        % Flip 'waitframes' monitor refresh intervals after last redraw.
        vbl = Screen('Flip', w, vbl + (waitframes - 0.5) * ifi);

        % Abort demo if any key is pressed:
        if KbCheck
            break;
        end;
    end;

    %The same commands wich close onscreen and offscreen windows also close
	%textures.
	Screen('CloseAll');

catch
    %this "catch" section executes in case of an error in the "try" section
    %above.  Importantly, it closes the onscreen window if its open.
    Screen('CloseAll');
    psychrethrow(psychlasterror);
end %try..catch..
	
	