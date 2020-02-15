% doLogGabor: spatial-frequency and/or orientation band-pass filter an
% image using a logGabor filter.
%
% This is a very flexible/useful spatial filter, since you can specify
% if it cares about orientation or not, and you can specify if it cares
% about spatial frequency or not.
%
% Using it looks like this:
% res = doLogGabor(im,FreqPeak,FreqSigma,ThetaPeak,ThetaSigma);
%
% Parameters:
% 'im' an image: can be RGB, grayscale or a stack of grayscale images (a movie)
% 'Peak' spatial frequency is 'FreqPeak' in cycles per image
% 'FreqSigma' specified the spatial-frequency bandwidth. It's the sigma parameter of a log-Gabor specified in octaves (put in 0 to pass all SFs)
% 'ThetaPeak' is peak orientation (radians., 0 is vertical)
% 'ThetaSigma' is orientation s.d. of a wrapped Gaussian (radians; Inf means orientation broadband)
%
% Note that  FreqPeak and ThetaPeak can be lists and the result will be an image array.
% Note that if you provide a second output argument the routine returns the filter FFTs
% Note that the routine tries to maintain the original RMS contrast in each
% input image component (e.g. within each R-G-B component)
%
% e.g. [res]=doLogGabor(randn(512),[8 32 128],[0.5],deg2rad([0:45:135]),deg2rad(15)); imagesc(real(res(:,:,1,1))); colormap(gray(256));
%
% This makes a 3 X 4 array of 512X512 pix noise patterns at 8,32 and 128 c/image
% with peak orientations of 0, 45, 90 and 135 deg.
%
% The results will have a real and imaginary component. Run real() and
% imaginary() on the result to get the components (you usually just use real())
% Running abs() sum the square of the two components to give the local energy.
%
% Note extra output arguments return (first) a list of contrast energies
% and (second) a list of the filter FFTs. I use these for batch processing.
%
%
% If you use this in published research please cite  "Horizontal information drives the
% behavioral signatures of face processing" Goffaux & Dakin (2010) Frontiers in Perception
% Science v1, 143
%
% May 2015,  Steven Dakin, s.dakin@auckland.ac.nz
%
function [resFinal,varargout]=doLogGabor(im,FreqPeak,FreqSigma,ThetaPeak,ThetaSigma)
[n m p]=size(im);
for pLoop=1:p                                       % loop on third dimension of image
   iFT = fft2(im(:,:,pLoop));                      % we'll need the fft of the image
   if length(ThetaSigma)< length(ThetaPeak)        % pad parameter lists if necessary so they're all the same length
       ThetaSigma = ThetaSigma(1)+ 0.*ThetaPeak;
   end
   if length(FreqSigma) < length(FreqPeak)         % pad parameter lists if necessary so they're all the same length
       FreqSigma  = FreqSigma(1) + 0.*FreqPeak;
   end
   [X,Y]                                   = meshgrid((-m/2: (m/2-1))/(m/2),(-n/2 : (n/2 - 1))/(n/2)); % the grid we'll use to make the filter in the Fourier domain
   CentreDist                              = sqrt(X.^2 + Y.^2);    % distance from centre for computing frequency
   CentreDist(round(n/2+1),round(m/2+1))   = 1;                    % Set 0 dist to be one (a hack to avoid 1/0: we fix this later)
   CentreAng                               = pi/2+atan2(-Y,X);          % angle from centre for computing filter orientation
   for OrLoop = 1:length(ThetaPeak)                                % loop on filter orientations
       % first compute the angular band-pass component of the filter and put it in the variable 'AngSpread'
       ds      = sin(CentreAng) * cos(ThetaPeak(OrLoop)) - cos(CentreAng) * sin(ThetaPeak(OrLoop)); % need this for dtheta calc
       dc      = cos(CentreAng) * cos(ThetaPeak(OrLoop)) + sin(CentreAng) * sin(ThetaPeak(OrLoop)); % need this for dtheta calc
       dtheta  = atan(ds./dc);                            %  angular difference.
       AngSpread  = exp((-dtheta.^2) /(2*ThetaSigma(OrLoop)^2));  % a Fourier-domain filter that is  bandpass in the angular domain
       % now add in the spatial-frequency bandpass component
       for s = 1:length(FreqPeak) % loop on filter SF
           FreqSdAbsolute = (1/(2.^(FreqSigma(s))));       % compute bandwidth from parameter (which is in octaves)
           rfo = (FreqPeak(s)./min([m n]))/0.5;            % Radius from centre of frequency plane
           sfSpread = exp((-(log(CentreDist/rfo)).^2) / (2 * log(FreqSdAbsolute)^2)); % a log Gaussian i.e. bandpass in the log-SF domain
           sfSpread(round(n/2+1),round(m/2+1)) = 0;                                % Impose zero d.c. on the filter (sorts out the hack above)
           filter1                             = (sfSpread.*AngSpread);               % Multiply by angular AngSpread
           tmp1                                = ifft2(iFT.*fftshift(filter1));    % compute result
           res(:,:,s,OrLoop)                   = tmp1;                        % pop the result in an array
           energy(s,OrLoop)                    = std(tmp1(:));                % compute RMS contrast and store it
       end
   end
   if nargout>1  % if you give an extra output argument it will return the energy
       varargout{1}=energy';
   end
   if nargout>2  % if you another output arguments it will return the filters
       varargout{2}=fftshift(filter1);
   end
   if (length(FreqSigma)<2) && (length(ThetaSigma)<2)
       resFinal(:,:,pLoop)=res;
   else
       resFinal=(res);
   end
end