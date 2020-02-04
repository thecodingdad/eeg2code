function bci_Initialize( in_signal_dims, out_signal_dims )
%bci_Initialize is called after a successful Preflight. Thus, it may safely
%   omit all checks related to parameter consistency.
    % import required functions
    PATHS = {'functions','vepstim','vepstim/layouts','vepstim/stimulations'};
    addpath(PATHS{:});
    
    % BCI 2000 parameters and states
    global bci_Parameters;
    
    %% Playback mode?
    if isfield(bci_Parameters,'PlaybackFileName')
%         [~, ~, params]=load_bcidat(bci_Parameters.PlaybackFileName{1},'-calibrated');
%         bci_Parameters.triggerchannel{1} = params.triggerchannel.Value{1};
%         bci_Parameters.realeegchannels{1} = params.realeegchannels.Value{1};
%         bci_Parameters.SamplingRate{1} = params.SamplingRate.Value{1};
%         bci_Parameters.monitorRefreshRate{1} = params.monitorrate.Value{1};
%         bci_Parameters.randomseed{1} = params.randomseed.Value{1};
%         bci_Parameters.trialTime{1} = mat2str(str2double(params.triallength.Value{1})/1000);
%         bci_Parameters.interTrialTime{1} = mat2str(str2double(params.trialpause.Value{1})/1000);
%         %bci_Parameters.layout{1} = params.layout.Value{1};
%         %bci_Parameters.trials{1} = params.trials.Value{1};
%         %bci_Parameters.stimulation{1} = params.stimulation.Value{1};
%         bci_Parameters.startWait{1} = params.startwait.Value{1};
    end
    
    %% INITIALIZE SHARED MEMFILE
    in_signal = zeros(100,in_signal_dims(1)+1,in_signal_dims(2));
    block_counter = 0;
    block_counter_main = 0;
    block_counter_task = 0;
    stop = 0;
    start = 0;
    reload = 0;
    runComplete = 1;
    isError = 0;
    isSave1 = 1;
    isSave2 = 1;
    
    global shared
    shared = creatememmappedfile(in_signal,block_counter,isSave1,isSave2,stop,start,reload,runComplete,isError,block_counter_main,block_counter_task);
    
    while true
        if shared.data.isSave1
            shared.data.isSave1 = 0;
            if shared.data.isSave2
                shared.data.isSave2 = 0;
                shared.data.in_signal = in_signal;
                shared.data.block_counter_main = block_counter_main;
                shared.data.block_counter_task = block_counter_task;
                shared.data.stop = stop;
                shared.data.start = start;
                shared.data.reload = reload;
                shared.data.runComplete = runComplete;
                shared.data.isError = isError;
                shared.data.block_counter = 0;
                shared.data.isSave1 = 1;
                shared.data.isSave2 = 1;
                break;
            else
                shared.data.isSave1 = 1;
            end
        end
        pause(0.01);
    end
    
    save('bci_settings.mat','bci_Parameters','shared');
            
    global bci_task
    if isa(bci_task,'double')
        c = parcluster();
        [~,~,running,~] = findJob(c);
        if ~isempty(running), running.delete; end
    end
    
    shared.data.reload = 1;
    
    if isa(bci_task,'double') || (isa(bci_task,'parallel.job.CJSCommunicatingJob') && (~isvalid(bci_task) || strcmp(bci_task.State,'finished')))
        rmpath('C:\Users\Neuroteam\Downloads\biosig4octmat-3.1.0\biosig\demo\');
        bci_task = batch(@task_bci_Process,1,{shared},'Pool',2,'AutoAttachFiles',false,'AdditionalPaths',PATHS);
    end
    
    %% SET PROCESS PRIORITIES AND AFFINITIES
    % Main Process
    task_manager.setPriorityAndAffinity(feature('getpid'),'RealTime',3);
    % BCI2000 Processes
    task_manager.setPriorityAndAffinity('Operator','RealTime',3);
    task_manager.setPriorityAndAffinity('DummyApplication','RealTime',3);
    task_manager.setPriorityAndAffinity('cvepMatlabSignalProcessing','RealTime',3);
    if isfield(bci_Parameters,'PlaybackFileName')
        task_manager.setPriorityAndAffinity('FilePlayback','RealTime',3);
    else
        task_manager.setPriorityAndAffinity('gUSBampSource','RealTime',3);
    end
    % BATCH Process
    batch_process = bci_task.findTask();
    while strcmp(batch_process(1).State,'pending')
        pause(0.1);
    end
    task_manager.setPriorityAndAffinity(batch_process(1).Worker.ProcessId,'RealTime',12);
    % POOL Processes
    task_manager.setPriorityAndAffinity(batch_process(2).Worker.ProcessId,'RealTime',12);
    task_manager.setPriorityAndAffinity(batch_process(3).Worker.ProcessId,'RealTime',12);
end


