function [ bestChannel ] = getBestcVEPChannel( lagfixedInputData, correctTemplates, timeShift )
    % leave-one-trial-out estimation to get channel with best VEP-noise-ratio
    [numTrials, numChannels, numSamples] = size(lagfixedInputData);
    numTemplates = max(correctTemplates);
    res=zeros(numChannels,numTrials);
    for channel=1:numChannels
        corrvals=zeros(numTemplates,numTrials);
        trainset=randperm(numTrials);
        for testtrial=trainset
            traininds=trainset(trainset~=testtrial);
            ctempl = squeeze(mean(lagfixedInputData(traininds,channel,:)));
            nctempl =zeros(numTemplates,numSamples);
            for i=1:numTemplates
                nctempl(i,:)=ctempl(mod((1:numSamples)+((i-1)*timeShift)-1,numSamples)+1);
            end
            [corrvals(:,testtrial), ~]=corr(nctempl',squeeze(lagfixedInputData(testtrial,channel,mod([1:numSamples]+((correctTemplates(testtrial)-1)*timeShift)-1,numSamples)+1)));
        end
        [~, b]= max(corrvals);
        res(channel,:) =b;
        acc(channel)= mean(res(channel,trainset)==correctTemplates(trainset)');
    end
    [~, bestChannel] = max(acc);
end

