%
%PAL_version   PAL_version displays the version number of Palamedes or
%   'silently' (no command window output) return version number as string
%   or vector.
%
%  syntax: [pfhb] = PAL_version({optional argument})
%
% Without argument, PAL_version sneds ome information on Palamedes (version
%   number, citation, etc.) to the environments command window. When passed
%   the optional argument 'version_number', PAL_version sends no output to
%   command window, but returns the Palamedes versions as a 3-element 
%   vector. When passed the optional argument 'version_text', PAL_version
%   returns the Palamedes versions as a string.
%
% Introduced: Palamedes version 1.1.0 (NP)
% Modified: Palamedes version 1.10.4 (See History.m)

function [version] = PAL_version(varargin)

version_number = [1 10 4];
date_of_release = 'February 26, 2020';
version_text = [int2str(version_number(1)),'.',int2str(version_number(2)),'.',int2str(version_number(3))];

if ~isempty(varargin)
    if strcmpi(varargin{1}, 'version_number')
        version = version_number;
    end
    if strcmpi(varargin{1}, 'version_text')
        version = version_text;
    end
else
    disp(sprintf(['\nThis is Palamedes version ',version_text,' Released: ',date_of_release,'\n']));
    disp(sprintf('The Palamedes toolbox is a set of free routines for analyzing'));
    disp(sprintf('psychophysical data written and made available by Nick Prins and'));
    disp(sprintf('Fred Kingdom.\n'));
    disp(sprintf('Citation: \nPrins, N. & Kingdom, F.A.A. (2018) Applying the'));
    disp(sprintf('Model-Comparison Approach to Test Specific Research Hypotheses'));
    disp(sprintf('in Psychophysical Research Using the Palamedes Toolbox.'));
    disp(sprintf('Frontiers in Psychology, 9:1250.\n'));
    disp(sprintf('doi: 10.3389/fpsyg.2018.01250\n'));
    disp(sprintf('www.palamedestoolbox.org'));
    disp(sprintf('palamedes@palamedestoolbox.org'));
end