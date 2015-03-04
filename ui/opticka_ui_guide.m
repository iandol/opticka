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

% Last Modified by GUIDE v2.5 24-Feb-2015 17:20:41

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
function OKMenuStimulusLog_Callback(hObject, eventdata, handles)
% hObject    handle to OKMenuStimulusLog (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	o.r.task.showLog;
end

% --------------------------------------------------------------------
function OKMenuShowGammaPlots_Callback(hObject, eventdata, handles)
% hObject    handle to OKMenuShowGammaPlots (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	if isa(o.r.screen.gammaTable,'calibrateLuminance')
		o.r.screen.gammaTable.plot;
	end
end
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
if isappdata(handles.output,'o')
	
end

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
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	o.r.getRunLog;
end

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

% --- Executes on selection change in OKSelectScreen.
function OKSelectScreen_Callback(hObject, eventdata, handles)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	o.getScreenVals;
end


function OKMonitorDistance_Callback(hObject, eventdata, handles)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	o.getScreenVals;
end


function OKpixelsPerCm_Callback(hObject, eventdata, handles)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	o.getScreenVals;
end


function OKscreenXOffset_Callback(hObject, eventdata, handles)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	o.getScreenVals;
end

function OKscreenYOffset_Callback(hObject, eventdata, handles)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	o.getScreenVals;
end

function OKWindowSize_Callback(hObject, eventdata, handles)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	o.getScreenVals;
end

function OKGLSrc_Callback(hObject, eventdata, handles)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	o.getScreenVals;
end


function OKGLDst_Callback(hObject, eventdata, handles)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	o.getScreenVals;
end

function OKbitDepth_Callback(hObject, eventdata, handles)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	o.getScreenVals;
end

function OKAntiAliasing_Callback(hObject, eventdata, handles)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	o.getScreenVals;
end

function OKUseGamma_Callback(hObject, eventdata, handles)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	o.getScreenVals;
end

function OKSerialPortName_Callback(hObject, eventdata, handles)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	o.getScreenVals;
end

% --- Executes on button press in OKUsePhotoDiode.
function OKUsePhotoDiode_Callback(hObject, eventdata, handles)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	o.getScreenVals;
end

% --- Executes on button press in OKuseDataPixx.
function OKuseDataPixx_Callback(hObject, eventdata, handles)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	if get(hObject,'Value') == 1 && get(handles.OKuseDataPixx,'Value') == 1
		set(handles.OKuseLabJack,'Value', 0)
	end
	o.getScreenVals;
end

% --- Executes on button press in OKuseLabJack.
function OKuseLabJack_Callback(hObject, eventdata, handles)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	if get(hObject,'Value') == 1 && get(handles.OKuseDataPixx,'Value') == 1
		set(handles.OKuseDataPixx,'Value', 0)
	end
	o.getScreenVals;
end

% --- Executes on button press in OKuseEyeLink.
function OKuseEyeLink_Callback(hObject, eventdata, handles)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	o.getScreenVals;
end


% --- Executes on button press in OKVerbose.
function OKVerbose_Callback(hObject, eventdata, handles)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	o.getScreenVals;
end

% --- Executes on button press in OKlogFrames.
function OKlogFrames_Callback(hObject, eventdata, handles)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	if isa(o.r.screen,'screenManager')
		if get(hObject,'Value') == 1
			set(handles.OKbenchmark,'Value',0)
		end
		o.getScreenVals;
	end
end

% --- Executes on button press in OKOpenGLBlending.
function OKOpenGLBlending_Callback(hObject, eventdata, handles)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	o.getScreenVals;
end

% --- Executes on button press in OKHideFlash.
function OKHideFlash_Callback(hObject, eventdata, handles)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	o.getScreenVals;
end

% --- Executes on button press in OKDebug.
function OKDebug_Callback(hObject, eventdata, handles)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	o.getScreenVals;
end

function OKbackgroundColour_Callback(hObject, eventdata, handles)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	o.getScreenVals;
end

function OKNativeBeamPosition_Callback(hObject, eventdata, handles)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	o.getScreenVals;
end

function OKrecordMovie_Callback(hObject, eventdata, handles)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	o.getScreenVals;
end

function OKnBlocks_Callback(hObject, eventdata, handles)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	o.getTaskVals;
end

function OKisTime_Callback(hObject, eventdata, handles)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	o.getTaskVals;
end

function OKtrialTime_Callback(hObject, eventdata, handles)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	o.getTaskVals;
end

function OKrealTime_Callback(hObject, eventdata, handles)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	o.getTaskVals;
end

% --------------------------------------------------------------------
function OKMenuNoiseTexture_Callback(hObject, eventdata, handles)
% hObject    handle to OKMenuNoiseTexture (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	o.store.visibleStimulus='dots';
	
end

% --------------------------------------------------------------------
function OKMenuLineTexture_Callback(hObject, eventdata, handles)
% hObject    handle to OKMenuLineTexture (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% --------------------------------------------------------------------
function OKMenuTargetInducer_Callback(hObject, eventdata, handles)
% hObject    handle to OKMenuSpot (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	
	if isfield(o.store,'visibleStimulus');
		o.store.visibleStimulus.closePanel();
		o.store = rmfield(o.store,'visibleStimulus');
	end
	
	set(handles.OKPanelStimulusText,'String','Loading Stimulus Panel...'); drawnow
	
	if ~isfield(o.store,'targetInducerStimulus')
		o.store.targetInducerStimulus=targetInducerStimulus('name','Target-Inducer Stimulus');
	end
	o.store.visibleStimulus = o.store.targetInducerStimulus;
	o.store.visibleStimulus.makePanel(handles.OKPanelStimulus);
	set(handles.OKAddStimulus,'Enable','on');
	set(handles.OKPanelStimulusText,'String','')
end

% --------------------------------------------------------------------
function OKMenuDots_Callback(hObject, eventdata, handles)
% hObject    handle to OKMenuSpot (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	
	if isfield(o.store,'visibleStimulus');
		o.store.visibleStimulus.closePanel();
		o.store = rmfield(o.store,'visibleStimulus');
	end
	
	set(handles.OKPanelStimulusText,'String','Loading Stimulus Panel...'); drawnow
	
	if ~isfield(o.store,'dotsStimulus')
		o.store.dotsStimulus=dotsStimulus('name', 'Coherent Dots Stimulus',...
			'speed', 2, 'colour', [1 1 1]);
	end
	o.store.dotsStimulus.speed = 2;
	o.store.visibleStimulus = o.store.dotsStimulus;
	o.store.visibleStimulus.makePanel(handles.OKPanelStimulus);
	set(handles.OKAddStimulus,'Enable','on');
	set(handles.OKPanelStimulusText,'String','')
end

% --------------------------------------------------------------------
function OKMenuNDots_Callback(hObject, eventdata, handles)
% hObject    handle to OKMenuNDots (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	
	if isfield(o.store,'visibleStimulus');
		o.store.visibleStimulus.closePanel();
		o.store = rmfield(o.store,'visibleStimulus');
	end
	
	set(handles.OKPanelStimulusText,'String','Loading Stimulus Panel...'); drawnow
	
	if ~isfield(o.store,'ndotsStimulus')
		o.store.ndotsStimulus=ndotsStimulus('name','Newsome Dots Stimulus',...
			'speed', 2, 'colour', [1 1 1]);
	end
	o.store.ndotsStimulus.speed = 2;
	o.store.visibleStimulus = o.store.ndotsStimulus;
	o.store.visibleStimulus.makePanel(handles.OKPanelStimulus);
	set(handles.OKAddStimulus,'Enable','on');
	set(handles.OKPanelStimulusText,'String','')
end

% --------------------------------------------------------------------
function OKMenuBar_Callback(hObject, eventdata, handles)
% hObject    handle to OKMenuBar (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	
	if isfield(o.store,'visibleStimulus');
		o.store.visibleStimulus.closePanel();
		o.store = rmfield(o.store,'visibleStimulus');
	end
	
	set(handles.OKPanelStimulusText,'String','Loading Stimulus Panel...'); drawnow
	
	if ~isfield(o.store,'barStimulus')
		o.store.barStimulus=barStimulus('name','Bar Stimulus');
	end
	o.store.visibleStimulus = o.store.barStimulus;
	o.store.visibleStimulus.makePanel(handles.OKPanelStimulus);
	set(handles.OKAddStimulus,'Enable','on');
	set(handles.OKPanelStimulusText,'String','')
end

% --------------------------------------------------------------------
function OKMenuGrating_Callback(hObject, eventdata, handles)
% hObject    handle to OKMenuGrating (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	
	if isfield(o.store,'visibleStimulus');
		o.store.visibleStimulus.closePanel();
		o.store = rmfield(o.store,'visibleStimulus');
	end
	
	set(handles.OKPanelStimulusText,'String','Loading Stimulus Panel...'); drawnow
	
	if ~isfield(o.store,'gratingStimulus')
		o.store.gratingStimulus=gratingStimulus('name','Grating Stimulus');
	end
	o.store.visibleStimulus = o.store.gratingStimulus;
	o.store.visibleStimulus.makePanel(handles.OKPanelStimulus);
	set(handles.OKAddStimulus,'Enable','on');
	set(handles.OKPanelStimulusText,'String','')
end

% --------------------------------------------------------------------
function OKMenuGabor_Callback(hObject, eventdata, handles)
% hObject    handle to OKMenuGabor (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	
	if isfield(o.store,'visibleStimulus');
		o.store.visibleStimulus.closePanel();
		o.store = rmfield(o.store,'visibleStimulus');
	end
	
	set(handles.OKPanelStimulusText,'String','Loading Stimulus Panel...'); drawnow
	
	if ~isfield(o.store,'gaborStimulus')
		o.store.gaborStimulus=gaborStimulus('name','Gabor Stimulus');
	end
	o.store.visibleStimulus = o.store.gaborStimulus;
	set(handles.OKPanelStimulusText,'String','')
	o.store.visibleStimulus.makePanel(handles.OKPanelStimulus);
	set(handles.OKAddStimulus,'Enable','on');
end

% --------------------------------------------------------------------
function OKMenuSpot_Callback(hObject, eventdata, handles)
% hObject    handle to OKMenuSpot (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if isappdata(handles.output,'o')
	
	o = getappdata(handles.output,'o');
	
	if isfield(o.store,'visibleStimulus');
		o.store.visibleStimulus.closePanel();
		o.store = rmfield(o.store,'visibleStimulus');
	end
	
	set(handles.OKPanelStimulusText,'String','Loading Stimulus Panel...'); drawnow
	
	if ~isfield(o.store,'spotStimulus')
		o.store.spotStimulus=spotStimulus('name','Spot Stimulus');
	end
	o.store.visibleStimulus = o.store.spotStimulus;
	set(handles.OKPanelStimulusText,'String','')
	o.store.visibleStimulus.makePanel(handles.OKPanelStimulus);
	set(handles.OKAddStimulus,'Enable','on');
end

% --------------------------------------------------------------------
function OKMenuTexture_Callback(hObject, eventdata, handles)
% hObject    handle to OKMenuTexture (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	
	if isfield(o.store,'visibleStimulus');
		o.store.visibleStimulus.closePanel();
		o.store = rmfield(o.store,'visibleStimulus');
	end
	
	set(handles.OKPanelStimulusText,'String','Loading Stimulus Panel...'); drawnow
	
	if ~isfield(o.store,'textureStimulus')
		o.store.textureStimulus=textureStimulus('name','Picture / Texture Stimulus');
	end
	o.store.visibleStimulus = o.store.textureStimulus;
	o.store.visibleStimulus.makePanel(handles.OKPanelStimulus);
	set(handles.OKAddStimulus,'Enable','on');
	set(handles.OKPanelStimulusText,'String','')
end


% --------------------------------------------------------------------
function OKMenuPreferences_Callback(hObject, eventdata, handles)


function OKProtocolsList_Callback(hObject, eventdata, handles)


function OKHistoryList_Callback(hObject, eventdata, handles)


% --- Executes on button press in OKProtocolLoad.
function OKProtocolLoad_Callback(hObject, eventdata, handles)
% hObject    handle to OKProtocolLoad (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	o.router('loadProtocol');
end

% --- Executes on button press in OKProtocolSave.
function OKProtocolSave_Callback(hObject, eventdata, handles)
% hObject    handle to OKProtocolSave (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	o.router('saveProtocol');
end

% --- Executes on button press in OKProtocolDuplicate.
function OKProtocolDuplicate_Callback(hObject, eventdata, handles)
% hObject    handle to OKProtocolDuplicate (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	o.router('duplicateProtocol');
end

% --- Executes on button press in OKProtocolDelete.
function OKProtocolDelete_Callback(hObject, eventdata, handles)
% hObject    handle to OKProtocolDelete (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	o.router('deleteProtocol');
end

% --------------------------------------------------------------------
function OKMenuCalibrateLuminance_Callback(hObject, eventdata, handles)
% hObject    handle to OKMenuCalibrateLuminance (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	v=get(handles.OKSelectScreen,'Value');
	inp = struct('screen',v-1);
	if isa(o.r.screen.gammaTable,'calibrateLuminance')
		o.r.screen.gammaTable.run;
	else
		c = calibrateLuminance(inp);
		o.r.screen.gammaTable = c;
		c.filename = [o.paths.calibration filesep 'Cal-' date '-' c.comments];
		o.saveCalibration;
	end
	set(handles.OKUseGamma,'Value',1)
	o.r.screen.gammaTable.choice = 0; 
	set(handles.OKUseGamma,'String',['None'; 'Gamma'; o.r.screen.gammaTable.analysisMethods]);
end

% --------------------------------------------------------------------
function OKMenuLoadGamma_Callback(hObject, eventdata, handles)
% hObject    handle to OKMenuLoadGamma (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	uiopen('~/MatlabFiles/Calibration')
	if exist('tmp','var') && isa(tmp,'calibrateLuminance')
		o.r.screen.gammaTable = tmp;
		clear tmp;
		if get(handles.OKUseGamma,'Value') > length(['None'; 'Gamma'; o.r.screen.gammaTable.analysisMethods])
			set(handles.OKUseGamma,'Value',1);
			o.r.screen.gammaTable.choice = 0; 
		else
			o.r.screen.gammaTable.choice = get(handles.OKUseGamma,'Value')-1;
		end
		set(handles.OKUseGamma,'String',['None'; 'Gamma'; o.r.screen.gammaTable.analysisMethods]);
	end
end

% --------------------------------------------------------------------
function OKMenuSaveGamma_Callback(hObject, eventdata, handles)
% hObject    handle to OKMenuSaveGamma (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	if isa(o.r.screen.gammaTable,'calibrateLuminance')
		tmp=o.r.screen.gammaTable;
		uisave('tmp',[o.paths.calibration filesep 'Calibration-' date '-' o.r.screen.gammaTable.comments]);
	end
end

% --------------------------------------------------------------------
function OKMenuCalibrateSize_Callback(hObject, eventdata, handles)
% hObject    handle to OKMenuCalibrateSize (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
v=get(handles.OKSelectScreen,'Value');
s=str2num(get(handles.OKMonitorDistance,'String')); 
[~,dpc]=calibrateSize(v-1,s);
set(handles.OKpixelsPerCm,'String',num2str(dpc));


function OKitTime_Callback(hObject, eventdata, handles)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	o.getTaskVals;
end

function OKRandomise_Callback(hObject, eventdata, handles)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	o.getTaskVals;
end
% --- Executes on selection change in OKrandomGenerator.
function OKrandomGenerator_Callback(hObject, eventdata, handles)
% hObject    handle to OKrandomGenerator (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% Hints: contents = cellstr(get(hObject,'String')) returns OKrandomGenerator contents as cell array
%        contents{get(hObject,'Value')} returns selected item from OKrandomGenerator
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	o.getTaskVals;
end

function OKRandomSeed_Callback(hObject, eventdata, handles)
% hObject    handle to OKRandomSeed (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% Hints: get(hObject,'String') returns contents of OKRandomSeed as text
%        str2double(get(hObject,'String')) returns contents of OKRandomSeed as a double
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	o.getTaskVals;
end

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

% --- Executes on button press in OKCopyVariableName.
function OKCopyVariableName_Callback(hObject, eventdata, handles)
% hObject    handle to OKCopyVariableName (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
string = get(handles.OKVariableList,'String');
value = get(handles.OKVariableList,'Value');
string=string{value};
set(handles.OKVariableName,'String',string);

function OKCopyVariableNameValues_Callback(hObject, eventdata, handles)
string = get(handles.OKVariableList,'String');
value = get(handles.OKVariableList,'Value');
string=string{value};
set(handles.OKVariableName,'String',string);

switch string
	case 'angle'
		string = num2str(-90:45:90);
		string = regexprep(string,'\s+',' '); %collapse spaces
		set(handles.OKVariableValues,'String',string);
	case 'motionAngle'
		string = num2str(-90:45:90);
		string = regexprep(string,'\s+',' '); %collapse spaces
		set(handles.OKVariableValues,'String',string);
	case 'phase'
		string = num2str(0:22.5:180);
		string = regexprep(string,'\s+',' '); %collapse spaces
		set(handles.OKVariableValues,'String',string);
	case 'size'
		string = num2str([0 0.1 0.2 0.35 0.5 0.75 1 2 4 6 8]);
		string = regexprep(string,'\s+',' '); %collapse spaces
		set(handles.OKVariableValues,'String',string);
	case 'contrast'
		string = num2str(0:0.1:1);
		string = regexprep(string,'\s+',' '); %collapse spaces
		set(handles.OKVariableValues,'String',string);
	case 'sf'
		string = num2str([0 0.1 0.5 0.7 1 1.5 2 3 4 5 6]);
		string = regexprep(string,'\s+',' '); %collapse spaces
		set(handles.OKVariableValues,'String',string);
	case 'tf'
		string = num2str([0.5 1 2 3 4 5]);
		string = regexprep(string,'\s+',' '); %collapse spaces
		set(handles.OKVariableValues,'String',string);
	case 'xPosition'
		string = num2str(-1:0.2:1);
		string = regexprep(string,'\s+',' '); %collapse spaces
		set(handles.OKVariableValues,'String',string);	
	case 'yPosition'
		string = num2str(-1:0.2:1);
		string = regexprep(string,'\s+',' '); %collapse spaces
		set(handles.OKVariableValues,'String',string);	
end



% --- Executes on button press in OKVariablesLinear.
function OKVariablesLinear_Callback(hObject, eventdata, handles)
values = str2num(get(handles.OKVariableValues,'String'));
if length(values) == 3
	values=linspace(values(1),values(2),values(3));
	string = num2str(values);
else
	string = num2str(values);
	string = regexprep(string,'\s+',' '); %collapse spaces
end
set(handles.OKVariableValues,'String',string);

% --- Executes on button press in OKVariablesLog.
function OKVariablesLog_Callback(hObject, eventdata, handles) %#ok<*INUSD>
values = str2num(get(handles.OKVariableValues,'String'));
if length(values) == 3
	values=logspace(log10(values(1)),log10(values(2)),values(3));
	string = num2str(values);
	string = regexprep(string,'\s+',' '); %collapse spaces
	set(handles.OKVariableValues,'String',string);
else
	warndlg('Please enter a minimum, maximum and number of values');
end

% --- Executes on button press in OKAddStimulus.
function OKAddStimulus_Callback(hObject, eventdata, handles)
% hObject    handle to OKAddStimulus (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	if isfield(o.store,'visibleStimulus')
		o.store.visibleStimulus.readPanel();
		o.r.stimuli{o.r.stimuli.n+1} = o.store.visibleStimulus.clone();
		%o.r.stimuli{o.r.stimuli.n}.name = 'Stimulus';
		o.addStimulus;
		if o.r.stimuli.n > 0
			set(handles.OKAddStimulus,'Enable','on');
			set(handles.OKDeleteStimulus,'Enable','on');
			set(handles.OKModifyStimulus,'Enable','on');
			set(handles.OKCopyStimulus,'Enable','on');
			set(handles.OKStimulusUp,'Enable','on');
			set(handles.OKStimulusDown,'Enable','on');
			set(handles.OKStimulusRun,'Enable','on');
			set(handles.OKStimulusRunBenchmark,'Enable','on');
			set(handles.OKStimulusRunAll,'Enable','on');
			set(handles.OKStimulusRunAllBenchmark,'Enable','on');
			set(handles.OKStimulusRunSingle,'Enable','on');
		end
	end
end

% --- Executes on button press in OKDeleteStimulus.
function OKDeleteStimulus_Callback(hObject, eventdata, handles)
% hObject    handle to OKDeleteStimulus (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	o.deleteStimulus;
	if o.r.stimuli.n == 0
		set(handles.OKAddStimulus,'Enable','off');
		set(handles.OKDeleteStimulus,'Enable','off');
		set(handles.OKModifyStimulus,'Enable','off');
		set(handles.OKCopyStimulus,'Enable','off');
		set(handles.OKStimulusUp,'Enable','off');
		set(handles.OKStimulusDown,'Enable','off');
		set(handles.OKStimulusRun,'Enable','off');
		set(handles.OKStimulusRunBenchmark,'Enable','off');
		set(handles.OKStimulusRunAll,'Enable','off');
		set(handles.OKStimulusRunAllBenchmark,'Enable','off');
		set(handles.OKStimulusRunSingle,'Enable','off');
	end
end

% --- Executes on button press in OKCopyStimulus.
function OKCopyStimulus_Callback(hObject, eventdata, handles)
% hObject    handle to OKCopyStimulus (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	v = get(handles.OKStimList,'Value');
	o.r.stimuli{o.r.stimuli.n+1} = o.r.stimuli{v}.clone;
	o.r.stimuli{o.r.stimuli.n}.name = ['Stimulus #' num2str(o.r.stimuli.n)];
	o.addStimulus;
end

% --- Executes on selection change in OKStimList.
function OKStimList_Callback(hObject, eventdata, handles)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	o.editStimulus;
end

% --- Executes on button press in OKStimulusDown.
function OKStimulusDown_Callback(hObject, eventdata, handles) %#ok<*INUSL>
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	value = get(handles.OKStimList,'Value'); %where are we in the stimulus list
	slength = o.r.stimuli.n;
	if value < slength
		idx = 1:slength;
		idx2 = idx;
		idx2(value) = idx2(value)+1;
		idx2(value+1) = idx2(value+1)-1;
		o.r.stimuli(idx) = o.r.stimuli(idx2);
		set(handles.OKStimList,'Value',value+1);
		o.modifyStimulus;
	end
end

% --- Executes on button press in OKStimulusUp.
function OKStimulusUp_Callback(hObject, eventdata, handles)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	value = get(handles.OKStimList,'Value'); %where are we in the stimulus list
	slength = o.r.stimuli.n;
	if value > 1
		idx = 1:slength;
		idx2 = idx;
		idx2(value) = idx2(value)-1;
		idx2(value-1) = idx2(value-1)+1;
		o.r.stimuli(idx) = o.r.stimuli(idx2);
		set(handles.OKStimList,'Value',value-1);
		o.modifyStimulus;
	end
end

% --- Executes on button press in OKStimulusRun.
function OKStimulusRun_Callback(hObject, eventdata, handles)
% hObject    handle to OKStimulusRun (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	v = get(handles.OKStimList,'Value');
	if v > 0 && isobject(o.r.stimuli{v})
		run(o.r.stimuli{v}, false, [], o.r.screen);
	end
	set(handles.OKStimulusRunAll,'Enable','on');
end

% --- Executes on button press in OKStimulusRunBenchmark.
function OKStimulusRunBenchmark_Callback(hObject, eventdata, handles)
% hObject    handle to OKStimulusRunBenchmark (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	v = get(handles.OKStimList,'Value');
	if v > 0 && isa(o.r.stimuli{v},'baseStimulus')
		run(o.r.stimuli{v}, true, [], o.r.screen);
	end
end

% --- Executes on button press in OKStimulusRunAll.
function OKStimulusRunAll_Callback(hObject, eventdata, handles)
% hObject    handle to OKStimulusRunAll (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	if isa(o.r.stimuli,'metaStimulus') && o.r.stimuli.n > 0
		o.r.stimuli.choice = [];
		if isa(o.r.screen,'screenManager')
			run(o.r.stimuli, [], [], o.r.screen);
		else
			run(o.r.stimuli);
		end
	end
end

% --- Executes on button press in OKStimulusRunAllBenchmark.
function OKStimulusRunAllBenchmark_Callback(hObject, eventdata, handles)
% hObject    handle to OKStimulusRunAllBenchmark (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	if isa(o.r.stimuli,'metaStimulus') && o.r.stimuli.n > 0
		o.r.stimuli.choice = [];
		if isa(o.r.screen,'screenManager')
			run(o.r.stimuli, true, 5, o.r.screen);
		else
			run(o.r.stimuli, true);
		end
	end
end

% --- Executes on button press in OKStimulusRunSingle.
function OKStimulusRunSingle_Callback(hObject, eventdata, handles)
% hObject    handle to OKStimulusRunSingle (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	if isa(o.r.stimuli,'metaStimulus') && o.r.stimuli.n > 0
		o.r.stimuli.choice = [];
		runSingle(o.r.stimuli, o.r.screen);
	end
end


% --- Executes on button press in OKInspectStimulus.
function OKInspectStimulus_Callback(hObject, eventdata, handles)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	v = get(handles.OKStimList,'Value');
	if v > 0;
		uiinspect(o.r.stimuli{v});
	end
end

% --- Executes on button press in OKInspectVariable.
function OKInspectVariable_Callback(hObject, eventdata, handles)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	v = get(handles.OKVarList,'Value');
	if v > 0;
		uiinspect(o.r.task.nVar(v));
	end
end


% --- Executes on button press in OKModifyStimulus.
function OKModifyStimulus_Callback(hObject, eventdata, handles)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	v = get(handles.OKStimList,'Value');
	if v > 0;
		seditor(o.r.stimuli{v}, handles.output);
	end
	
end

% --- Executes on button press in OKAddVariable.
function OKAddVariable_Callback(hObject, eventdata, handles)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	o.addVariable;
	if o.r.task.nVars > 0
		set(handles.OKDeleteVariable,'Enable','on');
		set(handles.OKCopyVariable,'Enable','on');
		set(handles.OKEditVariable,'Enable','on');
	end
end

% --- Executes on button press in OKDeleteVariable.
function OKDeleteVariable_Callback(hObject, eventdata, handles)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	o.deleteVariable;
	if o.r.task.nVars < 1
		set(handles.OKDeleteVariable,'Enable','off');
		set(handles.OKCopyVariable,'Enable','off');
		set(handles.OKEditVariable,'Enable','off');
	end
end

function OKCopyVariable_Callback(hObject, eventdata, handles)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	o.copyVariable;
end

function OKEditVariable_Callback(hObject, eventdata, handles)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	o.editVariable;
end

function OKVariableOffset_Callback(hObject, eventdata, handles)
% hObject    handle to OKVariableOffset (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKVariableOffset as text
%        str2double(get(hObject,'String')) returns contents of OKVariableOffset
%        as a double

% --------------------------------------------------------------------
function OKToolbarRun_ClickedCallback(hObject, eventdata, handles)
% hObject    handle to OKToolbarRun (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	if ~isempty(o.oc) && o.oc.isOpen == 1 && o.r.useLabJack == 1
		o.oc.write('--GO!--');
		pause(0.5);
	end
	drawnow;
	o.r.uiCommand='run';
	o.r.run;
end

% --------------------------------------------------------------------
function OKToolbarStop_ClickedCallback(hObject, eventdata, handles)
% hObject    handle to OKToolbarStop (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	o.r.uiCommand='stop';
	drawnow;
end

% --------------------------------------------------------------------
function OKToolbarAbort_ClickedCallback(hObject, eventdata, handles)
% hObject    handle to OKToolbarAbort (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	o.r.uiCommand='abort';
	if isa(o.oc,'dataConnection')
		o.oc.write('--abort--');
	end
	drawnow;
end

function OKRemoteIP_Callback(hObject, eventdata, handles)
% hObject    handle to OKRemoteIP (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKRemoteIP as text
%        str2double(get(hObject,'String')) returns contents of OKRemoteIP as a double
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	o.getTaskVals;
end


function OKRemotePort_Callback(hObject, eventdata, handles)
% hObject    handle to OKRemotePort (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKRemotePort as text
%        str2double(get(hObject,'String')) returns contents of OKRemotePort as a double
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	o.getTaskVals;
end

% --------------------------------------------------------------------
function OKToolbarToggleRemote_OnCallback(hObject, eventdata, handles)
% hObject    handle to OKToolbarToggleRemote (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	eval(o.store.serverCommand)
end


% --------------------------------------------------------------------
function OKMenumanageCode_Callback(hObject, eventdata, handles)
% hObject    handle to OKMenumanageCode (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
manageCode


% --------------------------------------------------------------------
function OKMenurfMapperLog_Callback(hObject, eventdata, handles)
% hObject    handle to OKMenurfMapperLog (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


function OKSettingsmovieSize_Callback(hObject, eventdata, handles)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	o.r.screen.movieSettings.size=str2num(get(hObject,'String'));
end

function OKSettingsmovieFrames_Callback(hObject, eventdata, handles)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	o.r.screen.movieSettings.nFrames=str2num(get(hObject,'String')); %#ok<*ST2NM>
end

function OKSettingsmoviePrecision_Callback(hObject, eventdata, handles)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	o.r.screen.movieSettings.quality=get(hObject,'Value');
end

function OKSettingsmovieType_Callback(hObject, eventdata, handles)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	o.r.screen.movieSettings.type=get(hObject,'Value');
end

function OKSettingsmovieCodec_Callback(hObject, eventdata, handles)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	o.r.screen.movieSettings.codec=get(hObject,'String');
end

% --------------------------------------------------------------------
function OKPanelTellOmniplex_ClickedCallback(hObject, eventdata, handles)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	resp = questdlg('Is opxOnline running on the Omniplex machine?','Check OPX','No');
	if strcmpi(resp,'Yes')
		o.connectToOmniplex
	end
end

% --------------------------------------------------------------------
function OKPanelReconnectOmniplex_ClickedCallback(hObject, eventdata, handles)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	if isa(o.oc,'dataConnection')
		o.oc.closeAll;
		o.connectToOmniplex;
	end
end

% --------------------------------------------------------------------
function OKPanelSendOmniplex_ClickedCallback(hObject, eventdata, handles)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	if isa(o.oc,'dataConnection')
		o.sendOmniplexStimulus;
	end
end

% --------------------------------------------------------------------
function OKPanelDisconnectOmniplex_ClickedCallback(hObject, eventdata, handles)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	if isa(o.oc,'dataConnection')
		o.disconnectOmniplex;
	end
end

% --------------------------------------------------------------------
function OKPanelPingOmniplex_ClickedCallback(hObject, eventdata, handles)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	rAddress = get(handles.OKOmniplexIP,'String');
	status = o.ping(rAddress);
	if status > 0
		set(o.h.OKOmniplexStatus,'String','Omniplex: machine ping ERROR!')
	else
		if isa(o.oc,'dataConnection') && o.oc.isOpen == 1
			o.oc.write('--ping--');
			loop = 1;
			while loop < 8
				in = o.oc.read(0);
				fprintf('\n{opticka said: %s}\n',in)
				if regexpi(in,'ping')
					fprintf('\nWe can ping omniplex master on try: %d\n',loop)
					set(handles.OKOmniplexStatus,'String','Omniplex: connected and pinged')
					break
				else
					fprintf('\nOmniplex master not responding, try: %d\n',loop)
					set(handles.OKOmniplexStatus,'String','Omniplex: not responding')
				end
				loop=loop+1;
				pause(0.1);
			end
		end
	end
end


function OKverbosityLevel_Callback(hObject, eventdata, handles)
% hObject    handle to OKverbosityLevel (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKverbosityLevel as text
%        str2double(get(hObject,'String')) returns contents of OKverbosityLevel as a double
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	if isa(o.r.screen,'screenManager')
		o.r.screen.verbosityLevel = str2double(get(hObject,'String'));
	end
end


% --- Executes on button press in OKbenchmark.
function OKbenchmark_Callback(hObject, eventdata, handles)
% hObject    handle to OKbenchmark (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% Hint: get(hObject,'Value') returns toggle state of OKbenchmark
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	if isa(o.r.screen,'screenManager')
		if get(hObject,'Value') == 1
			set(handles.OKlogFrames,'Value',0)
		end
		o.getScreenVals;
	end
end

% --- Executes on button press in OKOmniplexEnable.
function OKOmniplexEnable_Callback(hObject, eventdata, handles)
% hObject    handle to OKOmniplexEnable (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% Hint: get(hObject,'Value') returns toggle state of OKOmniplexEnable
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	if get(hObject,'Value') < 1
		set(handles.OKOmniplexIP,'Enable','off');
		set(handles.OKOmniplexPort,'Enable','off');
		set(handles.OKPanelTellOmniplex,'Enable','off');
		set(handles.OKPanelReconnectOmniplex,'Enable','off');
		set(handles.OKPanelSendOmniplex,'Enable','off');
		set(handles.OKPanelPingOmniplex,'Enable','off');
		set(handles.OKPanelDisconnectOmniplex,'Enable','off');
	else
		set(handles.OKOmniplexIP,'Enable','on');
		set(handles.OKOmniplexPort,'Enable','on');
		set(handles.OKPanelTellOmniplex,'Enable','on');
		set(handles.OKPanelReconnectOmniplex,'Enable','on');
		set(handles.OKPanelSendOmniplex,'Enable','on');
		set(handles.OKPanelPingOmniplex,'Enable','on');
		set(handles.OKPanelDisconnectOmniplex,'Enable','on');
	end
end

% --------------------------------------------------------------------
function OKMenuOpen_Callback(hObject, eventdata, handles)
% hObject    handle to OKMenuOpen (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	o.router('loadProtocol','1');
end

% --------------------------------------------------------------------
function OKMenuSave_Callback(hObject, eventdata, handles)
% hObject    handle to OKMenuSave (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	o.router('saveProtocol');
end

% --------------------------------------------------------------------
function OKMenuQuit_Callback(hObject, eventdata, handles)
% hObject    handle to OKMenuQuit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if isappdata(handles.output,'o')
	try
		o = getappdata(handles.output,'o');
		o.savePrefs;
		rmappdata(handles.output,'o');
		clear o;
	catch ME
		fprintf('>>> Opticka failed to clear all data on close...');
		rethrow ME
	end
end
close(gcf);

% --------------------------------------------------------------------
function OKMenuNewProtocol_Callback(hObject, eventdata, handles)
% hObject    handle to OKMenuNewProtocol (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	o.r = [];
	o.store.evnt = [];
	o.store = rmfield(o.store,'evnt');
	o.store.visibleStimulus=[];
	o.store = rmfield(o.store,'visibleStimulus');
	o.clearStimulusList;
	o.clearVariableList;
	o.getScreenVals;
	o.getTaskVals;
end

% --------------------------------------------------------------------
function OKToolbarInitialise_ClickedCallback(hObject, eventdata, handles) %#ok<*DEFNU>
% hObject    handle to OKToolbarInitialise (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	o.r = [];
	o.store.evnt = [];
	o.store = rmfield(o.store,'evnt');
	o.store.visibleStimulus=[];
	o.store = rmfield(o.store,'visibleStimulus');
	o.clearStimulusList;
	o.clearVariableList;
	o.getScreenVals;
	o.getTaskVals;
end

% --------------------------------------------------------------------
function OKToolbarOpen_ClickedCallback(hObject, eventdata, handles)
% hObject    handle to OKToolbarOpen (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	o.router('loadProtocol','1');
end

% --------------------------------------------------------------------
function OKToolbarSave_ClickedCallback(hObject, eventdata, handles)
% hObject    handle to OKToolbarSave (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	o.router('saveProtocol');
end


% --------------------------------------------------------------------
function OKToolbarDefinePath_ClickedCallback(hObject, eventdata, handles)
% hObject    handle to OKToolbarDefinePath (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	path = uigetdir;
	if ischar(path) && exist(path,'dir')
		initialiseSave(o, path);
		if isa(o.r,'runExperiment');
			initialiseSave(o.r, path);
		end
	end
end


function OKTrainingName_Callback(hObject, eventdata, handles)
% hObject    handle to OKTrainingName (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKTrainingName as text
%        str2double(get(hObject,'String')) returns contents of OKTrainingName as a double


% --- Executes during object creation, after setting all properties.
function OKTrainingName_CreateFcn(hObject, eventdata, handles)
% hObject    handle to OKTrainingName (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --------------------------------------------------------------------
function OKToggleUI_ClickedCallback(hObject, eventdata, handles)
% hObject    handle to OKToggleUI (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if strcmp(get(handles.OKPanelGlobal,'Visible'),'on')
	
	set(handles.OKPanelGlobal,'Visible','off');
	set(handles.OKPanelProtocols,'Visible','on');
	set(handles.OKPanelTraining,'Visible','off');
	
elseif strcmp(get(handles.OKPanelProtocols,'Visible'),'on')
	
	set(handles.OKPanelProtocols,'Visible','off')
	set(handles.OKPanelGlobal,'Visible','off')
	set(handles.OKPanelTraining,'Visible','on')
	if isappdata(handles.output,'o')
		o = getappdata(handles.output,'o');
		o.getStateInfo();
	end
	
else
	
	set(handles.OKPanelProtocols,'Visible','off')
	set(handles.OKPanelGlobal,'Visible','on')
	set(handles.OKPanelTraining,'Visible','off')
	
end

% --- Executes on button press in OKEditStateFileButon.
function OKEditStateFileButon_Callback(hObject, eventdata, handles)
% hObject    handle to OKEditStateFileButon (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	if exist(o.r.paths.stateInfoFile,'file')
		edit(o.r.paths.stateInfoFile);
	end
	o.getStateInfo();
end

function OKTrainingResearcherName_Callback(hObject, eventdata, handles)
% hObject    handle to OKTrainingResearcherName (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of OKTrainingResearcherName as text
%        str2double(get(hObject,'String')) returns contents of OKTrainingResearcherName as a double

% --------------------------------------------------------------------
function OKMenuStateInfo_Callback(hObject, eventdata, handles)
% hObject    handle to OKMenuStateInfo (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	o.router('LoadStateInfo');
	o.getStateInfo();
end

% --- Executes on button press in OKLoadStateButton.
function OKLoadStateButton_Callback(hObject, eventdata, handles)
% hObject    handle to OKLoadStateButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	o.router('LoadStateInfo');
	o.getStateInfo();
end

% --- Executes on button press in OKRefreshStateInfo.
function OKRefreshStateInfo_Callback(hObject, eventdata, handles)
% hObject    handle to OKRefreshStateInfo (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	o.getStateInfo();
end

% --------------------------------------------------------------------
function OKRFMapper_ClickedCallback(hObject, eventdata, handles)
% hObject    handle to OKRFMapper (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	o.store.rfLog = [];
	rf=rfMapper;
	rf.run(o.r);
	o.store.rfLog = rf;
	clear rf;
end

% --------------------------------------------------------------------
function OKRunRFMapper_Callback(hObject, eventdata, handles)
% hObject    handle to OKRunRFMapper (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	o.store.rfLog = [];
	rf=rfMapper;
	rf.run(o.r);
	o.store.rfLog = rf;
	clear rf;
end

% --------------------------------------------------------------------
function OKRunTrainingSession_Callback(hObject, eventdata, handles)
% hObject    handle to OKRunTrainingSession (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --------------------------------------------------------------------
function OKRunExperiment_Callback(hObject, eventdata, handles)
% hObject    handle to OKRunExperiment (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% --------------------------------------------------------------------
function OKStartTask_ClickedCallback(hObject, eventdata, handles)
% hObject    handle to OKStartTask (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if isappdata(handles.output,'o')
	o = getappdata(handles.output,'o');
	if isa(o.r,'runExperiment')
		%o.r.screenSettings.optickahandle = handles.output;
		initialiseSave(o.r, o.paths.savedData)
		if ~isempty(regexp(o.comment, '^Protocol','once'))
			o.r.comment = o.comment;
		end
		runTask(o.r);
	end
end


% --------------------------------------------------------------------
function OKMenuIO_Callback(hObject, eventdata, handles)
% hObject    handle to OKMenuIO (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
