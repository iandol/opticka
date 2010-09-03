Screen('Preference', 'SkipSyncTests',1) 
clear all
AssertOpenGL;
try
    % ------------------------
    % set dot field parameters
    % ------------------------
    nframes     = 60; % number of animation frames in loop
    mon_width   = 33.2;   % horizontal dimension of viewable screen (cm)
    v_dist      = 57.3;   % viewing distance (cm)
    dot_speed   = 0.5;    % dot speed (deg/sec)
    ndots       = 1000; % number of dots
    max_d       = 10;   % maximum radius of  annulus (degrees)
    min_d       = 1;  % minumum radius of  annulus (degrees)
    dot_w       = 0.2;  % width of dot (deg)
    fix_r       = 0.15; % radius of fixation point (deg)
    f_kill      = 0.05; % fraction of dots to kill each frame  (limited lifetime)
    waitframes	 = 2;     % Show new dot-images at each waitframes'th  monitor refresh.
    % Experiment parameters
    trialsDesired  = 10;
    dirAng        = 90;  % In degrees
    coherence     = 50;   % Percent
    responseKey1='1';
    responseKey2='2';
	 sr = [1 1 801 601];

    guessCoherence=25;
    while isempty(guessCoherence)
        guessCoherence=input('Estimate threshold (percent): ');
    end
    guessCoherenceSd=5;
    while isempty(guessCoherenceSd)
        guessCoherenceSd=input('Estimate the standard deviation of  your guess, above, (percent): ');
    end

    ndots=round(ndots);
    % Set up screen
    screens=Screen('Screens');
    screenNumber=max(screens);
    [w, rect] = Screen('OpenWindow', screenNumber, 128,[],[], 2);
    Screen('BlendFunction', w, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    [center(1), center(2)] = RectCenter(rect);
    fps=Screen('FrameRate',w);      % frames per second
    ifi=Screen('GetFlipInterval', w);
    if fps==0
       fps=1/ifi;
    end;
    black = BlackIndex(w);
    white = WhiteIndex(w);
    Screen('FillRect', w, black)
    HideCursor; % Hide the mouse cursor
    Priority(MaxPriority(w));

    ppd = 44; %pi * (rect(3)-rect(1)) / atan(mon_width/v_dist/2) /  360;    % pixels per degree
    pfs = dot_speed * ppd / fps;                            % dot  speed (pixels/frame)
    s = dot_w * ppd;                                        % dot  size (pixels)
    fix_cord = [center-fix_r*ppd center+fix_r*ppd];
    rmax = max_d * ppd;                                     %  maximum radius of annulus (pixels from center)
    rmin = min_d * ppd;                                     % minimum

    % Provide our prior knowledge to QuestCreate, and receive the  data struct "q".
    tGuess=log(guessCoherence)/log(10);
    tGuessSd=log(guessCoherenceSd)/log(10);
    pThreshold=0.82;
    beta=3.5;delta=0.01;gamma=0.5;
    q=QuestCreate(tGuess,tGuessSd,pThreshold,beta,delta,gamma);
    q.normalizePdf=1; % This adds a few ms per call to QuestUpdate,  but otherwise the pdf will underflow after about 1000 trials.
    wrongRight={'wrong','right'};

    % Trial Loop
    for k=1:trialsDesired
            Priority(MaxPriority(w));

        tTest=QuestQuantile(q); % Recommended by Pelli (1987), and  still our favorite.
        coherence=10^tTest;
        if coherence>100
            coherence=100;
        end
        cueSign=1-(rand>0.5).*2;
        allAngles=ones(ndots,1).*(dirAng*(pi/180));
        randDots=ndots-floor(ndots*(coherence/100));
        if randDots>0
            allAngles(1:randDots)=(2*pi).*rand(1,randDots);
        end
        r = rmax * sqrt(rand(ndots,1)); % r
        r(r<rmin) = rmin;
        t = 2*pi*rand(ndots,1);                     % theta polar  coordinate
        cs = [cos(t), sin(t)];
        xy = [r r] .* cs;   % dot positions in Cartesian coordinates  (pixels from center)
        dr = pfs.*(cueSign.*ones(ndots, 1))          ;   % change in radius per  frame (pixels)
        dxdy= dr(1).*[cos(allAngles) sin(allAngles)];
        buttons=0;
        vbl=Screen('Flip', w);
        for i = 1:nframes
            if (i>1)
                Screen('DrawDots', w, xymatrix, s, white, center, 1);  % change 1 to 0 to draw square dots
                Screen('DrawingFinished', w); % Tell PTB that no  further drawing commands will follow before Screen('Flip')
                Screen('FillOval', w, [255  0 0 ], fix_cord);   %  draw fixation dot(flip erases it)
            end;
            [mx, my, buttons]=GetMouse(screenNumber);
            if any(buttons) % break out of loop
                break;
            end;
            xy = xy + dxdy;                     % move dots
            r = r + dr;                         % update polar  coordinates too
            dist=(sqrt(xy(:,1).^2+xy(:,2).^2));
            r_out = find(dist > rmax | dist < rmin | rand(ndots,1) <  f_kill);   % dots to reposition
            nout = length(r_out);
            if nout
                r(r_out) = rmax * sqrt(rand(nout,1));    % choose  new coordinates
                r(r<rmin) = rmin;
                t(r_out) = 2*pi*(rand(nout,1));
                cs(r_out,:) = [cos(t(r_out)), sin(t(r_out))]; % now  convert the polar coordinates to Cartesian
                xy(r_out,:) = [r(r_out) r(r_out)] .* cs(r_out,:);
                dxdy(r_out,:) = [dr(r_out) dr(r_out)] .* cs (r_out,:); % compute the new cartesian velocities
                dxdy(r_out,:) =dr(1).*[cos(allAngles(r_out)) sin(allAngles(r_out))];
            end;
            xymatrix = transpose(xy);
            vbl=Screen('Flip', w, vbl + (waitframes-0.5)*ifi);
        end;
        Screen('FillRect', w, black)
        Screen('FillOval', w, [255  0 0 ], fix_cord);   % draw  fixation dot (flip erases it)
        vbl=Screen('Flip', w, vbl + (waitframes-0.5)*ifi);
        % get response
        Priority(0);
        while KbCheck;
        end; % wait until all keys are released.
        escapeKey = KbName('q'); NoHit=1;
        while NoHit
            touch = 0;
            while ~touch
                [touch, secs, keyCode] = KbCheck;
            end
            FlushEvents('keyDown','mouseDown');
            theKey = KbName(logical(keyCode)); NoHit=0;
            %fprintf(['You pressed key(s) ' int2str(find(keyCode)) '  which is %s\n'],theKey);
            if keyCode(escapeKey)
                break;
            end
            while KbCheck;end; % wait until key is released.
        end
        % classify response
        responseSign=0;
        if sum(responseKey1==theKey)
            responseSign=-1;
        end
        if sum(responseKey2==theKey)
            responseSign=1;
        end
        response=(responseSign==cueSign);
        if ~response
            SysBeep
        end
        fprintf('Trial %3d at %5.2f (%d percent) is %s\n',k,tTest,floor(10^tTest),char(wrongRight(response+1)));
        q=QuestUpdate(q,tTest,response); % Add the new datum (actual  test intensity and observer response) to the database.
        pause(0.1);

    end
    FlushEvents('keyDown');

    Priority(0);
    ShowCursor
    Screen('CloseAll');
    t=QuestMean(q);     % Recommended by Pelli (1989) and King-Smith  et al. (1994). Still our favorite.
    sd=QuestSd(q);
    fprintf('Final threshold estimate (mean±sd) is %.2f percent ± %. 2f percent\n',10^t,10^sd);
    plot([1:trialsDesired],q.intensity,'o-')
 catch
     Priority(0);
     ShowCursor
     Screen('CloseAll');
 end