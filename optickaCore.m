% ========================================================================
%> @brief optickaCore base class inherited by many other opticka classes.
%> optickaCore is itself derived from handle. It provides methods to find
%> attributes with specific parameters (used in autogenerating UI panels),
%> clone the object, parse arguments safely on construction and default
%> properties such as datestamp, a UUID and name/comment management.
% ========================================================================
classdef optickaCore < handle
	
	%--------------------PUBLIC PROPERTIES----------%
	properties
		%> object name
		name char = ''
		%> comment
		comment char = ''
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
		dateStamp double
		%> universal ID
		uuid char
		%> storage of various paths
		paths struct
	end
	
	%--------------------DEPENDENT PROPERTIES----------%
	properties (Dependent = true)
		%> The fullName is the object name combined with its uuid and class name
		fullName char
	end
	
	%--------------------TRANSIENT PROPERTIES----------%
	properties (SetAccess = protected, GetAccess = protected, Transient = true)
		%> Matlab version number, this is transient so it is not saved
		mversion double = 0
	end
	
	%--------------------PROTECTED PROPERTIES----------%
	properties (SetAccess = protected, GetAccess = protected)
		%> class name
		className char = ''
		%> save prefix generated from clock time
		savePrefix
	end
	
	%--------------------PRIVATE PROPERTIES----------%
	properties (SetAccess = private, GetAccess = private)
		%> allowed properties passed to object upon construction
		allowedPropertiesCore char = 'name|comment|cloning'
		%> cached full name
		fullName_ char
	end
	
	%=======================================================================
	methods %------------------PUBLIC METHODS
	%=======================================================================
		
		% ===================================================================
		%> @brief Class constructor
		%>
		%> More detailed description of what the constructor does.
		%>
		%> @param args are passed as a structure of properties which is
		%> parsed.
		%> @return instance of class.
		% ===================================================================
		function me = optickaCore(args)
			me.className = class(me);
			me.dateStamp = clock();
			me.uuid = num2str(dec2hex(floor((now - floor(now))*1e10))); %me.uuid = char(java.util.UUID.randomUUID)%128bit uuid
			me.fullName_ = me.fullName; %cache fullName
			if nargin>0
				me.parseArgs(args,me.allowedPropertiesCore);
			end
			me.mversion = str2double(regexp(version,'(?<ver>^\d\.\d[\d]?)','match','once'));
			setPaths(me)
		end
		
		% ===================================================================
		%> @brief concatenate the name with a uuid at get.
		%> @param
		%> @return name the concatenated name
		% ===================================================================
		function name = get.fullName(me)
			if isempty(me.name)
				me.fullName_ = [me.className '#' me.uuid];
			else
				me.fullName_ = [me.name ' <' me.className '#' me.uuid '>'];
			end
			name = me.fullName_;
		end
		
		% ===================================================================
		%> @brief Initialise Save Dir
		%>
		%> For single stimulus presentation, randomise stimulus choice
		% ===================================================================
		function initialiseSaveFile(me,path)
			if ~exist('path','var')
				path = me.paths.savedData;
			else
				me.paths.savedData = path;
			end
			c = fix(clock);
			c = num2str(c(1:5));
			c = regexprep(c,' +','-');
			me.savePrefix = c;
		end
		
		% ===================================================================
		%> @brief find properties of object with specific attributes, for
		%> example all properties whose GetAcccess attribute is public
		%> @param attrName attribute name, i.e. GetAccess, Transient
		%> @param attrValue value of that attribute, i.e. public, true
		%> @return list of properties that match that attribute
		% ===================================================================
		function [list, mplist] = findAttributes(me, attrName, attrValue)
			% Determine if first input is object or class name
			if ischar(me)
				mc = meta.class.fromName(me);
			elseif isobject(me)
				mc = metaclass(me);
			end
			
			% Initial size and preallocate
			ii = 0; nProps = length(mc.PropertyList);
			cl_array = cell(1,nProps);
			mp_array = cell(1,nProps);
			
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
				if ischar(attrValue)
					if strcmpi(attrValue,thisValue)
						ii = ii + 1;
						cl_array(ii) = {mp.Name};
						mp_array{ii} = mp;
					end
				elseif islogical(attrValue)
					if thisValue == attrValue
						ii = ii + 1;
						cl_array(ii) = {mp.Name};
						mp_array{ii} = mp;
					end
				elseif isempty(attrValue)
					if isempty(thisValue)
						ii = ii + 1;
						cl_array(ii) = {mp.Name};
						mp_array(ii) = mp;
					end
				end
			end
			% Return used portion of array
			list = cl_array(1:ii)';
			mplist = mp_array(1:ii)';
		end
		
		% ===================================================================
		%> @brief find properties of object with specific attributes, for
		%> example all properties whose GetAcccess attribute is public and
		%> type is logical
		%> @param attrName attribute name, i.e. GetAccess, Transient
		%> @param attrValue value of that attribute, i.e. public, true
		%> @param type logical, notlogical, string or number
		%> @return list of properties that match that attribute
		% ===================================================================
		function list = findAttributesandType(me, attrName, attrValue, type)
			% Determine if first input is object or class name
			if ischar(me)
				mc = meta.class.fromName(me);
			elseif isobject(me)
				mc = metaclass(me);
			end
			
			% Initial size and preallocate
			ii = 0; nProps = length(mc.PropertyList);
			cl_array = cell(1,nProps);
			
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
				if attrValue
					if islogical(attrValue) || strcmp(attrValue,thisValue)
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
		%> @brief Use this syntax to make a deep copy of an object me,
		%> i.e. OBJ_OUT has the same field values, but will not behave as a handle-copy of me anymore.
		%>
		%> @return obj_out  cloned object
		% ===================================================================
		function obj_out = clone(me)
			meta = metaclass(me);
			obj_out = feval(class(me),'cloning',true);
			for i = 1:length(meta.Properties)
				prop = meta.Properties{i};
				if strcmpi(prop.SetAccess,'Public') && ~(prop.Dependent || prop.Constant) && ~(isempty(me.(prop.Name)) && isempty(obj_out.(prop.Name)))
					if isobject(me.(prop.Name)) && isa(me.(prop.Name),'optickaCore')
						obj_out.(prop.Name) = me.(prop.Name).clone;
					else
						try
							obj_out.(prop.Name) = me.(prop.Name);
						catch %#ok<CTCH>
							warning('optickaCore:clone', 'Problem copying property "%s"',prop.Name)
						end
					end
				end
			end
			
			% Check lower levels ...
			props_child = {meta.PropertyList.Name};
			
			CheckSuperclasses(meta)
			
			% This function is called recursively ...
			function CheckSuperclasses(List)
				for ii=1:length(List.SuperclassList(:))
					if ~isempty(List.SuperclassList(ii).SuperclassList)
						CheckSuperclasses(List.SuperclassList(ii))
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
		%> @brief editProperties -- method to edit a bunch of properties
		%>
		%> @param properties - cell or struct of properties
		% ===================================================================
		function editProperties(me, properties)
			me.addArgs(properties);
		end
		
		% ===================================================================
		%> @brief set -- method to fast change a particular value. This is
		%> useful for use in anonymous functions, like in the state machine.
		%>
		%> @param property - the property to change
		%> @param value - the value to change it to
		% ===================================================================
		function set(me, property, value)
			if isprop(me,property)
				me.(property) = value;
			end
		end
		
	end
	
	%=======================================================================
	methods ( Hidden = true ) %-------HIDDEN METHODS-----%
	%=======================================================================
		% ===================================================================
		%> @brief checkPaths
		%>
		%> @param
		%> @return
		% ===================================================================
		function checkPaths(ego)
			samePath = false;
			if isprop(ego,'dir')
				
				%if our object wraps a plxReader, try to use its paths
				if isprop(ego,'p') && isa(ego.p,'plxReader')
					checkPaths(ego.p);
					ego.dir = ego.p.dir; %inherit the path
				end
				
				if isprop(ego,'matdir') %normally they are the same
					if ~isempty(ego.dir) && strcmpi(ego.dir, ego.matdir)
						samePath = true; 
					end
				end
				
				if ~exist(ego.dir,'dir')
					if isprop(ego,'file')
						fn = ego.file;
					else
						fn = '';
					end
					fprintf('Please find new directory for: %s\n',fn);
					p = uigetdir('',['Please find new directory for: ' fn]);
					if p ~= 0
						ego.dir = p;
						
					else
						warning('Can''t find valid source directory')
					end
				end
			end
			if isprop(ego,'matdir')
				if samePath; ego.matdir = ego.dir; return; end
				if ~exist(ego.matdir,'dir')
					if exist(ego.dir,'dir')
						ego.matdir = ego.file;
					else
						if isprop(ego,'matfile')
							fn = ego.matfile;
						else
							fn = '';
						end
						fprintf('Please find new directory for: %s\n',fn);
						p = uigetdir('',['Please find new directory for: ' fn]);
						if p ~= 0
							ego.matdir = p;
						else
							warning('Can''t find valid source directory')
						end
					end
				end
			end
			if isa(ego,'plxReader')
				if isprop(ego,'eA') && isa(ego.eA,'eyelinkAnalysis')
					ego.eA.dir = ego.dir;
				end
			end
		end
	end
	
	%=======================================================================
	methods ( Static = true ) %-------STATIC METHODS-----%
	%=======================================================================
	
		% ===================================================================
		%> @brief Converts cell args to structure
		%> 
		%>
		%> @param args input structure
		%> @return args
		% ===================================================================
		function args = makeArgs(args)
			
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
			end
			
		end
		
		% ===================================================================
		%> @brief add default options to arg input
		%> 
		%>
		%> @param args input structure
		%> @return args
		% ===================================================================
		function args = addDefaults(args,defs)
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
		
	end %--------END STATIC METHODS
	
	%=======================================================================
	methods ( Access = protected ) %-------PROTECTED METHODS-----%
	%=======================================================================
		
		% ===================================================================
		%> @brief Sets properties from a structure or normal arguments pairs,
		%> ignores invalid or non-allowed properties
		%>
		%> @param args input structure
		%> @param allowedProperties properties possible to set on construction
		% ===================================================================
		function parseArgs(me, args, allowedProperties)
			allowedProperties = ['^(' allowedProperties ')$'];
			
			args = optickaCore.makeArgs(args);

			if isstruct(args)
				fnames = fieldnames(args); %find our argument names
				for i=1:length(fnames)
					if regexpi(fnames{i},allowedProperties) %only set if allowed property
						me.salutation(fnames{i},'Parsing input argument');
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
		%> @brief Sets properties from a structure or normal arguments pairs,
		%> ignores invalid or non-allowed properties
		%>
		%> @param args input structure
		%> @param allowedProperties properties possible to set on construction
		% ===================================================================
		function addArgs(me, args)
			args = optickaCore.makeArgs(args);
			if isstruct(args)
				fnames = intersect(findAttributes(me,'SetAccess','public'),fieldnames(args));
				for i=1:length(fnames)
					try
						me.(fnames{i})=args.(fnames{i}); %we set up the properies from the arguments as a structure
						me.salutation(fnames{i},'SET property')
					catch
						me.salutation(fnames{i},'Property INVALID!',true);
					end
				end
			end
		end
		
		% ===================================================================
		%> @brief set paths for object
		%>
		%> @param
		% ===================================================================
		function setPaths(me)
			me.paths(1).whatami = me.className;
			me.paths.root = fileparts(which(mfilename));
			me.paths.whereami = me.paths.root;
			if ~isfield(me.paths, 'stateInfoFile')
				me.paths.stateInfoFile = '';
			end
			if ismac || isunix
				[~, me.paths.home] = system('echo $HOME');
				me.paths.home = regexprep(me.paths.home,'\n','');
			else
				me.paths.home = 'C:';
			end
			me.paths.parent = [me.paths.home filesep 'MatlabFiles'];
			if ~isfolder(me.paths.parent)
				status = mkdir(me.paths.parent);
				if status == 0;warning('Could not create MatlabFiles folder');end
			end
			me.paths.savedData = [me.paths.parent filesep 'SavedData'];
			if ~isfolder(me.paths.savedData)
				status = mkdir(me.paths.savedData);
				if status == 0;warning('Could not create savedData folder');end
			end
		end
		
		% ===================================================================
		%> @brief Converts properties to a structure
		%>
		%>
		%> @param me this instance object
		%> @param tmp is whether to use the temporary or permanent properties
		%> @return out the structure
		% ===================================================================
		function out=toStructure(me)
			fn = fieldnames(me);
			for j=1:length(fn)
				out.(fn{j}) = me.(fn{j});
			end
		end
		
		
		% ===================================================================
		%> @brief Prints messages dependent on verbosity
		%>
		%> Prints messages dependent on verbosity
		%> @param me this instance object
		%> @param in the calling function or main info
		%> @param message additional message that needs printing to command window
		%> @param override force logging if true even if verbose is false
		% ===================================================================
		function salutation(me,in,message,override)
			if ~exist('override','var');override = false;end
			if me.verbose==true || override == true
				if ~exist('message','var') || isempty(message)
					fprintf(['---> ' me.fullName_ ': ' in '\n']);
				else
					fprintf(['---> ' me.fullName_ ': ' message ' | ' in '\n']);
				end
			end
		end
		
	end
end
