classdef CompactEditableComboBox < matlab.ui.componentcontainer.ComponentContainer
    %CompactEditableComboBox Compact App Designer component using uihtml + MATLAB popup menu.
    %
    % This component keeps the HTML part short (one row) and opens the
    % option list as a MATLAB uicontextmenu. The menu is opened in the
    % parent uifigure, so it is not clipped by the uihtml component bounds.
    %
    % Required files in the same folder:
    %   CompactEditableComboBox.m
    %   CompactEditableComboBoxEventData.m
    %   compactEditableComboBox.html

    properties
        %Items Options shown in the combo box.
        Items cell = {}

        %Value Current value.
        Value char = ''

        %Placeholder Placeholder text in the edit field.
        Placeholder char = 'Select or type...'

        %Label Optional label shown to the left of the compact HTML field.
        Label char = ''

        %AllowCustomValue Allow values that are not already in Items.
        AllowCustomValue (1,1) logical = true

        %AllowDuplicateItems Allow duplicate entries in Items.
        AllowDuplicateItems (1,1) logical = false

        %Enabled Enable user interaction.
        Enabled (1,1) logical = true

        %ShowEditButtons Show add, rename, and delete mini-buttons in HTML.
        ShowEditButtons (1,1) logical = true

        %MaxMenuItems Maximum number of items to place directly in the popup menu.
        MaxMenuItems (1,1) double {mustBeInteger, mustBePositive} = 40

        %Debug Print uihtml/menu diagnostics to the Command Window.
        Debug (1,1) logical = false
    end

    properties (SetAccess = private)
        %SelectedIndex One-based index into Items. Zero means no matching item.
        SelectedIndex (1,1) double = 0

        %LastHTMLEventName Last event name received from JavaScript.
        LastHTMLEventName char = ''

        %LastMenuOpenPosition Last computed context-menu position in figure pixels.
        LastMenuOpenPosition (1,2) double = [NaN NaN]

        %LastHTMLData Last Data payload received from JavaScript.
        LastHTMLData = struct()
    end

    properties (Access = private)
        Grid
        LabelControl
        HTML
        Menu
        IsInternalUpdate (1,1) logical = false
    end

    events (HasCallbackProperty, NotifyAccess = protected)
        ValueChanged
        ValueEdited
        ItemsChanged
        ComponentChanged
    end

    methods
        function set.Items(obj, value)
            obj.Items = obj.normalizeItems(value);
            if ~obj.AllowDuplicateItems
                obj.Items = obj.uniqueStable(obj.Items);
            end
            obj.refreshSelectedIndex();
        end

        function set.Value(obj, value)
            if isempty(value)
                obj.Value = '';
            else
                obj.Value = char(string(value));
            end
            obj.refreshSelectedIndex();
        end

        function set.Placeholder(obj, value)
            obj.Placeholder = char(string(value));
        end

        function set.Label(obj, value)
            obj.Label = char(string(value));
        end

        function set.AllowDuplicateItems(obj, value)
            obj.AllowDuplicateItems = logical(value);
            if ~obj.AllowDuplicateItems
                obj.Items = obj.uniqueStable(obj.Items);
            end
            obj.refreshSelectedIndex();
        end

        function set.AllowCustomValue(obj, value)
            obj.AllowCustomValue = logical(value);
            obj.refreshSelectedIndex();
        end

        function set.Enabled(obj, value)
            obj.Enabled = logical(value);
        end

        function set.ShowEditButtons(obj, value)
            obj.ShowEditButtons = logical(value);
        end

        function set.Debug(obj, value)
            obj.Debug = logical(value);
        end
    end

    methods
        function debugOpenMenu(obj)
            %debugOpenMenu Programmatically open the popup menu for diagnostics.
            if isempty(obj.HTML) || ~isvalid(obj.HTML)
                error('CompactEditableComboBox:NoHTML','The internal uihtml object has not been created yet.');
            end
            p = obj.safePixelPosition(obj.HTML);
            payload = struct('x', max(1, p(3)-4), 'y', max(1, p(4)/2), ...
                'value', obj.Value, 'items', {obj.Items}, 'lastAction', 'debugOpenMenu');
            obj.openOptionsMenu(payload);
        end

        function printDebugStatus(obj)
            %printDebugStatus Print the most useful component diagnostics.
            fprintf('CompactEditableComboBox debug status:\n');
            fprintf('  Debug: %d\n', obj.Debug);
            fprintf('  Enabled: %d\n', obj.Enabled);
            fprintf('  Items: %d\n', numel(obj.Items));
            fprintf('  Value: %s\n', obj.Value);
            fprintf('  SelectedIndex: %d\n', obj.SelectedIndex);
            fprintf('  LastHTMLEventName: %s\n', obj.LastHTMLEventName);
            fprintf('  LastMenuOpenPosition: [%.1f %.1f]\n', obj.LastMenuOpenPosition(1), obj.LastMenuOpenPosition(2));
            if ~isempty(obj.HTML) && isvalid(obj.HTML)
                p = obj.safePixelPosition(obj.HTML);
                fprintf('  uihtml pixel position in figure: [%.1f %.1f %.1f %.1f]\n', p(1), p(2), p(3), p(4));
                fprintf('  HTMLSource: %s\n', string(obj.HTML.HTMLSource));
                fprintf('  DataChangedFcn set: %d\n', ~isempty(obj.HTML.DataChangedFcn));
                fprintf('  HTMLEventReceivedFcn set: %d\n', ~isempty(obj.HTML.HTMLEventReceivedFcn));
            else
                fprintf('  Internal uihtml object is empty or invalid.\n');
            end
        end
    end

    methods (Access = protected)
        function setup(obj)
            obj.Grid = uigridlayout(obj, [1 2]);
            obj.Grid.Padding = [0 0 0 0];
            obj.Grid.RowHeight = {'1x'};
            obj.Grid.ColumnSpacing = 4;
            obj.Grid.ColumnWidth = {0, '1x'};

            obj.LabelControl = uilabel(obj.Grid, ...
                'Text', obj.Label, ...
                'HorizontalAlignment', 'right', ...
                'VerticalAlignment', 'center');
            obj.LabelControl.Layout.Row = 1;
            obj.LabelControl.Layout.Column = 1;

            htmlFile = fullfile(fileparts(mfilename('fullpath')), 'compactEditableComboBox.html');
            obj.HTML = uihtml(obj.Grid, ...
                'HTMLSource', htmlFile, ...
                'DataChangedFcn', @(src, event)obj.onHTMLDataChanged(event), ...
                'HTMLEventReceivedFcn', @(src, event)obj.onHTMLEventReceived(event));
            obj.HTML.Layout.Row = 1;
            obj.HTML.Layout.Column = 2;
        end

        function update(obj)
            if isempty(obj.Grid) || ~isvalid(obj.Grid)
                return
            end

            if isempty(strtrim(obj.Label))
                obj.Grid.ColumnWidth = {0, '1x'};
            else
                obj.Grid.ColumnWidth = {'fit', '1x'};
            end

            obj.LabelControl.Text = obj.Label;
            obj.LabelControl.Enable = matlab.lang.OnOffSwitchState(obj.Enabled);

            obj.refreshSelectedIndex();
            obj.pushDataToHTML('MATLABUpdate');
        end
    end

    methods (Access = private)
        function onHTMLDataChanged(obj, event)
            if obj.IsInternalUpdate
                if obj.Debug
                    disp('[CompactEditableComboBox] Ignored internal DataChangedFcn update')
                end
                return
            end

            data = event.Data;
            obj.LastHTMLData = data;
            if obj.Debug
                disp('[CompactEditableComboBox] DataChangedFcn received data:')
                disp(data)
            end
            if isempty(data) || ~isstruct(data)
                return
            end

            oldValue = obj.Value;
            oldItems = obj.Items;

            value = obj.getField(data, 'value', obj.Value);
            value = char(string(value));

            if ~obj.AllowCustomValue && ~isempty(value) && ~ismember(value, obj.Items)
                value = oldValue;
            end

            if isfield(data, 'items')
                items = obj.normalizeItems(data.items);
            else
                items = obj.Items;
            end

            if ~obj.AllowDuplicateItems
                items = obj.uniqueStable(items);
            end

            action = char(string(obj.getField(data, 'lastAction', 'HTMLDataChanged')));

            obj.IsInternalUpdate = true;
            cleanup = onCleanup(@()setInternalUpdateFalse(obj));
            obj.Items = items;
            obj.Value = value;
            obj.refreshSelectedIndex();
            delete(cleanup);

            if ~isequal(oldValue, obj.Value)
                obj.notifyComponentEvent('ValueChanged', action, data);
            end
            if ~isequal(oldItems, obj.Items)
                obj.notifyComponentEvent('ItemsChanged', action, data);
            end
            obj.notifyComponentEvent('ComponentChanged', action, data);

            % Push back after validation/coercion, for example when
            % AllowCustomValue=false rejects an HTML-typed value.
            obj.pushDataToHTML(action);

            function setInternalUpdateFalse(o)
                o.IsInternalUpdate = false;
            end
        end

        function onHTMLEventReceived(obj, event)
            name = char(string(event.HTMLEventName));
            data = event.HTMLEventData;
            obj.LastHTMLEventName = name;
            if obj.Debug
                fprintf('[CompactEditableComboBox] HTMLEventReceivedFcn: %s\n', name);
                disp(data)
            end

            switch name
                case 'OpenOptionsMenu'
                    obj.openOptionsMenu(data)
                case 'AddCurrentItem'
                    obj.addCurrentValue()
                case 'RenameSelectedItem'
                    obj.renameSelectedItem()
                case 'DeleteSelectedItem'
                    obj.deleteSelectedItem()
                case 'ValueCommitted'
                    % DataChangedFcn handles the value synchronization.
                otherwise
                    obj.notifyComponentEvent('ComponentChanged', name, data);
            end
        end

        function openOptionsMenu(obj, data)
            if ~obj.Enabled
                if obj.Debug
                    disp('[CompactEditableComboBox] Menu open ignored because Enabled=false')
                end
                return
            end

            fig = ancestor(obj.HTML, 'figure');
            if isempty(fig) || ~isvalid(fig)
                if obj.Debug
                    disp('[CompactEditableComboBox] Could not find parent uifigure')
                end
                return
            end

            if isempty(obj.Menu) || ~isvalid(obj.Menu) || ~isequal(obj.Menu.Parent, fig)
                obj.Menu = uicontextmenu(fig);
            end
            delete(obj.Menu.Children);

            items = obj.Items;
            nItems = numel(items);
            nShown = min(nItems, obj.MaxMenuItems);

            if nShown == 0
                uimenu(obj.Menu, 'Text', '(no items)', 'Enable', 'off');
            else
                for k = 1:nShown
                    txt = obj.menuText(items{k});
                    checked = obj.onOff(strcmp(items{k}, obj.Value));
                    itemValue = items{k};
                    uimenu(obj.Menu, ...
                        'Text', txt, ...
                        'Checked', checked, ...
                        'MenuSelectedFcn', @(src, evt)obj.selectValue(itemValue));
                end

                if nItems > nShown
                    uimenu(obj.Menu, ...
                        'Text', sprintf('... %d more items; type to filter/select', nItems - nShown), ...
                        'Enable', 'off');
                end
            end

            uimenu(obj.Menu, ...
                'Text', 'Add typed value', ...
                'Separator', 'on', ...
                'Enable', obj.onOff(~isempty(strtrim(obj.Value))), ...
                'MenuSelectedFcn', @(src, evt)obj.addCurrentValue());

            uimenu(obj.Menu, ...
                'Text', 'Add new option...', ...
                'MenuSelectedFcn', @(src, evt)obj.addNewItem());

            uimenu(obj.Menu, ...
                'Text', 'Rename selected option...', ...
                'Enable', obj.onOff(obj.SelectedIndex > 0), ...
                'MenuSelectedFcn', @(src, evt)obj.renameSelectedItem());

            uimenu(obj.Menu, ...
                'Text', 'Delete selected option', ...
                'Enable', obj.onOff(obj.SelectedIndex > 0), ...
                'MenuSelectedFcn', @(src, evt)obj.deleteSelectedItem());

            uimenu(obj.Menu, ...
                'Text', 'Manage all options...', ...
                'Separator', 'on', ...
                'MenuSelectedFcn', @(src, evt)obj.manageItems());

            % The context menu open coordinates are figure pixel coordinates
            % measured from the lower-left corner of the uifigure.  The HTML
            % event supplies browser viewport coordinates measured from the
            % upper-left corner of the uihtml document, so y must be inverted.
            p = obj.safePixelPosition(obj.HTML);
            figPos = fig.Position;
            xLocal = obj.getNumericField(data, 'x', max(1, p(3)-4));
            yLocal = obj.getNumericField(data, 'y', max(1, p(4)/2));
            xLocal = max(1, min(p(3), xLocal));
            yLocal = max(1, min(p(4), yLocal));

            xOpen = round(p(1) + xLocal);
            yOpen = round(p(2) + p(4) - yLocal);

            % If x/y are outside the figure, MATLAB's open() can succeed but
            % the menu is invisible. Clamp to the visible figure area.
            xOpen = max(1, min(round(figPos(3)-2), xOpen));
            yOpen = max(1, min(round(figPos(4)-2), yOpen));
            obj.LastMenuOpenPosition = [xOpen yOpen];

            if obj.Debug
                fprintf('[CompactEditableComboBox] Opening context menu at figure pixels [%d %d]; uihtml=[%.1f %.1f %.1f %.1f]; nChildren=%d\n', ...
                    xOpen, yOpen, p(1), p(2), p(3), p(4), numel(obj.Menu.Children));
            end

            drawnow limitrate
            open(obj.Menu, xOpen, yOpen);
        end

        function selectValue(obj, value)
            oldValue = obj.Value;
            obj.Value = value;
            obj.refreshSelectedIndex();
            obj.pushDataToHTML('ValueChanged');

            if ~strcmp(oldValue, obj.Value)
                obj.notifyComponentEvent('ValueChanged', 'ValueChanged', struct());
            end
            obj.notifyComponentEvent('ComponentChanged', 'ValueChanged', struct());
        end

        function addCurrentValue(obj)
            value = strtrim(obj.Value);
            if isempty(value)
                obj.addNewItem();
                return
            end
            obj.addItemAndSelect(value, 'ItemAdded');
        end

        function addNewItem(obj)
            answer = inputdlg({'New option:'}, 'Add Option', [1 50], {obj.Value});
            if isempty(answer)
                return
            end
            value = strtrim(answer{1});
            if isempty(value)
                return
            end
            obj.addItemAndSelect(value, 'ItemAdded');
        end

        function addItemAndSelect(obj, value, action)
            oldItems = obj.Items;
            oldValue = obj.Value;

            if ~obj.AllowDuplicateItems
                existing = find(strcmp(obj.Items, value), 1, 'first');
                if isempty(existing)
                    obj.Items{end+1} = value;
                end
            else
                obj.Items{end+1} = value;
            end
            obj.Value = value;
            obj.refreshSelectedIndex();
            obj.pushDataToHTML(action);

            if ~isequal(oldItems, obj.Items)
                obj.notifyComponentEvent('ItemsChanged', action, struct());
            end
            if ~strcmp(oldValue, obj.Value)
                obj.notifyComponentEvent('ValueChanged', action, struct());
            end
            obj.notifyComponentEvent('ComponentChanged', action, struct());
        end

        function renameSelectedItem(obj)
            idx = obj.SelectedIndex;
            if idx < 1 || idx > numel(obj.Items)
                return
            end

            oldItem = obj.Items{idx};
            answer = inputdlg({'Rename selected option:'}, 'Rename Option', [1 60], {oldItem});
            if isempty(answer)
                return
            end
            newItem = strtrim(answer{1});
            if isempty(newItem) || strcmp(newItem, oldItem)
                return
            end

            if ~obj.AllowDuplicateItems && any(strcmp(obj.Items, newItem))
                obj.Value = newItem;
            else
                obj.Items{idx} = newItem;
                obj.Value = newItem;
            end
            obj.refreshSelectedIndex();
            obj.pushDataToHTML('ItemRenamed');
            obj.notifyComponentEvent('ItemsChanged', 'ItemRenamed', struct('OldItem', oldItem, 'NewItem', newItem));
            obj.notifyComponentEvent('ValueChanged', 'ItemRenamed', struct('OldItem', oldItem, 'NewItem', newItem));
            obj.notifyComponentEvent('ComponentChanged', 'ItemRenamed', struct('OldItem', oldItem, 'NewItem', newItem));
        end

        function deleteSelectedItem(obj)
            idx = obj.SelectedIndex;
            if idx < 1 || idx > numel(obj.Items)
                return
            end

            deletedItem = obj.Items{idx};
            obj.Items(idx) = [];

            if strcmp(obj.Value, deletedItem)
                if idx <= numel(obj.Items)
                    obj.Value = obj.Items{idx};
                elseif ~isempty(obj.Items)
                    obj.Value = obj.Items{end};
                else
                    obj.Value = '';
                end
            end

            obj.refreshSelectedIndex();
            obj.pushDataToHTML('ItemDeleted');
            obj.notifyComponentEvent('ItemsChanged', 'ItemDeleted', struct('DeletedItem', deletedItem));
            obj.notifyComponentEvent('ValueChanged', 'ItemDeleted', struct('DeletedItem', deletedItem));
            obj.notifyComponentEvent('ComponentChanged', 'ItemDeleted', struct('DeletedItem', deletedItem));
        end

        function manageItems(obj)
            defaultText = strjoin(obj.Items, newline);
            answer = inputdlg({'Options, one per line:'}, 'Manage Options', [10 60], {defaultText});
            if isempty(answer)
                return
            end

            lines = regexp(answer{1}, '\r\n|\n|\r', 'split');
            lines = cellfun(@strtrim, lines, 'UniformOutput', false);
            lines = lines(~cellfun(@isempty, lines));
            if ~obj.AllowDuplicateItems
                lines = obj.uniqueStable(lines);
            end

            oldItems = obj.Items;
            oldValue = obj.Value;
            obj.Items = lines;
            if ~isempty(obj.Value) && ~obj.AllowCustomValue && ~ismember(obj.Value, obj.Items)
                if isempty(obj.Items)
                    obj.Value = '';
                else
                    obj.Value = obj.Items{1};
                end
            end
            obj.refreshSelectedIndex();
            obj.pushDataToHTML('ItemsManaged');

            if ~isequal(oldItems, obj.Items)
                obj.notifyComponentEvent('ItemsChanged', 'ItemsManaged', struct());
            end
            if ~strcmp(oldValue, obj.Value)
                obj.notifyComponentEvent('ValueChanged', 'ItemsManaged', struct());
            end
            obj.notifyComponentEvent('ComponentChanged', 'ItemsManaged', struct());
        end

        function pushDataToHTML(obj, action)
            if isempty(obj.HTML) || ~isvalid(obj.HTML)
                return
            end

            data = struct();
            data.items = obj.Items;
            data.value = obj.Value;
            data.selectedIndex = obj.SelectedIndex;
            data.placeholder = obj.Placeholder;
            data.allowCustomValue = obj.AllowCustomValue;
            data.allowDuplicateItems = obj.AllowDuplicateItems;
            data.enabled = obj.Enabled;
            data.showEditButtons = obj.ShowEditButtons;
            data.lastAction = action;

            obj.IsInternalUpdate = true;
            cleanup = onCleanup(@()setInternalUpdateFalse(obj));
            obj.HTML.Data = data;
            delete(cleanup);

            function setInternalUpdateFalse(o)
                o.IsInternalUpdate = false;
            end
        end

        function notifyComponentEvent(obj, eventName, action, data)
            ed = CompactEditableComboBoxEventData(obj.Value, obj.Items, obj.SelectedIndex, action, data);
            notify(obj, eventName, ed);
        end

        function refreshSelectedIndex(obj)
            idx = find(strcmp(obj.Items, obj.Value), 1, 'first');
            if isempty(idx)
                obj.SelectedIndex = 0;
            else
                obj.SelectedIndex = idx;
            end
        end
    end

    methods (Static, Access = private)
        function items = normalizeItems(value)
            if isempty(value)
                items = {};
                return
            end

            if isstring(value)
                items = cellstr(value(:).');
            elseif ischar(value)
                items = {value};
            elseif iscell(value)
                items = cellfun(@(x) char(string(x)), value(:).', 'UniformOutput', false);
            else
                items = cellstr(string(value(:).'));
            end

            items = cellfun(@strtrim, items, 'UniformOutput', false);
            items = items(~cellfun(@isempty, items));
        end

        function items = uniqueStable(items)
            [~, idx] = unique(items, 'stable');
            items = items(sort(idx));
        end

        function p = safePixelPosition(h)
            try
                p = getpixelposition(h, true);
            catch
                p = h.Position;
            end
            p = double(p);
            if numel(p) ~= 4 || any(~isfinite(p))
                p = [1 1 100 24];
            end
        end

        function value = getField(data, fieldName, defaultValue)
            if isstruct(data) && isfield(data, fieldName)
                value = data.(fieldName);
            else
                value = defaultValue;
            end
        end

        function value = getNumericField(data, fieldName, defaultValue)
            value = defaultValue;
            if isstruct(data) && isfield(data, fieldName)
                tmp = data.(fieldName);
                if isnumeric(tmp) && isscalar(tmp) && isfinite(tmp)
                    value = tmp;
                else
                    tmp = str2double(string(tmp));
                    if isfinite(tmp)
                        value = tmp;
                    end
                end
            end
        end

        function s = onOff(tf)
            if tf
                s = 'on';
            else
                s = 'off';
            end
        end

        function txt = menuText(value)
            txt = char(string(value));
            txt = strrep(txt, newline, ' ');
            if strlength(string(txt)) > 60
                txt = char(extractBefore(string(txt), 58) + "...");
            end
        end
    end
end
