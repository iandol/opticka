classdef CompactEditableComboBoxEventData < event.EventData
    %CompactEditableComboBoxEventData Event data for CompactEditableComboBox.

    properties
        Value char = ''
        Items cell = {}
        SelectedIndex double = 0
        Action char = ''
        Data = struct()
    end

    methods
        function obj = CompactEditableComboBoxEventData(value, items, selectedIndex, action, data)
            if nargin >= 1 && ~isempty(value)
                obj.Value = char(string(value));
            end
            if nargin >= 2 && ~isempty(items)
                if isstring(items)
                    obj.Items = cellstr(items(:).');
                elseif ischar(items)
                    obj.Items = {items};
                elseif iscell(items)
                    obj.Items = cellfun(@(x) char(string(x)), items(:).', 'UniformOutput', false);
                else
                    obj.Items = cellstr(string(items(:).'));
                end
            end
            if nargin >= 3 && ~isempty(selectedIndex)
                obj.SelectedIndex = selectedIndex;
            end
            if nargin >= 4 && ~isempty(action)
                obj.Action = char(string(action));
            end
            if nargin >= 5
                obj.Data = data;
            end
        end
    end
end
