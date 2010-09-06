function varargout = opticka_ui(varargin)
% OPTICKA_UI M-file for opticka_ui.fig
%      OPTICKA_UI, by itself, creates a new OPTICKA_UI or raises the existing
%      singleton*.
%
%      H = OPTICKA_UI returns the handle to a new OPTICKA_UI or the handle to
%      the existing singleton*.
%
%      OPTICKA_UI('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in OPTICKA_UI.M with the given input arguments.
%
%      OPTICKA_UI('Property','Value',...) creates a new OPTICKA_UI or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before opticka_ui_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to opticka_ui_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help opticka_ui

% Last Modified by GUIDE v2.5 05-Sep-2010 20:14:47

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
	'gui_Singleton',  gui_Singleton, ...
	'gui_OpeningFcn', @opticka_ui_OpeningFcn, ...
	'gui_OutputFcn',  @opticka_ui_OutputFcn, ...
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


% --- Executes just before opticka_ui is made visible.
function opticka_ui_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to opticka_ui (see VARARGIN)

% Choose default command line output for opticka_ui
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes opticka_ui wait for user response (see UIRESUME)
% uiwait(handles.optika_uifig);


% --- Outputs from this function are returned to the command line.
function varargout = opticka_ui_OutputFcn(hObject, eventdata, handles)
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;



% --- Executes on button press in OKInitializeButton.
function OKInitializeButton_Callback(hObject, eventdata, handles)
% hObject    handle to OKInitializeButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --------------------------------------------------------------------
function OKMenuFile_Callback(hObject, eventdata, handles)
% hObject    handle to OKMenuFile (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --------------------------------------------------------------------
function OKMenuEdit_Callback(hObject, eventdata, handles)
% hObject    handle to OKMenuEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --------------------------------------------------------------------
function OKMenuTools_Callback(hObject, eventdata, handles)
% hObject    handle to OKMenuTools (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% --------------------------------------------------------------------
function OKMenuNewProtocol_Callback(hObject, eventdata, handles)
% hObject    handle to OKMenuNewProtocol (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --------------------------------------------------------------------
function OKMenuOpen_Callback(hObject, eventdata, handles)
% hObject    handle to OKMenuOpen (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --------------------------------------------------------------------
function OKMenuSave_Callback(hObject, eventdata, handles)
% hObject    handle to OKMenuSave (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --------------------------------------------------------------------
function OKMenuQuit_Callback(hObject, eventdata, handles)
% hObject    handle to OKMenuQuit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
close(gcf);

% --- Executes on selection change in OKStimList.
function OKStimList_Callback(hObject, eventdata, handles)
% hObject    handle to OKStimList (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = get(hObject,'String') returns OKStimList contents as cell array
%        contents{get(hObject,'Value')} returns selected item from
%        OKStimList


function OKMonitorDistance_Callback(hObject, eventdata, handles)
% hObject    handle to OKMonitorDistance (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKMonitorDistance as text
%        str2double(get(hObject,'String')) returns contents of OKMonitorDistance as a double



function OKPixelsPerCm_Callback(hObject, eventdata, handles)
% hObject    handle to OKPixelsPerCm (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKPixelsPerCm as text
%        str2double(get(hObject,'String')) returns contents of OKPixelsPerCm as a double



function OKXCenter_Callback(hObject, eventdata, handles)
% hObject    handle to OKXCenter (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKXCenter as text
%        str2double(get(hObject,'String')) returns contents of OKXCenter as a double


function OKYCenter_Callback(hObject, eventdata, handles)
% hObject    handle to OKYCenter (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKYCenter as text
%        str2double(get(hObject,'String')) returns contents of OKYCenter as a double


function OKBackgroundColour_Callback(hObject, eventdata, handles)
% hObject    handle to OKBackgroundColour (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKBackgroundColour as text
%        str2double(get(hObject,'String')) returns contents of OKBackgroundColour as a double



function OKTrialNumber_Callback(hObject, eventdata, handles)
% hObject    handle to OKTrialNumber (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKTrialNumber as text
%        str2double(get(hObject,'String')) returns contents of OKTrialNumber as a double




function OKInterStimulusTime_Callback(hObject, eventdata, handles)
% hObject    handle to OKInterStimulusTime (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKInterStimulusTime as text
%        str2double(get(hObject,'String')) returns contents of OKInterStimulusTime as a double


% --------------------------------------------------------------------
function OKMenuNoiseTexture_Callback(hObject, eventdata, handles)
% hObject    handle to OKMenuNoiseTexture (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
set(handles.OKPanelDots,'Visible','off')
set(handles.OKPanelGrating,'Visible','off')
set(handles.OKPanelNoise,'Visible','on')

% --------------------------------------------------------------------
function OKMenuLineTexture_Callback(hObject, eventdata, handles)
% hObject    handle to OKMenuLineTexture (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on selection change in OKVarList.
function OKVarList_Callback(hObject, eventdata, handles)
% hObject    handle to OKVarList (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = get(hObject,'String') returns OKVarList contents as cell array
%        contents{get(hObject,'Value')} returns selected item from OKVarList


% --- Executes on button press in OKTestButton.
function OKTestButton_Callback(hObject, eventdata, handles)
% hObject    handle to OKTestButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in OKOpenGLBlending.
function OKOpenGLBlending_Callback(hObject, eventdata, handles)
% hObject    handle to OKOpenGLBlending (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of OKOpenGLBlending


% --- Executes on button press in OKHideFlash.
function OKHideFlash_Callback(hObject, eventdata, handles)
% hObject    handle to OKHideFlash (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of OKHideFlash


% --- Executes on button press in OKDebug.
function OKDebug_Callback(hObject, eventdata, handles)
% hObject    handle to OKDebug (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of OKDebug

% --------------------------------------------------------------------
function OKMenuPlaid_Callback(hObject, eventdata, handles)
% hObject    handle to OKMenuPlaid (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
set(handles.OKPanelDots,'Visible','off')
%set(handles.OKPanelNoise,'Visible','off')
set(handles.OKPanelGrating,'Visible','off')
set(handles.OKPanelBar,'Visible','off')
%set(handles.OKPanelPlaid,'Visible','on')

% --------------------------------------------------------------------
function OKMenuDots_Callback(hObject, eventdata, handles)
% hObject    handle to OKMenuSpot (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
%set(handles.OKPanelNoise,'Visible','off')
set(handles.OKPanelGrating,'Visible','off')
set(handles.OKPanelBar,'Visible','off')
%set(handles.OKPanelPlaid,'Visible','off')
set(handles.OKPanelDots,'Visible','on')
% --------------------------------------------------------------------
function OKMenuBar_Callback(hObject, eventdata, handles)
% hObject    handle to OKMenuBar (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
set(handles.OKPanelGrating,'Visible','off')
set(handles.OKPanelBar,'Visible','on')
set(handles.OKPanelDots,'Visible','off')
%set(handles.OKPanelPlaid,'Visible','off')
%set(handles.OKPanelNoise,'Visible','on')

% --------------------------------------------------------------------
function OKMenuGrating_Callback(hObject, eventdata, handles)
% hObject    handle to OKMenuGrating (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
set(handles.OKPanelDots,'Visible','off')
%set(handles.OKPanelNoise,'Visible','off')
set(handles.OKPanelBar,'Visible','off')
%set(handles.OKPanelPlaid,'Visible','off')
set(handles.OKPanelGrating,'Visible','on')


function OKPanelGratingX_Callback(hObject, eventdata, handles)
% hObject    handle to OKPanelGratingX (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKPanelGratingX as text
%        str2double(get(hObject,'String')) returns contents of OKPanelGratingX as a double




function OKPanelGratingY_Callback(hObject, eventdata, handles)
% hObject    handle to OKPanelGratingY (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKPanelGratingY as text
%        str2double(get(hObject,'String')) returns contents of OKPanelGratingY as a double


function OKPanelGratingTF_Callback(hObject, eventdata, handles)
% hObject    handle to OKPanelGratingTF (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKPanelGratingTF as text
%        str2double(get(hObject,'String')) returns contents of OKPanelGratingTF as a double



% --- Executes on button press in OKPanelGratingGaussian.
function OKPanelGratingGaussian_Callback(hObject, eventdata, handles)
% hObject    handle to OKPanelGratingGaussian (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of OKPanelGratingGaussian



function OKPanelGratingSize_Callback(hObject, eventdata, handles)
% hObject    handle to OKPanelGratingSize (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKPanelGratingSize as text
%        str2double(get(hObject,'String')) returns contents of OKPanelGratingSize as a double



function OKPanelGratingSF_Callback(hObject, eventdata, handles)
% hObject    handle to OKPanelGratingSF (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKPanelGratingSF as text
%        str2double(get(hObject,'String')) returns contents of OKPanelGratingSF as a double



function OKPanelGratingContrast_Callback(hObject, eventdata, handles)
% hObject    handle to OKPanelGratingContrast (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKPanelGratingContrast as text
%        str2double(get(hObject,'String')) returns contents of OKPanelGratingContrast as a double



function OKPanelGratingTime_Callback(hObject, eventdata, handles)
% hObject    handle to OKPanelGratingTime (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKPanelGratingTime as text
%        str2double(get(hObject,'String')) returns contents of OKPanelGratingTime as a double


function OKWindowSize_Callback(hObject, eventdata, handles)


function OKPanelBarContrast_Callback(hObject, eventdata, handles)



function OKPanelBarWidth_Callback(hObject, eventdata, handles)



function OKPanelBarLength_Callback(hObject, eventdata, handles)



function OKPanelBarYPos_Callback(hObject, eventdata, handles)



function OKPanelBarXPos_Callback(hObject, eventdata, handles)


function OKMenuPreferences_Callback(hObject, eventdata, handles)


function OKPanelGratingType_Callback(hObject, eventdata, handles)


function OKRandomise_Callback(hObject, eventdata, handles)


function OKProtocolsList_Callback(hObject, eventdata, handles)


function pushbutton22_Callback(hObject, eventdata, handles)


function OKHistoryList_Callback(hObject, eventdata, handles)


function OKPanelGratingMask_Callback(hObject, eventdata, handles)



% --- Executes on selection change in OKGLSrc.
function OKGLSrc_Callback(hObject, eventdata, handles)
% hObject    handle to OKGLSrc (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns OKGLSrc contents as cell array


% --- Executes on selection change in OKGLDst.
function OKGLDst_Callback(hObject, eventdata, handles)
% hObject    handle to OKGLDst (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns OKGLDst contents as cell array
%        contents{get(hObject,'Value')} returns selected item from OKGLDst


function OKMultiSampling_Callback(hObject, eventdata, handles)
% hObject    handle to OKMultiSampling (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKMultiSampling as text
%        str2double(get(hObject,'String')) returns contents of OKMultiSampling as a double


function OKSerialPortName_Callback(hObject, eventdata, handles)
% hObject    handle to OKSerialPortName (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKSerialPortName as text
%        str2double(get(hObject,'String')) returns contents of OKSerialPortName as a double


% --- Executes on button press in OKUsePhotoDiode.
function OKUsePhotoDiode_Callback(hObject, eventdata, handles)
% hObject    handle to OKUsePhotoDiode (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of OKUsePhotoDiode


% --- Executes on button press in OKUseLabJack.
function OKUseLabJack_Callback(hObject, eventdata, handles)
% hObject    handle to OKUseLabJack (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of OKUseLabJack


% --- Executes on button press in OKVerbose.
function OKVerbose_Callback(hObject, eventdata, handles)
% hObject    handle to OKVerbose (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of OKVerbose


% --- Executes on button press in OKProtocolLoad.
function OKProtocolLoad_Callback(hObject, eventdata, handles)
% hObject    handle to OKProtocolLoad (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in OKProtocolSave.
function OKProtocolSave_Callback(hObject, eventdata, handles)
% hObject    handle to OKProtocolSave (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in OKProtocolDuplicate.
function OKProtocolDuplicate_Callback(hObject, eventdata, handles)
% hObject    handle to OKProtocolDuplicate (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in OKProtocolDelete.
function OKProtocolDelete_Callback(hObject, eventdata, handles)
% hObject    handle to OKProtocolDelete (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)



% --------------------------------------------------------------------
function OKMenuCalibrateLuminance_Callback(hObject, eventdata, handles)
% hObject    handle to OKMenuCalibrateLuminance (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --------------------------------------------------------------------
function OKMenuCalibrateSize_Callback(hObject, eventdata, handles)
% hObject    handle to OKMenuCalibrateSize (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


function OKInterTrialTime_Callback(hObject, eventdata, handles)
% hObject    handle to OKInterTrialTime (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKInterTrialTime as text
%        str2double(get(hObject,'String')) returns contents of OKInterTrialTime as a double

% --- Executes on selection change in OKRandomAlgorithm.
function OKRandomAlgorithm_Callback(hObject, eventdata, handles)
% hObject    handle to OKRandomAlgorithm (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns OKRandomAlgorithm contents as cell array
%        contents{get(hObject,'Value')} returns selected item from OKRandomAlgorithm

function OKRandomSeed_Callback(hObject, eventdata, handles)
% hObject    handle to OKRandomSeed (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKRandomSeed as text
%        str2double(get(hObject,'String')) returns contents of OKRandomSeed as a double

function OKTrialTime_Callback(hObject, eventdata, handles)
% hObject    handle to OKTrialTime (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKTrialTime as text
%        str2double(get(hObject,'String')) returns contents of OKTrialTime as a double


function edit86_Callback(hObject, eventdata, handles)
% hObject    handle to edit86 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit86 as text
%        str2double(get(hObject,'String')) returns contents of edit86 as a double



function OKPanelGratingColour_Callback(hObject, eventdata, handles)
% hObject    handle to OKPanelGratingColour (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKPanelGratingColour as text
%        str2double(get(hObject,'String')) returns contents of OKPanelGratingColour as a double

function OKPanelGratingAlpha_Callback(hObject, eventdata, handles)
% hObject    handle to OKPanelGratingAlpha (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKPanelGratingAlpha as text
%        str2double(get(hObject,'String')) returns contents of OKPanelGratingAlpha as a double


% --- Executes on selection change in popupmenu8.
function popupmenu8_Callback(hObject, eventdata, handles)
% hObject    handle to popupmenu8 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns popupmenu8 contents as cell array
%        contents{get(hObject,'Value')} returns selected item from popupmenu8


function OKPanelBarColour_Callback(hObject, eventdata, handles)
% hObject    handle to OKPanelBarColour (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKPanelBarColour as text
%        str2double(get(hObject,'String')) returns contents of OKPanelBarColour as a double


function OKPanelBarAlpha_Callback(hObject, eventdata, handles)
% hObject    handle to OKPanelBarAlpha (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKPanelBarAlpha as text
%        str2double(get(hObject,'String')) returns contents of OKPanelBarAlpha as a double



function OKPanelBarAngle_Callback(hObject, eventdata, handles)
% hObject    handle to OKPanelBarAngle (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKPanelBarAngle as text
%        str2double(get(hObject,'String')) returns contents of OKPanelBarAngle as a double


function OKPanelBarStartPosition_Callback(hObject, eventdata, handles)
% hObject    handle to OKPanelBarStartPosition (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKPanelBarStartPosition as text
%        str2double(get(hObject,'String')) returns contents of OKPanelBarStartPosition as a double


function OKPanelBarSpeed_Callback(hObject, eventdata, handles)
% hObject    handle to OKPanelBarSpeed (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKPanelBarSpeed as text
%        str2double(get(hObject,'String')) returns contents of OKPanelBarSpeed as a double



function edit104_Callback(hObject, eventdata, handles)
% hObject    handle to edit104 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit104 as text
%        str2double(get(hObject,'String')) returns contents of edit104 as a double



function OKPanelDostDotSize_Callback(hObject, eventdata, handles)
% hObject    handle to OKPanelDostDotSize (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKPanelDostDotSize as text
%        str2double(get(hObject,'String')) returns contents of OKPanelDostDotSize as a double


function OKPanelDotSize_Callback(hObject, eventdata, handles)
% hObject    handle to OKPanelDotSize (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKPanelDotSize as text
%        str2double(get(hObject,'String')) returns contents of OKPanelDotSize as a double



function OKPanelDotsYPos_Callback(hObject, eventdata, handles)
% hObject    handle to OKPanelDotsYPos (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKPanelDotsYPos as text
%        str2double(get(hObject,'String')) returns contents of OKPanelDotsYPos as a double


function OKPanelDotsXPos_Callback(hObject, eventdata, handles)
% hObject    handle to OKPanelDotsXPos (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKPanelDotsXPos as text
%        str2double(get(hObject,'String')) returns contents of OKPanelDotsXPos as a double


% --- Executes on selection change in OKPanelDotsType.
function OKPanelDotsType_Callback(hObject, eventdata, handles)
% hObject    handle to OKPanelDotsType (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns OKPanelDotsType contents as cell array
%        contents{get(hObject,'Value')} returns selected item from OKPanelDotsType


function OKPanelDotsColour_Callback(hObject, eventdata, handles)
% hObject    handle to OKPanelDotsColour (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKPanelDotsColour as text
%        str2double(get(hObject,'String')) returns contents of OKPanelDotsColour as a double



function OKPanelDotsAlpha_Callback(hObject, eventdata, handles)
% hObject    handle to OKPanelDotsAlpha (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKPanelDotsAlpha as text
%        str2double(get(hObject,'String')) returns contents of OKPanelDotsAlpha as a double


function OKPanelDotsAngle_Callback(hObject, eventdata, handles)
% hObject    handle to OKPanelDotsAngle (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKPanelDotsAngle as text
%        str2double(get(hObject,'String')) returns contents of OKPanelDotsAngle as a double


% --- Executes on button press in OKPanelGratingRotationMethod.
function OKPanelGratingRotationMethod_Callback(hObject, eventdata, handles)
% hObject    handle to OKPanelGratingRotationMethod (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of
% OKPanelGratingRotationMethod


% --- Executes on button press in OKHistoryUp.
function OKHistoryUp_Callback(hObject, eventdata, handles)
% hObject    handle to OKHistoryUp (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in OKHistoryDown.
function OKHistoryDown_Callback(hObject, eventdata, handles)
% hObject    handle to OKHistoryDown (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in OKHistoryDelete.
function OKHistoryDelete_Callback(hObject, eventdata, handles)
% hObject    handle to OKHistoryDelete (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on selection change in OKVariableList.
function OKVariableList_Callback(hObject, eventdata, handles)
% hObject    handle to OKVariableList (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns OKVariableList contents as cell array
%        contents{get(hObject,'Value')} returns selected item from OKVariableList


function OKVariableStimuli_Callback(hObject, eventdata, handles)
% hObject    handle to OKVariableStimuli (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKVariableStimuli as text
%        str2double(get(hObject,'String')) returns contents of OKVariableStimuli as a double


function OKVariableValues_Callback(hObject, eventdata, handles)
% hObject    handle to OKVariableValues (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKVariableValues as text
%        str2double(get(hObject,'String')) returns contents of OKVariableValues as a double



function OKVariableName_Callback(hObject, eventdata, handles)
% hObject    handle to OKVariableName (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKVariableName as text
%        str2double(get(hObject,'String')) returns contents of OKVariableName as a double


% --- Executes on button press in OKCopyVariable.
function OKCopyVariable_Callback(hObject, eventdata, handles)
% hObject    handle to OKCopyVariable (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

function OKTrialTime_CreateFcn(hObject, eventdata, handles)
function OKRandomSeed_CreateFcn(hObject, eventdata, handles)
function OKRandomAlgorithm_CreateFcn(hObject, eventdata, handles)
function OKInterTrialTime_CreateFcn(hObject, eventdata, handles)
function OKSerialPortName_CreateFcn(hObject, eventdata, handles)
function OKMultiSampling_CreateFcn(hObject, eventdata, handles)
function OKGLDst_CreateFcn(hObject, eventdata, handles)
function OKGLSrc_CreateFcn(hObject, eventdata, handles)
function popupmenu1_CreateFcn(hObject, eventdata, handles)
function OKWindowSize_CreateFcn(hObject, eventdata, handles)
function OKInterStimulusTime_CreateFcn(hObject, eventdata, handles)
function OKTrialNumber_CreateFcn(hObject, eventdata, handles)
function OKBackgroundColour_CreateFcn(hObject, eventdata, handles)
function OKYCenter_CreateFcn(hObject, eventdata, handles)
function OKXCenter_CreateFcn(hObject, eventdata, handles)
function OKPixelsPerCm_CreateFcn(hObject, eventdata, handles)
function OKMonitorDistance_CreateFcn(hObject, eventdata, handles)
function OKVariableName_CreateFcn(hObject, eventdata, handles)
function OKVariableValues_CreateFcn(hObject, eventdata, handles)
function OKVariableStimuli_CreateFcn(hObject, eventdata, handles)
function OKVariableList_CreateFcn(hObject, eventdata, handles)
function OKPanelBarSpeed_CreateFcn(hObject, eventdata, handles)
function OKPanelBarStartPosition_CreateFcn(hObject, eventdata, handles)
function OKPanelBarAngle_CreateFcn(hObject, eventdata, handles)
function OKPanelBarAlpha_CreateFcn(hObject, eventdata, handles)
function OKPanelBarColour_CreateFcn(hObject, eventdata, handles)
function popupmenu8_CreateFcn(hObject, eventdata, handles)
function OKPanelBarXPos_CreateFcn(hObject, eventdata, handles)
function OKPanelBarYPos_CreateFcn(hObject, eventdata, handles)
function OKPanelBarLength_CreateFcn(hObject, eventdata, handles)
function OKPanelBarWidth_CreateFcn(hObject, eventdata, handles)
function OKPanelBarContrast_CreateFcn(hObject, eventdata, handles)
function OKPanelGratingSize_CreateFcn(hObject, eventdata, handles)
function OKPanelGratingAlpha_CreateFcn(hObject, eventdata, handles)
function OKPanelGratingColour_CreateFcn(hObject, eventdata, handles)
function edit86_CreateFcn(hObject, eventdata, handles)
function OKPanelGratingType_CreateFcn(hObject, eventdata, handles)
function edit77_CreateFcn(hObject, eventdata, handles)
function OKPanelGratingTime_CreateFcn(hObject, eventdata, handles)
function OKPanelGratingContrast_CreateFcn(hObject, eventdata, handles)
function OKPanelGratingSF_CreateFcn(hObject, eventdata, handles)
function OKPanelGratingY_CreateFcn(hObject, eventdata, handles)
function OKPanelGratingX_CreateFcn(hObject, eventdata, handles)
function edit113_CreateFcn(hObject, eventdata, handles)
function edit112_CreateFcn(hObject, eventdata, handles)
function OKPanelDotsAngle_CreateFcn(hObject, eventdata, handles)
function OKPanelDotsAlpha_CreateFcn(hObject, eventdata, handles)
function OKPanelDotsColour_CreateFcn(hObject, eventdata, handles)
function OKPanelDotsType_CreateFcn(hObject, eventdata, handles)
function OKPanelDotsXPos_CreateFcn(hObject, eventdata, handles)
function OKPanelDotsYPos_CreateFcn(hObject, eventdata, handles)
function OKPanelDotSize_CreateFcn(hObject, eventdata, handles)
function OKPanelDostDotSize_CreateFcn(hObject, eventdata, handles)
function edit104_CreateFcn(hObject, eventdata, handles)
function OKVarList_CreateFcn(hObject, eventdata, handles)
function OKStimList_CreateFcn(hObject, eventdata, handles)
function OKTitleText_CreateFcn(hObject, eventdata, handles)
function OKHistoryList_CreateFcn(hObject, eventdata, handles)
function OKProtocolsList_CreateFcn(hObject, eventdata, handles)



function OKPanelGratingAspectRatio_Callback(hObject, eventdata, handles)
% hObject    handle to OKPanelGratingAspectRatio (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKPanelGratingAspectRatio as text
%        str2double(get(hObject,'String')) returns contents of OKPanelGratingAspectRatio as a double


% --- Executes during object creation, after setting all properties.
function OKPanelGratingAspectRatio_CreateFcn(hObject, eventdata, handles)
% hObject    handle to OKPanelGratingAspectRatio (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called



function edit118_Callback(hObject, eventdata, handles)
% hObject    handle to edit118 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit118 as text
%        str2double(get(hObject,'String')) returns contents of edit118 as a double


% --- Executes during object creation, after setting all properties.
function edit118_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit118 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called



% --------------------------------------------------------------------
function OKMenuSpot_Callback(hObject, eventdata, handles)
% hObject    handle to OKMenuSpot (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --------------------------------------------------------------------
function OKToolbarToggleGlobal_OnCallback(hObject, eventdata, handles)
% hObject    handle to OKToolbarToggleGlobal (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
set(handles.OKPanelProtocols,'Visible','off')
set(handles.OKPanelGlobal,'Visible','on')


% --------------------------------------------------------------------
function OKToolbarToggleGlobal_OffCallback(hObject, eventdata, handles)
% hObject    handle to OKToolbarToggleGlobal (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
set(handles.OKPanelProtocols,'Visible','on')
set(handles.OKPanelGlobal,'Visible','off')
