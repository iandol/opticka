function runOptickaTests(varargin)
	%> Run all Opticka class-based unit tests and display results.
	%>
	%> Usage:
	%>   runOptickaTests              %> run all tests
	%>   runOptickaTests('verbose')   %> run with verbose output
	%>   runOptickaTests('HSMOption1Test')  %> run a specific test class
	%>
	%> This script is the local equivalent of the GitHub Actions
	%> matlab-actions/run-tests step. It uses runtests() which works
	%> with both class-based and function-based tests.
	%>
	%> Available test files:
	%>   HSMOption1Test              - stateMachineHSM (Option 1) tests
	%>   HSMOption2Test              - stateMachineTree (Option 2) tests
	%>   HSMCompareTest              - HSM equivalence comparison tests
	%>   HSMBenchmarkTest            - HSM timing benchmark tests
	%>   TaskSequenceTest            - taskSequence randomisation tests
	%>   TimeLoggerTest              - timeLogger timing/message tests
	%>   AudioManagerTest            - audioManager silent mode tests
	%>   StateNodeTest               - stateNode tree operation tests
	%>   BaseStimulusTest            - baseStimulus shared behaviours
	%>   ImageStimulusTest           - imageStimulus property & PTB tests
	%>   GratingStimulusTest         - gratingStimulus property & PTB tests
	%>   DiscStimulusTest            - discStimulus property & PTB tests
	%>   BarStimulusTest             - barStimulus property & PTB tests
	%>   MetaStimulusTest            - metaStimulus container tests
	%>   TouchManagerTest            - touchManager dummy/PTB tests
	%>   AnimationManagerTest        - animationManager dyn4j tests
	%>   FixationCrossStimulusTest   - fixationCrossStimulus property & PTB tests
	%>   SpotStimulusTest            - spotStimulus property & PTB tests
	%>   GaborStimulusTest           - gaborStimulus procedural gabor tests
	%>   DotsStimulusTest            - dotsStimulus coherence/density tests
	%>   CheckerboardStimulusTest    - checkerboardStimulus GLSL shader tests
	%>   ColourGratingStimulusTest   - colourGratingStimulus dual-colour tests
	%>   LogGaborStimulusTest        - logGaborStimulus band-pass filter tests
	%>   AnnulusStimulusTest         - annulusStimulus dual-frequency tests
	%>   ApparentMotionStimulusTest  - apparentMotionStimulus bar flash tests
	%>   NDotsStimulusTest           - ndotsStimulus limited-lifetime dots tests
	%>   PolarGratingStimulusTest    - polarGratingStimulus radial/circular/spiral tests
	%>   PolarBoardStimulusTest      - polarBoardStimulus polar checkerboard tests
	%>   RevcorStimulusTest          - revcorStimulus reverse-correlation noise tests
	%>   DotlineStimulusTest         - dotlineStimulus dot-line texture tests
	%>   EyetrackerCoreTest          - eyetrackerCore/eyelinkManager dummy mode tests
	%>   ScreenManagerTest           - screenManager properties, conversion & PTB tests
	%>   RunExperimentTest           - runExperiment construction, config & state-machine tests
	%>   OptickaGUITest              - opticka GUI, protocol loading & runTask integration test
	%>
	%> Tests tagged 'hardware' require PTB/audio hardware and are
	%> excluded from CI (GitHub Actions). Run locally with:
	%>   runtests('tests/', '-IncludeTag', 'hardware')
	%>
	%> Copyright (c) 2026 Ian Max Andolina — LGPL3, see LICENCE.md
	addOptickaToPath;
	testDir = fileparts(mfilename('fullpath'));
	verbose = false;
	specific = '';
	for i = 1:length(varargin)
		if strcmpi(varargin{i}, 'verbose')
			verbose = true;
		else
			specific = varargin{i};
		end
	end
	if ~isempty(specific)
		suite = matlab.unittest.TestSuite.fromFile(fullfile(testDir, [specific '.m']));
	else
		suite = matlab.unittest.TestSuite.fromFolder(testDir);
	end
	if verbose
		runner = matlab.unittest.TestRunner.withTextOutput;
	else
		runner = matlab.unittest.TestRunner.withDefaultPlugins;
	end
	results = runner.run(suite);
	nFailed = sum([results.Failed]);
	if nFailed > 0
		error('runOptickaTests: %d of %d tests failed', nFailed, length(results));
	end
	fprintf('\n===== ALL TESTS PASSED (%d) =====\n', length(results));
end
