%imgconvmakelut
%B Jagadeesh 6/30/98
%Convert a group of images in imgdirin to cortex format, placed
%in imgdirout. imgdirin & imgdirout must be set before running

%Variables to check/change for each run.
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

%Calculate lookup table from the set of images, save it
%with first file filename.
[imgAllInd,imgAllMap,imgAll]= imgrefcolors([basedir,imgdirin,'\'],imglst,128);

savfile = strcat('1',imglst(1,1:nchars-4),'-mat-lut');
img2save=' imgAllMap';
saveplace=[' ',basedir,imgdirout,'\'];
save_str = strcat('save', saveplace, savfile, img2save);
eval(save_str);

clear imgAllInd;
clear imgAll;

%Display starting conversion
disp(' ');disp(' ');disp(' ');
disp('LUT Loaded from file');
disp('Start converting images');
disp(' ');disp(' ');disp(' ');

%Convert images, using function to convert images. 
[worked,imgfailed]=imgconvfun([basedir,imgdirin,'\'],[basedir,imgdirout,'\'],imglst,namestart,ndstart,imgAllMap,128);
