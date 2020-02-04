function [bits] = reproduceBits(path,subject,runs)
    subjectpath = sprintf('%s\\%s001\\',path,subject);
    for testrun = runs
        filename = sprintf('%s%sS001R%02i.dat',subjectpath,subject,testrun);
        [signal, bci_StateSamples, params]=load_bcidat(filename,'-calibrated');
        pport =   double([bci_StateSamples.DigitalInput1,...
                          bci_StateSamples.DigitalInput2,...
                          bci_StateSamples.DigitalInput3,...
                          bci_StateSamples.DigitalInput4,...
                          bci_StateSamples.DigitalInput5,...
                          bci_StateSamples.DigitalInput6,...
                          bci_StateSamples.DigitalInput7,...
                          bci_StateSamples.DigitalInput8]);
        stimSeed = params.stimSeed.NumericValue;
        randstream = RandStream('mt19937ar','Seed',stimSeed);
        if params.layout.NumericValue == 1
            numTargets = 32;
            load('M:\rvep-online\data_async\keyboardbits.mat','targetdelays');
        elseif params.layout.NumericValue == 2
            numTargets = 55;
            load('M:\rvep-online\data_async\qwertzbits.mat','targetdelays');
        end
        
        bla = stimulation_predefined(numTargets,'sequencePool','seqpool.csv','randomseed',stimSeed);
        
        trialstarts = find(diff(pport(:,4))==1)+1;
        trialends = find(diff(pport(:,4))==-1);
        if length(trialends)<length(trialstarts)
            trialends(end+1) = length(pport(:,4));
        end

        numBits = 0;
        for trial = 1:length(trialstarts)
            trialstart = trialstarts(trial);
            trialstop = trialends(trial);
            bitchanges = pport(trialstart:trialstop,3)';
            numBits = numBits + sum(diff(bitchanges)~=0)+1;
        end
        
        bits = zeros(numBits,numTargets+1);
        
        bit=0;
        for trial = 1:length(trialstarts)
            trialstart = trialstarts(trial);
            trialstop = trialends(trial);
            bitchanges = pport(trialstart:trialstop,3)';
            for ii = 1:sum(diff(bitchanges)~=0)+1
                bit = bit+1;
                bits(bit,:) = [bit,bla.next(0)];
            end
            bla.startTrial();
        end
        
        bitsTest = bits(:,2:end);
        for trial = 1:length(trialstarts)
            trialstart = trialstarts(trial);
            trialstop = trialends(trial);
            bitchanges = pport(trialstart:trialstop,3)';
            [samples,bitsTest] = upsampleBits(bitsTest,bitchanges,[]);
            if any(samples(1,:)~=pport(trialstart:trialstop,2)')
                error('bits async');
            end 
        end
        save([filename '_bits.mat'],'bits','targetdelays');
    end
end

