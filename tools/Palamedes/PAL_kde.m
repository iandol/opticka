%
%PAL_kde  Kernel Density Estimation
%
%   syntax: [grid, pdf, cdf] = PAL_kde(x, {optional boundaries})
%
%   Estimates probability density for random variable from which vector x 
%   is a sample.
%
%Input:
%
%   'x': Vector containing sampled values from the random variable whose 
%       density is to be estimated.
%
%Output:
%
%   'grid': Values of random variable
%
%   'pdf': Estimated probability density across 'grid'
%
%   'cdf': Estimated cumulative density across 'grid'
%   
%   If underlying random variable is constrained to finite interval (e.g.,
%   probabilities to [0 1]) user may supply a 1x2 vector containing lower 
%   and upper boundaries. Use of e.g., [-Inf, 10] allowed.
%
%Example 1:
%
%   x = randn(1,10000); %draw sample from standard normal distribution
%   [grid,pdf] = PAL_kde(x);
%   plot(grid,pdf);
%
%Example 2:
%
%   x = rand(1,10000);  %draw sample from standard uniform distribution
%   [grid,pdf] = PAL_kde(x,[0 1]);
%   plot(grid,pdf);
%
%Example 3:
%
%   x = rand(1,10000);  %draw sample from standard uniform distribution
%   [grid,pdf] = PAL_kde(x,[0 Inf]);    %weird example but demonstrates
%                                       %treatment of boundaries
%   plot(grid,pdf);
%
%Introduced: Palamedes version 1.10.0 (NP)

function [grid,pdf,cdf] = PAL_kde(x,varargin)

bound = [-Inf, Inf];
gridsize = 10000;
nbins = 500;

if ~isempty(varargin)
    bound = varargin{1};
end

[n,c] = hist(x,nbins);

h = std(x)*1.06*length(x)^-.2; %Kernel bandwidth using Silverman's (1986) rule of thumb
kernelpad = 3*h;

anchor(1) = max(min(c)-kernelpad,bound(1)); %If boundaries are applied, have values that exactly correspond to them in grid
anchor(2) = min(max(c)+kernelpad,bound(2));

lolim = c(1)-kernelpad;
hilim = c(end)+kernelpad;
range = hilim-lolim;
factor = (anchor(2)-anchor(1))/range;
grid = linspace(anchor(1),anchor(2),factor*gridsize);
binwidth = grid(2)-grid(1);
padlength = [0 0];
if lolim<anchor(1)
    pad = anchor(1)+(floor((lolim-anchor(1))/binwidth):1:-1)*binwidth;
    padlength(1) = length(pad);
    grid = [pad grid];
end
if hilim>anchor(2)
    pad = anchor(2)+(1:1:ceil((hilim-anchor(2))/binwidth))*binwidth;
    padlength(2) = length(pad);
    grid = [grid pad];
end

fun = @(grid)mean(n.*PAL_pdfNormal(grid,c,h));

pdf = arrayfun(fun,grid)*nbins/sum(n);

if padlength(1) > 0
    pdf(1+padlength(1):2*padlength(1)) = pdf(1+padlength(1):2*padlength(1))+ fliplr(pdf(1:padlength(1)));
    pdf(1:padlength(1)) = 0;
end
if padlength(2) > 0
    pdf(1+end-2*padlength(2):end-padlength(2)) = pdf(1+end-2*padlength(2):end-padlength(2))+ fliplr(pdf(end-padlength(2)+1:end));
    pdf(end-padlength(2)+1:end) = 0;
end
cdf = cumsum(pdf*binwidth);