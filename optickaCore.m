% ========================================================================
%> @brief optickaCore base class inherited by many other opticka classes.
%> optickaCore is itself derived from handle
% ========================================================================
classdef optickaCore < handle
	
	%--------------------PUBLIC PROPERTIES----------%
	properties
		%> object name
		name = ''
	end
	
	%--------------------ABSTRACT PROPERTIES----------%
	properties (Abstract = true)
		%> verbose logging, subclasses must assign this. This is normally true/false
		verbose
	end
	
	%--------------------VISIBLE PROPERTIES----------%
	properties (SetAccess = protected, GetAccess = public)
		%> clock() dateStamp set on construction
		dateStamp
		%> universal ID
		uuid = 0
		%> storage of various paths
		paths = struct()
	end
	
	%--------------------DEPENDENT PROPERTIES----------%
	properties (SetAccess = private, Dependent = true)
		%> The fullName is the object name combined with its uuid and class name
		fullName = ''
	end
	
	%--------------------TRANSIENT PROPERTIES----------%
	properties (SetAccess = protected, GetAccess = protected, Transient = true)
		%> Matlab version number, this is transient so it is not saved
		mversion = 0
	end
	
	%--------------------PROTECTED PROPERTIES----------%
	properties (SetAccess = protected, GetAccess = protected)
		%> class name
		className = ''
	end
	
	%--------------------PRIVATE PROPERTIES----------%
	properties (SetAccess = private, GetAccess = private)
		%> allowed properties passed to object upon construction
		allowedProperties = 'name'
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
		function obj = optickaCore(args)
			obj.className = class(obj);
			obj.dateStamp = clock();
			obj.uuid = num2str(dec2hex(floor((now - floor(now))*1e10)));
			%obj.uuid = char(java.util.UUID.randomUUID); %128bit uuid;
			if nargin>0
				obj.parseArgs(args,obj.allowedProperties);
			end
			obj.mversion = str2double(regexp(version,'(?<ver>^\d\.\d\d)','match','once'));
			obj.paths.whatami = obj.className;
			obj.paths.root = fileparts(which(mfilename));
		end
		
		% ===================================================================
		%> @brief concatenate the name with a uuid at get.
		%> @param
		%> @return name the concatenated name
		% ===================================================================
		function name = get.fullName(obj)
			if isempty(obj.name)
				name = [obj.className '#' obj.uuid];
			else
				name = [obj.name ' <' obj.className '#' obj.uuid '>'];
			end
		end
		
		% ===================================================================
		%> @brief find properties of object with specific attributes, for
		%> example all properties whose GetAcccess attribute is public
		%> @param attrName attribute name, i.e. GetAccess, Transient
		%> @param attrValue value of that attribute, i.e. public, true
		%> @return list of properties that match that attribute
		% ===================================================================
		function [list, mplist] = findAttributes(obj, attrName, attrValue)
			% Determine if first input is object or class name
			if ischar(obj)
				mc = meta.class.fromName(obj);
			elseif isobject(obj)
				mc = metaclass(obj);
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
		function list = findAttributesandType(obj, attrName, attrValue, type)
			% Determine if first input is object or class name
			if ischar(obj)
				mc = meta.class.fromName(obj);
			elseif isobject(obj)
				mc = metaclass(obj);
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
						val = obj.(mp.Name);
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
			% Return used portion of array
			list = cl_array(1:ii);
		end
		
		% ===================================================================
		%> @brief Use this syntax to make a deep copy of an object OBJ, 
		%> i.e. OBJ_OUT has the same field values, but will not behave as a handle-copy of OBJ anymore.
		%> 
		%> @return obj_out  cloned object
		% ===================================================================
		function obj_out = clone(obj)
            meta = metaclass(obj);
            obj_out = feval(class(obj));
            for i = 1:length(meta.Properties)
                prop = meta.Properties{i};
                if strcmpi(prop.SetAccess,'Public') && ~(prop.Dependent || prop.Constant) && ~(isempty(obj.(prop.Name)) && isempty(obj_out.(prop.Name)))
                    if isobject(obj.(prop.Name)) && isa(obj.(prop.Name),'optickaCore')
                        obj_out.(prop.Name) = obj.(prop.Name).clone;
					else
                        try
                            obj_out.(prop.Name) = obj.(prop.Name);
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
                            obj_out.(prop_super) = obj.(prop_super);
                        end
                    end
                end
			end
			obj_out.dateStamp = clock();
			obj_out.uuid = num2str(dec2hex(floor((now - floor(now))*1e10)));
        end
		
	end
	
	%=======================================================================
	methods ( Access = protected ) %-------PRIVATE (protected) METHODS-----%
		%=======================================================================
		
		% ===================================================================
		%> @brief Sets properties from a structure or normal arguments,
		%> ignores invalid properties
		%>
		%> @param args input structure
		%> @param allowedProperties properties possible to set on construction
		% ===================================================================
		function parseArgs(obj, args, allowedProperties)
			allowedProperties = ['^(' allowedProperties ')$'];
			
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
			
			if isstruct(args)
				fnames = fieldnames(args); %find our argument names
				for i=1:length(fnames);
					if regexp(fnames{i},allowedProperties) %only set if allowed property
						obj.salutation(fnames{i},'Constructor parsing input argument');
						obj.(fnames{i})=args.(fnames{i}); %we set up the properies from the arguments as a structure
					else
						obj.salutation(fnames{i},'Constructor parsing: invalid input');
					end
				end
			end
			
		end
		
		% ===================================================================
		%> @brief Prints messages dependent on verbosity
		%>
		%> Prints messages dependent on verbosity
		%> @param obj this instance object
		%> @param in the calling function
		%> @param message the message that needs printing to command window
		% ===================================================================
		function salutation(obj,in,message,override)
			if ~exist('override','var')
				override = false;
			end
			if obj.verbose==true || override == true
				if ~exist('in','var')
					in = 'undefined';
				end
				if exist('message','var')
					fprintf(['---> ' obj.fullName ': ' message ' | ' in '\n']);
				else
					fprintf(['---> ' obj.fullName ': ' in '\n']);
				end
			end
		end
		
		
		
	end
end