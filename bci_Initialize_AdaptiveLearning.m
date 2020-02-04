function bci_Initialize_AdaptiveLearning()
    % BCI 2000 parameters and states
    global bci_Parameters vepstim tasks settings;
    
    %% INPUTBUFFER
    global storedSamples predictedSamples newTrainTrials doTargetSelection;
    storedSamples = 0;
    predictedSamples = 0;
    newTrainTrials = false;
    doTargetSelection = false;
    
    %% DEFINE DATA
    global data_x_buffer data_y_buffer data_bits_all data_x_latest data_y_pred nextPrediction trialcounter;
    data_x_buffer     = zeros(settings.numTrials,settings.samplesPerTrial);
    data_y_buffer     = zeros(settings.numTrials,settings.samplesPerTrial);
    data_x_latest     = zeros(1,settings.samplesPerTrial);
    data_y_pred       = zeros(1,settings.samplesPerTrial);
    data_bits_all     = zeros(vepstim.getNumberOfTargets(),settings.samplesPerTrial);
    trialcounter      = 0;
    nextPrediction    = 0;
    
    %% load spatial filter
    global sp_filter;
    if length(settings.real_eegchannels) > 1 && str2double(bci_Parameters.modeltype{1}) ~= 2
        spatialfilter = load([settings.subjectPath 'spatialFilter.mat']);
        sp_filter = spatialfilter.spfilter;
        if strcmp(spatialfilter.filterType,'cca')
            settings.filterType = 'cca';
        end
        clear spatialfilter;
    end
    
    %% ECHO STATE NETWORK OR REGRESSION MODEL
    global trainedmodel;
    trainedmodel = [];
    if exist([settings.subjectPath 'trainedModel.mat'],'file') == 2
        % load trained model
        trainmodel = load([settings.subjectPath 'trainedModel.mat']);
        settings.modelType = trainmodel.modelType;
        trainedmodel = trainmodel.trainedmodel;
        
        if strcmp(settings.modelType,'reg')
            trialcounter = size(trainmodel.data_x_buffer,1);
            data_x_buffer = zeros(settings.numTrials,size(trainmodel.data_x_buffer,2));
            data_y_buffer = zeros(settings.numTrials,size(trainmodel.data_y_buffer,2));
            data_x_buffer = [trainmodel.data_x_buffer;data_x_buffer];
            data_y_buffer = [trainmodel.data_y_buffer;data_y_buffer];
            data_x_buffer = data_x_buffer(1:min(size(data_x_buffer,1),settings.trialsToStore),:);
            data_y_buffer = data_y_buffer(1:min(size(data_y_buffer,1),settings.trialsToStore),:);
        end
        
        switch settings.modelType
            case 'reg', settings.timelag = length(trainedmodel)-1;
        end
        
        clear trainmodel;
    else
        if str2double(bci_Parameters.modeltype{1}) == 1
            settings.modelType = 'reg';
            trainedmodel = zeros(1,settings.timelag+1);
        elseif str2double(bci_Parameters.modeltype{1}) == 2
            settings.modelType = 'remote';
            data_x_buffer = zeros(settings.numTrials,settings.samplesPerTrial,length(settings.real_eegchannels));
            data_x_latest = zeros(1,settings.samplesPerTrial,length(settings.real_eegchannels));
        end
    end
        
    %% CREATE BACKGROUND TASKS
    tasks.add('trainer');
    tasks.add('classifier');
end


