function [key qflag] = kbhit(cmd)
% Returns the last key pressed in the command window
%
% kbhit('init')        : initialise listening
% key = kbhit          : last character typed
% key = kbhit('struct'): struct for last character typed (including ctrl,
%                        shift, alt and ascii code information)
% key = kbhit('event') : java keyevent for last key pressed
% [key, qflag] = kbhit : qflag indicates whether ctrl+c was entered
% 
% kbhit('stop')        : turn off listening
%
% NOTE: There's a chance that pressing ctrl+c may interrupt the callback
% function that saves the key being pressed. 
%
% Demonstration code:
%
% kbhit('init');
% fprintf(1, 'Five seconds to type something ...');
% pause(5);
% key = kbhit; fprintf(1, 'Character : %c\n', key);
% key = kbhit('struct'); fprintf(1, 'Key struct :\n'); disp(key)
% [key, ctrlc] = kbhit('event'); fprintf(1, 'Key event :\n'); disp(key)
% fprintf(1, 'Ctrl+c pressed ? %d\n', ctrlc);
% kbhit('stop')
%
% Created by Amanda Ng 3 March 2011

    error(nargchk(0,1,nargin,'struct'));
    
    global KBHIT_h_cw
    global KBHIT_h_cw_cbp
    
    key = [];
    qflag = false;
    
    if nargin == 0
         if isempty(KBHIT_h_cw_cbp)
            error('kbhit has not been initialised.');
         else
            event = get(KBHIT_h_cw, 'userdata');
            if ~isempty(event)
                key = char(get(event, 'KeyCode'));
                qflag = (get(event, 'KeyCode') == 67 & strcmpi(get(event, 'ControlDown'),'on') );
            end
        end
    elseif nargin == 1
        switch lower(cmd)
            case 'init'
                try
                    mde = com.mathworks.mde.desk.MLDesktop.getInstance;
                    KBHIT_h_cw = mde.getClient('Command Window');
                    xCmdWndView = KBHIT_h_cw.getComponent(0).getViewport.getComponent(0);
                    KBHIT_h_cw_cbp = handle(xCmdWndView,'CallbackProperties');
                    javastr = ['global KBHIT_h_cw; ' ...
                               'set(KBHIT_h_cw,''Userdata'', get(gcbo, ''KeyPressedCallbackData'')); '...
                               'clear KBHIT_h_cw; ' ...
                               ];
                    set(KBHIT_h_cw_cbp, 'KeyPressedCallback', javastr);
                    set(KBHIT_h_cw, 'userdata', []);
                    key = 1;
                catch ME
                    key = 0;
                end
            case 'stop'
                set(KBHIT_h_cw_cbp, 'KeyPressedCallback', []);
                clear global KBHIT_h_cw KBHIT_h_cw_cbp KBHIT_ctrl_code
            case 'struct'
                event = get(KBHIT_h_cw, 'userdata');
                if ~isempty(event)
                    key.alt = strcmpi(get(event, 'AltDown'), 'on');
                    key.ctrl = strcmpi(get(event, 'ControlDown'), 'on');
                    key.shift = strcmpi(get(event, 'ShiftDown'), 'on');
                    key.ascii = get(event, 'KeyCode');
                    key.char = char(key.ascii);
                    qflag = (get(event, 'KeyCode') == 67 & strcmpi(get(event, 'ControlDown'),'on') );
                end
            case 'event'
                key = get(KBHIT_h_cw, 'userdata');
                if ~isempty(key)
                    qflag = (get(key, 'KeyCode') == 67 & strcmpi(get(key, 'ControlDown'),'on') );
                end
            otherwise
                error('Unrecognised parameter');
        end
    end
      