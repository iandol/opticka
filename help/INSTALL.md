# Detailed Install Instructions {#install}

## Requirements:

* Latest Psychophysics Toolbox (V3.0.18+) — please ensure it is kept up-to-date. Also consider donating to PTB to ensure its future development: <https://www.psychtoolbox.net/#future>
* MATLAB 2017a+ (Opticka utilises object-oriented property validation first introduced in that version). While I would love to support Octave, its `classdef` support is currently incomplete...
* Ubuntu V22.04+ strongly recommended, but also runs under Ubuntu V20.04, macOS and Windows 10+
* [Eyelink developer kit](https://www.sr-support.com) for Eyelink eyetrackers. «Class = eyelinkManager»
* [Titta Toolbox](https://github.com/dcnieho/Titta) for Tobii Pro eyetrackers. «Class = tobiiManager»
* [LJM](https://labjack.com/support/software/installers/ljm) for LabJack T4 / T7 digital I/O devices. «Class = labJackT»
* [Exodriver](https://labjack.com/support/software/installers/exodriver) for LabJack U3/6 devices. «Class = labJack»
* For Arduino Uno / Seeduino Xiao, there is **no need to install the official Arduino toolbox**, this hardware is supported using PTB's IOPort built-in. «Class = arduinoManager»

Opticka is tested and mostly used on 64bit Ubuntu 20.04 (in the lab) & macOS 12.x (only development) under MATLAB 2021b. The older LabJack U3/U6 interface ([`labJack.m`](https://github.com/iandol/opticka/blob/master/communication/labJack.m)) currently only works under Linux and macOS (Labjack uses a different interface on Linux/macOS vs. Windows). The newer LabJack T4/T7 interface ([`labJackT.m`](https://github.com/iandol/opticka/blob/master/communication/labJackT.m)) does work cross-platform. Linux is **by far the best OS** according the PTB developer Mario Kleiner, and receives the majority of development work from him. It is **_strongly advised_** to use it for all real data collection. My experience is that Linux is *much more* robust and performs better than both macOS or Windows, and it is well worth the effort to use Linux for all PTB experimental computers (reserving macOS or Windows systems for development).

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
