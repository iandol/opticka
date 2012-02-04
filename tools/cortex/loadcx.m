function [imgmtx, dmns, notes]=loadcx(filename)

% [imgmtx, dimensions, notes]=LOADCX(filename)
%       save the image files as a cortex readable image file.
%       filename,       path should be included
%       notes,          maximume 10 characters
%       dmns=[depth, x, y, nframes], in which
%               depth,          bitmap depth (1,2,4, or 8)
%               x,              x dimension of the image
%               y,              y dimension of the image
%               nframes,        number of frames in the movie
%       imgmtx,    the image file, will be rounded.

% By Yi-Xiong Zhou on 4-9-96



fid=fopen(filename, 'r');
notes=setstr(fread(fid, 10, 'char'))'
dmns=fread(fid, 4, 'uint16')';
[imgmtx, n]=fread(fid, inf, 'uchar');

[fn, pp, ar]=fopen(fid);
if strcmp(ar, 'ieee-be')
	tmp=floor(dmns/256);
	dmns=(dmns-256*tmp)*256+tmp;
elseif ~strcmp(ar, 'ieee-le')
	disp('unkown file format. find out the byte switch requirement.')
	disp('no byte switch was applied')
end
if (dmns(4) > 0) & (floor(max(size(imgmtx))/dmns(2)/dmns(3)) > 1)
	dmns(4)=dmns(4)+1; 
end
dmns
fclose(fid);


if (dmns(4) > 1) & (dmns(4) < 500) & (dmns(1) <= 8)
	imgmtx=[ones(18,1); imgmtx]; nf=dmns(4);
	if max(size(imgmtx)) ~= (dmns(2)*dmns(3)+18)*nf
		disp('dimension not match in the input file');
		nf=floor(max(size(imgmtx))/(dmns(2)*dmns(3)+18));
		imgmtx=imgmtx(1:(dmns(2)*dmns(3)+18)*nf);
	end
	imgmtx=reshape(imgmtx, (dmns(2)*dmns(3)+18), nf);
	imgmtx=imgmtx(19:(dmns(2)*dmns(3)+18), :);
	imgmtx=reshape(imgmtx, dmns(2), nf*dmns(3));
else
	if max(size(imgmtx)) ~= dmns(2)*dmns(3)
		disp('dimension not match in the input file');
		imgmtx=imgmtx(1:dmns(2)*dmns(3));
	end
	imgmtx=reshape(imgmtx, dmns(2), dmns(3));
end
imgmtx=imgmtx';


