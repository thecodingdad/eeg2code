function splittraindata(path,subject,trainsets,nctrainrun)
    %subject = 'VP01';
    subjectpath = sprintf('%s/%s001/',path,subject);
    %subjectpath = sprintf('M:/rvep-online/data_keras/%s001/',subject);
    %trainsets = 1:3;
    %nctrainrun = 4;

    %% model
    train_data_x=[];
    train_data_y=[];
    maxtriallength = 4*600;
    for trainrun = trainsets
        filename = sprintf('%s%sS001R%02i.dat',subjectpath,subject,trainrun);
        [signal, bci_StateSamples, params]=load_bcidat(filename,'-calibrated');
        load([filename '_bits.mat']);
        [~,bitOrder]=sort(bits(:,1));
        bits = bits(bitOrder,2:end);
        channels = 1:32;
        usedchannels = params.TransmitChList.NumericValue';
        pport =  double([bci_StateSamples.DigitalInput1,...
              bci_StateSamples.DigitalInput2,...
              bci_StateSamples.DigitalInput3,...
              bci_StateSamples.DigitalInput4,...
              bci_StateSamples.DigitalInput5,...
              bci_StateSamples.DigitalInput6,...
              bci_StateSamples.DigitalInput7,...
              bci_StateSamples.DigitalInput8]);
        trialstarts = find(diff(pport(:,4))==1)+1;
        trialends = find(diff(pport(:,4))==-1);

        triallength=params.trialTime.NumericValue*params.SamplingRate.NumericValue;
        for trial = 1:length(trialstarts)
            trialstart = trialstarts(trial);
            trialstop = trialends(trial);
            triallength = trialstop-trialstart+1;
            trialdata = signal(trialstart:trialstop,channels)';

            bitchanges = pport(trialstart:trialstop,3)';
            [samples,bits] = upsampleBits(bits,bitchanges,[]);

            data_x = zeros(32,maxtriallength);
            data_y = zeros(32,maxtriallength);
            data_x(:,1:min(length(trialdata),maxtriallength)) = trialdata(:,1:min(length(trialdata),maxtriallength));
            data_y(:,1:min(length(trialdata),maxtriallength)) = samples(:,1:min(length(trialdata),maxtriallength));
            train_data_x = [train_data_x;shiftdim(data_x,-1)];
            train_data_y = [train_data_y;shiftdim(data_y,-1)];
        end
    end

    trainnc_data_x=[];
    trainnc_data_y=[];

    filename = sprintf('%s%sS001R%02i.dat',subjectpath,subject,nctrainrun);
    [signal, bci_StateSamples, params]=load_bcidat(filename,'-calibrated');
    load([filename '_bits.mat']);
    [~,bitOrder]=sort(bits(:,1));
    bits = bits(bitOrder,2:end);
    channels = 1:32;
    usedchannels = params.TransmitChList.NumericValue';
    pport =  double([bci_StateSamples.DigitalInput1,...
          bci_StateSamples.DigitalInput2,...
          bci_StateSamples.DigitalInput3,...
          bci_StateSamples.DigitalInput4,...
          bci_StateSamples.DigitalInput5,...
          bci_StateSamples.DigitalInput6,...
          bci_StateSamples.DigitalInput7,...
          bci_StateSamples.DigitalInput8]);
    trialstarts = find(diff(pport(:,4))==1)+1;
    trialends = find(diff(pport(:,4))==-1);

    triallength=params.trialTime.NumericValue*params.SamplingRate.NumericValue;
    for trial = 1:length(trialstarts)
        trialstart = trialstarts(trial);
        trialstop = trialends(trial);
        triallength = trialstop-trialstart+1;
        trialdata = signal(trialstart:trialstop,channels)';

        bitchanges = pport(trialstart:trialstop,3)';
        [samples,bits] = upsampleBits(bits,bitchanges,[]);

        data_x = trialdata;
        data_y = samples;
        trainnc_data_x = [trainnc_data_x;shiftdim(data_x,-1)];
        trainnc_data_y = [trainnc_data_y;shiftdim(data_y,-1)];
    end

    targetdelays = round(params.SamplingRate.NumericValue/params.monitorRefreshRate.NumericValue*targetdelays);
    windowSize = round(params.timelag.NumericValue/1000*params.SamplingRate.NumericValue);
    save(sprintf('%s%s_train.mat',subjectpath,subject),'train_data_x','train_data_y','trainnc_data_x','trainnc_data_y','usedchannels','targetdelays','windowSize');
end