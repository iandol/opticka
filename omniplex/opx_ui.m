function varargout = opx_ui(varargin)
% OPX_UI M-file for opx_ui.fig
%      OPX_UI, by itself, creates a new OPX_UI or raises the existing
%      singleton*.
%
%      H = OPX_UI returns the handle to a new OPX_UI or the handle to
%      the existing singleton*.
%
%      OPX_UI('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in OPX_UI.M with the given input arguments.
%
%      OPX_UI('Property','Value',...) creates a new OPX_UI or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before opx_ui_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to opx_ui_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help opx_ui

% Last Modified by GUIDE v2.5 04-Mar-2011 19:10:07

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @opx_ui_OpeningFcn, ...
                   'gui_OutputFcn',  @opx_ui_OutputFcn, ...
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


% --- Executes just before opx_ui is made visible.
function opx_ui_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to opx_ui (see VARARGIN)

% Choose default command line output for opx_ui
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes opx_ui wait for user response (see UIRESUME)
% uiwait(handles.opxUI);


% --- Outputs from this function are returned to the command line.
function varargout = opx_ui_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


% --- Executes on button press in opxUIQuitButton.
function opxUIQuitButton_Callback(hObject, eventdata, handles)
% hObject    handle to opxUIQuitButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on selection change in opxUICell.
function opxUICell_Callback(hObject, eventdata, handles)
% hObject    handle to opxUICell (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns opxUICell contents as cell array
%        contents{get(hObject,'Value')} returns selected item from opxUICell

% --- Executes on selection change in opxUIAnalysisMethod.
function opxUIAnalysisMethod_Callback(hObject, eventdata, handles)
% hObject    handle to opxUIAnalysisMethod (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns opxUIAnalysisMethod contents as cell array
%        contents{get(hObject,'Value')} returns selected item from opxUIAnalysisMethod

function opxUIEdit1_Callback(hObject, eventdata, handles)
% hObject    handle to opxUIEdit1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of opxUIEdit1 as text
%        str2double(get(hObject,'String')) returns contents of opxUIEdit1 as a double

function opxUIEdit2_Callback(hObject, eventdata, handles)
% hObject    handle to opxUIEdit2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of opxUIEdit2 as text
%        str2double(get(hObject,'String')) returns contents of opxUIEdit2 as a double

% --- Executes on selection change in opxUISelect1.
function opxUISelect1_Callback(hObject, eventdata, handles)
% hObject    handle to opxUISelect1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns opxUISelect1 contents as cell array
%        contents{get(hObject,'Value')} returns selected item from opxUISelect1


% --- Executes on selection change in opxUISelect2.
function opxUISelect2_Callback(hObject, eventdata, handles)
% hObject    handle to opxUISelect2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns opxUISelect2 contents as cell array
%        contents{get(hObject,'Value')} returns selected item from opxUISelect2


% --- Executes on button press in opxUIButton1.
function opxUIButton1_Callback(hObject, eventdata, handles)
% hObject    handle to opxUIButton1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)



function opxUIInfoBox_Callback(hObject, eventdata, handles)
% hObject    handle to opxUIInfoBox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of opxUIInfoBox as text
%        str2double(get(hObject,'String')) returns contents of opxUIInfoBox as a double
