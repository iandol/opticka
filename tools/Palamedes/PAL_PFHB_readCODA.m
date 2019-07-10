%
%PAL_PFHB_readCODA  Read JAGS output.
%   
%   syntax: [samples] = PAL_PFHB_readCODA(engine)
%
%Internal Function
%
% Introduced: Palamedes version 1.10.0 (NP)

function [samples] = PAL_PFHB_readCODA(engine)

fi = fopen([engine.dirout,'/coda1index.txt'],'r');
nodeLine = fgetl(fi);
lineIndex = 1;
while nodeLine ~= -1
    firstnoID = find(isspace(nodeLine),1);
    nodeID = nodeLine(1:firstnoID-1);
    nodeEntries(lineIndex,1:2) = str2num(nodeLine(firstnoID+1:end));
    bracket = find(nodeID == '[');
    indexed = ~isempty(bracket);
    if ~indexed
        nodeName{lineIndex} = nodeID;
        nodeIndex(lineIndex,1:2) = 1;
    else
        nodeName{lineIndex} = nodeID(1:bracket-1);
        index = str2num(nodeID(bracket+1:end-1));
        if isscalar(index)
            nodeIndex(lineIndex,1:2) = [index 1];
        else
            nodeIndex(lineIndex,1:2) = index;
        end
    end
    nodeLine = fgetl(fi);
    lineIndex = lineIndex + 1;
end
nonodes = lineIndex-1;
fclose(fi);

for chain = 1:engine.nchains
    fi = fopen([engine.dirout,'/coda',int2str(chain),'chain1.txt'],'r');
    content = fscanf(fi,'%g',[2, Inf]);    
    fclose(fi);
    for node = 1:nonodes
        samples.(nodeName{node})(chain,:,nodeIndex(node,2),nodeIndex(node,1)) = content(2,nodeEntries(node,1):nodeEntries(node,2));
    end
    chain = chain + 1;
end