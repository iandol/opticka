classdef magstimManager < optickaCore
	%UNTITLED Summary of this class goes here
	%   Detailed explanation goes here
	
	properties
		%>which FIO line to use for the MagStim
		defaultTTL = 2 
		%> silentMode allows one to gracefully fail methods without a dataPixx connected
		silentMode = false
		%> labJack to use
		lJ 
		%> time to stimulate
		stimulateTime = 60
		%> frequency to stimulate at
		frequency = 0.7
		%>time of reward
		rewardTime = 25
		%> verbose or not
		verbose = false
	end
	
	properties (SetAccess = protected, GetAccess = public)
		isOpen = false
	end
	
	properties (SetAccess = private, GetAccess = private)
		%> properties allowed to be modified during construction
		allowedProperties='silentMode|verbose|defaultTTL|lJ'
	end
	
	methods
		% ===================================================================
		%> @brief Delete method
		%>
		% ===================================================================
		function obj = magstimManager(varargin)
			if nargin == 0; varargin.name = 'MagStim Manager'; end
			obj=obj@optickaCore(varargin); %superclass constructor
			if nargin > 0; obj.parseArgs(varargin,obj.allowedProperties); end
		end
		
		% ===================================================================
		%> @brief Delete method
		%>
		% ===================================================================
		function open(obj)
			obj.isOpen = false;
			if obj.silentMode == false
				try
					if isa(obj.lJ,'labJack') 
						if ~obj.lJ.isOpen
							open(obj.lJ);
						end
						if ~obj.lJ.isOpen
							error('Can''t open labJack')
						end
						obj.silentMode = false;
						obj.isOpen = true;
					else
						obj.salutation('open method','Couldn''t connect to LabJack, switching into silent mode',true);
						obj.silentMode = true;
						obj.isOpen = false;
					end
				catch %#ok<CTCH>
					obj.salutation('open method','Couldn''t connect to LabJack, switching into silent mode',true);
					obj.silentMode = true;
					obj.isOpen = false;
				end
			end
			end
		
		% ===================================================================
		%> @brief Delete method
		%>
		% ===================================================================
		function close(obj)
			if obj.isOpen
				obj.salutation('close method','Closing magstimManager...',true);
				obj.isOpen = false;
			end
		end
		
		% ===================================================================
		%> @brief Delete method
		%>
		% ===================================================================
		function delete(obj)
			close(obj);
			obj.salutation('DELETE method',[obj.fullName ' has been closed/reset...']);
		end
		
		% ===================================================================
		%> @brief Delete method
		%>
		% ===================================================================
		function stimulate(obj)
			if obj.isOpen && obj.silentMode == false
				t1 = GetSecs;
				tNow = t1;
				timeToWait = 1 / obj.frequency;
				loopReward = floor(obj.rewardTime / timeToWait);
				rloop = 1;
				while tNow <= t1+obj.stimulateTime
					timedTTL(obj.lJ, obj.defaultTTL, 2);
					WaitSecs(0.01)
					if rloop >= loopReward
						timedTTL(obj.lJ, 0, 160);
						rloop = 1;
					end
					WaitSecs(timeToWait-0.01);
					tNow=GetSecs;
					rloop = rloop + 1;
					fprintf('->Time of Stimulation: %i seconds\n',tNow-t1)
				end
				fprintf('===>>>MagStim FINISHED\n')
			end
		end
		
	end
	
end

