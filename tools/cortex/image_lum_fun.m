function [lum1,lumsum]=image_lum_fun(RGB)
%function [lum,lumsum]=image_lum_fun(RGB)
%B Jagadeesh
%6/25/98
%Altered into a function. 
%May 20, 1998

RGBdouble=double(RGB);

rred=sum(sum(RGBdouble(:,:,1).*RGBdouble(:,:,1)));
rgreen=sum(sum(RGBdouble(:,:,2).*RGBdouble(:,:,2)));
rblue=sum(sum(RGBdouble(:,:,3).*RGBdouble(:,:,3)));
lum1=sqrt(rred+rgreen+rblue);

rred=RGBdouble(:,:,1).*RGBdouble(:,:,1);
rgreen=RGBdouble(:,:,2).*RGBdouble(:,:,2);
rblue=RGBdouble(:,:,3).*RGBdouble(:,:,3);
lum=sqrt(rred+rgreen+rblue);
lumsum=sum(sum(lum));
