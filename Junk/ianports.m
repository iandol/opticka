function ianports

dio = digitalio('nidaq','Dev1');
hwlines = addline(dio,0:7,'out');
dio.Line(1).LineName = 'TrigLine';
portval = getvalue(dio);
putvalue(dio,[0 0 0 0 0 0 0 0]);

i=1;

loops=1000;

times=zeros(loops);

while(i<loops)
	timestamp=GetSecs;
	if getvalue(dio.Line(1))==1
		putvalue(dio.Line(1),0)
	else
		putvalue(dio.Line(1),1)
	end
	times(i)=GetSecs-timestamp; 
	i=i+1;
end

figure;
times=times/1000;
plot(times);
title('Raw times for the loop');
putvalue(dio,[0 0 0 0 0 0 0 0]);
delete(dio)
clear dio