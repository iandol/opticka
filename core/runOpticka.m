% Note, this is used only for App deployment
disp('===>>> Running Opticka via App Deployment…');
disp(['===>>> $HOME is: ' getenv('HOME')]);
disp(['===>>> App root is: ' ctfroot]);
disp(['===>>> PTB root is: ' PsychtoolboxRoot]);
disp(['===>>> PTB config is: ' PsychtoolboxConfigDir]);
o=opticka;
disp(['===>>> Opticka Version is: ' num2str(o.optickaVersion)]);