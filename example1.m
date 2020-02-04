% Ensure the workspace is clear and open screens are closed
sca;
close all;
clearvars;

% add required paths
addpath('inpout','vepstim');

% Returns all available screen indizes
screens = Screen('Screens');
% Choose screen with max index
screenNumber = max(screens);

% define some experimental settings (see section 3.2)
settings = struct();
settings.monitorResolution = [1920,1080];
settings.monitorRefreshRate = 10;
settings.stimulation = 'random';
settings.layout = 'keyboard';
settings.windowSize = 'fullscreen';
settings.startWait = 0;
settings.trialTime = 10;
settings.interTrialTime = 0.3;
settings.trials = 1;

% initialize experiment object without TCP/IP server and debug enabled
experiment = vep_experiment(screenNumber,'tcpip',false,'settings',settings,'debug',false);
% Save screenshot
%imageArray = Screen('GetImage', experiment.layout.windowPtr, [0 0 1920 1080]);
%imwrite(imageArray, 'qwertz.jpg')

experiment.start();

% Close the window after experiment.
experiment.exit();