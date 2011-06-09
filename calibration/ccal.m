function varargout = ccal(varargin)
% CCAL M-file for ccal.fig
%      CCAL, by itself, creates a new CCAL or raises the existing
%      singleton*.
%
%      H = CCAL returns the handle to a new CCAL or the handle to
%      the existing singleton*.
%
%      CCAL('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in CCAL.M with the given input arguments.
%
%      CCAL('Property','Value',...) creates a new CCAL or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before ccal_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to ccal_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help ccal

% Last Modified by GUIDE v2.5 09-Jun-2011 17:36:02

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @ccal_OpeningFcn, ...
                   'gui_OutputFcn',  @ccal_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT


% --- Executes just before ccal is made visible.
function ccal_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to ccal (see VARARGIN)

% Choose default command line output for ccal
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes ccal wait for user response (see UIRESUME)
% uiwait(handles.figure1);
cc=ColorCal2('GetRawData');
set(handles.ccaltriggerlevel,'String',num2str(cc.Trigger));

% --- Outputs from this function are returned to the command line.
function varargout = ccal_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;



function ccaltext_Callback(hObject, eventdata, handles)
% hObject    handle to ccaltext (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of ccaltext as text
%        str2double(get(hObject,'String')) returns contents of ccaltext as a double


% --- Executes during object creation, after setting all properties.
function ccaltext_CreateFcn(hObject, eventdata, handles)
% hObject    handle to ccaltext (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in ccaldarkcal.
function ccaldarkcal_Callback(hObject, eventdata, handles)
% hObject    handle to ccaldarkcal (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
ColorCal2('ZeroCalibration');
helpdlg('Dark Calibration Done!')


% --- Executes on button press in ccalledoff.
function ccalledoff_Callback(hObject, eventdata, handles)
% hObject    handle to ccalledoff (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of ccalledoff
if get(hObject,'Value') == 1
	ColorCal2('LEDOff');
else
	ColorCal2('LEDOn');
end

% --- Executes on button press in ccalledon.
function ccalledon_Callback(hObject, eventdata, handles)
% hObject    handle to ccalledon (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of ccalledon
if get(hObject,'Value') == 1
	ColorCal2('LEDOn');
else
	ColorCal2('LEDOff');
end

% --- Executes on button press in ccalinfo.
function ccalinfo_Callback(hObject, eventdata, handles)
% hObject    handle to ccalinfo (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
cc=ColorCal2('GetRawData');
vals=zeros(4,4);
vals(1,1)=cc.Xdata;
vals(1,2)=cc.Xzero;
vals(2,1)=cc.Ydata;
vals(2,2)=cc.Yzero;
vals(3,1)=cc.Zdata;
vals(3,2)=cc.Zzero;
vals(4,1)=cc.Trigger;

set(gh('ccaltriggerlevel'),'String',num2str(cc.Trigger));

cMatrix = ColorCal2('ReadColorMatrix');
s = ColorCal2('MeasureXYZ');
correctedValues = cMatrix(1:3,:) * [s.x s.y s.z]';
X = correctedValues(1);
Y = correctedValues(2);
Z = correctedValues(3);
vals(1:3,3)=correctedValues;
vals(1,4) = X / (X + Y + Z);
vals(2,4) = Y / (X + Y + Z);
vals(3,4) = Y;

set(handles.ccaltable,'Data',vals);

function ccaltriggerlevel_Callback(hObject, eventdata, handles)
% hObject    handle to ccaltriggerlevel (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of ccaltriggerlevel as text
%        str2double(get(hObject,'String')) returns contents of ccaltriggerlevel as a double
ColorCal2('SetTriggerThreshold',str2num(get(hObject,'String')));

% --- Executes during object creation, after setting all properties.
function ccaltriggerlevel_CreateFcn(hObject, eventdata, handles)
% hObject    handle to ccaltriggerlevel (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in ccalmeasurenow.
function ccalmeasurenow_Callback(hObject, eventdata, handles)
% hObject    handle to ccalmeasurenow (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
%cc=ColorCal2('GetRawData');
persistent cMatrix
vals=zeros(4,4);
vals(1,1)=0;%cc.Xdata;
vals(1,2)=0;%cc.Xzero;
vals(2,1)=0;%cc.Ydata;
vals(2,2)=0;%cc.Yzero;
vals(3,1)=0;%cc.Zdata;
vals(3,2)=0;%cc.Zzero;
vals(4,1)=0;%cc.Trigger;

%set(gh('ccaltriggerlevel'),'String',num2str(cc.Trigger));

if ~exist('cMatrix','var') || isempty(cMatrix)
	cMatrix = ColorCal2('ReadColorMatrix');
end
s = ColorCal2('MeasureXYZ');
correctedValues = cMatrix(1:3,:) * [s.x s.y s.z]';
X = correctedValues(1);
Y = correctedValues(2);
Z = correctedValues(3);
vals(1:3,3)=correctedValues;
vals(1,4) = X / (X + Y + Z);
vals(2,4) = Y / (X + Y + Z);
vals(3,4) = Y;

set(handles.ccaltable,'Data',vals);

% --- Executes on button press in ccalledtrigger.
function ccalledtrigger_Callback(hObject, eventdata, handles)
% hObject    handle to ccalledtrigger (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of ccalledtrigger
ColorCal2('SetLEDFunction',get(hObject,'Value'));


% --- Executes on button press in ccalplot.
function ccalplot_Callback(hObject, eventdata, handles)
% hObject    handle to ccalplot (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
persistent cMatrix
persistent ccalHandle
global ccalBreak
ccalBreak = false;
ccalHandle = [];
maxScreen=max(Screen('Screens'));
backgroundColour = [0 0 0];
if get(handles.ccalDisplay,'Value') == 1
	showStimulus = true;
else
	showStimulus = false;
end

if ~exist('cMatrix','var') || isempty(cMatrix)
	cMatrix = ColorCal2('ReadColorMatrix');
end
if ~exist('ccalHandle','var') || isempty(ccalHandle)
	figure;
	ccalHandle = gca;
	hold on
	plot3(0,0,0,'o','MarkerFaceColor',[0 0 0],'MarkerEdgeColor',[0 0 0]);
	plot3(0.2980,0.5323,3.57,'o','MarkerFaceColor',[0 1 0],'MarkerEdgeColor',[0 0 0]);
	plot3(0.2787,0.5470,21.15,'o','MarkerFaceColor',[0 1 0],'MarkerEdgeColor',[1 0 0]);
	plot3(0.2771,0.5471,38.4748,'o','MarkerFaceColor',[0 1 0],'MarkerEdgeColor',[1 0 1]);
	xlabel('x')
	ylabel('y')
	zlabel('luminance')
	view(45,45)
	hold off
end

try
	if showStimulus == true
		rchar='';
		FlushEvents;
		ListenChar(2);
		Screen('Preference', 'SkipSyncTests', 2);
		Screen('Preference', 'VisualDebugLevel', 0);
		Screen('Preference', 'Verbosity', 2);
		Screen('Preference', 'SuppressAllWarnings', 0);
		PsychImaging('PrepareConfiguration');
		PsychImaging('AddTask', 'General', 'FloatingPoint32BitIfPossible');
		PsychImaging('AddTask', 'General', 'NormalizedHighresColorRange');
		[obj.win, obj.winRect] = PsychImaging('OpenWindow', maxScreen, backgroundColour);
	end

	while ccalBreak == false
		s = ColorCal2('MeasureXYZ');
		correctedValues = cMatrix(1:3,:) * [s.x s.y s.z]';
		X = correctedValues(1);
		Y = correctedValues(2);
		Z = correctedValues(3);
		x = X / (X + Y + Z);
		y = Y / (X + Y + Z);
		rgb = XYZToSRGBPrimary([X Y Z]');
		fprintf('R: %g\tG: %g\tB: %g --> ',rgb(1),rgb(2),rgb(3))
		rgb = rgb ./ 256;
		rgb(rgb<0) = 0;
		fprintf('R: %g\tG: %g\tB: %g\n',rgb(1),rgb(2),rgb(3))
		rgb(rgb>1)=1;
		axes(ccalHandle);
		hold on
		plot3(x,y,Y,'o','MarkerFaceColor',rgb,'MarkerEdgeColor',rgb);
		hold off
		axis tight
		drawnow;
		
		if showStimulus == true
			%draw background
			Screen('FillRect',obj.win,backgroundColour,[]);
			Screen('Flip', obj.win);

			[keyIsDown, ~, keyCode] = KbCheck;
			if keyIsDown == 1
				obj.rchar = KbName(keyCode);
				if iscell(obj.rchar);obj.rchar=obj.rchar{1};end
				switch obj.rchar
					case ',<'
						if max(backgroundColour)>0.1
							backgroundColour = backgroundColour .* 0.9;
							backgroundColour(backgroundColour<0) = 0;
						end
					case '.>'
						backgroundColour = backgroundColour .* 1.1;
						backgroundColour(backgroundColour>1) = 1;
					case 'r'
						backgroundColour(1) = backgroundColour(1) + 0.05;
						if backgroundColour(1) > 1
							backgroundColour(1) = 1;
						end
						disp(backgroundColour);
					case 'g'
						backgroundColour(2) = backgroundColour(2) + 0.05;
						if backgroundColour(2) > 1
							backgroundColour(2) = 1;
						end
						disp(backgroundColour);
					case 'b'
						backgroundColour(3) = backgroundColour(3) + 0.05;
						if backgroundColour(3) > 1
							backgroundColour(3) = 1;
						end
						disp(backgroundColour);
					case 'e'
						backgroundColour(1) = backgroundColour(1) - 0.05;
						if backgroundColour(1) < 0.02
							backgroundColour(1) = 0;
						end
						disp(backgroundColour);
					case 'f'
						backgroundColour(2) = backgroundColour(2) - 0.05;
						if backgroundColour(2) < 0.02
							backgroundColour(2) = 0;
						end
						disp(backgroundColour);
					case 'v'
						backgroundColour(3) = backgroundColour(3) - 0.05;
						if backgroundColour(3) < 0.02
							backgroundColour(3) = 0;
						end
						disp(backgroundColour);
				end
			end
		end	
	end
	if showStimulus == true
		ListenChar(0);
		ShowCursor;
		Screen('CloseAll');
	end
catch ME
	if showStimulus == true
		ListenChar(0)
		ShowCursor;
		Screen('CloseAll');
	end
	psychrethrow(psychlasterror);
	rethrow ME
end


% --- Executes on button press in ccalStop.
function ccalStop_Callback(hObject, eventdata, handles)
% hObject    handle to ccalStop (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global ccalBreak
ccalBreak = true


% --- Executes on button press in ccalDisplay.
function ccalDisplay_Callback(hObject, eventdata, handles)
% hObject    handle to ccalDisplay (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of ccalDisplay
