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

% Last Modified by GUIDE v2.5 16-Sep-2010 14:49:09

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
% uiwait(handles.OKRoot);


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

function OKAntiAliasing_Callback(hObject, eventdata, handles)
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

% --- Executes on button press in OKuseLabJack.
function OKuseLabJack_Callback(hObject, eventdata, handles)
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

% --- Executes on button press in OKFixationSpot.
function OKFixationSpot_Callback(hObject, eventdata, handles)
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
function OKMenuDots_Callback(hObject, eventdata, handles)
% hObject    handle to OKMenuSpot (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
%set(handles.OKPanelNoise,'Visible','off')
set(handles.OKPanelGrating,'Visible','off')
set(handles.OKPanelBar,'Visible','off')
set(handles.OKPanelSpot,'Visible','off')
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
set(handles.OKPanelSpot,'Visible','off')
set(handles.OKPanelBar,'Visible','on')
set(handles.OKPanelDots,'Visible','off')
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
set(handles.OKPanelSpot,'Visible','off')
set(handles.OKPanelBar,'Visible','off')
set(handles.OKPanelGrating,'Visible','on')
if isappdata(0,'o')
	o = getappdata(0,'o');
	o.store.visibleStimulus='grating';
end

% --------------------------------------------------------------------
function OKMenuSpot_Callback(hObject, eventdata, handles)
% hObject    handle to OKMenuSpot (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
set(handles.OKPanelGrating,'Visible','off')
set(handles.OKPanelBar,'Visible','off')
set(handles.OKPanelDots,'Visible','off')
set(handles.OKPanelSpot,'Visible','on')
if isappdata(0,'o')
	o = getappdata(0,'o');
	o.store.visibleStimulus='spot';
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

switch get(hObject,'Value')
	case 1
		set(handles.OKPanelGratingaspectRatio,'Enable','off')
		%set(handles.OKPanelGratingcontrastMult,'Enable','off')
		set(handles.OKPanelGratingspatialConstant,'Enable','off')
		set(handles.OKPanelGratingdisableNorm,'Enable','off')
		set(handles.OKPanelGratingmask,'Enable','on')
		set(handles.OKPanelGratingrotationMethod,'Enable','on')
	otherwise
		set(handles.OKPanelGratingaspectRatio,'Enable','on')
		%set(handles.OKPanelGratingcontrastMult,'Enable','on')
		set(handles.OKPanelGratingspatialConstant,'Enable','on')
		set(handles.OKPanelGratingdisableNorm,'Enable','on')
		set(handles.OKPanelGratingmask,'Enable','off')
		set(handles.OKPanelGratingrotationMethod,'Enable','off')
end



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
MeasureDpi;

function OKitTime_Callback(hObject, eventdata, handles)
if isappdata(0,'o')
	o = getappdata(0,'o');
	o.getTaskVals;
end

function OKRandomise_Callback(hObject, eventdata, handles)
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
if isappdata(0,'o')
	o = getappdata(0,'o');
	o.getTaskVals;
end

function OKRandomSeed_Callback(hObject, eventdata, handles)
% hObject    handle to OKRandomSeed (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% Hints: get(hObject,'String') returns contents of OKRandomSeed as text
%        str2double(get(hObject,'String')) returns contents of OKRandomSeed as a double
if isappdata(0,'o')
	o = getappdata(0,'o');
	o.getTaskVals;
end

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


% --- Executes on button press in OKCopyVariableName.
function OKCopyVariableName_Callback(hObject, eventdata, handles)
% hObject    handle to OKCopyVariableName (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
string = get(handles.OKVariableList,'String');
value = get(handles.OKVariableList,'Value');
string=string{value};
set(handles.OKVariableName,'String',string);

function OKCopyVariable_Callback(hObject, eventdata, handles)


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
values = str2num(get(handles.OKVariableValues,'String'));
string = num2str(values);
string = regexprep(string,'\s+',' '); %collapse spaces
set(handles.OKVariableValues,'String',string);

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
	o.store.spotN = 0;
	o.store.plaidN = 0;
	o.store.noiseN = 0;
	o.clearStimulusList;
	o.clearVariableList;
	o.getScreenVals;
	o.getTaskVals;
end


% --- Executes on button press in OKAddStimulus.
function OKAddStimulus_Callback(hObject, eventdata, handles)
% hObject    handle to OKAddStimulus (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if isappdata(0,'o')
	o = getappdata(0,'o');
	o.r.updatesList; %initialise it.
	switch o.store.visibleStimulus
		case 'grating'
			o.addGrating;
		case 'bar'
			o.addBar;
		case 'dots'
			o.addDots;
		case 'spot'
			o.addSpot;
	end
	o.store.stimN = o.store.stimN + 1;
end

% --- Executes on button press in OKDeleteStimulus.
function OKDeleteStimulus_Callback(hObject, eventdata, handles)
% hObject    handle to OKDeleteStimulus (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if isappdata(0,'o')
	o = getappdata(0,'o');
	o.deleteStimulus;
end

% --- Executes on button press in OKAddVariable.
function OKAddVariable_Callback(hObject, eventdata, handles)
% hObject    handle to OKAddVariable (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if isappdata(0,'o')
	o = getappdata(0,'o');
	o.addVariable;
end

% --- Executes on button press in OKDeleteVariable.
function OKDeleteVariable_Callback(hObject, eventdata, handles)
% hObject    handle to OKDeleteVariable (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if isappdata(0,'o')
	o = getappdata(0,'o');
	o.deleteVariable;
end


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


% --- Executes on button press in OKPanelGratingdriftDirection.
function OKPanelGratingdriftDirection_Callback(hObject, eventdata, handles)
% hObject    handle to OKPanelGratingdriftDirection (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of OKPanelGratingdriftDirection

% --- Executes on button press in OKVariablesLog.
function OKPanelGratingdisableNorm_Callback(hObject, eventdata, handles) %#ok<*INUSD>
% hObject    handle to OKVariablesLog (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --------------------------------------------------------------------
function OKMenuLogs_Callback(hObject, eventdata, handles)
% hObject    handle to OKMenuLogs (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --------------------------------------------------------------------
function OKMenuCheckIO_Callback(hObject, eventdata, handles)
% hObject    handle to OKMenuCheckIO (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --------------------------------------------------------------------
function OKMenuEditConfiguration_Callback(hObject, eventdata, handles)
% hObject    handle to OKMenuEditConfiguration (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --------------------------------------------------------------------
function OKMenuAllTimingLogs_Callback(hObject, eventdata, handles)
% hObject    handle to OKMenuAllTimingLogs (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --------------------------------------------------------------------
function OKMenuMissedFrames_Callback(hObject, eventdata, handles)
% hObject    handle to OKMenuMissedFrames (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --------------------------------------------------------------------
function OKMenuCut_Callback(hObject, eventdata, handles)
% hObject    handle to OKMenuCut (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --------------------------------------------------------------------
function OKMenuCopy_Callback(hObject, eventdata, handles)
% hObject    handle to OKMenuCopy (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --------------------------------------------------------------------
function OKMenuPaste_Callback(hObject, eventdata, handles)
% hObject    handle to OKMenuPaste (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


function OKPanelGratingspeed_Callback(hObject, eventdata, handles)



function OKPanelGratingspatialConstant_Callback(hObject, eventdata, handles)
% hObject    handle to OKPanelGratingspatialConstant (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKPanelGratingspatialConstant as text
%        str2double(get(hObject,'String')) returns contents of OKPanelGratingspatialConstant as a double


% --- Executes on button press in OKCopyStimulus.
function OKCopyStimulus_Callback(hObject, eventdata, handles)
% hObject    handle to OKCopyStimulus (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on selection change in OKPanelSpottype.
function OKPanelSpottype_Callback(hObject, eventdata, handles)
% hObject    handle to OKPanelSpottype (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns OKPanelSpottype contents as cell array
%        contents{get(hObject,'Value')} returns selected item from
%        OKPanelSpottype


function OKPanelSpotxPosition_Callback(hObject, eventdata, handles)
% hObject    handle to OKPanelSpotxPosition (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKPanelSpotxPosition as text
%        str2double(get(hObject,'String')) returns contents of OKPanelSpotxPosition as a double

function OKPanelSpotyPosition_Callback(hObject, eventdata, handles)
% hObject    handle to OKPanelSpotyPosition (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKPanelSpotyPosition as text
%        str2double(get(hObject,'String')) returns contents of OKPanelSpotyPosition as a double

function OKPanelSpotsize_Callback(hObject, eventdata, handles)
% hObject    handle to OKPanelSpotsize (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKPanelSpotsize as text
%        str2double(get(hObject,'String')) returns contents of OKPanelSpotsize as a double

function OKPanelSpotflashTime_Callback(hObject, eventdata, handles)
% hObject    handle to OKPanelSpotflashTime (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKPanelSpotflashTime as text
%        str2double(get(hObject,'String')) returns contents of OKPanelSpotflashTime as a double

function OKPanelSpotspeed_Callback(hObject, eventdata, handles)
% hObject    handle to OKPanelSpotspeed (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKPanelSpotspeed as text
%        str2double(get(hObject,'String')) returns contents of OKPanelSpotspeed as a double

function OKPanelSpotcontrast_Callback(hObject, eventdata, handles)
% hObject    handle to OKPanelSpotcontrast (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKPanelSpotcontrast as text
%        str2double(get(hObject,'String')) returns contents of OKPanelSpotcontrast as a double

function OKPanelSpotangle_Callback(hObject, eventdata, handles)
% hObject    handle to OKPanelSpotangle (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKPanelSpotangle as text
%        str2double(get(hObject,'String')) returns contents of OKPanelSpotangle as a double

function OKPanelSpotstartPosition_Callback(hObject, eventdata, handles)
% hObject    handle to OKPanelSpotstartPosition (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKPanelSpotstartPosition as text
%        str2double(get(hObject,'String')) returns contents of OKPanelSpotstartPosition as a double

function OKPanelSpotcolour_Callback(hObject, eventdata, handles)
% hObject    handle to OKPanelSpotcolour (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKPanelSpotcolour as text
%        str2double(get(hObject,'String')) returns contents of OKPanelSpotcolour as a double

function OKPanelSpotalpha_Callback(hObject, eventdata, handles)
% hObject    handle to OKPanelSpotalpha (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKPanelSpotalpha as text
%        str2double(get(hObject,'String')) returns contents of OKPanelSpotalpha as a double
