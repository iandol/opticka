%
%PAL_mat2Rdump  Write (numeric) matlab structure to R dump format file
%
%   syntax: success = PAL_mat2Rdump(dataStruct, {optional filename})
%
%   Writes numeric matlab structure to a file using the R dump format.
%   Resulting file can be read into R using R's 'source' command e.g.,
%   source('data.R').
%
%   returns 0 if file could not be created, 1 otherwise.
%
%   By default, data will be written to a file named data.R in the
%   current directory. User may provide optional argument specifying
%   alternative name (including existing directory path).
%
%   Example:
%   
%   data.x = 1;
%   data.y = rand(1,4);
%   data.z = rand(4,4);
%   PAL_mat2Rdump(data, 'path_to_some_existing_directory/myDataforR.R')
%
%Introduced: Palamedes version 1.10.0 (NP)

function [success] = PAL_mat2Rdump(data,varargin)

success = 1;
fname = 'data.R';
if ~isempty(varargin)
    fname = varargin{1};
end
fo = fopen(fname,'w');
if fo < 0
    warning('PALAMEDES:FileOpenFail',['Could not open ',fname,'.']);
    success = 0;
    return;
end    

fields = fieldnames(data);

for field = 1:length(fields)
    if ~isempty(data.(fields{field})) 
        if isscalar(data.(fields{field}))
            fprintf(fo,['"',fields{field},'" <- ',num2str(data.(fields{field}),'%.10g')]);
            fprintf(fo,'\n');
        else
            sz = size(data.(fields{field}));
            if min(sz) == 1
                fprintf(fo,['"',fields{field},'" <- c(']);
                for entry = 1:length(data.(fields{field}))-1
                    fprintf(fo,'%.10g',data.(fields{field})(entry));
                    fprintf(fo,',');
                end
                fprintf(fo,'%.10g',data.(fields{field})(end));
                fprintf(fo,')\n');
            else
                fprintf(fo,['"',fields{field},'" <- structure(c(']);
                for column = 1:sz(2)
                    for row = 1:sz(1)                    
                        fprintf(fo,'%.10g',data.(fields{field})(row,column));
                        if ~(row == sz(1) && column == sz(2))
                            fprintf(fo,',');
                        else
                            fprintf(fo,['),.Dim=c(',int2str(sz(1)),',',int2str(sz(2)),')']);
                        end
                    end
                end
                fprintf(fo,')\n');
            end
        end
    end
end
fclose(fo);