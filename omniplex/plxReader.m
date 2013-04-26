classdef plxReader < optickaCore
	%TIMELOG Simple class used to store the timing data from an experiment
	%   timeLogger stores timing data for a taskrun and optionally graphs the
	%   result.
	
	properties
		verbose	= true
	end
	
	properties (SetAccess = private, GetAccess = public)
		info@cell
		file@char
		dir@char
		eventList@struct
		tsList@struct
		strobeList@struct
	end
	
	properties (SetAccess = private, GetAccess = private)
		oldDir@char
		%> allowed properties passed to object upon construction
		allowedProperties@char = 'verbose'
	end
	
	%=======================================================================
	methods %------------------PUBLIC METHODS
	%=======================================================================

		% ===================================================================
		%> @brief Constructor
		%>
		%> @param varargin
		%> @return
		% ===================================================================
		function obj=plxReader(varargin)
			if nargin == 0; varargin.name = 'plxReader';end
			if nargin>0; obj.parseArgs(varargin,obj.allowedProperties); end
			if isempty(obj.name);obj.name = 'plxReader'; end
			[obj.file, obj.dir] = uigetfile('*.plx');
		end
		
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function sd = parseToSD(obj)
			obj.oldDir = pwd;
			cd(obj.dir);
			generateInfo(obj)
			getStrobes(obj);
			disp(obj.info)
			sd = obj.strobeList;
			cd(obj.oldDir);
		end

	end %---END PUBLIC METHODS---%
	
	%=======================================================================
	methods ( Access = private ) %-------PRIVATE METHODS-----%
	%=======================================================================
		
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function getStrobes(obj)
			tic
			[a,b,c] = plx_event_ts(obj.file,257);
			[a19,b19] = plx_event_ts(obj.file,19);
			[a20,b20] = plx_event_ts(obj.file,20);
			[a21,b21] = plx_event_ts(obj.file,21);
			[a22,b22] = plx_event_ts(obj.file,22);
			[d,e] = plx_event_names(obj.file);
			[f,g] = plx_event_chanmap(obj.file);
			if a > 0
				obj.strobeList = struct();
				obj.strobeList(1).n = a;
				obj.strobeList.startFix = b19;
				obj.strobeList.correct = b20;
				obj.strobeList.breakFix = b21;
				obj.strobeList.incorrect = b22;
				obj.strobeList.times = b;
				obj.strobeList.values = c;
				obj.strobeList.unique = unique(c);
				obj.strobeList.nVars = length(obj.strobeList.unique)-1;
				for i = 1:obj.strobeList.nVars
					obj.strobeList.vars(i).name = obj.strobeList.unique(i);
					idx = find(obj.strobeList.values == obj.strobeList.unique(i));
					idxend = idx+1;
					while (length(idx) > length(idxend)) %prune incomplete trials
						idx = idx(1:end-1);
					end
					obj.strobeList.vars(i).nRepeats = length(idx);
					obj.strobeList.vars(i).index = idx;
					obj.strobeList.vars(i).t1 = obj.strobeList.times(idx);
					obj.strobeList.vars(i).t2 = obj.strobeList.times(idxend);
					obj.strobeList.vars(i).tDelta = obj.strobeList.vars(i).t2 - obj.strobeList.vars(i).t1;
					obj.strobeList.vars(i).tMax = max(obj.strobeList.vars(i).tDelta);
					
					for nr = 1:obj.strobeList.vars(i).nRepeats
						if 
					end
					
				end
			else
				obj.strobeList = struct();
			end
			fprintf('Loading all events took %s seconds\n',toc)
		end
		
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function generateInfo(obj)
			[OpenedFileName, Version, Freq, Comment, Trodalness,...
				NPW, PreThresh, SpikePeakV, SpikeADResBits,...
				SlowPeakV, SlowADResBits, Duration, DateTime] = plx_information(obj.file);
			obj.info = {};
			obj.info{1} = sprintf(['Opened File Name: ' OpenedFileName]);
			obj.info{end+1} = sprintf(['Version: ' num2str(Version)]);
			obj.info{end+1} = sprintf(['Frequency : ' num2str(Freq)]);
			obj.info{end+1} = sprintf(['Comment : ' Comment]);
			obj.info{end+1} = sprintf(['Date/Time : ' DateTime]);
			obj.info{end+1} = sprintf(['Duration : ' num2str(Duration)]);
			obj.info{end+1} = sprintf(['Num Pts Per Wave : ' num2str(NPW)]);
			obj.info{end+1} = sprintf(['Num Pts Pre-Threshold : ' num2str(PreThresh)]);
			% some of the information is only filled if the plx file version is >102
			if ( Version > 102 )
				if ( Trodalness < 2 )
					obj.info{end+1} = sprintf('Data type : Single Electrode');
				elseif ( Trodalness == 2 )
					obj.info{end+1} = sprintf('Data type : Stereotrode');
				elseif ( Trodalness == 4 )
					obj.info{end+1} = sprintf('Data type : Tetrode');
				else
					obj.info{end+1} = sprintf('Data type : Unknown');
				end

				obj.info{end+1} = sprintf(['Spike Peak Voltage (mV) : ' num2str(SpikePeakV)]);
				obj.info{end+1} = sprintf(['Spike A/D Resolution (bits) : ' num2str(SpikeADResBits)]);
				obj.info{end+1} = sprintf(['Slow A/D Peak Voltage (mV) : ' num2str(SlowPeakV)]);
				obj.info{end+1} = sprintf(['Slow A/D Resolution (bits) : ' num2str(SlowADResBits)]);
			end
			obj.info = obj.info';

			% get some counts
			[tscounts, wfcounts, evcounts, slowcounts] = plx_info(obj.file,1);
			[nunits1, nchannels1] = size( tscounts );
			obj.tsList = struct();
			obj.tsList(1).chMap = find(sum(tscounts) > 0);
			obj.tsList(1).chMap = obj.tsList(1).chMap - 1; %fix the index as plx_info add 1 to channels
			obj.tsList.unitMap = find(sum(tscounts,2) > 0);
			obj.tsList(1).unitMap = obj.tsList(1).unitMap' - 1; %fix the index as plx_info add 1 to channels
			obj.tsList.nCh = length(obj.tsList.chMap);
			obj.tsList.nUnit = length(obj.tsList.unitMap);
			obj.info{end+1} = ['Number of Active channels : ' num2str(obj.tsList.nCh)];
			obj.info{end+1} = ['Number of Active units : ' num2str(obj.tsList.nUnit)];
			obj.info{end+1} = ['Channel list : ' num2str(obj.tsList.chMap)];
			obj.info{end+1} = ['Unit list (0=unsorted) : ' num2str(obj.tsList.unitMap)];
			obj.tsList.ts = cell(obj.tsList.nUnit, obj.tsList.nCh); obj.tsList.tsN = obj.tsList.ts;
			
			tic
			for ich = 1:obj.tsList.nCh
				for iunit = 1:obj.tsList.nUnit
					[obj.tsList.tsN{iunit,ich}, obj.tsList.ts{iunit,ich}] = plx_ts(obj.file, obj.tsList.chMap(ich) , obj.tsList.unitMap(iunit) );
				end
			end
			fprintf('Loading all spikes took %s seconds\n',toc)

		end
		
	end
	
end

