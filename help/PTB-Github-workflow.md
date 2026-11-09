# Running Psychtoolbox tests on GitHub Actions runners

*A field note from the Opticka project: how we test a framework whose whole
purpose is drawing things on screens, on machines that have no screen at all —
and how we ended up running the window tests there too.*

---

Opticka is built on [Psychtoolbox](https://psychtoolbox.org) (PTB). That means
the heart of the framework — `screenManager`, every stimulus class, the flip
loop — ultimately bottoms out in `Screen`, a MEX binary that wants a real X
server, a real GPU, and ideally a monitor that reports honest refresh
timings. A GitHub Actions runner has none of those.

Until recently that forced a compromise: the unit suite ran in CI, the window
tests ran only on a rig. It doesn't any more. Two CI jobs now run on every
push — one for everything that never opens a window, and a second one that
opens real PTB windows under Xvfb, draws, flips and closes them, using a
`Screen.mexa64` we compile ourselves. That second job was unlocked by tracking
down a real crash at the boundary between PTB and Mesa's software rasteriser,
which is what a runner gives you instead of a GPU.

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
unit-tested at all. Category 2 sits in the middle: it needs a window, but it
does not need a *good* window. It can run against a software rasteriser, as
long as you only ask whether the calls work, not whether the result looks
right or arrives on time.

So Opticka tests carry tags:

```matlab
methods (Test, TestTags = {'CI'})       % runs everywhere
    function testToPixelsConversion(testCase) ... end
end

methods (Test, TestTags = {'hardware'}) % needs a window or a device
    function testFlipAfterOpen(testCase)
        assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI');
        ...
    end
end
```

CI-tagged tests never touch `Screen`. Hardware-tagged tests open windows,
flip, draw — and skip themselves *by assumption* rather than by filtering.
That distinction used to be the whole story; now it is only half of it,
because a second CI job deliberately defeats the assumption for the display
tests (Technique 5).

Every test file in the suite has a `hardware` block. Most stay lab-only:
audio, eye tracker, GUI interaction, stimulus appearance on a real GPU. What
we promoted into CI is the display path itself — the 36 hardware-tagged tests
in `ScreenManagerTest`, which exercise open/close, sync and async flips,
screen geometry and coordinate conversion, and every drawing primitive from
text to photodiode squares against a live GL context.

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
- name: Download Psychtoolbox dependency (V3.0.21)
  env:
    GH_TOKEN: ${{ github.token }}
  run: |
    gh release download 3.0.21.0 --repo Psychtoolbox-3/Psychtoolbox-3 \
      --pattern 3.0.21.0.zip --dir /tmp --clobber
    unzip -o -d /tmp/PTB /tmp/3.0.21.0.zip
```

We use the authenticated release API rather than the plain
`releases/download/...` URL: that endpoint intermittently answers with a
92-byte nginx "504 Gateway Time-out" page, which `unzip` then reports as
"End-of-central-directory signature not found" — a misleading error for what
is really an upstream HTTP failure.

**Pitfall #2 — pin the version, and pin it deliberately.** We pin **V3.0.21**
because it is the last release whose prebuilt Linux MEX binaries behave on CI
images, and because the patched `Screen.mexa64` (Technique 4) is built from
the same source tree. A floating `git clone` of PTB gives you source that may
need `make` — and even when prebuilt binaries exist, a mismatch between the
MEX ABI and the runner's MATLAB release surfaces as cryptic load failures or,
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
     libx11-dev libdc1394-dev libraw1394-dev curl patchelf
```

Miss `libglut-dev` or friends and `Screen` fails to load with errors that
look nothing like "missing library".

**Pitfall #4 — `savepath` will fail, and that's fine.** Runners can't write
to MATLAB's installed `pathdef.m`, so any `addpath` helper that calls
`savepath` warns. Don't "fix" this by fighting permissions; accept the
warning — path changes persist for the session, which is all a CI job needs.

## Technique 3: clear the executable-stack flag on PTB's MEX files

`ubuntu-latest` migrated to the Ubuntu 26.04 image in October 2026, and its
loader became strict about an old toolchain habit: 16 of the 19 MEX files in
the PTB 3.0.21 release request an executable stack (`PT_GNU_STACK = RWE`).
24.04 tolerated that. 26.04 refuses:

```
Invalid MEX-file '.../Screen.mexa64': cannot enable executable stack
as shared object requires: Invalid argument
```

That is fatal for all 16 affected mex files — `Screen`, `GetSecs`, `WaitSecs`,
`PsychHID` among them — and took out 109 of 617 tests, including
`AssertOpenGL`'s smoke test. Clear the execute bit on that single program
header:

```yaml
- name: Clear executable-stack flag on PTB mex files
  run: |
    find /tmp/PTB -name '*.mexa64' -print0 | xargs -0 -r patchelf --clear-execstack
    # fail loudly if any mex still asks for an executable stack
    if find /tmp/PTB -name '*.mexa64' -print0 | xargs -0 -r readelf -lW \
         | grep -q 'GNU_STACK.*RWE'; then
      echo "::error::some PTB mex files still request an executable stack"
      exit 1
    fi
```

`patchelf --clear-execstack` touches no code, symbols, sections or
relocations — it clears one bit in one program header, and none of these
binaries actually execute code from the stack. The flag is a build artefact,
not a requirement, and the loader error disappears.

## Technique 4: build a `Screen` that survives llvmpipe

With a display and loadable mex files, `Screen('Preference', ...)` works and
the unit suite runs. Opening a window was a different matter. Stock
`Screen.mexa64` segfaulted on the software rasteriser:

```
Segmentation violation
Current Thread: 'PTB mainthread'
RIP = 0000000000000000
[1] libGLX_mesa.so.0+00158029
[2] Screen.mexa64+00126380
```

That `RIP = 0` is literal: a call through a NULL function pointer inside
Mesa's libGLX, which kills the MATLAB process outright. No `assume` can save
such a job, because nothing after the crash runs.

**The diagnosis.** In `PsychOSSetVBLSyncLevel()`, PTB sets the swap interval
and then verifies it took effect:

```c
glXSwapIntervalEXT(dpy, drawable, interval);
glXQueryDrawable(dpy, drawable, GLX_SWAP_INTERVAL_EXT, &actual);
```

llvmpipe *advertises* `GLX_EXT_swap_control`, but leaves the GLX dispatch
slot that backs that drawable attribute NULL. `glXQueryDrawable()` therefore
jumps to address 0. It happens inside `libGLX_mesa`, not in X11 protocol
handling, so no X11 error handler can catch it — the failure is not a missing
library, not the MATLAB release, and not a sync test:

- the same Xvfb display reports GLX 1.4 with the llvmpipe renderer under
  `glxinfo`;
- the crash reproduces with PTB 3.0.21 and 3.0.22, under R2026b, with
  `LIBGL_ALWAYS_SOFTWARE=1`, `GALLIUM_DRIVER=llvmpipe`, and MATLAB
  `-softwareopengl`;
- forcing indirect GLX (`LIBGL_ALWAYS_INDIRECT=1`) avoids the crash but
  context creation fails cleanly (`glXCreateContext() failed`), so no window
  either;
- `SkipSyncTests` does not help, because this happens while the window is
  being opened, in swap-interval setup, before any sync test could be skipped.

**The fix.** Detect software rasterisers (`llvmpipe`, `softpipe`, `swrast`, …)
and skip only the verification query, trusting the interval that was just
requested — which is exactly what the pre-existing `GLX_SGI_swap_control`
fallback already does. Hardware drivers keep the check, because on hardware
the query is meaningful.

That change lives in `ci/ptb/` as a prebuilt binary. The provenance matters,
because a patched MEX is a fork you now own:

| | |
|---|---|
| File | `ci/ptb/Screen.mexa64`, 1,997,728 bytes |
| Integrity | pinned by `ci/ptb/Screen.mexa64.sha256`, verified in CI |
| PTB source | commit `c626a2380` (*"PsychPython: Bump version for 3.0.21.1 release"*), whose `Contents.m` reports `Version 3.0.21  31 March 2025` — the same release family as the 3.0.21.0 zip CI downloads |
| Source change | `Screen/Linux/GLX: Avoid GLX_SWAP_INTERVAL_EXT query on software rasterizers.` — commit `819af3eac` on branch `fix/glx-swapinterval-software-rasterizer` of <https://github.com/iandol/Psychtoolbox-3>, applied to the 3.0.21 tree as a patch |
| Toolchain | MATLAB R2026b `mex`, gcc 15.2.0, Ubuntu 26.04 x86-64 |
| Build defines | `-DPTBMODULE_Screen -DPSYCH_NOLM -DGLEW_STATIC -D_GNU_SOURCE`, no GStreamer/DC1394 (their dev headers are not installed) |
| Licence handling | `-DPSYCH_NOLM` compiles out the LexActivator manager (`PsychLM.c` is wrapped in `#ifndef PSYCH_NOLM`; `MiniBox.c` supplies `PsychIsLicensed()`), so the binary runs without an activated licence — required on ephemeral CI runners |
| Verified | 36/36 `ScreenManagerTest` hardware tests pass under Xvfb on Ubuntu 26.04 with PTB 3.0.21 m-files |

It is built from the 3.0.21 sources rather than 3.0.22 so the MEX matches the
m-files in the release zip; a 3.0.22-built binary also works against 3.0.21,
but that mismatch is one variable too many. Because it is built with MATLAB's
own `mex` linker (which passes `-z noexecstack`), it does not need the
`patchelf` step itself — check with `readelf -lW Screen.mexa64`, which must
report `GNU_STACK ... RW`. Rebuild instructions, including the exact `mex`
command line, are in `ci/ptb/README.md`.

In the workflow both jobs drop the same binary into place before MATLAB
starts, and verify the checked-in copy against its recorded hash:

```yaml
- name: Install patched Screen.mexa64 (Xvfb/llvmpipe GLX fix)
  run: |
    cp ci/ptb/Screen.mexa64 /tmp/PTB/Psychtoolbox/PsychBasic/Screen.mexa64
    (cd ci/ptb && sha256sum -c Screen.mexa64.sha256)
```

The hardware job is the one that depends on it. The unit job installs it too,
so there is exactly one `Screen` binary in play across the workflow and no
"works on my job" surprises.

**When to delete `ci/ptb/`.** Once the fix is merged upstream, or CI moves to a
PTB release that contains it, remove the directory and the two install steps.
Nothing else depends on it. Until then, the alternative is honest: keep window
tests off CI.

## Technique 5: gate the hardware tier twice — then open the gate on purpose

Three layers now, and the third one is the interesting inversion.

**Layer 1 — the unit job excludes the tag.** The workflow runs:

```yaml
command: setupOptickaCI; runOptickaTests('excludeTag', 'hardware');
```

`runOptickaTests` filters `suite.Tags` itself (the legacy
`runtests(...,'-ExcludeTag','hardware')` flags are rejected by recent MATLAB
releases). Hardware tests are never collected, so no entry point can
accidentally run one in the unit job.

**Layer 2 — each hardware test skips itself.** Belt and braces, because
people also run single files with plain `runtests`:

```matlab
assumeFalse(testCase, ~isempty(getenv('GITHUB_ACTIONS')), 'Skip in CI');
```

GitHub Actions sets `GITHUB_ACTIONS=true`, the assumption fails, and
`matlab.unittest` records the test as *filtered/incomplete* rather than
failed. Assumptions express intent better than external filtering: the person
writing the test declares its requirements right where the requirement lives.

**Layer 3 — the hardware job defeats the assumption.** That is a problem once
you *want* those tests to run on a runner: layer 2 will quietly skip all 36 of
them, the job will be green, and nothing will have been tested. So
`ci/runScreenHardwareTests.m` runs the `hardware`-tagged suite from
`ScreenManagerTest` and treats any incomplete result as a failure:

```matlab
setenv('GITHUB_ACTIONS', '');          %> defeat the self-skip
suite = matlab.unittest.TestSuite.fromFile(suiteFile, 'Tag', 'hardware');
results = runner.run(suite);
nSkipped = sum([results.Incomplete]);
if nSkipped > 0
    error('runScreenHardwareTests:Skipped', ...
        '%d hardware tests were skipped — the job is meant to run them.', nSkipped);
end
```

The `setenv` is not paranoia. A step-level `env: GITHUB_ACTIONS: ""` does
**not** win against the variable the runner forces into the job: MATLAB still
sees it, every test self-skips, and the suite reports 36 Incomplete. Changing
it inside the MATLAB process is what `getenv()` in the tests actually reads.

Two more details in that job:

- **It is a separate job.** A window test that crashes takes down its own job,
  not the unit-test job. Failures stay legible.
- **MATLAB is launched through `matlab-actions/run-command`.** A bare
  `matlab -batch` inside a `run:` step cannot check out a licence on a hosted
  runner, so the job dies before the first assertion.

## Assert on maths and state; on photons, only that the call works

What do CI-safe stimulus tests actually check? Things like:

```matlab
% coordinate transforms — pure arithmetic given screen geometry
[pX, pY] = sM.toPixels(degX, degY);
verifyEqual(testCase, pX, expectedPixels);

% object state around the window lifecycle
verifyFalse(testCase, sM.isOpen);          % before open()
```

The hardware tier adds the call sequence, not the picture:

```matlab
sM.disableSyncTests = true;                % mandatory under Xvfb
sM.open;
verifyTrue(testCase, sM.isOpen);
sM.flip;        %> returns, does not throw, window still valid
sM.close;
verifyFalse(testCase, sM.isOpen);
```

That is a contract test: "does the API survive a real GL context". It is not a
rendering test and not a timing test. Two rules keep it honest:

- **Sync tests are fiction on Xvfb.** PTB measures refresh against the
  vertical blank; a virtual display has no honest VBL, so `Screen` may stall,
  warn, or refuse. Every window test sets `disableSyncTests` — Opticka's
  wrapper for `Screen('Preference','SkipSyncTests',2)`, which skips the
  startup sync tests and calibration together — and treats every timestamp as
  fiction. Never assert on frame timing in CI — that belongs to the
  `hardware` tier on a rig, or to no test at all.
- **Software OpenGL is not the lab GPU.** llvmpipe renders on the CPU: shaders
  compile differently, some extensions vanish, float precision and
  anti-aliasing differ, performance collapses. A shader test passing under
  llvmpipe proves the shader compiles and the call sequence is accepted. It
  proves nothing about how the stimulus looks on a Display++ — and failing
  there proves even less.

The same philosophy extends to other peripherals: keyboard tests use PTB's
dummy key queues, eye trackers have recorded/dummy modes, audio managers get
a silent mode. Every hardware dependency in the framework grew a software
stub largely so that this CI story would work.

## The full picture, annotated

```yaml
jobs:
  test:                                   # everything that never opens a window
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6

      - name: System libraries PTB's MEX files link against
        run: |
          sudo apt-get update -qq
          sudo apt-get install -y xvfb xauth libglut-dev libglu1-mesa-dev \
               libx11-dev libdc1394-dev libraw1394-dev curl patchelf

      - name: Pinned PTB release (prebuilt MEX, no interactive installer)
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          gh release download 3.0.21.0 --repo Psychtoolbox-3/Psychtoolbox-3 \
            --pattern 3.0.21.0.zip --dir /tmp --clobber
          unzip -o -d /tmp/PTB /tmp/3.0.21.0.zip

      - name: Clear executable-stack flag (Ubuntu 26.04 loader)
        run: |
          find /tmp/PTB -name '*.mexa64' -print0 | xargs -0 -r patchelf --clear-execstack

      - name: Patched Screen.mexa64 (llvmpipe GLX fix)
        run: |
          cp ci/ptb/Screen.mexa64 /tmp/PTB/Psychtoolbox/PsychBasic/Screen.mexa64
          (cd ci/ptb && sha256sum -c Screen.mexa64.sha256)

      - uses: matlab-actions/setup-matlab@v3
        with:
          release: latest
          cache: true

      # DISPLAY must exist BEFORE MATLAB starts (startup.m safety)
      - name: Start virtual display
        run: |
          Xvfb :99 -screen 0 1024x768x24 > /tmp/xvfb.log 2>&1 &
          echo "DISPLAY=:99" >> "$GITHUB_ENV"

      - uses: matlab-actions/run-command@v3
        with:
          command: setupOptickaCI; runOptickaTests('excludeTag', 'hardware');

  screen-hardware:                        # the tier that really opens windows
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6

      # identical to the test job: system libs, PTB 3.0.21 download,
      # patchelf --clear-execstack, patched Screen + sha256 check,
      # setup-matlab, Xvfb :99 exported through $GITHUB_ENV
      - name: System libraries
        run: |
          sudo apt-get update -qq
          sudo apt-get install -y xvfb xauth libglut-dev libglu1-mesa-dev \
               libx11-dev libdc1394-dev libraw1394-dev curl patchelf

      - name: Pinned PTB release
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          gh release download 3.0.21.0 --repo Psychtoolbox-3/Psychtoolbox-3 \
            --pattern 3.0.21.0.zip --dir /tmp --clobber
          unzip -o -d /tmp/PTB /tmp/3.0.21.0.zip

      - name: Clear executable-stack flag (Ubuntu 26.04 loader)
        run: |
          find /tmp/PTB -name '*.mexa64' -print0 | xargs -0 -r patchelf --clear-execstack

      - name: Patched Screen.mexa64 (llvmpipe GLX fix)
        run: |
          cp ci/ptb/Screen.mexa64 /tmp/PTB/Psychtoolbox/PsychBasic/Screen.mexa64
          (cd ci/ptb && sha256sum -c Screen.mexa64.sha256)

      - uses: matlab-actions/setup-matlab@v3
        with:
          release: latest
          cache: true

      - name: Start virtual display
        run: |
          Xvfb :99 -screen 0 1024x768x24 > /tmp/xvfb.log 2>&1 &
          echo "DISPLAY=:99" >> "$GITHUB_ENV"

      # GITHUB_ACTIONS is cleared inside MATLAB (setenv), not in YAML: a
      # step-level env: override does not win against the runner's variable.
      - uses: matlab-actions/run-command@v3
        with:
          command: addpath('ci'); runScreenHardwareTests
```

`setupOptickaCI` does the PTB `addpath(genpath(...))`, sanity-checks the
display variable, adds Opticka + `tests/` to the path, and warns if
`GetSecs`/`WaitSecs` aren't proper MEX files.

## Reproducing the hardware job locally

On a Linux box without a display, put the patched binary in place and use the
same wrapper the unit tests use:

```bash
# keep a copy of the stock binary first!
PTB=/path/to/Psychtoolbox
cp "$PTB/PsychBasic/Screen.mexa64" ~/Screen.mexa64.stock
cp ci/ptb/Screen.mexa64 "$PTB/PsychBasic/Screen.mexa64"

cd ~/Code/opticka
tests/runOptickaTestsXvfb.sh \
  "addOptickaToPath; cd(optickaRoot); addpath('tests'); runOptickaTests('ScreenManagerTest','includeTag','hardware','verbose')"
```

`GITHUB_ACTIONS` is unset in a normal shell, so the self-skip assumptions pass
and the window tests actually run. Restore the stock binary when you update
PTB — a patched binary built against 3.0.21 and left in place across a PTB
upgrade is exactly the MEX/m-file mismatch this document warns about.

## Pitfall grab-bag (the short, painful list)

1. **Headless `startup.m`** calling `Screen` — noisy but survivable; still,
   guard such lines with `~isempty(getenv('DISPLAY'))`.
2. **Unpinned PTB** — new releases change MEX targets and sync-test
   behaviour; upgrade deliberately, and rebuild `ci/ptb/Screen.mexa64` when
   you do.
3. **Missing `-dev` packages** — `Screen` won't load, error messages mislead.
4. **`savepath` permission warnings** on runners — expected noise.
5. **Executable-stack MEX files** — Ubuntu 26.04 refuses `PT_GNU_STACK = RWE`
   with "cannot enable executable stack"; `patchelf --clear-execstack` fixes
   all of them in one pass.
6. **Sync tests on Xvfb** — never trust VBL timestamps from a virtual
   display; set `SkipSyncTests`/`disableSyncTests` in every window test.
7. **Software GL differences** — shader-heavy and appearance tests belong on
   the hardware tier; llvmpipe proves compilation, not appearance.
8. **Assume vs verify semantics** — an unmet `assume*` filters the test
   (suite stays green); a failed `verify*` fails it. Gate environment
   dependencies with assumptions exclusively.
9. **Assumptions can hide an entire job** — any job that is *supposed* to run
   hardware tests must assert zero `Incomplete` results, or it will report a
   false pass while testing nothing.
10. **`env: GITHUB_ACTIONS: ""` does not work** — the runner's variable wins;
    clear it with `setenv('GITHUB_ACTIONS','')` inside MATLAB.
11. **Tag filtering isn't automatic** — if your runner enumerates a folder,
    remember tests run unless they self-skip (or are excluded by tag).
12. **Concurrent MATLAB sessions** (relevant if a test spawns helper MATLAB
    processes, as our ØMQ IPC suite does): fine on network licenses, but not
    guaranteed on hosted-runner licenses — gate those behind the same
    `GITHUB_ACTIONS` assumption until proven otherwise.

## Closing thought

For a long time the trick to testing display-framework code in the cloud was
refusing to test the display. That is still the right instinct for timing and
appearance: those need photons, and a runner has none. But it turned out that
"can't open a window" was not a law of nature — it was one NULL GLX dispatch
slot in Mesa plus one executable-stack flag in the loader. Fix both, and 36
window tests run on every push, on a CPU rasteriser, in a job that never sees
a monitor.

Your runner now draws pixels. It still cannot tell you whether they arrived on
time, or whether they were the right colour on the right display — and that
division of labour is exactly what makes the suite trustworthy.
