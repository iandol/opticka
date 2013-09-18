function  out  = makedprime(dat)
set(0,'DefaultFigurePaperUnits','centimeters','DefaultFigurePaperType','A4')
r = dat.task.response;

if dat.task.nVars<4
	pos = zeros(size(r,1),1);
else
	pos = [dat.task.outValues{:,4}]';
	pos = [pos{:}]'; pos = pos(1:length(r));
end

if size(r,2) > 5
	rr = [r{:,1};r{:,2};r{:,3};r{:,4};r{:,6}]';
elseif size(r,2) > 3
	rr = [r{:,1};r{:,2};r{:,3};r{:,4}]';
	rr = [rr,pos];
else
	rr = [r{:,1};r{:,2};r{:,3}]';
	an = [dat.task.outValues{:,1}]';
	an = [an{:,1}]';
	an = an(1:length(rr));
	pos = pos(1:length(rr));
	rr = [rr, an, pos];
end

rrcongruent = rr(rr(:,2)==true,:);
rrdotsalone1 = rrcongruent(rrcongruent(:,5)~=0,:);
rrcongruent = rrcongruent(rrcongruent(:,5)==0,:);
rrincongruent = rr(rr(:,2)==false,:);
rrdotsalone2 = rrincongruent(rrincongruent(:,5)~=0,:);
rrincongruent = rrincongruent(rrincongruent(:,5)==0,:);
coherencevals = unique(rr(:,3));

rrdotsalone = [rrdotsalone1;rrdotsalone2];

for i = 1:length(coherencevals) %we step through each coherence value
	
	%--------------------------
	cValIndex = rrcongruent(rrcongruent(:,3)==coherencevals(i),:); %find congruent trials == current coherence
	
	congruentCorrect = find(rrcongruent(cValIndex,1) == true); %correct congruent trials at this coherence
	congruentIncorrect = find(rrcongruent(cValIndex,1) == false);  %incorrect congruent trials at this coherence
	
	congruentAngle1 = find(rrcongruent(cValIndex,4) == 0); %index into 0deg = right angle
	congruentAngle2 = find(rrcongruent(cValIndex,4) ~= 0); %left trials
	
	intersectpc = intersect(congruentCorrect,congruentAngle1);
	intersectpf = intersect(congruentIncorrect,congruentAngle2);
	
	cc(i) = length(congruentCorrect) / length(cValIndex);
	cpc(i) = length(intersectpc) / length(congruentAngle1);
	cpf(i) = length(intersectpf) / length(congruentAngle2);
	
	cpc(cpc==1)=0.99;
	cpc(cpc==0)=0.01;
	cpf(cpf==1)=0.99;
	cpf(cpf==0)=0.01;
	
	[cDp(i), cC(i), cnB(i), cPc(i)] = PAL_SDT_1AFC_PHFtoDP([cpc(i) cpf(i)]);
	
	%--------------------------
	incongruentIndex = find(rrincongruent(:,3) == coherencevals(i)); %find incongruent trials == current coherence
	
	incongruentCorrect = find(rrincongruent(incongruentIndex,1) == true); %correct incongruent trials at this coherence
	incongruentIncorrect = find(rrincongruent(incongruentIndex,1) == false);%incorrect incongruent trials at this coherence
	
	incongruentAngle1 = find(rrincongruent(incongruentIndex,4) == 0);
	incongruentAngle2 = find(rrincongruent(incongruentIndex,4) ~= 0);
	
	intersectpc = intersect(incongruentCorrect,incongruentAngle1);
	intersectpf = intersect(incongruentIncorrect,incongruentAngle2);
	
	ic(i) = length(incongruentCorrect) / length(incongruentIndex);
	ipc(i) = length(intersectpc) / length(incongruentAngle1);
	ipf(i) = length(intersectpf) / length(incongruentAngle2);
	
	ipc(ipc==1)=0.99;
	ipc(ipc==0)=0.01;
	ipf(ipf==1)=0.99;
	ipf(ipf==0)=0.01;
	
	[iDp(i), iC(i), inB(i), iPc(i)] = PAL_SDT_1AFC_PHFtoDP([ipc(i) ipf(i)]);
	
	%--------------------------------
	doDots = false;
	if ~isempty(rrdotsalone)
		doDots = true;
		dotsIndex = find(rrdotsalone(:,3) == coherencevals(i)); %find congruent trials == current coherence
	
		dotsCorrect = find(rrdotsalone(dotsIndex,1) == true); %correct congruent trials at this coherence
		dotsIncorrect = find(rrdotsalone(dotsIndex,1) == false);  %incorrect congruent trials at this coherence

		dotsAngle1 = find(rrdotsalone(dotsIndex,4) == 0); %index into 0deg = right angle
		dotsAngle2 = find(rrdotsalone(dotsIndex,4) > 0); %left trials

		intersectpc = intersect(dotsCorrect,dotsAngle1);
		intersectpf = intersect(dotsIncorrect,dotsAngle2);

		dc(i) = length(dotsCorrect) / length(dotsIndex);
		dpc(i) = length(intersectpc) / length(dotsAngle1);
		dpf(i) = length(intersectpf) / length(dotsAngle2);

		dpc(dpc==1)=0.99;
		dpc(dpc==0)=0.01;
		dpf(dpf==1)=0.99;
		dpf(dpf==0)=0.01;

		[dDp(i), dC(i), dnB(i), dPc(i)] = PAL_SDT_1AFC_PHFtoDP([dpc(i) dpf(i)]);
		
	end
	
end

out.vals = coherencevals';

out.cc = cc;
out.ic = ic;

out.cpc = cpc;
out.cpf = cpf;
out.ipc = ipc;
out.ipf = ipf;

out.cDp = cDp;
out.cC = cC;
out.cnB = cnB;
out.cPc = cPc;

out.iDp = iDp;
out.iC = iC;
out.inB = inB;
out.iPc = iPc;

if doDots
	out.dc = dc;
	out.dpc = dpc;
	out.dpf = dpf;
	out.dDp = dDp;
	out.dC = dC;
	out.dnB = dnB;
	out.dPc = dPc;
end

f=figure('name','DPrime Output');
set(f,'Color',[1 1 1]);
figpos(1,[1000 1000])
p=panel(f);
p.margin = 25;
p.pack(2,2);

miny = min([min(out.cDp) min(out.iDp)]);
maxy = max([max(out.cDp) max(out.iDp)]);

p(1,1).select();
plot(out.vals,out.cc*4.6527,'k-o',out.vals,out.cDp,'r-o')
if doDots
	hold on
	plot(out.vals,out.dc*4.6527,'k:*',out.vals,out.dDp,'r:*')
	hleg = legend('% Correct','d-prime','% Correct dots alone','d-prime dots alone','Location','NorthWest');
else
	hleg = legend('% Correct','d-prime','Location','NorthWest');
end
set(gca,'FontSize',16);
title(['CONGRUENT' dat.name],'Interpreter','none','FontSize',18);
axis([-inf inf miny maxy])
xlabel('Coherence')
ylabel('D-Prime / % correct')
set(hleg,'FontAngle','italic','TextColor',[.5,.4,.3],'FontSize',10)
box on
grid on

p(1,2).select();
plot(out.vals,out.cC,'k-o',out.vals,out.cnB,'r-o')
if doDots
	hold on
	plot(out.vals,out.dC,'k:*',out.vals,out.dnB,'r:*')
	hleg = legend('C bias','nB Bias','C bias dots alone','nB Bias dots alone','Location','NorthWest');
else
	hleg = legend('C bias','nB Bias','Location','NorthWest');
end
set(gca,'FontSize',16);
title(['CONGRUENT' dat.name],'Interpreter','none','FontSize',18);
xlabel('Coherence')
ylabel('BIAS')
set(hleg,'FontAngle','italic','TextColor',[.5,.4,.3],'FontSize',10)
box on
grid on

p(2,1).select();
plot(out.vals,out.ic*4.6527,'k-o',out.vals,out.iDp,'r-o')
if doDots
	hold on
	plot(out.vals,out.dc*4.6527,'k:*',out.vals,out.dDp,'r:*')
	hleg = legend('% Correct','d-prime','% Correct dots alone','d-prime dots alone','Location','NorthWest');
else
	hleg = legend('% Correct','d-prime','Location','NorthWest');
end
set(gca,'FontSize',16);
title(['INCONGRUENT' dat.name],'Interpreter','none','FontSize',18)
axis([-inf inf miny maxy])
xlabel('Coherence')
ylabel('D-Prime / % correct')
set(hleg,'FontAngle','italic','TextColor',[.5,.4,.3],'FontSize',10)
box on
grid on

p(2,2).select();
plot(out.vals,out.iC,'k-o',out.vals,out.inB,'r-o')
if doDots
	hold on
	plot(out.vals,out.dC,'k:*',out.vals,out.dnB,'r:*')
	hleg = legend('C bias','nB Bias','C bias dots alone','nB Bias dots alone','Location','NorthWest');
else
	hleg = legend('C bias','nB Bias','Location','NorthWest');
end
set(gca,'FontSize',16);
title(['INCONGRUENT' dat.name],'Interpreter','none','FontSize',18);
xlabel('Coherence')
ylabel('BIAS')
set(hleg,'FontAngle','italic','TextColor',[.5,.4,.3],'FontSize',10)
box on
grid on

end