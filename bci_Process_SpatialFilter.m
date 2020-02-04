function bci_Process_SpatialFilter()
    global vepstim tasks settings;
    global data_eeg data_pp data_bits lastTrialSample isTrialEnd data_x data_y data_template lastAction trialcounter runComplete;
    
    %% PREPARE DATA
    if ~isempty(data_eeg)
        % extract trial from buffer
        mseqStart = find(diff([0;data_pp(1:lastTrialSample,5)])==1);
        if (length(mseqStart)>1 || length(mseqStart)==1 && isTrialEnd) && trialcounter < settings.numTrials
            trialcounter = trialcounter+1;
            
            % get last sample position of full msequence
            if isTrialEnd, lastMseqSample = size(data_eeg,2);
            else           lastMseqSample = mseqStart(2)-1; end
            
            % in the case a trial is few samples too long
            lastSample = min(size(data_x,3),lastMseqSample);

            % shift msequence by (2 bits) X (target number - 1)
            seqShift = (lastAction-1)*vepstim.settings.stimSettings.mseqShift*settings.samplesPerBit;
            
            % correct monitor delay
            targetdelay = vepstim.getDelayOfTarget(vepstim.settings.trials(lastAction));
            eegshift = round(targetdelay * settings.samplesPerFrame);
            
            % buffer each msequence cycle (eeg data and bit samples)
            data_x(trialcounter,:,1:lastSample) = circshift(data_eeg(:,1:lastSample),[0 seqShift-eegshift]);
            data_y(trialcounter,1:lastSample)   = circshift(data_bits(lastAction,1:lastSample),[0 seqShift]);
            data_template(trialcounter) = lastAction;

            % clear trial from buffer
            data_eeg  = data_eeg(:,lastMseqSample+1:end);
            data_pp   = data_pp(lastMseqSample+1:end,:);
            data_bits = data_bits(:,lastMseqSample+1:end);
            lastTrialSample = lastTrialSample-lastMseqSample;
            
            % all trials ready? Train spatial filter and stop training
            if isTrialEnd && lastAction==length(vepstim.settings.trials) %trialcounter == settings.numTrials
                % start training (background task)
                tasks.run('spfilter',@taskSpatialFilter,data_x(1:trialcounter,:,:),data_template(1:trialcounter),settings);
                
                % stop run and show info on screen
                vepstim.stop();
                vepstim.info('Calculating Spatial Filter...',5);
            end

            % start next trial
            if lastAction<length(vepstim.settings.trials) && isTrialEnd
                vepstim.highlightTarget(vepstim.settings.trials(lastAction),0.1);
                lastAction = lastAction+1;
            end
    
        end
    end
    
    %% CHECK IF SPATIAL FILTER IS READY
    if tasks.isFinished('spfilter')
        runComplete = true;
        % pull data from task
        [spfilter,bestchannel] = tasks.getOutput('spfilter');
        % save spatial filter
        filterType = settings.filterType;
        bestchannel = settings.real_eegchannels(bestchannel);
        % save filter and train data
        save([settings.subjectPath 'spatialFilter.mat'],'spfilter','filterType','bestchannel','data_x','data_y','data_template');
        
        % show info to user
        vepstim.info(sprintf('Finished. Best Channel: %.0f',bestchannel),5);
    end
end

