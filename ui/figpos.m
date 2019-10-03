function figpos(position,size,mult)

oldunits = get(gcf,'Units');
set(gcf,'Units','pixels');


if nargin<1 || isempty(position);
	position=1;
end
if nargin<2 || isempty(size);
	pos=get(gcf,'Position');
	size=[pos(3) pos(4)];
end
if nargin < 3
	mult=1;
end

if mult ~=1
	size = size .* mult;
end

oldsunits = get(0,'Units');
set(0,'Units','pixels');
scr=get(0,'ScreenSize');
width=scr(3);
height=scr(4);
set(0,'Units',oldsunits);

if size(1) > width;	size(1) = width;	end
if size(2) > height;	size(2) = height;	end

switch(position)
case 2 %a third off
	x=(width/3)-(size(1)/2);
	y=(height/2)-(size(2)/2);
	if x < 1; x=0; end
	if y < 1; y=0; end
	set(gcf,'Position',[x y size(1) size(2)]);
case 3 %full height
	size(2) = height;
	x=(width/2)-(size(1)/2);
	y=(height/2)-(size(2)/2);
	if x < 1; x=0; end
	if y < 1; y=0; end
	set(gcf,'Position',[x y size(1) size(2)]);
case 4 %full width
	size(1) = width;
	x=(width/3)-(size(1)/2);
	y=(height/2)-(size(2)/2);
	if x < 1; x=0; end
	if y < 1; y=0; end
	set(gcf,'Position',[x y size(1) size(2)]);
case 5 %full screen
	size(1) = width;
	size(2) = height;
	x=(width/3)-(size(1)/2);
	y=(height/2)-(size(2)/2);
	if x < 1; x=0; end
	if y < 1; y=0; end
	set(gcf,'Position',[x y size(1) size(2)]);
case 6 %top of screen
	x=(width/2)-(size(1)/2);
	y=(height)-((size(2)+40)/2);
	if x < 1; x=0; end
	if y < 1; y=0; end
	set(gcf,'Position',[x y size(1) size(2)]);
otherwise %center it
	x=(width/2)-(size(1)/2);
	y=(height/2)-((size(2)+40)/2);
	if x < 1; x=0; end
	if y < 1; y=0; end
	set(gcf,'Position',[x y size(1) size(2)]);
end
set(gcf,'Units',oldunits);