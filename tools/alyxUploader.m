% ========================================================================
classdef alyxUploader < handle
%> @class alyxUploader @brief Retroactively upload session files to Alyx
%>
%> This tool scans an ALF-formatted folder hierarchy, creates matching
%> Alyx sessions for any data files that are not yet registered, uploads
%> the files to the S3/MinIO data repository, and registers them with
%> the Alyx database.
%>
%> The session start_time stored in Alyx is derived from the timestamp
%> embedded in the files themselves (e.g. opticka.raw.2026-04-23-10-20-03_001_Subject.mat),
%> so historical sessions are registered with their original date/time.
%>
%> If the files are readable, we try to parse the metadata from the files,
%> currently this must be managed for each task/tool. The defaults come
%> from this classes properties if no extra metadata than the filename is present.
%>
%> Required folder structure (ALF convention):
%>   <root>/<lab>/subjects/<subject>/<YYYY-MM-DD>/<NNN>/[files...]
%>
%> https://int-brain-lab.github.io/ONE/alf_intro.html
%>
%> Typical usage:
%>   up = alyxUploader('rootPath', '/data/SavedData', ...
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
		%> internal alyxManager instance
		alyx alyxManager
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
		dataRepo char				= 'http://172.16.102.77:9000'
		%> perform all steps but do NOT post to Alyx or upload to S3
		dryRun logical				= false
		%> more logging
		verbose logical				= false
		%> diary file to save the upload log to
		diaryFile					= '~/OptickaFiles/alyxUploader.log'
	end

	%--------------------DEPENDENT PROPERTIES----------%
	properties (Dependent)
		%> returns true when the internal alyxManager is logged in
		loggedIn
	end

	properties (SetAccess = protected, GetAccess = public)
		%> internal minioManager instance (created on demand)
		store
	end

	%--------------------PRIVATE PROPERTIES----------%
	properties (Access = private)
		%> regex to extract timestamp from opticka filenames
		%> matches: 2026-04-23-10-20-03  (yyyy-MM-dd-HH-mm-ss)
		tsPattern = '(\d{4}-\d{2}-\d{2}-\d{2}-\d{2}-\d{2})'
		%> cache of remote name lists keyed by type, mirroring alyxManager.cache
		cache dictionary
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

			if isempty(me.alyx)
				me.alyx = alyxManager;
			end

			me.cache = configureDictionary("string","cell");
		end

		% ===================================================================
		function [report, diaryFile] = run(me, dryRun, subFolder)
		%> @brief Scan rootPath and process every session folder found.
		%>
		%> @param varargin optional name-value pairs:
		%>   'DryRun'    (logical) — if true, skip all network operations
		%>   'SubFolder' (char)    — restrict scan to this sub-path
		% ===================================================================
			arguments(Input)
				me
				dryRun logical = false
				subFolder char = ''
			end

			% open the diary file
			if isempty(me.diaryFile)
				me.diaryFile = fullfile(me.alyx.paths.parent, "alyxUploader.log");
			end
			diary(me.diaryFile);
			report{1} = '≣≣≣≣ ≣≣≣≣ ≣≣≣≣ ≣≣≣≣ ≣≣≣≣ ≣≣≣≣ ≣≣≣≣ ≣≣≣≣ ≣≣≣≣';
			report{2} = report{1};
			report{end+1} = sprintf('≣≣≣≣⊱ alyxUploader: diary file: %s', me.diaryFile);
			
			me.dryRun = dryRun;
			scanRoot = me.rootPath;
			if ~isempty(subFolder)
				scanRoot = fullfile(scanRoot, p.Results.SubFolder);
			end

			assert(~isempty(scanRoot) && exist(scanRoot,'dir')==7, ...
				'alyxUploader:badRoot', 'rootPath "%s" does not exist', scanRoot);

			% Login to Alyx
			if ~me.dryRun
				ensureLogin(me);
				me.alyx.cleanQueue;
			end

			% Find all session folders (leaf directories under date/NNN)
			sessions = discoverSessions(me, scanRoot);
			if isempty(sessions)
				report{end+1} = sprintf('≣≣≣≣⊱ alyxUploader: no session folders found under %s', scanRoot);
				disp(report{end});
				return;
			end

			report{end+1} = sprintf('≣≣≣≣⊱ alyxUploader: found %d session folder(s) to process', numel(sessions));
			fprintf("\n\n\n");
			cellfun(@(ln)disp(ln),report);

			for ii = 1:numel(sessions)
				try
					t = me.processSession(sessions(ii));
					report = [report t]; 
					cellfun(@(ln)disp(ln),t);
				catch ERR
					getReport(ERR)
					report{end+1} = sprintf('Error processing %s:     %s', sessions(ii).alfPath, ERR.message);
					warning('alyxUploader:sessionError', report{end});
				end
			end

			fprintf('≣≣≣≣⊱ alyxUploader: finished.\n');

			diary off
			diaryFile = me.diaryFile;
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
				if matches(e1.name,'subjects')
					subjectsDir = fullfile(e1.folder, e1.name);
					[~,lab] = fileparts(e1.folder);
				else
					subjectsDir = fullfile(e1.folder, e1.name, 'subjects');
					lab = e1.name;
				end
				if exist(subjectsDir,'dir') == 7
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
		function log = processSession(me, s)
		%> @brief Create Alyx session, upload & register files for one session.
		%>
		%> The Alyx session start_time is taken from the timestamp embedded in
		%> the filename (e.g. 2026-04-23-10-20-03 → 2026-04-23T10:20:03).
		%> If no timestamp can be found in any filename, the date from the
		%> folder name is used at midnight as a safe fallback.
		%>
		%> @param s struct from discoverSessions
		% ===================================================================
			log = {'=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-='};
			log{end+1} = sprintf('≣≣≣≣⊱ Subject: %s  Date: %s  #: %s  Lab: %s', ...
				s.subject, s.date, s.sessionID, s.lab);
			log{end+1} = sprintf('  Path: %s', s.alfPath);

			%% === Build sessionData struct mimicking runExperiment.sessionData
			session = struct();
			session.subjectName    = s.subject;
			try session.researcherName = me.ternary(~isempty(me.researcherName), me.researcherName, me.user); end
			try session.labName        = me.ternary(~isempty(s.lab),             s.lab,             me.labName); end
			if ~isempty(me.location); session.location = me.location; end
			session.dataBucket     = lower(session.labName);
			session.dataRepo       = me.dataRepo;
			if isempty(session.labName)
				log{end+1} = sprintf('  ↳ No lab name in the ALF path, we need to get this from the MAT file otherwise upload will fail');
			end

			%% === Build paths struct mimicking runExperiment.paths
			paths = struct();
			paths.ALFPath        = s.alfPath;
			paths.sessionID      = str2double(s.sessionID);
			paths.ALFKeyShort    = s.alfKeyShort;
			paths.ALFKey         = me.ternary(~isempty(session.labName), ...
				fullfile(session.labName, 'subjects', s.subject, s.date, s.sessionID), ...
				fullfile(s.subject, s.date, s.sessionID));

			%% === Collect files now — we need them to extract the timestamp
			sFiles = dir(paths.ALFPath);
			sFiles = sFiles(~[sFiles.isdir]);
			sFiles = me.normalizeDiaryLogFiles(sFiles);
			if isempty(sFiles)
				log{end+1} = printf('  ↳ No files found in %s, skipping.', paths.ALFPath);
				return;
			end
			files = arrayfun(@(f) fullfile(f.folder, f.name), sFiles, 'UniformOutput', false);
			log{end+1} = sprintf('  ↳ %d file(s) found.\n', numel(files));

			%% === Extract start_time from filename timestamps -------------------
			startTime = me.extractStartTime(sFiles, s.date);
			log{end+1} = sprintf('  ↳ Session start_time: %s', char(startTime, 'yyyy-MM-dd''T''HH:mm:ss'));

			%% === check if a mat file is present and it contains session data
			% if so we prefer this session info
			[tmpSession, json] = getSessionDetails(me, files);
			if ~isempty(tmpSession)
				try session.researcherName = tmpSession.researcherName; end
				try session.location = tmpSession.location; end %#ok<*TRYNC>
				try session.project = tmpSession.project; end
				try session.procedure = tmpSession.procedure; end
				try session.brainRegion = tmpSession.brainRegion; end
				session.dataBucket     = lower(session.labName);
			end

			%% === Validate subject / user / lab exist in Alyx before proceeding
			if ~me.dryRun
				session = validateSession(me, session);
				if ~isfield(session,'labName'); session.labName = 'Unknown'; end
				if ~isfield(session,'project'); session.project = 'Unknown'; end
				if ~isfield(session,'researcherName'); session.researcherName = 'Unknown'; end
			end
			%% ============================================================CREATE SESSION
			% Check if this session already exists in Alyx (using the real date)
			% Use only the date part for the date_range query
			dayDate = char(startTime, 'yyyy-MM-dd');
			alyxSession = [];
			if ~me.dryRun
				request = sprintf('sessions?date_range=%s,%s&subject=%s&number=%s', ...
					dayDate, dayDate, s.subject, s.sessionID);
				[alyxSession, sc] = me.alyx.getData(request);
				if sc == 200 && ~isempty(alyxSession)
					log{end+1} = sprintf('  ↳ Session already in Alyx (id=%s), skipping creation.', alyxSession(1).id);
					me.alyx.sessionURL = alyxSession(1).url;
					alyxSession = alyxSession(1);
					if ~isempty(json)
						t = updateJSON(me, alyxSession, json); 
						if ~isempty(t); log{end+1} = t; end
					end
				else
					[url, alyxSession] = me.createAlyxSession(paths, session, json, startTime);
					if ~exist('url','var') || isempty(url); error("Could not create a new session!"); end
					log{end+1} = '  ↳ Session created...';
					me.alyx.sessionURL = url;
					me.alyx.updateNarrative("Session created by alyxUploader");
				end
				log{end+1} = [' <a href="' char(me.alyx.sessionURL) '">' char(me.alyx.sessionURL) '</a> '];
			else
				log{end+1} = sprintf('  [DryRun] Would create Alyx session with start_time %s.', ...
					char(startTime, 'yyyy-MM-dd''T''HH:mm:ss'));
			end
			doClose = false;

			%% =========================================================================
			% Register files with Alyx
			if ~me.dryRun
				setQC = false;
				filenames = {};
				uuids = {};
				datasets = struct.empty;
				try
					localFiles = me.buildLocalFileRecords(sFiles);
					existingDatasets = me.getExistingDatasets(alyxSession);
					[filesToRegister, matchedFiles] = me.findMissingDatasets(localFiles, existingDatasets);
					if ~isempty(matchedFiles)
						log{end+1} = sprintf('  ↳ %d dataset(s) already present in Alyx; skipping.', ...
							numel(matchedFiles));
					end
					if isempty(filesToRegister)
						log{end+1} = sprintf('  ↳ All %d local file(s) are already registered in Alyx.', ...
							numel(localFiles));
						setQC = true;
					else
						log{end+1} = sprintf('  ↳ %d local file(s) will be registered.', ...
							numel(filesToRegister));
						if ~isempty(filesToRegister) && ~isempty(existingDatasets)
							filesToRegister = avoidNameCollisions(me, filesToRegister, existingDatasets);
						end
						[datasets, filenames, uuids] = me.registerDatasets(paths, session, filesToRegister);
					end
					if ~isempty(filesToRegister) && isempty(datasets)
						log{end+1} = sprintf('≣≣≣≣⊱ WARNING Files Failed to Send, could be the same named file already exists: %s', me.alyx.sessionURL);
					elseif ~isempty(datasets)
						doClose = true;
						log{end+1} = sprintf('≣≣≣≣⊱ Added %d File(s) to ALYX Session: %s', ...
							numel(filenames), me.alyx.sessionURL);
						try 
							arrayfun(@(ss)disp([ss.name ' - bytes: ' num2str(ss.file_size)]),datasets); 
						end
					end
				catch ERR
					getReport(ERR)
					log{end+1} = sprintf('registering missing datasets failed: %s', ERR.message);
					warning('alyxUploader:registerFail', log{end});
				end
			else
				log{end+1} = sprintf('  [DryRun] Would register %d file(s) with Alyx.', numel(files));
				log{end+1} = sprintf ("  %s",string(files));
			end

			%% =========================================================================
			% Upload to S3
			if ~me.dryRun && ~isempty(datasets) && ~isempty(filenames)
				[uploaded, log] = uploadToS3(me, filenames, uuids, paths, session, log);
				setQC = ~isempty(uploaded) && all(uploaded);
			elseif me.dryRun
				log{end+1} = sprintf('  [DryRun] Would upload the %d file(s) to S3 bucket "%s".', ...
					numel(files), lower(session.labName));
				setQC = false;
			end

			%% =========================================================================
			% if the upload was successful, set the dataset QC to PASS in ALYX
			if setQC
				qc = struct("qc", "PASS", "default", true);
				%% set the dataset QC to PASS if upload successful
				for ii = 1:length(uuids)
					if ~isempty(uuids{ii})
						me.alyx.postData("datasets/"+string(uuids{ii}), qc, 'PATCH');
					end
				end
				log{end+1} = sprintf('≣≣≣≣⊱ Set ALYX QC to PASS for session: %s', me.alyx.sessionURL);
			end

			% Close the Alyx session with the original end_time
			% Use folder date at end-of-day as a reasonable end_time when not known
			if ~me.dryRun && ~isempty(me.alyx.sessionURL) && doClose
				me.alyx.closeSession('Uploaded via alyxUploader', 'PASS');
				log{end+1} = sprintf('  ↳ Alyx session closed.');
			end
		end

		% ===================================================================
		function new = avoidNameCollisions(~, new, old)
		% ===================================================================
			if isempty(new) || isempty(old); return; end
			for ii = 1:length(new)
				if matches(new(ii).name,{old.name})
					[p,f,e] = fileparts(new(ii).fullPath);
					newName = [f 'A' e];
					newPath = fullfile(p, newName);
					movefile(new(ii).fullPath,newPath);
					new(ii).fullPath = newPath;
					new(ii).name = newName;
				end
			end
		end

		% ===================================================================
		function log = updateJSON(me, session, json)
		% ===================================================================
			endpoint = ['sessions/', session.id];
			details = me.alyx.getData(endpoint);
			tmp = [];
			log = '';
			if ~isempty(details)
				tmp.json = json;
				tmpjson = jsondecode(json);
				if isfield(tmpjson,'totalTrials')
					tmp.n_trials = tmpjson.totalTrials;
				end
				if isfield(tmpjson,'totalCorrect')
					tmp.n_correct_trials = tmpjson.totalCorrect;
				end
				try
					if ~isempty(tmp)
						[d, status] = me.alyx.postData(endpoint,tmp,'patch');
						if status == 201
							log = '  ↳ Patched the JSON and trial numbers if valid';
						end
					end
				end
			end
		end

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
		%> passed as start_time to alyxManager.createSession.
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
		function sFiles = normalizeDiaryLogFiles(~, sFiles)
		%> @brief Ensure MATLAB diary files use the .log suffix.
		%>
		%> Files starting with "_matlab_diary" must end in ".log" before
		%> Alyx dataset registration and S3 upload. Existing names are kept
		%> intact apart from replacing the current extension with ".log". A
		%> numeric suffix is added only if needed to avoid overwriting a file.
		% ===================================================================
			for ii = 1:numel(sFiles)
				oldName = sFiles(ii).name;
				if ~startsWith(oldName, '_matlab_diary') || endsWith(oldName, '.log')
					continue;
				end

				folder = sFiles(ii).folder;
				[~, baseName] = fileparts(oldName);
				newName = [baseName '.log'];
				newPath = fullfile(folder, newName);
				counter = 2;
				while exist(newPath, 'file') == 2
					newName = sprintf('%s_%d.log', baseName, counter);
					newPath = fullfile(folder, newName);
					counter = counter + 1;
				end

				oldPath = fullfile(folder, oldName);
				[success, message] = movefile(oldPath, newPath);
				if ~success
					error('alyxUploader:diaryRenameFail', ...
						'Could not rename diary file "%s" to "%s": %s', ...
						oldPath, newPath, message);
				end

				fprintf('  ↳ Renamed MATLAB diary file: %s -> %s\n', ...
					oldName, newName);
				sFiles(ii) = dir(newPath);
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
		function [url, newSession] = createAlyxSession(me, paths, session, json, startTime)
		%> @brief Wrapper around alyxManager.createSession passing the real start_time
		%>
		%> @param startTime  datetime scalar — the timestamp parsed from filenames
		% ===================================================================
			try
				[url, newSession] = me.alyx.createSession(paths.ALFPath, paths.sessionID, session, json, startTime);
				if ~isempty(url)
					fprintf('  ↳ Created Alyx session: %s\n', url);
				else
					warning('alyxUploader:noURL', 'createSession returned empty URL');
				end
			catch ERR
				getReport(ERR)
				warning('alyxUploader:createSessionFail', 'createSession failed: %s', ERR.message);
			end
		end

		% ===================================================================
		function records = buildLocalFileRecords(~, sFiles)
		%> @brief Build local file metadata used to compare/register datasets.
		% ===================================================================
			records = struct('fullPath',{},'name',{},'bytes',{},'hash',{});
			for ii = 1:numel(sFiles)
				records(ii).fullPath = fullfile(sFiles(ii).folder, sFiles(ii).name);
				records(ii).name = sFiles(ii).name;
				records(ii).bytes = sFiles(ii).bytes;
				records(ii).hash = '';
				try
					records(ii).hash = DataHash(records(ii).fullPath, 'file', 'sha1');
				catch ERR
					warning('alyxUploader:hashFail', ...
						'Could not SHA1 hash %s: %s', records(ii).fullPath, ERR.message);
				end
			end
		end

		% ===================================================================
		function [datasets, status] = getExistingDatasets(me, alyxSession)
		%> @brief Read existing Alyx datasets for the selected session.
		% ===================================================================
			datasets = struct.empty;
			sessionID = '';
			sessionURL = me.alyx.sessionURL;
			if isstruct(alyxSession) && ~isempty(alyxSession)
				if isfield(alyxSession, 'id'); sessionID = char(string(alyxSession.id)); end
				if isfield(alyxSession, 'url'); sessionURL = char(string(alyxSession.url)); end
			end
			endpoint = '';
			if ~isempty(sessionID)
				endpoint = sprintf('datasets?session=%s', sessionID);
			elseif ~isempty(sessionURL)
				sessionURL = split(sessionURL,"/");
				sessionURL = sessionURL(end);
				endpoint = sprintf('datasets?session=%s', sessionURL);
			end
			[candidate, status] = me.alyx.getData(endpoint);
			if status ~= 200 || isempty(candidate); return; end
			candidate = me.normalizeStructArray(candidate);
			datasets = candidate;
		end

		% ===================================================================
		function [missingFiles, matchedFiles] = findMissingDatasets(me, localFiles, datasets)
		%> @brief Return local files not confirmed in Alyx by name and bytes/hash.
		% ===================================================================
			isMatched = false(1, numel(localFiles));
			for ii = 1:numel(localFiles)
				for jj = 1:numel(datasets)
					if me.datasetMatchesLocalFile(datasets(jj), localFiles(ii))
						isMatched(ii) = true;
						break;
					end
				end
			end
			matchedFiles = localFiles(isMatched);
			missingFiles = localFiles(~isMatched);
		end

		% ===================================================================
		function matched = datasetMatchesLocalFile(me, dataset, localFile)
		%> @brief True when Alyx has same filename and same byte count or hash.
		% ===================================================================
			matched = false;
			names = me.datasetNames(dataset);
			if ~any(strcmp(localFile.name, names)); return; end

			[bytes, hashes] = me.datasetSignatures(dataset);
			bytesMatch = ~isempty(bytes) && any(double(bytes) == double(localFile.bytes));
			hashMatch = ~isempty(localFile.hash) && any(strcmpi(localFile.hash, hashes));
			matched = bytesMatch || hashMatch;
		end

		% ===================================================================
		function [datasets, filenames, uuids] = registerDatasets(me, paths, session, filesToRegister)
		%> @brief Register only missing local files with Alyx.
		% ===================================================================
			datasets = struct.empty;
			filenames = {filesToRegister.fullPath};
			uuids = cell(1, numel(filesToRegister));
			if isempty(filesToRegister); return; end

			if isempty(session.labName); session.labName = me.labName; end
			if isempty(session.dataBucket); session.dataBucket = lower(me.labName); end

			rf = struct('name', session.dataBucket);
			rf.path = paths.ALFKeyShort;
			rf.filenames = filenames;
			rf.hashes = {filesToRegister.hash};
			rf.filesizes = int32([filesToRegister.bytes]);
			rf.labs = session.labName;
			try rf.created_by = session.researcherName; end
			
			%[datasets,files,success] = me.alyx.registerALFFiles(paths,session);
			[datasets, success] = me.alyx.registerFile(rf,false);
			if ~success || isempty(datasets)
				datasets = struct.empty;
				return;
			end
			datasets = me.normalizeStructArray(datasets);
			uuids = me.matchDatasetUUIDs(datasets, filesToRegister);
		end

		% ===================================================================
		function uuids = matchDatasetUUIDs(me, datasets, localFiles)
		%> @brief Match registered Alyx dataset UUIDs back to local file order.
		% ===================================================================
			uuids = cell(1, numel(localFiles));
			for ii = 1:numel(localFiles)
				uuids{ii} = '';
				for jj = 1:numel(datasets)
					if any(strcmp(localFiles(ii).name, me.datasetNames(datasets(jj)))) && ...
						isfield(datasets(jj), 'id')
						uuids{ii} = char(string(datasets(jj).id));
						break;
					end
				end
			end
		end

		% ===================================================================
		function names = datasetNames(me, dataset)
		%> @brief Collect possible dataset filenames from an Alyx dataset record.
		% ===================================================================
			names = {};
			value = me.getFieldValue(dataset, {'name', 'filename'});
			names = me.appendBasename(names, value);

			fileRecords = me.getFieldValue(dataset, {'file_records', 'fileRecords'});
			fileRecords = me.normalizeStructArray(fileRecords);
			for ii = 1:numel(fileRecords)
				value = me.getFieldValue(fileRecords(ii), ...
					{'name', 'filename', 'relative_path', 'data_url'});
				names = me.appendBasename(names, value);
			end
			names = unique(names(~cellfun(@isempty, names)));
		end

		% ===================================================================
		function [bytes, hashes] = datasetSignatures(me, dataset)
		%> @brief Collect byte counts and hashes from dataset/file_records fields.
		% ===================================================================
			bytes = [];
			hashes = {};
			[bytes, hashes] = me.appendSignature(bytes, hashes, dataset);

			fileRecords = me.getFieldValue(dataset, {'file_records', 'fileRecords'});
			fileRecords = me.normalizeStructArray(fileRecords);
			for ii = 1:numel(fileRecords)
				[bytes, hashes] = me.appendSignature(bytes, hashes, fileRecords(ii));
			end
			hashes = unique(hashes(~cellfun(@isempty, hashes)));
		end

		% ===================================================================
		function [bytes, hashes] = appendSignature(me, bytes, hashes, record)
		%> @brief Add known size/hash fields from one Alyx record.
		% ===================================================================
			byteValue = me.getFieldValue(record, ...
				{'file_size', 'filesize', 'fileSize', 'size', 'bytes'});
			if ~isempty(byteValue)
				if isnumeric(byteValue)
					bytes(end+1) = double(byteValue(1));
				else
					bytes(end+1) = str2double(char(string(byteValue)));
				end
			end

			hashValue = me.getFieldValue(record, ...
				{'hash', 'hash_sha1', 'sha1', 'file_hash', 'fileHash'});
			if ~isempty(hashValue)
				hashes{end+1} = char(string(hashValue));
			end
		end

		% ===================================================================
		function records = normalizeStructArray(~, records)
		%> @brief Convert Alyx cell/struct responses to a struct array.
		% ===================================================================
			if isempty(records)
				records = struct.empty;
			elseif iscell(records)
				records = [records{:}];
			elseif ~isstruct(records)
				records = struct.empty;
			end
		end

		% ===================================================================
		function value = getFieldValue(~, record, names)
		%> @brief Return the first non-empty value for a list of field names.
		% ===================================================================
			value = [];
			if ~isstruct(record); return; end
			for ii = 1:numel(names)
				fieldName = names{ii};
				if isfield(record, fieldName) && ~isempty(record.(fieldName))
					value = record.(fieldName);
					return;
				end
			end
		end

		% ===================================================================
		function names = appendBasename(~, names, value)
		%> @brief Append basename(s) from a char/string/cell value.
		% ===================================================================
			if isempty(value); return; end
			if iscell(value)
				values = value;
			elseif isstring(value)
				values = cellstr(value);
			elseif ischar(value)
				values = {value};
			else
				return;
			end

			newNames = cell(1, numel(values));
			nNew = 0;
			for ii = 1:numel(values)
				if isempty(values{ii}); continue; end
				[~, name, ext] = fileparts(char(string(values{ii})));
				if isempty(name) && isempty(ext); continue; end
				nNew = nNew + 1;
				newNames{nNew} = [name ext];
			end
			names = [names, newNames(1:nNew)];
		end


		% ===================================================================
		function [success, log] = uploadToS3(me, filenames, uuids, paths, session, log)
		%> @brief Upload files to S3 / MinIO via minioManager
		% ===================================================================
			arguments(Input)
				me
				filenames cell
				uuids cell
				paths struct
				session struct
				log cell
			end

			success = false(1, numel(filenames));
			if isempty(me.dataRepo)
				log{end+1} = sprintf('  ↳ dataRepo not set, skipping S3 upload.');
				disp(log{end});
				return;
			end

			try
				if isempty(me.store)
					minioID  = '';
					minioKey = '';
					try minioID  = getSecret('AWS_ID');  end 
					try minioKey = getSecret('AWS_KEY'); end 
					assert(minioID ~= "" && minioKey ~= "", ...
						'alyxUploader:noMINIOSecrets', ...
						'MINIO_ID and MINIO_KEY secrets are not set. Run setSecret(''MINIO_ID'') etc.');
					me.store = minioManager(minioID, minioKey, me.dataRepo);
				end

				bucket = lower(session.labName);
				if isempty(bucket)
					log{end+1} = 'labName is empty; cannot determine S3 bucket name. Skipping upload.';
					warning('alyxUploader:noBucket', log{end});
					return;
				end
				me.store.checkBucket(bucket);

				for ii = 1:numel(filenames)
					[~, fn, ext] = fileparts(filenames{ii});
					if ~isempty(uuids) && numel(uuids) >= ii && ~isempty(uuids{ii})
						%> ONE protocol: append UUID before extension
						key = fullfile(paths.ALFKeyShort, [fn '.' uuids{ii} ext]);
					else
						key = fullfile(paths.ALFKeyShort, [fn ext]);
					end

					%% === check if the remote file already exists on S3 ----------
					[exists, info] = me.store.statObject(bucket, key);
					if exists && isfield(info, 'size') && ~isempty(info.size)
						localInfo = dir(filenames{ii});
						if ~isempty(localInfo) && localInfo(1).bytes == info.size
							log{end+1} = sprintf('  ↳ Skipping %s (already on S3, same size %d bytes)', ...
								key, localInfo(1).bytes);
							disp(log{end});
							success(ii) = true;  % already present — considered OK
							continue;
						else
							log{end+1} = sprintf('  ↳ File %s exists remotely (remote %d, local %d bytes); re-uploading.', ...
								key, info.size, localInfo(1).bytes);
							disp(log{end});
						end
					end
					success(ii) = me.store.copyFiles(filenames{ii}, bucket, key);
				end
				log{end+1} = sprintf('  ↳ Uploaded %d file(s) to s3://%s/%s\n', ...
					numel(filenames), bucket, paths.ALFKeyShort);
				disp(log{end});
			catch ERR
				log{end+1} = sprintf('S3 upload failed: %s', ERR.message);
				warning('alyxUploader:s3Fail', log{end});
			end
		end

		% ===================================================================
		function [session, json] = getSessionDetails(me, files)
		% ===================================================================
			arguments(Input)
				me alyxUploader
				files cell
			end
			arguments(Output)
				session struct
				json char
			end

			session = []; json = '';

			for ii = 1:length(files)
				if ~contains(files{ii},{'opticka.raw','matlab.raw'}); continue; end
				ml = load(files{ii});
				%% touchData signifies a cagelab session
				if isfield(ml,'dt') && isa(ml.dt,'touchData')
					if isfield(ml,'in') 
						if isfield(ml.in,'session')
							session = ml.in.session;
						end
						if isfield(ml,'dt') && isa(ml.dt,"touchData")
							if isfield(ml,'in') && isstruct(ml.in)
								ml.in.totalCorrect = sum(ml.dt.data.result==1);
								ml.in.totalTrials = length(ml.dt.data.result);
							end
						end
						if isfield(ml,'in') && isstruct(ml.in)
							json = jsonencode(ml.in);
						end
					end
				elseif isfield(ml,'rE') && isa(ml.rE,'runExperiment')
					if isprop(ml.rE,'sessionData')
						session = ml.rE.sessionData;
						fn = fieldnames(session);
						for jj = 1:numel(fn)
							if isempty(session.(fn{jj})); session = rmfield(session, fn{jj}); end
						end
					end
					if isfield(ml,'tS') && isstruct(ml.tS) && isfield(ml.tS,'runName')
						session.taskProtocol = ml.tS.runName;
						json = jsonencode(ml.tS);
					end
				elseif isfield(ml,'allGamesData') && isstruct(ml.allGamesData)
					nGames = length(fieldnames(ml.allGamesData))/2;
					if isfield(ml,'opts')
						json = ml.opts;
						if isfield(json,'session'); session = json.session; end
						json.nGames = nGames;
						json.sourceFile = files{ii};
						try json.tL = []; end
						try json.aM = []; end
					else
						json.nGames = nGames;
						json.sourceFile = files{ii};
					end
					json = jsonencode(json);
				end
				clear ml;
			end
		end

		% ===================================================================
		function session = validateSession(me, session)
		%> @brief Check entries exist in Alyx database; if only the
		%> case differs from a remote name, replace rather than drop.
		% ===================================================================
			toCheck = dictionary("subjectName", "subjects",...
				"labName",			"labs",...
				"location",			"locations",...
				"researcherName",	"users",...
				"brainRegion",		"brain-regions",...
				"procedure",		"procedures", ...
				"project",			"projects");
			myKeys = keys(toCheck)';
			for key = myKeys
				if ~isfield(session, key); continue; end
				[remoteNames, found] = me.getRemoteNames(toCheck(key));
				if ~found
					session = rmfield(session, key);
					continue;
				end
				remoteNames = string(remoteNames);
				localVal = string(session.(key));
				ci = matches(remoteNames, localVal, 'IgnoreCase', true);
				if ~any(ci)
					session = rmfield(session, key);
					continue;
				end
				if ~matches(remoteNames, localVal, 'IgnoreCase', false)
					session.(key) = char(remoteNames(find(ci, 1)));
				end
			end
		end

		% ===================================================================
		function [names, success] = getRemoteNames(me, type)
		%> @brief Fetch all valid names for a given Alyx type (e.g. 'subjects').
		%>
		%> Returns the list of canonical names as a string array. Results are
		%> cached per type, mirroring the cache strategy in alyxManager.hasEntry.
		% ===================================================================
			typeKey = string(type);
			if numEntries(me.cache) > 0 && isKey(me.cache, typeKey)
				rt = lookup(me.cache, typeKey);
				while isscalar(rt); rt = rt{1}; end
				names = string(rt);
				success = true;
				return;
			end

			[data, status] = me.alyx.getData(type);
			success = status == 200 && isstruct(data) && ~isempty(data);
			names = string.empty;
			if ~success; return; end
			switch type
				case {'subjects'}
					names = string({data(:).nickname});
				case {'tags','tasks','procedures','labs','locations','brain-regions','projects','data-repository','dataset-types'}
					names = string({data(:).name});
				case {'users'}
					names = string({data(:).username});
				case {'sessions'}
					names = string({data(:).id});
				otherwise
					success = false;
					return;
			end
			me.cache = insert(me.cache, typeKey, {cellstr(names)});
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
