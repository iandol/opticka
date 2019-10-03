function [mapmat,map]=ctxlut2mat(mapdir,mapname);
%function [mapmat,map]=ctxlut2mat(mapdir,mapname);
%B Jagadeesh 6/30/98
%Reads a cortex image color map (i.e. .lut, lookup table)
%and returns the matlab converted image map, and the original
%cortex map. 
[f, msg] = fopen ([mapdir,mapname, '.lut'], 'r');
if f == -1
   error (msg);
end
map=fread (f, 'ushort');
values=length(map)./4;
mapmat=reshape(map,4,values)';
mapmat=mapmat(:,[1:3]);
mapmat=mapmat./255;
fclose (f);
retval = 1;
