function  out  = makedprime(dat)

r = dat.task.response;

if size(r,2) > 3
	rr = [r{:,1};r{:,2};r{:,3};r{:,4}]';
else
	rr = [r{:,1};r{:,2};r{:,3}]';
	an = [dat.task.outValues{:,1}]';
	an = [an{:,1}]';
	an = an(1:length(rr));
	rr = [rr, an];
end

rrcongruent = rr(rr(:,2)==true,:);
rrincongruent = rr(rr(:,2)==false,:);
coherencevals = unique(rr(:,3));

for i = 1:length(coherencevals) %we step through each coherence value
	
	%--------------------------
	congruentIndex = find(rrcongruent(:,3) == coherencevals(i)); %find congruent trials == current coherence
	
	congruentCorrect = find(rrcongruent(congruentIndex,1) == true); %correct congruent trials at this coherence
	congruentIncorrect = find(rrcongruent(congruentIndex,1) == false);  %incorrect congruent trials at this coherence
	
	congruentAngle1 = find(rrcongruent(congruentIndex,4) == 0); %index into 0deg = right angle
	congruentAngle2 = find(rrcongruent(congruentIndex,4) > 0); %left trials
	
	intersectpc = intersect(congruentCorrect,congruentAngle1);
	intersectpf = intersect(congruentIncorrect,congruentAngle2);
	
	cc(i) = length(congruentCorrect) / length(congruentIndex);
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
	incongruentAngle2 = find(rrincongruent(incongruentIndex,4) > 0);
	
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

f=figure('name','DPrime Output');
set(f,'Color',[1 1 1]);
figpos(1,[1000 1000])
p=panel(f);
p.margin = 25;
p.pack(2,2);

miny = min([min(out.cDp) min(out.iDp)]);
maxy = max([max(out.cDp) max(out.iDp)]);

p(1,1).select();
plot(out.vals,out.cc,'k-o',out.vals,out.cDp,'r-o')
set(gca,'FontSize',16);
title(['CONGRUENT' dat.name],'Interpreter','none','FontSize',20);
axis([-inf inf miny maxy])
xlabel('Coherence')
ylabel('D-Prime / % correct')
legend('% correct','D-Prime')
box on
grid on

p(1,2).select();
plot(out.vals,out.cC,'k-o',out.vals,out.cnB,'r-o')
set(gca,'FontSize',20);
title(['CONGRUENT' dat.name],'Interpreter','none','FontSize',20);
xlabel('Coherence')
legend('C bias','nB Bias')
ylabel('BIAS')
box on
grid on

p(2,1).select();
plot(out.vals,out.ic,'k-o',out.vals,out.iDp,'r-o')
set(gca,'FontSize',20);
title(['INCONGRUENT' dat.name],'Interpreter','none','FontSize',20)
axis([-inf inf miny maxy])
xlabel('Coherence')
ylabel('D-Prime / % correct')
legend('% correct','D-Prime')
box on
grid on

p(2,2).select();
plot(out.vals,out.iC,'k-o',out.vals,out.inB,'r-o')
set(gca,'FontSize',20);
title(['CONGRUENT' dat.name],'Interpreter','none','FontSize',20);
xlabel('Coherence')
legend('C bias','nB Bias')
ylabel('BIAS')
box on
grid on

end