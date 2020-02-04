function [pvalcorrect,pvalwrong] = getAsynchronousThresholds(path,subject,runs)

    pvalData = cell(length(runs),32);
    distData = cell(length(runs),32);
    predData = cell(length(runs),32);
    
    numAfterTrialSamples = 150;
    windowSize = 150;
    minTrialDuration = 150;
    maxTrialDuration = 900;
    
    subjectpath = sprintf('%s\\%s001\\',path,subject);

    load('targetdelays.mat');
    load([subjectpath 'spatialFilter.mat']);
    load([subjectpath 'trainedModel.mat']);

    run = 0;
    for testrun = runs
        filename = sprintf('%s%sS001R%02i.dat',subjectpath,subject,testrun);
        [signal, bci_StateSamples, params]=load_bcidat(filename,'-calibrated');
        
        run = run+1;

        pport =  double([bci_StateSamples.DigitalInput1,...
                  bci_StateSamples.DigitalInput2,...
                  bci_StateSamples.DigitalInput3,...
                  bci_StateSamples.DigitalInput4,...
                  bci_StateSamples.DigitalInput5,...
                  bci_StateSamples.DigitalInput6,...
                  bci_StateSamples.DigitalInput7,...
                  bci_StateSamples.DigitalInput8]);

        load([filename '_bits.mat']);
        [~,bitOrder]=sort(bits(:,1));
        bits = bits(bitOrder,2:end);

        channels = params.TransmitChList.NumericValue;
        signal = signal(:,channels)';
        settings = struct();
        settings.filterType = filterType;

        trialstarts = find(diff(pport(:,4))==1)+1;
        trialends = find(diff(pport(:,4))==-1);

        for trial = 1:length(trialstarts)
            trialstart = trialstarts(trial);
            trialstop = trialends(trial);
            bitchanges = pport(trialstart:trialstop,3)';
            [samples,bits] = upsampleBits(bits,bitchanges,[]);

            trialdata = applySpatialFilter(signal(:,trialstart:trialstop+numAfterTrialSamples)',spfilter,settings)';

            data_x_timelag = zeros(size(trialdata,1),windowSize);
            for t=1:150
                data_x_timelag(:,t) = circshift(trialdata,[-t 0])';
            end

            predSamples = trainedmodel(2:end)*data_x_timelag'+trainedmodel(1);
            predSamplesTrimmed = predSamples(1:end-windowSize+numAfterTrialSamples);
            samples = samples(:,1:end-windowSize+numAfterTrialSamples);
            minsize = min(size(samples,2), size(predSamplesTrimmed,2));
            samples = samples(:,1:minsize);
            predSamplesTrimmed = predSamplesTrimmed(1:minsize);


            targetPred = zeros(1,length(minTrialDuration:32:minsize));
            targetPval = zeros(1,length(minTrialDuration:32:minsize));
            targetDist = zeros(1,length(minTrialDuration:32:minsize));

            subtrialcounter = 0;
            for trialend=minTrialDuration:32:length(predSamplesTrimmed)
                subtrialcounter = subtrialcounter +1;
                trialstart = max(1,trialend-maxTrialDuration+1);
                predsamples = predSamplesTrimmed(trialstart:trialend);


                targetCorrs = zeros(1,size(bits,2));
                targetPVals = zeros(1,size(bits,2));
                for target=1:size(bits,2)
                    targetdelay = targetdelays(target);
                    eegshift = round(targetdelay * 10);

                    targetsamples = samples(target,trialstart:trialend)';

                    [targetCorrs(target), targetPVals(target)] = ...
                        corr(targetsamples,circshift(predsamples,[0 -eegshift])');
                end

                [a,b] = sort(targetCorrs);
                targetPred(subtrialcounter) = b(end);
                targetDist(subtrialcounter) = a(end)/a(end-1)-1;
                targetPval(subtrialcounter) = targetPVals(b(end));
            end

            pvalData{run,trial} = targetPval;
            distData{run,trial} = targetDist;
            predData{run,trial} = targetPred;
        end
        fprintf('Run %.0f\n',run);
    end

    threshold = zeros(size(predData{1,1},2)-1,1);
    %maxpval   = zeros(size(predData{1,1},2)-1,1);
    pvalcorrect = [];
    pvalwrong = [];
    for duration=1:size(predData{1,1},2)-1
        pred = []; dist = []; pvals = [];
        for run=1:size(predData,1)
            pred = [pred;cellfun(@(x) x(duration),squeeze(predData(run,:)))'==(1:32)'];
            dist = [dist;cellfun(@(x) x(duration),squeeze(distData(run,:)))'];
            pvals = [pvals;cellfun(@(x) x(duration),squeeze(pvalData(run,:)))'];
        end
        wrong95 = quantile(dist(pred==0),0.99);
        correct25 = quantile(dist(pred==1),0.5);
        threshold(duration) = (wrong95+correct25)/2;
        pvalwrong = [pvalwrong;pvals(pred==0)];
        pvalcorrect = [pvalcorrect;pvals(pred==1)];
    end

    %distance = mean(threshold,'omitnan');
    %pvalue = min(maxpval,'omitnan');
    figure;
    boxplot([pvalcorrect;pvalwrong],[zeros(length(pvalcorrect),1);ones(length(pvalwrong),1)]);
    set(gca, 'YScale', 'log');
end

