%
%PAL_PFHB_readStanOutput  Read Stan output.
%   
%   syntax: [samples, nodeName, nodeIndex]= PAL_PFHB_readStanOutput(engine)
%
%Internal Function
%
% Introduced: Palamedes version 1.10.0 (NP)
% Modified: Palamedes version 1.10.4 (See History.m)

function [samples, nodeName, nodeIndex, stan_version]= PAL_PFHB_readStanOutput(engine)

filename = [engine.dirout,'/samples'];
nochains = engine.nchains;

samples = [];

fi = fopen(strcat(filename,'1.csv'),'r');
for versionpart = 1:3
    line = fgetl(fi);
    stan_version(versionpart) = sscanf(line(24:end),'%d');
end
line(1) = '#';
lineno = 3;
while line(1) == '#'
    line = fgetl(fi);
    lineno = lineno+1;
end
line(line == ',') = ' ';
nodeID = textscan(line,'%s');
nodeID = nodeID{:};
nonodes = size(nodeID,1); %-7

for node = 1:nonodes    
    nodeIDchar = char(nodeID(node));
    dots = find(nodeIDchar =='.');
    noindexes = size(dots,2);    
    switch noindexes
        case 0
            nodeName{node} = nodeIDchar;
            nodeIndex(node,1:2) = 1;
        case 1            
            nodeName{node} = nodeIDchar(1:dots(1)-1);
            nodeIndex(node,1:2) = [str2num(nodeIDchar(dots(1)+1:end)) 1];
        case 2            
            nodeName{node} = nodeIDchar(1:dots(1)-1);
            nodeIndex(node,1:2) = [str2num(nodeIDchar(dots(1)+1:dots(2)-1)) str2num(nodeIDchar(dots(2)+1:end))];
    end
end

line(1) = '#';
while line(1) == '#'
    line = fgetl(fi);
    lineno = lineno+1;
end
fclose(fi);

for chain = 1:nochains

    A = dlmread(strcat(filename,int2str(chain),'.csv'),',',[lineno-1 0 engine.nsamples+lineno-2 size(nodeName,2)-1]);    
    
    for node = 8:nonodes
        samples.(nodeName{node})(chain,:,nodeIndex(node,2),nodeIndex(node,1)) = A(:,node);
    end
    
end
