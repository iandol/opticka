% Used for App deployment
disp('===>>> Running Opticka via App Deployment…');
disp(['===>>> Home is: ' getenv('HOME')]);
disp(['===>>> App root is: ' ctfroot]);
disp(['===>>> PTB root is: ' PsychtoolboxRoot]);
disp(['===>>> PTB config is: ' PsychtoolboxConfigDir]);
opticka;