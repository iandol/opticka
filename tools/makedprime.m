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

out.totalCongruent = rrcongruent;
out.totalIncongruent = rrincongruent;
out.totalDotsAlone = rrdotsalone;

for i = 1:length(coherencevals) %we step through each coherence value
	
	%--------------------------
	cohValIndex = rrcongruent(rrcongruent(:,3)==coherencevals(i),:); %find congruent trials == current coherence
	
	out.coh.CongruentLength(i) = length(cohValIndex);
	
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
	
	cc(i) = length(congruentCorrect) / congruentLength;
	intersectpc = congruentHit0;
	pclength = length(congruentAngle1);
	intersectpf = conFalseAlarm180;
	pflength = length(congruentAngle2);
	cpc(i) = length(intersectpc) / pclength;
	cpf(i) = length(intersectpf) / pflength;
	
	cpc(cpc==1)=0.99; cpc(cpc==0)=0.01; cpf(cpf==1)=0.99; cpf(cpf==0)=0.01;
	
	[cDp(i), cC(i), cnB(i), cPc(i)] = PAL_SDT_1AFC_PHFtoDP([cpc(i) cpf(i)]);
	
	out.coh.CongruentCorrect(i) = length(congruentCorrect);
	out.coh.congruentHit0(1,i)  = length(congruentHit0);
	out.coh.congruentHit0(2,i)  = length(congruentAngle1);
	out.coh.congruentHit180(1,i)  = length(congruentHit180);
	out.coh.congruentHit180(2,i)  = length(congruentAngle2);
	%--------------------------
	cohValIndex = rrincongruent(rrincongruent(:,3)==coherencevals(i),:); %find incongruent trials == current coherence
	
	out.coh.IncongruentLength(i) = length(cohValIndex);
	
	incongruentCorrect = find(cohValIndex(:,1) == true); %correct incongruent trials at this coherence
	incongruentIncorrect = find(cohValIndex(:,1) == false);%incorrect incongruent trials at this coherence
	
	incongruentAngle1 = find(cohValIndex(:,4) == 0);
	incongruentAngle2 = find(cohValIndex(:,4) ~= 0);
	
	incongruentHit0 = intersect(incongruentCorrect,incongruentAngle1);
	incongruentHit180 = intersect(incongruentCorrect,incongruentAngle2);
	incongruentHit = [incongruentHit0; incongruentHit180];
	inconFalseAlarm0 = intersect(incongruentIncorrect,incongruentAngle1);
	inconFalseAlarm180 = intersect(incongruentIncorrect,incongruentAngle2);
	inconFalseAlarm = [inconFalseAlarm0; inconFalseAlarm180];
	incongruentLength = length(cohValIndex);
	
	intersectpc = incongruentHit0;
	intersectpf = inconFalseAlarm180;
	
	ic(i) = length(incongruentCorrect) / incongruentLength;
	ipc(i) = length(intersectpc) / length(incongruentAngle1);
	ipf(i) = length(intersectpf) / length(incongruentAngle2);
	
	ipc(ipc==1)=0.99; ipc(ipc==0)=0.01; ipf(ipf==1)=0.99; ipf(ipf==0)=0.01;
	
	[iDp(i), iC(i), inB(i), iPc(i)] = PAL_SDT_1AFC_PHFtoDP([ipc(i) ipf(i)]);
	
	out.coh.IncongruentCorrect(i) = length(incongruentCorrect);
	out.coh.incongruentHit0(1,i)  = length(incongruentHit0);
	out.coh.incongruentHit0(2,i)  = length(incongruentAngle1);
	out.coh.incongruentHit180(1,i)  = length(incongruentHit180);
	out.coh.incongruentHit180(2,i)  = length(incongruentAngle2);
	
	%--------------------------------
	%Stewarts congruent hit vs incongruent false alarms
	intersectpc = congruentHit;
	pclength = congruentLength;
	intersectpf = inconFalseAlarm;
	pflength = incongruentLength;
	
	pc(i) = length(intersectpc) / pclength;
	pf(i) = length(intersectpf) / pflength;
	
	pc(pc==1)=0.99;	pc(pc==0)=0.01;	pf(pf==1)=0.99;	pf(pf==0)=0.01;
	
	[sDp(i), sC(i), snB(i), sPc(i)] = PAL_SDT_1AFC_PHFtoDP([pc(i) pf(i)]);
	
	%--------------------------------
	%all congruent
	intersectpc = congruentHit;
	pclength = congruentLength;
	intersectpf = conFalseAlarm;
	pflength = congruentLength;
	
	pc(i) = length(intersectpc) / pclength;
	pf(i) = length(intersectpf) / pflength;
	
	pc(pc==1)=0.99; pc(pc==0)=0.01; pf(pf==1)=0.99; pf(pf==0)=0.01;
	
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
	
		out.coh.DotsAloneLength(i) = length(cohValIndex);
		
		dotsCorrect = find(cohValIndex(:,1) == true); %correct congruent trials at this coherence
		dotsIncorrect = find(cohValIndex(:,1) == false);  %incorrect congruent trials at this coherence

		dotsAngle1 = find(cohValIndex(:,4) == 0); %index into 0deg = right angle
		dotsAngle2 = find(cohValIndex(:,4) > 0); %left trials

		dotsHit0 = intersect(dotsCorrect,dotsAngle1);
		dotsHit180 = intersect(dotsCorrect,dotsAngle2);
		dotsHit = [dotsHit0;dotsHit180];
		dotsFalseAlarm0 = intersect(dotsIncorrect,dotsAngle1);
		dotsFalseAlarm180 = intersect(dotsIncorrect,dotsAngle2);
		dotsFalseAlarm = [dotsFalseAlarm0; dotsFalseAlarm180];
		dotsLength = length(cohValIndex);

		intersectpc = dotsHit0;
		intersectpf = dotsFalseAlarm180;
		
		dc(i) = length(dotsCorrect) / length(cohValIndex);
		dpc(i) = length(intersectpc) / length(dotsAngle1);
		dpf(i) = length(intersectpf) / length(dotsAngle2);

		dpc(dpc==1)=0.99; dpc(dpc==0)=0.01; dpf(dpf==1)=0.99; dpf(dpf==0)=0.01;

		[dDp(i), dC(i), dnB(i), dPc(i)] = PAL_SDT_1AFC_PHFtoDP([dpc(i) dpf(i)]);
		
		out.coh.DotsAloneCorrect(i) = length(dotsCorrect);
		out.coh.dotsHit0(1,i)  = length(dotsHit0);
		out.coh.dotsHit0(2,i)  = length(dotsAngle1);
		out.coh.dotsHit180(1,i)  = length(dotsHit180);
		out.coh.dotsHit180(2,i)  = length(dotsAngle2);;
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
plot(out.vals,out.cc,'k-o',out.vals,out.cDp,'r-o','MarkerSize',10,'linewidth',1.5)
if doDots
	hold on
	plot(out.vals,out.dc,'k:*',out.vals,out.dDp,'r:*','MarkerSize',10,'linewidth',1.5)
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

p(2,1).select();
plot(out.vals,out.cC,'k-o',out.vals,out.cnB,'r-o','MarkerSize',10,'linewidth',1.5)
if doDots
	hold on
	plot(out.vals,out.dC,'k:*',out.vals,out.dnB,'r:*','MarkerSize',10,'linewidth',1.5)
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

p(1,2).select();
plot(out.vals,out.ic,'k-o',out.vals,out.iDp,'r-o','MarkerSize',10,'linewidth',1.5)
if doDots
	hold on
	plot(out.vals,out.dc,'k:*',out.vals,out.dDp,'r:*','MarkerSize',10,'linewidth',1.5)
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
plot(out.vals,out.iC,'k-o',out.vals,out.inB,'r-o','MarkerSize',10,'linewidth',1.5)
if doDots
	hold on
	plot(out.vals,out.dC,'k:*',out.vals,out.dnB,'r:*','MarkerSize',10,'linewidth',1.5)
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
plot(out.vals,out.sPc,'k-o',out.vals,out.sDp,'r-o','MarkerSize',10,'linewidth',1.5)
if doDots
	hold on
	plot(out.vals,out.dc,'k:*',out.vals,out.dDp,'r:*','MarkerSize',10,'linewidth',1.5)
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
plot(out.vals,out.sC,'k-o',out.vals,out.snB,'r-o','MarkerSize',10,'linewidth',1.5)
if doDots
	hold on
	plot(out.vals,out.dC,'k:*',out.vals,out.dnB,'r:*','MarkerSize',10,'linewidth',1.5)
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


f=figure('name','Percent Correct');
set(f,'Color',[1 1 1]);
figpos(1,[1000 1000])
hold on

[fitVals,outvals,outfine]=fitit(out.vals, out.coh.CongruentCorrect, out.coh.CongruentLength);
out.conFit = fitVals;
plot(out.vals,out.cc,'b.','MarkerSize',20);
plot(outvals,outfine,'b-','linewidth',1.5);

[fitVals,outvals,outfine]=fitit(out.vals, out.coh.IncongruentCorrect, out.coh.IncongruentLength);
out.inconFit = fitVals;
plot(out.vals,out.ic,'r.','MarkerSize',20);
plot(outvals,outfine,'r-','linewidth',1.5);

if doDots
	[fitVals,outvals,outfine]=fitit(out.vals, out.coh.DotsAloneCorrect, out.coh.DotsAloneLength);
	out.dotsFit = fitVals;
	plot(out.vals,out.dc,'k.','MarkerSize',20);
	plot(outvals,outfine,'k-','linewidth',1.5);
	hleg = legend('Congruent','Congruent Fit','Incongurent','Inongruent Fit','Dots Alone','Dots Alone Fit','Location','SouthEast');
else
	hleg = legend('Congruent','Congruent Fit','Incongurent','Inongruent Fit','Location','SouthEast');
end
set(gca,'FontSize',15);
title(['PC ' dat.name],'Interpreter','none','FontSize',16);
xlabel('Coherence')
ylabel('Percentage Correct')
	set(hleg,'FontAngle','italic','TextColor',[.5,.4,.3],'FontSize',10)
box on
grid on


p1 = -fliplr(out.vals);
p2 = unique([p1 out.vals]);

cr = out.coh.congruentHit0(1,:) ./ out.coh.congruentHit0(2,:);
ir = out.coh.incongruentHit0(1,:) ./ out.coh.incongruentHit0(2,:);
dr = out.coh.dotsHit0(1,:) ./ out.coh.dotsHit0(2,:);

cl = fliplr(1 - (out.coh.incongruentHit180(1,:) ./ out.coh.incongruentHit180(2,:))); 
il = fliplr(1 - (out.coh.congruentHit180(1,:) ./ out.coh.congruentHit180(2,:)));
dl = fliplr(1 - (out.coh.dotsHit180(1,:) ./ out.coh.dotsHit180(2,:)));

cm = mean([cr(1) cl(end)]);
c = [cl(1:end-1) cm cr(2:end)];
im = mean([ir(1) il(end)]);
i = [il(1:end-1) im ir(2:end)];
if doDots
	dm = mean([dr(1) dl(end)]);
	d = [dl(1:end-1) dm dr(2:end)];
end

out.bvals = p2;
out.c = c;
out.i = i;
if doDots
	out.d = d;
end

f=figure('name','Overall Shift');
set(f,'Color',[1 1 1]);
figpos(1,[1000 1000])
hold on
if doDots
	plot(p2,c,'b.-',p2,i,'r.-',p2,d,'k.-','MarkerSize',30,'linewidth',1.5);
	hleg = legend('Congruent','Incongurent','Dots Alone','Location','SouthEast');
else
	plot(p2,c,'b.-',p2,i,'r.-','MarkerSize',30,'linewidth',1.5);
	hleg = legend('Congruent','Incongurent','Location','SouthEast');
end
set(gca,'FontSize',15);
title(['PC ' dat.name],'Interpreter','none','FontSize',16);
xlabel('Coherence L<->R')
ylabel('Percentage Correct Right')
set(hleg,'FontAngle','italic','TextColor',[.5,.4,.3],'FontSize',10)
box on
grid on
end

function [out, outvals, outfine, LL, exitFlag] = fitit(vals, num, tot)

correctnegative = false;

PF = {@PAL_Logistic; @PAL_Weibull; @PAL_CumulativeNormal; @PAL_Gumbel; @PAL_HyperbolicSecant};
PFSelect = 1;

if correctnegative
	minv = min(vals);
	vals = vals+minv;
end

iparamsValues = [0.15 10 0.5];
iparamsFree = [1 1 1];

paramsValues = iparamsValues;
paramsFree = iparamsFree;

exitN = 1;
exitFlag = 0;
while exitFlag == 0 && exitN <= 50
	message = '';
	[out, LL, exitFlag, message] = PAL_PFML_Fit(vals, num, tot, paramsValues, paramsFree, PF{PFSelect});
	if exitFlag == 0;
		paramsValues = out(1:3);
		disp([func2str(PF{PFSelect}) ' didn''t fit: ' message.message '|vals= ' num2str(out)]);
		if exitN > 50
			paramsValues = iparamsValues;
			paramsFree = iparamsFree;
			PFSelect = 5;
		elseif exitN > 40
			paramsValues = iparamsValues;
			paramsFree = iparamsFree;
			PFSelect = 4;
		elseif exitN > 30
			paramsValues = iparamsValues;
			paramsFree = iparamsFree;
			PFSelect = 3;
		elseif exitN > 20
			paramsValues = iparamsValues;
			paramsFree = iparamsFree;
			PFSelect = 2;
		elseif exitN > 10
		end
		exitN = exitN + 1;
	end
end

disp([func2str(PF{PFSelect}) ' fit: ' message.message '| vals= ' num2str(out)]);

outvals = linspace(min(vals), max(vals), 500);
f = PF{PFSelect};
if correctnegative
	outvals = outvals - minv;
end
outfine = f(out, outvals);

end
