% 
% EDFMEX uses the Eyelink EDF access API to read eyelink data
% files into a matlab structure.
%
% Usage:
% 
%     edfdata = edfmex(filename,[start_at_record_number],[end_at_record_number],
%                               [load_sample_flag], [load_event_flag],[consistency_check_flag]);
% 
% Input:
% 
%     filename                -   name of the file to be loaded.
%     
%     start_at_record_number  -   load data starting at this record number 
%                                    (default is 0 indicating the first record ).
%     
%     end_at_record_number    -   load up to this record number. Default is
%                                  0 indicating read to end of file.
% 
%     load_sample_flag       -    0 to skip samples. Default = 1. 
%                                 Or an array specifying which sample fields 
%                                 to load in the order of fieldnames(e.FSAMPLE), 
%                                 upto the last field that should be loaded, 
%                                 i.e. [1 0 0 0 0 0 1 1] would only load time, 
%                                 gx and gy. 
%                                 Or a cell array of string containing the 
%                                 sample fields to load, e.g. {'time', 'gx',
%                                 'gy'}
% 
%     load_events_flag       -    0 to skip events. Default = 1.
% 
%     consistency_check_flag -    Performs file consistency check as
%                                 described in the API documentation:
%                                 see edf_open_file(). Default = 1.
%                                 
% 
% edfdata:  A matlab structure with the following fields:
%     
%   edfdata.FSAMPLE     - a matlab stucture with fields corresponding to the 
%                         FSAMPLE structure as described in the Eyelink EDF 
%                         access API documentation. Each field is an M x Nsamp 
%                         array, where Nsamp is the number of samples.
%                         
% 	edfdata.FEVENT      - a 1 x Nevent structure array, where Nevent is 
%                         the number of events. Fields correspond to the 
%                         fields of the FEVENT structure as described in 
%                         the API documentation.
%                         
% 	edfdata.IOEVENT     -  as above for the IOEVENT structure.
%     
% 	edfdata.RECORDINGS  - as above for the RECORDINGS structure.
%                         
% 	edfdata.HEADER      - Header information.
%                         
% 	edfdata.FILENAME    - Name of the file from which data are loaded.
% 
%   To recompile from the source code under 32 bit Windows, make sure the
%   source directory contains edfapi.dll and edfapi.lib, as well as 
%   the headers edf.h edf_data.h and edftypes.h which can be obtained 
%   from the Eyelink support website. Be sure that these are for the same
%   versions of the API as the edfapi.dll. Run the matlab script MAKEHEADER before 
%   compiling, which will generate an additional header file, edf2mex.h. 
%
%   I compiled successfully in matlab using microsoft visual C++ compiler 
%   with the command:
%
%        mex edfmex.cpp edfapi.lib
% 
%   Copyright (C) 2009  Christopher K. Kovach, 2015 Christopher K. Kovach & Jonas Knöll
% 
%   This program is free software: you can redistribute it and/or modify
%   it under the terms of the GNU Affero General Public License as published by
%   the Free Software Foundation, either version 3 of the License, or
%   (at your option) any later version.
% 
%   This program is distributed in the hope that it will be useful,
%   but WITHOUT ANY WARRANTY; without even the implied warranty of
%   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%   GNU Affero General Public License for more details.
% 
%   You should have received a copy of the GNU Affero General Public License
%   along with this program.  If not, see <http://www.gnu.org/licenses/>. 
%
% Questions can be sent to christopher-kovach@uiowa.edu or Jonas Knöll (jonas.knoell@utexas.edu) 