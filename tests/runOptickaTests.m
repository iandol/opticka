function runOptickaTests(varargin)
%> Run Opticka class-based unit tests and display results.
%>
%> Usage (from the repository root; this function lives in tests/, which
%> addOptickaToPath excludes, so add that folder to the path first):
%>
%>   >> addpath('tests')
%>   >> runOptickaTests                  %> run every test file
%>   >> runOptickaTests('verbose')       %> run with text output
%>   >> runOptickaTests('TaskSequenceTest')  %> run one test class
%>
%>   >> runOptickaTests('excludeTag', 'hardware')
%>                                       %> every file minus hardware tests
%>   >> runOptickaTests('TaskSequenceTest', 'excludeTag', 'hardware')
%>   >> runOptickaTests('includeTag', 'hardware')
%>                                       %> hardware tests only
%>
%> Several tags can be passed at once, either as a cell array of char or a
%> string array: runOptickaTests('excludeTag',{'hardware','live'}).
%>
%> Tags are filtered here because the legacy runtests flags ('-IncludeTag',
%> '-ExcludeTag') are rejected by recent MATLAB releases (R2026b:
%> "Unmatched parameter name '-ExcludeTag' must be a string scalar...").
%> Filtering uses suite.Tags through cellfun, so the mask stays aligned
%> with the suite even for tests that carry no tags.
%>
%> This script is the local equivalent of the GitHub Actions
%> matlab-actions/run-tests step. It works with both class-based and
%> function-based tests.
%>
%> Available test files:
%>   AlyxManagerTest            - alyxManager REST, secret & queue tests (live tagged)
%>   AnimationManagerTest       - animationManager dyn4j tests
%>   AprilTagStimulusTest       - aprilTagStimulus marker property & PTB tests
%>   AudioManagerTest           - audioManager silent mode tests
%>   BarStimulusTest            - barStimulus property & PTB tests
%>   BaseStimulusTest           - baseStimulus shared behaviours
%>   CheckerboardStimulusTest   - checkerboardStimulus GLSL shader tests
%>   ColourGratingStimulusTest  - colourGratingStimulus dual-colour tests
%>   DiscStimulusTest           - discStimulus property & PTB tests
%>   DotlineStimulusTest        - dotlineStimulus dot-line texture tests
%>   DotsStimulusTest           - dotsStimulus coherence/density tests
%>   EyetrackerCoreTest         - eyetrackerCore/eyelinkManager dummy mode tests
%>   FixationCrossStimulusTest  - fixationCrossStimulus property & PTB tests
%>   GaborStimulusTest          - gaborStimulus procedural gabor tests
%>   GratingStimulusTest        - gratingStimulus property & PTB tests
%>   HSMBenchmarkTest           - HSM timing benchmark tests
%>   HSMCompareTest             - HSM equivalence comparison tests
%>   HSMOption1Test             - stateMachineHSM (Option 1) tests
%>   HSMOption2Test             - stateMachineTree (Option 2) tests
%>   ImageStimulusTest          - imageStimulus property & PTB tests
%>   JzmqConnectionTest         - jzmqConnection ØMQ protocol/socket tests
%>   JzmqCrossProcessTest       - jzmqConnection cross-process IPC tests (local only)
%>   LissajousPathTest          - lissajousPath generation & constant-speed tests
%>   LogGaborStimulusTest       - logGaborStimulus band-pass filter tests
%>   MetaStimulusTest           - metaStimulus container tests
%>   MovieStimulusTest          - movieStimulus property & PTB playback tests
%>   NDotsStimulusTest          - ndotsStimulus limited-lifetime dots tests
%>   OptickaGUITest             - opticka GUI, protocol loading & runTask integration test
%>   PolarBoardStimulusTest     - polarBoardStimulus polar checkerboard tests
%>   PolarGratingStimulusTest   - polarGratingStimulus radial/circular/spiral tests
%>   RevcorStimulusTest         - revcorStimulus reverse-correlation noise tests
%>   RunExperimentTest          - runExperiment construction, config & state-machine tests
%>   ScreenManagerTest          - screenManager properties, conversion & PTB tests
%>   SpotStimulusTest           - spotStimulus property & PTB tests
%>   StateNodeTest              - stateNode tree operation tests
%>   TaskSequenceTest           - taskSequence randomisation tests
%>   TimeLoggerTest             - timeLogger timing/message tests
%>   TouchManagerTest           - touchManager dummy/PTB tests
%>
%> Tests tagged 'hardware' require PTB/audio hardware and are excluded from
%> CI (GitHub Actions), where they filter themselves via assumptions. Run
%> them locally with runOptickaTests('includeTag', 'hardware').
%>
%> Copyright (c) 2026 Ian Max Andolina — LGPL3, see LICENCE.md
	testDir = fileparts(mfilename('fullpath'));
	addOptickaToPath;
	addpath(testDir); %> addOptickaToPath strips tests/, re-add our own folder

	verbose = false;
	specific = '';
	excludeTags = {};
	includeTags = {};
	i = 1;
	while i <= numel(varargin)
		arg = varargin{i};
		if isstring(arg) && isscalar(arg); arg = char(arg); end
		if ~ischar(arg) || ~isrow(arg)
			error('runOptickaTests:badArgument', ...
				'Argument %d must be a char or string, got %s.', ...
				i, class(arg));
		end
		switch lower(arg)
			case 'verbose'
				verbose = true;
				i = i + 1;
			case {'excludetag', 'includetag'}
				if i == numel(varargin)
					error('runOptickaTests:badArgument', ...
						'%s requires at least one tag name.', arg);
				end
				val = varargin{i + 1};
				if ischar(val) || isstring(val) || ...
						(iscell(val) && all(cellfun(@ischar, val)))
					tags = reshape(cellstr(string(val)), 1, []);
				else
					error('runOptickaTests:badArgument', ...
						'%s tags must be char, string or cellstr.', arg);
				end
				if isempty(tags)
					error('runOptickaTests:badArgument', ...
						'%s requires at least one tag name.', arg);
				end
				if strcmpi(arg, 'excludetag')
					excludeTags = [excludeTags tags];
				else
					includeTags = [includeTags tags];
				end
				i = i + 2;
			otherwise
				specific = arg;
				i = i + 1;
		end
	end

	if ~isempty(specific)
		% accept 'Name', 'Name.m' or 'tests/Name.m'
		[~, specific] = fileparts(specific);
		suite = matlab.unittest.TestSuite.fromFile( ...
			fullfile(testDir, [specific '.m']));
	else
		suite = matlab.unittest.TestSuite.fromFolder(testDir);
	end
	if ~isempty(excludeTags) || ~isempty(includeTags)
		suite = filterByTag(suite, includeTags, excludeTags);
	end
	if isempty(suite)
		warning('runOptickaTests:noTests', ...
			'No tests matched the requested selection.');
		return
	end

	if verbose
		runner = matlab.unittest.TestRunner.withTextOutput;
	else
		runner = matlab.unittest.TestRunner.withDefaultPlugins;
	end
	results = runner.run(suite);
	nFailed = sum([results.Failed]);
	nSkipped = sum([results.Incomplete]);
	if nFailed > 0
		error('runOptickaTests: %d of %d tests failed', ...
			nFailed, numel(results));
	end
	fprintf('\n===== ALL TESTS PASSED (%d passed, %d skipped) =====\n', ...
		numel(results) - nSkipped, nSkipped);
end

% ========================================================================
function suite = filterByTag(suite, includeTags, excludeTags)
%> Keep tests whose tag list matches any include tag and no exclude tag.
%>
%> suite.Tags is a cell array of cell arrays of char, so cellfun keeps the
%> logical mask aligned with the suite even when a test carries no tags
%> (plain concatenation, [suite.Tags], would drop those empty entries and
%> silently misalign the mask).
	if isempty(suite); return; end
	tags = {suite.Tags};
	keep = true(1, numel(tags));
	if ~isempty(includeTags)
		keep = keep & cellfun(@(c) any(ismember(c, includeTags)), tags);
	end
	if ~isempty(excludeTags)
		keep = keep & ~cellfun(@(c) any(ismember(c, excludeTags)), tags);
	end
	suite = suite(keep);
end
