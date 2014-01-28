function [hdr] = ft_read_plxheader(filename, varargin)

% FT_READ_HEADER reads header information from a variety of EEG, MEG and LFP
% files and represents the header information in a common data-independent
% format. The supported formats are listed below.
%
% Use as
%   hdr = ft_read_header(filename, ...)
%
% Additional options should be specified in key-value pairs and can be
%   'headerformat'   string
%   'fallback'       can be empty or 'biosig' (default = [])
%   'coordsys'       string, 'head' or 'dewar' (default = 'head')
%   'freq'			 number, selecting either the wideband @40Khz or LFP @1KHz
%
% This returns a header structure with the following elements
%   hdr.Fs                  sampling frequency
%   hdr.nChans              number of channels
%   hdr.nSamples            number of samples per trial
%   hdr.nSamplesPre         number of pre-trigger samples in each trial
%   hdr.nTrials             number of trials
%   hdr.label               Nx1 cell-array with the label of each channel
%   hdr.chantype            Nx1 cell-array with the channel type, see FT_CHANTYPE
%   hdr.chanunit            Nx1 cell-array with the physical units, see FT_CHANUNIT
%
% For continuously recorded data, nSamplesPre=0 and nTrials=1.
%
% For some data formats that are recorded on animal electrophysiology
% systems (e.g. Neuralynx, Plexon), the following optional fields are
% returned, which allows for relating the timing of spike and LFP data
%   hdr.FirstTimeStamp      number, 32 bit or 64 bit unsigned integer
%   hdr.TimeStampPerSample  double
%
% Depending on the file format, additional header information can be
% returned in the hdr.orig subfield.
%
% The following MEG dataformats are supported
%   CTF - VSM MedTech (*.ds, *.res4, *.meg4)
%   Neuromag - Elekta (*.fif)
%   BTi - 4D Neuroimaging (*.m4d, *.pdf, *.xyz)
%   Yokogawa (*.ave, *.con, *.raw)
%   NetMEG (*.nc)
%   ITAB - Chieti (*.mhd)
%
% The following EEG dataformats are supported
%   ANT - Advanced Neuro Technology, EEProbe (*.avr, *.eeg, *.cnt)
%   BCI2000 (*.dat)
%   Biosemi (*.bdf)
%   BrainVision (*.eeg, *.seg, *.dat, *.vhdr, *.vmrk)
%   CED - Cambridge Electronic Design (*.smr)
%   EGI - Electrical Geodesics, Inc. (*.egis, *.ave, *.gave, *.ses, *.raw, *.sbin, *.mff)
%   GTec (*.mat)
%   Generic data formats (*.edf, *.gdf)
%   Megis/BESA (*.avr, *.swf)
%   NeuroScan (*.eeg, *.cnt, *.avg)
%   Nexstim (*.nxe)
%
% The following spike and LFP dataformats are supported
%   Neuralynx (*.ncs, *.nse, *.nts, *.nev, *.nrd, *.dma, *.log)
%   Plextor (*.nex, *.plx, *.ddt)
%   CED - Cambridge Electronic Design (*.smr)
%   MPI - Max Planck Institute (*.dap)
%   Neurosim  (neurosim_spikes, neurosim_signals, neurosim_ds)
%   Windaq (*.wdq)
%
% The following NIRS dataformats are supported
%   BUCN - Birkbeck college, London (*.txt)
%
% The following Eyetracker dataformats are supported
%   EyeLink - SR Research (*.asc)
%
% See also FT_READ_DATA, FT_READ_EVENT, FT_WRITE_DATA, FT_WRITE_EVENT,
% FT_CHANTYPE, FT_CHANUNIT

% Copyright (C) 2003-2013 Robert Oostenveld
%
% This file is part of FieldTrip, see http://www.ru.nl/neuroimaging/fieldtrip
% for the documentation and details.
%
%    FieldTrip is free software: you can redistribute it and/or modify
%    it under the terms of the GNU General Public License as published by
%    the Free Software Foundation, either version 3 of the License, or
%    (at your option) any later version.
%
%    FieldTrip is distributed in the hope that it will be useful,
%    but WITHOUT ANY WARRANTY; without even the implied warranty of
%    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%    GNU General Public License for more details.
%
%    You should have received a copy of the GNU General Public License
%    along with FieldTrip. If not, see <http://www.gnu.org/licenses/>.
%
% $Id$

% TODO channel renaming should be made a general option (see bham_bdf)

persistent cacheheader        % for caching the full header
persistent cachechunk         % for caching the res4 chunk when doing realtime analysis on the CTF scanner
persistent db_blob            % for fcdc_mysql

if isempty(db_blob)
  db_blob = false;
end

% optionally get the data from the URL and make a temporary local copy
%filename = fetch_url(filename);

realtime = any(strcmp(ft_filetype(filename), {'fcdc_buffer', 'ctf_shm', 'fcdc_mysql'}));

% check whether the file or directory exists, not for realtime
if  ~realtime && ~exist(filename, 'file')
  error('FILEIO:InvalidFileName', 'file or directory ''%s'' does not exist', filename);
end

% get the options
headerformat = ft_getopt(varargin, 'headerformat');
retry        = ft_getopt(varargin, 'retry', false);     % the default is not to retry reading the header
coordsys     = ft_getopt(varargin, 'coordsys', 'head'); % this is used for ctf and neuromag_mne, it can be head or dewar
freq		 = ft_getopt(varargin, 'freq');

if isempty(headerformat)
  % only do the autodetection if the format was not specified
  headerformat = ft_filetype(filename);
end

% The checkUniqueLabels flag is used for the realtime buffer in case
% it contains fMRI data. It prevents 1000000 voxel names to be checked
% for uniqueness. fMRI users will probably never use channel names
% for anything.

if realtime
  % skip the rest of the initial checks to increase the speed for realtime operation
  
  checkUniqueLabels = false;
  % the cache and fallback option should always be false for realtime processing
  cache    = false;
  fallback = false;
  
else
  checkUniqueLabels = true;
  % the cache and fallback option are according to the user's specification
  cache    = ft_getopt(varargin, 'cache');
  fallback = ft_getopt(varargin, 'fallback');
  
  if isempty(cache),
    if strcmp(headerformat, 'bci2000_dat') || strcmp(headerformat, 'eyelink_asc') || strcmp(headerformat, 'gtec_mat') || strcmp(headerformat, 'biosig')
      cache = true;
    else
      cache = false;
    end
  end
  
  % ensure that the headerfile and datafile are defined, which are sometimes different than the name of the dataset
  [filename, headerfile, datafile] = dataset2files(filename, headerformat);
  if ~strcmp(filename, headerfile) && ~ft_filetype(filename, 'ctf_ds') && ~ft_filetype(filename, 'fcdc_buffer_offline') && ~ft_filetype(filename, 'fcdc_matbin')
    filename     = headerfile;                % this function should read the headerfile, not the dataset
    headerformat = ft_filetype(filename);     % update the filetype
  end
end % if skip initial check

% implement the caching in a data-format independent way
if cache && exist(headerfile, 'file') && ~isempty(cacheheader)
  % try to get the header from cache
  details = dir(headerfile);
  if isequal(details, cacheheader.details)
    % the header file has not been updated, fetch it from the cache
    % fprintf('got header from cache\n');
    hdr = rmfield(cacheheader, 'details');
    
    switch ft_filetype(datafile)
      case {'ctf_ds' 'ctf_meg4' 'ctf_old' 'read_ctf_res4'}
        % for realtime analysis EOF chasing the res4 does not correctly
        % estimate the number of samples, so we compute it on the fly
        sz = 0;
        files = dir([filename '/*.*meg4']);
        for j=1:numel(files)
          sz = sz + files(j).bytes;
        end
        hdr.nTrials = floor((sz - 8) / (hdr.nChans*4) / hdr.nSamples);
    end
    
    return;
  end % if the details correspond
end % if cache

% the support for head/dewar coordinates is still limited
if strcmp(coordsys, 'dewar') && ~any(strcmp(headerformat, {'fcdc_buffer', 'ctf_ds', 'ctf_meg4', 'ctf_res4', 'neuromag_fif', 'neuromag_mne'}))
  error('dewar coordinates are not supported for %s', headerformat);
end

% start with an empty header
hdr = [];

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% read the data with the low-level reading function
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
switch headerformat
  case 'plexon_ds'
    hdr = read_plexon_ds(filename);
    
  case 'plexon_ddt'
    orig = read_plexon_ddt(filename);
    hdr.nChans      = orig.NChannels;
    hdr.Fs          = orig.Freq;
    hdr.nSamples    = orig.NSamples;
    hdr.nSamplesPre = 0;      % continuous
    hdr.nTrials     = 1;      % continuous
    hdr.label       = cell(1,hdr.nChans);
    % give this warning only once
    warning('creating fake channel names');
    for i=1:hdr.nChans
      hdr.label{i} = sprintf('%d', i);
    end
    % also remember the original header
    hdr.orig        = orig;
    
  case {'read_nex_data'} % this is an alternative reader for nex files
    orig = read_nex_header(filename);
    % assign the obligatory items to the output FCDC header
    numsmp = cell2mat({orig.varheader.numsmp});
    adindx = find(cell2mat({orig.varheader.typ})==5);
    if isempty(adindx)
      error('file does not contain continuous channels');
    end
    hdr.nChans      = length(orig.varheader);
    hdr.Fs          = orig.varheader(adindx(1)).wfrequency;     % take the sampling frequency from the first A/D channel
    hdr.nSamples    = max(numsmp(adindx));                      % take the number of samples from the longest A/D channel
    hdr.nTrials     = 1;                                        % it can always be interpreted as continuous data
    hdr.nSamplesPre = 0;                                        % and therefore it is not trial based
    for i=1:hdr.nChans
      hdr.label{i} = deblank(char(orig.varheader(i).nam));
    end
    hdr.label = hdr.label(:);
    % also remember the original header details
    hdr.orig = orig;
    
  case {'read_plexon_nex' 'plexon_nex'} % this is the default reader for nex files
    orig = read_plexon_nex(filename);
    numsmp = cell2mat({orig.VarHeader.NPointsWave});
    adindx = find(cell2mat({orig.VarHeader.Type})==5);
    if isempty(adindx)
      error('file does not contain continuous channels');
    end
    hdr.nChans      = length(orig.VarHeader);
    hdr.Fs          = orig.VarHeader(adindx(1)).WFrequency;     % take the sampling frequency from the first A/D channel
    hdr.nSamples    = max(numsmp(adindx));                      % take the number of samples from the longest A/D channel
    hdr.nTrials     = 1;                                        % it can always be interpreted as continuous data
    hdr.nSamplesPre = 0;                                        % and therefore it is not trial based
    for i=1:hdr.nChans
      hdr.label{i} = deblank(char(orig.VarHeader(i).Name));
    end
    hdr.label = hdr.label(:);
    hdr.FirstTimeStamp     = orig.FileHeader.Beg;
    hdr.TimeStampPerSample = orig.FileHeader.Frequency ./ hdr.Fs;
    % also remember the original header details
    hdr.orig = orig;
    
  case {'plexon_plx', 'plexon_plx_v2'}
    ft_hastoolbox('PLEXON', 1);
    
    orig = plx_orig_header(filename);
    
    if orig.NumSlowChannels==0
      error('file does not contain continuous channels');
	end
    for i=1:length(orig.SlowChannelHeader)
      label{i} = deblank(orig.SlowChannelHeader(i).Name);
    end
    % continuous channels don't always contain data, remove the empty ones
    [~, scounts] = plx_adchan_samplecounts(filename);
    chansel = scounts > 0;
    chansel = find(chansel); % this is required for timestamp selection
	fsample = [orig.SlowChannelHeader.ADFreq];
	fsample = fsample(chansel); %select non-empty channels only
	if any(fsample~=fsample(1))
      warning('different sampling rates in continuous data not supported, please select channels carefully');
    end
    label = label(chansel);
    % only the continuous channels are returned as visible
    hdr.nChans      = length(label);
	hdr.eventFs		= orig.ADFrequency;
    hdr.Fs          = min(fsample);
    hdr.label       = label;
    % also remember the original header
    hdr.orig        = orig;
	hdr.fsample = fsample;
    
    hdr.nSamples = max(scounts);
    hdr.nSamplesPre = 0;      % continuous
    hdr.nTrials     = 1;      % continuous
    hdr.TimeStampPerSample = double(orig.ADFrequency) / hdr.Fs;
    
    % also make the spike channels visible
    for i=1:length(orig.ChannelHeader)
      hdr.label{end+1} = deblank(orig.ChannelHeader(i).Name);
    end
    hdr.label = hdr.label(:);
    hdr.nChans = length(hdr.label);

  otherwise
    if strcmp(fallback, 'biosig') && ft_hastoolbox('BIOSIG', 1)
      hdr = read_biosig_header(filename);
    else
      error('unsupported header format (%s)', headerformat);
    end
end % switch headerformat


% Sometimes, the not all labels are correctly filled in by low-level reading
% functions. See for example bug #1572.
% First, make sure that there are enough (potentially empty) labels:
if numel(hdr.label) < hdr.nChans
  warning('low-level reading function did not supply enough channel labels');
  hdr.label{hdr.nChans} = [];
end

% Now, replace all empty labels with new name:
if any(cellfun(@isempty, hdr.label))
  warning('channel labels should not be empty, creating unique labels');
  hdr.label = fix_empty(hdr.label);
end

if checkUniqueLabels
  if length(hdr.label)~=length(unique(hdr.label))
    % all channels must have unique names
    warning('all channels must have unique labels, creating unique labels');
    for i=1:hdr.nChans
      sel = find(strcmp(hdr.label{i}, hdr.label));
      if length(sel)>1
        for j=1:length(sel)
          hdr.label{sel(j)} = sprintf('%s-%d', hdr.label{sel(j)}, j);
        end
      end
    end
  end
end

% ensure that it is a column array
hdr.label = hdr.label(:);

% as of November 2011, the header is supposed to include the channel type (see FT_CHANTYPE,
% e.g. meggrad, megref, eeg) and the units of each channel (see FT_CHANUNIT, e.g. uV, fT)

if ~isfield(hdr, 'chantype')
  % use a helper function which has some built in intelligence
  hdr.chantype = ft_chantype(hdr);
end % for

if ~isfield(hdr, 'chanunit')
  % use a helper function which has some built in intelligence
  hdr.chanunit = ft_chanunit(hdr);
end % for

% ensure that the output grad is according to the latest definition
if isfield(hdr, 'grad')
  hdr.grad = ft_datatype_sens(hdr.grad);
end

% ensure that the output elec is according to the latest definition
if isfield(hdr, 'elec')
  hdr.elec = ft_datatype_sens(hdr.elec);
end

% ensure that these are double precision and not integers, otherwise
% subsequent computations that depend on these might be messed up
hdr.Fs          = double(hdr.Fs);
hdr.nSamples    = double(hdr.nSamples);
hdr.nSamplesPre = double(hdr.nSamplesPre);
hdr.nTrials     = double(hdr.nTrials);
hdr.nChans      = double(hdr.nChans);

if cache && exist(headerfile, 'file')
  % put the header in the cache
  cacheheader = hdr;
  % update the header details (including time stampp, size and name)
  cacheheader.details = dir(headerfile);
  % fprintf('added header to cache\n');
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% SUBFUNCTION to determine the file size in bytes
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [siz] = filesize(filename)
l = dir(filename);
if l.isdir
  error('"%s" is not a file', filename);
end
siz = l.bytes;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% SUBFUNCTION to determine the file size in bytes
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [hdr] = recursive_read_header(filename)
[p, f, x] = fileparts(filename);
ls = dir(filename);
ls = ls(~strcmp({ls.name}, '.'));  % exclude this directory
ls = ls(~strcmp({ls.name}, '..')); % exclude parent directory
for i=1:length(ls)
  % make sure that the directory listing includes the complete path
  ls(i).name = fullfile(filename, ls(i).name);
end
lst = {ls.name};
hdr = cell(size(lst));
sel = zeros(size(lst));
for i=1:length(lst)
  % read the header of each individual file
  try
    thishdr = ft_read_header(lst{i});
    if isstruct(thishdr)
      thishdr.filename = lst{i};
    end
  catch
    thishdr = [];
    warning(lasterr);
    fprintf('while reading %s\n\n', lst{i});
  end
  if ~isempty(thishdr)
    hdr{i} = thishdr;
    sel(i) = true;
  else
    sel(i) = false;
  end
end
sel = logical(sel(:));
hdr = hdr(sel);
tmp = {};
for i=1:length(hdr)
  if isstruct(hdr{i})
    tmp = cat(1, tmp, hdr(i));
  elseif iscell(hdr{i})
    tmp = cat(1, tmp, hdr{i}{:});
  end
end
hdr = tmp;


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% SUBFUNCTION to fill in empty labels
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function labels = fix_empty(labels)
for i = find(cellfun(@isempty, {labels{:}}));
  labels{i} = sprintf('%d', i);
end

function filename = fetch_url(filename)

% FETCH_URL checks the filename and downloads the file to a local copy in
% case it is specified as an Universal Resource Locator. It returns the
% name of the temporary file on the local filesystem.
%
% Use as
%   filename = fetch_url(filename)
%
% In case the filename does not specify an URL, it just returns the original
% filename.

% Copyright (C) 2012 Robert Oostenveld
%
% This file is part of FieldTrip, see http://www.ru.nl/neuroimaging/fieldtrip
% for the documentation and details.
%
%    FieldTrip is free software: you can redistribute it and/or modify
%    it under the terms of the GNU General Public License as published by
%    the Free Software Foundation, either version 3 of the License, or
%    (at your option) any later version.
%
%    FieldTrip is distributed in the hope that it will be useful,
%    but WITHOUT ANY WARRANTY; without even the implied warranty of
%    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%    GNU General Public License for more details.
%
%    You should have received a copy of the GNU General Public License
%    along with FieldTrip. If not, see <http://www.gnu.org/licenses/>.
%
% $Id: fetch_url.m 7123 2012-12-06 21:21:38Z roboos $

if filetype_check_uri(filename, 'sftp')
  [user, host, filename] = filetype_check_uri(filename);
  [p, f, x] = fileparts(filename);
  p = tempdir;
  try
    mkdir(p);
    cmd = sprintf('sftp %s@%s:%s %s', user, host, filename, fullfile(p, [f x]));
    system(cmd);
    filename = fullfile(p, [f x]);
  end
  % elseif filetype_check_uri(filename, 'http')
  % FIXME the http scheme should be supported using default MATLAB
  % elseif filetype_check_uri(filename, 'ftp')
  % FIXME the http scheme should be supported using default MATLAB
  % elseif filetype_check_uri(filename, 'smb')
  % FIXME the smb scheme can be supported using smbclient
end


function [filename, headerfile, datafile] = dataset2files(filename, format)

% DATASET2FILES manages the filenames for the dataset, headerfile, datafile and eventfile
% and tries to maintain a consistent mapping between them for each of the known fileformats
%
% Use as
%   [filename, headerfile, datafile] = dataset2files(filename, format)

% Copyright (C) 2007-2013, Robert Oostenveld
%
% This file is part of FieldTrip, see http://www.ru.nl/neuroimaging/fieldtrip
% for the documentation and details.
%
%    FieldTrip is free software: you can redistribute it and/or modify
%    it under the terms of the GNU General Public License as published by
%    the Free Software Foundation, either version 3 of the License, or
%    (at your option) any later version.
%
%    FieldTrip is distributed in the hope that it will be useful,
%    but WITHOUT ANY WARRANTY; without even the implied warranty of
%    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%    GNU General Public License for more details.
%
%    You should have received a copy of the GNU General Public License
%    along with FieldTrip. If not, see <http://www.gnu.org/licenses/>.
%
% $Id: dataset2files.m 8365 2013-08-01 10:21:40Z roboos $

persistent previous_argin previous_argout

current_argin = {filename, format};
if isequal(current_argin, previous_argin)
  % don't do the whole cheking again, but return the previous output from cache
  filename   = previous_argout{1};
  headerfile = previous_argout{2};
  datafile   = previous_argout{3};
  return
end

if isempty(format)
  format = ft_filetype(filename);
end

switch format
  case '4d_pdf'
    datafile   = filename;
    headerfile = [datafile '.m4d'];
    sensorfile = [datafile '.xyz'];
  case {'4d_m4d', '4d_xyz'}
    datafile   = filename(1:(end-4)); % remove the extension
    headerfile = [datafile '.m4d'];
    sensorfile = [datafile '.xyz'];
  case '4d'
    [path, file, ext] = fileparts(filename);
    datafile   = fullfile(path, [file,ext]);
    headerfile = fullfile(path, [file,ext]);
    configfile = fullfile(path, 'config');
  case {'ctf_ds', 'ctf_old'}
    % convert CTF filename into filenames
    [path, file, ext] = fileparts(filename);
    if any(strcmp(ext, {'.res4' '.meg4', '.1_meg4' '.2_meg4' '.3_meg4' '.4_meg4' '.5_meg4' '.6_meg4' '.7_meg4' '.8_meg4' '.9_meg4'}))
      filename = path;
      [path, file, ext] = fileparts(filename);
    end
    if isempty(path) && isempty(file)
      % this means that the dataset was specified as the present working directory, i.e. only with '.'
      filename = pwd;
      [path, file, ext] = fileparts(filename);
    end
    headerfile = fullfile(filename, [file '.res4']);
    datafile   = fullfile(filename, [file '.meg4']);
    if length(path)>3 && strcmp(path(end-2:end), '.ds')
      filename = path; % this is the *.ds directory
    end
  case {'ctf_meg4' 'ctf_res4' 'ctf_read_meg4' 'ctf_read_res4' 'read_ctf_meg4' 'read_ctf_res4'}
    [path, file, ext] = fileparts(filename);
    if strcmp(ext, '.ds')
      % the directory name was specified instead of the meg4/res4 file
      path = filename;
    end
    if isempty(path)
      path = pwd;
    end
    headerfile = fullfile(path, [file '.res4']);
    datafile   = fullfile(path, [file '.meg4']);
    if length(path)>3 && strcmp(path(end-2:end), '.ds')
      filename = path; % this is the *.ds directory
    end
  case 'brainvision_vhdr'
    [path, file, ext] = fileparts(filename);
    headerfile = fullfile(path, [file '.vhdr']);
    if exist(fullfile(path, [file '.eeg']))
      datafile   = fullfile(path, [file '.eeg']);
    elseif exist(fullfile(path, [file '.seg']))
      datafile   = fullfile(path, [file '.seg']);
    elseif exist(fullfile(path, [file '.dat']))
      datafile   = fullfile(path, [file '.dat']);
    end
  case 'brainvision_eeg'
    [path, file, ext] = fileparts(filename);
    headerfile = fullfile(path, [file '.vhdr']);
    datafile   = fullfile(path, [file '.eeg']);
  case 'brainvision_seg'
    [path, file, ext] = fileparts(filename);
    headerfile = fullfile(path, [file '.vhdr']);
    datafile   = fullfile(path, [file '.seg']);
  case 'brainvision_dat'
    [path, file, ext] = fileparts(filename);
    headerfile = fullfile(path, [file '.vhdr']);
    datafile   = fullfile(path, [file '.dat']);
  case 'itab_raw'
    [path, file, ext] = fileparts(filename);
    headerfile = fullfile(path, [file '.raw.mhd']);
    datafile   = fullfile(path, [file '.raw']);
  case 'fcdc_matbin'
    [path, file, ext] = fileparts(filename);
    headerfile = fullfile(path, [file '.mat']);
    datafile   = fullfile(path, [file '.bin']);
  case 'fcdc_buffer_offline'
    [path, file, ext] = fileparts(filename);
    headerfile = fullfile(path, 'header');
    datafile   = fullfile(path, 'samples');
  case {'tdt_tsq' 'tdt_tev'}
    [path, file, ext] = fileparts(filename);
    headerfile = fullfile(path, [file '.tsq']);
    datafile   = fullfile(path, [file '.tev']);
  case 'egi_mff'
    if ~isdir(filename);
      [path, file, ext] = fileparts(filename);
      headerfile = path;
      datafile   = path;
    else
      headerfile = filename;
      datafile   = filename;
    end
  case {'deymed_dat' 'deymed_ini'}
    [p, f, x] = fileparts(filename);
    headerfile = fullfile(p, [f '.ini']);
    if ~exist(headerfile, 'file')
      headerfile = fullfile(p, [f '.Ini']);
    end
    datafile = fullfile(p, [f '.dat']);
    if ~exist(datafile, 'file')
      datafile = fullfile(p, [f '.Dat']);
    end
  case 'neurosim_ds'
    % this is the directory
    filename = fullfile(filename, 'signals'); % this is the only one we care about for the continuous signals
    headerfile = filename;
    datafile   = filename;
  otherwise
    % convert filename into filenames, assume that the header and data are the same
    datafile   = filename;
    headerfile = filename;
end

% remember the current input and output arguments, so that they can be
% reused on a subsequent call in case the same input argument is given
current_argout = {filename, headerfile, datafile};
previous_argin  = current_argin;
previous_argout = current_argout;

function [ orig ] = plx_orig_header( fname )
% PLX_ORIG_HEADER Extracts the header informations of plx files using the
% Plexon Offline SDK, which is available from
% http://www.plexon.com/assets/downloads/sdk/ReadingPLXandDDTfilesinMatlab-mexw.zip
%
% Use as
%   [orig] = plx_orig_header(filename)
%
% Copyright (C) 2012 by Thomas Hartmann
%
% This code can be redistributed under the terms of the GPL version 3 or
% newer.

% get counts...
[tscounts, wfcounts, evcounts, contcounts] = plx_info(fname, 0);

orig.TSCounts = tscounts;
orig.WFCounts = wfcounts;

% get event channels...
[dummy, evchans] = plx_event_chanmap(fname);

orig.EVCounts = zeros(512, 1);

for i=1:length(evchans)
  try
    orig.EVCounts(evchans(i)+1) = evcounts(i);
  catch
  end
end %for

% get more infos...
[OpenedFileName, Version, Freq, Comment, Trodalness, NPW, PreTresh, SpikePeakV, SpikeADResBits, SlowPeakV, SlowADResBits, Duration, DateTime] = plx_information(fname);
orig.MagicNumber = 1480936528;
orig.Version = Version;
orig.ADFrequency = Freq;
orig.Comment = Comment;
orig.NumEventChannels = length(evchans);
orig.NumSlowChannels = length(contcounts);
[orig.NumDSPChannels, dummy] = plx_chanmap(fname);
orig.NumPointsWave = NPW;
orig.NumPointsPreThr = PreTresh;
[orig.Year orig.Month orig.Day orig.Hour orig.Minute orig.Second] = datevec(DateTime);
orig.LastTimestamp = Duration * Freq;
orig.Trodalness = Trodalness;
orig.DataTrodalness = Trodalness;
orig.BitsPerSpikeSample = SpikeADResBits;
orig.BitsPerSlowSample = SlowADResBits;
orig.SpikeMaxMagnitudeMV = SpikePeakV;
orig.SlowMaxMagnitudeMV = SlowPeakV;

% gather further info for additional headers...
[dummy, chan_names] = plx_chan_names(fname);
[dummy, dspchans] = plx_chanmap(fname);
[dummy, gains] = plx_chan_gains(fname);
[dummy, filters] = plx_chan_filters(fname);
[dummy, thresholds] = plx_chan_thresholds(fname);
[dummy, evnames] = plx_event_names(fname);
[dummy, ad_names] = plx_adchan_names(fname);
[dummy, adchans] = plx_ad_chanmap(fname);
[dummy, ad_freqs] = plx_adchan_freqs(fname);
[dummy, ad_gains] = plx_adchan_gains(fname);

% do channelheaders...
for i=1:orig.NumDSPChannels
  head = [];
  head.Name = ['mua_' chan_names(i, :)];
  head.SIGName = ['mua_' chan_names(i, :)];
  head.Channel = dspchans(i);
  head.SIG = i;
  head.Gain = gains(i);
  head.Filter = filters(i);
  head.Threshold = thresholds(i);
  
  orig.ChannelHeader(i) = head;
end %for

% do eventheaders...
for i=1:orig.NumEventChannels
  head = [];
  head.Name = evnames(i, :);
  head.Channel = evchans(i);
  
  orig.EventHeader(i) = head;
end %for

% do slowchannelheaders...
for i=1:orig.NumSlowChannels
  head = [];
  head.Name = ['lfp_' ad_names(i, :)];
  head.Channel = adchans(i);
  head.ADFreq = ad_freqs(i);
  head.Gain = ad_gains(i);
  
  orig.SlowChannelHeader(i) = head;
end %for