function [worked,imgfailed]=imgconvfun(imgdir,imgdirout,imglst,ff,ffi,maptoapply,offset);
%function [worked,imgfailed]=imgconvfun(imgdir,imgdirout,imglst,maptoapply,offset);
%B Jagadeesh 6/30/98
%Convert a group of images, in imglst, using a
%predeterimined lookup table. If the image names
%in the input directory are > 8+3 characters, 
%the output names will be renamed

imgfailed=[];
set_up_page;
[nimgs,nchars]=size(imglst);

for ii=1:nimgs
   imgtoload=strcat(imgdir,imglst(ii,:));
   imgrgb=imread(imgtoload);

   if strcmp(ff,'no');
      imgout=strcat(imgdirout,imglst(ii,1:nchars-4));
   else
      imgout=strcat(imgdirout,ff,sprintf('%3.0f',ffi+ii-1));
   end
   
   [imgInd]=rgb2ind(imgrgb,maptoapply,'no dither');
   subplot(1,2,1), subimage(imgrgb)
   subplot(1,2,2), subimage(imgInd,maptoapply)
   drawnow
   temp=strcat(sprintf('input %s output %s',imglst(ii,:),[ff,sprintf('%3.0f',ffi+ii-1),'.ctx']));
   disp(temp);disp(' ');
   
   worked=im2cort (imgInd, maptoapply, imgout, offset);
   if worked ~=1
      imgfailed=strvcat(imgfailed,imglst(ii,:));
   end
end

