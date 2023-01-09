% ========================================================================
%> @brief annulusStimulus TODO
%>
%> 
%>
%> Copyright ©2014-2022 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ========================================================================
classdef annulusStimulus < baseStimulus
 
    properties
		method='procedural'
        sf1=0.01
        sf2=0.01
		tf1=0.01
		tf2=0.01
		angle1=0
		angle2=0
		phase1=0
		phase2=0
		contrast1=0.36
        contrast2=0.36
		texid=[];
    end
    properties (SetAccess = private, GetAccess = private)
		allowedProperties={'family', 'sf1', 'tf1', 'sf2', 'tf2', 'method', 'angle1', 'phase1', 'angle2', 'phase2', 'contrast1', 'contrast2', 'texid'}
	end
    
    methods
        function obj = annulusStimulus(args) %%%CONSTRUCTOR%%%
			%Initialise for superclass, stops a noargs error
			if nargin == 0
				args.family = 'annulus';
			end
			obj=obj@baseStimulus(args); %we call the superclass constructor first
			%check we are a grating
			if ~strcmp(obj.family,'annulus')
				error('Sorry, you are trying to call a gratingStimulus with a family other than grating');
			end
			%start to build our parameters
			if nargin>0 && isstruct(args)
				fnames = fieldnames(args); %find our argument names
				for i=1:length(fnames);
					if regexp(fnames{i},obj.allowedProperties) %only set if allowed property
						obj.salutation(fnames{i});
						obj.(fnames{i})=args.(fnames{i}); %we set up the properies from the arguments as a structure
					end
                end
			end
			obj.salutation('happy annulus stimulus user');
		end
		
		function construct(obj,~)
			obj.salutation('construct is go!');
		end
        
    end
    
end

