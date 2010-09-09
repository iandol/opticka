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

% Last Modified by GUIDE v2.5 09-Sep-2010 06:43:14

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
if isappdata(0,'o')
	rmappdata(0,'o');
	clear o;
end
close(gcf);

% --- Executes on selection change in OKStimList.
function OKStimList_Callback(hObject, eventdata, handles)
% hObject    handle to OKStimList (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = get(hObject,'String') returns OKStimList contents as cell array
%        contents{get(hObject,'Value')} returns selected item from
%        OKStimList

% --- Executes on selection change in OKSelectScreen.
function OKSelectScreen_Callback(hObject, eventdata, handles)
if isappdata(0,'o')
	o = getappdata(0,'o');
	o.getScreenVals;
end


function OKMonitorDistance_Callback(hObject, eventdata, handles)
if isappdata(0,'o')
	o = getappdata(0,'o');
	o.getScreenVals;
end


function OKPixelsPerCm_Callback(hObject, eventdata, handles)
if isappdata(0,'o')
	o = getappdata(0,'o');
	o.getScreenVals;
end


function OKXCenter_Callback(hObject, eventdata, handles)
if isappdata(0,'o')
	o = getappdata(0,'o');
	o.getScreenVals;
end

function OKYCenter_Callback(hObject, eventdata, handles)
if isappdata(0,'o')
	o = getappdata(0,'o');
	o.getScreenVals;
end

function OKWindowSize_Callback(hObject, eventdata, handles)
if isappdata(0,'o')
	o = getappdata(0,'o');
	o.getScreenVals;
end

function OKGLSrc_Callback(hObject, eventdata, handles)
if isappdata(0,'o')
	o = getappdata(0,'o');
	o.getScreenVals;
end


function OKGLDst_Callback(hObject, eventdata, handles)
if isappdata(0,'o')
	o = getappdata(0,'o');
	o.getScreenVals;
end

function OKMultiSampling_Callback(hObject, eventdata, handles)
if isappdata(0,'o')
	o = getappdata(0,'o');
	o.getScreenVals;
end

function OKSerialPortName_Callback(hObject, eventdata, handles)
if isappdata(0,'o')
	o = getappdata(0,'o');
	o.getScreenVals;
end

% --- Executes on button press in OKUsePhotoDiode.
function OKUsePhotoDiode_Callback(hObject, eventdata, handles)
if isappdata(0,'o')
	o = getappdata(0,'o');
	o.getScreenVals;
end

% --- Executes on button press in OKUseLabJack.
function OKUseLabJack_Callback(hObject, eventdata, handles)
if isappdata(0,'o')
	o = getappdata(0,'o');
	o.getScreenVals;
end

% --- Executes on button press in OKVerbose.
function OKVerbose_Callback(hObject, eventdata, handles)
if isappdata(0,'o')
	o = getappdata(0,'o');
	o.getScreenVals;
end

% --- Executes on button press in OKOpenGLBlending.
function OKOpenGLBlending_Callback(hObject, eventdata, handles)
if isappdata(0,'o')
	o = getappdata(0,'o');
	o.getScreenVals;
end

% --- Executes on button press in OKHideFlash.
function OKHideFlash_Callback(hObject, eventdata, handles)
if isappdata(0,'o')
	o = getappdata(0,'o');
	o.getScreenVals;
end

% --- Executes on button press in OKDebug.
function OKDebug_Callback(hObject, eventdata, handles)
if isappdata(0,'o')
	o = getappdata(0,'o');
	o.getScreenVals;
end

function OKbackgroundColour_Callback(hObject, eventdata, handles)
if isappdata(0,'o')
	o = getappdata(0,'o');
	o.getScreenVals;
end

function OKnTrials_Callback(hObject, eventdata, handles)
if isappdata(0,'o')
	o = getappdata(0,'o');
	o.getTaskVals;
end


function OKisTime_Callback(hObject, eventdata, handles)
if isappdata(0,'o')
	o = getappdata(0,'o');
	o.getTaskVals;
end

function OKtrialTime_Callback(hObject, eventdata, handles)
if isappdata(0,'o')
	o = getappdata(0,'o');
	o.getTaskVals;
end

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
%        contents{get(hObject,'Value')} returns selected item from
%        OKVarList

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
if isappdata(0,'o')
	o = getappdata(0,'o');
	o.store.visibleStimulus='dots';
end

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
if isappdata(0,'o')
	o = getappdata(0,'o');
	o.store.visibleStimulus='bar';
end

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
if isappdata(0,'o')
	o = getappdata(0,'o');
	o.store.visibleStimulus='grating';
end


function OKPanelGratingxPosition_Callback(hObject, eventdata, handles)
% hObject    handle to OKPanelGratingxPosition (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKPanelGratingxPosition as text
%        str2double(get(hObject,'String')) returns contents of OKPanelGratingxPosition as a double




function OKPanelGratingyPosition_Callback(hObject, eventdata, handles)
% hObject    handle to OKPanelGratingyPosition (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKPanelGratingyPosition as text
%        str2double(get(hObject,'String')) returns contents of OKPanelGratingyPosition as a double


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



function OKPanelGratingsize_Callback(hObject, eventdata, handles)
% hObject    handle to OKPanelGratingsize (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKPanelGratingsize as text
%        str2double(get(hObject,'String')) returns contents of OKPanelGratingsize as a double



function OKPanelGratingsf_Callback(hObject, eventdata, handles)
% hObject    handle to OKPanelGratingsf (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKPanelGratingsf as text
%        str2double(get(hObject,'String')) returns contents of OKPanelGratingsf as a double



function OKPanelGratingcontrast_Callback(hObject, eventdata, handles)
% hObject    handle to OKPanelGratingcontrast (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKPanelGratingcontrast as text
%        str2double(get(hObject,'String')) returns contents of OKPanelGratingcontrast as a double



function OKPanelGratingangle_Callback(hObject, eventdata, handles)
% hObject    handle to OKPanelGratingangle (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKPanelGratingangle as text
%        str2double(get(hObject,'String')) returns contents of OKPanelGratingangle as a double




function OKPanelBarcontrast_Callback(hObject, eventdata, handles)



function OKPanelBarbarWidth_Callback(hObject, eventdata, handles)



function OKPanelBarbarLength_Callback(hObject, eventdata, handles)



function OKPanelBaryPosition_Callback(hObject, eventdata, handles)



function OKPanelBarxPosition_Callback(hObject, eventdata, handles)


function OKMenuPreferences_Callback(hObject, eventdata, handles)


function OKPanelGratinggabor_Callback(hObject, eventdata, handles)


function OKRandomise_Callback(hObject, eventdata, handles)


function OKProtocolsList_Callback(hObject, eventdata, handles)


function pushbutton22_Callback(hObject, eventdata, handles)


function OKHistoryList_Callback(hObject, eventdata, handles)


function OKPanelGratingmask_Callback(hObject, eventdata, handles)


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


function OKitTime_Callback(hObject, eventdata, handles)
if isappdata(0,'o')
	o = getappdata(0,'o');
	o.getTaskVals;
end

% --- Executes on selection change in OKrandomGenerator.
function OKrandomGenerator_Callback(hObject, eventdata, handles)
% hObject    handle to OKrandomGenerator (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns OKrandomGenerator contents as cell array
%        contents{get(hObject,'Value')} returns selected item from OKrandomGenerator

function OKRandomSeed_Callback(hObject, eventdata, handles)
% hObject    handle to OKRandomSeed (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKRandomSeed as text
%        str2double(get(hObject,'String')) returns contents of OKRandomSeed as a double


function OKPanelGratingtf_Callback(hObject, eventdata, handles)
% hObject    handle to OKPanelGratingtf (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKPanelGratingtf as text
%        str2double(get(hObject,'String')) returns contents of OKPanelGratingtf as a double



function OKPanelGratingcolour_Callback(hObject, eventdata, handles)
% hObject    handle to OKPanelGratingcolour (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKPanelGratingcolour as text
%        str2double(get(hObject,'String')) returns contents of OKPanelGratingcolour as a double

function OKPanelGratingalpha_Callback(hObject, eventdata, handles)
% hObject    handle to OKPanelGratingalpha (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKPanelGratingalpha as text
%        str2double(get(hObject,'String')) returns contents of OKPanelGratingalpha as a double


% --- Executes on selection change in OKPanelBartype.
function OKPanelBartype_Callback(hObject, eventdata, handles)
% hObject    handle to OKPanelBartype (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns OKPanelBartype contents as cell array
%        contents{get(hObject,'Value')} returns selected item from OKPanelBartype


function OKPanelBarcolour_Callback(hObject, eventdata, handles)
% hObject    handle to OKPanelBarcolour (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKPanelBarcolour as text
%        str2double(get(hObject,'String')) returns contents of OKPanelBarcolour as a double


function OKPanelBaralpha_Callback(hObject, eventdata, handles)
% hObject    handle to OKPanelBaralpha (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKPanelBaralpha as text
%        str2double(get(hObject,'String')) returns contents of OKPanelBaralpha as a double



function OKPanelBarangle_Callback(hObject, eventdata, handles)
% hObject    handle to OKPanelBarangle (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKPanelBarangle as text
%        str2double(get(hObject,'String')) returns contents of OKPanelBarangle as a double


function OKPanelBarstartPosition_Callback(hObject, eventdata, handles)
% hObject    handle to OKPanelBarstartPosition (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKPanelBarstartPosition as text
%        str2double(get(hObject,'String')) returns contents of OKPanelBarstartPosition as a double


function OKPanelBarspeed_Callback(hObject, eventdata, handles)
% hObject    handle to OKPanelBarspeed (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKPanelBarspeed as text
%        str2double(get(hObject,'String')) returns contents of OKPanelBarspeed as a double



function OKPanelDotsnDots_Callback(hObject, eventdata, handles)
% hObject    handle to OKPanelDotsnDots (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKPanelDotsnDots as text
%        str2double(get(hObject,'String')) returns contents of OKPanelDotsnDots as a double



function OKPanelDotsdotSize_Callback(hObject, eventdata, handles)
% hObject    handle to OKPanelDotsdotSize (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKPanelDotsdotSize as text
%        str2double(get(hObject,'String')) returns contents of OKPanelDotsdotSize as a double


function OKPanelDotssize_Callback(hObject, eventdata, handles)
% hObject    handle to OKPanelDotssize (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKPanelDotssize as text
%        str2double(get(hObject,'String')) returns contents of OKPanelDotssize as a double



function OKPanelDotsyPosition_Callback(hObject, eventdata, handles)
% hObject    handle to OKPanelDotsyPosition (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKPanelDotsyPosition as text
%        str2double(get(hObject,'String')) returns contents of OKPanelDotsyPosition as a double


function OKPanelDotsxPosition_Callback(hObject, eventdata, handles)
% hObject    handle to OKPanelDotsxPosition (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKPanelDotsxPosition as text
%        str2double(get(hObject,'String')) returns contents of OKPanelDotsxPosition as a double


% --- Executes on selection change in OKPanelDotsdotType.
function OKPanelDotsdotType_Callback(hObject, eventdata, handles)
% hObject    handle to OKPanelDotsdotType (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns OKPanelDotsdotType contents as cell array
%        contents{get(hObject,'Value')} returns selected item from OKPanelDotsdotType


function OKPanelDotscolour_Callback(hObject, eventdata, handles)
% hObject    handle to OKPanelDotscolour (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKPanelDotscolour as text
%        str2double(get(hObject,'String')) returns contents of OKPanelDotscolour as a double



function OKPanelDotsalpha_Callback(hObject, eventdata, handles)
% hObject    handle to OKPanelDotsalpha (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKPanelDotsalpha as text
%        str2double(get(hObject,'String')) returns contents of OKPanelDotsalpha as a double


function OKPanelDotsangle_Callback(hObject, eventdata, handles)
% hObject    handle to OKPanelDotsangle (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKPanelDotsangle as text
%        str2double(get(hObject,'String')) returns contents of OKPanelDotsangle as a double


% --- Executes on button press in OKPanelGratingrotationMethod.
function OKPanelGratingrotationMethod_Callback(hObject, eventdata, handles)
% hObject    handle to OKPanelGratingrotationMethod (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of
% OKPanelGratingrotationMethod


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


function OKPanelGratingaspectRatio_Callback(hObject, eventdata, handles)
% hObject    handle to OKPanelGratingaspectRatio (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKPanelGratingaspectRatio as text
%        str2double(get(hObject,'String')) returns contents of
%        OKPanelGratingaspectRatio as a double


function OKPanelGratingcontrastMult_Callback(hObject, eventdata, handles)
% hObject    handle to OKPanelGratingcontrastMult (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKPanelGratingcontrastMult as text
%        str2double(get(hObject,'String')) returns contents of OKPanelGratingcontrastMult as a double


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
function OKToolbarToggleGlobal_OffCallback(hObject, eventdata, handles) %#ok<*INUSL>
% hObject    handle to OKToolbarToggleGlobal (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
set(handles.OKPanelProtocols,'Visible','on')
set(handles.OKPanelGlobal,'Visible','off')


% --- Executes on button press in OKVariablesLinear.
function OKVariablesLinear_Callback(hObject, eventdata, handles)
% hObject    handle to OKVariablesLinear (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in OKVariablesLog.
function OKVariablesLog_Callback(hObject, eventdata, handles) %#ok<*INUSD>
% hObject    handle to OKVariablesLog (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --------------------------------------------------------------------
function OKToolbarInitialise_ClickedCallback(hObject, eventdata, handles) %#ok<*DEFNU>
% hObject    handle to OKToolbarInitialise (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if isappdata(0,'o')
	o = getappdata(0,'o');
	o.r=[];
	set(handles.OKPanelDots,'Visible','off')
	%set(handles.OKPanelNoise,'Visible','off')
	set(handles.OKPanelBar,'Visible','off')
	%set(handles.OKPanelPlaid,'Visible','off')
	set(handles.OKPanelGrating,'Visible','on')
	o.store.visibleStimulus='grating';
	o.store.gratingN = 0;
	o.store.barN = 0;
	o.store.dotsN = 0;
	o.store.plaidN = 0;
	o.store.noiseN = 0;
	o.getScreenVals
	o.getTaskVals;
	o.clearStimulusList;
	o.clearVariableList;
end


% --- Executes on button press in OKAddStimulus.
function OKAddStimulus_Callback(hObject, eventdata, handles)
% hObject    handle to OKAddStimulus (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if isappdata(0,'o')
	o = getappdata(0,'o');
	switch o.store.visibleStimulus
		case 'grating'
			o.addGrating;
		case 'bar'
			o.addBar;
		case 'dots'
			o.addDots;
	end
end

% --- Executes on button press in OKDeleteStimulus.
function OKDeleteStimulus_Callback(hObject, eventdata, handles)
% hObject    handle to OKDeleteStimulus (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if isappdata(0,'o')
	o = getappdata(0,'o');
	switch o.store.visibleStimulus
		case 'grating'
			o.deleteGrating;
		case 'bar'
			o.deleteBar;
		case 'dots'
			o.deleteDots;
	end
end

% --- Executes on button press in OKAddVariable.
function OKAddVariable_Callback(hObject, eventdata, handles)
% hObject    handle to OKAddVariable (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in OKDeleteVariable.
function OKDeleteVariable_Callback(hObject, eventdata, handles)
% hObject    handle to OKDeleteVariable (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)



function OKPanelGratingstartPosition_Callback(hObject, eventdata, handles)
% hObject    handle to OKPanelGratingstartPosition (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKPanelGratingstartPosition as text
%        str2double(get(hObject,'String')) returns contents of OKPanelGratingstartPosition as a double



function OKPanelGratingphase_Callback(hObject, eventdata, handles)
% hObject    handle to OKPanelGratingphase (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKPanelGratingphase as text
%        str2double(get(hObject,'String')) returns contents of OKPanelGratingphase as a double



function OKPanelDotscoherence_Callback(hObject, eventdata, handles)
% hObject    handle to OKPanelDotscoherence (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKPanelDotscoherence as text
%        str2double(get(hObject,'String')) returns contents of OKPanelDotscoherence as a double



function OKPanelDotsspeed_Callback(hObject, eventdata, handles)
% hObject    handle to OKPanelDotsspeed (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKPanelDotsspeed as text
%        str2double(get(hObject,'String')) returns contents of OKPanelDotsspeed as a double


% --- Executes on selection change in OKPanelDotstype.
function OKPanelDotstype_Callback(hObject, eventdata, handles)
% hObject    handle to OKPanelDotstype (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns OKPanelDotstype contents as cell array
%        contents{get(hObject,'Value')} returns selected item from OKPanelDotstype

% --------------------------------------------------------------------
function OKToolbarRun_ClickedCallback(hObject, eventdata, handles)
% hObject    handle to OKToolbarRun (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

if isappdata(0,'o')
	o = getappdata(0,'o');
	o.r.run;
end

% --- Executes during object creation, after setting all properties.
function OKMonitorDistance_CreateFcn(hObject, eventdata, handles)
% hObject    handle to OKMonitorDistance (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function OKPixelsPerCm_CreateFcn(hObject, eventdata, handles)
% hObject    handle to OKPixelsPerCm (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function OKXCenter_CreateFcn(hObject, eventdata, handles)
% hObject    handle to OKXCenter (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function OKYCenter_CreateFcn(hObject, eventdata, handles)
% hObject    handle to OKYCenter (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function OKbackgroundColour_CreateFcn(hObject, eventdata, handles)
% hObject    handle to okbackgroundcolour (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function OKnTrials_CreateFcn(hObject, eventdata, handles)
% hObject    handle to OKnTrials (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function OKisTime_CreateFcn(hObject, eventdata, handles)
% hObject    handle to OKisTime (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function OKWindowSize_CreateFcn(hObject, eventdata, handles)
% hObject    handle to OKWindowSize (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function OKSelectScreen_CreateFcn(hObject, eventdata, handles)
% hObject    handle to OKSelectScreen (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function OKitTime_CreateFcn(hObject, eventdata, handles)
% hObject    handle to OKitTime (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function OKrandomGenerator_CreateFcn(hObject, eventdata, handles)
% hObject    handle to OKrandomGenerator (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function OKRandomSeed_CreateFcn(hObject, eventdata, handles)
% hObject    handle to OKRandomSeed (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function OKtrialTime_CreateFcn(hObject, eventdata, handles)
% hObject    handle to OKtrialTime (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function OKGLSrc_CreateFcn(hObject, eventdata, handles)
% hObject    handle to OKGLSrc (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function OKGLDst_CreateFcn(hObject, eventdata, handles)
% hObject    handle to OKGLDst (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function OKMultiSampling_CreateFcn(hObject, eventdata, handles)
% hObject    handle to OKMultiSampling (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function OKSerialPortName_CreateFcn(hObject, eventdata, handles)
% hObject    handle to OKSerialPortName (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function OKHistoryList_CreateFcn(hObject, eventdata, handles)
% hObject    handle to OKHistoryList (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function OKProtocolsList_CreateFcn(hObject, eventdata, handles)
% hObject    handle to OKProtocolsList (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function OKVariableList_CreateFcn(hObject, eventdata, handles)
% hObject    handle to OKVariableList (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function OKVariableStimuli_CreateFcn(hObject, eventdata, handles)
% hObject    handle to OKVariableStimuli (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function OKVariableValues_CreateFcn(hObject, eventdata, handles)
% hObject    handle to OKVariableValues (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function OKVariableName_CreateFcn(hObject, eventdata, handles)
% hObject    handle to OKVariableName (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function OKPanelBartype_CreateFcn(hObject, eventdata, handles)
% hObject    handle to OKPanelBartype (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function OKPanelBarxPosition_CreateFcn(hObject, eventdata, handles)
% hObject    handle to OKPanelBarxPosition (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function OKPanelBaryPosition_CreateFcn(hObject, eventdata, handles)
% hObject    handle to OKPanelBaryPosition (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function OKPanelBarbarLength_CreateFcn(hObject, eventdata, handles)
% hObject    handle to OKPanelBarbarLength (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function OKPanelBarbarWidth_CreateFcn(hObject, eventdata, handles)
% hObject    handle to OKPanelBarbarWidth (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function OKPanelBarspeed_CreateFcn(hObject, eventdata, handles)
% hObject    handle to OKPanelBarspeed (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function OKPanelBarcontrast_CreateFcn(hObject, eventdata, handles)
% hObject    handle to OKPanelBarcontrast (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function OKPanelBarangle_CreateFcn(hObject, eventdata, handles)
% hObject    handle to OKPanelBarangle (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function OKPanelBarstartPosition_CreateFcn(hObject, eventdata, handles)
% hObject    handle to OKPanelBarstartPosition (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function OKPanelBarcolour_CreateFcn(hObject, eventdata, handles)
% hObject    handle to OKPanelBarcolour (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function OKPanelBaralpha_CreateFcn(hObject, eventdata, handles)
% hObject    handle to OKPanelBaralpha (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function OKPanelGratingxPosition_CreateFcn(hObject, eventdata, handles)
% hObject    handle to OKPanelGratingxPosition (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function OKPanelGratingyPosition_CreateFcn(hObject, eventdata, handles)
% hObject    handle to OKPanelGratingyPosition (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function OKPanelGratingcontrast_CreateFcn(hObject, eventdata, handles)
% hObject    handle to OKPanelGratingcontrast (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function OKPanelGratingstartPosition_CreateFcn(hObject, eventdata, handles)
% hObject    handle to OKPanelGratingstartPosition (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function OKPanelGratinggabor_CreateFcn(hObject, eventdata, handles)
% hObject    handle to OKPanelGratinggabor (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function OKPanelGratingtf_CreateFcn(hObject, eventdata, handles)
% hObject    handle to OKPanelGratingtf (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function OKPanelGratingcolour_CreateFcn(hObject, eventdata, handles)
% hObject    handle to OKPanelGratingcolour (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function OKPanelGratingalpha_CreateFcn(hObject, eventdata, handles)
% hObject    handle to OKPanelGratingalpha (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function OKPanelGratingsize_CreateFcn(hObject, eventdata, handles)
% hObject    handle to OKPanelGratingsize (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function OKPanelGratingaspectRatio_CreateFcn(hObject, eventdata, handles)
% hObject    handle to OKPanelGratingaspectRatio (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function OKPanelGratingsf_CreateFcn(hObject, eventdata, handles)
% hObject    handle to OKPanelGratingsf (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function OKPanelGratingangle_CreateFcn(hObject, eventdata, handles)
% hObject    handle to OKPanelGratingangle (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function OKPanelGratingcontrastMult_CreateFcn(hObject, eventdata, handles)
% hObject    handle to OKPanelGratingcontrastMult (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function OKPanelGratingphase_CreateFcn(hObject, eventdata, handles)
% hObject    handle to OKPanelGratingphase (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in OKPanelGratingdisableNorm.
function OKPanelGratingdisableNorm_Callback(hObject, eventdata, handles)
% hObject    handle to OKPanelGratingdisableNorm (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of OKPanelGratingdisableNorm



function OKPanelGratingspeed_Callback(hObject, eventdata, handles)
% hObject    handle to OKPanelGratingspeed (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKPanelGratingspeed as text
%        str2double(get(hObject,'String')) returns contents of OKPanelGratingspeed as a double


% --- Executes during object creation, after setting all properties.
function OKPanelGratingspeed_CreateFcn(hObject, eventdata, handles)
% hObject    handle to OKPanelGratingspeed (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function OKPanelDotsnDots_CreateFcn(hObject, eventdata, handles)
% hObject    handle to OKPanelDotsnDots (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function OKPanelDotsdotSize_CreateFcn(hObject, eventdata, handles)
% hObject    handle to OKPanelDotsdotSize (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function OKPanelDotssize_CreateFcn(hObject, eventdata, handles)
% hObject    handle to OKPanelDotssize (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function OKPanelDotsyPosition_CreateFcn(hObject, eventdata, handles)
% hObject    handle to OKPanelDotsyPosition (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function OKPanelDotsxPosition_CreateFcn(hObject, eventdata, handles)
% hObject    handle to OKPanelDotsxPosition (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function OKPanelDotsdotType_CreateFcn(hObject, eventdata, handles)
% hObject    handle to OKPanelDotsdotType (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function OKPanelDotscolour_CreateFcn(hObject, eventdata, handles)
% hObject    handle to OKPanelDotscolour (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function OKPanelDotsalpha_CreateFcn(hObject, eventdata, handles)
% hObject    handle to OKPanelDotsalpha (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function OKPanelDotsangle_CreateFcn(hObject, eventdata, handles)
% hObject    handle to OKPanelDotsangle (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function OKPanelDotscoherence_CreateFcn(hObject, eventdata, handles)
% hObject    handle to OKPanelDotscoherence (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function OKPanelDotsspeed_CreateFcn(hObject, eventdata, handles)
% hObject    handle to OKPanelDotsspeed (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function OKPanelDotstype_CreateFcn(hObject, eventdata, handles)
% hObject    handle to OKPanelDotstype (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
