%imgprocess
%B Jagadeesh 6/30/98
%7/2/98 Added more processes.
%Process a list of images, including renaming, 
%cropping, histogram equalization. Another script to
%write would be one that applied a parametric manipulation
%of a single image, i.e. different orientations, different
%brightnesses, etc. 

%Zero variables
imglst=[];

warning off

%Variables to check/change for each run.
%Image directories
imgdirin='imgraw'
imgdirout='imgin'
basedir='c:\matlab\';

%List of processes that will be run.
proccesstodo='rl';

%s = resize; 
%c = crop; 
%t = turn (rotate image)
%q = histogram equalize; 
%m = apply predetermined lookup table.
%l = lookup table, generate.
%r = rename; 


%Parameters for different processes
%s = resize
heightsize=75;widthsize=75;

%c = crop (Values must be less than resize, if resize is set; must be less
%than size of iamge). 
maxheight=90;maxwidth=90;

%turn
turnangle=20;

%q = histogram equalize

%r = rename, 
threelettercode='gab';startindex=101;

%m = apply predetermined lookuptable
if ~isempty(findstr('m',proccesstodo));
   maptablename='1mnalln-mat-lut.mat';
	load(['c:\matlab\ctximg-mat\',maptablename]);
	clear imgAll;imgAllInd;
   maptoapply=imgAllMap;
   lookuptype=sprintf('preloaded from %s ',maptablename);
end

%----------------------------------

%Make pages for displaying images:
beforefig=figure;
set(beforefig,'Position', [772 535 128 128])
afterfig=figure;
set(afterfig,'Position',[937 535 128 128])

%----------------------------------

%Get list of images from directory
%imglst=make_file_list(strcat(basedir,imgdirin,'\*.tif'));
%imglst2=make_file_list(strcat(basedir,imgdirin,'\*.jpg'));
imglst3=make_file_list(strcat(basedir,imgdirin,'\*'));
[trsh1,trsh2]=size(imglst3);
imglst3=imglst3([3:trsh1],:);

%imglst=strvcat(imglst,imglst2,imglst3);
imglst=sortrows(imglst3);


%Number of images, and the characters in the maximum filename
[nimgs,nchars]=size(imglst);

%-----------------------------------

%l = lookuptable
if ~isempty(findstr('l',proccesstodo));
[imgAllInd,imgAllMap,imgAll]= imgrefcolors([basedir,imgdirin,'\'],imglst,128);
clear imgAllInd;
clear imgAll;
maptoapply=imgAllMap;
lookuptype='custom for set of images';
end

%Save lookuptable with name of first image in imglst if 
%a lookup table is being applyed. This is necessary 
if ~isempty([findstr('l',proccesstodo),findstr('m',proccesstodo)]);
ff=findstr('.',imglst(1,:));
savfile = strcat('1',imglst(1,1:ff-1),'-mat-lut');
saveplace=[' ',basedir,imgdirout,'\'];
img2save=' imgAllMap lookuptype';
save_str = strcat('save', saveplace, savfile, img2save);
eval(save_str);
end

%-----------------------------------
%Loop through images
for ii=1:nimgs
   imgtoload=strcat(basedir,'\',imgdirin,'\',imglst(ii,:));
   imgrgb=imread(imgtoload);
   imgrgbOut=imgrgb;
   
   %ReSize image, if 's' was in process. 
   if ~isempty(findstr('s',proccesstodo));
      imgrgbOut=imresize(imgrgbOut,[heightsize,widthsize],'bilinear');
   end
   
      
   %Crop image, if 'c' was in process. 
   if ~isempty(findstr('c',proccesstodo));
      temp(:,:,1)=imgrgbOut([1:maxheight],[1:maxwidth],1);
      temp(:,:,2)=imgrgbOut([1:maxheight],[1:maxwidth],2);
      temp(:,:,3)=imgrgbOut([1:maxheight],[1:maxwidth],3);
		imgrgbOut=temp;
   end
   
   %Turn image, if 't' was in process. 
   if ~isempty(findstr('t',proccesstodo));
      imgrgbOut=imrotate(imgrgbOut,turnangle);
   end

   %Equalize image, if 1' was in process. 
   if ~isempty(findstr('q',proccesstodo));
      imgrgbOut=histeq(imgrgbOut);
   end
   
   %reduce lookup table, if 'l' was in process or if 'm' was in process. 
   if ~isempty([findstr('l',proccesstodo),findstr('m',proccesstodo)]);
      [imgrgbOut]=rgb2ind(imgrgbOut,maptoapply,'no dither');
   end
   
   %rename images
   if ~isempty(findstr('r',proccesstodo));
      imgname=strcat(threelettercode,sprintf('%3.0f',startindex+ii-1));
   	imgout=strcat(basedir,imgdirout,'\',threelettercode,sprintf('%3.0f',startindex+ii-1),'.tif');
	else
      imgname=strcat(imglst(ii,1:nchars-4));
      imgout=strcat(basedir,imgdirout,'\',imglst(ii,:));
	end
   
   %Display file names converted to command window
   temp=strcat(sprintf('input %s output %s',imglst(ii,:),imgname));
	disp(temp);disp(' ');
   
   %Draw input & output images
	figure(beforefig)
   imshow(imgrgb);
   truesize;
   
   figure(afterfig)
   if ~isempty([findstr('l',proccesstodo),findstr('m',proccesstodo)]);
      imshow(imgrgbOut,maptoapply)
   else
      imshow(imgrgbOut)
   end
   truesize;
   drawnow
   
   %Write output image
	imwrite(imgrgbOut,imgout,'tiff');

end

warning on