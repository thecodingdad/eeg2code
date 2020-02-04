% Ensure the workspace is clear and open screens are closed
sca;
close all;
clearvars;
% add required paths
addpath('vepstim','inpout');

% Returns all available screen indizes
screens = Screen('Screens');
% Choose screen with max index
screenNumber = max(screens);

% settings = struct();
% settings.monitorResolution = [1920,1080];
% settings.monitorRefreshRate = 60;
% settings.stimulation = 'cvep';
% settings.layout = 'tetris2';
% settings.windowSize = [0,0,800,600];
% settings.startWait = 5;
% settings.trialTime = 60;
% settings.interTrialTime = 0.3;
% settings.trials = 2;

% initialize experiment object with TCP/IP server listening at port 3000
exp_obj = vep_experiment(screenNumber,'debug', false);

