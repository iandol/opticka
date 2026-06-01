function demoCompactEditableComboBox
% demoCompactEditableComboBox Demonstrate CompactEditableComboBox.
%
% Put this file, CompactEditableComboBox.m,
% CompactEditableComboBoxEventData.m, and compactEditableComboBox.html in
% the same folder, add that folder to your MATLAB path, then run:
%
%   demoCompactEditableComboBox

fig = uifigure('Name','CompactEditableComboBox demo', 'Position',[100 100 520 170]);
g = uigridlayout(fig, [3 2]);
g.Padding = [12 12 12 12];
g.RowHeight = {28, 28, '1x'};
g.ColumnWidth = {120, '1x'};

uilabel(g, 'Text','Compact field:', 'HorizontalAlignment','right');
combo = CompactEditableComboBox(g, ...
    'Items', {'V1','V2','V3','V4','MT','MST','IT'}, ...
    'Value', 'V4', ...
    'Placeholder', 'Select, type, or add...', ...
    'AllowCustomValue', true, ...
    'AllowDuplicateItems', false, ...
    'ShowEditButtons', true);
combo.Layout.Row = 1;
combo.Layout.Column = 2;

uilabel(g, 'Text','Current value:', 'HorizontalAlignment','right');
valueLabel = uilabel(g, 'Text', combo.Value);
valueLabel.Layout.Row = 2;
valueLabel.Layout.Column = 2;

logArea = uitextarea(g, 'Editable','off');
logArea.Layout.Row = 3;
logArea.Layout.Column = [1 2];

combo.ValueChangedFcn = @(src,event)onComboEvent('ValueChanged', src, event);
combo.ItemsChangedFcn = @(src,event)onComboEvent('ItemsChanged', src, event);
combo.ComponentChangedFcn = @(src,event)onComboEvent('ComponentChanged', src, event);

    function onComboEvent(name, src, event)
        valueLabel.Text = src.Value;
        msg = sprintf('%s | action=%s | value=%s | nItems=%d', ...
            name, event.Action, event.Value, numel(event.Items));
        logArea.Value = [{msg}; logArea.Value(:)];
    end
end
