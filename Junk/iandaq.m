function [data,time]=iandaq

if (~isempty(daqfind))
    stop(daqfind)
end

%analog input
ai = analoginput('nidaq','Dev1');
set(ai,'InputType','Differential');
set(ai,'TriggerType','Immediate');
set(ai,'SampleRate',2000);
ActualRate = get(ai,'SampleRate');
set(ai,'SamplesPerTrigger',inf);
chans = addchannel(ai,0:1);

%digital input/output
dio = digitalio('nidaq','Dev1');
hwlines = addline(dio,0:7,'out');
dio.Line(1).LineName = 'TrigLine';

preview = ActualRate/4;
figure;
subplot(221);
set(gcf,'doublebuffer','on');
P = plot(zeros(preview,2)); grid on
title('Preview Data');
xlabel('Samples');
ylabel('Signal Level (Volts)');
drawnow;

loopt=1010;
switchtime=0.01;
times=zeros(loopt,1);
i=1;
peeklimit=ai.SampleRate/5;
a=1;

try
	while(i<loopt)
		tstamp=GetSecs;
		if i==1; start(ai); end
		if getvalue(dio.Line(1))==0
			putvalue(dio.Line(1),1);
		else
			putvalue(dio.Line(1),0);
		end
		if ai.SamplesAcquired>=(peeklimit*a)
			data = peekdata(ai,peeklimit);
			for j=1:length(P)
				set(P(j),'ydata',data(:,j)');
			end
			drawnow;
			a=a+1;
		end
		tloc=GetSecs-tstamp;
		waitt=switchtime-tloc;
		if waitt>0
			WaitSecs(waitt);
		end
		times(i)=GetSecs-tstamp;
		i=i+1;
 	end
	stop(ai);
	[data,time]=getdata(ai,ai.SamplesAvailable);

	subplot(222);
	plot(time,data);
	%times=times(1:1009);
	subplot(223);
	plot(times,'k.');
	axis tight;
	subplot(224);
	histfit(times);
	[m,e]=stderr(times);
	title(['Mean loop=' num2str(m) ' +- ' num2str(e)]);
	
	delete(ai);
	clear ai;

	putvalue(dio,[0 0 0 0 0 0 0 0]);
	delete(dio);
	clear dio;
catch ME
	delete(ai);
	clear ai;

	putvalue(dio,[0 0 0 0 0 0 0 0]);
	delete(dio);
	clear dio;
	
	rethrow(ME);
end