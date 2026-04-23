% ========================================================================
classdef alyxUploader < handle
%> @class alyxUploader @brief Retroactively upload opticka session files to Alyx
%>
%> This tool scans an ALF-formatted folder hierarchy, creates matching
%> Alyx sessions for any data files that are not yet registered, uploads
%> the files to the S3/MinIO data repository, and registers them with
%> the Alyx database.
%>
%> The session start_time stored in Alyx is derived from the timestamp
%> embedded in the opticka filenames (e.g. opticka.raw.2026-04-23-10-20-03_001_Subject.mat),
%> so historical sessions are registered with their original date/time.
%>
%> Expected folder structure (opticka ALF convention):
%>   <root>/<lab>/subjects/<subject>/<YYYY-MM-DD>/<NNN>/[files...]
%>
%> Typical usage:
%>   up = alyxUploader('rootPath', '/data/OptickaFiles/SavedData', ...
%>                     'alyxURL',  'http://172.16.102.30:8000', ...
%>                     'user',     'admin', ...
%>                     'dataRepo', 'http://172.16.102.77:9000');
%>   up.run('DryRun', true);  % preview without posting
%>   up.run();                % scan + upload everything not yet in Alyx
%>
%> Copyright ©2024-2026 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ========================================================================

	%--------------------PUBLIC PROPERTIES----------%
	properties
		%> root of the ALF tree to scan
		rootPath char				= ''
		%> Alyx base URL
		alyxURL char				= 'http://172.16.102.30:8000'
		%> Alyx username
		user char					= 'admin'
		%> lab name used both in Alyx and as S3 bucket name
		labName char				= ''
		%> researcher / responsible user to set on new sessions
		researcherName char			= ''
		%> Alyx location string
		location char				= ''
		%> S3/MinIO endpoint URL
		dataRepo char				= 'http://172.16.102.30:9000'
		%> perform all steps but do NOT post to Alyx or upload to S3
		dryRun logical				= false
		%> more logging
		verbose logical				= false
	end

	%--------------------DEPENDENT PROPERTIES----------%
	properties (Dependent)
		%> returns true when the internal alyxManager is logged in
		loggedIn
	end

	%--------------------PRIVATE PROPERTIES----------%
	properties (Access = private)
		%> internal alyxManager instance
		alyx alyxManager
		%> internal awsManager instance (created on demand)
		aws
		%> regex to extract timestamp from opticka filenames
		%> matches: 2026-04-23-10-20-03  (yyyy-MM-dd-HH-mm-ss)
		tsPattern = '(\d{4}-\d{2}-\d{2}-\d{2}-\d{2}-\d{2})'
	end

	%=======================================================================
	methods %----------------------------PUBLIC METHODS
	%=======================================================================

		% ===================================================================
		function me = alyxUploader(varargin)
		%> @brief Constructor — pass properties as name-value pairs.
		%>
		%> @param varargin name-value pairs for any public property
		% ===================================================================
			for ii = 1:2:length(varargin)
				if isprop(me, varargin{ii})
					me.(varargin{ii}) = varargin{ii+1};
				end
			end
		end

		% ===================================================================
		function run(me, varargin)
		%> @brief Scan rootPath and process every session folder found.
		%>
		%> @param varargin optional name-value pairs:
		%>   'DryRun'    (logical) — if true, skip all network operations
		%>   'SubFolder' (char)    — restrict scan to this sub-path
		% ===================================================================
			p = inputParser;
			addParameter(p, 'DryRun',    me.dryRun,  @islogical);
			addParameter(p, 'SubFolder', '',          @ischar);
			parse(p, varargin{:});
			me.dryRun = p.Results.DryRun;
			scanRoot = me.rootPath;
			if ~isempty(p.Results.SubFolder)
				scanRoot = fullfile(scanRoot, p.Results.SubFolder);
			end

			assert(~isempty(scanRoot) && exist(scanRoot,'dir')==7, ...
				'alyxUploader:badRoot', 'rootPath "%s" does not exist', scanRoot);

			% Login to Alyx
			if ~me.dryRun
				me.ensureLogin();
			end

			% Find all session folders (leaf directories under date/NNN)
			sessions = me.discoverSessions(scanRoot);
			if isempty(sessions)
				fprintf('\n≣≣≣≣⊱ alyxUploader: no session folders found under %s\n', scanRoot);
				return;
			end
			fprintf('\n≣≣≣≣⊱ alyxUploader: found %d session folder(s) to process\n', numel(sessions));

			for ii = 1:numel(sessions)
				try
					me.processSession(sessions(ii));
				catch ERR
					warning('alyxUploader:sessionError', ...
						'Error processing %s:\n  %s', sessions(ii).alfPath, ERR.message);
				end
			end

			fprintf('\n≣≣≣≣⊱ alyxUploader: finished.\n\n');
		end

		% ===================================================================
		function sessions = discoverSessions(me, root)
		%> @brief Walk root and return a struct-array of session descriptors.
		%>
		%> Supports two layouts:
		%>   (A) <root>/<lab>/subjects/<subject>/<YYYY-MM-DD>/<NNN>/
		%>   (B) <root>/<subject>/<YYYY-MM-DD>/<NNN>/
		%>
		%> Returned struct fields: subject, date, sessionID, lab, alfPath, alfKeyShort
		% ===================================================================
			sessions = struct('subject',{},'date',{},'sessionID',{},...
				'lab',{},'alfPath',{},'alfKeyShort',{});

			% Pattern helpers
			datePattern = digitsPattern(4) + "-" + digitsPattern(2) + "-" + digitsPattern(2);
			numPattern   = digitsPattern(1,6);

			entries = dir(root);
			entries = entries([entries.isdir] & ~startsWith({entries.name},'.'));

			for e1 = entries'
				% ---- Layout A: <lab>/subjects/<subject>/<date>/<NNN>
				subjectsDir = fullfile(e1.folder, e1.name, 'subjects');
				if exist(subjectsDir,'dir') == 7
					lab = e1.name;
					subEntries = dir(subjectsDir);
					subEntries = subEntries([subEntries.isdir] & ~startsWith({subEntries.name},'.'));
					for e2 = subEntries'
						subject = e2.name;
						subjectDir = fullfile(subjectsDir, subject);
						sessions = me.scanDateDirs(sessions, subjectDir, subject, lab, datePattern, numPattern);
					end
					continue
				end

				% ---- Layout B: <subject>/<date>/<NNN>  (no lab prefix)
				% Check if e1.name looks like a date — if so it is the date level
				% Otherwise treat e1 as the subject level
				token = extract(e1.name, datePattern);
				if ~isempty(token)
					% e1 is already a date folder; parent is the subject dir
					subjectDir = e1.folder;
					[~, subject] = fileparts(subjectDir);
					sessions = me.scanDateDirs(sessions, subjectDir, subject, '', datePattern, numPattern);
				else
					subjectDir = fullfile(e1.folder, e1.name);
					sessions = me.scanDateDirs(sessions, subjectDir, e1.name, '', datePattern, numPattern);
				end
			end
		end

		% ===================================================================
		function processSession(me, s)
		%> @brief Create Alyx session, upload & register files for one session.
		%>
		%> The Alyx session start_time is taken from the timestamp embedded in
		%> the filename (e.g. 2026-04-23-10-20-03 → 2026-04-23T10:20:03).
		%> If no timestamp can be found in any filename, the date from the
		%> folder name is used at midnight as a safe fallback.
		%>
		%> @param s struct from discoverSessions
		% ===================================================================
			fprintf('\n――――――――――――――――――――――――――――――――――――――――\n');
			fprintf('≣≣≣≣⊱ Subject: %s  Date: %s  #: %s  Lab: %s\n', ...
				s.subject, s.date, s.sessionID, s.lab);
			fprintf('  Path: %s\n', s.alfPath);

			% Build sessionData struct mimicking runExperiment.sessionData
			session = struct();
			session.subjectName    = s.subject;
			session.researcherName = me.ternary(~isempty(me.researcherName), me.researcherName, me.user);
			session.labName        = me.ternary(~isempty(s.lab),             s.lab,             me.labName);
			session.location       = me.location;
			session.procedure      = '';
			session.project        = '';
			session.taskProtocol   = '';
			session.dataBucket     = lower(session.labName);
			session.dataRepo       = me.dataRepo;

			% Build paths struct mimicking runExperiment.paths
			paths = struct();
			paths.ALFPath        = s.alfPath;
			paths.sessionID      = str2double(s.sessionID);
			paths.ALFKeyShort    = s.alfKeyShort;
			paths.ALFKey         = me.ternary(~isempty(session.labName), ...
				fullfile(session.labName, 'subjects', s.subject, s.date, s.sessionID), ...
				fullfile(s.subject, s.date, s.sessionID));

			% Collect files now — we need them to extract the timestamp
			sFiles = dir(paths.ALFPath);
			sFiles = sFiles(~[sFiles.isdir]);
			if isempty(sFiles)
				fprintf('  ↳ No files found in %s, skipping.\n', paths.ALFPath);
				return;
			end
			filenames = arrayfun(@(f) fullfile(f.folder, f.name), sFiles, 'UniformOutput', false);
			fprintf('  ↳ %d file(s) found.\n', numel(filenames));

			% --- Extract start_time from filename timestamps -------------------
			startTime = me.extractStartTime(sFiles, s.date);
			fprintf('  ↳ Session start_time: %s\n', char(startTime, 'yyyy-MM-dd''T''HH:mm:ss'));

			% Validate subject / user / lab exist in Alyx before proceeding
			if ~me.dryRun
				me.validateAlyxEntries(session);
			end

			% Check if this session already exists in Alyx (using the real date)
			% Use only the date part for the date_range query
			dayDate = char(startTime, 'yyyy-MM-dd');
			if ~me.dryRun
				request = sprintf('sessions?date_range=%s,%s&subject=%s&number=%s', ...
					dayDate, dayDate, s.subject, s.sessionID);
				[existing, sc] = me.alyx.getData(request);
				if sc == 200 && ~isempty(existing)
					fprintf('  ↳ Session already in Alyx (id=%s), skipping creation.\n', existing(1).id);
					me.alyx.sessionURL = existing(1).url;
				else
					me.createAlyxSession(paths, session, startTime);
				end
			else
				fprintf('  [DryRun] Would create Alyx session with start_time %s.\n', ...
					char(startTime, 'yyyy-MM-dd''T''HH:mm:ss'));
			end

			% Register files with Alyx
			uuids = cell(1, numel(filenames));
			if ~me.dryRun
				try
					[datasets, regNames] = me.alyx.registerALFFiles(paths, session);
					fprintf('  ↳ Registered %d dataset(s) with Alyx.\n', numel(datasets));
					% match UUIDs back to local filenames
					for ii = 1:min(numel(datasets), numel(regNames))
						[~, rn, re] = fileparts(regNames{ii});
						needle = [rn re];
						for jj = 1:numel(filenames)
							[~, fn2, ext2] = fileparts(filenames{jj});
							if strcmp([fn2 ext2], needle)
								uuids{jj} = datasets(ii).id;
								break;
							end
						end
					end
				catch ERR
					warning('alyxUploader:registerFail', ...
						'registerALFFiles failed: %s', ERR.message);
				end
			else
				fprintf('  [DryRun] Would register %d file(s) with Alyx.\n', numel(filenames));
			end

			% Upload to S3
			if ~me.dryRun
				me.uploadToS3(filenames, uuids, paths, session);
			else
				fprintf('  [DryRun] Would upload %d file(s) to S3 bucket "%s".\n', ...
					numel(filenames), lower(session.labName));
			end

			% Close the Alyx session with the original end_time
			% Use folder date at end-of-day as a reasonable end_time when not known
			if ~me.dryRun && ~isempty(me.alyx.sessionURL)
				me.alyx.closeSession('Uploaded via alyxUploader', 'PASS');
				fprintf('  ↳ Alyx session closed.\n');
			end
		end

		% ===================================================================
		function bool = get.loggedIn(me)
		%> @brief Dependent property — true when alyx is logged in
		% ===================================================================
			bool = ~isempty(me.alyx) && isa(me.alyx,'alyxManager') && me.alyx.loggedIn;
		end

	%=======================================================================
	end %---END PUBLIC METHODS---%
	%=======================================================================

	%=======================================================================
	methods (Access = private)
	%=======================================================================

		% ===================================================================
		function startTime = extractStartTime(me, sFiles, folderDate)
		%> @brief Parse the earliest timestamp from the filenames in sFiles.
		%>
		%> Opticka names files as:
		%>   <type>.<YYYY-MM-DD-HH-mm-ss>_<NNN>_<Subject>[.<uuid>].<ext>
		%> e.g.  opticka.raw.2026-04-23-10-20-03_001_TestSubject.mat
		%>
		%> The timestamp portion is yyyy-MM-dd-HH-mm-ss (six dash-separated
		%> fields).  This is converted to a MATLAB datetime so it can be
		%> passed as start_time to alyxManager.newExp.
		%>
		%> If no timestamp is found in any file, the folder date (YYYY-MM-DD)
		%> at 00:00:00 is used as a fallback.
		%>
		%> @param sFiles  dir() struct array of files in the session folder
		%> @param folderDate  char 'YYYY-MM-DD' from the folder name
		%> @return startTime  datetime scalar (no timezone)
		% ===================================================================
			candidate = datetime.empty;
			for ff = 1:numel(sFiles)
				tok = regexp(sFiles(ff).name, me.tsPattern, 'tokens', 'once');
				if isempty(tok); continue; end
				tsStr = tok{1}; % 'YYYY-MM-DD-HH-mm-ss'
				try
					dt = datetime(tsStr, 'InputFormat', 'yyyy-MM-dd-HH-mm-ss');
					candidate(end+1) = dt; %#ok<AGROW>
				catch
					% malformed timestamp — skip
				end
			end

			if ~isempty(candidate)
				startTime = min(candidate); % use earliest in case multiple files
				if me.verbose
					fprintf('  ↳ Timestamp parsed from filename: %s\n', ...
						char(startTime, 'yyyy-MM-dd HH:mm:ss'));
				end
			else
				% Fallback: use the folder date at midnight
				startTime = datetime(folderDate, 'InputFormat', 'yyyy-MM-dd');
				warning('alyxUploader:noTimestamp', ...
					'No timestamp found in filenames; using folder date %s at 00:00:00', folderDate);
			end
		end

		% ===================================================================
		function ensureLogin(me)
		%> @brief Create/login the internal alyxManager if needed
		% ===================================================================
			if isempty(me.alyx) || ~isa(me.alyx,'alyxManager')
				me.alyx = alyxManager('baseURL', me.alyxURL, 'user', me.user, 'verbose', me.verbose);
			end
			if ~me.alyx.loggedIn
				me.alyx.login();
				assert(me.alyx.loggedIn, 'alyxUploader:loginFail', ...
					'Could not log in to Alyx at %s', me.alyxURL);
			end
		end

		% ===================================================================
		function sessions = scanDateDirs(me, sessions, subjectDir, subject, lab, datePattern, numPattern)
		%> @brief Scan date subdirectories inside a subject directory.
		% ===================================================================
			if ~exist(subjectDir,'dir'); return; end
			dateEntries = dir(subjectDir);
			dateEntries = dateEntries([dateEntries.isdir] & ~startsWith({dateEntries.name},'.'));
			for de = dateEntries'
				tok = extract(de.name, datePattern);
				if isempty(tok); continue; end
				dateStr = char(tok{1});
				dateDir = fullfile(subjectDir, de.name);
				% look for numeric session subdirs
				sesEntries = dir(dateDir);
				sesEntries = sesEntries([sesEntries.isdir] & ~startsWith({sesEntries.name},'.'));
				for se = sesEntries'
					nTok = extract(se.name, numPattern);
					if isempty(nTok); continue; end
					sesID   = se.name;
					alfPath = fullfile(dateDir, sesID);
					alfKeyShort = fullfile(subject, dateStr, sesID);
					entry = struct('subject', subject, 'date', dateStr, ...
						'sessionID', sesID, 'lab', lab, ...
						'alfPath', alfPath, 'alfKeyShort', alfKeyShort);
					sessions(end+1) = entry; %#ok<AGROW>
				end
			end
		end

		% ===================================================================
		function validateAlyxEntries(me, session)
		%> @brief Warn (not error) if required Alyx entries are missing
		% ===================================================================
			if ~isempty(session.labName)
				if ~me.alyx.hasEntry('labs', session.labName)
					warning('alyxUploader:missingLab', ...
						'Lab "%s" not found in Alyx', session.labName);
				end
			end
			if ~me.alyx.hasEntry('subjects', session.subjectName)
				warning('alyxUploader:missingSubject', ...
					'Subject "%s" not found in Alyx', session.subjectName);
			end
			if ~me.alyx.hasEntry('users', session.researcherName)
				warning('alyxUploader:missingUser', ...
					'User "%s" not found in Alyx', session.researcherName);
			end
			if ~isempty(session.location) && ~me.alyx.hasEntry('locations', session.location)
				warning('alyxUploader:missingLocation', ...
					'Location "%s" not found in Alyx', session.location);
			end
		end

		% ===================================================================
		function createAlyxSession(me, paths, session, startTime)
		%> @brief Wrapper around alyxManager.newExp passing the real start_time
		%>
		%> @param startTime  datetime scalar — the timestamp parsed from filenames
		% ===================================================================
			try
				[url, ~] = me.alyx.newExp(paths.ALFPath, paths.sessionID, session, [], startTime);
				if ~isempty(url)
					fprintf('  ↳ Created Alyx session: %s\n', url);
				else
					warning('alyxUploader:noURL', 'newExp returned empty URL');
				end
			catch ERR
				warning('alyxUploader:newExpFail', 'newExp failed: %s', ERR.message);
			end
		end

		% ===================================================================
		function uploadToS3(me, filenames, uuids, paths, session)
		%> @brief Upload files to S3 / MinIO via awsManager
		% ===================================================================
			if isempty(me.dataRepo)
				if me.verbose
					fprintf('  ↳ dataRepo not set, skipping S3 upload.\n');
				end
				return;
			end

			try
				if isempty(me.aws)
					awsID  = '';
					awsKey = '';
					try awsID  = getSecret('AWS_ID');  end %#ok<TRYNC>
					try awsKey = getSecret('AWS_KEY'); end %#ok<TRYNC>
					assert(~isempty(awsID) && ~isempty(awsKey), ...
						'alyxUploader:noAWSSecrets', ...
						'AWS_ID and AWS_KEY secrets are not set. Run setSecret(''AWS_ID'') etc.');
					me.aws = awsManager(awsID, awsKey, me.dataRepo);
				end

				bucket = lower(session.labName);
				if isempty(bucket)
					warning('alyxUploader:noBucket', ...
						'labName is empty; cannot determine S3 bucket name. Skipping upload.');
					return;
				end
				me.aws.checkBucket(bucket);

				for ii = 1:numel(filenames)
					[~, fn, ext] = fileparts(filenames{ii});
					if ~isempty(uuids) && numel(uuids) >= ii && ~isempty(uuids{ii})
						%> ONE protocol: append UUID before extension
						key = fullfile(paths.ALFKeyShort, [fn '.' uuids{ii} ext]);
					else
						key = fullfile(paths.ALFKeyShort, [fn ext]);
					end
					me.aws.copyFiles(filenames{ii}, bucket, key);
				end
				fprintf('  ↳ Uploaded %d file(s) to s3://%s/%s\n', ...
					numel(filenames), bucket, paths.ALFKeyShort);
			catch ERR
				warning('alyxUploader:s3Fail', 'S3 upload failed: %s', ERR.message);
			end
		end

		% ===================================================================
		function out = ternary(~, condition, ifTrue, ifFalse)
		%> @brief Simple ternary helper
		% ===================================================================
			if condition
				out = ifTrue;
			else
				out = ifFalse;
			end
		end

	%=======================================================================
	end %---END PRIVATE METHODS---%
	%=======================================================================

end
