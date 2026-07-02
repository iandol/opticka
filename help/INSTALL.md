---
title: Installing Opticka
---

# Detailed Install Instructions {#install}

## Requirements:

* Latest Psychophysics Toolbox (V3.0.18+) — please ensure it is kept up-to-date. Also consider donating to PTB to ensure its future development: <https://www.psychtoolbox.net/#future>
* MATLAB 2021a+ (we use property validation extensively so newer MATLABs R2025a+ are better for this). While I would love to support Octave, its `classdef` support is currently incomplete...
* Ubuntu V24.04+ strongly recommended, but also runs under Ubuntu V20.04, macOS and Windows 10+
* Java V21 -- we use Java classes for communication via [ZMQ](https://github.com/zeromq/jeromq) and for 2D physics animations in PTB, newer MATLAB's do not bundle Java so download seperately.
* For Alyx, we use an S3-like store and use the [minio-cli](https://github.com/minio/mc) to send data from MATLAB to the object store.
* [Eyelink developer kit](https://www.sr-support.com) for Eyelink eyetrackers. «Class = eyelinkManager»
* [Titta Toolbox](https://github.com/dcnieho/Titta) for Tobii Pro eyetrackers. «Class = tobiiManager»
* [Palamedes Toolbox](https://www.palamedestoolbox.org) to enable staircase behavioural task control.
* [LJM](https://labjack.com/support/software/installers/ljm) for LabJack T4 / T7 digital I/O devices. «Class = labJackT»
* [Exodriver](https://labjack.com/support/software/installers/exodriver) for LabJack U3/6 devices. «Class = labJack»
* For Arduino Uno / Seeduino Xiao, there is **no need to install the official Arduino toolbox**, this hardware is supported using PTB's IOPort built-in. «Class = arduinoManager»

Opticka is tested and mostly used on 64bit Ubuntu 24.04 (in the lab) & macOS 26.x (only development) under MATLAB 2026a. The older LabJack U3/U6 interface ([`labJack.m`](https://github.com/iandol/opticka/blob/master/communication/labJack.m)) currently only works under Linux and macOS (Labjack uses a different interface on Linux/macOS vs. Windows). The newer LabJack T4/T7 interface ([`labJackT.m`](https://github.com/iandol/opticka/blob/master/communication/labJackT.m)) does work cross-platform. Linux is **by far the best OS** according the PTB developer Mario Kleiner, and receives the majority of development work from him. It is **_strongly advised_** to use it for all real data collection. My experience is that Linux is *much more* robust and performs better than both macOS or Windows, and it is well worth the effort to use Linux for all PTB experimental computers (reserving macOS or Windows systems for development).

## Using the Git repository

Using `git` to install is the recommended route; it makes it easy to update:

* Create a parent folder to hold the code, I use `~/Code/` on Ubuntu and macOS and `C:/Code/` on windows.
* `cd` to that parent folder in the terminal and run 
```shell
git clone https://github.com/iandol/opticka.git
```
* In MATLAB, `cd` to the new `~/Code/opticka` folder and run `addOptickaToPath.m`

To keep opticka up-to-date in the terminal: `git pull` — if you want to make local changes, then please create a new local branch to keep the main branch clean so you can pull without issue. If you do have issues pulling you can either (1) reset the repo losing any local changes: `git fetch -v; git reset --hard origin/master; git clean -f -d; git pull` — (2) stash your changes: `git fetch -v; git stash push; git pull`

## Using the ZIP file

I recommend using `git` as you can keep the code up-to-date by pulling from Github, but a ZIP install is a bit easier:

* Download the latest ZIP file: [GitHub ZIP File](https://github.com/iandol/opticka/archive/refs/heads/master.zip)
* Unzip the **contents** of the `opticka-master` folder in the zip to a new folder (I use `~/Code/opticka`). You should end up with something like e.g. `~/Code/opticka/opticka.m` as a path.
* In MATLAB, `cd` to that folder and run `addOptickaToPath.m`.

To keep up-to-date you should manually keep downloading and unzipping the newest versions...

## Headless SSH testing with Xvfb

PTB's `Screen` function needs an X11 display even for many non-interactive
startup and test paths. When MATLAB is launched over SSH without X11
forwarding or a local display, calls such as `Screen('Preference', ...)` can
fail before tests start. On Linux, run MATLAB under `xvfb-run` to provide a
virtual X server:

```shell
xvfb-run -a -s "-screen 0 1024x768x24" matlab -batch "addOptickaToPath; cd(optickaRoot); addpath('tests'); runOptickaTests"
```

For a single test file:

```shell
xvfb-run -a -s "-screen 0 1024x768x24" matlab -batch "addOptickaToPath; cd(optickaRoot); addpath('tests'); results = runtests('tests/TaskSequenceTest.m'); assertSuccess(results)"
```

The repository also includes a convenience wrapper:

```shell
tests/runOptickaTestsXvfb.sh
tests/runOptickaTestsXvfb.sh "addOptickaToPath; cd(optickaRoot); addpath('tests'); results = runtests('tests/TaskSequenceTest.m'); assertSuccess(results)"
```

GitHub Actions uses the same principle by starting `Xvfb` and exporting
`DISPLAY=:99` before MATLAB runs.
