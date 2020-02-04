% Ensure the workspace is clear
clearvars;
% add required paths
addpath('vepstim','vepstim/layouts','vepstim/stimulations');

% define some experimental settings (see section 3.2)
settings = struct();
settings.monitorResolution = [1920,1080];
settings.monitorRefreshRate = 60;
settings.stimulation = 'cvep';
settings.layout = 'tetris2';
settings.windowSize = [0,0,800,600];
settings.startWait = 5;
settings.trialTime = 60;
settings.interTrialTime = 0.3;
settings.trials = 2;

% initialize operator object with debug enabled
op_obj = vep_operator('127.0.0.1:3000','settings',settings,'debug',false);

% start the experiment, doesn't block!
op_obj.start();

% now you can send some commands, like choosing a target (of course, this should be done by your classifier :))
% first wait 15 seconds
%pause(15);

% Now write some letters and highlight target for 100 ms. Wait 2 seconds after each.
%op_obj.chooseTarget(8,0.1); pause(2);
%op_obj.chooseTarget(1,0.1); pause(2);
%op_obj.chooseTarget(12,0.1); pause(2);
%op_obj.chooseTarget(12,0.1); pause(2);
%op_obj.chooseTarget(15,0.1); pause(2);

% terminate experiment and close window
%op_obj.exit()