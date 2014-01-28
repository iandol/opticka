function txt = lfpCursor(empt, event_obj)
% Customizes text of data tips
pos = get(event_obj,'Position');
tag = get(event_obj.Target,'Tag');
txt = {['X: ',num2str(pos(1))],...
	   ['Y: ',num2str(pos(2))],...
	   ['TAG: ' tag]};
end