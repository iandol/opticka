function varargout = opx_opt_ui(varargin)
% OPX_OPT_UI MATLAB code for opx_opt_ui.fig
%      OPX_OPT_UI, by itself, creates a new OPX_OPT_UI or raises the existing
%      singleton*.
%
%      H = OPX_OPT_UI returns the handle to a new OPX_OPT_UI or the handle to
%      the existing singleton*.
%
%      OPX_OPT_UI('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in OPX_OPT_UI.M with the given input arguments.
%
%      OPX_OPT_UI('Property','Value',...) creates a new OPX_OPT_UI or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before opx_opt_ui_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to opx_opt_ui_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help opx_opt_ui

% Last Modified by GUIDE v2.5 02-Jul-2011 13:15:16

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @opx_opt_ui_OpeningFcn, ...
                   'gui_OutputFcn',  @opx_opt_ui_OutputFcn, ...
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


% --- Executes just before opx_opt_ui is made visible.
function opx_opt_ui_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to opx_opt_ui (see VARARGIN)

% Choose default command line output for opx_opt_ui
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes opx_opt_ui wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = opx_opt_ui_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;



function opxOptPath_Callback(hObject, eventdata, handles)
% hObject    handle to opxOptPath (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of opxOptPath as text
%        str2double(get(hObject,'String')) returns contents of opxOptPath as a double


% --- Executes on button press in opxOptChangePath.
function opxOptChangePath_Callback(hObject, eventdata, handles)
% hObject    handle to opxOptChangePath (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
