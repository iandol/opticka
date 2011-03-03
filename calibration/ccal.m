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

% Last Modified by GUIDE v2.5 09-Jul-2009 20:47:44

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
vals=zeros(4,4);
vals(1,1)=0;%cc.Xdata;
vals(1,2)=0;%cc.Xzero;
vals(2,1)=0;%cc.Ydata;
vals(2,2)=0;%cc.Yzero;
vals(3,1)=0;%cc.Zdata;
vals(3,2)=0;%cc.Zzero;
vals(4,1)=0;%cc.Trigger;

%set(gh('ccaltriggerlevel'),'String',num2str(cc.Trigger));

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

% --- Executes on button press in ccalledtrigger.
function ccalledtrigger_Callback(hObject, eventdata, handles)
% hObject    handle to ccalledtrigger (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of ccalledtrigger
ColorCal2('SetLEDFunction',get(hObject,'Value'));
