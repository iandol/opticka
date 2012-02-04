function [imgAllInd,imgAllMap,imgAll]= imgrefcolors(imgdir,imglst,ncolors);
%function [imgAllInd,imgAllMap,imgAll]= imgrefcolors(imgdir,imglst,ncolors);
%B Jagadeesh 6/30/98
%Takes a list of images from a directory (or a list from a variable)
%concatenates the image, and gets the lookup table for that image
%with a smaller number of colors, and the indexed image. Images
%used must all be the same size. 
imgheightAll=[];
imgwidthAll=[];

if nargin ==1
   imglst=make_file_list(strcat(imgdir,'*.tif'));
   tmplst=make_file_list(strcat(imgdir,'*.jpg'));
   imglst=strvcat(imglst,tmplst);
   ncolors=128
end

if nargin ==2
   ncolors=128
end

imgRed=[];imgGreen=[];imgBlue=[];imgAll=[];
[nimgs,nchars]=size(imglst);

for ii=1:nimgs
   imgtoload=strcat(imgdir,imglst(ii,:));
   imgload=imread(imgtoload);
   [imgheight,imgwidth,colurs]=size(imgload);
   imgheightAll=[imgheightAll;imgheight];
   imgwidthAll=[imgwidthAll;imgwidth];
end

imgheightmin=min(imgheightAll);
imgwidthmin=min(imgwidthAll);

for ii=1:nimgs
      imgtoload=strcat(imgdir,imglst(ii,:));
      imgload=imread(imgtoload);
      imgcropped=imgload([1:imgheightmin],[1:imgwidthmin],:);
      imgRed=[imgRed;imgcropped(:,:,1)];
      imgGreen=[imgGreen;imgcropped(:,:,2)];
      imgBlue=[imgBlue;imgcropped(:,:,3)];
end

imgAll(:,:,1)=imgRed;imgAll(:,:,2)=imgGreen;imgAll(:,:,3)=imgBlue;

%Finds the 128 colors in the image
[imgAllInd,imgAllMap]=rgb2ind(imgAll,ncolors,'no dither');
