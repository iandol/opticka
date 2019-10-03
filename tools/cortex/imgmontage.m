function [monthandle,movfig,allimgs,maptoapply, allmov]=imgmontage(basedir,imdirin);
%function [monthandle,movfig,allimgs,maptoapply, allmov]=imgmontage(basedir,imdirin);
%B Jagadeesh 7/2/98
%Concatenates the images in imgdirin into frames, and then
%displays a montage; if the images are already in indexed 
%format, also displays a movie.

%Warnings about TIFF files turned off

warning off

%Define image directory
%basedir='c:\matlab\';
imgdircomp=[basedir,imdirin,'\'];
imgnew=make_file_list([imgdircomp,'*.tif*']);
imgnew=sortrows(imgnew);

%Get lookup table name, if there is one. If the files
%have been saved in indexed format, the lookup table 
%should have been saved as imgAllMap, with the extension 
%'.mat'.
maptoappfile=make_file_list([imgdircomp,'*.mat']);

[nimgs,trsh]=size(imgnew);

montfig=figure;
set(montfig,'Position',[30    10   850   750]);

for i=1:nimgs
   tempopen=strcat(imgdircomp,imgnew(i,:));
	allimgs(:,:,:,i)=imread(tempopen);
end

if isempty(maptoappfile)
   monthandle=montage(allimgs);
temp=strcat(strrep(imdirin,'\','-'),'-',imgnew(1,:),'-',date);
toptitle(temp);
end
   
if ~isempty(maptoappfile)
   load([imgdircomp,maptoappfile]);
   maptoapply=imgAllMap;
   monthandle=montage(allimgs,maptoapply);
   temp=strcat(strrep(imdirin,'\','-'),'-',imgnew(1,:),'-',date,'-',maptoappfile);
	toptitle(temp);
end


if ~isempty(maptoappfile)
   movfig=figure
   set(movfig,'Position',[965 48 128 128]);
   %Make movie from indexed image. 
   allmov=immovie(allimgs,maptoapply);
   %Display movie
   movie(allmov,-3,20);
   end
warning on

