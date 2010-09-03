function item = getdata( varargin )
% GETDATA get data item
%
% Description:
%     Get an item of data from the file specified in CONFIG_DATA.
%
% Usage:
%     GETDATA( row )        - return row of data as cell array
%     GETDATA( row, col )   - return data item at (row,col)
%
% Arguments:
%     row - row index of data item
%     col - col index of data item
%
% Examples:
%
% See also:
%     LOADDATA, COUNTDATAROWS, CONFIG_DATA
%
% Cogent 2000 function.

global cogent;

item = [];

if nargin < 1 | nargin > 2
   error( 'wrong number of arguments' );
end

row = varargin{1};
if row > length(cogent.data)
   error( [ 'no data at row=' num2str(row) ] );
end

if nargin == 1
   item = cogent.data{row};
end

if nargin == 2
   col = varargin{2};
   if col > length(cogent.data{row})
      error( [ 'no data at (row=' num2str(row) ',col=' num2str(col) ')' ] );
   end
   item = cogent.data{row}{col};
end


