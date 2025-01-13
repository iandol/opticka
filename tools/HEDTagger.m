classdef HEDTagger < handle
	%HEDTagger 

	properties
		outputFormat = 'json'
		headings = {'onset','timeType','HED','tick','message','uuid','source'}
		timezone = 'local'
	end

	methods
		function me = HEDTagger()
			
		end

		function setupPython(me)
			disp('We need Python V3.12 with pip3 command, will try to install HEDtools now')
			[~,p] = system('which python');
			[~,pp] = system('which pip3');
			pyenv('Version',p);
			try system([pp ' install hedtools']); end
			try  pyrun("from hed import _version as vr; print(f'Using HEDTOOLS version: {str(vr.get_versions())}')"); end
		end

		function outputArg = makeHED(me, tL, bR, sM)

			if isa(tL,'timeLogger')
				msgs = tL.messageTable();
				for jj = 1:length(msgs)
					data{jj,1} = msgs{jj,1};
					date{jj,2} = msgs{jj,6};
					m = msgs{jj,5};
					if contains(m,'StartTime')
						date{jj,2} = HEDTags.Creation_date.name;
					elseif contains(m,regexpPattern('^===>>>'))
						date{jj,2} = HEDTags.Data_marker.name;
					elseif contains(m, regexpPattern('-post flip: \d+')
						n = NaN;
						num = regexp(m,'flip strobe: (?<number>\d+)$','names');
						if ~isempty(num); n = num.number; end
						date{jj,2} = [HEDTags.Experiment_control.name ', '];
					end
					date{jj,4} = msgs{jj,3};
					date{jj,5} = msgs{jj,5};
					date{jj,6} = '';
					date{jj,7} = 'timeLog';
				end
			end	
		end

		
	end

	methods (Static)
		function out = toDateTime(posixT)
			out = datetime(posixT,'ConvertFrom','posixtime','TimeZone',me.timezone,'Format','yyyy-MM-dd HH:mm:ss:SSSS');
		end
	end
end