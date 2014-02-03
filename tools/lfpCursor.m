function txt = lfpCursor(empt, event_obj)
% Customizes text of data tips
persistent toggle
if isempty(toggle)
	toggle = cputime;
end

pos = get(event_obj,'Position');
tag = get(event_obj.Target,'Tag');
txt = {['X: ',num2str(pos(1))],...
	   ['Y: ',num2str(pos(2))],...
	   ['TAG: ' tag]};
if cputime > toggle+0.5
	lw = get(event_obj.Target,'LineWidth');
	if lw > 1
		set(event_obj.Target,'LineWidth',0.5);
	else
		set(event_obj.Target,'LineWidth',3);
	end
	drawnow;
end
end