% All.m

function res=All(inp,ind)


res=inp(:);
if exist('ind')
    res=res(ind);
end
