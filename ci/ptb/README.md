# ci/ptb — patched `Screen.mexa64` for CI

`Screen.mexa64` here is a locally built Psychtoolbox (PTB) Screen MEX file used
by CI in both jobs. It exists for one reason.

## Why a custom binary

Stock PTB Screen segfaults on a software OpenGL renderer — Mesa llvmpipe, which
is what Xvfb provides on a GitHub runner. In `PsychOSSetVBLSyncLevel()` the code
verifies the requested swap interval:

```c
glXSwapIntervalEXT(dpy, drawable, interval);
glXQueryDrawable(dpy, drawable, GLX_SWAP_INTERVAL_EXT, &actual);
```

llvmpipe *advertises* `GLX_EXT_swap_control`, but leaves the GLX dispatch slot
that backs that drawable attribute NULL. `glXQueryDrawable()` therefore calls
through a NULL function pointer — a jump to address 0 — and takes MATLAB down.
It happens inside `libGLX_mesa`, not in X11 protocol handling, so no X11 error
handler can catch it. Every test that opens a window dies, which is why the
hardware tests were previously excluded from CI entirely.

The fix detects software rasterisers (`llvmpipe`, `softpipe`, `swrast`, …) and
skips only the query, trusting the requested interval — the same thing the
existing `GLX_SGI_swap_control` fallback already does. Hardware drivers keep the
verification.

## Provenance

| | |
|---|---|
| File | `Screen.mexa64`, 1,997,728 bytes |
| sha256 | see `Screen.mexa64.sha256` |
| PTB source | commit `c626a2380` (*"PsychPython: Bump version for 3.0.21.1 release"*), whose `Contents.m` reports `Version 3.0.21  31 March 2025` — the same release family as the 3.0.21.0 zip CI downloads |
| Source change | `Screen/Linux/GLX: Avoid GLX_SWAP_INTERVAL_EXT query on software rasterizers.` — commit `819af3eac` on branch `fix/glx-swapinterval-software-rasterizer` of <https://github.com/iandol/Psychtoolbox-3>, applied to the 3.0.21 tree as a patch |
| Toolchain | MATLAB R2026b `mex`, gcc 15.2.0, Ubuntu 26.04 x86-64 |
| Build defines | `-DPTBMODULE_Screen -DPSYCH_NOLM -DGLEW_STATIC -D_GNU_SOURCE`, no GStreamer/DC1394 (their dev headers are not installed) |
| Licence handling | `-DPSYCH_NOLM` compiles out the LexActivator manager (`PsychLM.c` is wrapped in `#ifndef PSYCH_NOLM`; `MiniBox.c` supplies `PsychIsLicensed()`), so the binary runs without an activated licence — required on ephemeral CI runners |
| Verified | 36/36 `ScreenManagerTest` hardware tests pass under Xvfb on Ubuntu 26.04 with PTB 3.0.21 m-files |

Built from the 3.0.21 sources rather than 3.0.22 so the MEX matches the m-files
in the release zip. A 3.0.22-built binary also works against 3.0.21, but this
removes the mismatch.

## Rebuilding

```bash
git clone https://github.com/iandol/Psychtoolbox-3.git ptb
cd ptb && git checkout c626a2380
git show 819af3eac | git apply --3way        # the GLX fix, applies cleanly
```

then, from `PsychSourceGL/Source`, with the dependency pruning described above:

```matlab
mex -c Common/Screen/tinyexr.cc
mex -outdir <outdir> -output Screen -largeArrayDims ...
    -DMEX_DOUBLE_HANDLE -DPTBMODULE_Screen -DPSYCH_NOLM -DGLEW_STATIC -D_GNU_SOURCE ...
    "Linux/Base/*.c" "Linux/Screen/*.c" "Common/Screen/*.c" "Common/Base/*.c" tinyexr.o ...
```

The exact command line used is the one in `PsychSourceGL/Source/linuxmakeit64.m`
(mode 0) minus `-DPTB_USE_GSTREAMER`, `-DPTBVIDEOCAPTURE_LIBDC`, `-DPTB_USE_NVSTUSB`
and the corresponding `-l` flags. Afterwards `readelf -lW Screen.mexa64` must
report `GNU_STACK ... RW` — MATLAB's mex linker already passes `-z noexecstack`.

## How CI uses it

Both jobs unpack PTB 3.0.21 into `/tmp/PTB`, clear the executable-stack flag on
its MEX files (see the workflow comments), copy this binary over
`PsychBasic/Screen.mexa64`, and verify the checked-in copy against
`Screen.mexa64.sha256`, so exactly one `Screen` binary is in play across the
workflow. The `screen-hardware` job is the one that depends on the fix: it runs
`ci/runScreenHardwareTests` against this binary, while the unit-test job
excludes the `hardware` tag and never opens a window.

## When to delete this directory

Once the fix is merged upstream (or CI moves to a PTB release that contains it),
remove `ci/ptb/` and the two "Install patched Screen.mexa64" steps. Nothing else
depends on it.
