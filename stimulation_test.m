settings.stimulation = 'optimal';
settings.trials = 1;
settings.stimSettings.monitorRefreshRate = 60;
settings.stimSettings.framesPerStimulus = 1;
layout.numTargets = 1.0;
number_of_trials = 1000;
save_dir = './weight_update_data/approach_test';
seq_bit_acc = csvread('random_seq_bit_acc_demo.csv');

stimulation = feval(['stimulation_' settings.stimulation],layout.numTargets,settings.stimSettings);
rng(0,'twister');
number_of_trials = 1000;
for i=1:number_of_trials

    stimulation.setTargetSequences();
    max_r = seq_bit_acc(1,stimulation.subset);
    min_r = seq_bit_acc(2,stimulation.subset);
    r = (max_r-min_r).*rand(1,1) + min_r;
    
    stimulation.updateWeights(r, 1, number_of_trials, i);
end
stimulation.save('1', number_of_trials, save_dir);

figure
plot(1.-(1/10).*log2((1000:-1:1)))