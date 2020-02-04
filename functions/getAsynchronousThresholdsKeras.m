function [maxTrialDuration,pvalthreshold] = getAsynchronousThresholdsKeras(path,subject)

    
    samplingRate = 600;
    refreshRate = 60;
    samplesPerFrame = samplingRate/refreshRate;
    windowSize = 150;
    minTrialDuration = 0.5*samplingRate;
    maxTrialDuration = 3*samplingRate;
    trialdurations = (minTrialDuration:windowSize:maxTrialDuration);
    
    subjectpath = sprintf('%s/%s001/',path,subject);
    %subjectpath = sprintf('%s/',path);
    
    load([subjectpath subject '_train.mat']);
    targetdelays=targetdelays/samplesPerFrame;
    numTargets = length(targetdelays);
%%
    if exist([subjectpath 'thresholdDataKeras.mat'], 'file') == 2
        load([subjectpath 'thresholdDataKeras.mat']);
    else
        disp([subjectpath subject '_train_train_pred.csv']);
        predSamplesKeras=csvread([subjectpath subject '_train_train_pred.csv']);
        predSamplesKeras = predSamplesKeras(:,1)';
        pvalDataCorrect = cell(1,length(trialdurations));
        pvalDataWrong = cell(1,length(trialdurations));
        
        for trial = 1:size(train_data_x,1)
            trialstart = 1;
            trialstop = size(train_data_x,3);

            triallength = length(trialstart:trialstop)-windowSize;
            predSamplesTrimmed = predSamplesKeras(1:triallength);
            predSamplesKeras = predSamplesKeras(triallength+1:end);

            samples = squeeze(train_data_y(trial,:,1:triallength));
            numWindows = min(50,floor((length(predSamplesTrimmed)-(trialdurations(end)-windowSize))/samplesPerFrame));
            %start parpool
            startParPool(length(trialdurations))
            parfor trialdur = 1:length(trialdurations)
                maxtrialend = (trialdurations(trialdur)-windowSize)+numWindows*samplesPerFrame;
                subtrialends = (trialdurations(trialdur):samplesPerFrame:length(trialstart:trialstop))-windowSize;
                subtrialends = subtrialends(randperm(length(subtrialends),numWindows));
                targetPred = zeros(1,length(subtrialends));
                targetPval = zeros(1,length(subtrialends));

                for subtrialcounter=1:length(subtrialends)
                    subtrialend = subtrialends(subtrialcounter);
                    subtrialstart = max(1,subtrialend-(trialdurations(trialdur)-windowSize)+1);
                    predsamples = predSamplesTrimmed(subtrialstart:subtrialend);


                    targetPVals = zeros(1,size(samples,1));
                    for target=1:size(samples,1)
                        targetdelay = targetdelays(target);
                        eegshift = round(targetdelay * (samplingRate/refreshRate));

                        targetsamples = samples(target,subtrialstart:subtrialend)';

                        [~, targetPVals(target)] = ...
                            corr(targetsamples,circshift(predsamples,[0 -eegshift])','tail','right');
                    end

                    [targetPval(subtrialcounter),targetPred(subtrialcounter)] = min(targetPVals);
                end

                pvalDataCorrect{trialdur} = [pvalDataCorrect{trialdur},targetPval(targetPred==(mod(trial-1,numTargets)+1))];
                pvalDataWrong{trialdur} = [pvalDataWrong{trialdur},targetPval(targetPred~=(mod(trial-1,numTargets)+1))];
            end
            fprintf('Trial: %.0f, %.0f\n',trial,length(predSamplesKeras));
            if trial == numTargets
                disp('Run complete');
            end
        end

        save([subjectpath 'thresholdDataKeras.mat'], 'pvalDataCorrect','pvalDataWrong');
    end
    pvalthreshold = quantile(horzcat(pvalDataWrong{:}),0.01);
    maxTrialDuration=trialdurations(find(cellfun(@(x) ifelse(isempty(x),0,mean(x<=pvalthreshold)),pvalDataCorrect)>=0.99,1,'first'));
    if isempty(maxTrialDuration), maxTrialDuration = trialdurations(end); end
    
    %% test non-control
    predSamplesKeras=csvread([subjectpath subject '_train_trainnc_pred.csv']);
    predSamplesKeras = predSamplesKeras(:,1)';
    ncpvals = [];
        
    for trial = 1:size(trainnc_data_x,1)
        trialstart = 1;
        trialstop = size(trainnc_data_x,3);

        triallength = length(trialstart:trialstop)-windowSize;
        predSamplesTrimmed = predSamplesKeras(1:triallength);
        predSamplesKeras = predSamplesKeras(triallength+1:end);

        samples = squeeze(trainnc_data_y(trial,:,1:triallength));
        
        bitends = trialdurations(1):samplesPerFrame:trialstop;
        ncpval = zeros(1,length(bitends));
        parfor subtrialind = 1:length(bitends)
            subtrialend = bitends(subtrialind)-windowSize;
            subtrialstart=max(1,subtrialend-(maxTrialDuration-windowSize)+1);
            predsamples = predSamplesTrimmed(subtrialstart:subtrialend);

            targetPVals = zeros(1,size(samples,1));
            for target=1:size(samples,1)
                targetdelay = targetdelays(target);
                eegshift = round(targetdelay * samplesPerFrame);

                targetsamples = samples(target,subtrialstart:subtrialend)';

                [~, targetPVals(target)] = ...
                    corr(targetsamples,circshift(predsamples,[0 -eegshift])','tail','right');
            end
            ncpval(subtrialind) = min(targetPVals);
        end
        ncpvals = [ncpvals,ncpval];
    end
    
    if sum(ncpvals<=pvalthreshold)
        pvalthreshold = min(ncpvals);
    end
    
    fileID = fopen([subjectpath 'threshold.txt'],'w');
    fprintf(fileID,'%s\n',mat2str(pvalthreshold));
    fprintf(fileID,'%s\n',mat2str(maxTrialDuration));
    fclose(fileID);
    disp (pvalthreshold);
    disp (maxTrialDuration);
    data_y = [];
    entries = cellfun(@(x) size(x,2),pvalDataCorrect);
    for ii = 1:length(entries)
        data_y=[data_y,ones(1,entries(ii))*ii];
    end
    data_y=[data_y,12*ones(1,length(horzcat(pvalDataWrong{:})))];
    data_x=[horzcat(pvalDataCorrect{:}),horzcat(pvalDataWrong{:})];
    figure;
    boxplot(data_x,data_y);
    set(gca, 'YScale', 'log')
    saveas(gcf,[subjectpath 'threshold1.png']);
    
    figure;
    data_y=[zeros(1,length(horzcat(pvalDataCorrect{:}))),ones(1,length(horzcat(pvalDataWrong{:}))),ones(1,length(ncpvals))*2];
    data_x=[horzcat(pvalDataCorrect{:}),horzcat(pvalDataWrong{:}),ncpvals];
    boxplot(data_x,data_y);
    hold on;
    plot([0, 14], [pvalthreshold, pvalthreshold])
    set(gca, 'YScale', 'log')
    saveas(gcf,[subjectpath 'threshold2.png']);
end

