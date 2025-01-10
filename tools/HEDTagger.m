classdef HEDTagger < handle
	%HEDTagger 

	properties
		outputFormat = 'json'
		headings = {'onset','HED','timeType','tick','message','uuid','source'}
	end

	methods
		function me = HEDTagger()
			
		end

		function setupPython(me)
			[~,p] = system('which python');
			[~,pp] = system('which pip3');
			pyenv('Version',p);
			try system([pp ' install hedtools']); end
			try  pyrun("from hed import _version as vr; print(f'Using HEDTOOLS version: {str(vr.get_versions())}')"); end
		end

		function getTag('name')
			
		end

		function outputArg = makeHED(me, tL, bR, sM)

			data = {tL.startTime,''};

			if isa(tL,'timeLogger')
				for jj = 1:length(tL.messages)
					data{jj,1} = tL.messages(jj).vbl;
				
				end
			end	
		end
	end
end