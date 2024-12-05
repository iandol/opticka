% ========================================================================
classdef optickaCore < handle
%> @class optickaCore
%> @brief optickaCore base class inherited by other opticka classes.
%>
%> @section intro Introduction
%>
%> optickaCore is itself derived from handle. It provides methods to find
%> attributes with specific parameters (used in autogenerating UI panels),
%> clone the object, parse arguments safely on construction and add default
%> properties such as paths, dateStamp, uuid and name/comment management.
%>
%> Copyright ©2014-2024 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ========================================================================

	%--------------------PUBLIC PROPERTIES----------%
	properties
		%> object name
		name char = ''
		%> comment
		comment string = ""
	end

	%--------------------ABSTRACT PROPERTIES----------%
	properties (Abstract = true)
		%> verbose logging, subclasses must assign this. This is normally logical true/false
		verbose
	end

	%--------------------HIDDEN PROPERTIES------------%
	properties (SetAccess = protected, Hidden = true)
		%> are we cloning this from another object
		cloning logical = false
	end

	%--------------------VISIBLE PROPERTIES-----------%
	properties (SetAccess = protected, GetAccess = public)
		%> clock() dateStamp set on construction
		dateStamp = []
		%> universal ID
		uuid char
		%> storage of various paths
		paths struct
		%> version number
		optickaVersion char		= '2.16.3'
	end

	%--------------------DEPENDENT PROPERTIES----------%
	properties (Dependent = true)
		%> The fullName is the object name combined with its uuid and class name
		fullName char
	end

	%--------------------TRANSIENT PROPERTIES----------%
	properties (Access = protected, Transient = true)
		%> Matlab version number, this is transient so it is not saved
		mversion double = 0
		%> sans font
		sansFont		= 'Ubuntu'
		%> monoFont
		monoFont		= 'Ubunto Mono'
	end

	%--------------------PROTECTED PROPERTIES----------%
	properties (Access = protected)
		%> class name
		className char = ''
		%> save prefix generated from clock time
		savePrefix = ''
		%> cached full name
		fullName_ = ''
	end

	%--------------------PRIVATE PROPERTIES----------%
	properties (Access = private)
		%> allowed properties passed to object upon construction
		allowedPropertiesCore = {'name','comment','cloning'}
	end

	%=======================================================================
	methods %------------------PUBLIC METHODS
	%=======================================================================

		% ===================================================================
		function me = optickaCore(varargin)
		%> @fn optickaCore
		%> @brief Class constructor
		%>
		%> The class constructor for optickaCore.
		%>
		%> @param args are passed as name-value pairs or a structure of properties
		%> which is parsed.
		%>
		%> @return instance of class.
		% ===================================================================
			args = me.addDefaults(varargin);
			me.parseArgs(args, me.allowedPropertiesCore);
			me.dateStamp = datetime('now');
			me.className = class(me);
			me.uuid = num2str(dec2hex(floor((now - floor(now))*1e10))); %me.uuid = char(java.util.UUID.randomUUID)%128bit uuid
			me.fullName; %cache fullName
			me.mversion = str2double(regexp(version,'(?<ver>^\d\.\d[\d]?)','match','once'));
			setPaths(me);
			getFonts(me);
		end
		
		% ===================================================================
		function name = get.fullName(me)
		%> @fn get.fullName
		%> @brief concatenate the name with a uuid at get.
		%> @param
		%> @return name the concatenated name
		% ===================================================================
			if isempty(me.name)
				me.fullName_ = sprintf('%s#%s', me.className, me.uuid);
			else
				me.fullName_ = sprintf('%s<%s#%s>', me.name, me.className, me.uuid);
			end
			name = me.fullName_;
		end

		% ===================================================================
		function [path, sessionID, dateID] = getALF(me, subject, sessionPrefix, lab, create)
		%> @fn initialiseSaveFile(me)
		%> @brief Initialise Save prefix
		%>
		%> @return path - the path to use
		%> @return dateid - YYYY-MM-DD-HH-MM-SS
		% ===================================================================
			if ~exist('subject','var') || isempty(subject); subject = 'unknown'; end
			if ~exist('sessionPrefix','var') || isempty(sessionPrefix); sessionPrefix = ''; end
			if ~exist('lab','var') || isempty(lab); lab = []; end
			if ~exist('create','var') || isempty(create); create = false; end
			
			dateID = fix(clock); %#ok<*CLOCK> compatible with octave
			dateID = num2str(dateID(1:6));
			dateID = regexprep(dateID,' +','-');
			
			d = char(datetime("today"));
			if isempty(lab)
				path = [me.paths.savedData filesep subject filesep d];
			else
				path = [me.paths.savedData filesep lab filesep 'subjects' filesep subject filesep d];
			end
			if ~exist(path,'dir')
				sessionID = [sessionPrefix '001'];
				path = [path filesep sessionID filesep];
				s = mkdir(path);
				if s == 0; error('Cannot make Save File directory!!!'); end
				fprintf('---> Path: %s created...\n',path);
				return
			else
				isMatch = false;
				n = 0;
				d = dir(path);
				pattern = sessionPrefix + digitsPattern(3);
				for jj = 1:length(d)
					e = extract(d(jj).name, pattern);
					if ~isempty(e)
						isMatch = true;
						nn = str2double(e{1}(end-2:end));
						if nn > n; n = nn; end
					end
				end
				if isMatch
					if create
						sessionID = [sessionPrefix sprintf('%0.3d',n+1)];
						path = [path filesep sessionID filesep];
						s = mkdir(path);
						if s == 0; error('Cannot make Save File directory!!!'); end
						fprintf('---> Path: %s created...\n',path);
						return
					else
						sessionID = [sessionPrefix sprintf('%0.3d',n)];
						path = [path filesep sessionID filesep];
						fprintf('---> Path: %s found...\n',path);
						return
					end
				else
					sessionID = [sessionPrefix '001'];
					path = [path filesep sessionID filesep];
					s = mkdir(path);
					if s == 0; error('Cannot make Save File directory!!!'); end
					fprintf('---> Path: %s created...\n',path);
				end
			end
			me.paths.ALFPath = path;
		end

		% ===================================================================
		function makeReport(me, rpt)
			try
				import mlreportgen.report.* %#ok<*SIMPT>
				import mlreportgen.dom.* 
			catch
				warning('Report Generator Toolbox not installed...');
			end

			if ~exist('rpt','var') || isempty(rpt) 
				fullReport = true; 
			else
				fullReport = false; 
			end

			tt = tic;
			
			if fullReport
				name = me.name;
				name = regexprep(name,'\s*','-');
				rpt = Report([me.paths.parent filesep name '--' me.uuid],'PDF');
	
				tp = TitlePage; 
				tp.Title = 'Opticka Object Report'; 
				tp.Subtitle = sprintf('Name: %s',me.fullName); 
				tp.Publisher = 'Opticka';
				tp.Image = [me.paths.root filesep 'ui' filesep 'images' filesep 'opticka-small.png'];
				tp.Author = me.comment; 
				append(rpt,tp); 
				append(rpt,TableOfContents);
				fprintf('=== makeReport: initialise @%.2f secs\n',toc(tt));
			end

			parnote = {Color('#8b008b'),Bold(true),FontSize('14pt')};

			switch class(me)

				case 'opticka'
					fprintf('=== makeReport: opticka @%.2f secs\n',toc(tt));
					ch = Chapter('opticka Object'); 
					sec = Section('General Information'); 
					append(sec,Paragraph('opticka Object:'))
					append(sec, MATLABVariable('Variable', me, 'MaxCols', 2, 'DepthLimit', 0, 'ObjectLimit', 1));
					append(ch,sec);
					append(rpt,ch);
					me.r.makeReport(rpt);

				case 'runExperiment'
					fprintf('=== makeReport: runExperiment @%.2f secs\n',toc(tt));
					ch = Chapter('runExperiment Object'); 
					sec = Section('General Information'); 
					append(sec,Paragraph('runExperiment is the main object that manages a task. It contains multiple other managers: screenManager, taskSequence, stateMachine, eyeTracker'))
					append(sec,Paragraph('runExperiment Object:'))
					append(sec, MATLABVariable('Variable', me, 'MaxCols', 2, 'DepthLimit', 0, 'ObjectLimit', 1));
					append(ch,sec);
					append(rpt,ch);
					if isa(me.task,'taskSequence') && ~isempty(me.task)
						me.task.makeReport(rpt);
					end
					if isa(me.behaviouralRecord,'behaviouralRecord') && ~isempty(me.behaviouralRecord)
						me.behaviouralRecord.makeReport(rpt);
					end
					if isa(me.stateMachine,'stateMachine') && ~isempty(me.stateMachine)
						me.stateMachine.makeReport(rpt);
					end

				case 'taskSequence'
					fprintf('=== makeReport: taskSequence @%.2f secs\n',toc(tt));
					ch = Chapter('taskSequence Object'); 
					sec = Section('Details'); 
					append(sec,Paragraph('The taskSequence manages variable randomisation, you pass it a list of variables and their values and the number of repeat blocks and it will generate a balanced table. There is also an indepedent blockVar and trialVar.'))
					append(sec,Paragraph(' There is also an indepedent blockVar and trialVar.'))
					append(sec,Paragraph('taskSequence Object:'))
					append(sec, MATLABVariable('Variable', me, 'MaxCols', 2, 'DepthLimit', 0, 'ObjectLimit', 1));
					append(ch,sec);
					append(rpt,ch);

				case 'stateMachine'
					fprintf('=== makeReport: stateMachine @%.2f secs\n',toc(tt));
					ch = Chapter('stateMachine Object'); 
					sec = Section('Details'); 
					i = me.stateList;
					append(sec, MATLABVariable('Title','stateList','Variable', i, 'MaxCols', 2, 'DepthLimit', 0, 'ObjectLimit', 1));
					t = me.showTable();
					append(sec, MATLABVariable('Title','State Table','Variable', t, 'MaxCols', 2, 'DepthLimit', 0, 'ObjectLimit', 1));
					sec2 = Section('Plots'); 
					me.showLog();
					f = gcf;
					if strcmpi(f.Tag,'opticka')
						fr = Figure(f);
						fr.Scaling = 'none';
						fr.Snapshot.ScaleToFit = true;
						append(sec2,Paragraph('All State Events (from the stateMachine.log property):'))
						append(sec2,fr);
					end
					close(f);
					append(ch,sec);
					append(ch,sec2);
					append(rpt,ch);

				case 'behaviouralRecord'
					fprintf('=== makeReport: behaviouralRecord @%.2f secs\n',toc(tt));
					ch = Chapter('behaviouralRecord Object'); 
					sec = Section('Plots'); 
					me.plotPerformance;
					if isgraphics(me.h.root)
						tmpf = [tempname '.png'];
						exportapp(me.h.root, tmpf);
						if exist(tmpf,'file')
							img = Image(tmpf);
							img.Style = {ScaleToFit};
							append(sec,img);
							try delete tmpf; end
						end
						try close(me.h.root); end
						try me.clearHandles; end
					end
					append(ch,sec);
					append(rpt,ch);
					
				case {'tobiiAnalysis','eyelinkAnalysis','iRecAnalysis'}
					fprintf('=== makeReport: eyeTracker @%.2f secs\n',toc(tt));
					ch = Chapter('Eyetracker Object'); 
					sec = Section('General Information'); 
					
					t = me.fileName;
					append(sec, MATLABVariable('Title','File','Variable', t));
					t = me.comment;
					append(sec, MATLABVariable('Title','Comment','Variable', t));
					p = Paragraph("We will try to load the data...");
					p.Style = parnote;
					append(sec,p)
					r = evalc('me.load(true)');
					append(sec,Preformatted(r));
					append(ch,sec); append(rpt,ch);

					if isprop(me, 'exp') && ~isempty(me.exp) && isfield(me.exp,'rE')
						rE = me.exp.rE;
						rE.makeReport(rpt);
					end
					
					ch = Chapter('Eyetracker Data'); 
					sec = Section('General Information'); 
					append(sec,Paragraph('Tobii Messages'))
					m = me.raw.messages;
					append(sec, MATLABVariable('Variable', m));
					p = Paragraph('We will try to parse the data and plot it now...');
					p.Style = parnote;
					append(sec,p)
					try
						r = evalc('me.parse');
						append(sec,Preformatted(r));
						plot(me);
						f = gcf;
						if strcmpi(f.Tag,'opticka')
							fr = Figure(f);
							fr.Scaling = 'none';
							fr.Snapshot.ScaleToFit = true;
							append(sec,fr);
						end
						close(f);
					catch ME
						append(sec,Paragraph('Parsing / plotting failed'))
						append(sec, MATLABVariable('Title','ERROR','Variable', ME));
					end
					append(ch,sec);append(rpt,ch);
			end

			if fullReport
				close(rpt);
				rptview(rpt);
			end
		
		end
		
		% ===================================================================
		function [list, typelist] = findAttributes(me, attrName, attrValue)
		% [list, typelist] = findAttributes(me, attrName, attrValue)
		%> @fn [list, typelist] = findAttributes (me, attrName, attrValue)
		%> @brief find properties of object with specific attributes, for
		%> example all properties whose GetAcccess attribute is public.
		%>
		%> @param attrName attribute name, i.e. GetAccess, Transient
		%> @param attrValue value of that attribute, i.e. public, true
		%>
		%> @return list of properties that match that attribute
		%> @return typelist the type of the property
		% ===================================================================
			if ischar(me) % Determine if first input is object or class name
				mc = meta.class.fromName(me);
			elseif isobject(me)
				mc = metaclass(me);
			end
			
			% Initial size and preallocate
			ii = 0; nProps = length(mc.PropertyList);
			nameArray = cell(1, nProps);
			typeArray = cell(1, nProps);
			
			% For each property, check the value of the queried attribute
			for  c = 1:nProps
				
				% Get a meta.property object from the meta.class object
				mp = mc.PropertyList(c);
				
				% Determine if the specified attribute is valid on this object
				if isempty (findprop(mp,attrName))
					error('Not a valid attribute name');
				end
				thisValue = mp.(attrName);
				% If the attribute is set or has the specified value,
				% save its name in cell array
				if ischar(attrValue)
					if strcmpi(attrValue, thisValue)
						ii = ii + 1;
						nameArray(ii) = {mp.Name};
						typeArray{ii} = getType(me, mp);
					end
				elseif islogical(attrValue)
					if thisValue == attrValue
						ii = ii + 1;
						nameArray(ii) = {mp.Name};
						typeArray{ii} = getType(me, mp);
					end
				elseif isempty(attrValue)
					if isempty(thisValue)
						ii = ii + 1;
						nameArray(ii) = {mp.Name};
						typeArray{ii} = getType(me, mp);
					end
				end
			end
			% Return used portion of array
			list = nameArray(1:ii)';
			typelist = typeArray(1:ii)';
		end
		
		% ===================================================================
		function list = findAttributesandType(me, attrName, attrValue, type)
		%> @fn list = findAttributesandType(me, attrName, attrValue, type)
		%> @brief find properties of object with specific attributes, for
		%> example all properties whose GetAcccess attribute is public and
		%> type is logical.
		%>
		%> @param attrName attribute name, i.e. GetAccess, Transient
		%> @param attrValue value of that attribute, i.e. public, true
		%> @param type logical, notlogical, string or number
		%>
		%> @return list of properties that match that attribute
		% ===================================================================
			if ischar(me) % Determine if first input is object or class name
				mc		= meta.class.fromName(me);
			elseif isobject(me)
				mc		= metaclass(me);
			end
			
			% Initial size and preallocate
			ii			= 0; 
			nProps		= length(mc.PropertyList);
			cl_array	= cell(1, nProps);
			
			% For each property, check the value of the queried attribute
			for  c = 1:nProps
				
				% Get a meta.property object from the meta.class object
				mp = mc.PropertyList(c);
				
				% Determine if the specified attribute is valid on this object
				if isempty (findprop(mp,attrName))
					error('Not a valid attribute name')
				end
				thisValue = mp.(attrName);
				
				% If the attribute is set or has the specified value,
				% save its name in cell array
				if exist('attrValue','var') && ~isempty(thisValue)
					if all(islogical(attrValue)) || all((ischar(thisValue) && strcmp(attrValue,thisValue)))
						val = me.(mp.Name);
						if exist('val','var')
							if islogical(val) && strcmpi(type,'logical')
								ii = ii + 1;
								cl_array(ii) = {mp.Name};
							elseif ~islogical(val) && strcmpi(type,'notlogical')
								ii = ii + 1;
								cl_array(ii) = {mp.Name};
							elseif ischar(val) && strcmpi(type,'string')
								ii = ii + 1;
								cl_array(ii) = {mp.Name};
							elseif isnumeric(val) && strcmpi(type,'number')
								ii = ii + 1;
								cl_array(ii) = {mp.Name};
							elseif strcmpi(type,'any')
								ii = ii + 1;
								cl_array(ii) = {mp.Name};
							end
						end
					end
				end
			end
			% Return used portion of array
			list = cl_array(1:ii);
		end

		% ===================================================================
		% TODO 
		function value = findPropertyDefault(me,propName)
			value = [];
			if ischar(me) % Determine if first input is object or class name
				mc		= meta.class.fromName(me);
			elseif isobject(me)
				mc		= metaclass(me);
			end
			nlist = {mc.PropertyList.Name};
			nidx = find(matches(nlist, propName));
			if ~isempty(nidx)
				value = mc.PropertyList(nidx).DefaultValue;
			end
		end
		
		% ===================================================================
		function obj_out = clone(me)
		%> @fn obj_out = clone(me)
		%> @brief Use this syntax to make a deep copy of the object, i.e.
		%> OBJ_OUT has the same field values, but will not behave as a
		%> handle-copy of me anymore.
		%>
		%> @return obj_out  cloned object
		% ===================================================================
			if isempty(me); obj_out = me; return; end
			meta = metaclass(me);
			obj_out = feval(class(me),'cloning',true);
			for i = 1:length(meta.Properties)
				prop = meta.Properties{i};
				if strcmpi(prop.SetAccess,'Public') ...
				&& ~(prop.Dependent || prop.Constant) ...
				&& isprop(obj_out, prop.Name) ...
				&& ~(isempty(me.(prop.Name)) ...
				&& isempty(obj_out.(prop.Name)))
					if isobject(me.(prop.Name)) && isa(me.(prop.Name),'optickaCore')
						obj_out.(prop.Name) = me.(prop.Name).clone;
					else
						try
							if ~matches(prop.Name,'font')
								obj_out.(prop.Name) = me.(prop.Name);
							end
						catch ERR %#ok<CTCH>
							warning('optickaCore:clone', 'Property not specified: "%s"',prop.Name)
						end
					end
				end
			end
			
			% Check lower levels ...
			props_child = {meta.PropertyList.Name};
			
			checkSuperclasses(meta)
			
			% This function is called recursively ...
			function checkSuperclasses(List)
				for ii=1:length(List.SuperclassList(:))
					if ~isempty(List.SuperclassList(ii).SuperclassList)
						checkSuperclasses(List.SuperclassList(ii))
					end
					for jj=1:length(List.SuperclassList(ii).PropertyList(:))
						prop_super = List.SuperclassList(ii).PropertyList(jj).Name;
						if ~strcmp(prop_super, props_child)
							obj_out.(prop_super) = me.(prop_super);
						end
					end
				end
			end
		end

		% ===================================================================
		function editProperties(me, properties)
		%> @fn editProperties
		%> @brief method to modify a set of properties
		%>
		%> @param properties - cell or struct of properties to modify
		% ===================================================================
			me.addArgs(properties);
		end

		% ===================================================================
		function setProp(me, property, value)
		%> @fn setProp(me, property, value)
		%> @brief method to fast change a particular value. This is
		%> useful for use in anonymous functions, like in the state machine.
		%>
		%> @param property — the property to change
		%> @param value — the value to change it to
		% ===================================================================
			if isprop(me,property)
				me.(property) = value;
			end
        end
		
	end

	%=======================================================================
	methods ( Hidden = true ) %-------HIDDEN METHODS-----%
	%=======================================================================

		% ===================================================================
		function ID = initialiseSaveFile(me)
		%> @fn initialiseSaveFile
		%> @brief just get date fragment
		%>
		% ===================================================================
			[~,~,ID] = getALF(me);
		end

		% ===================================================================
		function checkPaths(me)
		%> @fn checkPaths
		%> @brief checks the paths are valid
		%>
		% ===================================================================

			oldhome = me.paths.home;
			newhome = getenv('HOME');
			if ~matches(newhome,oldhome)
				fn = fieldnames(me.paths);
				for ii = 1:length(fieldnames(me.paths))
					if contains(me.paths.(fn{ii}),oldhome)
						me.paths.(fn{ii}) = regexprep(me.paths.(fn{ii}),oldhome,newhome);
					end
				end
				me.paths.oldhome = oldhome;
			end

			samePath = false;
			if isprop(me,'dir')

				%if our object wraps a plxReader, try to use its paths
				if isprop(me,'p') && isa(me.p,'plxReader')
					checkPaths(me.p);
					me.dir = me.p.dir; %inherit the path
				end

				if isprop(me,'matdir') %normally they are the same
					if ~isempty(me.dir) && strcmpi(me.dir, me.matdir)
						samePath = true;
					end
				end

				if ~exist(me.dir,'dir')
					if isprop(me,'file')
						fn = me.file;
					else
						fn = '';
					end
					fprintf('Please find new directory for: %s\n',fn);
					p = uigetdir('',['Please find new directory for: ' fn]);
					if p ~= 0
						me.dir = p;

					else
						warning('Can''t find valid source directory');
					end
				end
			end
			if isprop(me,'matdir')
				if samePath; me.matdir = me.dir; return; end
				if ~exist(me.matdir,'dir')
					if exist(me.dir,'dir')
						me.matdir = me.file;
					else
						if isprop(me,'matfile')
							fn = me.matfile;
						else
							fn = '';
						end
						fprintf('Please find new directory for: %s\n',fn);
						p = uigetdir('',['Please find new directory for: ' fn]);
						if p ~= 0
							me.matdir = p;
						else
							warning('Can''t find valid source directory');
						end
					end
				end
			end
			if isa(me,'plxReader')
				if isprop(me,'eA') && isa(me.eA,'eyelinkAnalysis')
					me.eA.dir = me.dir;
				end
			end
		end
	end

	%=======================================================================
	methods ( Static = true ) %-------STATIC METHODS-----%
	%=======================================================================

        % ===================================================================
		function [rM, aM] = initialiseGlobals(doReset, doOpen)
		%> @fn [rM, aM] = initialiseGlobals(doReset,doOpen)
		%> @brief in general we try NOT to use globals but for reward and audio, 
        %> due to e.g. eyelink and other devices we can't avoid it. This 
        %> initialises and returns the single-instance globals
		%> rM (rewardManager) and aM (audioManager). Run this to get the
		%> reward/audio manager objects in any child class...
		%>
		%> @param doReset - try to reset the objects? [false]
		%> @param doOpen  - try to open objects if not yet open? [false]
		% ===================================================================
			global rM aM %#ok<GVMIS>
				
			if ~exist('doReset','var'); doReset = false; end
			if ~exist('doOpen','var'); doOpen = false; end

			%------initialise the rewardManager global object
			if ~isa(rM,'arduinoManager'); rM = arduinoManager(); end
			if rM.isOpen && doReset
				try rM.close; rM.reset; end
			end
			if doOpen && ~rM.isOpen; open(rM); end
			
			%------initialise an audioManager for beeps,playing sounds etc.
			if ~isa(aM,'audioManager'); aM = audioManager(); end
			if doReset
				try
					aM.silentMode = false;
					reset(aM);
				catch
					warning('Could not reset audio manager!');
					aM.silentMode = true;
				end
			end
			if doOpen && ~aM.isOpen && ~aM.silentMode && (isempty(aM.device) || aM.device > -1)
				open(aM);
				aM.beep(2000,0.1,0.1);
			end
        end

		% ===================================================================
		function args = makeArgs(args)
		%> @fn makeArgs
		%> @brief Converts cell args to structure array
		%>
		%>
		%> @param args input data
		%> @return args as a structure
		% ===================================================================
			if isstruct(args); return; end
			while iscell(args) && length(args) == 1
				args = args{1};
			end
			if iscell(args)
				if mod(length(args),2) == 1 % odd
					args = args(1:end-1); %remove last arg
				end
				odd = logical(mod(1:length(args),2));
				even = logical(abs(odd-1));
				args = cell2struct(args(even),args(odd),2);
			elseif isstruct(args)
				return
			else
				error('---> makeArgs: You need to pass name:value pairs / structure of name:value fields!');
			end
		end

		% ===================================================================
		function args = addDefaults(args, defs)
		%> @fn addDefaults
		%> @brief add default options to arg input
		%>
		%>
		%> @param args input structure from varargin
		%> @param defs extra default settings
		%> @return args structure
		% ===================================================================
			if ~exist('args','var'); args = struct; end
			if ~exist('defs','var'); defs = struct; end
			if iscell(args); args = optickaCore.makeArgs(args); end
			if iscell(defs); defs = optickaCore.makeArgs(defs); end
			fnameDef = fieldnames(defs); %find our argument names
			fnameArg = fieldnames(args); %find our argument names
			for i=1:length(fnameDef)
				id=cell2mat(cellfun(@(c) strcmp(c,fnameDef{i}),fnameArg,'UniformOutput',false));
				if ~any(id)
					args.(fnameDef{i}) = defs.(fnameDef{i});
				end
			end
		end

		% ===================================================================
		function result = hasKey(in, key)
		%> @fn hasKey
		%> @brief check if a struct / object has a propery / field
		%>
		%> @param value name
		% ===================================================================
			result = false;
			if isfield(in, key) || isprop(in, key)
				result = true;
			end
		end

		% ===================================================================
		function [pressed, name, keys, shift] = getKeys(device)
		%> @fn getKeys
		%> @brief PTB Get key presses, stops key bouncing
		% ===================================================================
			persistent oldKeys
			persistent shiftKey 
			if ~exist('device','var'); device = []; end
			if isempty(oldKeys); oldKeys = zeros(1,256); end
			if isempty(shiftKey); shiftKey = KbName('LeftShift'); end
			pressed = false; name = []; keys = []; shift = false;

			[press, ~, keyCode] = KbCheck(device);
			shift = logical(keyCode(shiftKey));
			if press
				keys = keyCode & ~oldKeys;
				if any(keys)
					name = KbName(keys);
					pressed = true;
				end
			end
			oldKeys = keyCode;
		end

	end %--------END STATIC METHODS

	%=======================================================================
	methods ( Access = protected ) %-------PROTECTED METHODS-----%
	%=======================================================================

		% ===================================================================
		function parseArgs(me, args, allowedProperties)
		%> @fn parseArgs
		%> @brief Sets properties from a structure or normal arguments pairs,
		%> ignores invalid or non-allowed properties
		%>
		%> @param args input structure
		%> @param allowedProperties properties possible to set on construction
		% ===================================================================
			if ischar(allowedProperties)
				%we used | for regexp but better use cell array
				allowedProperties = strsplit(allowedProperties,'|');
			end
			
			args = optickaCore.makeArgs(args);

			if isstruct(args)
				fnames = fieldnames(args); %find our argument names
				for i=1:length(fnames)
					if matches(fnames{i},allowedProperties) %only set if allowed property
						try
							me.(fnames{i})=args.(fnames{i}); %we set up the properies from the arguments as a structure
						catch
							me.salutation(fnames{i},'Propery invalid!',true);
						end
					end
				end
			end
			
		end

		% ===================================================================
		function addArgs(me, args)
		%> @brief Sets properties from a structure or normal arguments pairs,
		%> ignores invalid or non-allowed properties
		%>
		%> @param args input structure
		% ===================================================================
			args = optickaCore.makeArgs(args);
			if isstruct(args)
				fnames = intersect(findAttributes(me,'SetAccess','public'),fieldnames(args));
				for i=1:length(fnames)
					try
						if isstruct(me.(fnames{i})) && isstruct(args.(fnames{i}))
							fn = fieldnames(args.(fnames{i}));
							for j = 1:length(fn)
								me.(fnames{i}).(fn{j}) = args.(fnames{i}).(fn{j});
							end
						else
							me.(fnames{i})=args.(fnames{i}); %we set up the properies from the arguments as a structure
						
						end
						me.salutation(fnames{i},'SET property')
					catch
						me.salutation(fnames{i},'Property INVALID!',true);
					end
				end
			end
		end

		% ===================================================================
		function setPaths(me)
		%> @brief set paths for object
		%>
		%> @param
		% ===================================================================
			me.paths(1).whatami = me.className;
			me.paths.root = fileparts(which(mfilename));
			me.paths.whereami = me.paths.root;
			if ~isfield(me.paths, 'stateInfoFile')
				me.paths.stateInfoFile = '';
			end
			if ismac || isunix
				me.paths.home = getenv('HOME');
			else
				me.paths.home = 'C:';
			end
			me.paths.parent = [me.paths.home filesep 'OptickaFiles'];
			if ~isfolder(me.paths.parent)
				status = mkdir(me.paths.parent);
				if status == 0; warning('Could not create OptickaFiles folder'); end
			end
			me.paths.savedData = [me.paths.parent filesep 'SavedData'];
			if ~isfolder(me.paths.savedData)
				status = mkdir(me.paths.savedData);
				if status == 0; warning('Could not create SavedData folder'); end
			end
			me.paths.protocols = [me.paths.parent filesep 'Protocols'];
			if ~isfolder(me.paths.protocols)
				status = mkdir(me.paths.protocols);
				if status == 0; warning('Could not create Protocols folder'); end
			end
			me.paths.calibration = [me.paths.parent filesep 'Calibration'];
			if ~isfolder(me.paths.calibration)
				status = mkdir(me.paths.calibration);
				if status == 0; warning('Could not create Calibration folder'); end
			end
			if isdeployed
				me.paths.deploypath = ctfroot;
			end
		end

		% ===================================================================
		function getFonts(me)
		%> @fn getFonts(me)
		%> @brief Checks OS and assigns a sans and mono font
			lf = listfonts;
			if ismac
				me.sansFont = 'Avenir Next';
				me.monoFont = 'Menlo';
			elseif ispc
				me.sansFont = 'Calibri';
				me.monoFont = 'Consolas';
			else %linux
				me.sansFont = 'Ubuntu'; 
				me.monoFont = 'Ubuntu Mono';
			end
			if matches('Graublau Sans', lf)
				me.sansFont = 'Graublau Sans';
			elseif matches('Source Sans 3', lf)
				me.sansFont = 'Source Sans 3';
			elseif matches('Source Sans Pro', lf)
				me.sansFont = 'Source Sans Pro';
			end
			if matches('Fira Code', lf)
				me.monoFont = 'Fira Code';
			elseif matches('Cascadia Code', lf)
				me.monoFont = 'Cascadia Code';
			elseif matches('JetBrains Mono', lf)
				me.monoFont = 'JetBrains Mono';
			end
		end
		
		% ===================================================================
		function out=toStructure(me)
		%> @fn out=toStructure(me)
		%> @brief Converts properties to a structure
		%>
		%>
		%> @param me this instance object
		%> @param tmp is whether to use the temporary or permanent properties
		%> @return out the structure
		% ===================================================================
			fn = fieldnames(me);
			for j=1:length(fn)
				out.(fn{j}) = me.(fn{j});
			end
		end

		% ===================================================================
		function out = getType(me, in)
		%> @brief Give a metaproperty return the likely property class
		%>
		%>
		%> @param me this instance object
		%> @param in metaproperty
		%> @return out class name
		% ===================================================================
			out = 'undefined';
			thisClass = '';
			if in.HasDefault
				thisClass = class(in.DefaultValue);
				if strcmpi(thisClass,'double') && length(in.DefaultValue) > 1
					thisClass = '{[double vector],[]}';
				end
			elseif ~isempty(in.Validation) && ~isempty(in.Validation.Class)
				thisClass = in.Validation.Class.Name;
			end
			if ~isempty(thisClass); out = thisClass; end
		end


		% ===================================================================
		function logOutput(me, in, message, override)
		%> @brief Prints messages dependent on verbosity
		%>
		%> Prints messages dependent on verbosity
		%> @param me this instance object
		%> @param in the calling function or main info
		%> @param message additional message that needs printing to command window
		%> @param override force logging if true even if verbose is false
		% ===================================================================
			if ~exist('override','var');override = false;end
			if me.verbose==true || override == true
				if ~exist('message','var') || isempty(message)
					fprintf(['---> ' me.fullName_ ': ' in '\n']);
				else
					fprintf(['---> ' me.fullName_ ': ' message ' | ' in '\n']);
				end
			end
		end
		function salutation(me, varargin)
			logOutput(me, varargin{:});
		end
		
	end
end
