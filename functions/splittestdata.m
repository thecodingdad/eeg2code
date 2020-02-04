subject = 'VP01';
%subjectpath = sprintf('C:/Users/Neuro/Desktop/Sebastian/keras/%s001/',subject);
subjectpath = sprintf('M:/rvep-online/data_keras/%s001/',subject);
testsets = 5:7;

%% model
test_data_x=[];
test_data_y=[];
test_data_bitchanges=[];
maxtriallength = 5*600;
for trainrun = testsets
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
        
        targetdelay = targetdelays(trial);
        eegshift = round(targetdelay * 10);
        
        trialdata = circshift(signal(trialstart:trialstop,channels)',[0 -eegshift]);

        bitchanges = pport(trialstart:trialstop,3)';
        [samples,bits] = upsampleBits(bits,bitchanges,[]);

        data_x = zeros(32,maxtriallength);
        data_y = zeros(1,maxtriallength);
        data_bitchanges = zeros(1,maxtriallength);
        data_x(:,1:min(length(trialdata),maxtriallength)) = trialdata(:,1:min(length(trialdata),maxtriallength));
        data_y(:,1:min(length(trialdata),maxtriallength)) = samples(trial,1:min(length(trialdata),maxtriallength));
        data_bitchanges(:,1:min(length(trialdata),maxtriallength)) = bitchanges(1:min(length(trialdata),maxtriallength));
        test_data_x = [test_data_x;shiftdim(data_x,-1)];
        test_data_y = [test_data_y;data_y];
        test_data_bitchanges = [test_data_bitchanges;data_bitchanges];
    end
end

save(sprintf('%s%s.mat',subjectpath,subject),'test_data_x','test_data_y','test_data_bitchanges','usedchannels');