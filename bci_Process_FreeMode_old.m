function bci_Process_FreeMode()
    global data_eeg data_pp data_bits data_bits_all lastTrialSample trainedmodel isTrialEnd data_x_latest data_y_pred numRunSamples bci_States storedSamples predictedSamples settings vepstim lastAction sp_filter runComplete;
    
    bci_States.Chosenclass = 0;
    bci_States.Targetclass = 0;
    blockSize = size(data_bits,2);
            
    %% NEW TRIAL DATA IN BUFFER?
    if ~isempty(data_eeg) && ((storedSamples-predictedSamples)+blockSize > settings.timelag || isTrialEnd)
        
        data_x = data_eeg(:,1:blockSize)';
        
        % apply spatial filter
        if length(settings.real_eegchannels) > 1
            data_x = applySpatialFilter(data_x,sp_filter,settings);
        end
        
        % buffer trials for trainer task
        data_x_latest(storedSamples+1:storedSamples+length(data_x)) = data_x;
        data_bits_all(:,storedSamples+1:storedSamples+length(data_x)) = data_bits(:,1:length(data_x));
        storedSamples = storedSamples +length(data_x);
        
        % clear data from buffers
        data_eeg = data_eeg(:,blockSize+1:end);
        data_pp = data_pp(blockSize+1:end,:);
        data_bits = data_bits(:,blockSize+1:end);
        lastTrialSample = lastTrialSample-blockSize;
        
        doClassification = isTrialEnd || (settings.asynchronous && storedSamples >= settings.minSamplesPerTrial);
        if doClassification && lastAction <= length(vepstim.settings.trials)
            realTarget = vepstim.settings.trials(lastAction);
        else
            realTarget = 0;
        end
                                
        [data_y_pred_new,predAction,predAcc,predDistance,predPValue,bitAcc] = taskClassify(trainedmodel,data_x_latest(predictedSamples+1:storedSamples),data_y_pred(1:predictedSamples),realTarget,data_bits_all(:,1:storedSamples),settings,vepstim.targetDelays,doClassification);
        data_y_pred(1:length(data_y_pred_new)) = data_y_pred_new;
        predictedSamples = storedSamples-settings.numSamples2skip;
        
        % if asynchronous mode is enabled and threshold is reached
        if settings.asynchronous && ~isTrialEnd && doClassification && predPValue <= settings.pValueThreshold
            vepstim.endTrial();
        end
        
        if settings.asynchronous && ~isTrialEnd && storedSamples >= settings.samplesPerTrial
            blockshift = settings.samplesPerBlock;
            data_y_pred   = circshift(data_y_pred,[0,-blockshift]);
            data_x_latest = circshift(data_x_latest,[0,-blockshift]);
            data_bits_all = circshift(data_bits_all,[0,-blockshift]);
            storedSamples = storedSamples - blockshift;
            predictedSamples = predictedSamples - blockshift;
        end
        
        % prepare next trial
        if isTrialEnd
            % make sure that buffers are clear
            data_eeg = [];
            data_bits = [];
            data_pp = [];
            lastTrialSample = 0;
            data_bits_all(:) = 0;
            storedSamples = 0;
            predictedSamples = 0;
            data_x_latest(:) = 0;
            
            lastAction = lastAction+1;
            switch settings.classificationMode
                case 'target'
                    vepstim.chooseTarget(predAction,0.1);
                case 'bitacc'
                    vepstim.chooseTarget(predAction,0);
                    %vepstim.info(sprintf('Bit Accuracy: %0.1f (ITR: %0.1f)',bitAcc*100,ITR(2,min(0.99999,bitAcc),settings.samplesPerBit/settings.samplingRate)*60),1);
            end
            
            bci_States.Chosenclass = predAction;
            if length(vepstim.settings.trials) == length(vepstim.chosenTargets) && ~vepstim.settings.freeMode
                runComplete = true;
                vepstim.stop();
                switch settings.classificationMode
                    case 'target'
                        % show target prediction accuracy on screen
                        trialsToPerform = vepstim.settings.trials;
                        chosenTargets = vepstim.chosenTargets;
                        predictionACC = mean(trialsToPerform == chosenTargets);
                        vepstim.info(sprintf('Finished. ACC: %0.1f, ITR: %0.1f', predictionACC*100, ITR(vepstim.getNumberOfTargets(),min(0.99999,predictionACC),(numRunSamples/settings.samplingRate)/(lastAction-1))*60),10);
                        
                        save([settings.subjectPath settings.currentFilename '_statistics.mat'],'predictionACC');
                    case 'bitacc'
                        vepstim.info(sprintf('Bit Accuracy: %0.1f (ITR: %0.1f)',bitAcc*100,ITR(2,min(0.99999,bitAcc),settings.samplesPerBit/settings.samplingRate)*60),10);
                        save([settings.subjectPath settings.currentFilename '_statistics.mat'],'bitAcc');
                end
            end
        end
    end
end

