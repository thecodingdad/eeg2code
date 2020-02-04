function bci_Initialize_FreeMode()
    % global settings
    global bci_Parameters vepstim settings storedSamples predictedSamples bitACCs;
    storedSamples = 0;
    predictedSamples = 0;
    bitACCs = [];
    
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
        switch settings.modelType
            case 'reg', settings.timelag = length(trainedmodel)-1;
        end
        clear trainmodel;
    end
    
    %% ASYNCHRONOUS MODE?
    if settings.asynchronous
        settings.minSamplesPerTrial = settings.mintriallength/1000*settings.samplingRate;
        settings.minSamplesPerTrial = ceil(settings.minSamplesPerTrial/settings.samplesPerBit)*settings.samplesPerBit;
    end
    
    %% DEFINE DATA
    global data_bits_all data_x_latest data_y_pred nextPrediction trialcounter;
    data_x_latest     = zeros(settings.samplesPerTrial,1);
    data_y_pred       = zeros(1,settings.samplesPerTrial);
    data_bits_all     = zeros(vepstim.getNumberOfTargets(),settings.samplesPerTrial);
    trialcounter      = 0;
    nextPrediction    = 0;
    
    %% REMOTE MODEL
    if str2double(bci_Parameters.modeltype{1}) == 2
        settings.modelType = 'remote';
        data_x_latest = zeros(settings.samplesPerTrial,length(settings.real_eegchannels));
        %hostport = split(bci_Parameters.tcpiphost{1},':');
        %trainedmodel = tcpclient(hostport{2},str2double(hostport{2}));
		trainedmodel = tcpclient('lucille',50000);
    end
end


