function choice = menuN(mtitle, options, Opt)
%% MENUN A modern rewrite of menuN using uifigure and uigridlayout
%
% Syntax:
%  choice = MENUN(mtitle, options)
%  choice = MENUN(mtitle, options, Opt)
%
% Input:
%  mtitle   - [string OR cell with 2 elements] - Menu window title and message
%           - {'Menu title','Menu Message'} - Supply different title and message
%           - {'Menu title',''} - Does not print any message
%           Note, the message has to be line breaked manually. This can be
%           achieved by inserting '|' where a line break should be done.
%  options  - [various] - Multifunctional:
%     (b) [cellstr]: Buttons are created with labels as in the cell array.
%     ex. options = {'option1', 'option2', ... }, results in:
%           |--mtitle---------|
%           |  [  option1  ]  |
%           |  [  option2  ]  |
%           |  [    ...    ]  |
%           |-----------------|
%     (r) [string && options(1:2) == 'r|' ]:
%           Radiobuttons for single selection, separate options with |:
%           Start an option string part with ¤ to have it default toggled on.
%     ex. options = 'r|option1|¤option2|...', results in:
%           |--mtitle--------|
%           |  O  option1    |
%           |  x  option2    |
%           |  O     ...     |
%           |  [OK][Cancel]  |
%           |----------------|
%     (p) [string && options(1:2) == 'p|' ]:
%           Popupmenu for single selection, separate options with |:
%           Start an option string part with ¤ to set it default toggled on.
%     ex. options = 'p|option1|option2|...', results in:
%           |--mtitle--------|
%           |  | optionX |v| |
%           |  [OK] [Cancel] |
%           |----------------|
%     (x) [string && options(1:2) == 'x|' ]:
%           Checkboxes with mutliselection, separate options with |:
%           Start an option string part with ¤ to set it default toggled on.
%     ex. options = 'x|option1|¤option2|...', results in:
%           |--mtitle--------|
%           | | | options    |
%           | |x| options    |
%           | | |    ...     |
%           | [OK][Cancel]   |
%           |----------------|
%     (l) [string && options(1:2) == 'l|']:
%           Listbox with mutliselection, separate options with |.
%           Start an option string part with ¤ to set it default toggled on.
%     ex. options = 'l|option1|option2|...', results in:
%           |--mtitle----------|
%           |  |  option1  |   |
%           |  |  option2  |   |
%           |  |    ...    |   |
%           |  [OK] [Cancel]   |
%           |------------------|
%     (s) [double, length == 2]: Slider is created from initial to final value.
%      or [double, length == 3]: Same slider but with third value as default
%     ex. options = [0,7,3.5], results in:
%           |--mtitle--------------|
%           | |<|====[]====|>| 3.5 |
%           | [  OK  ][  Cancel  ] |
%           |----------------------|
%     (t) [string && options(1:2) == 't|' ]:
%           Input text/edit box, returns string inputed into text box.
%           Obvious numeric input (for which str2num is ok) is returned as
%           numerical values (ex, 14, 1:2:10, 0.35E+5).
%     ex. options = 't|my text|the second line', results in:
%           |--mtitle--------------|
%           | | my text          | |
%           | | the second line  | |
%           | [  OK  ][  Cancel  ] |
%           |----------------------|
%     (*) [cell-Nx2]: Multiple "choice groups" in the same menu:
%           Each cell element should have any of the syntaxes as above.
%           A gui menu window is then created with all of these selections of
%           choices. The second column of the cell should contain a subtitle for
%           the corresponding choice group. If the second input is empty no
%           subtitle is printed. The pushbutton type menu group (b) is changed
%           to a popupmenu selection (p) instead of pushbuttons. Example:
%     ex. options = {'p|option1|option2|...','subititle1';...
%                    'options2 part1|options2 part2','subtitle2';...
%                    [0,7,3.5],'subtitle3'}, results in:
%           |--mtitle---------------|
%           |  subtitle1            |
%           |  | options1     |v|   |        % Popupmenu (instead of buttons)
%           |  subtitle2            |
%           |  | options2 part1 |   |        % Listbox
%           |  | options2 part2 |   |
%           |  subtitle3            |
%           |  |<|===[]===|>| 3.5   |        % Slider
%           |  [  OK  ][  Cancel  ] |
%           |-----------------------|
%  Opt    - [struct]  - Structure containing options for font name, size etc.
%
% Output:
%  choice - [double OR cell IF multiple options] - selected option(s)
%     (a) If multiple selection groups are used as by input of type (*) choice
%         is a cell array equal with length == number of rows in options.
%     (b) If an selection type allows multiselection the choice array
%         contains all selected options, (array instead of scalar).
%     (c) If any option group has no values selected its value is NaN.
%
% See also menuN, menu, inputdlg, uifigure, uigridlayout

%   Created by: Johan Winges (original menuN)
%   Rewritten: 2026-06-25 using uifigure + uigridlayout

	%% 1. Font and HiDPI detection
	lf = listfonts;
	if ismac
		SansFont = 'Avenir Next';
	elseif ispc
		SansFont = 'Calibri';
	else
		SansFont = 'Ubuntu';
	end
	if any(matches(lf, 'Source Sans 3'))
		SansFont = 'Source Sans 3';
	end

	fontSize = 13;
	buttonFontSize = 15;

	%% 2. Default Opt struct
	defOpt = struct();
	defOpt.fontName               = SansFont;
	defOpt.subtitleFontSize       = buttonFontSize;
	defOpt.pushbuttonFontSize     = fontSize;
	defOpt.popupmenuFontSize      = fontSize;
	defOpt.radiobuttonFontSize    = fontSize;
	defOpt.checkboxFontSize       = fontSize;
	defOpt.listboxFontSize        = fontSize;
	defOpt.sliderFontSize         = fontSize;
	defOpt.sliderStepsFraction    = [0.01, 0.1];
	defOpt.okButtonLabel          = 'OK';
	defOpt.pixelHeigthUIcontrol   = 30;
	defOpt.pixelPaddingHeigth     = [5, 5];
	defOpt.pixelPaddingWidth      = [6, 4];
	defOpt.InsteadOfPushUse       = 'p';
	defOpt.cancelButton           = true;
	defOpt.cancelButtonLabel      = 'Cancel';
	defOpt.standardCancelOutput   = NaN;
	defOpt.printTitleAsText       = true;

	%% 3. Handle input arguments
	if nargin == 0
		mtitle = {'Opticka: menuNN', 'This is a menuN test dialog...'};
		options = {  [1,2,1.75], 'Loss parameter:';   ...
			'r|Test A|Test B|¤Default','Test procedure:';...
			'p|a|b|¤c','Select a, b or c:';...
			'x|Flux|¤E-Field|¤B-Field','Compute:';...
			't|First test|New user','Comment:';...
			't|1:2:12','Numeric edit:'};
		Opt = defOpt;
	elseif nargin == 3
		if isstruct(Opt)
			Opt = setdefaultsstruct(Opt, defOpt);
		else
			error('menuNN:input:Third input is not a structure.')
		end
	elseif nargin == 2
		Opt = defOpt;
	else
		error('menuNN:input:Insufficient inputs, menuNN need mtitle and options.')
	end

	%% 4. Parse mtitle
	if ~iscell(mtitle)
		if Opt.printTitleAsText
			mtitle = {mtitle, mtitle};
		else
			mtitle = {mtitle, ''};
		end
	end

	%% 5. Parse options and subtitles
	flagMakeOkButton = true;
	flagMakeOnlyCancelButton = false;

	if iscellstr(options) && isvector(options) && ...
			isempty(strfind(options{1}, '|')) %#ok<STREMP>
		options = {options};
		subtitles = {''};
		flagMakeOkButton = false;
		flagMakeOnlyCancelButton = true;
	elseif iscell(options) && size(options, 2) == 2
		Opt.usePopupInsteadOfPush = true;
		subtitles = options(:, 2);
		options = options(:, 1);
	else
		options = {options};
		subtitles = {''};
	end

	numOptionsGroups = length(options);

	%% 6. Pre-parse all option groups to determine types and row counts
	groupInfo = cell(numOptionsGroups, 1);
	for idx = 1:numOptionsGroups
		groupInfo{idx} = classifyOption(options{idx}, numOptionsGroups, Opt);
	end

	%% 7. Count rows and determine row heights
	rowSpecs = {};
	hasTitleRow = ~isempty(mtitle{2});
	if hasTitleRow
		rowSpecs{end+1} = 'fit';
	end

	hasSubtitleRow = false(1, numOptionsGroups);
	for idx = 1:numOptionsGroups
		if ~isempty(subtitles{idx})
			hasSubtitleRow(idx) = true;
			rowSpecs{end+1} = 'fit';
		end
		switch groupInfo{idx}.type
			case {'listbox', 'textarea'}
				rowSpecs{end+1} = 120;
			otherwise
				rowSpecs{end+1} = 'fit';
		end
	end
	rowSpecs{end+1} = 'fit'; % button row
	numRows = length(rowSpecs);

	%% 8. Calculate figure size
	% Estimate pixel height for each row type
	figWidth = 500;
	figPaddingTop = 10;
	figPaddingBottom = 10;
	rowSpacingPx = 6;
	fitRowHeight = 38;

	totalHeight = figPaddingTop + figPaddingBottom;
	for k = 1:length(rowSpecs)
		if isnumeric(rowSpecs{k})
			totalHeight = totalHeight + rowSpecs{k};
		else
			totalHeight = totalHeight + fitRowHeight;
		end
		if k > 1
			totalHeight = totalHeight + rowSpacingPx;
		end
	end

	% Center on screen
	scr = get(0, 'ScreenSize');
	figX = max(1, round((scr(3) - figWidth) / 2));
	figY = max(1, round((scr(4) - totalHeight) / 2));

	%% 9. Create figure and grid
	fig = uifigure( ...
		'Name', mtitle{1}, ...
		'WindowStyle', 'modal', ...
		'AutoResizeChildren', 'on', ...
		'Position', [50, 50, figWidth, totalHeight], ...
		'Scrollable','on',...
		'Visible', 'on');

	mainGrid = uigridlayout(fig, [numRows, 1]);
	mainGrid.ColumnWidth = {'1x'};
	mainGrid.RowHeight = rowSpecs;
	mainGrid.Padding = [10 10 10 10];
	mainGrid.RowSpacing = 6;
	mainGrid.ColumnSpacing = 10;

	currentRow = 1;

	%% 10. Title row
	if hasTitleRow
		titleStr = strrep(mtitle{2}, '|', newline);
		titleLbl = uilabel(mainGrid, ...
			'Text', titleStr, ...
			'FontName', Opt.fontName, ...
			'FontSize', Opt.subtitleFontSize, ...
			'FontWeight', 'bold', ...
			'HorizontalAlignment', 'left');
		titleLbl.Layout.Row = currentRow;
		titleLbl.Layout.Column = 1;
		currentRow = currentRow + 1;
	end

	%% 11. Option group rows
	hOptions = cell(numOptionsGroups, 1);

	for idx = 1:numOptionsGroups
		tmpOptions = options{idx};
		info = groupInfo{idx};

		% Subtitle
		if hasSubtitleRow(idx)
			subStr = strrep(subtitles{idx}, '|', newline);
			subLbl = uilabel(mainGrid, ...
				'Text', subStr, ...
				'FontName', Opt.fontName, ...
				'FontSize', Opt.subtitleFontSize, ...
				'FontWeight', 'bold', ...
				'HorizontalAlignment', 'left');
			subLbl.Layout.Row = currentRow;
			subLbl.Layout.Column = 1;
			currentRow = currentRow + 1;
		end

		% Widget
		switch info.type

			case 'pushbutton'
				panel = uipanel(mainGrid, 'BorderType', 'none');
				panel.Layout.Row = currentRow;
				panel.Layout.Column = 1;
				numBtns = length(info.labels);
				innerGrid = uigridlayout(panel, [numBtns, 1]);
				innerGrid.RowHeight = repmat({'fit'}, 1, numBtns);
				innerGrid.ColumnWidth = {'1x'};
				innerGrid.RowSpacing = 4;
				innerGrid.Padding = [0 0 0 0];
				hButtons = cell(numBtns, 1);
				for k = numBtns:-1:1
					hButtons{k} = uibutton(innerGrid, 'push', ...
						'Text', info.labels{k}, ...
						'FontName', Opt.fontName, ...
						'FontSize', Opt.pushbuttonFontSize, ...
						'ButtonPushedFcn', @(~,~) closeFig(fig, k));
					hButtons{k}.Layout.Row = k;
					hButtons{k}.Layout.Column = 1;
				end
				hOptions{idx} = hButtons;

			case 'radio'
				panel = uipanel(mainGrid, 'BorderType', 'none');
				panel.Layout.Row = currentRow;
				panel.Layout.Column = 1;
				numRadios = length(info.labels);
				innerGrid = uigridlayout(panel, [numRadios, 1]);
				innerGrid.RowHeight = repmat({'fit'}, 1, numRadios);
				innerGrid.ColumnWidth = {'1x'};
				innerGrid.RowSpacing = 2;
				innerGrid.Padding = [0 0 0 0];
				hRadios = cell(numRadios, 1);
				for k = 1:numRadios
					hRadios{k} = uiradiobutton(innerGrid, ...
						'Text', info.labels{k}, ...
						'FontName', Opt.fontName, ...
						'FontSize', Opt.radiobuttonFontSize);
					hRadios{k}.Layout.Row = k;
					hRadios{k}.Layout.Column = 1;
				end
				if ~isempty(info.defaultIdx)
					hRadios{info.defaultIdx(1)}.Value = true;
				end
				hOptions{idx} = hRadios;

			case 'popup'
				dropdown = uidropdown(mainGrid, ...
					'Items', info.labels, ...
					'FontName', Opt.fontName, ...
					'FontSize', Opt.popupmenuFontSize);
				if ~isempty(info.defaultIdx)
					dropdown.Value = info.labels{info.defaultIdx(1)};
				else
					dropdown.Value = info.labels{1};
				end
				dropdown.Layout.Row = currentRow;
				dropdown.Layout.Column = 1;
				hOptions{idx} = dropdown;

			case 'checkbox'
				panel = uipanel(mainGrid, 'BorderType', 'none');
				panel.Layout.Row = currentRow;
				panel.Layout.Column = 1;
				numChecks = length(info.labels);
				innerGrid = uigridlayout(panel, [numChecks, 1]);
				innerGrid.RowHeight = repmat({'fit'}, 1, numChecks);
				innerGrid.ColumnWidth = {'1x'};
				innerGrid.RowSpacing = 2;
				innerGrid.Padding = [0 0 0 0];
				hChecks = cell(numChecks, 1);
				for k = 1:numChecks
					hChecks{k} = uicheckbox(innerGrid, ...
						'Text', info.labels{k}, ...
						'FontName', Opt.fontName, ...
						'FontSize', Opt.checkboxFontSize, ...
						'Value', ismember(k, info.defaultIdx));
					hChecks{k}.Layout.Row = k;
					hChecks{k}.Layout.Column = 1;
				end
				hOptions{idx} = hChecks;

			case 'listbox'
				listbox = uilistbox(mainGrid, ...
					'Items', info.labels, ...
					'Multiselect', 'on', ...
					'FontName', Opt.fontName, ...
					'FontSize', Opt.listboxFontSize);
				if ~isempty(info.defaultIdx)
					listbox.Value = info.labels(info.defaultIdx);
				else
					listbox.Value = {};
				end
				listbox.Layout.Row = currentRow;
				listbox.Layout.Column = 1;
				hOptions{idx} = listbox;

			case 'slider'
				sliderGrid = uigridlayout(mainGrid, [1, 2]);
				sliderGrid.ColumnWidth = {'1x', 'fit'};
				sliderGrid.RowHeight = {'fit'};
				sliderGrid.RowSpacing = 0;
				sliderGrid.ColumnSpacing = 10;
				sliderGrid.Padding = [0 0 0 0];
				sliderGrid.Layout.Row = currentRow;
				sliderGrid.Layout.Column = 1;

				numericVal = info.numericValue;
			sl = uislider(sliderGrid, ...
				'Limits', [numericVal(1), numericVal(2)], ...
				'Value', numericVal(3), ...
				'MajorTicks', linspace(numericVal(1), numericVal(2), 5));
				sl.Layout.Row = 1;
				sl.Layout.Column = 1;

				sliderLbl = uilabel(sliderGrid, ...
					'Text', num2str(numericVal(3)), ...
					'FontName', Opt.fontName, ...
					'FontSize', Opt.sliderFontSize, ...
					'HorizontalAlignment', 'center', ...
					'VerticalAlignment', 'center');
				sliderLbl.Layout.Row = 1;
				sliderLbl.Layout.Column = 2;

				sl.ValueChangedFcn = @(~,~) set(sliderLbl, 'Text', num2str(sl.Value));

				hOptions{idx} = {sl, sliderLbl};

			case 'textarea'
				ta = uitextarea(mainGrid, ...
					'Value', info.textValue, ...
					'FontName', Opt.fontName, ...
					'FontSize', Opt.popupmenuFontSize);
				ta.Layout.Row = currentRow;
				ta.Layout.Column = 1;
				hOptions{idx} = ta;

		end

		currentRow = currentRow + 1;
	end

	%% 12. Button row
	btnGrid = uigridlayout(mainGrid, [1, 2]);
	btnGrid.Layout.Row = currentRow;
	btnGrid.Layout.Column = 1;
	btnGrid.RowHeight = {'fit'};
	btnGrid.Padding = [0 0 0 0];
	btnGrid.RowSpacing = 0;
	btnGrid.ColumnSpacing = 10;

	if flagMakeOkButton
		btnGrid.ColumnWidth = {'1x', '1x'};
		okBtn = uibutton(btnGrid, 'push', ...
			'Text', Opt.okButtonLabel, ...
			'FontName', Opt.fontName, ...
			'FontSize', Opt.pushbuttonFontSize, ...
			'ButtonPushedFcn', @(~,~) closeFig(fig, 'OK'));
		okBtn.Layout.Row = 1;
		okBtn.Layout.Column = 1;

		if Opt.cancelButton
			cancelBtn = uibutton(btnGrid, 'push', ...
				'Text', Opt.cancelButtonLabel, ...
				'FontName', Opt.fontName, ...
				'FontSize', Opt.pushbuttonFontSize, ...
				'ButtonPushedFcn', @(~,~) closeFig(fig, Opt.standardCancelOutput));
			cancelBtn.Layout.Row = 1;
			cancelBtn.Layout.Column = 2;
		end
	elseif flagMakeOnlyCancelButton && Opt.cancelButton
		btnGrid.ColumnWidth = {'1x'};
		cancelBtn = uibutton(btnGrid, 'push', ...
			'Text', Opt.cancelButtonLabel, ...
			'FontName', Opt.fontName, ...
			'FontSize', Opt.pushbuttonFontSize, ...
			'ButtonPushedFcn', @(~,~) closeFig(fig, Opt.standardCancelOutput));
		cancelBtn.Layout.Row = 1;
		cancelBtn.Layout.Column = 1;
	end

	%% 13. Show and wait
	fig.Visible = 'on';
	drawnow;
	uiwait(fig);

	%% 14. Collect results
	if ishandle(fig)
		choice = fig.UserData;
		if strcmp(choice, 'OK')
			choice = cell(numOptionsGroups, 1);
			for idx = 1:numOptionsGroups
				info = groupInfo{idx};
				hw = hOptions{idx};
				switch info.type
					case 'textarea'
						tmpStr = char(hw.Value);
						[tmpVal, tmpStatus] = str2num(tmpStr); %#ok<ST2NM>
						if tmpStatus
							choice{idx} = tmpVal;
						else
							choice{idx} = tmpStr;
						end

					case 'popup'
						choice{idx} = find(strcmp(hw.Items, hw.Value), 1);

					case 'radio'
						selIdx = find(cellfun(@(r) r.Value, hw));
						if isempty(selIdx)
							choice{idx} = Opt.standardCancelOutput;
						else
							choice{idx} = selIdx;
						end

					case 'checkbox'
						selIdx = find(cellfun(@(c) c.Value, hw));
						choice{idx} = selIdx;

					case 'listbox'
						if isempty(hw.Value)
							choice{idx} = Opt.standardCancelOutput;
						else
							choice{idx} = find(ismember(hw.Items, hw.Value));
						end

					case 'slider'
						choice{idx} = hw{1}.Value;

					case 'pushbutton'
						choice{idx} = Opt.standardCancelOutput;
				end
			end
			if numOptionsGroups == 1
				choice = choice{1};
			end
		end
		delete(fig);
	else
		choice = Opt.standardCancelOutput;
	end
end

%% ========================================================================
%  Local helper functions
%  ========================================================================

function closeFig(fig, val)
% closeFig Store result and resume from uiwait
	fig.UserData = val;
	uiresume(fig);
end

function info = classifyOption(optStr, numGroups, Opt)
% classifyOption Determine the type and contents of an option group
	info = struct('type', '', 'labels', {{}}, 'defaultIdx', [], ...
		'numericValue', [], 'textValue', '', 'isMultiline', false);

	if iscellstr(optStr) && (numGroups > 1)
		% Multi-group pushbutton → convert to popup or radio
		sep = repmat({'|'}, 1, length(optStr));
		sep{1} = sprintf('%s|', Opt.InsteadOfPushUse);
		joined = cat(1, sep, optStr);
		optStr = cat(2, joined{:});
		if strcmp(Opt.InsteadOfPushUse, 'r')
			info.type = 'radio';
		else
			info.type = 'popup';
		end
		[info.labels, info.defaultIdx] = parsePipeString(optStr);
		return;
	elseif iscellstr(optStr)
		info.type = 'pushbutton';
		info.labels = optStr;
		return;
	end

	if isnumeric(optStr)
		info.type = 'slider';
		sv = optStr;
		if length(sv) == 2
			sv(3) = sv(1) + 0.5 * diff(sv);
		elseif length(sv) == 3
			if sv(3) > sv(2) || sv(3) < sv(1)
				sv(3) = sv(1) + 0.5 * diff(sv);
			end
		else
			error('menuNN:slider:Bad numeric input length.')
		end
		if sv(1) > sv(2)
			error('menuNN:slider:Start value must be less than end value.');
		end
		info.numericValue = sv;
		return;
	end

	if ischar(optStr) && length(optStr) >= 2
		prefix = optStr(1:2);
		switch prefix
			case 'r|'
				info.type = 'radio';
				[info.labels, info.defaultIdx] = parsePipeString(optStr(3:end));
			case 'p|'
				info.type = 'popup';
				[info.labels, info.defaultIdx] = parsePipeString(optStr(3:end));
			case 'x|'
				info.type = 'checkbox';
				[info.labels, info.defaultIdx] = parsePipeString(optStr(3:end));
			case 'l|'
				info.type = 'listbox';
				[info.labels, info.defaultIdx] = parsePipeString(optStr(3:end));
			case 't|'
				info.type = 'textarea';
				txt = optStr(3:end);
				% Strip ¤ markers
				txt(strfind(txt, '¤')) = [];
				pipeIdx = strfind(txt, '|');
				if ~isempty(pipeIdx)
					info.textValue = strrep(txt, '|', newline);
					info.isMultiline = true;
				else
					info.textValue = txt;
					info.isMultiline = false;
				end
			otherwise
				error('menuNN:input:Unknown option prefix "%s".', prefix);
		end
	else
		error('menuNN:input:Unrecognised option format.');
	end
end

function [labels, defaultIdx] = parsePipeString(str)
% parsePipeString Split a pipe-separated string and find ¤ defaults
	markedIdx = strfind(str, '¤');
	pipeIdxOrig = strfind(str, '|');

	% Remove ¤ markers
	str(markedIdx) = [];

	% Split on | using the modified string
	pipeIdx = strfind(str, '|');

	if isempty(pipeIdx)
		labels = {str};
		defaultIdx = [];
		return;
	end

	numItems = length(pipeIdx) + 1;
	bounds = [0, pipeIdx, length(str) + 1];
	labels = cell(1, numItems);
	for k = 1:numItems
		labels{k} = str(bounds(k)+1 : bounds(k+1)-1);
	end

	% Find defaults using original positions (before ¤ removal)
	defaultIdx = [];
	for k = 1:length(markedIdx)
		pos = markedIdx(k);
		matchIdx = find(pos >= pipeIdxOrig, 1, 'last');
		if isempty(matchIdx)
			idx = 1;
		else
			idx = matchIdx + 1;
		end
		defaultIdx = [defaultIdx, idx]; %#ok<AGROW>
	end
	defaultIdx = unique(defaultIdx);
end

function sout = setdefaultsstruct(s, sdef)
% SETDEFAULTSSTRUCT Merge user struct with defaults
	sout = sdef;
	for f = fieldnames(s)'
		sout.(f{1}) = s.(f{1});
	end
end
