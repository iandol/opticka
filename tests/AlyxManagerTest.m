% ========================================================================
%> @class AlyxManagerTest
%> @brief Class-based unit tests for alyxManager.
%>
%> Tests construction, validation, endpoint generation, secret assignment,
%> login/logout state, queue handling, helper methods, and read-only Alyx
%> operations. Live tests are tagged `live` and never create sessions or
%> delete data.
%>
%> Run with:
%>   >> runtests('tests/AlyxManagerTest.m')
%>   >> runtests('tests/AlyxManagerTest.m', '-ExcludeTag', 'live')
% ========================================================================
classdef AlyxManagerTest < matlab.unittest.TestCase

	properties
		%> temporary queue directory for each test
		queueDir char
	end

	methods (TestClassSetup)
		function setupPath(testCase)
			%> Ensure Opticka classes are on the MATLAB path.
			addOptickaToPath;
		end
	end

	methods (TestMethodSetup)
		function createTempQueue(testCase)
			%> Create an isolated queue directory for filesystem tests.
			testCase.queueDir = tempname;
			mkdir(testCase.queueDir);
		end
	end

	methods (TestMethodTeardown)
		function removeTempQueue(testCase)
			%> Remove temporary queue files created by a test.
			if ~isempty(testCase.queueDir) && exist(testCase.queueDir, 'dir')
				rmdir(testCase.queueDir, 's');
			end
		end
	end

	methods (Test, TestTags = {'CI'})
		function testConstructionDefaults(testCase)
			am = alyxManager('queueDir', testCase.queueDir, 'verbose', false);

			verifyEqual(testCase, am.baseURL, 'http://172.16.102.30:8000');
			verifyEqual(testCase, am.user, 'admin');
			verifyEqual(testCase, am.lab, 'Lab');
			verifyEqual(testCase, am.subject, 'TestSubject');
			verifyEqual(testCase, am.pageLimit, 100);
			verifyFalse(testCase, am.verbose);
			verifyFalse(testCase, am.loggedIn);
			verifyTrue(testCase, exist(am.queueDir, 'dir') == 7);
		end

		function testConstructorCustomProperties(testCase)
			am = alyxManager('baseURL', 'alyx.example.org/', ...
				'user', 'tester', 'lab', 'TestLab', ...
				'subject', 'MouseA', 'queueDir', testCase.queueDir, ...
				'pageLimit', 5, 'verbose', true);

			verifyEqual(testCase, am.baseURL, 'https://alyx.example.org');
			verifyEqual(testCase, am.user, 'tester');
			verifyEqual(testCase, am.lab, 'TestLab');
			verifyEqual(testCase, am.subject, 'MouseA');
			verifyEqual(testCase, am.pageLimit, 5);
			verifyTrue(testCase, am.verbose);
		end

		function testPropertyValidation(testCase)
			am = alyxManager('queueDir', testCase.queueDir, 'verbose', false);

			verifyError(testCase, @() setProp(am, 'pageLimit', 0), ...
				'MATLAB:validators:mustBePositive');
			verifyError(testCase, @() setProp(am, 'verbose', 1), ...
				'MATLAB:validators:mustBeA');
			verifyError(testCase, @() setProp(am, 'baseURL', ''), ...
				'Alyx:baseURL:invalidInput');
		end

		function testQueueDirSetterCreatesDirectory(testCase)
			qDir = tempname;
			am = alyxManager('queueDir', qDir, 'verbose', false);
			cleanup = onCleanup(@() removeDir(qDir)); %#ok<NASGU>
			verifyEqual(testCase, am.queueDir, qDir);
			verifyTrue(testCase, exist(qDir, 'dir') == 7);
		end

		function testMakeEndpoint(testCase)
			am = alyxManagerHarness('baseURL', 'https://alyx.example.org/', ...
				'queueDir', testCase.queueDir, 'verbose', false);

			verifyEqual(testCase, am.exposeMakeEndpoint('subjects'), ...
				'https://alyx.example.org/subjects');
			verifyEqual(testCase, am.exposeMakeEndpoint('/subjects/'), ...
				'https://alyx.example.org/subjects');
			verifyEqual(testCase, am.exposeMakeEndpoint('https://other.test/users/'), ...
				'https://other.test/users');
			verifyError(testCase, @() am.exposeMakeEndpoint(''), ...
				'Alyx:makeEndpoint:invalidInput');
		end

		function testExplicitSecrets(testCase)
			am = alyxManager('queueDir', testCase.queueDir, 'verbose', false);
			am.setSecrets('pw', 'awsId', 'awsKey');
			secrets = am.getSecrets();

			verifyTrue(testCase, am.hasSecrets());
			verifyEqual(testCase, secrets.user, am.user);
			verifyEqual(testCase, secrets.password, 'pw');
			verifyEqual(testCase, secrets.AWS_ID, 'awsId');
			verifyEqual(testCase, secrets.AWS_KEY, 'awsKey');
		end

		function testLoginAndLogoutWithMockToken(testCase)
			am = alyxManagerHarness('queueDir', testCase.queueDir, ...
				'user', 'tester', 'verbose', false);
			am.setSecrets('pw', '', '');
			am.nextStatusCode = 200;
			am.nextResponseBody = struct('token', 'abc123');

			success = am.login();

			verifyTrue(testCase, success);
			verifyTrue(testCase, am.loggedIn);
			verifyEqual(testCase, am.lastEndpoint, 'auth-token');
			verifyEqual(testCase, am.lastRequestMethod, 'post');
			verifyTrue(testCase, contains(am.lastJsonData, 'tester'));
			verifyEqual(testCase, am.webOptions.HeaderFields, ...
				{'Authorization', 'Token abc123'});

			am.logout();
			verifyFalse(testCase, am.loggedIn);
			verifyEmpty(testCase, am.sessionURL);
		end

		function testPostDataQueuesWhenLoggedOut(testCase)
			am = alyxManager('queueDir', testCase.queueDir, 'verbose', false);
			[data, statusCode] = am.postData('sessions', struct('name', 'dry-run'));

			verifyEmpty(testCase, data);
			verifyEqual(testCase, statusCode, 0);
			queued = dir(fullfile(testCase.queueDir, '*.post'));
			verifyNumElements(testCase, queued, 1);
			body = fileread(fullfile(queued(1).folder, queued(1).name));
			verifyTrue(testCase, startsWith(body, 'sessions'));
			verifyTrue(testCase, contains(body, 'dry-run'));
		end

		function testFlushQueueSuccessDeletesFile(testCase)
			am = alyxManagerHarness('queueDir', testCase.queueDir, 'verbose', false);
			am.forceToken('abc123');
			am.nextStatusCode = 201;
			am.nextResponseBody = struct('url', 'https://alyx.example.org/sessions/1');
			writeQueueFile(testCase.queueDir, 'sessions', '{"subject":"MouseA"}', 'post');

			[data, statusCode] = am.exposeFlushQueue(false);

			verifyEqual(testCase, statusCode, 201);
			verifyEqual(testCase, data.url, 'https://alyx.example.org/sessions/1');
			verifyEmpty(testCase, dir(fullfile(testCase.queueDir, '*.post')));
			verifyEqual(testCase, am.lastRequestMethod, 'post');
		end

		function testFlushQueueServerErrorPreservesFile(testCase)
			am = alyxManagerHarness('queueDir', testCase.queueDir, 'verbose', false);
			am.forceToken('abc123');
			am.nextStatusCode = 503;
			am.nextResponseBody = 'server unavailable';
			writeQueueFile(testCase.queueDir, 'sessions', '{"subject":"MouseA"}', 'post');

			[~, statusCode] = am.exposeFlushQueue(false);

			verifyEqual(testCase, statusCode, 503);
			verifyNumElements(testCase, dir(fullfile(testCase.queueDir, '*.post')), 1);
		end

		function testHasEntryCachesReadOnlyCollections(testCase)
			am = alyxManagerHarness('queueDir', testCase.queueDir, 'verbose', false);
			am.mockData.subjects = struct('nickname', {'MouseA', 'MouseB'});

			verifyTrue(testCase, am.hasEntry('subjects', 'MouseA'));
			verifyTrue(testCase, am.hasEntry('subjects', 'MouseB'));
			verifyEqual(testCase, am.getDataCallCount, 1);
			verifyFalse(testCase, am.hasEntry('subjects', 'MissingMouse'));
		end

		function testListSubjectsSortsCurrentUserFirst(testCase)
			am = alyxManagerHarness('queueDir', testCase.queueDir, ...
				'user', 'tester', 'verbose', false);
			am.forceToken('abc123');
			am.mockData.subjects = struct( ...
				'nickname', {'MouseB', 'MouseA', 'MouseC'}, ...
				'responsible_user', {'other', 'tester', 'tester'});

			subjects = am.listSubjects(false, true, true);

			verifyEqual(testCase, subjects(:)', {'default', 'MouseA', 'MouseC', 'MouseB'});
			verifyEqual(testCase, am.lastGetEndpoint, 'subjects?stock=False&alive=True');
		end

		function testGetSessionsBuildsReferenceQuery(testCase)
			am = alyxManagerHarness('queueDir', testCase.queueDir, 'verbose', false);
			am.mockData.sessions = struct('url', ...
				'https://alyx.example.org/sessions/11111111-2222-3333-4444-555555555555', ...
				'id', '11111111-2222-3333-4444-555555555555');

			[sessions, eids] = am.getSessions('2026-01-02_3_MouseA');

			verifyEqual(testCase, sessions.id, '11111111-2222-3333-4444-555555555555');
			verifyEqual(testCase, eids, {'11111111-2222-3333-4444-555555555555'});
			verifyEqual(testCase, am.lastGetEndpoint, 'sessions/');
			verifyEqual(testCase, am.lastGetArgs, ...
				{'subject', 'MouseA', 'date_range', '2026-01-02,2026-01-02', 'number', '3'});
		end

		function testUpdateNarrativeUsesPatch(testCase)
			am = alyxManagerHarness('queueDir', testCase.queueDir, 'verbose', false);
			am.sessionURL = 'https://alyx.example.org/sessions/session-id';
			am.mockData.session = struct('narrative', 'old note');
			am.mockPostResponse = struct('narrative', sprintf('old note\\nnew note'));

			narrative = am.updateNarrative('new note');

			verifyEqual(testCase, narrative, sprintf('old note\nnew note'));
			verifyEqual(testCase, am.lastPostEndpoint, am.sessionURL);
			verifyEqual(testCase, am.lastPostMethod, 'patch');
			verifyTrue(testCase, contains(am.lastPostData.narrative, 'old note'));
			verifyTrue(testCase, contains(am.lastPostData.narrative, 'new note'));
		end

		function testStaticHelpers(testCase)
			[a, wrapped] = alyxManager.ensureCell(5);
			verifyEqual(testCase, a, {5});
			verifyTrue(testCase, wrapped);

			flat = alyxManager.cellflat({1, {2, []}});
			verifyEqual(testCase, flat, {1; 2; []});

			s = alyxManager.catStructs({struct('a', 1), struct('b', 2)}, NaN);
			verifyEqual(testCase, [s.a], [1 NaN]);
			verifyEqual(testCase, [s.b], [NaN 2]);

			eid = '11111111-2222-3333-4444-555555555555';
			verifyEqual(testCase, alyxManager.url2eid(['https://x/sessions/' eid '/']), eid);
			verifyEqual(testCase, alyxManager.url2eid({['https://x/sessions/' eid]}), {eid});
		end
	end

	methods (Test, TestTags = {'live'})
		function testLiveLoginAndReadOnlyRequest(testCase)
			am = alyxManager('queueDir', testCase.queueDir, 'verbose', false);
			assumeTrue(testCase, am.hasSecrets(), ...
				'No local Alyx credentials available for live test');

			success = am.login();
			assumeTrue(testCase, success && am.loggedIn, ...
				'Could not log in to Alyx for live read-only test');

			[data, statusCode] = am.getData('users', 'limit', 1);
			verifyEqual(testCase, statusCode, 200);
			verifyNotEmpty(testCase, data);
			am.logout();
		end
	end
end


function setProp(obj, prop, value)
	%> Trigger a property setter for validation tests.
	obj.(prop) = value;
end

function writeQueueFile(queueDir, endpoint, jsonData, extension)
	%> Write a queued Alyx operation to the temporary queue.
	filename = fullfile(queueDir, ['queued.' extension]);
	fid = fopen(filename, 'w');
	cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
	fprintf(fid, '%s\n%s', endpoint, jsonData);
end

function removeDir(qDir)
	%> Remove a directory if it still exists.
	if exist(qDir, 'dir')
		rmdir(qDir, 's');
	end
end
