function tittaCalCallback(titta_instance,currentPoint,posNorm,posPix,stage,calState)
global rM %our reward manager object
if strcmpi(stage,'cal')
    % this demo function is no-op for validation mode
    if calState.status==0
        status = 'ok';
		  if isa(rM,'arduinoManager')
			  timedTTL(rM);
		  end
    else
        status = sprintf('failed (%s)',calState.statusString);
    end
    titta_instance.sendMessage(sprintf('Calibration data collection status result for point %d, positioned at (%.2f,%.2f): %s',currentPoint,posNorm,status));
elseif strcmpi(stage,'val')
	if isa(rM,'arduinoManager')
		timedTTL(rM);
	end
end