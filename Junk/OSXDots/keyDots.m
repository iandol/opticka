% dotroutine for keypresses
% use left and right key presses (currently not set up for any other
% directions)
% have to wait for 5 seconds or so for psychtoolbox to finish its testing,
% and get stuff ready, then hit space bar to start experiment, hit
% space bar again to pause (hit it at any time - sometimes you need to hit
% repeatedly, will wait to pause until end of current trial), and then can
% either hit return to resume or esc to exit  
% 

% to determine whether key press is correct, first determine which
% direction the dots are going, and which target is associated with this
% direction. Then we can compare if the keypress was for the same target.
% This depends on how the dot directions were entered into the config file.
% Whichever direction is first will be associated with the left arrow.
% Eventually would be nice to incorporate up and down arrows, and make the
% association smarter (ie. look at the actual directions instead of their
% position to determine correct keypress)

% The correction trial option keeps track of errors. If subject makes an
% error to the same side 3 times, will keep going to that side until
% subject does the trial correctly, then returns to random.

clear all;

done = 0;

% order we go through the cases is determined by trialtype and timing
% (dotInfo.trialtype and dotInfo.minTime)
% cases used:
% fixon - turn on fixation
% wait - waits for a key press.
% targson - turns on targets
% dotson - turns on dots
% fixoff - turns off fixation 
% correct - rewards correct trial
% incorrect - does not reward
% endtrial - keeps track of errorcount, saves data at certain intervals,
% and determines if there was an abort
% pause - stops the experiment and waits for user input (resume or end)


% setup
try

    %initialize the screen
    % touchscreen is 34, laptop is 32, viewsonic is 38
    screenInfo = openExperiment(34,50,0);

    % initiate feedback sound
    [freq beepmatrix] = createSound;

    % initialize dotInfo structure if no file present
    if ~exist('KeydotInfoMatrix.mat','file')
        createDotInfo(1);
	end

    % keep track of trial number
    count = 0;

    % start with fixation
    nextstep = 'fixon';
    % push any key to start trials - KbWait doesn't seem to work unless we
    % assign a variable to it, but since we don't care when it was pushed
    % just re-use the variable to save memory.
    abort = KbWait();
    abort = 0;

    [keyIsDown, secs, keyCode] = KbCheck;

    % start experiment
    while ~done
        switch nextstep
            case 'fixon'

                abort = 0;
                count = count + 1;
                % determine dot direction, coherence, etc. for this run
                load keyDotInfoMatrix
				
                % need this for error correction mode
                % not sure if this really works with more than two directions
                errorcnt = [zeros(size(dotInfo.dirSet))];

                keys = [dotInfo.keyLeft dotInfo.keyRight];
		
                % set up trial
                dotInfo = randomDotTrial(dotInfo, errorcnt);
                %screenInfo

                % if we go into correction mode, flash a small dot in the
                % left top corner of the screen.
                trialData(count).cormode= 0;
                trialData(count).coh = dotInfo.coh;
                
                if any(errorcnt == 3)
                    Screen('FillOval', screenInfo.curWindow, [100 100 100], [10 12 40 42]);
                    Screen('DrawingFinished',screenInfo.curWindow, screenInfo.dontclear);
                    Screen('Flip', screenInfo.curWindow, 0, screenInfo.dontclear);
                    Screen('DrawingFinished',screenInfo.curWindow, screenInfo.dontclear);
                    Screen('Flip', screenInfo.curWindow, 0, screenInfo.dontclear);
                end

                % keep track of trials that are due to correction mode
                if any(errorcnt > 2)
                    trialData(count).cormode = find(errorcnt>2);
				end
                % initialize targets
                targets = makeDotTargets(screenInfo, dotInfo);
                % figure out which target will be the correct one
                %dotInfo;
                trialData(count).corTar = find(dotInfo.dirSet==dotInfo.dir);
                trialData(count).dotDir = dotInfo.dir;
                % goodtrial is zero, unless makes it to end of trial
                trialData(count).goodtrial = 0;
                % if good trial, this will be filled in with a rxtime
                if dotInfo.trialtype == 2
                    trialData(count).rxtime = nan;
                end
                % make sure that the wrong targets(s) is (are) colored if suppose to be
                if ~isempty(dotInfo.wrongColor)
                    colIndex = zeros(1,length(dotInfo.tarDiam) + 1);
                    colIndex(1) = 1; % don't want fixation color changed
                    colIndex(trialData(count).corTar + 1) = 1; % don't want correct target color changed
                    % change the incorrect targets color
                    targets = newTargets(screenInfo, targets, [find(colIndex==0)], [], [], [], [dotInfo.wrongColor]);
                end
                starttime = GetSecs;
                % official start of trial
                showTargets(screenInfo, targets, 1);
                if dotInfo.minTime(1) == 0
                    nextstep = 'targson';
                else
                    nextstep = 'wait';
                    % if minTime 1 is greater than minTime 2 then we
                    % are doing dots before targets; waiting is fix to
                    % dots on
                    if dotInfo.minTime(1) > dotInfo.minTime(2)
                        afterwait = 'dotson';
                        waittime = dotInfo.minTime(2);
                    elseif dotInfo.minTime(2) >= dotInfo.minTime(1)
                        % if minTime 2 is greater than minTime 1 then
                        % we need to put up the targets before we do
                        % the dots. waiting is fix to targson
                        afterwait = 'targson';
                        waittime = dotInfo.minTime(1);
                    end
                end

            case 'wait'
                % wait specified time, checking for abort
                waitloop = 1;
                while waitloop
                    % loop ends when time delay is met
                    if GetSecs - starttime >= waittime
                        %disp('waited long enough')
                        waitloop = 0;
                    end
                    % DO I NEED A WAITSECS HERE?
                    % check for abort
                    [keyIsDown, secs, keyCode] = KbCheck;
                    if keyIsDown
                        if keyCode(dotInfo.keySpace)
                            %disp('abort');
                            abort = 1;
                        % any other keypress is an error
                        else
                            afterwait = 'incorrect';
                        end;
                    end
                end
                nextstep = afterwait;

            case 'targson'
                % draw
                showTargets(screenInfo, targets, [1:length(targets.d)]);
                % if time from fixation until targets on (minTime(2))
                % is greater than time from fixation until dots on,
                % then we show dots first, and then targets, otherwise
                % targets and then dots.
                if dotInfo.minTime(1) > dotInfo.minTime(2)
                    % dots have already been on, use delay from dots off to fix
                    % on measured from time of dots off (already set
                    % starttime at dotson), for reaction time, targets
                    % should always be up before dots - assume user is
                    % smart enough to figure that out.
                    afterwait = 'fixoff';
                    waittime = dotInfo.minTime(4);
                elseif dotInfo.minTime(2) >= dotInfo.minTime(1)
                    afterwait = 'dotson';
                    % wait however much longer to turn on dots as time from
                    % dots on minus targets on. (fix to dots on - fix
                    % to targets on)
                    starttime = GetSecs;
                    waittime = dotInfo.minTime(2) - dotInfo.minTime(1);
                end
                nextstep = 'wait';

            case 'dotson'
                %dotInfo
                %screenInfo
                [frames, rseed, start_time, end_time, response, response_time] = dotsX(screenInfo, dotInfo, targets);
                % if response{2} == 1, then spacebar was hit during the
                % dots, and we want to abort after this trial.
                
                if response{1} == 1
                    abort = 1;
                end
                
                trialData(count).rseed = rseed;
                tcnt = trialData(count).corTar;

                %response
                % for rt task, should have exited dots early (response{1}
                % will have something in it)
                
                if ~isnan(response{3})
                    %disp('isnan')
                    % if pressed a key during dots, and it was fixed
                    % duration, incorrect.
                    if dotInfo.trialtype(1) == 1
                        nextstep = 'incorrect';
                        % for rt, need to figure out if response was
                        % appropriate. Right now we are assuming a
                        % right/left paradigm. Have to figure out what to
                        % do if not.
                    else
                        % reaction time
                        % since we made it far enough to see if touching
                        % correct target, its a good trial
                        trialData(count).goodtrial = 1;
                        trialData(count).rxtime = response_time - start_time;
                        if response{3} == tcnt
                            nextstep = 'correct';
                        else
                            nextstep = 'incorrect';
                        end
                    end
                elseif dotInfo.trialtype(1) == 2
                    % if reaction time and didn't hit a key during the
                    % dots, then an error
                    nextstep = 'incorrect';
                else
                    % fixed duration - hasn't pressed yet
                    nextstep = 'wait';
                    % once dots have finished, all timing should be with
                    % reference to when the dots went off. (starttime is always
                    % the time we judge the wait time with, and end_time is
                    % when the dots went off)
                    starttime = end_time;
                    % if time from fixation until targets on (minTime(1))
                    % is greater than time from fixation until dots on,
                    % then we show dots first, and then targets, otherwise
                    % targets and then dots.
                    if dotInfo.minTime(1) > dotInfo.minTime(2)
                        afterwait = 'targson';
                        % all wait times are from dots off. If screwed up and
                        % have targets coming on after fixation goes off, just
                        % turn targets on at same time as fixation goes off,
                        % and use time from dots off to fixation for waittime
                        % otherwise have to figure out time to wait as time
                        % from fix to targets on minus fix to dots off (mintime
                        % 2 + 3)
                        % if fix to targets > (fix to dots + dot dur + dots off to fix off) use fix off for both
                        if dotInfo.minTime(1) > sum(dotInfo.minTime(2:4))
                            waittime = dotInfo.minTime(4);
                        else
                            % waittime = fix to targets-(fix to dots + dot dur)
                            waittime = dotInfo.minTime(1) - sum(dotInfo.minTime(2:3));
                        end
                    elseif dotInfo.minTime(2) >= dotInfo.minTime(1)
                        afterwait = 'fixoff';
                        % can just use dots off to fix off for waittime here
                        waittime = dotInfo.minTime(4);
                    end
                end
                
            case 'fixoff'
                showTargets(screenInfo, targets, [2:length(targets.d)]);
                drawtime = GetSecs;
                % have to wait for keypress now.
                % decide whether want seperate waitpress case.
                % doesn't seem necessary, since only wait for press
                % either here or during dots.
                hold = 1;
                while hold
                    [keyIsDown,secs,keyCode] = KbCheck;
                    % loop ends when time delay is met
                    if GetSecs - drawtime >= dotInfo.minTime(5)
                        %disp('waited long enough')
                        response{1} = 0;
                        hold = 0;
                    end
                    if keyIsDown,
                        if keyCode(dotInfo.keySpace)
                            %disp('abort');
                            abort = 1;
                        end
                        if any(keyCode(keys)),
                            response{1} = find(keyCode(keys));
                            hold = 0;
                        end;
                    end;
                end
                trialData(count).goodtrial = 1;
                if response{1} == tcnt
                    nextstep = 'correct';
                else
                    nextstep = 'incorrect';
                end

            case 'correct'
                screenInfo.rewardOn
                if screenInfo.rewardOn == 1
                    err=DaqAOut(screenInfo.daq(1),0,1); % D/A 0
                    WaitSecs(0.5)
                    err=DaqAOut(screenInfo.daq(1),0,0); % D/A 1
                end
                % erase the targets up
                showTargets(screenInfo, targets, []);
                %disp('correct')
                sound(beepmatrix,freq)
                WaitSecs(0.5)
                trialData(count).correct = 1;
                nextstep = 'endtrial';

            case 'incorrect'
                % erase the targets up
                showTargets(screenInfo, targets, []);
                %disp('wrong!')
                sound(beepmatrix,freq)
                %etime(clock,t0)
                WaitSecs(0.1);
                sound(beepmatrix,freq)
                WaitSecs(2)
                trialData(count).correct = 0;
                nextstep = 'endtrial';

            case 'endtrial'
                if dotInfo.auto(3) == 3
                    % if was an error where the monkey chose the wrong
                    % target (rather than broke fixation), then keep count
                    % of error
                    if trialData(count).correct == 0 && trialData(count).goodtrial
                        % if error, add 1 to the counter for that direction
                        errorcnt(trialData(count).corTar) = errorcnt(trialData(count).corTar) + 1;
                    elseif trialData(count).correct == 1
                        errorcnt(trialData(count).corTar) = 0;
                    end
                    % if there is a correction loop, send the other
                    % counters back to zero
                    %disp('going into correction mode')
                    %any(errorcnt > 2)
                    if any(errorcnt > 2)
                        find(errorcnt < 3);
                        errorcnt(find(errorcnt < 3)) = 0;
                    end
                end
                % save the data every 100 trials
                if count/100 == round(count/100)
                    save(['keydots' num2str(date)], 'trialData');
                end
                if count == 275
                    done = 1;
                end
                if abort == 1
                    nextstep = 'pause';
                else
                    nextstep = 'fixon';
                end

            case 'pause'

                % give a pause so abort beeps don't run together with
                % correct/incorrect beeps
                WaitSecs(0.5);
                % let everyone know we are paused
                sound(beepmatrix,freq)
                WaitSecs(0.1);
                sound(beepmatrix,freq)
                WaitSecs(0.1);
                sound(beepmatrix,freq)
                WaitSecs(0.1);
                sound(beepmatrix,freq)
                WaitSecs(0.1);

                % Wait to see what user does. esc for quit, return to
                % continue experiment
                secs = KbWait();
                [keyIsDown, secs, keyCode] = KbCheck;
                if keyCode(dotInfo.keyEscape)
                    done = 1;
                    abort = 0;
                    % continue experiment
                elseif any(keyCode(dotInfo.keyReturn))
                    [keyIsDown, secs, keyCode] = KbCheck;
                    abort = 0;
                    nextstep = 'fixon';
                end
        end
    
        %keyIsDown;
        %keyCode(dotInfo.keySpace);
        %abort;
        %nextstep
    end
    save(['keydots' num2str(date)], 'trialData', 'dotInfo');
    closeExperiment;
catch
    disp('caught')
    lasterr
    closeExperiment;
end


