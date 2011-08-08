% ========================================================================
%> @brief meta stimulus, inherits from baseStimulus
%> METASTIMULUS a collection of stimuli, wrapped in one structure
% ========================================================================
classdef metaStimulus < baseStimulus
	
	properties %--------------------PUBLIC PROPERTIES----------%
		%> stimulus family
		family = 'meta'
		stimuli = {}
	end
	
	properties (SetAccess = private, GetAccess = public)
		
	end
	
	properties (SetAccess = private, GetAccess = private)
		%> allowed properties passed to object upon construction
		allowedProperties = ['^()$']
		%>properties to not create transient copies of during setup phase
		ignoreProperties = 'stimuli'
	end
	
	events
		
	end
	
	%=======================================================================
	methods %------------------PUBLIC METHODS
	%=======================================================================
		
		% ===================================================================
		%> @brief Class constructor
		%>
		%> More detailed description of what the constructor does.
		%>
		%> @param args are passed as a structure of properties which is
		%> parsed.
		%> @return instance of class.
		% ===================================================================
		function obj = metaStimulus(args)
			if nargin>0 && isstruct(args)
				obj.parseArgs(args);
			end
		end
		
		% ===================================================================
		%> @brief Setup this object in preperation for use
		%> When displaying a stimulus object, the main properties that are to be
		%> modified are copied into cache copies of the property, both to convert from 
		%> visual description (c/d, Hz, degrees) to
		%> computer metrics, and to be animated and modified as independant
		%> variables. So xPosition is copied to xPositionOut and converyed from
		%> degrees to pixels. The animation and drawing functions use these modified
		%> properties, and when they are updated, for example to change to a new
		%> xPosition, internal methods ensure reconversion and update any dependent
		%> properties. This method initialises the object for display.
		%>
		%> @param rE runExperiment object for reference
		% ===================================================================
		function setup(obj,rE)
			
		end
		
	end
end