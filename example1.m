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
settings.monitorRefreshRate = 60;
settings.stimulation = 'optimal';
settings.layout = 'qwertz';
settings.windowSize = 'fullscreen';
settings.startWait = 0;
settings.trialTime = 10;
settings.interTrialTime = 0.3;
settings.trials = 1;

settings.weight_step_size = 0.5;
% 
% bit_size = 20;
% sequence_number = 100;
% max_correlation_coef = 0.6;
% seq_generator(sequence_number, bit_size, max_correlation_coef);

settings.stimSettings.monitorRefreshRate = 60;
settings.stimSettings.framesPerStimulus = 1;

layout.numTargets = 55.0;
stimulation = feval(['stimulation_' settings.stimulation],layout.numTargets,settings.stimSettings);
stimulation.setTargetSequences();

% indeces = stimulation.weights(:, 1)/stimulation.weights(41, 1) < 0.3;
% stimulation.weights(indeces, 1)
% [m,i] = max(stimulation.weights(:, 1))

% initialize experiment object without TCP/IP server and debug enabled
experiment = vep_experiment(screenNumber,'tcpip',false,'settings',settings,'debug',false);
% Save screenshot
%imageArray = Screen('GetImage', experiment.layout.windowPtr, [0 0 1920 1080]);
%imwrite(imageArray, 'qwertz.jpg')

experiment.start();

% Close the window after experiment.
experiment.exit();