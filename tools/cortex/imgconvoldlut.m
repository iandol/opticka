%imgconvoldlut
%B Jagadeesh 6/30/98
%Convert a group of images in imgdirin to cortex format. Use
%a predetermined lookup table. imgdirin and imgdirout must be preset. 
%as well as a file, as lutname, from which to load the lut (with name from c:\matlab\). 

%Variables to check/change for each run.
lutfile='ctximg-mat\1mnalln-mat-lut'
imgdirin='imgin'
imgdirout='imgout'
threelettercode='bbb';startindex=100;
basedir='c:\matlab\';

%Get list of images from directory
imglst=make_file_list(strcat(basedir,imgdirin,'\*.tif'));
imglst2=make_file_list(strcat(basedir,imgdirin,'\*.jpg'));
imglst=strvcat(imglst,imglst2);
imglst=sortrows(imglst);

%Number of images, and the characters in the maximum filename
[nimgs,nchars]=size(imglst);

%If filenames aren't DOS compatible, rename based on index of three letter, 
%number, starting with 100. 
if nchars>12
   disp('files need to be renamed');
   namestart = threelettercode
   ndstart = startindex 
else
   namestart='no';
   ndstart=0;
end

%Load in the file with the lookup table, saved in matlab format
load([basedir,lutfile]);

clear imgAll;
clear imgAllInd;

%Display starting conversion
disp(' ');disp(' ');disp(' ');
disp('LUT Loaded from file');
disp('Start converting images');
disp(' ');disp(' ');disp(' ');

%Convert images, using function to convert images. 
[worked,imgfailed]=imgconvfun([basedir,imgdirin,'\'],[basedir,imgdirout,'\'],imglst,namestart,ndstart,imgAllMap,128);
