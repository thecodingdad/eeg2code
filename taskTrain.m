function [trainedmodel] = taskTrain(trainedmodel,data_x,data_y,settings)
% taskRegressionTrain trains the model using a background task
    % timelag data
    data_x = data_x';
    data_y = data_y';
    numSamples = size(data_x,1);
    data_x = data_x(:);
    data_y = data_y(:);
    data_x_timelag = zeros(size(data_x,1),settings.timelag);
    for t=0:(settings.timelag-1)
        data_x_timelag(:,t+1) = circshift(data_x,[-t 0])';
    end
    
    % skip last timelag-samples
    samples2skip = (numSamples-settings.timelag+1):numSamples;
    data_x_timelag = skipSamples(data_x_timelag,numSamples,samples2skip);
    data_y = skipSamples(data_y,numSamples,samples2skip);
            
    % train model
    switch settings.modelType
        case 'reg', trainedmodel = ridge(data_y,data_x_timelag,1,0)';
    end
end

