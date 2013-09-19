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
	cohValIndex = rrcongruent(rrcongruent(:,3)==coherencevals(i),:); %find congruent trials == current coherence
	
	congruentCorrect = find(cohValIndex(:,1) == true); %correct congruent trials at this coherence
	congruentIncorrect = find(cohValIndex(:,1) == false);  %incorrect congruent trials at this coherence
	
	congruentAngle1 = find(cohValIndex(:,4) == 0); %index into 0deg = right angle
	congruentAngle2 = find(cohValIndex(:,4) ~= 0); %left trials
	
	congruentHit0 = intersect(congruentCorrect,congruentAngle1);
	congruentHit180 = intersect(congruentCorrect,congruentAngle2);
	congruentHit = [congruentHit0; congruentHit180];
	conFalseAlarm0 = intersect(congruentIncorrect,congruentAngle1);
	conFalseAlarm180 = intersect(congruentIncorrect,congruentAngle2);
	conFalseAlarm = [conFalseAlarm0; conFalseAlarm180];
	congruentLength = length(cohValIndex);
	
	intersectpc = congruentHit0;
	pclength = length(congruentAngle1);
	intersectpf = conFalseAlarm180;
	pflength = length(congruentAngle2);
	
	cc(i) = length(congruentCorrect) / congruentLength;
	cpc(i) = length(intersectpc) / pclength;
	cpf(i) = length(intersectpf) / pflength;
	
	cpc(cpc==1)=0.99;
	cpc(cpc==0)=0.01;
	cpf(cpf==1)=0.99;
	cpf(cpf==0)=0.01;
	
	[cDp(i), cC(i), cnB(i), cPc(i)] = PAL_SDT_1AFC_PHFtoDP([cpc(i) cpf(i)]);
	
	%--------------------------
	cohValIndex = rrincongruent(rrincongruent(:,3)==coherencevals(i),:); %find incongruent trials == current coherence
	
	incongruentCorrect = find(cohValIndex(:,1) == true); %correct incongruent trials at this coherence
	incongruentIncorrect = find(cohValIndex(:,1) == false);%incorrect incongruent trials at this coherence
	
	incongruentAngle1 = find(cohValIndex(:,4) == 0);
	incongruentAngle2 = find(cohValIndex(:,4) ~= 0);
	
	incongrunetHit0 = intersect(incongruentCorrect,incongruentAngle1);
	incongruentHit180 = intersect(incongruentCorrect,incongruentAngle2);
	incongruentHit = [incongrunetHit0; incongruentHit180];
	inconFalseAlarm0 = intersect(incongruentIncorrect,incongruentAngle1);
	inconFalseAlarm180 = intersect(incongruentIncorrect,incongruentAngle2);
	inconFalseAlarm = [inconFalseAlarm0; inconFalseAlarm180];
	incongruentLength = length(cohValIndex);
	
	intersectpc = incongrunetHit0;
	intersectpf = inconFalseAlarm180;
	
	ic(i) = length(incongruentCorrect) / incongruentLength;
	ipc(i) = length(intersectpc) / length(incongruentAngle1);
	ipf(i) = length(intersectpf) / length(incongruentAngle2);
	
	ipc(ipc==1)=0.99;
	ipc(ipc==0)=0.01;
	ipf(ipf==1)=0.99;
	ipf(ipf==0)=0.01;
	
	[iDp(i), iC(i), inB(i), iPc(i)] = PAL_SDT_1AFC_PHFtoDP([ipc(i) ipf(i)]);
	
	%--------------------------------
	%Stewarts congruent hit vs incongruent false alarms
	intersectpc = congruentHit;
	pclength = congruentLength;
	intersectpf = inconFalseAlarm;
	pflength = incongruentLength;
	
	pc(i) = length(intersectpc) / pclength;
	pf(i) = length(intersectpf) / pflength;
	
	pc(pc==1)=0.99;
	pc(pc==0)=0.01;
	pf(pf==1)=0.99;
	pf(pf==0)=0.01;
	
	[sDp(i), sC(i), snB(i), sPc(i)] = PAL_SDT_1AFC_PHFtoDP([pc(i) pf(i)]);
	
	%--------------------------------
	%all congruent
	intersectpc = congruentHit;
	pclength = congruentLength;
	intersectpf = conFalseAlarm;
	pflength = congruentLength;
	
	pc(i) = length(intersectpc) / pclength;
	pf(i) = length(intersectpf) / pflength;
	
	pc(pc==1)=0.99;
	pc(pc==0)=0.01;
	pf(pf==1)=0.99;
	pf(pf==0)=0.01;
	
	[ccDp(i), ccC(i), ccnB(i), ccPc(i)] = PAL_SDT_1AFC_PHFtoDP([pc(i) pf(i)]);
	
	%--------------------------------
	%all incongruent
	intersectpc = incongruentHit;
	pclength = incongruentLength;
	intersectpf = inconFalseAlarm;
	pflength = incongruentLength;
	
	pc(i) = length(intersectpc) / pclength;
	pf(i) = length(intersectpf) / pflength;
	
	pc(pc==1)=0.99;
	pc(pc==0)=0.01;
	pf(pf==1)=0.99;
	pf(pf==0)=0.01;
	
	[icDp(i), icC(i), icnB(i), icPc(i)] = PAL_SDT_1AFC_PHFtoDP([pc(i) pf(i)]);
	
	%--------------------------------
	doDots = false;
	if ~isempty(rrdotsalone)
		doDots = true;
		cohValIndex = rrdotsalone(rrdotsalone(:,3) == coherencevals(i),:); %find congruent trials == current coherence
	
		dotsCorrect = find(cohValIndex(:,1) == true); %correct congruent trials at this coherence
		dotsIncorrect = find(cohValIndex(:,1) == false);  %incorrect congruent trials at this coherence

		dotsAngle1 = find(cohValIndex(:,4) == 0); %index into 0deg = right angle
		dotsAngle2 = find(cohValIndex(:,4) > 0); %left trials

		dotshit0 = intersect(dotsCorrect,dotsAngle1);
		dotshit180 = intersect(dotsCorrect,dotsAngle2);
		dotshit = [dotshit0;dotshit180];
		dotsfalsealarm0 = intersect(dotsIncorrect,dotsAngle1);
		dotsfalsealarm180 = intersect(dotsIncorrect,dotsAngle2);
		dotsfalsealarm = [dotsfalsealarm0; dotsfalsealarm180];

		intersectpc = dotshit0;
		intersectpf = dotsfalsealarm180;
		
		dc(i) = length(dotsCorrect) / length(cohValIndex);
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

out.div1 = 'CONGRUENT';
out.cc = cc;
out.cpc = cpc;
out.cpf = cpf;
out.cDp = cDp;
out.cC = cC;
out.cnB = cnB;
out.cPc = cPc;

out.div2 = 'INCONGRUENT';
out.ic = ic;
out.ipc = ipc;
out.ipf = ipf;
out.iDp = iDp;
out.iC = iC;
out.inB = inB;
out.iPc = iPc;

out.div3 = 'DOTSALONE';
if doDots
	out.dc = dc;
	out.dpc = dpc;
	out.dpf = dpf;
	out.dDp = dDp;
	out.dC = dC;
	out.dnB = dnB;
	out.dPc = dPc;
end

out.div4 = 'COMBINE';
out.spc = pc;
out.spf = pf;
out.sDp = sDp;
out.sC = sC;
out.snB = snB;
out.sPc = sPc;

out.div5 = 'ALLCONGRUENT';
out.ccDp = ccDp;
out.ccC = ccC;
out.ccnB = ccnB;
out.ccPc = ccPc;

out.div6 = 'ALLINCONGRUENT';
out.icDp = icDp;
out.icC = icC;
out.icnB = icnB;
out.icPc = icPc;

%---------------------------------------------------------------------------

f=figure('name','DPrime Output');
set(f,'Color',[1 1 1]);
figpos(1,[1000 1000])
p=panel(f);
p.margin = 25;
p.pack(2,3);

miny = min([min(out.cDp) min(out.iDp)]);
maxy = max([max(out.cDp) max(out.iDp)]);

p(1,1).select();
plot(out.vals,out.cc,'k-o',out.vals,out.cDp,'r-o')
if doDots
	hold on
	plot(out.vals,out.dc,'k:*',out.vals,out.dDp,'r:*')
	hleg = legend('% Correct','d-prime','% Correct dots alone','d-prime dots alone','Location','SouthEast');
else
	hleg = legend('% Correct','d-prime','Location','SouthEast');
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
	hleg = legend('C bias','nB Bias','C bias dots alone','nB Bias dots alone','Location','SouthEast');
else
	hleg = legend('C bias','nB Bias','Location','SouthEast');
end
set(gca,'FontSize',16);
title(['CONGRUENT' dat.name],'Interpreter','none','FontSize',18);
xlabel('Coherence')
ylabel('BIAS')
set(hleg,'FontAngle','italic','TextColor',[.5,.4,.3],'FontSize',10)
box on
grid on

p(2,1).select();
plot(out.vals,out.ic,'k-o',out.vals,out.iDp,'r-o')
if doDots
	hold on
	plot(out.vals,out.dc,'k:*',out.vals,out.dDp,'r:*')
	hleg = legend('% Correct','d-prime','% Correct dots alone','d-prime dots alone','Location','SouthEast');
else
	hleg = legend('% Correct','d-prime','Location','SouthEast');
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
	hleg = legend('C bias','nB Bias','C bias dots alone','nB Bias dots alone','Location','SouthEast');
else
	hleg = legend('C bias','nB Bias','Location','SouthEast');
end
set(gca,'FontSize',16);
title(['INCONGRUENT' dat.name],'Interpreter','none','FontSize',18);
xlabel('Coherence')
ylabel('BIAS')
set(hleg,'FontAngle','italic','TextColor',[.5,.4,.3],'FontSize',10)
box on
grid on

p(1,3).select();
plot(out.vals,out.sPc,'k-o',out.vals,out.sDp,'r-o')
if doDots
	hold on
	plot(out.vals,out.dc,'k:*',out.vals,out.dDp,'r:*')
	hleg = legend('% Correct','d-prime','% Correct dots alone','d-prime dots alone','Location','SouthEast');
else
	hleg = legend('% Correct','d-prime','Location','SouthEast');
end
set(gca,'FontSize',16);
title(['COMBINE' dat.name],'Interpreter','none','FontSize',18)
axis([-inf inf miny maxy])
xlabel('Coherence')
ylabel('D-Prime / % correct')
set(hleg,'FontAngle','italic','TextColor',[.5,.4,.3],'FontSize',10)
box on
grid on

p(2,3).select();
plot(out.vals,out.sC,'k-o',out.vals,out.snB,'r-o')
if doDots
	hold on
	plot(out.vals,out.dC,'k:*',out.vals,out.dnB,'r:*')
	hleg = legend('C bias','nB Bias','C bias dots alone','nB Bias dots alone','Location','SouthEast');
else
	hleg = legend('C bias','nB Bias','Location','SouthEast');
end
set(gca,'FontSize',16);
title(['COMBINE' dat.name],'Interpreter','none','FontSize',18);
xlabel('Coherence')
ylabel('BIAS')
set(hleg,'FontAngle','italic','TextColor',[.5,.4,.3],'FontSize',10)
box on
grid on


end