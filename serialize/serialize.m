function m = serialize(v)
% SERIALIZE converts a matlab object into a compact (but uncompressed)
% series of bytes.
%  
% m = SERIALIZE(v)
%
% v is a matlab object. It can be any combination of
% structs, cells, and arrays. Other object types are not supported.
% Note that numeric types in matlab are double by default. To save space
% you might want to convert them to integers like this:
%
% foo = int16([1 2 3]);
%
% They are automatically converted back to doubles by DESERIALIZE.
%
% Limitations: No object can have more than 255 dimensions, and each
% dimension must be smaller than 2^32. Also structs cannot have more
% than 255 fields.
% 
% EXAMPLE:
%
% v(1).red = {'blue', uint16([1 2 3])};
% v(2).green = [4.5 6.7 8.9];
% m = serialize(v);
% v2 = deserialize(m);
%
% By Tim Hutt, 19/11/2010
%
% Updated 16/12/2010 - Fix bug with matrices.

	if isnumeric(v) || islogical(v) || ischar(v) % Matrix type thing.
		m = serializeMatrix(v);
	elseif isstruct(v)
		m = serializeStruct(v);
	elseif iscell(v)
		m = serializeCell(v);
	else
		error('Unknown class');
	end

end

function m = serializeMatrix(v)
	m = uint8([]);
	% Data type.
	m = [m; classToByte(class(v))];
	
	% Number of dimensions.
	m = [m; ndims(v)];
	
	% Dimensions.
	for ii = 1:ndims(v)
		m = [m; typecast(uint32(size(v, ii)), 'uint8').'];
	end
	
	% Data.
	if ischar(v)
		m = [m; uint8(v(:))];
	else
		m = [m; typecast(v(:).', 'uint8').'];
	end
end

function b = classToByte(cls)
	switch cls
		case 'double'
			b = 0;
		case 'single'
			b = 1;
		case 'logical'
			b = 2;
		case 'char'
			b = 3;
		case 'int8'
			b = 4;
		case 'uint8'
			b = 5;
		case 'int16'
			b = 6;
		case 'uint16'
			b = 7;
		case 'int32'
			b = 8;
		case 'uint32'
			b = 9;
		case 'int64'
			b = 10;
		case 'uint64'
			b = 11;
		otherwise
			error('Unknown class');
	end
end


function m = serializeCell(v)
	m = uint8([]);
	% Data type.
	m = [m; 254]; % 254 = cell.
	
	% Number of dimensions.
	m = [m; ndims(v)];
	
	% Dimensions.
	for ii = 1:ndims(v)
		m = [m; typecast(uint32(size(v, ii)), 'uint8').'];
	end
	
	% Just serialize each member.
	for ii = 1:numel(v)
		m = [m; serialize(v{ii})];
	end	
end

% Struct array. A plain struct is just a struct array of size 1.
function m = serializeStruct(v)
	m = uint8([]);
	% Data type.
	m = [m; 255]; % 255 = struct.
	
	
	% Field names.
	fieldNames = fieldnames(v);
	
	if numel(fieldNames) > 255
		error('Too many fields!');
	end
	
	% Number of field names.
	m = [m; numel(fieldNames)];
	
	for ii = 1:numel(fieldNames)
		m = [m; typecast(uint32(numel(fieldNames{ii})), 'uint8').'; uint8(fieldNames{ii}(:))];
	end	
	
	
	% Number of dimensions.
	m = [m; ndims(v)];
	
	% Dimensions.
	for ii = 1:ndims(v)
		m = [m; typecast(uint32(size(v, ii)), 'uint8').'];
	end
	
	% Now for go through each one.
	% This is slightly redundant because we encode the type info lots of
	% times, but it is only one byte so meh.
	for ii = 1:numel(v)
		for ff = 1:numel(fieldNames)
			m = [m; serialize(v(ii).(fieldNames{ff}))];
		end
	end
end