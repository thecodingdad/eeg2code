classdef vep_operator < handle
%VEP_OPERATOR is a tcpip bridge for the vep_experiment program.
%   It implements methods to send commands and settings to the vep_experiment.
%
%Usage:
%VEP_OPERATOR(HostAndPort) - tcpip host and port
%   Example: VEP_OPERATOR('localhost:3000')
%VEP_OPERATOR(___,NAME,VALUE)
%   debug - enable (true) or disable (false) debug mode (default: false)
%   settings - struct with settings (see <a href="matlab: help vep_operator.set">vep_operator.set</a>)
    properties (Constant)
        TCPIP_BUFFER_SIZE = 1024;
    end
    
    %% private properties
    properties(SetAccess = private, Hidden = true)
        tcpip;          %the tcpip connection object
    end
    
    %% read-only properties
    properties(SetAccess = private, Hidden = false)
        presentedbits = [];     %presented bits of a run
        processedbits = 0;      %number of processed bits
        settings;               %experiment settings
        debug = true;           %debug flag
        chosenTargets = [];     %logs the chosen targets during a run
        targetDelays;           %relative monitor delays of targets
        
        STIMULATIONTYPES = {};  %possible stimulation types
        LAYOUTTYPES = {};       %possible layouts
    end
    
    %% PUBLIC METHODS
    methods(Access = public)
        function this = vep_operator(HostAndPort,varargin)
            % define possible parameters
            p = inputParser;
            addRequired(p,'HostAndPort',@(x) ischar(x) && length(strsplit(HostAndPort,':')) == 2);
            addParameter(p,'debug',false,@islogical);
            addParameter(p,'settings',struct(),@isstruct);
            parse(p,HostAndPort,varargin{:});
            
            % set debug flag
            this.debug = p.Results.debug;
            % connect to vep_experiment and wait for answer
            this.initTcpip(HostAndPort);
            % set experiment settings
            this.set(p.Results.settings);
        end
        
        function set(this,varargin)
        %SET - set the settings of the experiment and send them to the vep_experiment
        %   SET() - use default settings
        %   SET(___,Name,Value)
        %   SET(struct) - struct with Name/Value pairs
        %
        %   Possible parameters:
        %   monitorResolution  - the monitor resolution that should be set
        %   monitorRefreshRate - the monitor refresh rate that should be set
        %   windowSize         - the dimension of the window ([top,left,width,height] in pixels or 'fullscreen')
        %   hideCursor         - hides the cursor if true
        %   layout             - name of the layout to be used for the experiment
        %   layoutSettings     - struct containing the layout settings
        %   stimulation        - name of the stimulation type used for the experiment
        %   stimSettings       - struct containing the stimulation settings
        %   framesPerStimulus  - number of frames for a single stimulus
        %   trials             - array of target indices used as trial order
        %   freeMode           - endless run if true
        %   startWait          - time (in seconds) to wait before a run will be started
        %   trialTime          - time (in seconds) of each trial (synchronous mode) or minimum trial time (asynchronous mode)
        %   interTrialTime     - time (in seconds) between 2 successive trials
        %   asynchronous       - asynchronous mode (true) or synchronous (false)
        %   playbackMode       - enables the playback mode (don't set parallel port and don't send bits through tcpip)
        
            loopStart = tic;
            while (isempty(this.LAYOUTTYPES) || isempty(this.STIMULATIONTYPES)) && toc(loopStart) < 5
                pause(1);
            end
            
            p = inputParser;
            p.StructExpand = true;
            p.KeepUnmatched = true;
            
            % define possible parameters
            addParameter(p,'monitorResolution',[1920,1080],@(x) helper.isint(x) && length(x) == 2);
            addParameter(p,'monitorRefreshRate',60,@(x) helper.isint(x) && length(x) == 1);
            addParameter(p,'windowSize','fullscreen',@(x) (ischar(x) && strcmp(x,'fullscreen')) || (helper.isint(x) && length(x) == 4));
            addParameter(p,'hideCursor',true,@islogical);
            addParameter(p,'layout','keyboard',@(x) (ischar(x) && any(ismember(this.LAYOUTTYPES,x))) || (helper.isint(x) && length(x) == 1 && x <= length(this.LAYOUTTYPES)));
            addParameter(p,'layoutSettings',struct(),@isstruct);
            addParameter(p,'stimulation','cvep',@(x) (ischar(x) && any(ismember(this.STIMULATIONTYPES,x))) || (helper.isint(x) && length(x) == 1 && x <= length(this.STIMULATIONTYPES)));
            addParameter(p,'stimSettings',struct(),@isstruct);
            addParameter(p,'framesPerStimulus',1,@(x) helper.isint(x) && length(x) == 1);
            addParameter(p,'trials',1,@helper.isint);
            addParameter(p,'freeMode',false,@islogical);
            addParameter(p,'startWait',5,@(x) helper.isint(x) && length(x) == 1);
            addParameter(p,'trialTime',1.05,@isfloat);
            addParameter(p,'interTrialTime',1.05,@isfloat);
            addParameter(p,'asynchronous',false,@islogical);
            addParameter(p,'playbackMode',false,@islogical);
            
            % parse parameters
            parse(p,varargin{:});
            
            % if settings already defined, just set new parameters
            if isstruct(this.settings) && ~isempty(p.UsingDefaults)
                previousParams = cell(1,length(p.UsingDefaults)*2);
                for param=1:length(p.UsingDefaults)
                    previousParams{param*2-1} = p.UsingDefaults{param};
                    previousParams{param*2} = this.settings.(p.UsingDefaults{param});
                end
                parse(p,varargin{:},previousParams{:});
            end
            
            % store parameters and send them to vep_experiment
            this.settings = p.Results;
            if isnumeric(this.settings.layout), this.settings.layout = this.LAYOUTTYPES{this.settings.layout}; end
            if isnumeric(this.settings.stimulation), this.settings.stimulation = this.STIMULATIONTYPES{this.settings.stimulation}; end
            this.chosenTargets = [];
            this.targetDelays = [];
            this.processedbits = 0;
            this.send('set',this.settings);
            % wait until layout is ready
            pause(2);
            this.getNumberOfTargets();
        end
        
        function start(this)
        %START - start experiment
            if ~this.settings.playbackMode
                this.presentedbits = [];
            end
            this.processedbits = 0;
            this.chosenTargets = [];
            this.send('start');
        end
        
        function stop(this)
        %STOP - end experiment 
            this.send('stop');
        end
        
        function close(this)
        %STOP - end experiment 
            this.send('close');
        end
        
        function exit(this)
        %STOP - end experiment 
            this.send('exit');
        end
        
        function endTrial(this)
        %ENDTRIAL - force trial end, only asynchronous mode
            if this.settings.asynchronous
                this.send('endTrial');
            end
        end
        
        function console(this,text)
        %CONSOLE - write TEXT to experiment console 
            this.send('console',text);
        end
        
        function info(this,text,varargin)
        %INFO - shows a info text on the screen
        %   INFO(text) - show TEXT for 10 seconds
        %   INFO(text,duration) - show TEXT for DURATION seconds
            if isempty(varargin), duration = 10; 
            else duration = varargin{1}; end
            this.send('setInfoText',text,duration);
        end
        
        function highlightTarget(this,idx,duration)
        %HIGHLIGHTTARGET - highlights a specific target
        %   HIGHLIGHTTARGET(idx,highlight) - highlight target IDX for DURATION seconds
            this.send('setHighlightTarget',idx,duration);
        end
        
        function chooseTarget(this,idx,duration)
        %CHOOSETARGET - choose a specific target and highlight it
        %   CHOOSETARGET(idx,highlight) - choose target IDX and highlight it for DURATION seconds
            this.chosenTargets = [this.chosenTargets,idx];
            this.send('chooseTarget',idx,duration);
        end
        
        function samples = getTargetSamples(this,bitchanges,afterTrialBitchanges)
        %GETTARGETSAMPLES - expands target bits to samples
        %   GETTARGETSAMPLES(bitchanges) - expands target bits to samples
        %       dependent on the bitchanges
            samplesPerBits = diff(find([1,abs(diff(bitchanges)),1]));
            if isempty(bitchanges), samplesPerBits = []; end
            afterTrialSamplesPerBits = diff(find([1,abs(diff(afterTrialBitchanges)),1]));
            if isempty(afterTrialBitchanges), afterTrialSamplesPerBits = []; end
            numBits = length(samplesPerBits)-length(afterTrialSamplesPerBits);
            bits = this.presentedbits(this.processedbits+1:this.processedbits+numBits,2:end)';
            %bits = this.presentedbits(this.processedbits+1:this.processedbits+numBits,:)';
            this.processedbits = this.processedbits+numBits;
            samples = zeros(size(this.presentedbits,2)-1,sum(samplesPerBits));
            %samples = zeros(size(this.presentedbits,2),sum(samplesPerBits));
            samplePos = 0;
            for bit = 1:numBits
                samples(:,samplePos+1:samplePos+samplesPerBits(bit)) = repmat(bits(:,bit),1,samplesPerBits(bit));
                samplePos = samplePos+samplesPerBits(bit);
            end
            samples(:,samplePos+1:end) = 1;
        end
        
        function ready = areTargetBitsReady(this,bitchanges,afterTrialBitchanges)
        %ARETARGETBITSREADY - checks if all required bits are recieved
        %   through tcpip. Aborts after 2 seconds.
            samplesPerBits = diff(find([1,abs(diff(bitchanges)),1]));
            if isempty(bitchanges), samplesPerBits = []; end
            afterTrialSamplesPerBits = diff(find([1,abs(diff(afterTrialBitchanges)),1]));
            if isempty(afterTrialBitchanges), afterTrialSamplesPerBits = []; end
            numBits = length(samplesPerBits)-length(afterTrialSamplesPerBits);
            ready = numBits == 0;
            loopStart = tic;
            while ~ready
                ready = numBits <= size(this.presentedbits,1)-this.processedbits;
                if numBits <= size(this.presentedbits,1)-this.processedbits;
                    if ~all(diff(this.presentedbits(this.processedbits+1:this.processedbits+numBits,1))==1)
                        [~,sortOrder] = sort(this.presentedbits(this.processedbits+1:end,1));
                        this.presentedbits(this.processedbits+1:length(sortOrder),:) = this.presentedbits(this.processedbits+sortOrder,:);
                    end
                    ready = all(diff(this.presentedbits(this.processedbits+1:this.processedbits+numBits,1))==1);
                end
                if ~ready, pause(0.015); end
                if toc(loopStart) > 2
                    break;
                end
            end
        end
        
        function delay = getDelayOfTarget(this,target)
        %GETDELAYOFTARGET - returns the relative delay of a specific target
            delay = this.targetDelays(target);
        end
        
        function numTargets = getNumberOfTargets(this)
        %GETNUMBEROFTARGETS - return the total number of possible targets
            loopStart = tic;
            while isempty(this.targetDelays) && toc(loopStart) < 60
                pause(1);
            end
            numTargets = length(this.targetDelays);
        end
        
        function disconnect(this)
        %DISCONNECT - stops the experiment, closes the tcp connection and reopen server on remote host
            this.send('stop');
            this.send('initTcpip',this.tcpip.RemotePort);
            fclose(this.tcpip);
        end
    end
    
    %% PRIVATE TCPIP METHODS
    methods(Access = private)
        function initTcpip(this,HostAndPort)
        %INITTCPIP - connect to vep_experiment tcpip server
        %   INITTCPIP(HostAndPort) - tcpip host and port
            % close and delete all tcpip connections
            if ~isempty(instrfind)
                fclose(instrfind);
                delete(instrfind);
            end
            
            % create connection and define callback function
            HostAndPort = strsplit(HostAndPort,':');
            this.tcpip = tcpip(HostAndPort{1}, str2double(HostAndPort{2}));
            this.tcpip.OutputBufferSize = this.TCPIP_BUFFER_SIZE;
            this.tcpip.InputBufferSize = this.TCPIP_BUFFER_SIZE;
            this.tcpip.BytesAvailableFcn = @(~, ~) this.tcpipCallback(strtrim(fscanf(this.tcpip)));
            % open connection
            fopen(this.tcpip);
        end
        
        function tcpipReadSynchronous(this)
        %TCPIPREADSYNCHRONOUS - synchronous check and evaluation of tcpip messages
            if isempty(this.tcpip.BytesAvailableFcn)
                while this.tcpip.BytesAvailable
                    this.tcpipCallback(strtrim(fscanf(this.tcpip)));
                end
            end 
        end
        
        function send(this,fun,varargin)
        %SEND - send tcpip command to vep_experiment
        %   SEND(fun) - call fun()
        %   SEND(fun,param1,...,paramN) - call fun(param1,...,paramN)
        %   SEND(fun,struct) - call fun(struct.Name1,struct.Value1,...,struct.NameN,struct.ValueN)
            if isa(this.tcpip,'tcpip') && isvalid(this.tcpip) && ~strcmp(this.tcpip.Status,'closed')
                if length(varargin) == 1 && isstruct(varargin{1})
                    % if parameters are set as struct, expand the struct
                    params = helper.structToCell(varargin{1});
                else
                    % else varargin are the parameters
                    params = varargin;
                end
                
                % convert parameters to string
                paramString = helper.paramsToString(false,params{:});
                
                % send function string as tcpip message
                this.log('send', sprintf('%s(%s)',fun,paramString));
                fprintf(this.tcpip,sprintf('%s(%s)',fun,paramString));
            end
        end
    end
    
    %% PRIVATE CALLBACK AND HELPER METHODS
    methods(Access = private)
        function tcpipCallback(this, cmd)
        %TCPIPCALLBACK - evaluation of tcpip messages
            this.log('tcpipCallback', cmd);
            eval(['this.' cmd]);
        end
        
        function tcpipCallback2(this,cmd)
        %TCPIPCALLBACK2 - alternative evaluation of tcpip messages evaluating 
        %   only the parameters, seems to have no performance differences
            this.log('tcpipCallback2',cmd);
            funend = strfind(cmd,'(');
            funname = cmd(1:funend(1)-1);
            params = eval(['{' cmd(funend(1)+1:end-1) '}']);
            this.(funname)(params{:});
        end
        
        function setModes(this,layouts,stimulations)
        %SETMODES - set possible layouts and stimulations
            this.LAYOUTTYPES = layouts;
            this.STIMULATIONTYPES = stimulations;
        end
        
        function setTargetDelays(this,delays)
        %SETTARGETDELAYS - sets the delay for each target
            this.targetDelays = delays;
        end
        
        function nextStimuli(this,bits)
        %NEXTSTIMULI - append recent presented stimuli
            this.presentedbits = [this.presentedbits;bits];
        end
        
        function log(this,fun,log)
        %LOG - helper function for logging
        %   LOG(fun,log) - FUNction name and LOGtext
            if this.debug, fprintf('%s: %s\n',fun,log); end
        end
    end
    
    %% PRESENTED BIT FUNCTIONS
    methods(Access = public)
        function savePresentedBits(this,filename)
        %SAVEPRESENTEDBITS(filename) - saves presented bits to FILENAME
            bits = this.presentedbits;
            targetdelays = this.targetDelays;
            [~,sortOrder] = sort(bits(:,1));
            bits = bits(sortOrder,:);
            if ~isempty(bits)
                save(filename,'bits','targetdelays');
            end
        end
        
        function loadPresentedBits(this,filename)
        %LOADPRESENTEDBITS(filename) - loads presented bits from FILENAME (for BCI2000 playback mode)
            if exist(filename,'file') == 2
                bitdata = load(filename);
                this.presentedbits = bitdata.bits;
                this.targetDelays = bitdata.targetdelays;
            end
        end
    end
    
end

