approach = 'approach_test';
data_loc = './weight_update_data/';
full_path = strcat(data_loc, approach);
initial_pool = csvread(strcat(data_loc,'random_seq_pool_init.csv'));
% seq_bit_acc = csvread('random_seq_bit_acc_demo.csv');

approach_files = dir(fullfile(full_path, '*.csv'));
approach_files = {approach_files.name};

weight_update = zeros(2,100,size(approach_files,2)/2);
bit_acc = zeros(1000,4,size(approach_files,2)/2);

for i = 1:size(approach_files,2)/2
    file_name_weight = strcat('r_', string(i), '_tr_', string(i*1000), '_new_weights.csv');
    file_name_bitacc = strcat('r_', string(i), '_tr_', string(i*1000), '_bit_acc_weight.csv');
    
    weight_update(:,:,i) = csvread(strcat(full_path,'/',file_name_weight));
    bit_acc(:,:,i) = csvread(strcat(full_path,'/',file_name_bitacc));
end
% 
% figure;
% plot(transpose(seq_bit_acc));

sum(weight_update(2,:,1) == 0)
figure;
subplot(2,2,1)
plot(squeeze(weight_update(1,:,:)));
title('Weights after 1000 iter');

subplot(2,2,2)
plot(squeeze(weight_update(2,:,:)));
title('Sampled count after 1000 iter');

subplot(2,2,3)
scatter(squeeze(bit_acc(:,1,:)),squeeze(bit_acc(:,4,:) - bit_acc(:,3,:)));
title('Weight Change for BitAcc');

subplot(2,2,4)
scatter(squeeze(bit_acc(:,2,:)),squeeze(bit_acc(:,4,:) - bit_acc(:,3,:)));
title('Weight Change for Each Weights');
