function [dpi, dpc] = calibrateSize(theScreen,distance, mSize)
% dpi=MeasureDpi([theScreen])
% Helps the user to accurately measure the screen's dots per inch.
%
% Denis Pelli

% 5/28/96 dgp Updated to use new GetMouse.
% 3/20/97 dgp Updated.
% 4/2/97  dgp FlushEvents.
% 4/26/97 dhb Got rid of call to disp(7), which was writing '7' to the
%             command window and not producing a beep.
% 8/16/97 dgp Changed "text" to "theText" to avoid conflict with TEXT function.
% 4/06/02 awi Check all elements of the new multi-element button vector
%             returned by GetMouse on Windows.
%             Replaced Chicago font with Arial because it's available on
%             both Mac and Windows
% 11/6/06 dgp Updated from PTB-2 to PTB-3.

if nargin>3 || nargout>2
	error('Usage: [dpi,dpc]=calibrateSize(screen,distance,mSize)');
end
if nargin<1
	theScreen=0;
end
if nargin<2
	distance = 57.3;
end
if nargin<3
	mSize = 7.7;
end

AssertOpenGL;

try
	inches = 0;
	unitInches=1/2.54;
	units='cm';
	unit='cm';
	objectInches=mSize*unitInches;
	disp('A small correction will be made for your viewing distance and the thickness of');
	disp('the screen''s clear front plate, which separates your object from the screen''s');
	disp('light emitting surface.');
	if Screen('FrameRate',theScreen)==0
		thicknessInches=0.1;
		fprintf('The zero nominal frame rate of your display suggests that it''s an LCD, \n');
		fprintf('with a thin (%.1f inch) clear front plate.\n',thicknessInches);
	else
		thicknessInches=0.25;
		fprintf('The nonzero nominal frame rate of your display suggests that it''s a CRT, \n');
		fprintf('with a thick (%.1f inch) clear front plate.\n',thicknessInches);
	end
	distanceInches=distance*unitInches;
	Screen('Preference', 'SkipSyncTests', 1);
	Screen('Preference', 'VisualDebugLevel', 0);
	[window,screenRect]=Screen('OpenWindow',theScreen, 128);
	white=WhiteIndex(window);
	black=BlackIndex(window);
	
	% Instructions
	s=sprintf('Hold your %.1f-%s-wide object against the display.',objectInches/unitInches,unit);
	theText={s,'Use one eye. Drag to match the object''s width.'};
	Screen('TextFont',window,'Helvetica');
	s=18;
	Screen('TextSize',window,s);
	textLeading=s+5;
	textRect=Screen('TextBounds',window,theText{1});
	textRect(4)=length(theText)*textLeading;
	textRect=CenterRect(textRect,screenRect);
	textRect=AlignRect(textRect,screenRect,RectTop);
	textRect(RectRight)=screenRect(RectRight);
	dragText=theText;
	dragTextRect=textRect;
	
	% Animate
	% Track horizontal mouse position to draw a bar of variable width.
	for i=1:length(dragText)
		Screen('DrawText',window,dragText{i},dragTextRect(RectLeft),dragTextRect(RectTop)+textLeading*i,black);
	end
	barRect=CenterRect(SetRect(0,0,RectWidth(screenRect),20),screenRect);
	fullBarRect=barRect;
	top=RectTop;
	bottom=RectBottom;
	left=RectLeft;
	right=RectRight;
	width=0;
	Screen('FillRect',window,white,fullBarRect);
	Screen('Flip',window);
	oldButton=0;
	while 1
		[x,~,button]=GetMouse(theScreen);
		FlushEvents('mouseDown');
		if any(button)
			if ~oldButton
				origin=x;
				barRect(left)=origin;
				barRect(right)=origin;
			else
				if x<origin
					barRect(left)=x;
					barRect(right)=origin;
				else
					barRect(left)=origin;
					barRect(right)=x;
				end
			end
			width = abs(origin-x);
			if ~IsEmptyRect(barRect)
				Screen('FillRect',window,[80,0,0],barRect);
			end
			backgroundRect=barRect;
			backgroundRect(left)=screenRect(left);
			backgroundRect(right)=barRect(left);
			if ~IsEmptyRect(backgroundRect)
				Screen('FillRect',window,white,backgroundRect);
			end
			backgroundRect(left)=barRect(right);
			backgroundRect(right)=screenRect(right);
			if ~IsEmptyRect(backgroundRect)
				Screen('FillRect',window,white,backgroundRect);
			end
			for i=1:length(dragText)
				Screen('DrawText',window,dragText{i},dragTextRect(RectLeft),dragTextRect(RectTop)+textLeading*i,black);
			end
			Screen('Flip',window);
			if ~IsEmptyRect(barRect)
				finalRect=barRect;
				finalRect(bottom)=finalRect(top)+(width);
				finalRect(right)=finalRect(left)+(width);
				Screen('FillRect',window,[0,80,0],finalRect);
			end
		else
			if oldButton
				objectPix=RectWidth(barRect);
				dpi=objectPix/objectInches;
				dpi=dpi*distanceInches/(distanceInches+thicknessInches);
				dpc=dpi/2.54;
				clear theText
				if inches
					theText{1}=sprintf('%.0f dots per inch.',dpi);
				else
					theText{1}=sprintf('%.0f dots per cm. (%.0f dots/inch.)',dpc,dpi);
				end
				theText{2}='Click once to repeat; twice to exit. Use green square to check vertical CRT calibration.';
				textRect=Screen('TextBounds',window,theText{2});
				textRect(4)=length(theText)*textLeading;
				textRect=CenterRect(textRect,screenRect);
				textRect=AlignRect(textRect,screenRect,RectTop);
				for i=1:length(theText)
					Screen('DrawText',window,theText{i},textRect(RectLeft),textRect(RectTop)+textLeading*i,black);
				end
				Screen('Flip',window);
				i=GetClicks;
				if ~IsEmptyRect(barRect)
					Screen('FillRect',window,white,fullBarRect);
				end
				if i>1
					break
				end
				for i=1:length(dragText)
					Screen('DrawText',window,dragText{i},dragTextRect(RectLeft),dragTextRect(RectTop)+textLeading*i,black);
				end
				%Screen('FrameRect',window,black,fullBarRect);
				Screen('Flip',window);
			end
		end
		oldButton=any(button);
	end
	Screen('Close',window);
catch
	ShowCursor;
	Screen('CloseAll');
	FlushEvents('keyDown');
	while CharAvail
		GetChar;
	end
	psychrethrow(psychlasterror);
end
