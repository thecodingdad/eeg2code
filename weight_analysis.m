approach = 'approach_2';
data_loc = './weight_update_data/';
full_path = strcat(data_loc, approach);
initial_pool = csvread(strcat(data_loc,'random_seq_pool_init.csv'));

approach_files = dir(fullfile(full_path, '*.csv'));
approach_files = {approach_files.name};

weight_update = zeros(2,100,20);
bit_acc = zeros(2,100,20);

for i = 1:size(approach_files,2)/2
    file_name_weight = strcat('r_', string(i), '_tr_', string(i*100), '_new_weights.csv');
    file_name_bitacc = strcat('r_', string(i), '_tr_', string(i*100), '_bit_acc_weight.csv');
    
    weight_update(:,:,i) = csvread(strcat(full_path,'/',file_name_weight));
    bit_acc(:,:,i) = csvread(strcat(full_path,'/',file_name_bitacc));
end

figure
plot(squeeze(weight_update(1,:,:)));
figure
plot(squeeze(weight_update(2,:,:)));

figure
plot(squeeze(bit_acc(2,:,:)))
