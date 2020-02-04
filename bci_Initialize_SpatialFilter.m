function bci_Initialize_SpatialFilter()
    % BCI 2000 parameters and states
    global bci_Parameters settings vepstim tasks;
    
    %% trial counter
    global trialcounter;
    trialcounter = 0;
    
    %%
    global data_x data_y data_template
    mseqLength = vepstim.settings.stimSettings.mseqParams(1)^vepstim.settings.stimSettings.mseqParams(2)-1;
    settings.numTrials = settings.numTrials*ceil(settings.samplesPerTrial/(mseqLength*settings.samplesPerBit));
    data_x = zeros(settings.numTrials,length(settings.real_eegchannels),mseqLength*settings.samplesPerBit);
    data_y = zeros(settings.numTrials,mseqLength*settings.samplesPerBit);
    data_template = zeros(settings.numTrials,1);
    
    %% GENERAL SETTINGS
    if exist([settings.subjectPath 'spatialFilter.mat'],'file') == 2
        spatialfilter = load([settings.subjectPath 'spatialFilter.mat']);
        if strcmp(spatialfilter.filterType,'cca')
            settings.filterType = 'cca';
            data_x = [spatialfilter.data_x; data_x];
            data_y = [spatialfilter.data_y; data_y];
            data_template = [spatialfilter.data_template; data_template];
            trialcounter = size(spatialfilter.data_x,1);
            settings.numTrials = settings.numTrials + trialcounter;
        end
        clear spatialfilter;
    else
        settings.filterType = 'cca';
    end
    
    %% SPATIAL FILTER TRAINER BACKGROUND THREAD
    tasks.add('spfilter');
end


