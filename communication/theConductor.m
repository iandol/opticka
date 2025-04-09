% ========================================================================
%> @class theConductor
%> @brief theConductor — ØMQ server to run behavioural tasks
%>
%> 
%>
%> Copyright ©2014-2025 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ========================================================================
classdef theConductor < optickaCore
	
	properties
		%> run the zmq server immediately?
		runNow = false
		%> IP address
		address = '0.0.0.0'
		%> port to bind to
		port = 6666
		%>
		verbose = true
	end

	properties (GetAccess = public, SetAccess = protected)
		%> ØMQ zmqConnection object
		zmq
		%> command
		command
		%> data
		data
		%> task object
		runner
	end

	properties (Access = private)
		allowedProperties = {'runNow','address','port','verbose'}
		sendState = false
		recState = false
	end

	methods
		% ===================================================================
		function me = theConductor(varargin)
		%> @brief 
		%> @details 
		%> @note 
		% ===================================================================	
			args = optickaCore.addDefaults(varargin,struct('name','screenManager'));
			me=me@optickaCore(args); %superclass constructor
			me.parseArgs(args,me.allowedProperties); %check remaining properties from varargin

			%setupPTB(me);
			
			me.zmq = zmqConnection('type', 'REP', 'address', me.address,'port', me.port, 'verbose', me.verbose);

			if me.runNow; run(me); end

		end

		% ===================================================================
		function run(me)
		%> @brief Enters a loop to continuously receive and process commands.
		%> @details This method runs a `while` loop that repeatedly calls
		%>   `receiveCommand(me, false)` to wait for incoming commands without
		%>   sending an automatic 'ok'. Based on the received `command`, it
		%>   performs specific actions (e.g., echo, gettime) and sends an
		%>   appropriate reply using `sendObject`. The loop terminates upon
		%>   receiving an 'exit' or 'quit' command.
		%> @note This is typically used for server-like roles (e.g., REP sockets)
		%>   that need to handle various client requests. Includes short pauses
		%>   using `WaitSecs` to prevent busy-waiting.
		% ===================================================================
			cd(me.paths.parent);
			fprintf('=== The Conductor is Running... ===\n');
			if exist('conductorData.json','file')
				j = readstruct('conductorData.json');
				me.address = j.address;
				me.port = j.port;
			end
			if ~me.zmq.isOpen; open(me.zmq); end
			process(me);
			fprintf('Run finished...\n');
			
		end

	end

	methods (Access = protected)
		
		% ===================================================================
		function process(me)
		%> @brief Enters a loop to continuously receive and process commands.
		%> @details This method runs a `while` loop that repeatedly calls
		%>   `receiveCommand(me, false)` to wait for incoming commands without
		%>   sending an automatic 'ok'. Based on the received `command`, it
		%>   performs specific actions (e.g., echo, gettime) and sends an
		%>   appropriate reply using `sendObject`. The loop terminates upon
		%>   receiving an 'exit' or 'quit' command.
		%> @note This is typically used for server-like roles (e.g., REP sockets)
		%>   that need to handle various client requests. Includes short pauses
		%>   using `WaitSecs` to prevent busy-waiting.
		% ===================================================================
			stop = false; stopMATLAB = false;
			fprintf('\n\n=== Starting command receive loop... ===\n\n');
			while ~stop
				% Call receiveCommand, but tell it NOT to send the default 'ok' reply
				[cmd, data] = receiveCommand(me.zmq, false);

				me.command = cmd;
				me.data = data; %#ok<*PROP>

				if ~isempty(cmd) % Check if receive failed or timed out
					me.recState = true; me.sendState = false;
				else
					me.recState = false;
					WaitSecs('YieldSecs', 0.005); % Short pause before trying again
					continue;
				end

				% Command was received successfully (recState is true).
				% Now determine the reply and send it.
				replyCommand = ''; replyData = []; runCommand = false;
				switch lower(cmd)

					case {'exit', 'quit'}
						fprintf('Received exit command. Shutting down loop.\n');
						replyCommand = 'bye';
						replyData = {'Shutting down'};
						stop = true;

					case 'exitmatlab'
						fprintf('Received exit MATLAB command. Shutting down loop.\n');
						replyCommand = 'bye';
						replyData = {'Shutting down MATLAB'};
						stop = true;
						stopMATLAB = true;

					case 'rundemo'
						if me.verbose > 0; fprintf('Run PTB demo...\n'); end
						replyCommand = 'demo_run';
						replyData = {'VBLSyncTest'}; % Send back the data we received
						runCommand = true;

					case 'echo'
						if me.verbose > 0; fprintf('Echoing received data.\n'); end
						replyCommand = 'echo_reply';
						replyData = data; % Send back the data we received

					case 'gettime'
						replyData(1).GetSecs = GetSecs;
						replyData(1).currentTime = datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss.SSS');
						if isfield(data,'currentTime')
							replyData.remoteTime = data.currentTime;
						else
							replyData.remoteTime = NaN;
						end
						replyDate.timeDiff = replyData.currentTime - replyData.remoteTime;
						if isfield(data,'GetSecs')
							replyData.remoteGetSecs = data.GetSecs;
						else
							replyData.remoteGetSecs = NaN;
						end
						replyData.GetSecsDiff = replyData.GetSecs - replyData.remoteGetSecs;
						if me.verbose > 0; fprintf('Replying with current time: %s\n', replyData.currentTime); end
						replyCommand = 'time_reply';

					case 'syncbuffer'
						% Placeholder for syncBuffer logic
						if me.verbose > 0; fprintf('Processing syncBuffer command (placeholder).\n'); end
						% me.flush(); % Example: maybe flush the input buffer?
						if isfield(data,'frameSize')
							me.zmq.frameSize = data.frameSize;
						end
						replyCommand = 'sync_ack';
						replyData = {'buffer synced'};

					otherwise
						t = sprintf('Received unknown command: «%s»', cmd);
						disp(t);
						replyCommand = 'unknown-command';
						replyData = {t};
				end

				% Send the determined reply
				[rep, dataOut, sendStatus] = sendCommand(me.zmq, replyCommand, replyData, false);
				if sendStatus ~= 0
					warning('Send failed for command "%s": %s', cmd, msg);
					me.sendState = false; % Update state on send failure
				else
					if ~isempty(rep)
						fprintf('Reply was: %s\n', rep);
						if me.verbose; disp(dataOut); end
					end
					me.sendState = true; me.recState = false; % Update state on send success
				end

				if runCommand
					eval(replyData{1});
				end

				% Small pause to prevent busy-waiting if no commands arrive quickly
				if ~stop
					WaitSecs('YieldSecs', 0.005);
				end
			end
			fprintf('Command receive loop finished.\n');
			if stopMATLAB
				me.zmq.close;
				me.zmq = [];
				WaitSecs(0.01);
				quit(0,"force");
			end
		end

		% ===================================================================
		function result = runTask(me)
			if isempty(me.runner)
				warning('Task Runner has not been sent!!!');
				return
			end
			result = 'ok';
		end

		function setupPTB(me)
			Screen('Preference', 'VisualDebugLevel', 3);
			if ismac
				Screen('Preference', 'SkipSyncTests', 2);
			end
			if IsLinux
				!powerprofilesctl set performance
			end
		end


	end

end