function savecx(filename, notes, dmns, imgmtx)

% SAVECX(filename, notes, dmns, imgmtx)
%       save the image files as a cortex readable image file.
%       filename,       path should be included
%       notes,          maximume 10 characters
%       dmns=[depth, x, y, nframes], in which
%               depth,          bitmap depth (1,2,4, or 8)
%               x,              x dimension of the image
%               y,              y dimension of the image
%               nframes,        number of frames in the movie
%       imgmtx,    the image file, will be rounded to the range of 0-255.
%
% By Yi-Xiong Zhou on 4-9-96
% Last modified 9-3-96
%

if size(notes,2)>10, notes=notes([1:10]);
else, notes=[notes, zeros(1,10-size(notes,2))];
end

x=dmns(2); y=dmns(3); nf=dmns(4); 
nfy=size(imgmtx)./[y,x]; nfx=nfy(2); nfy=nfy(1);
if (nfx > 1.99) | (nfy > 1.99)
	dmns(4)=dmns(4)-1;
end

if (nf ~= round(nfx*nfy)) & (nf ~= 0)
	disp('warning: dimension does not match!!')
	if (nf > 1)
		nfx=nfx+0.01; nfx=floor(nfx);
		nfy=nfy+0.01; nfy=floor(nfy);
		imgmtx=imgmtx(1:nfy*y, 1:nfx*x);
	end
	disp('image is cropped to its maximal number of frames')
end
if (nfx > 1.5)
	nfy=nfx*nfy; nfx=1;
	%imgmtx=restack(imgmtx, [x,y], [1,nfy]);
   imgmtx=reshape(imgmtx, x,y,nfy);
end
imgmtx=round(imgmtx);
imgmtx=imgmtx'; 


fid=fopen(filename, 'w');

[fn, pp, ar]=fopen(fid);
if strcmp(ar, 'ieee-be')
	tmp=floor(dmns/256);
	dmns=(dmns-tmp*256)*256+tmp;
elseif ~strcmp(ar, 'ieee-le')
	disp('unknow file format. find out the byte switch requirement!')
	disp('use unswitch as default') 
end

for i=1:nfy
	fwrite(fid, notes, 'char');
	fwrite(fid, dmns, 'uint16');
	if i==1, dmns(4)=0; end
	fwrite(fid, imgmtx(:, 1+(i-1)*y:i*y), 'uchar');
end
fclose(fid);




