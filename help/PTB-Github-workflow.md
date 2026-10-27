# Running Psychtoolbox-backed unit tests on GitHub Actions runners

*A field note from the Opticka project: how we test a framework whose whole
purpose is drawing things on screens, on machines that have no screen at all.*

---

Opticka is built on [Psychtoolbox](https://psychtoolbox.org) (PTB). That means
the heart of the framework — `screenManager`, every stimulus class, the flip
loop — ultimately bottoms out in `Screen`, a MEX binary that wants a real X
server, a real GPU, and ideally a monitor that reports honest refresh
timings. A GitHub Actions runner has none of those. And yet we run the full
unit suite on every push.

This post is the recipe we settled on, plus the potholes we found by driving
into them.

## The core idea: split your tests, not your framework

The single most important decision came *before* any CI plumbing: **most of
what you want to test has nothing to do with the display.**

A stimulus class is really three things glued together:

1. *Logic* — parameter validation, degree↔pixel conversion, colour maths,
   serialisation, state machines, randomisation.
2. *Drawing calls* — "set this texture, draw this quad, flip".
3. *Timing behaviour* — VBL synchronisation, frame drops.

Category 1 is the bulk of the code and needs **zero** display. Category 3 is
exactly what a virtual display *cannot* honour honestly, so it should not be
unit-tested at all. Category 2 sits awkwardly in the middle.

So Opticka tests carry tags:

```matlab
methods (Test, TestTags = {'CI'})       % runs everywhere
    function testToPixelsConversion(testCase) ... end
end

methods (Test, TestTags = {'hardware'}) % runs only on real rigs
    function testFlipAfterOpen(testCase)
        assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI');
        ...
    end
end
```

CI-tagged tests never touch `Screen`. Hardware-tagged tests open real windows,
flip, draw — and are skipped *by assumption*, not by filtering. More on why
that distinction matters later.

## Technique 1: give MATLAB a fake display before it wakes up

PTB's `Screen` MEX probes the X server the moment it initialises. Without a
display you get the infamous:

```
FATAL ERROR: Couldn't open default X11 display connection to X-Server!!!
```

Xvfb solves this. In the workflow we start it as its own step and export
`DISPLAY` through `$GITHUB_ENV` so *every subsequent step* inherits it:

```yaml
- name: Start virtual display
  run: |
    Xvfb :99 -screen 0 1024x768x24 > /tmp/xvfb.log 2>&1 &
    echo "DISPLAY=:99" >> "$GITHUB_ENV"
```

Locally, the wrapper script `tests/runOptickaTestsXvfb.sh` does the same job
in one line with `xvfb-run -a`:

```bash
exec xvfb-run -a -s "-screen 0 ${xvfb_screen}" "$matlab_bin" -batch "$matlab_command"
```

**Pitfall #1 — order of operations.** `DISPLAY` must exist *before* MATLAB
starts, because user `startup.m` files often poke `Screen` during startup (ours
sets a visual debug level). If MATLAB boots headless, startup errors loudly.
It's usually non-fatal for `-batch` sessions — execution continues — but it
pollutes logs and can mask real failures. Start Xvfb first. Always first.

## Technique 2: install PTB without ever answering a prompt

The interactive `SetupPsychtoolbox()` asks questions. CI cannot answer. Our
`setupOptickaCI.m` therefore skips it entirely and just puts PTB on the path:

```matlab
ptbRoot = '/tmp/PTB/Psychtoolbox';
addpath(genpath(ptbRoot));
```

with the release downloaded earlier in the workflow:

```yaml
- name: Download Psychtoolbox dependency
  run: |
    curl -L -o /tmp/ptb.zip https://github.com/Psychtoolbox-3/Psychtoolbox-3/releases/download/3.0.21.0/3.0.21.0.zip \
      && unzip -o -d /tmp/PTB /tmp/ptb.zip
```

**Pitfall #2 — pin the version, and pin it deliberately.** We pin **V3.0.21**
because it is the last release whose prebuilt Linux MEX binaries behave on CI
images. A floating `git clone` of PTB gives you source that may need
`make` — and even when prebuilt binaries exist, a mismatch between the MEX
ABI and the runner's MATLAB release surfaces as cryptic load failures or,
worse, silently degraded timing functions.

Which leads to the check we run after path setup:

```matlab
if exist('GetSecs', 'file') ~= 3   % 3 = MEX-file
    warning('GetSecs is not a MEX file — timing precision reduced.');
end
```

It only warns, because most tests don't care — but if the warning appears in
CI logs, something regressed upstream.

**Pitfall #3 — native library deps.** PTB links against X/GL/firewire
libraries the bare runner lacks:

```yaml
sudo apt-get install -y xvfb xauth libglut-dev libglu1-mesa-dev \
     libx11-dev libdc1394-dev libraw1394-dev curl
```

Miss `libglut-dev` or friends and `Screen` fails to load with errors that
look nothing like "missing library".

**Pitfall #4 — `savepath` will fail, and that's fine.** Runners can't write
to MATLAB's installed `pathdef.m`, so any `addpath` helper that calls
`savepath` warns. Don't "fix" this by fighting permissions; accept the
warning — path changes persist for the session, which is all a CI job needs.

## Technique 3: gate hardware tests with assumptions, not filters

Here's a subtlety that cost us some confusion: our local runner
(`runOptickaTests`) uses `TestSuite.fromFolder` and **does not filter by
tag**. So how do hardware tests stay out of CI? They skip themselves:

```matlab
assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI');
```

GitHub Actions sets `GITHUB_ACTIONS=true`, the assumption fails, and
`matlab.unittest` records the test as *filtered/incomplete* rather than
failed — the suite stays green while the same file runs fully on a lab rig
with a real display. Assumptions also express intent better than external
filtering: the person writing the test declares its requirements right where
the requirement exists.

If you prefer explicit control, our runner filters by tag:
`runOptickaTests('excludeTag','hardware')` (the legacy
`runtests(...,'-ExcludeTag','hardware')` flags are rejected by recent MATLAB
releases). Explicit filtering works too — but then every entry point must
remember to pass it. The self-skipping gate travels with the test.

## Technique 4: assert on maths and state, never on photons

What do CI-safe stimulus tests actually check? Things like:

```matlab
% coordinate transforms — pure arithmetic given screen geometry
[pX, pY] = sM.toPixels(degX, degY);
verifyEqual(testCase, pX, expectedPixels);

% object state around the window lifecycle
verifyFalse(testCase, sM.isOpen);          % before open()
% (open/close/flip live in the 'hardware' tier)
```

Resist the temptation to `Screen('OpenWindow', ...)` under Xvfb "just to see
if it works". Two reasons:

- **Sync tests.** PTB measures refresh timing against the vertical blank; a
  virtual display has no honest VBL, so `Screen` may stall, warn, or refuse.
  If you ever do open windows virtually, you must set
  `Screen('Preference', 'SkipSyncTests', 1)` (or opticka's
  `disableSyncTests`) and treat every timestamp as fiction.
- **Software OpenGL.** Without a GPU, Mesa renders on the CPU. Shaders
  compile differently, some extensions vanish, performance collapses. A
  shader test passing under llvmpipe proves almost nothing about a lab
  machine — and failing there proves even less.

The same philosophy extends to other peripherals: keyboard tests use PTB's
dummy key queues, eye trackers have recorded/dummy modes, audio managers get
a silent mode. Every hardware dependency in the framework grew a software
stub largely so that this CI story would work.

## The full picture, annotated

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6

      # native libs PTB's Screen MEX links against
      - run: |
          sudo apt-get update -qq
          sudo apt-get install -y xvfb xauth libglut-dev libglu1-mesa-dev \
               libx11-dev libdc1394-dev libraw1394-dev curl

      # pinned PTB release: prebuilt MEX, no interactive installer
      - run: |
          curl -L -o /tmp/ptb.zip https://github.com/Psychtoolbox-3/Psychtoolbox-3/releases/download/3.0.21.0/3.0.21.0.zip \
            && unzip -o -d /tmp/PTB /tmp/ptb.zip

      - uses: matlab-actions/setup-matlab@v3
        with:
          release: latest
          cache: true

      # DISPLAY must exist BEFORE MATLAB starts (startup.m safety)
      - run: |
          Xvfb :99 -screen 0 1024x768x24 > /tmp/xvfb.log 2>&1 &
          echo "DISPLAY=:99" >> "$GITHUB_ENV"

      - uses: matlab-actions/run-command@v3
        with:
          command: setupOptickaCI; runOptickaTests;
```

`setupOptickaCI` does the PTB `addpath(genpath(...))`, sanity-checks the
display variable, adds Opticka + `tests/` to the path, and warns if
`GetSecs`/`WaitSecs` aren't proper MEX files.

## Pitfall grab-bag (the short, painful list)

1. **Headless `startup.m`** calling `Screen` — noisy but survivable; still,
   guard such lines with `~isempty(getenv('DISPLAY'))`.
2. **Unpinned PTB** — new releases change MEX targets and sync-test
   behaviour; upgrade deliberately.
3. **Missing `-dev` packages** — `Screen` won't load, error messages mislead.
4. **`savepath` permission warnings** on runners — expected noise.
5. **Sync tests on Xvfb** — never trust VBL timestamps from a virtual
   display; skip sync checks or don't open windows at all in unit tests.
6. **Software GL differences** — shader-heavy tests belong on the hardware
   tier.
7. **Assume vs verify semantics** — an unmet `assume*` filters the test
   (suite stays green); a failed `verify*` fails it. Gate environment
   dependencies with assumptions exclusively.
8. **Tag filtering isn't automatic** — if your runner enumerates a folder,
   remember tests run unless they self-skip.
9. **Concurrent MATLAB sessions** (relevant if a test spawns helper MATLAB
   processes, as our ØMQ IPC suite does): fine on network licenses, but not
   guaranteed on hosted-runner licenses — gate those behind the same
   `GITHUB_ACTIONS` assumption until proven otherwise.

## Closing thought

The trick to testing display-framework code in the cloud is refusing to test
the display. Put everything that is genuinely arithmetic, state, or protocol
into the CI tier, wrap the true hardware paths in honest assumptions, and
give MATLAB a cheap fake X server purely so its startup rituals don't burn
the house down. Your runner never draws a single pixel — and that's exactly
why it can run thousands of assertions about them in ninety seconds.
