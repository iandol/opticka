function [v, pos] = deserialize(m, pos)
% DESERIALIZE converts the output of SERIALIZE back into a matlab object.
%
% v = DESERIALIZE(m)
% [v, pos] = DESERIALIZE(m, pos)
%
% m is the series of bytes created by SERIALIZE. Integer numeric types are
% automatically converted back to doubles. The optional input/output 'pos'
% is the position to start reading from, and is returned as pointing to the
% first unused byte.
%
% If all the data is supposed to be decoded, the following should be true
% after execution.
%
% pos == numel(m)+1
%
% By Tim Hutt, 19/11/2010
%
% Updated 16/12/2010 - Fix bug with matrices.

	if ~isnumeric(m)
		error('Input must be numeric (and uint8)');
	end
	if ~strcmp(class(m), 'uint8') 
		error('Input must be uint8');
	end
	if nargin < 2
		pos = 1;
	end
	if pos > numel(m)
		error('Input too small')
	end
	
	cls = byteToClass(m(pos));
	
	switch (cls)
		case {'double', 'single', 'logical', 'char', ...
				'int8', 'uint8', 'int16', 'uint16', 'int32', 'uint32', 'int64', 'uint64'}
			[v, pos] = deserializeMatrix(m, pos);			
		case 'struct'
			[v, pos] = deserializeStruct(m, pos);			
		case 'cell'
			[v, pos] = deserializeCell(m, pos);			
		otherwise
			error('Unknown class');
	end

end

function [v, pos] = deserializeMatrix(m, pos)
	cls = byteToClass(m(pos));
	pos = pos + 1;
	ndms = double(m(pos));
	pos = pos + 1;
	dms = [];
	for ii = 1:ndms
		dms(ii) = double(typecast(m(pos:pos+3), 'uint32'));
		pos = pos + 4;
	end
	
	nbytes = prod(dms) * sizeof(cls);
	
	% Data.
	switch cls
		case 'char'
			v = char(m(pos:pos+nbytes-1));
		case 'logical'
			v = logical(m(pos:pos+nbytes-1));
		otherwise
			v = double(typecast(m(pos:pos+nbytes-1), cls));
	end
	
	pos = pos + nbytes;
	v = reshape(v, [dms 1 1]);
end

function sz = sizeof(cls)
	switch cls
		case {'double', 'int64', 'uint64'}
			sz = 8;
		case {'single', 'int32', 'uint32'}
			sz = 4;
		case {'int16', 'uint16'}
			sz = 2;
		case {'logical', 'char', 'int8', 'uint8'}
			sz = 1;
		otherwise
			error('Unknown class');
	end
end

function cls = byteToClass(b)
	switch b
		case 0
			cls = 'double';
		case 1
			cls = 'single';
		case 2
			cls = 'logical';
		case 3
			cls = 'char';
		case 4
			cls = 'int8';
		case 5
			cls = 'uint8';
		case 6
			cls = 'int16';
		case 7
			cls = 'uint16';
		case 8
			cls = 'int32';
		case 9
			cls = 'uint32';
		case 10
			cls = 'int64';
		case 11
			cls = 'uint64';
		case 254
			cls = 'cell';
		case 255
			cls = 'struct';
		otherwise
			error('Unknown class');
	end
end


function [v, pos] = deserializeCell(m, pos)
	pos = pos + 1; % We know it is a cell.
	
	
	ndms = double(m(pos));
	pos = pos + 1;
	dms = [];
	for ii = 1:ndms
		dms(ii) = double(typecast(m(pos:pos+3), 'uint32'));
		pos = pos + 4;
	end
	
	nels = prod(dms);
	
	v = {};
	for ii = 1:nels
		[v{ii}, pos] = deserialize(m, pos);
	end
	v = reshape(v, [dms 1 1]);
end

% Struct array. A plain struct is just a struct array of size 1.
function [v, pos] = deserializeStruct(m, pos)
	pos = pos + 1; % We know it is a struct.
	
	% Number of field names.
	nfields = double(m(pos));
	pos = pos + 1;
	% Field names.
	for ii = 1:nfields
		fnlen = double(typecast(m(pos:pos+3), 'uint32'));
		pos = pos + 4;
		fieldNames{ii} = char(m(pos:pos+fnlen-1)).';
		pos = pos + fnlen;
	end

	% Dimensions
	ndms = double(m(pos));
	pos = pos + 1;
	dms = [];
	for ii = 1:ndms
		dms(ii) = double(typecast(m(pos:pos+3), 'uint32'));
		pos = pos + 4;
	end
	
	nels = prod(dms);
	
	v = [];
	for ii = 1:nels
		for ff = 1:nfields
			[v(ii).(fieldNames{ff}), pos] = deserialize(m, pos);
		end
	end
	v = reshape(v, [dms 1 1]);

end