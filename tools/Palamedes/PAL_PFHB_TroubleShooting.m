%Model fits are performed by PAL_PFHB_fitModel. In order to learn about how 
%to use PAL_PFHB_fitModel, type: help PAL_PFHB_fitModel.
%
%This not very well organized document serves the purpose of listing known 
%issues and give some trouble-shooting advice.
%
%The PAL_PFHB routines require a working intsallation of JAGS or cmdStan,
%https://sourceforge.net/projects/mcmc-jags/
%or
%https://mc-stan.org/users/interfaces/cmdstan.html
%respectively.
%
%In order to install Stan or JAGS please refer to the Stan or JAGS
%documentation. If you're on Linux, we found this particularly helpful to 
%install Stan:
%https://gist.github.com/lindemann09/5bead1ce0320974ac4f6
%(thanks to: O. Lindemann). Execute the 
%wget -P /tmp https://gist.githubusercontent.com/.....
%line at bottom of page in linux terminal and wait till it's done. Then
%open the file /tmp/install_CmdStan.sh in a text editor (e.g., type:
%'gedit /tmp/install_CmdStan.sh' in terminal), change the version number in
%line 9 to the most current version of Stan (go here to find out what most
%current version is: https://github.com/stan-dev/cmdstan/releases) and save
%then run 'sudo sh /tmp/install_CmdStan.sh' from terminal and wait.
%
%In case you installed Stan some other way and find that building an
%executable sampler from PAL_PFHB_fitModel takes a very long time and 
%produces seemingly endless text in the process, execute the command 
%'make build' in the folder in which Stan recides (in system terminal 
%window, not matlab terminal window). This will produce the same seemingly 
%endless stream of text but once completed, building executable in 
%PAL_PFHB_fitModel should be much faster.
%
%Before asking us why Palamedes won't work with Stan or JAGS make sure 
%Stan or JAGS is correctly installed (e.g., if the bernoulli example that
%comes with cmdStan doesn't work for you, cmdStan won't work for Palamedes 
%either). Refer to JAGS or Stan documentation to install JAGS or Stan. Note
%that the PAL_PFHB routines require the cmdStan to be installed in order to 
%use Stan.
%
%When MCMC sampling is done in parallel (not the default option), Stan or 
%JAGS output may not be visible depending on which combination of Octave, 
%Matlab, Linux OS, MAC OS, or Windows OS you are running PAL_PFHB_fitModel 
%from. In order to test whether Stan or JAGS is running or has crashed take 
%a look at how busy your processor cores are. As many sampling chains you 
%have started (default: 3) or as many processing cores as you have 
%(whichever is lesser) should be ~100% engaged while sampling takes place.
%
%Related: Matlab or Octave outsources sampling to Stan or JAGS, force-
%quitting Matlab or Octave does not necessarily force-quit Stan of JAGS
%once started. Take a look at how busy your processor cores are or what 
%processes are running to determine whether Stan or JAGS is still sampling.
%
%Some of the work done after MCMC sampling is complete (PAL_PFHB_fitModel 
%will say: 'Reading and Analyzing samples') takes VERY long under Octave
%(several times as long as under Matlab). Not sure yet why this is, will
%look into it.
%
%seeding MCMC sampler (using 'seed' argument in PAL_PFHB_fitModel may not
%work as intended. Looking into it.