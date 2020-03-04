settings.stimulation = 'optimal';
settings.trials = 1;
settings.stimSettings.monitorRefreshRate = 60;
settings.stimSettings.framesPerStimulus = 1;
settings.stimSettings.trials = 2000;
settings.saveDir = './weight_update_data/approach_test';
layout.numTargets = 1.0;
seq_bit_acc = csvread('random_seq_bit_acc_demo.csv');

tic;
stimulation = feval(['stimulation_' settings.stimulation],layout.numTargets,settings.stimSettings);
rng(0,'twister');
for i=1:settings.stimSettings.trials

    stimulation.setTargetSequences();
    max_r = seq_bit_acc(1,stimulation.subset);
    min_r = seq_bit_acc(2,stimulation.subset);
    r = (max_r-min_r).*rand(1,1) + min_r;
    
    stimulation.updateWeights(r, 1);
end
stop = toc;
disp('duration: ' + string(stop));
disp('single trial: ' + string((stop)/settings.stimSettings.trials));
stimulation.save('1', settings.saveDir);
% figure
% plot(1-(1/3).*log10((1000:-1:1)))
% 
% array = (1:5000);
% array = (array - min(array))./(max(array) - min(array)).*(0 + 6) - 6;
% array = array ./ sqrt((1+array.^2));
% 
% figure
% plot(1 + array)

