% ========================================================================
classdef alyxManager < optickaCore
%> @class alyxManager @brief manage communication with an Alyx database
%>
%> https://alyx.readthedocs.io/en/latest/
%>
%> This class provides methods to connect to an Alyx database, login/logout,
%> upload data, and other management tasks. It is based on the Alyx REST API
%> and older MATLAB code modified from IBL.
%>
%> Copyright ©2014-2026 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ========================================================================

	%--------------------PUBLIC PROPERTIES----------%
	properties
		%> the URL of the ALYX database
		baseURL char = 'http://172.16.102.30:8000'
		%> the user to login
		user char = 'admin'
		%> the lab defined in the Alyx database
		lab char = 'Lab'
		%> the experimental subject
		subject char = 'TestSubject'
		%> where to save the temporary json files sent via REST
		queueDir char = ''
		%> if we open a new session this is the main URL
		sessionURL char = ''
		%> if we open a new session as a child, this is the base session URL
		sessionParentURL char = ''
		%> limit how many values returned
		pageLimit double {mustBeInteger, mustBePositive} = 100
		%> more logging for debugging
		verbose = false
	end

	%--------------------TRANSIENT PROPERTIES-----------%
	properties (Transient = true)
		webOptions				= weboptions('MediaType','application/json','Timeout',5);
	end

	%--------------------DEPENDENT PROTECTED PROPERTIES----------%
	properties (GetAccess = public, Dependent = true)
		loggedIn
	end

	%--------------------TRANSIENT PROTECTED PROPERTIES----------%
	properties (Access = protected, Transient = true)
		token char		= ''
		cache dictionary
	end

	%--------------------PRIVATE PROPERTIES----------%
	properties (Access = private)
		%> password for Alyx login
		password char	= ''
		%> AWS key for S3 uploads
		AWS_KEY char	= ''
		%> AWS ID for S3 uploads
		AWS_ID char		= ''
		%> user assigned when setting secrets
		assignedUser char	= ''
		%> properties allowed to be passed on construction
		allowedProperties = {'baseURL','user','lab','subject','queueDir','pageLimit','verbose'}
		%> regular expression to parse ALF filenames
		alfMatch = '(?<date>^[0-9\-]+)_(?<seq>\d+)_(?<subject>\w+)'
	end


	%=======================================================================
	methods %----------------------------PUBLIC METHODS
	%=======================================================================

		% ===================================================================
		%> @brief Class constructor
		%>
		%> @param varargin are passed as a structure / cell of properties which is
		%> parsed.
		%> @return instance of class.
		% ===================================================================
		function me = alyxManager(varargin)
			me=me@optickaCore(varargin); %superclass constructor
			me.parseArgs(varargin, me.allowedProperties); %parse input args

			cleanQueue(me); %flush any existing queue files in the queueDir
			setSecrets(me); %set secrets from secure storage if present
			me.cache = configureDictionary("string","cell"); % set up the cache for hasEntry()
		end

		% ===================================================================
		function result = hasSecrets(me)
		%> @brief check secrets for the AlyxManager instance
		% ===================================================================
		 	if isempty(me.password) && isempty(me.AWS_ID) && isempty(me.AWS_KEY)
				result = false;
			else
				result = true;
			end
		end

		% ===================================================================
		function cleanQueue(me)
		%> @brief Clean out (drop) the alyxManager queue directory
		% ===================================================================
			flushQueue(me,true);
		end

		% ===================================================================
		function setSecrets(me, password, AWS_ID, AWS_KEY, force)
		%> @brief Set secrets for the AlyxManager instance
		%>
		%> This method allows the user to set the password, AWS ID, and AWS
		%> key for the AlyxManager instance. If any of these values are not
		%> provided, the method attempts to retrieve them from a secure
		%> storage (MATLAB secrets management). Set these manually: 
		%> setSecret('AlyxPassword'); setSecret('AWS_ID'); setSecret('AWS_KEY');
		%>
		%> @param password (char) The password for the Alyx database. If not
		%> provided, it will be retrieved from secure storage.
		%
		%> @param AWS_ID (char) The AWS ID for accessing AWS services. If
		%> not provided, it will be retrieved from secure storage.
		%
		%> @param AWS_KEY (char) The AWS key for accessing AWS services. If
		%> not provided, it will be retrieved from secure storage.
		%
		%> @param force (logical) If true, prompts the user to set the
		%> secrets even if no secrets are stored or provided. In this case
		%> it will use a GUI requestor to get secrets and store them
		% ===================================================================
			arguments
				me alyxManager
				password char = ''
				AWS_ID char = ''
				AWS_KEY char = ''
				force logical = false
			end

			me.assignedUser = me.user;

			if isempty(password)
				try password = getSecret('AlyxPassword'); end %#ok<*TRYNC>
			end
			if isempty(AWS_ID)
				try AWS_ID = getSecret('AWS_ID'); end
			end
			if isempty(AWS_KEY)
				try AWS_KEY = getSecret('AWS_KEY'); end
			end

			if force
				if isempty(password)
					setSecret('AlyxPassword');
					password = getSecret('AlyxPassword');
					me.password = '';
				end
				if isempty(AWS_ID)
					setSecret('AWS_ID');
					AWS_ID = getSecret('AWS_ID');
					me.AWS_ID = '';
				end
				if isempty(AWS_KEY)
					setSecret('AWS_KEY');
					AWS_KEY = getSecret('AWS_KEY');
					me.AWS_KEY = '';
				end
			end

			txt = "";
			if ~isempty(password); me.password = password; txt=txt+"password"; end
			if ~isempty(AWS_ID); me.AWS_ID = AWS_ID; txt=txt+" AWS_ID";end
			if ~isempty(AWS_KEY); me.AWS_KEY = AWS_KEY; txt=txt+" AWS_KEY";end
			fprintf('\n≣≣≣≣⊱ alyxManager: set these secrets: %s\n', txt);

		end

		% ===================================================================
		function logout(me)
		%> @brief Logs out the current user from the AlyxManager instance
		%>
		%> This method clears the session token and any associated session
		%> information, effectively logging the user out of the Alyx system.
		%> It also provides feedback to the user indicating the logout status.
		% ===================================================================
			if me.loggedIn
				me.token = [];
				me.sessionURL = '';
				me.webOptions.HeaderFields = []; % Remove token from header field
				if ~me.loggedIn
					fprintf('\n≣≣≣≣⊱ alyxManager: user <<%s>> logged OUT of <<%s>> successfully...\n\n', me.user, me.baseURL);
				end
			end
		end

		% ===================================================================
		function success = login(me)
		%> @brief Log in the current user from the AlyxManager instance
		% ===================================================================
			success = false;
			if me.loggedIn; warning('Already Logged in...'); end
			noDisplay = usejava('jvm') && ~feature('ShowFigureWindows');
			if isempty(me.user)
				prompt = {'Alyx Username:'};
				if noDisplay
					% use text-based alternative
					answer = strip(input(prompt{:}+" ", 's'));
				else
					% use GUI dialog
					dlg_title = 'Alyx Login';
					num_lines = 1;
					defaultans = {'',''};
					answer = inputdlg(prompt, dlg_title, num_lines, defaultans);
				end
				if isempty(answer)|| (iscell(answer) && isempty(answer{1})); return; end

				if iscell(answer)
					me.user = answer{1};
				else
					me.user = answer;
				end
			end

			if isempty(me.password)
				setSecrets(me);
			end
			if isempty(me.password)
				secretUI(me,'password');
			end

			try
				me.getToken(me.user, me.password);
				fprintf('\n≣≣≣≣⊱ alyxManager: user <<%s>> logged in to <<%s>> successfully...\n\n', me.user, me.baseURL);
				success = me.loggedIn;
				me.sessionURL = '';
				me.sessionParentURL = '';
				flushQueue(me, true);
  			catch ex
    			if strcmp(ex.identifier, 'Alyx:Login:FailedToConnect')

					warning('Alyx:LoginFail:FailedToConnect', 'Failed To Connect.')
					return
				elseif contains(ex.message, 'credentials')||strcmpi(ex.message, 'Bad Request')
					warning('Alyx:LoginFail:BadCredentials', 'Unable to log in with provided credentials. Will reset password')
					me.password = '';
					return
				elseif contains(ex.message, 'password')&&contains(ex.message, 'blank')
					disp('Password may not be left blank')
				else % Another error altogether
					rethrow(ex)
				end
			end
		end

		% ===================================================================
		function r = hasEntry(me, type, name)
		%> @brief Checks if an item exists in the Alyx database
		%>
		%> This method verifies the existence of a specified entry in the
		%> Alyx database based on the type and name provided. It returns
		%> true if the entry exists, and false otherwise.
		%>
		%> @param type (char) The type of entry to check (e.g., 'users', 'subjects').
		%> @param name (char) The name of the entry to check for existence.
		%> @return r (logical) Returns true if the entry exists, false otherwise.
		% ===================================================================
			arguments(Input)
				me
				type string
				name string
			end
			if numEntries(me.cache) > 0 && isKey(me.cache, type)
				rt = lookup(me.cache, type);
				while isscalar(rt); rt = rt{1}; end
				status = 200;
				doCache = false;
			else
				[rt, status] = me.getData(type);
				doCache = true;
			end
			if status ~= 200; warning('Alyx:hasEntry','Problem retrieving %s from Alyx',type); return; end
			if isstruct(rt)
				switch type
					case {'subjects'}
						rt = {rt(:).nickname};
					case {'tags','tasks','procedures','labs', 'locations', 'brain-regions', 'projects','data-repository','dataset-types'}
						rt = {rt(:).name};
					case {'users'}
						rt = {rt(:).username};
					case {'sessions'}
						rt = {rt(:).id};
				end
			end
			if doCache && iscell(rt)
				me.cache = insert(me.cache, type, {rt});
			end
			if iscell(rt)
				r = any(strcmp(string(rt), string(name)));
			else
				r = false;
			end
		end

		% ===================================================================
		function [data, statusCode] = getData(me, endpoint, varargin)
		% ===================================================================
			%GETDATA Return a specific Alyx/REST read-only endpoint
			%   Makes a request to an Alyx endpoint; returns the data as a MATLAB struct.
			%
			%   Examples:
			%     sessions = me.getData('sessions')
			%     sessions = me.getData('https://alyx.cortexlab.net/sessions')
			%     sessions = me.getData('sessions?type=Base')
			%     sessions = me.getData('sessions', 'type', 'Base')
			%
			%
			data = [];
			statusCode = 0;
			if ~me.loggedIn || ~exist('endpoint','var'); return; end
			hasNext = true; page = 1;
			isPaginated = @(r)all(isfield(r, {'count', 'next', 'previous', 'results'}));
			fullEndpoint = me.makeEndpoint(endpoint); % Get complete URL
			options = me.webOptions;
			options.MediaType = 'application/x-www-form-urlencoded';
			try
				while hasNext
					assert(page < me.pageLimit, 'Maximum number of page requests reached')

					result = webread(fullEndpoint, varargin{:}, options);

					if ~isPaginated(result)
						data = result;
						break
					end
					data = [data, result.results']; %#ok<AGROW>
					hasNext = ~isempty(result.next);
					fullEndpoint = result.next;
					page = page + 1;
				end
				statusCode = 200; % Success
				return
			catch ex
				switch ex.identifier
					case {'MATLAB:webservices:UnknownHost', 'MATLAB:webservices:Timeout', ...
						'MATLAB:webservices:CopyContentToDataStreamError'}
						warning(ex.identifier, '%s', ex.message)
						statusCode = 000;
					otherwise
						response = regexp(ex.message, '(?:the status )(\d{3})', 'tokens');
						statusCode = str2double(me.cellflat(response));
						if statusCode == 403 % Invalid token
							warning('Alyx:getData:InvalidToken', 'Invalid token, please re-login')
							me.logout; % Delete token
							me.login; % Re-login
							if me.loggedIn % If succeded
								data = me.getData(fullEndpoint); % Retry
							end
						else
							warning(append('alyxManager.getData: ', ex.identifier), '%s', ex.message);
						end
					end
			end
		end

		% ===================================================================
		function [dataOut, statusCode] = postData(me, endpoint, dataIn, requestMethod, useQueue)
		% ===================================================================
			%> @brief Post any new data to an Alyx/REST endpoint
			%>
			%> Makes a request to an Alyx endpoint with new data as a MATLAB
			%> struct; returns the JSON response data as a MATLAB struct. This
			%> function will create a new record by default, if requestMethod
			%> is undefined. Other methods include 'PUT', 'PATCH' and 'DELETE'.
			%>
			%> @param endpoint char for REST endpoint
			%> @param data struct to encode as JSON and send
			%> @param requestMethod char default 'post', can be 'put','patch','delete'
			%> @return data the JSON response as MATLAB struct
			%> @return statusCode integer HTTP status code
			%>
			%> Example:
			%>   subjects = me.postData('subjects', myStructData, 'post')
			%>
			arguments
				me alyxManager
				endpoint char
				dataIn struct
				requestMethod char = 'post'
				useQueue logical = true
			end

			if ~me.loggedIn; return; end
			assert(any(strcmpi(requestMethod, {'post', 'put', 'patch', 'delete'})),...
			'%s not a valid HTTP request method', requestMethod)

			if ~useQueue % Send directly to Alyx,we do not use the queue
				endpoint = me.makeEndpoint(endpoint); % Ensure absolute URL
				options = me.webOptions;
				options.RequestMethod = lower(requestMethod);
				dataIn = jsonencode(dataIn);
				dataOut = webwrite(endpoint, dataIn, options);
				if ~isempty(dataOut)
					if endsWith(endpoint,'auth-token')
						statusCode = 200;
					else
						statusCode = 201;
					end
				else
					dataOut = []; statusCode = 500;
				end
			else % use the queue to send the data, which will be flushed later
				% Create the JSON command
				jsonData = jsonencode(dataIn);
				% If local Alyx queue directory doesn't exist, create one
				if isempty(me.queueDir) || ~exist(me.queueDir, 'dir')
					me.queueDir = me.paths.parent;
				end
				% Make a filename for the current command
				queueFilename = append(datestr(now, 'yyyy-mm-dd-HH-MM-SS-FFF'), '.', lower(requestMethod));
				queueFullfile = fullfile(me.queueDir, queueFilename);
				% Save the endpoint and json locally
				fid = fopen(queueFullfile, 'w');
				fprintf(fid, '%s\n%s', endpoint, jsonData);
				fclose(fid);
				% Flush the queue
				if me.loggedIn
					[dataOut, statusCode] = me.flushQueue();
					% Return only relevent data
					if numel(statusCode) > 1; statusCode = statusCode(end); end
				end

			end
		end

		% ===================================================================
		function [sessions, eids] = getSessions(me, ref, varargin)
		% ===================================================================
			%> @brief Return session records matched by an Alyx query
			%>
			%> This method searches Alyx sessions using either a direct session
			%> reference string, or named query parameters. It returns a cell array
			%> of session structs and, optionally, the extracted session EIDs
			%> parsed from each session URL.
			%>
			%> The search accepts:
			%>   - subject: subject nickname or ID
			%>   - users: user(s) who created the session
			%>   - lab: lab name
			%>   - date_range: two dates as a comma-separated string or numeric
			%>     date vector [start end]
			%>   - dataset_types: comma-separated dataset type(s)
			%>   - number: session number within the subject/date
			%>
			%> If `ref` contains an ALF-style reference string like
			%> `2023-07-12_001_MyMouse`, the method resolves it to the matching
			%> Alyx session by subject/date/number. If `ref` is a query name, the
			%> method treats it as the first parameter name and shifts the rest of
			%> the inputs accordingly.
			%>
			%> @param ref char|string|cell optional session reference or first
			%>   query parameter name. If omitted, the method uses only named
			%>   query parameters from `varargin`.
			%> @param varargin name-value pairs for query fields listed above.
			%> @return sessions cell array of session structs from Alyx.
			%> @return eids cell array of session IDs parsed from the session URLs.
			%>
			%> @example
			%>   [sessions, eids] = me.getSessions('subject', 'MyMouse', 'date_range', '2024-01-01,2024-01-31');
			%>   [sessions, eids] = me.getSessions({'2024-01-15_001_MyMouse'});
			arguments(Input)
				me alyxManager
				ref = {}
			end
			arguments(Repeating)
				varargin
			end
			arguments(Output)
				sessions
				eids
			end

			[sessions, results, eids] = deal({});
			queryNames = {'subject', 'users', 'lab', 'date_range', ...
				'dataset_types', 'number'};
			if isTextScalar(ref) && any(strcmpi(char(ref), queryNames))
				varargin = [{char(ref)}, varargin];
				ref = {};
			end

			p = inputParser;
			addParameter(p, 'subject', '');
			addParameter(p, 'users', '');
			addParameter(p, 'lab', '');
			addParameter(p, 'date_range', '', 'PartialMatchPriority', 2);
			addParameter(p, 'dataset_types', '');
			addParameter(p, 'number', []);
			parse(p, varargin{:});

			names = setdiff(fieldnames(p.Results), p.UsingDefaults, 'stable');
			values = cellfun(@processValue, names, 'UniformOutput', false);
			queries = cell(1, numel(names) * 2);
			queries(1:2:end) = names;
			queries(2:2:end) = values;

			if ~isempty(ref)
				refs = cellstr(ref);
				parsedRef = regexp(refs, me.alfMatch, 'names');
				sessFromRef = @(r)me.getData('sessions/', ...
					'subject', r.subject, ...
					'date_range', [r.date ',' r.date], ...
					'number', r.seq);
				isExpRef = ~cellfun(@isempty, parsedRef);
				sessions = [me.mapToCell(@(eid)me.getData(['sessions/' eid]), ...
					refs(~isExpRef)), me.mapToCell(sessFromRef, parsedRef(isExpRef))];
				sessions = me.rmEmpty(sessions);
			end

			if ~isempty(queries)
				results = me.getData('sessions', queries{:});
			end
			if isempty(sessions) && isempty(results); return; end
			sessions = me.catStructs([sessions, me.ensureCell(results)]);
			if nargout > 1
				eids = me.url2eid({sessions.url});
			end

			function tf = isTextScalar(value)
				tf = ischar(value) || (isstring(value) && isscalar(value));
			end

			function value = processValue(name)
				value = p.Results.(name);
				if contains(name, 'date')
					if isnumeric(value)
						value = me.iff(isscalar(value), repmat(value, 1, 2), value);
						value = string(datestr(value, 'yyyy-mm-dd'));
					elseif isTextScalar(value) && ~contains(string(value), ',')
						value = repmat(string(value), 1, 2);
					else
						error('Alyx:getSessions:InvalidInput', ...
							'The value of ''date_range'' is invalid')
					end
				end
				if iscellstr(value) || isstring(value)
					value = strjoin(value, ',');
				end
			end
		end
		% ===================================================================
		function subjects = listSubjects(me, stock, alive, sortByUser)
		% ===================================================================
			%> @brief Lists recorded subjects
			%>
			%> Lists the experimental subjects present in main repository. If
			%> logged in, returns a subject list generated from Alyx, with the
			%> option of filtering by stock (default false) and alive (default
			%> true). The sortByUser flag, when (default) true, returns the list
			%> with the user's animals at the top.
			%>
			%> @param stock logical filter by stock (default false)
			%> @param alive logical filter by alive status (default true)
			%> @param sortByUser logical sort user's animals first (default true)
			%> @return subjects cell array of subject names
			%>
			arguments
				me alyxManager
				stock logical = false
				alive logical = true
				sortByUser logical = true
			end

			if me.loggedIn % user provided an alyx instance
				% convert bool to string for endpoint
				alive = me.iff(islogical(alive)&&alive, 'True', 'False');
				stock = me.iff(islogical(stock)&&stock, 'True', 'False');

				% get list of all living, non-stock mice from alyx
				s = me.getData(sprintf('subjects?stock=%s&alive=%s', stock, alive));

				% return on empty
				if isempty(s); subjects = {'default'}; return; end

				% get cell array of subject names
				subjNames = {s.nickname};

				if sortByUser
					% determine the user for each mouse
					respUser = {s.responsible_user};

					% determine which subjects belong to this user
					thisUserSubs = sort(subjNames(strcmp(respUser, me.user)));

					% all the subjects
					otherUserSubs = sort(subjNames(~strcmp(respUser, me.user)));

					% the full, ordered list
					subjects = [{'default'}, thisUserSubs, otherUserSubs]';
				else
					subjects = [{'default'}, subjNames]';
				end
			else
				% The remote 'main' repositories are the reference for the existence of
				% experiments, as given by the folder structure
				subjects = [];
			end
		end

		function narrative = updateNarrative(me, comments, endpoint, subject)
		% ===================================================================
			%> @brief Update the narrative field for an Alyx session record
			%>
			%> This method retrieves a session record from Alyx, appends new
			%> narrative text to the existing `narrative` field, and sends a
			%> PATCH request to update the record. If no endpoint is provided, it
			%> uses `me.sessionURL` as the target session endpoint.
			%>
			%> The method accepts either direct narrative text or, when `comments`
			%> is empty, prompts the user with a dialog to enter narrative text.
			%> If the `subject` argument is provided, the method currently issues a
			%> warning and does not perform a subject narrative update.
			%>
			%> @param comments char|string Narrative text to append to the session.
			%> @param endpoint char URL or Alyx endpoint path of the session record.
			%> @param subject char Placeholder for subject narrative updates.
			%> @return narrative char The updated narrative string returned by Alyx.
			%>
			%> @example
			%>   narrative = me.updateNarrative('Experiment notes added', me.sessionURL);
			arguments
				me alyxManager
				comments {mustBeText} = ''
				endpoint {mustBeTextScalar} = ''
				subject {mustBeTextScalar} = ''
			end
			endpoint = char(endpoint);
			subject = char(subject);
			narrative = '';
			if isempty(endpoint)
				if isempty(me.sessionURL)
					error('Alyx:updateNarrative:NoEndpoint', ...
					'No endpoint specified and no sessionURL set');
				end
				endpoint = me.sessionURL;
			end

			if isempty(comments)
				if ~isempty(subject) && isempty(endpoint)
					titleStr = 'Update subject description';
				else
					titleStr = 'Update session narrative';
				end
				comments = inputdlg('Enter narrative:', titleStr, [10 60]);
				if isempty(comments); return; end
			end

			session = me.getData(endpoint);
			if isempty(session) || ~isfield(session, 'narrative')
				error('Alyx:updateNarrative:MissingNarrative', ...
					'Endpoint did not return a narrative field');
			end
			oldNarrative = string(session.narrative);
			newNarrative = strtrim(string(comments));
			newNarrative = replace(newNarrative, newline, '\n');
			newNarrative = strjoin(newNarrative, '\n');
			if strlength(newNarrative) == 0; return; end
			if strlength(oldNarrative) > 0
				narrative = char(strjoin([oldNarrative, newNarrative], '\n'));
			else
				narrative = char(newNarrative);
			end

			if ~isempty(subject)
				warning('Alyx:TODO', 'Subject narrative updates are not implemented');
				return
			end

			data = me.postData(endpoint, struct('narrative', narrative), 'patch');
			if isempty(data) || ~isfield(data, 'narrative')
				error('Alyx:updateNarrative:FailedToUpdate', ...
					'Failed to update narrative on Alyx');
			end
			narrative = strrep(data.narrative, '\n', newline);
		end


		% ===================================================================
		function [url, newSession] = createSession(me, path, sessionID, session, jsonData, startTime)
		% ===================================================================
			%> @brief Create a new unique experimental session in the database
			%>
			%> Creates a new experiment session in Alyx with the structure:
			%> subject/ |_ YYYY-MM-DD/ |_ sessionID/
			%>
			%> @param path char ALF path for the session
			%> @param sessionID integer experiment sequence number
			%> @param session struct with labName, subjectName, researcherName, location
			%> @param jsonData char JSON string (default '[]')
			%> @param startTime datetime optional override for start_time
			%> @return url char URL of created session
			%> @return newSession struct created session record
			%>
			%> Example:
			%>   [url, session] = createSession(me, '/path/to/alf', 1, sessionStruct)
			%>
			arguments (Input)
				me alyxManager
				path char
				sessionID double
				session struct
				jsonData string = "[]"
				startTime datetime = datetime.empty
			end
			arguments (Output)
				url char
				newSession struct
			end

			url = ''; newSession = [];

			% Ensure user is logged in
			if ~me.loggedIn; me.login; end

			% check items exists in the database, subject is necessary,
			% others optional
			assert(me.hasEntry('subjects',session.subjectName), 'Alyx:createSession:subjectNotFound', sprintf('subject "%s" does not exist', session.subjectName));
			if isfield(session,'researcherName') && ~me.hasEntry('users',session.researcherName)
				session = rmfield(session,'researcherName');
				session.researcherName = 'Unknown';

			end
			if isfield(session,'labName') && ~me.hasEntry('labs',session.labName)
				session = rmfield(session,'labName');
			end
			if isfield(session,'location') && ~me.hasEntry('locations',session.location)
				session = rmfield(session,'location');
			end
			if isfield(session,'project') && ~me.hasEntry('projects',session.project)
				session = rmfield(session,'project');
				session.project = 'Unknown';
			end
			if isfield(session,'procedure') && ~me.hasEntry('procedures',session.procedure)
				session = rmfield(session,'procedure');
			end

			me.sessionURL = '';
			me.sessionParentURL = '';

			% Use caller-supplied startTime when registering historical sessions,
			% otherwise default to now.
			if ~isempty(startTime)
				if isa(startTime,'datetime')
					expDate = char(startTime,'yyyy-MM-dd''T''HH:mm:ss');
				else
					expDate = char(startTime); % assume already formatted
				end
			else
				expDate = char(datetime("now",'Format','yyyy-MM-dd''T''HH:mm:ss'));
			end
			dayDate = expDate(1:10);

			% make sure the session is new
			request = ['sessions?date_range=' dayDate ',' dayDate '&subject=' session.subjectName '&number=' num2str(sessionID)];
			[sessions, statusCode] = me.getData(request);

			if statusCode == 200 && ~isempty(sessions)
				error("There is an existing session for ID = %i!!!", sessionID);
			end

			% Now create a new SESSION, using the experiment number
			d = struct;
			d.subject = session.subjectName;
			d.number = sessionID;
			d.start_time = expDate;
			d.projects = {session.project};
			try d.lab = session.labName; end
			try d.location = session.location; end
			try d.brain_region = session.brainRegion; end
			try d.task_protocol = session.taskProtocol; end
			try d.users = {session.researcherName}; end

			try
				[newSession, statusCode] = me.postData('sessions', d, 'post');
				if ~exist('newSession','var') || isempty(newSession); error("postData to Alyx returned an empty session"); end
				url = newSession.url;
				me.sessionURL = url;
			catch ME
				getReport(ME)
				if (isinteger(statusCode) && statusCode == 503)
					warning(ME.identifier, 'Failed to create session file for %i: %s.', sessionID, ME.message)
				else % Probably fatal user error
					rethrow(ME)
				end
			end
		end

		% ===================================================================
		function session = closeSession(me, narrative, QC, nTrials, nTrialsCorrect, jsonData)
		% ===================================================================
			%> @brief Close an Alyx session
			%>
			%> Closes the current session by setting end_time and optionally
			%> updating the narrative and QC fields.
			%>
			%> @param narrative char[] narrative text to add (optional)
			%> @param QC char quality control status (default 'NOT_SET')
			%> @return session struct the updated session record
			%>
			arguments
				me alyxManager
				narrative char = ''
				QC char = 'NOT_SET'
				nTrials double = NaN
				nTrialsCorrect double = NaN
				jsonData string = ""
			end
			if isempty(me.sessionURL); session = []; return; end
			session = [];
			[ses, s] = me.getData(me.sessionURL);

			if ~isempty(ses)
				if ~isempty(narrative)
					me.updateNarrative(narrative);
				end
				d.qc = QC;
				d.end_time = char(datetime("now",'Format','yyyy-MM-dd''T''HH:mm:ss'));
				if ~isnan(nTrials) && nTrials >= 0
					d.n_trials = nTrials;
				end
				if ~isnan(nTrialsCorrect) && nTrialsCorrect >= 0
					d.n_trials_correct = nTrialsCorrect;
				end
				if jsonData ~= ""
					d.json = [jsonData];
				end
				session = me.postData(['sessions/' ses.id], d, 'patch');
			end
		end

		% ===================================================================
		function [fullpath, filename, fileID, records] = expFilePath(me, varargin)
		% ===================================================================
			%> @brief Full path for file pertaining to designated experiment
			%>
			%> Returns the path(s) that a particular type of experiment file should
			%> be located at for a specific experiment. NB: Unlike dat.expFilePath,
			%> this CAN NOT be used to determine where a file should be saved to.
			%> This function only returns existing file records from Alyx.
			%>
			%> @param varargin Arguments describing the experiment and dataset type.
			%>   Accepted forms:
			%>     1) (ref, type)
			%>        - ref: ALF-style experiment reference string
			%>          `YYYY-MM-DD_NNN_Subject`
			%>        - type: Alyx dataset type name
			%>
			%>     2) (ref, type, user)
			%>        - user: dataset creator / Alyx `created_by` filter
			%>
			%>     3) (ref, type, user, reposlocation)
			%>        - reposlocation: Alyx repository location name
			%>
			%>     4) (subject, date, seq, type)
			%>        - subject: subject nickname string
			%>        - date: MATLAB date string or datetime
			%>        - seq: experiment sequence number
			%>        - type: Alyx dataset type name
			%>
			%>     5) (subject, date, seq, type, user)
			%>     6) (subject, date, seq, type, user, reposlocation)
			%>
			%> @return fullpath char[] full file paths
			%> @return filename char[] file names
			%> @return fileID char[] file UUIDs
			%> @return records struct[] complete records from Alyx
			%>

			% Validate input
			assert(nargin > 2, 'Error: Not enough arguments supplied.')

			% Flag for searching by session start time, rather than dataset created
			% time (see below)
			strictSearch = true;

			parsed = regexp(varargin{1}, me.alfMatch, 'tokens');
			if isempty(parsed) % Subject, not ref
				subject = varargin{1};
				expDate = varargin{2};
				seq = varargin{3};
				type = varargin{4};
				varargin(1:4) = [];
			else % Ref, not subject
				subject = parsed{1}{3};
				expDate = parsed{1}{1};
				seq = parsed{1}{2};
				type = varargin{2};
				varargin(1:2) = [];
			end

			% Check date
			if ~ischar(expDate)
				expDate = datestr(expDate, 'yyyy-mm-dd');
			elseif ischar(expDate) && length(expDate) > 10
				expDate = expDate(1:10);
			end

			if length(varargin) > 1 % Repository location defined
				user = varargin{1};
				location = varargin{2};
				% Validate repository
				repos = catStructs(me.getData('data-repository'));
				idx = strcmpi(location, {repos.name});
				assert(any(idx), 'Alyx:expFilePath:InvalidType', ...
					'Error: ''%s'' is an invalid data set type', location)
				location = repos(idx).name; % Ensures correct case
			elseif ~isempty(varargin)
				user = varargin{1};
				location = [];
			else
				location = [];
				user = '';
			end

			% Validate type
			dataSets = catStructs(me.getData('dataset-types'));
			idx = strcmpi(type, {dataSets.name});
			assert(any(idx), 'Alyx:expFilePath:InvalidType', ...
			'Error: ''%s'' is an invalid data set type', type)
			type = dataSets(idx).name; % Ensures correct case

			% Construct the endpoint
			% FIXME: datasets endpoint filters no longer work
			% @body because of this we must make a seperate query to obtain the
			% datetime.  Querying the sessions takes around 3 seconds.  Otherwise we
			% filter by created time under the assumption that the dataset was created
			% on the same day as the session.  See https://github.com/cortex-lab/alyx/issues/601
			if strictSearch
				endpoint = sprintf(['/datasets?'...
					'subject=%s&'...
					'experiment_number=%s&'...
					'dataset_type=%s&'...
					'created_by=%s'],...
					subject, num2str(seq), type, user);
				records = me.getData(endpoint);
				if ~isempty(records)
					sessions = me.getSessions(me.url2eid({records.session}));
					records = records(floor(me.datenum({sessions.start_time})) == datenum(expDate));
				end
			else
				endpoint = sprintf(['/datasets?'...
					'subject=%1$s&'...
					'experiment_number=%2$s&'...
					'dataset_type=%3$s&'...
					'created_by=%4$s&'...
					'created_datetime_gte=%5$s&'...
					'created_datetime_lte=%5$s'],...
					subject, num2str(seq), type, user, expDate);
				records = me.getData(endpoint);
			end
			% Construct the endpoint
			% endpoint = sprintf('/datasets?subject=%s&date=%s&experiment_number=%s&dataset_type=%s&created_by=%s',...
			%   subject, expDate, num2str(seq), type, user);
			% records = me.getData(endpoint);

			if ~isempty(records)
				data = me.catStructs(records);
				fileRecords = me.catStructs([data(:).file_records]);
			else
				fullpath = [];
				filename = [];
				fileID = [];
				return
			end

			if ~isempty(location)
				% Remove records in unwanted repo locations
				idx = strcmp({fileRecords.data_repository}, location);
				fileRecords = fileRecords(idx);
			end

			% Get the full paths
			mkPath = @(x) me.iff(isempty(x.data_url), ... % If data url not present
			[x.data_repository_path x.relative_path], ... % make path from repo path and relative path
			x.data_url); % otherwise use data_url field
			% Make paths
			fullpath = arrayfun(mkPath, fileRecords, 'uni', 0);
			filename = {data.name};
			fileID = {fileRecords.id};

			% If only one record was returned, don't return a cell array
			if isscalar(fullpath)
				fullpath = fullpath{1};
				filename = filename{1};
				fileID = fileID{1};
			end
		end

		% ===================================================================
	function [datasets, success] = registerFile(me, rFiles, useQueue)
		% ===================================================================
			%> @brief Register file(s) with Alyx using the `register-file` endpoint
			%>
			%> This method posts a `register-file` payload to Alyx for one or more
			%> files. The input struct must follow the Alyx `register-file` schema,
			%> including repository name, path, filenames, SHA1 hashes, and file
			%> sizes.
			%>
			%> @param rFiles struct Payload for Alyx `register-file` request.
			%>   Expected fields include:
			%>     - name: repository name in Alyx
			%>     - path: subject/date/number path
			%>     - filenames: cell array of filenames
			%>     - hashes: SHA1 hashes for each file
			%>     - bytes: file sizes in int32 bytes
			%>     - created_by: user uploading the files
			%> @return datasets struct Alyx response for the registered file records.
			%> @return success logical True when registration succeeds (HTTP 201).
			%>
			%> @see https://openalyx.internationalbrainlab.org/docs/#register-file

			arguments(Input)
				me
				rFiles struct
				useQueue logical = true
			end

			success = false;

			if isempty(fieldnames(rFiles)); warning('alyxManager.register file incorrect input'); end

			[datasets, statusCode] = me.postData('register-file', rFiles, 'post', useQueue);

			if statusCode ~= 201
				warning('HTTP Error %i -- No file registering', statusCode)
				disp(datasets)
			else
				success = true;
			end

		end

		% ===================================================================
		function [datasets, filenames, success] = registerALFFiles(me, paths, session)
		% ===================================================================
		%> @brief Register all files in an ALF path with Alyx
		%>
		%> This method collects every file from `paths.ALFPath`, validates each
		%> filename against the Alyx `dataset-types` filename patterns, and
		%> registers the files using `registerFile()`.
		%>
		%> @param paths struct Contains `ALFPath` and `ALFKeyShort` for the
		%>   current ALF session.
		%> @param session struct Contains Alyx session metadata such as
		%>   `dataBucket`, `labName`, and `researcherName`.
		%> @return datasets struct Alyx response for the registered files.
		%> @return filenames cell Full path names of registered files.
		%>
		%> @see registerFile
		% ===================================================================
			arguments(Input)
				me
				paths struct
				session struct
			end
			arguments(Output)
				datasets struct
				filenames cell
				success logical
			end

			sFiles = dir(paths.ALFPath);
			sFiles = sFiles(~[sFiles(:).isdir]);

			% Validate that each ALF file matches an Alyx dataset-type filename pattern.
			datasetTypes = me.getData('dataset-types');
			if isempty(datasetTypes)
				error('Alyx:registerALFFiles:NoDatasetTypes', ...
					'Unable to retrieve Alyx dataset types for filename validation');
			end
			datasetPatterns = {datasetTypes.filename_pattern};
			datasetPatterns(cellfun(@isempty, datasetPatterns)) = {''};
			invalidFiles = string.empty;
			validMask = true(1, numel(sFiles));
			for ii = 1:numel(sFiles)
				name = sFiles(ii).name;
				matchIdx = regexp(name, regexptranslate('wildcard', datasetPatterns));
				if all(cellfun(@isempty, matchIdx))
					invalidFiles(end+1) = string(name); %#ok<AGROW>
					validMask(ii) = false;
				end
			end
			if ~isempty(invalidFiles)
				warning('Alyx:registerALFFiles:InvalidFilename', ...
					'The following files were skipped because they did not match any Alyx dataset-type filename patterns:\n%s', ...
					strjoin(invalidFiles, '\n'));
				sFiles = sFiles(validMask);
			end
			if isempty(sFiles)
				datasets = struct.empty;
				filenames = {};
				return;
			end

			for ii = 1:length(sFiles)
				filenames{ii} = fullfile(sFiles(ii).folder, sFiles(ii).name);
				bytes(ii) = sFiles(ii).bytes;
				hashes{ii} = DataHash(filenames{ii},'file','sha1');
			end

			rf = struct('name',session.dataBucket);
			rf.path = paths.ALFKeyShort;
			rf.filenames = filenames;
			rf.hashes = hashes;
			rf.filesizes = int32(bytes);
			rf.labs = session.labName;
			try rf.created_by = session.researcherName; end

			[datasets, success] = registerFile(me, rf);

		end

		% ===================================================================
		function initDatabase(me)
		% ===================================================================

			% opticka.raw*.mat dataset type is used to store the raw data from the opticka system for a single session
			[r, s] = getData(me,'dataset-types/opticka.raw');
			if s ~= 200
				d = struct;
				d.name = 'opticka.raw';
				d.created_by = me.user;
				d.description = "Opticka raw mat file for single session";
				d.filename_pattern = "opticka.raw.*.mat";
				[r, s] = me.postData('dataset-types', d, 'post');
				if isempty(r)
					warning("Couldn't create opticka.raw dataset type");
				end
			end
			% opticka.raw*.mat dataset type is used to store the raw data from the opticka system for a single session
			[r, s] = getData(me,'dataset-types/matlab.raw');
			if s ~= 200
				d = struct;
				d.name = 'matlab.raw';
				d.created_by = me.user;
				d.description = "MATLAB raw mat file for single session";
				d.filename_pattern = "matlab.raw.*.mat";
				[r, s] = me.postData('dataset-types', d, 'post');
				if isempty(r)
					warning("Couldn't create matlab.raw dataset type");
				end
			end
			% _matlab_diary dataset type is used to store the MATLAB diary for a single session
			[r, s] = getData(me,'dataset-types/_matlab_diary');
			if s ~= 200
				d = struct;
				d.name = '_matlab_diary';
				d.created_by = me.user;
				d.description = "Recording the output from MATLAB's command window using Diary function";
				d.filename_pattern = "_matlab_diary.*.log";
				[r, s] = me.postData('dataset-types', d, 'post');
				if isempty(r)
					warning("Couldn't create _matlab_diary dataset type");
				end
			end
			% opticka.details dataset type is used to store JSON of experiment details
			[r, s] = getData(me,'dataset-types/opticka.details');
			if s ~= 200
				d = struct;
				d.name = 'opticka.details';
				d.created_by = me.user;
				d.description = "JSON of experiment details";
				d.filename_pattern = "opticka.details.*.json";
				[r, s] = me.postData('dataset-types', d, 'post');
				if isempty(r)
					warning("Couldn't create opticka.details dataset type");
				end
			end
			% events.table dataset type is used to store TSV event tables with HED tag mapping
			[r, s] = getData(me,'dataset-types/events.table');
			if s ~= 200
				d = struct;
				d.name = 'events.table';
				d.created_by = me.user;
				d.description = "Events table with HED tag mapping";
				d.filename_pattern = "events.table.*.tsv";
				[r, s] = me.postData('dataset-types', d, 'post');
				if isempty(r)
					warning("Couldn't create events.table dataset type");
				end
			end
			% eyetracking.raw.tobii dataset type is used to store the raw data from the Tobii eyetracker for a single session
			[r, s] = getData(me,'dataset-types/eyetracking.raw.tobii');
			if s ~= 200
				d = struct;
				d.name = 'eyetracking.raw.tobii';
				d.created_by = me.user;
				d.description = "Raw Tobii eyetracking data";
				d.filename_pattern = "eyetracking.raw.tobii*.mat";
				[r, s] = me.postData('dataset-types', d, 'post');
				if isempty(r)
					warning("Couldn't create eyetracking.raw.tobii*.mat dataset type");
				end
			end
			% eyetracking.raw.irec dataset type is used to store the raw data from the iRec eyetracker for a single session
			[r, s] = getData(me,'dataset-types/eyetracking.raw.irec');
			if s ~= 200
				d = struct;
				d.name = 'Raw iRec eyetracking data';
				d.created_by = me.user;
				d.description = "Raw iRec eyetracking data";
				d.filename_pattern = "eyetracking.raw.irec*";
				[r, s] = me.postData('dataset-types', d, 'post');
				if isempty(r)
					warning("Couldn't create eyetracking.raw.irec dataset type");
				end
			end
			% 
			[r, s] = getData(me,'dataset-types/eyetracking.raw.eyelink');
			if s ~= 200
				d = struct;
				d.name = 'Raw iRec eyetracking data';
				d.created_by = me.user;
				d.description = "Raw Eyelink EDF file";
				d.filename_pattern = "eyetracking.raw.eyelink*.edf";
				[r, s] = me.postData('dataset-types', d, 'post');
				if isempty(r)
					warning("Couldn't create eyetracking.raw.irec dataset type");
				end
			end
		end

		% ===================================================================
		function bool = get.loggedIn(me)
		% ===================================================================
			bool = ~isempty(me.user) && ~isempty(me.token);
		end

		% ===================================================================
		function set.queueDir(me, qDir)
		% ===================================================================
			%SET.QUEUEDIR Ensure directory exists
			if ~exist(qDir, 'dir'); mkdir(qDir); end
			me.queueDir = qDir;
		end

		% ===================================================================
		function set.baseURL(me, value)
		% ===================================================================
			%> Normalize Alyx base URLs to a protocol-qualified URL with no trailing slash.
			if isstring(value) && isscalar(value)
				value = char(value);
			end
			if ~ischar(value) || isempty(strtrim(value))
				error('Alyx:baseURL:invalidInput', 'baseURL must be a non-empty text scalar');
			end
			value = strtrim(value);
			if ~startsWith(value, {'http://', 'https://'})
				value = ['https://' value];
			end
			me.baseURL = regexprep(value, '/+$', '');
		end


		% ===================================================================
		function set.verbose(me, value)
		% ===================================================================
			if ~islogical(value) || ~isscalar(value)
				error('MATLAB:validators:mustBeA', ...
					'verbose must be a scalar logical');
			end
			me.verbose = value;
		end

		% =========================end==========================================
		function set.user(me, value)
		% ===================================================================
			if ~matches(me.user, value)
				%if me.loggedIn; logout(me); end
				%fprintf('≣≣≣≣⊱ User name change, logged out!\n');
			end
			me.user = value;
		end

	%=======================================================================
	end %---END PUBLIC METHODS---%
	%=======================================================================

	%=======================================================================
	methods (Hidden = true)
	%=======================================================================

		% ===================================================================
		% GETSECRETS Function to retrieve user secrets
		%
		% Input Arguments:
		%     me - object containing user credentials
		%
		% Output Arguments:
		%     secrets - structure containing user credentials
		function secrets = getSecrets(me)
			% Extract user credentials from the object
			secrets.user = me.user;
			secrets.password = me.password;
			secrets.AWS_KEY = me.AWS_KEY;
			secrets.AWS_ID = me.AWS_ID;
		end

		% ===================================================================
		% SECRETUI Function to securely handle password input
		%
		% Input Arguments:
		%     me    - Instance of alyxManager
		%     field - Field name to store the password, default is 'password'
		function secretUI(me,field)
			arguments (Input)
				me alyxManager
				field char = 'password'
			end
			switch field
				case 'password'
					secret = 'AlyxPassword';
				case {'AWS_ID', 'AWS_KEY'}
					secret = field;
				otherwise
					return
			end
			noDisplay = false;
			try noDisplay = usejava('jvm') && ~feature('ShowFigureWindows'); end
    		if noDisplay
        		% Temporarily disable diary logging to avoid storing the password
        		diaryState = get(0, 'Diary');
        		diary('off'); % At minimum we can keep out of diary log file
        		passwd = input('Alyx password <strong>**INSECURE**</strong>: ', 's');
        		me.(field) = passwd; % Store the entered password in the object
        		diary(diaryState); % Restore the previous diary state
    		else
        		setSecret(secret, Overwrite=true); % Get secret through a user interface
        		me.(field) = getSecret(secret); % Store the entered password in the object
    		end
		end

	%=======================================================================
	end %---END HIDDEN METHODS---%
	%=======================================================================

	%=======================================================================
	methods ( Access = protected ) %-------PRIVATE (protected) METHODS-----%
	%=======================================================================

		% ===================================================================
		function [me, statusCode] = getToken(me, username, password)
			%GETTOKEN Acquire an authentication token for Alyx
			%   Makes a request for an authentication token to an Alyx instance;
			%   returns the token and status code.
			%
			% Example:
			% statusCode = getToken('https://alyx.cortexlab.net', 'max', '123')
			%
			% See also ALYX, LOGIN
			[statusCode, responseBody] = me.jsonPost('auth-token',...
			['{"username":"', username, '","password":"', password, '"}']);

			if statusCode == 200
				me.token = responseBody.token;
				me.user = username;
				me.assignedUser = me.user;
				% Add the token to the authorization header field
				me.webOptions.HeaderFields = {'Authorization', ['Token ' me.token]};
				% Flush the local queue on successful login
				me.flushQueue(true);
			elseif statusCode == 403
				j = ['{"username":"', username, '","password":"', password, '"}'];
				cmd = ['LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu curl -X POST ' me.makeEndpoint('auth-token') ' -H "Content-Type: application/json" -d ''' j ''' ' ];
				[r,tc] = system(cmd); %can we fix using curl directly?
				if r == 0
					tc = jsondecode(tc);
					if isfield(tc,'token')
						me.token = tc.token;
						me.user = username;
						me.assignedUser = me.user;
						me.webOptions.HeaderFields = {'Authorization', ['Token ' me.token]};
						me.flushQueue(true);
						statusCode = 200;
					end
				end

			elseif statusCode == 000
				me.assignedUser = '';
				me.token = '';
				error('Alyx:Login:FailedToConnect', responseBody)
			elseif statusCode == 400 && isempty(password)
				me.assignedUser = '';
				me.token = '';
				error('Alyx:Login:PasswordEmpty', 'Password may not be left blank')
			else
				me.assignedUser = '';
				me.token = '';
				error(responseBody)
			end
		end

		% ===================================================================
		function fullEndpoint = makeEndpoint(me, endpoint)
		% ===================================================================
			arguments
				me alyxManager
				endpoint {mustBeTextScalar}
			end
			endpointWasString = isstring(endpoint);
			endpoint = char(endpoint);
			if isempty(strtrim(endpoint))
				error('Alyx:makeEndpoint:invalidInput', 'Invalid endpoint');
			end
			endpoint = strtrim(endpoint);
			if startsWith(endpoint, {'http://', 'https://'})
				fullEndpoint = regexprep(endpoint, '/+$', '');
			else
				endpoint = regexprep(endpoint, '^/+', '');
				fullEndpoint = regexprep([me.baseURL '/' endpoint], '/+$', '');
			end
			if endpointWasString
				fullEndpoint = string(fullEndpoint);
			end
		end

		% ===================================================================
		function [statusCode, responseBody] = jsonPost(me, endpoint, jsonData, requestMethod)
		% ===================================================================
			%> @brief Makes POST, PUT and PATCH requests with JSON body
			%>
			%> Makes a POST request, with a JSON request body, asking for a
			%> JSON response.
			%>
			%> @param endpoint char REST API endpoint to make the request to
			%> @param jsonData char JSON string to use as request body
			%> @param requestMethod char HTTP method: 'post'(default),'put','patch','delete'
			%> @return statusCode integer HTTP response code
			%> @return responseBody char[] response body or data struct
			%>
			%> @see JSONGET, JSONPUT, JSONPATCH
			arguments
				me alyxManager
				endpoint char
				jsonData char
				requestMethod char = 'post'
			end
			% Validate the inputs
			endpoint = me.makeEndpoint(endpoint); % Ensure absolute URL
			assert(any(strcmpi(requestMethod, {'post', 'put', 'patch', 'delete'})),...
			'%s not a valid HTTP request method', requestMethod)
			% Set the HTTP request method in options
			options = me.webOptions;
			options.RequestMethod = lower(requestMethod);
			responseBody = [];
			try % Post data
				responseBody = webwrite(endpoint, jsonData, options);
				if endsWith(endpoint,'auth-token')
					statusCode = 200;
				else
					statusCode = 201;
				end
			catch ex
				disp("=== Response Body:")
				try disp(responseBody); end
				getReport(ex)
				responseBody = ex.message;
				switch ex.identifier
				case 'MATLAB:webservices:UnknownHost'
					% Can't resolve URL
					warning(ex.identifier, '%s Posting temporarily supressed', ex.message)
					statusCode = 000;
				case {'MATLAB:webservices:CopyContentToDataStreamError'
					'MATLAB:webservices:SSLConnectionFailure'
					'MATLAB:webservices:Timeout'}
				% Connection refused or timed out, set as headless and continue on
					warning(ex.identifier, '%s. Posting temporarily supressed', ex.message)
					statusCode = 000;
				otherwise
					response = regexp(ex.message, '(?:the status )(?<status>\d{3}).*"(?<message>.+)"', 'names');
					if ~isempty(response)
						statusCode = str2double(response.status);
						responseBody = response.message;
					else
						statusCode = 000;
						responseBody = ex.message;
					end
				end
			end
		end

		% ===================================================================
		function [data, statusCode] = flushQueue(me, dontSend)
		% ===================================================================
			%> @brief Checks for and uploads queued data to Alyx
			arguments
				me alyxManager
				dontSend logical = false
			end
			data = [];
			statusCode = [];
			if isempty(me.queueDir) || ~exist(me.queueDir, 'dir')
				me.queueDir = me.paths.parent;
			end

			queuePatterns = {'*.post', '*.put', '*.patch'};
			alyxQueue = [];
			for ii = 1:numel(queuePatterns)
				alyxQueue = [alyxQueue; dir(fullfile(me.queueDir, queuePatterns{ii}))]; %#ok<AGROW>
			end
			if isempty(alyxQueue); return; end

			alyxQueueFiles = sort(arrayfun(@(x) fullfile(x.folder, x.name), ...
				alyxQueue, 'UniformOutput', false));
			if dontSend
				cellfun(@delete, alyxQueueFiles);
				return
			end

			statusCode = ones(1, numel(alyxQueueFiles)) * 401;
			responses = cell(1, numel(alyxQueueFiles));
			for currFile = 1:numel(alyxQueueFiles)
				[~, queueName, uploadType] = fileparts(alyxQueueFiles{currFile});
				uploadType = uploadType(2:end);
				fid = fopen(alyxQueueFiles{currFile}, 'r');
				cleanup = onCleanup(@() fclose(fid));
				endpoint = fgetl(fid);
				jsonData = fscanf(fid, '%c');
				clear cleanup

				try
					[statusCode(currFile), responseBody] = ...
						me.jsonPost(endpoint, jsonData, uploadType);
					switch floor(statusCode(currFile) / 100)
						case {2, 3}
							responses{currFile} = responseBody;
							delete(alyxQueueFiles{currFile});
						case 4
							if statusCode(currFile) == 403
								me.logout();
								warning('Alyx:flushQueue:InvalidToken', ...
									'%s (%i): %s saved in queue', responseBody, ...
									statusCode(currFile), queueName);
							else
								delete(alyxQueueFiles{currFile});
								warning('Alyx:flushQueue:BadUploadCommand', ...
									'%s (%i): %s', responseBody, statusCode(currFile), queueName);
							end
						case 5
							warning('Alyx:flushQueue:InternalServerError', ...
								'%s (%i): %s saved in queue', responseBody, ...
								statusCode(currFile), queueName);
					end
				catch ex
					if strcmp(ex.identifier, 'MATLAB:weboptions:unrecognizedStringChoice')
						warning('Alyx:flushQueue:MethodNotSupported', ...
							'%s method not supported', upper(uploadType));
					else
						warning('Alyx:flushQueue:NotConnected', ...
							'Alyx upload failed - saved in queue');
					end
				end
			end
			responses = responses(~cellfun('isempty', responses));
			if ~isempty(responses)
				data = alyxManager.catStructs(alyxManager.cellflat(responses));
			end
		end
		% ===================================================================
		%> @fn Delete method
		%>
		%> @param me
		%> @return
		% ===================================================================
		function delete(me)
			if me.verbose; fprintf('≣≣≣≣⊱ Delete: %s\n',me.fullName); end
		end

	%=======================================================================
	end %---END PRIVATE METHODS---%
	%=======================================================================

	%=======================================================================
	methods ( Static ) %----------STATIC METHODS
	%=======================================================================

		% ===================================================================
		function [a, wrapped] = ensureCell(a)
		% ===================================================================
			%ENSURECELL If arg not already a cell array, wrap it in one
			if ~iscell(a);a = {a};wrapped = true; else; wrapped = false;end
		end

		% ===================================================================
		function flat = cellflat(c)
		% ===================================================================
			flat = {};
			for i = 1:numel(c)
				elem = c{i};
				if iscell(elem); elem = alyxManager.cellflat(elem); end
				if isempty(elem); elem = {elem}; end
				flat = [flat; alyxManager.ensureCell(elem)];
			end
		end

		% ===================================================================
		function passed = rmEmpty(A)
		% ===================================================================
			if iscell(A)
				empty = cellfun('isempty', A);
			else
				empty = arrayfun(@isempty, A);
			end
			passed = A(~empty);
		end

		% ===================================================================
		function [C1, varargout] = mapToCell(f, varargin)
		% ===================================================================
			%MAPTOCELL Like cellfun and arrayfun, but always returns a cell array
			%   [C1, ...] = MAPTOCELL(FUN, A1, ...) applies the function FUN to
			%   each element of the variable number of arrays A1, A2, etc, passed in. The
			%   outputs of FUN are used to build up cell arrays for each output.
			%
			%   Unlike MATLAB's cellfun and arrayfun, MAPTOCELL(..) can take a mixture
			%   of standard and cell arrays, and will always output a cell array (which
			%   for cellfun and array requires the 'UniformOutput' = false flag).
			nelems = numel(varargin{1});
			% ensure all input array arguments have the same size (todo: check shape)
			assert(all(nelems == cellfun(@numel, varargin)),'Not all arrays have the same number of elements');
			inSize = size(varargin{1});
			nout = max(nargout, min(nargout(f), 1));
			% function that converts non-cell arrays to cell arrays
			ensureCell = @(a) alyxManager.iff(~iscell(a), @() num2cell(a), a);
			% make sure all input arguments are cell arrays...
			varargin = cellfun(ensureCell, varargin, 'UniformOutput', false);
			% ...so now we can concatenate them and treat them as cols in a table and
			% read them row-wise
			catarrays = cat(ndims(varargin{1}), varargin{:});
			linarrays = reshape(catarrays, nelems, numel(varargin));
			fout = cell(nout, 1);
			arg = cell(nout, nelems);
			% iterate over each element of input array(s), apply f, and save each (variable
			% number of) output.
			for i = 1:nelems
				[fout{1:nout}] = f(linarrays{i,:});
				arg(1:nout,i) = fout(1:nout);
			end
			varargout = cell(nargout - 1, 1);
			for i = 1:nout
				if i == 1
					C1 = reshape(arg(i,:), inSize);
				else
					varargout{i - 1} = reshape(arg(i,:), inSize);
				end
			end
		end

		% ===================================================================
		function s = catStructs(cellOfStructs, missingValue)
		% ===================================================================
			%> @brief Concatenates different structures into one structure array
			%>
			%> Returns a non-scalar structure made from concatenating the
			%> structures in `cellOfStructs` and optionally replacing any missing
			%> values. NB: all empty values in the output struct are replaced by
			%> `missingValue`, including ones present in the original input.
			%>
			%> @param cellOfStructs cell cell array of structs to concatenate
			%> @param missingValue any value to replace missing fields with
			%> @return s struct concatenated structure array
			%>
			%> Example:
			%>   s = catStructs({struct1, struct2}, NaN)
			%>
			%> @see ALYX
			arguments
				cellOfStructs cell
				missingValue = []
			end
			fields = unique(alyxManager.cellflat(alyxManager.mapToCell(@fieldnames, cellOfStructs)));
			function t = valueTable(s)
				if ~isrow(s); s = reshape(s, 1, []); end
				t =  alyxManager.mapToCell(@(f) alyxManager.pick(s, f, 'cell', 'def', missingValue), fields);
				t = vertcat(t{:});
			end
			values = alyxManager.mapToCell(@valueTable, cellOfStructs);
			values = horzcat(values{:});
			if numel(values) > 0; s = cell2struct(values, fields); else; s = struct([]); end
		end

		% ===================================================================
		function v = pick(from, key, varargin)
		% ===================================================================
			%PICK Retrieves indexed elements from arrays, structs, objects, maps, or cells.
			if iscell(key)
				v = alyxManager.mapToCell(@(k) alyxManager.pick(from, k, varargin{:}), key);
				return
			end

			stringArgs = cellfun(@ischar, varargin);
			[withDefault, default] = alyxManager.namedArg(varargin, 'def');
			cellOut = any(strcmpi(varargin(stringArgs), 'cell'));
			if isa(from, 'containers.Map')
				v = alyxManager.iff(withDefault && ~from.isKey(key), ...
					default, @() from(key));
			elseif ischar(key) || isStringScalar(key)
				key = char(key);
				if ~iscell(from)
					if cellOut
						if ~withDefault
							v = reshape({from.(key)}, size(from));
						elseif isfield(from, key) || isAProp(from, key)
							v = reshape({from.(key)}, size(from));
							[v{cellfun(@isempty, v)}] = deal(default);
						else
							v = repmat({default}, size(from));
						end
					else
						if ~withDefault
							if isscalar(from)
								v = from.(key);
							else
								v = reshape([from.(key)], size(from));
							end
						else
							asCell = alyxManager.pick(from, key, varargin{:}, 'cell');
							v = alyxManager.iff(isscalar(asCell), ...
								@() asCell{1}, @() cell2mat(asCell));
						end
					end
				else
					if cellOut
						v = alyxManager.mapToCell(@(e) ...
							alyxManager.pick(e, key, varargin{:}), from);
					else
						v = cellfun(@(e) alyxManager.pick(e, key, varargin{:}), from);
					end
				end
			elseif iscell(from)
				if cellOut
					v = from(key);
				else
					v = [from{key}];
				end
			else
				v = from(key);
				if cellOut
					v = num2cell(v);
				end
			end

			function b = isAProp(v, name)
				if isstruct(v) || isempty(v)
					b = false;
				else
					b = isprop(v, name);
				end
			end
		end
		% ===================================================================
		function [present, value, idx] = namedArg(args, name)
		% ===================================================================
			%NAMEDARG Returns value from name,value argument pairs.
			matches = @(s)(ischar(s) || isStringScalar(s)) && strcmpi(s, name);
			idx = find(cellfun(matches, args), 1);
			if ~isempty(idx)
				present = true;
				value = args{idx + 1};
			else
				present = false;
				value = [];
			end
		end
		% ===================================================================
		function eid = url2eid(url)
		% ===================================================================
			% URL2EID Return eid portion of Alyx URL.
			if iscell(url)
				eid = alyxManager.mapToCell(@alyxManager.url2eid, url);
				return
			end
			if isstring(url) && isscalar(url)
				url = char(url);
			end
			eidLength = 36;
			assert(ischar(url) && numel(url) >= eidLength, ...
				'Alyx:url2Eid:InvalidURL', 'URL may not contain eid')
			url = strip(url, 'right', '/');
			eid = url(end-eidLength+1:end);
		end
		% ===================================================================
		function [ref, AlyxInstance] = parseAlyxInstance(varargin)
		% ===================================================================
			%> @brief Converts input to string for UDP message and back
			%>
			%> @param varargin can be (ref, AlyxInstance) or (UDP_string)
			%> @return ref either JSON string or expRef depending on call mode
			%> @return AlyxInstance either empty or Alyx object depending on call mode
			%>
			%> @see SAVEOBJ, LOADOBJ
			if length(varargin) > 1 % in [ref, AlyxInstance]
				ref = varargin{1}; % extract expRef
				ai = varargin{2}; % extract AlyxInstance struct
				if isa(ai, 'Alyx') % if there is an AlyxInstance
					d = ai.saveobj;
				end
				d.expRef = ref; % Add expRef field
				ref = jsonencode(d); % Convert to JSON string
			else % in [UDP_string]
				s = jsondecode(varargin{1}); % Convert JSON to structure
				ref = s.expRef; % Extract the expRef
				AlyxInstance = Alyx('',''); % Create empty Alyx object
				if numel(fieldnames(s)) > 1 % Assume to be Alyx object as struct
					AlyxInstance = AlyxInstance.loadobj(s); % Turn into object
				end
			end
		end

		% ===================================================================
		function [varargout] = iff(cond, evalTrue, evalFalse)
		% ===================================================================
			%IFF 'if' expression implementation
			%   v = IFF(cond, evalTrue, evalFalse) returns 'evalTrue' if 'cond' is true,
			%   otherwise returns 'evalFalse'.
			%
			%   This enables you to write succint one-liners like:
			%   signstr = iff(x > 0, 'positive', 'negative');
			%
			%   Either of 'evalTrue' or 'evalFalse' can be functions, in which case
			%   the result of their execution is returned, but only the returned one
			%   will be executed. This allows for evaluations which only make sense
			%   depedent on the condition, e.g.:
			%   added = iff(ischar(x), @() [x x], @() x + x)
			if isa(cond, 'function_handle'); cond = cond(); end
			if cond; result = evalTrue; else; result = evalFalse; end

			if isa(result, 'function_handle')
			if nargout == 0 || nargout(result) == 0
				result();
				varargout = {};
			else
				[varargout{1:nargout}] = result();
			end
			else
			varargout = {result};
			end
		end

	end%---END STATIC METHODS---%
end
