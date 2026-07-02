#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

matlab_bin="${MATLAB_BIN:-matlab}"
xvfb_screen="${XVFB_SCREEN:-1024x768x24}"

if [[ $# -gt 0 ]]; then
	matlab_command="$*"
else
	matlab_command="addOptickaToPath; cd(optickaRoot); addpath('tests'); runOptickaTests"
fi

exec xvfb-run -a -s "-screen 0 ${xvfb_screen}" "$matlab_bin" -batch "$matlab_command"
