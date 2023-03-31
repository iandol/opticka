% ========================================================================
classdef eyetrackerSmooth < handle
%> @class eyetrackerSmooth
%> @brief Smoothes incoming eye sample data
%>
%> Copyright ©2014-2023 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ========================================================================
	
	properties
		%> options for online smoothing of peeked data
		% %> method = {'median','heuristic','heuristic2', 'savitsky-golay'}
		smoothing		= struct('nSamples',8,'method','median','window',3,...
						'eyes','both','sampleRate', 500)
	end

	properties (SetAccess = protected, GetAccess = public, Dependent = true)
		%> calculates the smoothing in ms
		smoothingTime double
	end

	%========================================================================
	methods %----------------------------PUBLIC METHODS
	%========================================================================

		% ===================================================================
		%> @brief This is the constructor for this class
		%>
		% ===================================================================
		function me = eyetrackerSmooth()
			if isprop(me,'sampleRate')
				me.smoothing.sampleRate = me.sampleRate; %#ok<*MCNPN>
			end
		end

		% ===================================================================
		%> @brief calculate smoothing Time in ms
		%>
		% ===================================================================
		function value = get.smoothingTime(me)
			value = (1000 / me.smoothing.sampleRate) * me.smoothing.nSamples;
		end

	end%-------------------------END PUBLIC METHODS--------------------------------%

	%============================================================================
	methods (Hidden = true) %--STATIC METHODS 
	%============================================================================

		% ===================================================================
		%> @brief smooth data in M x N where M = 2 (x&y trace) or M = 4 is x&y
		%> for both eyes. Output is 2 x 1 x + y average position
		%>
		% ===================================================================
		function out = doSmoothing(me,in)
			if size(in,2) > me.smoothing.window * 2
				switch me.smoothing.method
					case 'median'
						out = movmedian(in,me.smoothing.window,2);
						out = median(out, 2);
					case {'heuristic','heuristic1'}
						out = eyetrackerSmooth.heuristicFilter(in,1);
						out = median(out, 2);
					case 'heuristic2'
						out = eyetrackerSmooth.heuristicFilter(in,2);
						out = median(out, 2);
					case {'sg','savitzky-golay'}
						out = sgolayfilt(in,1,me.smoothing.window,[],2);
						out = median(out, 2);
					otherwise
						out = median(in, 2);
				end
			elseif size(in, 2) > 1
				out = median(in, 2);
			else
				out = in;
			end
			if size(out,1)==4 % XY for both eyes, combine together.
				out = [mean([out(1) out(3)]); mean([out(2) out(4)])];
			end
			if length(out) ~= 2
				out = [NaN NaN];
			end
		end

	end

	%============================================================================
	methods (Static) %--STATIC METHODS 
	%============================================================================

		% ===================================================================
		%> @brief Stampe 1993 heuristic filter as used by Eyelink
		%>
		%> @param indata - input data
		%> @param level - 1 = filter level 1, 2 = filter level 1+2
		%> @param steps - we step every # steps along the in data, changes the filter characteristics, 3 is the default (filter 2 is #+1)
		%> @out out - smoothed data
		% ===================================================================
		function out = heuristicFilter(indata,level,steps)
			if ~exist('level','var'); level = 1; end %filter level 1 [std] or 2 [extra]
			if ~exist('steps','var'); steps = 3; end %step along the data every n steps
			out=zeros(size(indata));
			for k = 1:2 % x (row1) and y (row2) eye samples
				in = indata(k,:);
				%filter 1 from Stampe 1993, see Fig. 2a
				if level > 0
					for i = 1:steps:length(in)-2
						x = in(i); x1 = in(i+1); x2 = in(i+2); %#ok<*PROPLC>
						if ((x2 > x1) && (x1 < x)) || ((x2 < x1) && (x1 > x))
							if abs(x1-x) < abs(x2-x1) %i is closest
								x1 = x;
							else
								x1 = x2;
							end
						end
						x2 = x1;
						x1 = x;
						in(i)=x; in(i+1) = x1; in(i+2) = x2;
					end
				end
				%filter2 from Stampe 1993, see Fig. 2b
				if level > 1
					for i = 1:steps+1:length(in)-3
						x = in(i); x1 = in(i+1); x2 = in(i+2); x3 = in(i+3);
						if x2 == x1 && (x == x1 || x2 == x3)
							x3 = x2;
							x2 = x1;
							x1 = x;
						else %x2 and x1 are the same, find closest of x2 or x
							if abs(x1 - x3) < abs(x1 - x)
								x2 = x3;
								x1 = x3;
							else
								x2 = x;
								x1 = x;
							end
						end
						in(i)=x; in(i+1) = x1; in(i+2) = x2; in(i+3) = x3;
					end
				end
				out(k,:) = in;
			end
		end
	end
end