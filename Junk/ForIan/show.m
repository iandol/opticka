% SHOW - Displays an image with the right size and colors and with a title.
%
% Usage:  show(im, figNo)
%
% Arguments:  im    - Either a 2 or 3D array of pixel values or the name
%                     of an image file;
%             figNo - Optional figure number to display image in.
%
% The function displays the image, automatically setting the colour map to
% grey if it is a 2D image, or leaving it as colour otherwise, and setting
% the axes to be 'equal'.  The image is also displayed as `TrueSize', that
% is, pixels on the screen match pixels in the image - you can then resize
% the image manually if you wish.
%
% If figNo is omitted a new figure window is created for the image.  If
% figNo is supplied, and the figure exists, the existing window is reused
% to display the image, otherwise a new window is created.

% PK October 2000


function show(im, figNo)
    warning off            
    if ~isnumeric(im)          % Guess that an image name has been supplied
	Title = im;
	im = imread(im);
    else
	Title = inputname(1);  % Get variable name of image data
    end
    
    if nargin == 2
	figure(figNo);         % Reuse or create a figure window with this number
    else
	figNo = figure;        % Create new figure window
    end

    if ndims(im) == 2          % Display as greyscale
	imagesc(im)
	colormap('gray')
    else
	imshow(im)             % Display as RGB
    end

    axis image, title(Title), truesize(figNo)
    warning on