function bci_Process_AdaptiveLearning()
    global bci_States settings vepstim tasks;
    global data_eeg data_pp data_bits data_bits_all lastTrialSample trainedmodel isTrialEnd data_x_buffer data_y_buffer data_x_latest numRunSamples data_y_pred trialcounter storedSamples predictedSamples lastAction sp_filter newTrainTrials runComplete doTargetSelection;
    
    bci_States.Chosenclass = 0;
    bci_States.Targetclass = 0;
    blockSize = size(data_bits,2);
    
    %% GET LATEST MODEL
    if tasks.isFinished('trainer')
        trainedmodel = tasks.getOutput('trainer');
    end
    
    %% GET LATEST PREDICTION
    if tasks.isFinished('classifier')
        [data_y_pred_new,predAction,~,~,bitAcc] = tasks.getOutput('classifier');
        data_y_pred(1:length(data_y_pred_new)) = data_y_pred_new;
        
        if predAction > 0
            
            switch settings.classificationMode
                case 'target'
                    vepstim.chooseTarget(predAction,0.1);
                    bci_States.Chosenclass = predAction;
                case 'bitacc'
                    vepstim.chooseTarget(predAction,0);
                    vepstim.info(sprintf('Bit Accuracy: %0.1f (ITR: %0.1f)',bitAcc*100,ITR(2,min(0.99999,bitAcc),settings.samplesPerBit/settings.samplingRate)*60),1);
            end
            
            if length(vepstim.settings.trials) == length(vepstim.chosenTargets)
                vepstim.stop();
            end
        end
    end
        
    %% NEW TRIAL DATA IN BUFFER?
    if ~isempty(data_eeg) && ~strcmp(settings.modelType,'remote')
        % extract new trial data of current block            
        data_x = data_eeg(:,1:blockSize)';
        
        % apply spatial filter
        if length(settings.real_eegchannels) > 1
            data_x = applySpatialFilter(data_x,sp_filter,settings);
        end
        
        % buffer trials for trainer task
        data_x_latest(storedSamples+1:storedSamples+length(data_x)) = data_x;
        data_x_buffer(mod(trialcounter,settings.trialsToStore)+1,storedSamples+1:storedSamples+length(data_x)) = data_x;
        data_y_buffer(mod(trialcounter,settings.trialsToStore)+1,storedSamples+1:storedSamples+length(data_x)) = data_bits(vepstim.settings.trials(lastAction),1:length(data_x));
        data_bits_all(:,storedSamples+1:storedSamples+length(data_x)) = data_bits(:,1:length(data_x));
        storedSamples = storedSamples +length(data_x);
        
        % clear data from buffers
        data_eeg = data_eeg(:,blockSize+1:end);
        data_pp = data_pp(blockSize+1:end,:);
        data_bits = data_bits(:,blockSize+1:end);
        lastTrialSample = lastTrialSample-blockSize;
        
        % prepare next trial
        if isTrialEnd
            targetdelay = vepstim.getDelayOfTarget(vepstim.settings.trials(lastAction));
            eegshift = round(targetdelay * settings.samplesPerFrame);
            data_x_buffer(mod(trialcounter,settings.trialsToStore)+1,:) = ...
                circshift(data_x_buffer(mod(trialcounter,settings.trialsToStore)+1,:),[0,-eegshift]);
            
            lastAction = lastAction+1;
            trialcounter = trialcounter +1;
            newTrainTrials = true;
            doTargetSelection = true;
            
            % make sure that buffers are clear
            data_eeg = [];
            data_bits = [];
            data_pp = [];
            lastTrialSample = 0;
            isTrialEnd = false;
        end
    end
    
    % start classification of current block
    if tasks.isReady('classifier') && (predictedSamples < (storedSamples-settings.timelag+1) || doTargetSelection)
        if doTargetSelection
            realTarget = vepstim.settings.trials(lastAction-1);
        else
            realTarget = 0;
        end
        tasks.run('classifier',@taskClassify,trainedmodel,data_x_latest(predictedSamples+1:storedSamples),data_y_pred(1:predictedSamples),realTarget,data_bits_all(:,1:storedSamples),settings,vepstim.targetDelays,doTargetSelection);
        
        predictedSamples = storedSamples-settings.timelag+1;
        if doTargetSelection
            data_bits_all(:) = 0;
            storedSamples = 0;
            predictedSamples = 0;
            data_x_latest(:) = 0;
            doTargetSelection = false;
        end
    end
        
    %% start training (background task)
    if tasks.isReady('trainer') && newTrainTrials
        tasks.run('trainer',@taskTrain,trainedmodel,data_x_buffer(1:min(size(data_x_buffer,1),trialcounter),:),data_y_buffer(1:min(size(data_y_buffer,1),trialcounter),:),settings);
        newTrainTrials = false;
    end
    
    %% trialend using remote model
    if isTrialEnd && strcmp(settings.modelType,'remote')
        trialcounter = trialcounter +1;
        vepstim.chooseTarget(vepstim.settings.trials(trialcounter),0.1);
        data_eeg = [];
        data_bits = [];
        data_pp = [];
        lastTrialSample = 0;
        isTrialEnd = false;
    end

    %% save model to file
    if length(vepstim.settings.trials) == length(vepstim.chosenTargets) && tasks.isReady('trainer') && ~newTrainTrials
        runComplete = true;
        
        if strcmp(settings.modelType,'remote')
            vepstim.info('Finish.',2)
        else
            modelType = settings.modelType;

            vepstim.info('Finished. Save model...',5);

            % save regression model and train data
            save([settings.subjectPath 'trainedModel.mat'],'trainedmodel','modelType','data_x_buffer','data_y_buffer');

            % save statistics and show info on screen
            trialsToPerform = vepstim.settings.trials;
            chosenTargets = vepstim.chosenTargets;
            predictionACC = mean(trialsToPerform == chosenTargets);
            save([settings.subjectPath settings.currentFilename '_statistics.mat'],'predictionACC','trialsToPerform','chosenTargets');
            vepstim.info(sprintf('Model saved. ACC: %0.1f, ITR: %0.1f', predictionACC*100, ITR(vepstim.getNumberOfTargets(),min(0.99999,predictionACC),(numRunSamples/settings.samplingRate)/(lastAction-1))*60),2);
        end
    end
end

