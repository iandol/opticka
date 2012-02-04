function [status] = WriteLut(filename,mat)
%
%  Writes to disk an LUT in a format that Cortex can read.
%  A return value of '0' means it worked, '-1' means it didn't.
%
%
%
%  function [status] = WriteLut(filename,mat)
%
%  GDLH 8/17/00

if (size(mat,2) ~= 3)
   if (size(mat,1) ~= 3)
      error('LUT argument has neither 3 rows nor 3 columns')
   else
      mat = mat';
   end
end

mat = [mat, zeros(size(mat,1),1)];  % Padding with zeros for Cortex

status = 0;
fid = fopen([filename,'.lut'],'w');
if (fid == -1)
   status = -1;
else
   count = fwrite(fid,mat','int16');
   if (count ~= length(mat(:)))
      status = -1;
   else
      status = fclose(fid);
   end
end
