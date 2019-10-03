function retval = im2cort (m, map, filename, offset)

if ~isind(m)
   error ('Image must be idexed');
end

[Xsize Ysize] = size (m);
[values channels] = size (map);
header  = '000000000000';
ammappa = 0;  % What is this value?

if values > 128
   warning ('are you sure you want more than 128 lut values?');
end
if channels ~= 3
   error ('invalid lut');
end

[f, msg] = fopen ([filename, '.ctx'], 'w');
if f == -1
   error (msg);
end

moff = double(m') + offset;

if ~isempty (find (moff<128)) or ~isempty (find(moff>255))
   error ('something wrong with the lut values');
end

fwrite (f, header);
fwrite (f, Xsize,  'ushort');
fwrite (f, Ysize,  'ushort');
fwrite (f, ammappa,'ushort');
fwrite (f, moff,   'uchar');
fclose (f);

[f, msg] = fopen ([filename, '.lut'], 'w');
if f == -1
   error (msg);
end

mapi = round (map * 255);
mapi (values, 4)=0;
for i=1:values
   fwrite (f, mapi (i,:), 'ushort');
end

fclose (f);
retval = 1;