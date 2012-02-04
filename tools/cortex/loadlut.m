function lut=loadlut(filename)

% lut=LAODCX(filename)
%       load the look-up-table file of the cortex
%       filename,       path should be included
%       lut,            the array to store the look-up-table

% By Yi-Xiong Zhou on 4-9-96


if length(filename)<5
	filename=[filename, '.lut'];
elseif any(filename(length(filename)-3:length(filename))~='.lut'),
	filename=[filename, '.lut'];
end

fid=fopen(filename, 'r');
[lut,n]=fread(fid, inf, 'uint16');
if floor(n/4)~=n/4, 
	error('not the correct number of inputs for a lut file');
end

lut=reshape(lut, 4, n/4)'; lut=lut(:,1:3);
[fn, pp, ar]=fopen(fid);
if strcmp(ar, 'ieee-be')
	tmp=floor(lut/256);
	lut=(lut-tmp*256)*256+tmp;
elseif ~strcmp(ar, 'ieee-le')
	error('unknown machine. find out the byte switch requirement first.');
end

fclose(fid);


