function [ result ] = task_bci_Process (shared)
    %% MAIN PROCESS PARAMETERS
    global bci_Parameters vepstim tasks settings 
    
    global lastAction trialSamples previousTrialSamples numRunSamples numAfterTrialSamples lastTrialSample runStarted isTrialEnd runComplete data_eeg data_pp data_bits;
    
    result = false;
    errorText = '';
    
    %% MAIN LOOP
    while true
        %% if run was stopped
        if shared.data.stop
            shared.data.runComplete = 1;
            shared.data.stop = 0;
            vepstim.stop();
            %% save presented bits
            if ~vepstim.settings.playbackMode
                vepstim.savePresentedBits([settings.subjectPath settings.currentFilename '_bits.mat']);
            end
            if shared.data.isError
                if isempty(errorText), errorText = 'ERROR'; end
                vepstim.close();
                vepstim.console(errorText);
            end
            try
                global trainedmodel;
                if strcmp(settings.modelType,'remote') && isa(trainedmodel,'tcpclient')
                    trainedmodel.delete;
                end
            catch 
               
            end
        end
        %% if run was started
        if shared.data.start
            vepstim.start();
            % get current filename
            allfiles = dir([settings.subjectPath '*.dat']);
            [~,currentFile] = max([allfiles.datenum]);
            settings.currentFilename=allfiles(currentFile).name;
            shared.data.start = 0;
        end
        
        %% reload settings after "SET CONFING"
        if shared.data.reload == 1
            % load settings
            load('bci_settings.mat');
            [settings,vepSettings] = helper.parseBCIParams(bci_Parameters);
            
            % initialize settings
            if isa(vepstim,'vep_operator')
                vepstim.stop();
                tasks.cancelAll();
                
                vepstim.set(vepSettings);
            else
                vepstim = vep_operator(bci_Parameters.tcpiphost{1},'settings',vepSettings,'debug',settings.debug);
                tasks = task_manager();
            end
            
            % load presented bits if playback mode is used
            if vepstim.settings.playbackMode
                vepstim.loadPresentedBits([bci_Parameters.PlaybackFileName{1} '_bits.mat']);
            end
            
            % HELPER VARIABLES
            trialSamples = [];
            previousTrialSamples = false;
            lastTrialSample = 0;
            isTrialEnd = false;
            runComplete = false;
            numRunSamples = 0;
            numAfterTrialSamples = 0;
            runStarted = false;
            lastAction = 1;
            errorText = '';
            shared.data.runComplete = 0;
            shared.data.block_counter = 0;

            % BUFFER VARIABLES
            data_eeg = [];
            data_pp = [];
            data_bits = [];

            % INITIALIZE MODE SPECIFIC CONTENT
            switch (str2double(bci_Parameters.trainmode{1}))
                case 1 % spatial filter training
                    bci_Initialize_SpatialFilter();
                case 2 % adaptive learning
                    bci_Initialize_AdaptiveLearning();
                case 3 % free mode
                    bci_Initialize_FreeMode();
            end

            % Ready to start
            vepstim.info('Initialized.');
            shared.data.reload = 0;
        end
        
        %% PROCESS NEW BLOCKS
        if shared.data.block_counter > 0 && ~shared.data.isError && ~shared.data.runComplete && ~shared.data.stop
            if shared.data.isSave1
                % get recent sample blocks
                shared.data.isSave1 = 0;
                if shared.data.isSave2
                    shared.data.isSave2 = 0;
                    in_signal_blocks = shared.data.in_signal(1:shared.data.block_counter,:,:);
                    shared.data.block_counter = 0;
                    shared.data.isSave1 = 1;
                    shared.data.isSave2 = 1;

                    % process each block
                    for block=1:size(in_signal_blocks,1)
                        if shared.data.isError, break; end
                        shared.data.block_counter_task = shared.data.block_counter_task + 1;
                        in_signal = squeeze(in_signal_blocks(block,:,:));

                        %% PREPARE TRIAL EEG DATA
                        pp=de2bi(in_signal(end,:),8);
                        pp(:,8) = 0;
                        % check if block has tiralsamples
                        trialSamples = pp(:,4)==1;

                        % check if block is the end of trial
                        firstNonTrialSample = find(pp(:,4)==0,1,'first');
                        isTrialEnd = (~isempty(firstNonTrialSample) &&...
                                        ((firstNonTrialSample == 1 && ~any(trialSamples) && previousTrialSamples) ...
                                        || firstNonTrialSample > 1));
                        previousTrialSamples = pp(settings.samplesPerBlock,4)==1;
                        
                        if (isTrialEnd && settings.afterTrialSamples > 0) || numAfterTrialSamples > 0
                            if numAfterTrialSamples == 0, numAfterTrialSamples = settings.afterTrialSamples; end
                            numSamplesToAdd = min(settings.samplesPerBlock - firstNonTrialSample - 1,numAfterTrialSamples);
                            numAfterTrialSamples = numAfterTrialSamples - numSamplesToAdd;
                            samplesToAdd = firstNonTrialSample:firstNonTrialSample+numSamplesToAdd-1;
                            trialSamples(samplesToAdd) = true;
                            pp(samplesToAdd,[2,4,8]) = true;
                            
                            isTrialEnd = numAfterTrialSamples == 0;
                            
                            if isempty(isTrialEnd)
                                save;
                            end
                        end
                        
                        % count all samples during a run to measure runtime
                        if runStarted && ~runComplete
                            numRunSamples = numRunSamples + sum(pp(:,1)==1);
                        end
                        
                        if isTrialEnd || any(trialSamples)
                            % append trial samples to buffer
                            if any(trialSamples)
                                runStarted = true;
                                data_eeg  = [data_eeg, in_signal(1:end-1,trialSamples)];
                                data_pp   = [data_pp;  pp(trialSamples,:)];
                            end

                            %% PREPARE BITBUFFER OF ALL TARGETS

                            % get last position of full bit sample block
                            if ~isTrialEnd, lastBitPos = find(abs([1;diff(data_pp(1:end,3))]),1,'last')-1;
                            else            lastBitPos = size(data_eeg,2); end

                            % append target bits samples to buffer
                            if lastTrialSample < lastBitPos
                                % block until bits are ready
                                bitchanges = data_pp(lastTrialSample+1:lastBitPos,3)';
                                afterTrialBitchanges = bitchanges(data_pp(lastTrialSample+1:lastBitPos,8)'==1);

                                if vepstim.areTargetBitsReady(bitchanges,afterTrialBitchanges)
                                    data_bits = [data_bits, vepstim.getTargetSamples(bitchanges,afterTrialBitchanges)];
                                    lastTrialSample = lastBitPos;

                                    % check if bit buffer is sync to parallel port
                                    if sum(data_pp(1:lastTrialSample,2)'~=round(data_bits(1,1:lastTrialSample))) ~= 0
                                        shared.data.isError = 1;
                                        shared.data.stop = 1;
                                        save;
                                        errorText = 'ERROR: bit synchronisation error';
                                        break;
                                    end
                                else
                                    shared.data.isError = 1;
                                    shared.data.stop = 1;
                                    save;
                                    errorText = 'ERROR: targetbits are delayed';
                                    break;
                                end
                            end
                        end
                        
                        %% MODE SPECIFIC PROZESSING
                        switch (str2double(bci_Parameters.trainmode{1}))
                            case 1
                                bci_Process_SpatialFilter();
                            case 2
                                bci_Process_AdaptiveLearning();
                            case 3
                                bci_Process_FreeMode();
                        end
                    end
                else
                    shared.data.isSave1 = 1;
                end
            end
        else
            %% No more data blocks? CALL MODE SPECIFIC PROZESSING until run complete
            if ~shared.data.runComplete
                switch (str2double(bci_Parameters.trainmode{1}))
                    case 1
                        bci_Process_SpatialFilter();
                    case 2
                        bci_Process_AdaptiveLearning();
                    case 3
                        bci_Process_FreeMode();
                end
            end
        end
                        
        
        if runComplete
            runComplete = false;
            shared.data.runComplete = 1;
            
            %% save presented bits
            if ~vepstim.settings.playbackMode
                vepstim.savePresentedBits([settings.subjectPath settings.currentFilename '_bits.mat']);
            end
        end
        
        pause(0.01);
    end
end

