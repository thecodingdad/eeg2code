approach = 'approach_test';
data_loc = './weight_update_data/';
full_path = strcat(data_loc, approach);
initial_pool = csvread(strcat(data_loc,'random_seq_pool_init.csv'));
% seq_bit_acc = csvread('random_seq_bit_acc_demo.csv');
number_of_trials = 2000;

approach_files = dir(fullfile(full_path, '*.csv'));
approach_files = {approach_files.name};

weight_update = zeros(2,100,size(approach_files,2)/2);
bit_acc = zeros(number_of_trials,4,size(approach_files,2)/2);

for i = 1:size(approach_files,2)/2
    file_name_weight = strcat('r_', string(i), '_tr_', string(i*number_of_trials), '_new_weights.csv');
    file_name_bitacc = strcat('r_', string(i), '_tr_', string(i*number_of_trials), '_bit_acc_weight.csv');
    
    weight_update(:,:,i) = csvread(strcat(full_path,'/',file_name_weight));
    bit_acc(:,:,i) = csvread(strcat(full_path,'/',file_name_bitacc));
end
% 
% figure;
% plot(transpose(seq_bit_acc));
weights_each_iter = ones(size(bit_acc(:,4,:),1),100)./100;
average_bit_acc_over_iter = zeros(size(bit_acc(:,4,:)));

for i=1:size(bit_acc(:,4,:),1)
    weights_each_iter(i,bit_acc(i,2,:)) = bit_acc(i,4,:);
    
    weights_each_iter(i+1:size(bit_acc(:,4,:),1),bit_acc(i,2,:)) = bit_acc(i,4,:);
    
    average_bit_acc_over_iter(i) = mean(bit_acc(1:i,1,:));
end

sum(weight_update(2,:,1) == 0)
sz = 15;
figure;
subplot(2,2,1)
scatter(1:100,squeeze(weight_update(1,:,:)),sz,'filled');
hold on 
m_x = mean(squeeze(weight_update(1,:,:)));
plot(1:100,ones(length(1:100),1)*m_x);
title('Weights after '+string(number_of_trials)+' iter');

subplot(2,2,2)
scatter(1:100,squeeze(weight_update(2,:,:)),sz,'filled');
title('Sampled count after '+string(number_of_trials)+' iter');

subplot(2,2,3)
scatter(squeeze(bit_acc(:,1,:)),squeeze(bit_acc(:,4,:) - bit_acc(:,3,:)),sz,'filled');
title('Weight Change for BitAcc');

subplot(2,2,4)
scatter(squeeze(bit_acc(:,2,:)),squeeze(bit_acc(:,4,:) - bit_acc(:,3,:)),sz,'filled');
title('Weight Change for Each Weights');

y_max = max(weights_each_iter(:,:),[],'all');
y_min = min(weights_each_iter(:,:),[],'all');
figure;
subplot(1,3,1)
plot(mean(weights_each_iter(:,1:50),2));
title('Good 50 Weights Average for Each Iter');
ylim([y_min y_max]);

subplot(1,3,2)
plot(mean((weights_each_iter(:,51:100)),2));
title('Bad 50 Weights Average for Each Iter');
ylim([y_min y_max]);

subplot(1,3,3)
plot(average_bit_acc_over_iter);
title('Average Bit Accuracy for Each Iter');
