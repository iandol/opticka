% ========================================================================
classdef alyxManager < optickaCore
%> @class alyxManager
%> @brief manage connection to an Alyx database
%>
%>
%> Copyright ©2014-2024 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ========================================================================


	%--------------------PUBLIC PROPERTIES----------%
	properties
		baseURL	char			= 'http://172.16.102.30:8000'
		user char				= 'admin'
		queueDir char			= ''
		sessionURL				= []
		pageLimit				= 100
		verbose					= false
	end

	%--------------------TRANSIENT PROPERTIES-----------%
	properties (Transient = true)
		webOptions				= weboptions('MediaType','application/json','Timeout',10);
	end

	%--------------------HIDDEN PROPERTIES-----------%
	properties(Transient = true, Hidden = true)
		pwd						= ''
	end
	
	%--------------------VISIBLE PROPERTIES-----------%
	properties (SetAccess = protected, GetAccess = public)
		alyx					= []
	end
	
	%--------------------DEPENDENT PROTECTED PROPERTIES----------%
	properties (GetAccess = public, Dependent = true)
		loggedIn
	end
	
	%--------------------TRANSIENT PROTECTED PROPERTIES----------%
	properties (Access = protected, Transient = true)
		token
	end
	
	%--------------------PROTECTED PROPERTIES----------%
	properties (Access = protected)
		
	end
	
	%--------------------PRIVATE PROPERTIES----------%
	properties (Access = private)
		%> properties allowed to be passed on construction
		allowedProperties = {'baseURL','user','pageLimit','verbose'}
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
			me.parseArgs(varargin, me.allowedProperties);

			me.queueDir = me.paths.parent;

		end

		% ===================================================================
		function logout(me)
			if me.loggedIn
				me.token = [];
				me.sessionURL = [];
				me.webOptions.HeaderFields = []; % Remove token from header field
				fprintf('\n--->>> alyxManager: user <<%s>> logged OUT of <<%s>> successfully...\n\n', me.user, me.baseURL);
			end
		end

		% ===================================================================
		function login(me)
			if me.loggedIn; warning('Already Logged in...'); end
			noDisplay = usejava('jvm') && ~feature('ShowFigureWindows');
  			if isempty(me.user)
    			prompt = {'Alyx Username:'};
    			if noDisplay
					% use text-based alternative
					answer = strip(input([prompt{:} ' '], 's'));
    			else
      				% use GUI dialog
      				dlg_title = 'Alyx Login';
      				num_lines = 1;
      				defaultans = {'',''};
      				answer = inputdlg(prompt, dlg_title, num_lines, defaultans);
    			end
    			if isempty(answer)|| (iscell(answer) && isempty(answer{1})); return; end
    			
    			if iscell(answer)
					username = answer{1};
    			else
					username = answer;
    			end
  			else
    			username = me.user;
  			end
  			
  			if isempty(me.pwd)
    			if noDisplay
					diaryState = get(0, 'Diary');
					diary('off'); % At minimum we can keep out of dairy log file
					passwd = input('Alyx password <strong>**INSECURE**</strong>: ', 's');
					diary(diaryState);
    			else
					passwd = passwordUI();
    			end
  			else
    			passwd = me.pwd;
  			end
  			
  			try
    			me.getToken(username, passwd);
				fprintf('\n--->>> alyxManager: user <<%s>> logged in to <<%s>> successfully...\n\n', me.user, me.baseURL);
  			catch ex
    			products = ver;
    			toolboxes = matlab.addons.toolbox.installedToolboxes;
    			% Check the correct toolboxes are installed
    			if numel(toolboxes) == 0 || (~any(contains({products.Name},'JSONlab')) &&...
        			~any(contains({toolboxes.Name},'JSONlab')) && contains(ex.message, 'loadjson'))
					% JSONlab not installed
					error(ex.identifier, 'JSONLab Toolbox required.  Click <a href="matlab:web(''%s'',''-browser'')">here</a> to install.',...
        			'https://uk.mathworks.com/matlabcentral/fileexchange/33381-jsonlab--a-toolbox-to-encode-decode-json-files')
    			elseif strcmp(ex.identifier, 'Alyx:Login:FailedToConnect')
					me.Headless = true;
					return
    			elseif contains(ex.message, 'credentials')||strcmpi(ex.message, 'Bad Request')
      				if me.Headless == true
        				warning('Alyx:LoginFail:BadCredentials', 'Unable to log in with provided credentials.')
        				return
      				else
        				disp('Unable to log in with provided credentials.')
        				me.pwd = [];
      				end
    			elseif contains(ex.message, 'password')&&contains(ex.message, 'blank')
					disp('Password may not be left blank')
    			else % Another error altogether
					rethrow(ex)
    			end
  			end
		end

		% ===================================================================
		function [data, statusCode] = getData(me, endpoint, varargin)
			%GETDATA Return a specific Alyx/REST read-only endpoint
			%   Makes a request to an Alyx endpoint; returns the data as a MATLAB struct.
			%
			%   Examples:
			%     sessions = me.getData('sessions')
			%     sessions = me.getData('https://alyx.cortexlab.net/sessions')
			%     sessions = me.getData('sessions?type=Base')
			%     sessions = me.getData('sessions', 'type', 'Base')
			%
			% See also ALYX, MAKEENDPOINT, REGISTERFILE
			if ~me.loggedIn || ~exist('endpoint','var'); return; end
			data = []; hasNext = true; page = 1;
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
        					rethrow(ex)
      					end
  				end
			end
		end

		% ===================================================================
		function [data, statusCode] = postData(me, endpoint, data, requestMethod)
			%POSTDATA Post any new data to an Alyx/REST endpoint
			%   Description: Makes a request to an Alyx endpoint with new data as a
			%   MATLAB struct; returns the JSON response data as a MATLAB struct.
			%   This function will create a new record by default, if requestMethod is
			%   undefined. Other methods include 'PUT', 'PATCH and 'DELETE'.
			%   Example:
			%     subjects = me.postData('subjects', myStructData, 'post')
			%
			% See also ALYX, JSONPOST, FLUSHQUEUE, REGISTERFILE, GETDATA
			if nargin == 3; requestMethod = 'post'; end % Default request method
			assert(any(strcmpi(requestMethod, {'post', 'put', 'patch', 'delete'})),...
  			'%s not a valid HTTP request method', requestMethod)
			
			% Create the JSON command
			jsonData = jsonencode(data);
			
			% Make a filename for the current command
			queueFilename = [datestr(now, 'yyyy-mm-dd-HH-MM-SS-FFF') '.' lower(requestMethod)];
			queueFullfile = fullfile(me.queueDir, queueFilename);
			% If local Alyx queue directory doesn't exist, create one
			if ~exist(me.queueDir, 'dir'); mkdir(me.queueDir); end
			
			% Save the endpoint and json locally
			fid = fopen(queueFullfile, 'w');
			fprintf(fid, '%s\n%s', endpoint, jsonData);
			fclose(fid);
			
			% Flush the queue
			if me.loggedIn
				[data, statusCode] = me.flushQueue();
				% Return only relevent data
				if numel(statusCode) > 1; statusCode = statusCode(end); end
  				if floor(statusCode/100) == 2 && ~isempty(data)
    				data = data(end);
  				end
			else
				statusCode = 000;
				data = [];
				warning('Alyx:flushQueue:NotConnected','Not connected to Alyx - saved in queue');
			end
		end

		% ===================================================================
		function [sessions, eids] = getSessions(me, varargin)
			% GETSESSIONS Return sessions and eids for a given search query
			%   Returns Alyx records for specific refs (eid and/or expRef strings)
			%   and/or those matching search queries.  Values may be char arrays,
			%   strings, or cell strings.  If searching dates, values may also be a
			%   datenum or array thereof.
			%
			%   Examples:
			%     sessions = ai.getSessions('cf264653-2deb-44cb-aa84-89b82507028a')
			%     sessions = ai.getSessions('2018-07-13_1_flowers')
			%     sessions = ai.getSessions('cf264653-2deb-44cb-aa84-89b82507028a', ...
			%                 'subject', {'flowers', 'ZM_307'})
			%     sessions = ai.getSessions('lab', 'cortexlab', ...
			%                 'date_range', datenum([2018 8 28 ; 2018 8 31]))
			%     sessions = ai.getSessions('date', now)
			%     sessions = ai.getSessions('data', {'clusters.probes', 'eye.blink'})
			%     [~, eids] = ai.getSessions(expRefs)
			%
			% See also ALYX.UPDATESESSIONS, ALYX.GETDATA
			
			p = inputParser;
			if mod(length(varargin),2) % Uneven num args when ref is first input
				validationFcn = @(x)(iscellstr(x) || isstring(x) || ischar(x));
				addOptional(p, 'ref', [], validationFcn);
			end
			% Parse Name-Value paired args
			addParameter(p, 'subject', '');
			addParameter(p, 'users', '');
			addParameter(p, 'lab', '');
			addParameter(p, 'date_range', '', 'PartialMatchPriority', 2);
			addParameter(p, 'dataset_types', '');
			addParameter(p, 'number', 1);
			
			[sessions, results, eids] = deal({}); % Initialize as empty
			parse(p, varargin{:})
			
			% Convert search params back to cell
			names = setdiff(fieldnames(p.Results), [{'ref'} p.UsingDefaults]);
			% Get values, and if nessesary convert datenums to datestrs
			values = cellfun(@processValue, names, 'UniformOutput', 0);
			assert(length(names) == length(values))
			queries = cell(length(names)*2,1);
			queries(1:2:end) = names;
			queries(2:2:end) = values;
			
			% Get sessions for specified refs
			if isfield(p.Results, 'ref') && ~isempty(p.Results.ref)
  				refs = cellstr(p.Results.ref);
  				parsedRef = regexp(refs, me.alfMatch, 'names');
  				sessFromRef = @(ref)me.getData('sessions/', ...
    				'subject', ref.subject, 'date_range', [ref.date ',' ref.date], 'number', ref.seq);
				b = cellfun(@isempty, parsedRef);
  				isRef = ~b;
  				sessions = [me.mapToCell(@(eid)me.getData(['sessions/' eid]), refs(~isRef))...
    				me.mapToCell(sessFromRef, parsedRef(isRef))];
  				sessions = me.rmEmpty(sessions);
			end
			
			% Do search for other queries
			if ~isempty(queries); results = me.getData('sessions', queries{:}); end
			% Return on empty
			if isempty(sessions) && isempty(results); return; end
			sessions = me.catStructs([sessions, me.ensureCell(results)]);
			if nargout > 1
				eids = me.url2eid({sessions.url});
			end
			function value = processValue(name)
    			if contains(name,'date')
      				if isnumeric(p.Results.(name))
        				value = me.iff(numel(p.Results.(name))==1, repmat(p.Results.(name),1,2), p.Results.(name));
        				value = string(datestr(value, 'yyyy-mm-dd'));
      				elseif isscalar(string(p.Results.(name))) && ~any(p.Results.(name)==',')
        				value = repmat(string(p.Results.(name)),2,1);
      				else
        				error('Alyx:getSessions:InvalidInput', 'The value of ''date_range'' is invalid')
      				end
    			else
					value = p.Results.(name);
				end
    			if iscellstr(value)||isstring(value); value = strjoin(value,','); end
			end
		end

		% ===================================================================
		function subjects = listSubjects(me, stock, alive, sortByUser)
			%ALYX.LISTSUBJECTS Lists recorded subjects
			%   subjects = ALYX.LISTSUBJECTS([stock, alive, sortByUser]) Lists the
			%   experimental subjects present in main repository.  If logged in,
			%   returns a subject list generated from Alyx, with the option of
			%   filtering by stock (default false) and alive (default true).  The
			%   sortByUser flag, when (default) true, returns the list with the user's
			%   animals at the top. 
			if nargin < 4; sortByUser = true; end
			if nargin < 3; alive = true; end
			if nargin < 2; stock = false; end
			
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

		function registerALF(me, alfDir, sessionURL)
			%REGISTERALFTOALYX Register files contained within alfDir to Alyx
			%   This function registers files contained within the alfDir to Alyx.
			%   Files are only registered if their filenames match a datasetType's
			%   alf_filename field. Must also provide an alyx session URL. Optionally
			%   can provide alyxInstance as well.
			%
			%   INPUTS:
			%     -alfDir: Directory containing ALF files, this will be searched
			%     recursively for all ALF files which match a datasetType
			%     -endpoint (optional): Alyx URL of the session to register this data
			%     to. If none supplied, will use SessionURL in me.  If this is unset,
			%     an error is thrown.
			%
			% See also ALYX, REGISTERFILES, POSTDATA, HTTP.JSONGET
			
			if nargin < 3
  				if isempty(me.sessionURL)
    				error('No session URL set')
  				else
    				sessionURL = me.sessionURL;
  				end
			end
			
			assert(exist('dirPlus','file') == 2,...
  			'Function ''dirPlus'' not found, make sure alyx helpers folder is added to path')
			
			%%INPUT VALIDATION
			% Validate alfDir path
			assert(~contains(alfDir,'/'), 'Do not use forward slashes in the path');
			assert(exist(alfDir,'dir') == 7 , 'alfDir %s does not exist', alfDir);
			
			% Validate alyxInstance, creating one if not supplied
			if ~me.IsLoggedIn; me = me.login; end
			
			%%Validate that the files within alfDir match a datasetType.
			%1) Get all datasetTypes from the database, and list the filename patterns
			datasetTypes = me.getData('dataset-types');
			datasetTypes = [datasetTypes{:}];
			datasetTypes_filemasks = {datasetTypes.filename_pattern};
			datasetTypes_filemasks(cellfun(@isempty,datasetTypes_filemasks)) = {''}; %Ensures all entries are character arrays
			
			%2) Get all the files contained within the alfDir, which match a
			%datasetType in the Alyx database
			function v = validateFcn(fileObj)
    			match = regexp(fileObj.name, regexptranslate('wildcard',datasetTypes_filemasks));
    			v = ~isempty([match{:}]);
			end
			alfFiles = dirPlus(alfDir, 'ValidateFileFcn', @validateFcn, 'Struct', true);
			assert(~isempty(alfFiles), 'No files within %s matched a datasetType', alfDir);
			
			%% Define a hierarchy of alfFiles based on the ALF naming scheme: parent.child.*
			alfFileParts = cellfun(@(name) strsplit(name,'.'), {alfFiles.name}, 'uni', 0);
			alfFileParts = cat(1, alfFileParts{:});
			
			%Create parent datasets, which contain no filerecords themselves
			[parentTypes, ~, parentID] = unique(alfFileParts(:,1));
			parentURLs = cell(size(parentTypes));
			fprintf('Creating parent datasets... ');
			for parent = 1:length(parentTypes)
    			d = struct('created_by', me.User,...
               			'dataset_type', parentTypes{parent},...
               			'session', sessionURL,...
               			'data_format', 'notData');
    			w = me.postData('datasets',d);
    			parentURLs{parent} = w.url;
			end
			
			%Now go through each file, creating a dataset and filerecord for that file
			for file = 1:length(alfFiles)
    			fullPath = fullfile(alfFiles(file).folder, alfFiles(file).name);
    			fileFormat = alfFileParts{file,3};
    			parentDataset = parentURLs{parentID(file)};
			
    			datasetTypes_filemasks(contains(datasetTypes_filemasks,'*.*')) = []; % Remove parant datasets from search
    			matchIdx = regexp(alfFiles(file).name, regexptranslate('wildcard', datasetTypes_filemasks));
    			matchIdx = find(~cellfun(@isempty, matchIdx));
    			assert(numel(matchIdx)==1, 'Insufficient/Too many matches of datasetType for file %s', alfFiles(file).name);
    			datasetType = datasetTypes(matchIdx).name;
    			
    			me.registerFile(fullPath, fileFormat, sessionURL, datasetType, parentDataset);
    			
    			fprintf('Registered file %s as datasetType %s\n', alfFiles(file).name, datasetType);
			end
			
			%% Alyx-dev
			return
			try %#ok<UNRCH>
  			%Get datarepositories and their base paths
  			repo_paths = cellfun(@(r) r.name, me.getData('data-repository'), 'uni', 0);
  			
  			%Identify which repository the filePath is in
  			which_repo = cellfun( @(rp) contains(alfDir, rp), repo_paths);
  			assert(sum(which_repo) == 1, 'Input filePath\n%s\ndoes not contain the a repository path\n', alfDir);
  			
  			%Define the relative path of the file within the repo
  			dnsId = regexp(alfDir, ['(?<=' repo_paths{which_repo} '.*)\\?'], 'once')+1;
  			relativePath = alfDir(dnsId:end);
  			
  			me.BaseURL = 'https://alyx-dev.cortexlab.net';
			%   subject = regexpi(relativePath, '(?<=Subjects\\)[A-Z_0-9]+', 'match');
  			
			%   D.subject = subject{1};
  			D.filenames = {alfFiles.name};
  			D.path = alfDir;
			%   D.exists_in = repo_paths{which_repo};
  			
  			me.postData('register-file', D);
			catch ex
  			warning(ex.identifier, '%s', ex.message)
			end
			me.BaseURL = 'https://alyx.cortexlab.net';
		end

		% ===================================================================
		function [fullpath, filename, fileID, records] = expFilePath(me, varargin)
			%EXPFILEPATH Full path for file pertaining to designated experiment
			%   Returns the path(s) that a particular type of experiment file should be
			%   located at for a specific experiment. NB: Unlike dat.expFilePath, this
			%   CAN NOT be used to determine where a file should be saved to.  This
			%   function only returns existing file records from Alyx.  There may be
			%   files that exist but aren't on Alyx and likewise, may not exist but are
			%   still on Alyx.
			%
			%   e.g. to get the paths for an experiments 2 photon TIFF movie:
			%   ALYX.EXPFILEPATH('mouse1', datenum(2013, 01, 01), 1, 'block');
			%
			%   [full, filename] = expFilePath(ref, type[, user, reposlocation])
			%   [full, filename] = expFilePath(subject, date, seq, type[, user, reposlocation])
			%
			%   
			%   You specify:
			%     - subject/ref: a string with the subject name or an experiment
			%       reference
			%     - date: a string in 'yyyy-mm-dd', 'yyyymmdd' or  'yyyy-mm-ddTHH:MM:SS'
			%       format, or a datenum 
			%     - seq: an integer number of the experiment you want
			%     - type: a case-insensitive string specifying which file you want, e.g. 'Block'.  Must
			%       be a valid dataset type on Alyx (see /dataset-types)
			%     - user: optional string argument specifying the user who created the files 
			%     - reposlocation: optional case-insensitive string argument specifying
			%       the location of the files e.g. 'zubjects'.  Must be a valid data 
			%       repository on Alyx (see /data-repository)
			%
			%   Outputs:
			%     - fullpath: the full file paths of the files
			%     - filename: the names of the files
			%     - uuid: the Alyx ids of the files
			%     - records: the complete records returned by Alyx
			%
			%   If more than one matching paths are found, output argument filePath
			%   will be a cell array of strings, otherwise just a string.
			
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
			if numel(fullpath)==1
  				fullpath = fullpath{1};
  				filename = filename{1};
  				fileID = fileID{1};
			end
		end

		function [datasets, filerecords] = registerFile(me, filePath)
			%REGISTERFILE Registers filepath(s) to Alyx. The file being registered should already be on the target server.
			%   The repository being registered to will be automatically determined
			%   from the filePath. Registration work first by creating a dataset (a
			%   record of the dataset type, creation date), and then a filerecord (a
			%   record of the relative path within the repository). The dataset is
			%   associated with a session and a subject, which is inferred from the
			%   path provided. 
			%
			%   The input filePath must be a full path to a directory or file, or a
			%   cell array thereof.  For any directory paths provided, registerFile
			%   attempts to register all files contained.  All file paths must include
			%   an extension (if exists).  In order to be registered all files must
			%   have an associated dataset type on Alyx.
			%
			%   All paths must conform to the following structure:
			%   <dns>\<subject>\<yyyy-mm-dd>\<seq>\ where <dns> matches a valid data
			%   repository domain name server entry on Alyx.
			%
			%   Examples:
			%     datasets = me.registerFile({...
			%       '\\zubjects.cortexlab.net\Subjects\ALK055\2017-07-17\1\2017-07-17_1_ALK055_Block.mat',...
			%       '\\zubjects.cortexlab.net\Subjects\ALK055\2017-07-17\2'});
			%
			%   NB: The returned datasets may not be in the same order as the filePaths
			%   list provided.
			%
			% See also ALYX, GETDATA, POSTDATA
			
			%%INPUT VALIDATION
			filePath = me.ensureCell(filePath);
			if size(filePath,1) < size(filePath,2)
  			filePath = filePath';
			end
			
			% Validate files/directories exist
			exists = cellfun(@(p) exist(p,'file') || exist(p,'dir'), filePath);
			if any(~exists)
  			warning('Alyx:registerFile:InvalidPath',...
    			'One or more files/directories not found')
  			filePath = filePath(exists);
			end
			
			% Remove redundant paths, i.e. those that point to specific files if a path
			% to the same directory was also provided
			dirs = cellfun(@(p)exist(p,'dir')~=0, filePath); % For 2017b and later, we can use @isfolder
			filePath = [filePath(~dirs); me.cellflat(cellfun(@dirPlus, filePath(dirs), 'uni', 0))];
			filePath = unique(filePath);
			
			% Get the DNS part of the file paths  FIXME: Generalize expression
			hostname = me.cellflat(regexp(filePath,'.*(?:\\{2}|\/)(.[^\\|\/]*)', 'tokens'));
			
			% Retrieve information from Alyx for file validation
			[dataFormats, statusCode(1)] = me.getData('data-formats');
			[datasetTypes, statusCode(2)] = me.getData('dataset-types');
			[repositories, statusCode(3)] = me.getData('data-repository');
			
			% When Alyx unreachable, i.e. server down or user is not
			% logged in and object is headless, we can not validate posts
			if any(statusCode==000)||(any(statusCode==403)&&me.Headless)
  			warning('Alyx:registerFile:UnableToValidate',...
    			'Unable to validate paths, some posts may fail')
			else %%% FURTHER VALIDATION %%%
  			% Ensure there are DNS fields on the database
  			repo_dns = me.rmEmpty({repositories.hostname});
  			if isempty(repo_dns)
    			warning('Alyx:registerFile:EmptyDNSField',...
    			'No valid DNS returned by database data repositories.')
    			return
  			end
  			
  			% Identify which repository the filePath is in
  			valid = cellfun(@(p)~isempty(p)&&any(strcmp(p,repo_dns)), hostname);
  			if ~all(valid)
    			warning('Alyx:registerFile:InvalidRepoPath',...
      			['The following file path(s) not valid repository path(s):\n%s\n',...
      			'Check dns field of data repositories on Alyx'], strjoin(filePath(~valid), '\n'))
    			filePath = filePath(valid);
    			hostname = hostname(valid);
  			end
  			
  			% Validate dataset format
  			dataFormats(strcmp({dataFormats.name}, 'unknown')) = [];
  			isValidFormat = @(p)any(cell2mat(regexp(p,...
    			regexptranslate('wildcard', me.rmEmpty({dataFormats.file_extension})))));
  			valid = cellfun(isValidFormat, filePath);
  			if ~all(valid)
    			[~,~,ext] = cellfun(@fileparts, filePath, 'uni', 0);
    			warning('Alyx:registerFile:InvalidFileType',...
      			'File extention(s) ''%s'' not found on Alyx', strjoin(unique(ext(~valid)),''', '''))
    			filePath = filePath(valid);
    			hostname = hostname(valid);
  			end
  			
  			% Validate file name matching a dataset type
  			datasetTypes(strcmp({datasetTypes.name}, 'unknown')) = [];
  			isValidFileName = @(p)any(cell2mat(regexp(p,...
    			regexptranslate('wildcard', rmEmpty({datasetTypes.filename_pattern})))));
  			valid = cellfun(isValidFileName, filePath);
  			if ~all(valid)
    			warning('Alyx:registerFile:InvalidFileName',...
      			'The following input file path(s) have invalid file name pattern(s):\n%s ',...
      			strjoin(filePath(~valid), '\n'))
    			filePath = filePath(valid);
    			hostname = hostname(valid);
  			end
			end
			
			% Validate dataFormat supplied
			% Remove leading slashes and replace back-slashes with forward ones
			% filePaths = cellfun(@(s)strip(s,'\'), filePaths, 'uni', 0);
			% filePaths = cellfun(@(s)strrep(s,'\','/'), filePaths, 'uni', 0);
			
			% Split filepaths into path and filenames
			[filePath, filenames, ext] = cellfun(@fileparts, filePath, 'uni', 0);
			filenames = strcat(filenames, ext);
			[filePath,~,ic] = unique(filePath);
			% Initialize datasets array
			datasets = cell(1, numel(filePath));
			filerecords = []; % Initialize in case unable to access server
			
			if isempty(filePath)
  			warning('Alyx:registerFile:NoValidPaths', 'No file paths were registered')
  			return
			end
			
			% Regex pattern for the relative path
			expr = ['\w+(\\|\/)\d{4}\-\d{2}\-\d{2}((?:(\\|\/))\d+)+(?=(\\|\/)\w+\.\w+)|',...
  			'\w+(\\|\/)\d{4}\-\d{2}\-\d{2}((\\|\/)\w+)+'];
			realtivePath = cellflat(regexp(filePath, expr, 'match'));
			
			% Register files
			D = struct('created_by', me.User);
			for i = 1:length(filePath)
  			D.hostname = hostname{i};
  			D.path = realtivePath{i};
  			D.filenames = filenames(ic==i);
  			[record, statusCode] = me.postData('register-file', D);
  			if statusCode==000; continue; end % Cannot reach server
  			assert(statusCode(end)==201, 'Failed to submit filerecord to Alyx');
  			datasets{i} = record(end);
			end
			
			if statusCode~=000 % Cannot reach server
			datasets = catStructs(datasets);
			filerecords = [datasets(:).file_records];
			end
		end

		% ===================================================================
		function bool = get.loggedIn(me)
			bool = ~isempty(me.user) && ~isempty(me.token);
		end

		% ===================================================================
		function set.queueDir(me, qDir)
			%SET.QUEUEDIR Ensure directory exists
			if ~exist(qDir, 'dir'); mkdir(qDir); end
			me.queueDir = qDir;
    	end
    	
    	% ===================================================================
		function set.baseURL(me, value)
			% Drop trailing slash and ensure protocol defined
			if isempty(value); me.BaseURL = ''; return; end % return on empty
			if matches(value(1:4), 'http'); value = ['https://' value]; end
			if value(end)=='/'; me.baseURL = value(1:end-1); else; me.baseURL =  value; end
    	end

	end %---END PUBLIC METHODS---%

	%=======================================================================
	methods ( Static ) %----------STATIC METHODS
	%=======================================================================
    
		% ===================================================================
		function [a, wrapped] = ensureCell(a)
			%ENSURECELL If arg not already a cell array, wrap it in one
			if ~iscell(a);a = {a};wrapped = true; else; wrapped = false;end
		end

		% ===================================================================
		function flat = cellflat(c)
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
			if iscell(A)
  			empty = cellfun('isempty', A);
			else
  			empty = arrayfun(@isempty, A);
			end
			
			passed = A(~empty);
		end

		% ===================================================================
		function [C1, varargout] = mapToCell(f, varargin)
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
			%CATSTRUCTS Concatenates different structures into one structure array
			%   s = catStructs(cellOfStructs, [missingValue])
			%   Returns a non-scalar structure made from concatinating the structures
			%   in `cellOfStructs` and optionally replacing any missing values. NB: all
			%   empty values in the output struct are replaced by `missingValue`,
			%   including ones present in the original input.
			if nargin < 2; missingValue = []; end
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
			%PICK Retrieves indexed elements from a data structure
			%   Encapsulates different MATLAB syntax for retreival from data structures
			%
			%   * For arrays, numeric keys mean indices:
			%   v = PICK(arr, idx) returns values at the specified indices in 'arr', e.g:
			%         PICK(2:2:10, [1 2 4]) % like arg1([1 2 4]) returns [2,4,8]
			%
			%   * For structs & class objects and string key(s), fetch value of the
			%   struct's field or object's property:
			%   v = PICK(s, f) returns the value of field 'f' in structure 's' (or
			%   property 'f' in object 's'). If 's' is a structure or object array,
			%   return an array of each elements field or property value. e.g:
			%           s.a = 1; s.b = 3;
			%           PICK(s, 'a')       % like s.a, returns 1
			%           PICK(s, {'a' 'b'}) % selecting two fields, returns {[1] [2]}
			%           s(2).a = 2; s(2).b = 4;
			%           PICK(s, 'a')       % like [s.a], returns [1 2]
			%           PICK(s, {'a' 'b'}) % selecting two fields, returns {[1 2] [3 4]}
			%
			%   * For containers.Map object's with a valid key type, get keyed value:
			%   v = PICK(map, key) returns the value in 'map' of the specified 'key'
			%   If key is an array of keys (with valid types for that map), return a 
			%   cell array with each element retreived by the corresponding key. e.g:
			%           m = containers.Map;
			%           m('number') = 1
			%           m('word') = 'apple'
			%           PICK(m, 'word')            % like m('word'), returns 'apple'
			%           PICK(m, {'word' 'number'}) % returns {'apple' [1]}
			%
			%   When picking from structs, objects and maps, you can
			%   also specify a default value to be used when the specified key does not
			%   exist in your data structure: pass in a pair of parameters, 'def'
			%   followed by the default value (e.g. see (2) below).
			%
			%   Finally, you can pass in the option 'cell', to return a cell array
			%   instead of a standard array (or scalar). This is useful e.g. if you are
			%   picking from fields containing strings in a struct array:
			%           w(1).a = 'hello'; w(2).a = 'goodbye';
			%           PICK(w, 'a', 'cell') % like {w.a}, returns {'hello' 'goodbye'}
			%
			%   Why is all this useful? A few reasons:
			%   1) If a function returns an array or a structure, MATLAB does not allow
			%   you to use standard syntax to index it from the function call:
			%     e.g. you might only want the third element from some computation:
			%           fft(x)(2)           % does not work, must do:
			%           y = fft(x);
			%           y(2)                % ewww, a whole extra line! Try:
			%           y = PICK(fft(x), 2) % tidier, no?
			%   2) Defaults are super useful & succint. e.g. default values for settings:
			%     e.g.  settings = load('settings');
			%           % now normally I have to say:
			%           if ~isfield(settings, 'dataPath')
			%             mypath = 'default/path'; % default value
			%           else
			%             mypath = settings.dataPath;
			%           end % pretty tedious, when we could just do:
			%           mypath = PICK(settings, 'dataPath, 'def', 'default/path') % yay!
			%   3) Make code flexible without repetition. If you want code that can
			%   e.g. retrieve a bunch of data from some structure and process it, you
			%   might want it to be able to handle retrieving from a matrix or a cell
			%   array, but without all the 'if iscell(blah) blah{i} else blah(i)'. With
			%   PICK you can handle many different data structures with one function call.		
			if iscell(key)
				v = mapToCell(@(k) pick(from, k, varargin{:}), key);
			else
  				stringArgs = cellfun(@ischar, varargin); %string option params
  				[withDefault, default] = alyxManager.namedArg(varargin, 'def');
  				cellOut = any(strcmpi(varargin(stringArgs), 'cell'));
				if isa(from, 'containers.Map')
					%% Handle MATLAB maps with key meaning key!
    				v = me.iff(withDefault && ~from.isKey(key), default, @() from(key));
  				elseif ischar(key)
    				%% Handle structures and class objects with key meaning field/property
    				if ~iscell(from)
      					if cellOut
        					if ~withDefault
								v = reshape({from.(key)}, size(from));
        					elseif withDefault && (isfield(from, key) || isAProp(from, key))
								% create cell array, then replace empties with default value
								v = reshape({from.(key)}, size(from));
								[v{cellfun(@isempty, v)}] = deal(default);
        					else
								% default but field or property does not exist
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
          						% if using default but with default array output, first get cell
          						% output with defaults applied, then convert back to a MATLAB array:
          						asCell = alyxManager.pick(from, key, varargin{:}, 'cell');
								% v = cell2mat( pick(from, key, varargin{:}, 'cell'));
          						% cell2mat doesn't process single element cells if they contain a
          						% cell or string, so we short circuit ourselves in this case:
          						v = iff(isscalar(asCell), @() asCell{1}, @() cell2mat(asCell));
        					end
						end
    				else
      					if cellOut
        					% The following line was changed 2019-08
					%         v = mapToCell(@(e) pick(pick(e, key, varargin{:}), 1), from);
        					v = me.mapToCell(@(e) me.pick(e, key, varargin{:}), from);
      					else
        					v = cellfun(@(e) me.pick(e, key, varargin{:}), from);
      					end
    				end
  				elseif iscell(from)
    				%% Handle cell arrays with key meaning indices
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
			%NAMEDARG Returns value from name,value argument pairs
			%   [present, value, idx] = NAMEDARG(args, name) returns flag for presence
			%   and value of the argument 'name' in a list potentially containing
			%   adjacent (name, value) pairs.  Also returns the index of 'name'.
			matches = @(s) (ischar(s) || isStringScalar(s)) && strcmpi(s, name);
			idx = find(cellfun(matches, args), 1);
			if ~isempty(idx)
				present = true;
				value = args{idx + 1};
			else
				present = false;
				value = nil;
			end
		end
		
		% ===================================================================
		function eid = url2eid(url)
			% URL2EID Return eid portion of Alyx URL
			%   Provided a url (or array thereof) returns the eid portion.
			%
			%   Example:
			%     url =
			%     'https://www.url.com/sessions/bc93a3b2-070d-47a8-a2b8-91b3b6e9f25c';
			%     eid = Alyx.url2eid(url)
			%
			% See also ALYX.MAKEENDPOINT		
			if iscell(url)
				eid = mapToCell(@Alyx.url2eid, url);
				return
			end
			
			eid_length = 36; % Length of our uuids
			% Ensure url longer than minimum length
			assert(numel(url) >= eid_length, ...
			'Alyx:url2Eid:InvalidURL', 'URL may not contain eid')
			
			% Remove trailing slash if present
			url = strip(url, 'right', '/');
			% Get eid component of url
			% eid = mapToCell(@(str)str(end-eid_length+1:end), url);
			eid = url(end-eid_length+1:end);
		end

		% ===================================================================
		function [ref, AlyxInstance] = parseAlyxInstance(varargin)
			%PARSEALYXINSTANCE Converts input to string for UDP message and back
			%   [UDP_string] = ALYX.PARSEALYXINSTANCE(ref, AlyxInstance)
			%   [ref, AlyxInstance] = ALYX.PARSEALYXINSTANCE(UDP_string)
			%   
			%   AlyxInstance should be an Alyx object.
			%
			% See also SAVEOBJ, LOADOBJ
			
			if nargin > 1 % in [ref, AlyxInstance]
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
  				% Add the token to the authorization header field
  				me.webOptions.HeaderFields = {'Authorization', ['Token ' me.token]};
  				% Flush the local queue on successful login
  				me.flushQueue();
			elseif statusCode == 000
  				% Alyx is down, set as headless
  				me.Headless = true;
  				error('Alyx:Login:FailedToConnect', responseBody)
			elseif statusCode == 400 && isempty(password)
				error('Alyx:Login:PasswordEmpty', 'Password may not be left blank')
			else
				error(responseBody)
			end
		end

		% ===================================================================
		function fullEndpoint = makeEndpoint(me, endpoint)
			assert(~isempty(endpoint)...
       			&& (ischar(endpoint) || isStringScalar(endpoint))...
       			&& endpoint ~= "", ...
       			'Alyx:makeEndpoint:invalidInput', 'Invalid endpoint');
			if startsWith(endpoint, 'http')
				% this is a full url already
				fullEndpoint = endpoint;
			else
				fullEndpoint = [me.baseURL, '/', char(endpoint)];
  				if isstring(endpoint)
    				fullEndpoint = string(fullEndpoint);
  				end
			end
			% drop trailing slash
			fullEndpoint = strip(fullEndpoint, '/');
		end

		% ===================================================================
		function [statusCode, responseBody] = jsonPost(me, endpoint, jsonData, requestMethod)
			%JSONPOST Makes POST, PUT and PATCH requests to endpoint with a JSON request body
			% Makes a POST request, with a JSON request body (`Content-Type: application/json`), 
			% and asking for a JSON response (`Accept: application/json`).
			%   
			% Inputs:
			%   endpoint      - REST API endpoint to make the request to
			%   requestBody   - String to use as request body
			%   requestMethod - String indicating HTTP request method, i.e. 'POST'
			%                   (default), 'PUT', 'PATCH' or 'DELETE'
			%
			% Output:
			%   statusCode - Integer response code
			%   responseBody - String response body or data struct
			%
			% See also JSONGET, JSONPUT, JSONPATCH
			
			% Validate the inputs
			endpoint = me.makeEndpoint(endpoint); % Ensure absolute URL
			if nargin == 3; requestMethod = 'post'; end % Default request method
			assert(any(strcmpi(requestMethod, {'post', 'put', 'patch', 'delete'})),...
  			'%s not a valid HTTP request method', requestMethod)
			% Set the HTTP request method in options
			options = me.webOptions;
			options.RequestMethod = lower(requestMethod);
			
			try % Post data
				responseBody = webwrite(endpoint, jsonData, options);
				if endsWith(endpoint,'auth-token'); statusCode = 200; else  statusCode = 201; end
			catch ex
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
		function [data, statusCode] = flushQueue(me)
			% FLUSHQUEUE Checks for and uploads queued data to Alyx
			%   Checks all .post and .put files in me.QueueDir and tries to post/put
			%   them to the database.  If the upload is successfull, the queued file is
			%   deleted.  If an error is returned the queued file is also deleted,
			%   unless it was a server error.
			%
			%   Status codes:
			%     200: Upload success - delete from queue
			%     300: Redirect - delete from queue
			%     400: User error - delete from queue
			%     403: Invalid token - delete from queue
			%     500: Server error - save in queue
			%
			% See also ALYX, ALYX.JSONPOST
			
			% Get all currently queued posts, puts, etc.
			alyxQueue = [dir([me.queueDir filesep '*.post']);...
  			dir([me.queueDir filesep '*.put']);...
  			dir([me.queueDir filesep '*.patch'])];
			alyxQueueFiles = sort(cellfun(@(x) fullfile(me.queueDir, x), {alyxQueue.name}, 'uni', false));
			
			% Leave the function if there aren't any queued commands
			if isempty(alyxQueueFiles); return; end
			
			% Loop through all files, attempt to put/post
			statusCode = ones(1,length(alyxQueueFiles))*401; % Initialize with user error code
			data = cell(1,length(alyxQueueFiles));
			for curr_file = 1:length(alyxQueueFiles)
				[~, ~, uploadType] = fileparts(alyxQueueFiles{curr_file});
				fid = fopen(alyxQueueFiles{curr_file});
				% First line is the endpoint
				endpoint = fgetl(fid);
				% Rest of the text is the JSON data
				jsonData = fscanf(fid,'%c');
				fclose(fid);
  			
  				try
    				[statusCode(curr_file), responseBody] = me.jsonPost(endpoint, jsonData, uploadType(2:end));
				%     [statusCode(curr_file), responseBody] = http.jsonPost(me.makeEndpoint(endpoint), jsonData, 'Authorization', ['Token ' me.Token]);
    				switch floor(statusCode(curr_file)/100)
      				case 2
        				% Upload success - delete from queue
        				data{curr_file} = responseBody;
        				delete(alyxQueueFiles{curr_file});
        				disp([int2str(statusCode(curr_file)) ' Success, uploaded to Alyx: ' jsonData])
      				case 3
        				% Redirect - delete from queue
        				data{curr_file} = responseBody;
        				delete(alyxQueueFiles{curr_file});
        				disp([int2str(statusCode(curr_file)) ' Redirect, uploaded to Alyx: ' jsonData])
      				case 4
        				if statusCode(curr_file) == 403 % Invalid token
          				me.logout; % delete token
          				if ~me.headless % if user can see dialog...
            				me.login; % prompt for login
            				[data, statusCode] = me.flushQueue; % Retry
          				else % otherwise - save in queue
            				warning('Alyx:flushQueue:InvalidToken', '%s (%i): %s saved in queue',...
              				responseBody, statusCode(curr_file), alyxQueue(curr_file).name)
          				end
        				else % User error - delete from queue
							delete(alyxQueueFiles{curr_file});
							warning('Alyx:flushQueue:BadUploadCommand', '%s (%i): %s',...
            				responseBody, statusCode(curr_file), alyxQueue(curr_file).name)
        				end
      				case 5
        				% Server error - save in queue
        				warning('Alyx:flushQueue:InternalServerError', '%s (%i): %s saved in queue',...
          				responseBody, statusCode(curr_file), alyxQueue(curr_file).name)
    				end
  				catch ex
      				if strcmp(ex.identifier, 'MATLAB:weboptions:unrecognizedStringChoice')
          				warning('Alyx:flushQueue:MethodNotSupported',...
              				'%s method not supported', upper(uploadType(2:end)));
      				else
          				% If the JSON command failed (e.g. internet is down)
          				warning('Alyx:flushQueue:NotConnected', 'Alyx upload failed - saved in queue');
      				end
  				end
			end
			data = me.cellflat(data(~cellfun('isempty',data))); % Remove empty cells
			data = me.catStructs(data); % Convert cell array into struct
		end

		% ===================================================================
		%> @fn Delete method
		%>
		%> @param me
		%> @return
		% ===================================================================
		function delete(me)
			if me.verbose; fprintf('--->>> Delete: %s\n',me.fullName); end
		end
		
	end%---END PRIVATE METHODS---%
end
