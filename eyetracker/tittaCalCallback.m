function tittaCalCallback(titta_instance,currentPoint,posNorm,posPix,stage,calState)
global rM aM %our reward manager and audio manager object
if strcmpi(stage,'cal')
    % this demo function is no-op for validation mode
    if calState.status==0
        status = 'ok';
		  if isa(rM,'arduinoManager') && rM.isOpen
			  giveReward(rM);
			  try beep(aM,2000,0.1,0.1); end
			  fprintf('--->>> Calibration reward!\n');
		  end
    else
        status = sprintf('failed (%s)',calState.statusString);
		fprintf('--->>> NO Calibration reward!\n');
    end
    titta_instance.sendMessage(sprintf('Calibration data collection status result for point %d, positioned at (%.2f,%.2f): %s',currentPoint,posNorm,status));
elseif strcmpi(stage,'val')
	if calState.status==0
		if isa(rM,'arduinoManager')  && rM.isOpen
			giveReward(rM);
			try beep(aM,2000,0.1,0.1); end
			fprintf('--->>> Validation reward!\n');
		end
	else
		fprintf('--->>> NO Validation reward!\n');
	end
end