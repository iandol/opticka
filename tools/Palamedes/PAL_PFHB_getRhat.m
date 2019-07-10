%
%PAL_PFHB_getRhat    Determines Gelman & Rubin's Rhat statistic (aka, 
%   'potential scale reduction factor, psrf) based on multiple MCMC chains.
%
%   syntax: [Rhat] = PAL_PFHB_getRhat(samples)
%
%Input:
%
%   samples: m x n matrix containing m ( > 1) MCMC chains of length n
%
%Output: 
%   
%   Rhat: Gelman & Rubin's Rhat (psrf) statistic. An Rhat smaller than the
%   somewhat arbitrary value of 1.05 is generally taken to be indicative of
%   successful convergence.
%
%Introduced: Palamedes version 1.10.0 (NP)

function [Rhat] = PAL_PFHB_getRhat(samples)

[m, n] = size(samples);
W = mean(var(samples,0,2));
B = n*var(mean(samples,2));

Rhat = sqrt(((1 - 1/n)*W + B/n)/(W+eps));   