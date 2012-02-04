function savelut(filename, mp)

% SAVELUT(filename, lut)
%       SAVE look-up-table of cortex from a matlab colormap matrix
%       filename,       path should be included
%       mp,            the array to store the map in 0-255

% By Yi-Xiong Zhou on 4-9-96


if length(filename)<5
	filename=[filename, '.lut'];
elseif any(filename(length(filename)-3:length(filename))~='.lut'),
	filename=[filename, '.lut'];
end


lut=[mp, zeros(size(mp,1),1)];
fid=fopen(filename, 'w');
[fn, pp, ar]=fopen(fid);
if strcmp(ar, 'ieee-be')
	tmp=floor(lut/256);
	lut=(lut-tmp*256)*256+tmp;
elseif ~strcmp(ar, 'ieee-le')
	error('unknown machine. find out the byte switch requirement first.');
end

fwrite(fid, lut', 'uint16');
fclose(fid);


