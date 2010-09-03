function DriftDemo5(angle, cyclespersecond, f, drawmask)
% function DriftDemo2Ext(angle, cyclespersecond, f, drawmask)
% ___________________________________________________________________
%
% Display an animated grating using the new Screen('DrawTexture') command.
% In the OS X Psychtoolbox Screen('DrawTexture') replaces
% Screen('CopyWindow'). The demo will stop after roughly 20 seconds have
% passed or after the user hits a key.
%
% This demo illustrates how to draw an animated grating online by use of
% only one grating texture. We create one texture with a static sine
% grating. In each successive frame we only draw a rectangular subregion of
% the sine-texture onto the screen, basically showing the texture through
% an aperture. The subregion - and therefore our "aperture" is shifted each
% frame, so we create the impression of a moving grating.
%
% The demo also shows how to use alpha-blending for masking the grating
% with a gaussian transparency mask (a texture with transparency layer).
%
% And finally, we demonstrate rotated drawing, as well as how to emulate
% the old OS-9 'WaitBlanking' command with the new 'Flip' command.
%
% Parameters:
%
% angle = Angle of the grating with respect to the vertical direction.
% cyclespersecond = Speed of grating in cycles per second.
% f = Frequency of grating in cycles per pixel.
% drawmask = If set to 1, then a gaussian aperture is drawn over the grating
%
% CopyWindow vs. DrawTexture:
%
% In the OS 9 Psychtoolbox, Screen ('CopyWindow") was used for all
% time-critical display of images, in particular for display of the movie
% frames in animated stimuli. In contrast, Screen('DrawTexture') should not
% be used for display of all graphic elements, but only for display of
% MATLAB matrices. For all other graphical elements, such as lines, rectangles,
% and ovals we recommend that these be drawn directly to the display
% window during the animation rather than rendered to offscreen windows
% prior to the animation.
%
% _________________________________________________________________________
%
% see also: PsychDemos, MovieDemo

% HISTORY
% 6/7/05 mk Adapted from Allen Ingling's DriftDemoOSX.m

if nargin<4
    % By default, we mask the grating by a gaussian transparency mask:
    drawmask=1;
end;

if nargin<3
    % Grating cycles/pixel
    f=0.05;
end;

if nargin<2
    % Speed of grating in cycles per second:
    cyclespersecond=1;
end;

if nargin<1
    % Angle of the grating: We default to 30 degrees.
    angle=30;
end;

movieDurationSecs=20; % Abort demo after 20 seconds.
% Choose really huge texsize, so image covers even a large screen, even if
% no mask/aperture is used:
texsize=300; % Half-Size of the grating image.

% Screen('Preference', 'SkipSyncTests', 1);

try
    % This script calls Psychtoolbox commands available only in OpenGL-based
    % versions of the Psychtoolbox. (So far, the OS X Psychtoolbox is the
    % only OpenGL-base Psychtoolbox.) The Psychtoolbox command AssertPsychOpenGL
    % an error message if someone tries to execute this script on a computer
    % an OpenGL Psychtoolbox
    AssertOpenGL;

    % Get the list of screens and choose the one with the highest screen number.
    % Screen 0 is, by definition, the display with the menu bar. Often when
    % two monitors are connected the one without the menu bar is used as
    % the stimulus display. Chosing the display with the highest dislay number is
    % a best guess about where you want the stimulus displayed.
    screens=Screen('Screens');
    screenNumber=max(screens);

    % Find the color values which correspond to white and black. Though on OS
    % X we currently only support true color and thus, for scalar color
    % arguments,
    % black is always 0 and white 255, this rule is not true on other platforms
    % not remain true on OS X after we add other color depth modes.
    white=WhiteIndex(screenNumber);
    black=BlackIndex(screenNumber);
    gray=(white+black)/2;
    if round(gray)==white
        gray=black;
    end
    inc=white-gray;

    % Open a double buffered fullscreen window and draw a gray background
    % to front and back buffers:
    [w screenRect]=Screen('OpenWindow',screenNumber, 0,[],32,2);
    Screen('BlendFunction', w, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    Screen('FillRect',w, gray);
    Screen('Flip', w);

    % Calculate parameters of the grating:
    p=ceil(1/f); % pixels/cycle, rounded up.
    fr=f*2*pi;
    visiblesize=2*texsize+1;
    visible2size=visiblesize/2;

    % Create one single static grating image:
    % MK: We only need a single texture row (i.e. 1 pixel in height) to
    % define the whole grating! If srcRect in the Drawtexture call below is
    % "higher" than that (i.e. visibleSize >> 1), the GPU will
    % automatically replicate pixel rows. This 1 pixel height saves memory
    % and memory bandwith, ie. potentially faster.
    [x,y]=meshgrid(-texsize:texsize + p, 1);
    grating=gray + inc*cos(fr*x);

    circle=ones(texsize+1, texsize+1, 2) * gray;
    [x2,y2]=meshgrid(-texsize/2:texsize/2 + p, 1);
    circle= white *(1-(x2.^2 + y2.^2 <= (texsize/2)^2)) % circular boundry
    m=cos(fr*x2);
    grating2=gray + inc*m;


    % Store grating in texture:
    gratingtex=Screen('MakeTexture', w, grating);
    grating2tex=Screen('MakeTexture', w, grating2);

    % Create a single gaussian transparency mask and store it to a texture:
    mask=ones(2*texsize+1, 2*texsize+1, 2) * gray;
    [x,y]=meshgrid(-1*texsize:1*texsize,-1*texsize:1*texsize);
    %mask(:, :, 2)=white * (1 - exp(-((x/90).^2)-((y/90).^2)));
    mask(:, :, 2)=white * (1-(x.^2 + y.^2 <= texsize^2));
    masktex=Screen('MakeTexture', w, mask);

    priorityLevel=MaxPriority(w);

    % We don't use Priority() in order to not accidentally overload older
    % machines that can't handle a redraw every 40 ms. If your machine is
    % fast enough, uncomment this to get more accurate timing.
    %Priority(priorityLevel);

    % Definition of the drawn rectangle on the screen:
    dstRect=[0 0 visiblesize visiblesize];
    dstRect=CenterRect(dstRect, screenRect);

    % Definition of the drawn rectangle on the screen:
    dst2Rect=[0 0 visible2size visible2size];
    dst2Rect=CenterRect(dst2Rect, screenRect);

    % Query duration of monitor refresh interval:
    ifi=Screen('GetFlipInterval', w);

    waitframes = 1;
    waitduration = waitframes * ifi;

    % Recompute p, this time without the ceil() operation from above.
    % Otherwise we will get wrong drift speed due to rounding!
    p=1/f; % pixels/cycle

    % Translate requested speed of the grating (in cycles per second)
    % into a shift value in "pixels per frame", assuming given
    % waitduration: This is the amount of pixels to shift our "aperture" at
    % each redraw:
    shiftperframe = cyclespersecond * p * waitduration;

    % Perform initial Flip to sync us to the VBL and for getting an initial
    % VBL-Timestamp for our "WaitBlanking" emulation:
    vbl=Screen('Flip', w);

    % We run at most 'movieDurationSecs' seconds if user doesn't abort via
    % keypress.
    vblendtime = vbl + movieDurationSecs;
    i=0;

    % Animationloop:
    while(vbl < vblendtime)

        % Shift the grating by "shiftperframe" pixels per frame:
        xoffset = mod(i*shiftperframe,p);
        i=i+1;

        % Define shifted srcRect that cuts out the properly shifted rectangular
        % area from the texture:
        srcRect=[xoffset 0 xoffset + visiblesize visiblesize];
        src2Rect=[xoffset 0 xoffset + visible2size visible2size];
        % Draw grating texture, rotated by "angle":
        Screen('DrawTexture', w, gratingtex, srcRect, dstRect, angle);

        if drawmask==1
            % Draw gaussian mask over grating: We need to subtract 0.5 from
            % the real size to avoid interpolation artifacts that are
            % created by the gfx-hardware due to internal numerical
            % roundoff errors when drawing rotated images:
            Screen('DrawTexture', w, masktex, [0 0 visiblesize visiblesize],dstRect, angle);
        end;

        Screen('Blendfunction', w, GL_ONE, GL_ZERO, [0 0 0 1]);
        Screen('FillRect', w, [0 0 0 0], dst2Rect);
        Screen('FillOval', w, [0 0 0 255], dst2Rect);
        Screen('Blendfunction', w, GL_DST_ALPHA, GL_ONE_MINUS_DST_ALPHA, [1 1 1 1]);        
        Screen('DrawTexture', w, grating2tex, src2Rect, dst2Rect, 90);
        Screen('Blendfunction', w, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

        % Flip 'waitframes' monitor refresh intervals after last redraw.
        vbl = Screen('Flip', w, vbl + (waitframes - 0.5) * ifi);




        % Abort demo if any key is pressed:
        if KbCheck
            break;
        end;
    end;

    Priority(0);

    %The same commands wich close onscreen and offscreen windows also close
    %textures.
    Screen('CloseAll');

catch
    %this "catch" section executes in case of an error in the "try" section
    %above. Importantly, it closes the onscreen window if its open.
    Screen('CloseAll');
    Priority(0);
    psychrethrow(psychlasterror);
end %try..catch..

