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

% Last Modified by GUIDE v2.5 01-Mar-2011 18:46:40

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
% uiwait(handles.figure1);


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


% --- Executes during object creation, after setting all properties.
function opxUICell_CreateFcn(hObject, eventdata, handles)
% hObject    handle to opxUICell (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in opxUIAnalysisMethod.
function opxUIAnalysisMethod_Callback(hObject, eventdata, handles)
% hObject    handle to opxUIAnalysisMethod (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns opxUIAnalysisMethod contents as cell array
%        contents{get(hObject,'Value')} returns selected item from opxUIAnalysisMethod


% --- Executes during object creation, after setting all properties.
function opxUIAnalysisMethod_CreateFcn(hObject, eventdata, handles)
% hObject    handle to opxUIAnalysisMethod (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
