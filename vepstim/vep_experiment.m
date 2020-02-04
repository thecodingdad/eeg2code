classdef vep_experiment < handle
%VEP_EXPERIMENT - create vep experiments using PSYCHTOOLBOX
%   Create vep experiments with several layouts and stimulations.
%   Stimuli presentation can be variied with multiple parameters. Using
%   the vep_operator, the vep experiment can be operated remotely.
%
%Usage:
%VEP_EXPERIMENT(screenNumber) - open window on specific screen
%VEP_EXPERIMENT(___,Name,Value)
%   debug - enable (true) or disable (false) debug mode (default: false)
%   settings - struct with settings (see <a href="matlab: help vep_experiment.set">vep_experiment.set</a>)
%   tcpip - enable (true) or disable (false) tcpip server (default: true)
%   port - port used for tcpip server (default: 3000)

    %% constant properties: possible layouts and stimulations
    properties(Constant)
        TCPIP_BUFFER_SIZE = 1024;
    end
    
    %% private properties
    properties(SetAccess = private, Hidden = true)
        STIMULATIONTYPES;          %possible stimulation types
        LAYOUTTYPES;    %possible layouts
        
        screenNumber;   %number of the screen the window is shown
        windowPtr;      %internal window pointer for PSYCHTOOLBOX
        vbl;            %vertical blank time
        
        tcpip;          %tcpip object
        debug;          %debug flag
        
        interrupt = false;%interrupt flag to abort a run
        isRunning = false;%flag indicating if the experiment is running
        frameCounter = 0; %counts the number of processed frames
        
        trialStart;     %timepoint at trial start
        trialEnd;       %timepoint at trial end
    end
    
    % read-only properties
    properties(SetAccess = private, Hidden = false)
        screenSettings; %settings of the screen: resolution, refresh rate, ...
        computerInfo;
        settings;       %settings of the experiment
        layout;         %layout of the targets
        stimulation;    %stimulation used for experiment
        
        pport;
        
        recentFrameDrops = 0;   %delay of the last frame in number of frames
        totalFrameDrops = 0;    %total number of frame drops during last run
        duration;               %total duration of the last run in seconds
        
        lastbitoffirsttarget = 0;     %last presented bit of first target (used for synchronization)
    end
    
    %% PUBLIC METHODS
    methods(Access = public)
        function this=vep_experiment(screenNumber,varargin)
            % add required paths
            path = fileparts(mfilename('fullpath'));
            addpath(genpath(path));
            
            % scan for possible layouts and stimulations
            files = dir([path filesep 'layouts' filesep 'screenlayout_*.m']);
            this.LAYOUTTYPES = strrep(strrep({files.name},'.m',''),'screenlayout_','');
            files = dir([path filesep 'stimulations' filesep 'stimulation_*.m']);
            this.STIMULATIONTYPES = strrep(strrep({files.name},'.m',''),'stimulation_','');
            
            % define possible parameters
            p = inputParser;
            addRequired(p,'screenNumber',@(x) helper.isint(x) && length(x) == 1);
            addParameter(p,'debug',false,@islogical);
            addParameter(p,'settings',struct(),@isstruct);
            addParameter(p,'tcpip',true,@islogical);
            addParameter(p,'port',3000,@(x) helper.isint(x) && length(x) == 1);
            addParameter(p,'pport','378',@(x) isnumeric(x) || all(isstrprop(address,'xdigit')));
            parse(p,screenNumber,varargin{:});
            
            % set screen number and debug flag
            this.screenNumber = p.Results.screenNumber;
            this.computerInfo = mexext;
            this.debug = p.Results.debug;
            
            % init parallel port
            this.pport = PPort(p.Results.pport);
            
            % disable sync test (only during debug)
            Screen('Preference', 'SkipSyncTests', double(this.debug));
            Screen('Preference','TextEncodingLocale','UTF-16');
            Screen('Preference', 'TextRenderer', 0);
            
            % set experiment settings
            this.set(p.Results.settings);
            
            % innitialize tcpip server
            if p.Results.tcpip, this.initTcpip(p.Results.port); end
        end
        
        function set(this,varargin)
        %SET - set the settings of the experiment
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
        
            p = inputParser;
            p.StructExpand = true;
            p.KeepUnmatched = true;
            
            % define possible parameters
            addParameter(p,'monitorResolution',[1920,1080],@(x) helper.isint(x) && length(x) == 2);
            addParameter(p,'monitorRefreshRate',60,@(x) helper.isint(x) && length(x) == 1);
            addParameter(p,'windowSize','fullscreen',@(x) (ischar(x) && strcmp(x,'fullscreen')) || (helper.isint(x) && length(x) == 4));
            addParameter(p,'hideCursor',true,@islogical);
            addParameter(p,'layout','keyboard',@(x) ischar(x) && any(ismember(this.LAYOUTTYPES,x)));
            addParameter(p,'layoutSettings',struct(),@isstruct);
            addParameter(p,'stimulation','cvep',@(x) ischar(x) && any(ismember(this.STIMULATIONTYPES,x)));
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
                newParams = p.Parameters(~ismember(p.Parameters,p.UsingDefaults));
                previousParams = cell(1,length(p.UsingDefaults)*2);
                for param=1:length(p.UsingDefaults)
                    previousParams{param*2-1} = p.UsingDefaults{param};
                    previousParams{param*2} = this.settings.(p.UsingDefaults{param});
                end
                parse(p,varargin{:},previousParams{:});
            else
                newParams = p.Parameters;
            end
            
            % store settings
            this.settings = p.Results;
            
            % add required settings to stimSettings
            this.settings.stimSettings.monitorRefreshRate = this.settings.monitorRefreshRate;
            this.settings.stimSettings.framesPerStimulus = this.settings.framesPerStimulus;
            
            % any window exists?
            windowExists = ~isempty(Screen(this.windowPtr, 'WindowKind')) && Screen(this.windowPtr, 'WindowKind') ~= 0;
            
            % screen initialization required?
            if any(ismember(newParams,{'monitorResolution','monitorRefreshRate','windowSize'})) || ~windowExists
                this.initScreen();
                this.initLayout();
                this.send('setTargetDelays',this.layout.getTargetDelays());
                this.initStimulation();
            elseif any(ismember(newParams,{'layout','layoutSettings'}))
                this.initLayout();
                this.send('setTargetDelays',this.layout.getTargetDelays());
                this.initStimulation();
            elseif any(ismember(newParams,{'stimulation','stimSettings'}))
                this.initStimulation();
            end
            
            this.setParallelPort(0);
        end
        
        function start(this)
        %START - starts the experiment
            % hide mouse cursor
            if this.settings.hideCursor, HideCursor(); end
            % prepare new run
            this.initLayout();
            this.initStimulation();
            this.interrupt = false;
            this.layout.startRun();
            this.frameCounter = 0;
            this.totalFrameDrops = 0;
            this.recentFrameDrops = 0;
            % switch to synchronous tcpip mode
            this.tcpipMode('synchronous');
            % set maximum process priority
            Priority(MaxPriority(this.windowPtr));
            % show start counter
            this.initStartCounter();
            % store run start time
            startTime = tic;
            this.isRunning = true;
            
            % main loop
            this.loop();
            
            % measure run duration
            this.duration = toc(startTime);
            % indicating that experiment is finished, also to parallel port
            this.isRunning = false;
            this.setParallelPort(0);
            % switch to asynchronous tcpip mode
            this.tcpipMode('asynchronous');
            % reset process priority
            Priority(0);
            % show mouse cursor
            if this.settings.hideCursor, ShowCursor(); end
        end
        
        function stop(this)
        %STOP - interrupt the experiment if running
            this.interrupt = true;
        end
        
        function send(this,fun,varargin)
        %SEND - send tcpip command to vep_operator
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
        
        function close(this)
        %CLOSE - interrupt the experiment if running and close the current window
            this.stop();
            sca;
            clear Screen;
            this.windowPtr = [];
        end
        
        function exit(this)
        %EXIT - interrupt experiment, close the window and terminate the tcpip server
            this.close();
            
            % close and delete all tcpip connections
            this.closeTcpipConnections();
        end
        
        function startTrial(this)
        %STARTTRIAL - indicate that trial has started
            % time point at trial start
            this.trialStart = tic;
            this.trialEnd = 0;
            
            this.layout.startTrial()
            this.stimulation.startTrial();
        end
        
        function endTrial(this)
        %ENDTRIAL - indicate that trial has ended and inter trial time has started
            % time point at trial end
            this.trialEnd = tic;
            
            this.layout.endTrial();
            this.stimulation.endTrial();
        end
        
        function setInfoText(this,text,duration)
        %SETINFOTEXT - shows a info text on the screen
        %   SETINFOTEXT(text,duration) - shows TEXT for DURATION seconds
            this.layout.setInfoText(text,25,duration);
            if ~this.isRunning
                this.layout.drawLayout();
                % Flip to the screen
                this.vbl = Screen('Flip', this.windowPtr, this.vbl + 1);
            end
        end
        
        function chooseTarget(this,target,highlightDuration)
        %CHOOSETARGET - choose a specific target and highlight it
        %   CHOOSETARGET(idx,duration) - choose target IDX and highlight it for DURATION seconds
            this.layout.chooseTarget(target);
            this.setHighlightTarget(target,highlightDuration);
        end
        
        function setHighlightTarget(this,target,duration)
        %SETHIGHLIGHTTARGET - highlights a specific target
        %   SETHIGHLIGHTTARGET(target,duration) - highlight TARGET for DURATION seconds
            if duration > 0
                this.layout.setHighlightTarget(target,duration);
                if ~this.isRunning
                    this.layout.drawLayout();
                    % Flip to the screen
                    this.vbl = Screen('Flip', this.windowPtr, this.vbl + 1);
                end
            end
        end
        
        function console(~,text)
            fprintf('%s\n',text);
        end
        
        function log(this,fun,log)
        %LOG - helper function for logging
        %   LOG(fun,log) - FUNction name and LOGtext
            if this.debug, this.console(sprintf('%s: %s',fun,log)); end
            %fprintf('%s: %s\n',fun,log);
        end
    end
    
    %% PRIVATE INITIALIZATION METHODS
    methods(Access = private)
        function initScreen(this)
        %INITSCREEN - initialize the window
            % Here we call some default settings for setting up Psychtoolbox
            PsychDefaultSetup(2);
            
            % window exist? close it
            if ~isempty(this.windowPtr), this.close(); end
            
            this.setResolutionAndRefreshRate();
            if this.debug
                PsychDebugWindowConfiguration(0,0.5);
            end
            
            Screen('Preference', 'VBLTimestampingMode', -1);

            % Open an on screen window using PsychImaging and color it black.
            if ischar(this.settings.windowSize)
                [this.windowPtr, ~] = PsychImaging('OpenWindow', this.screenNumber, [0;0;0;0]);
            else
                [this.windowPtr, ~] = PsychImaging('OpenWindow', this.screenNumber, [0;0;0;0], this.settings.windowSize);
            end
            
            Screen('BlendFunction', this.windowPtr, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');
            
            this.screenSettings.ifi = Screen('GetFlipInterval', this.windowPtr);
        end
        
        function initLayout(this)
        %INITLAYOUT - initialize the layout of the targets
            % which layout?
            this.layout = feval(['screenlayout_' this.settings.layout],this.windowPtr,this.settings.layoutSettings);
            
            % draw layout
            this.layout.drawLayout();
            this.vbl = Screen('Flip', this.windowPtr);
        end
        
        function initStimulation(this)
        %INITSTIMULATION - initialize the stimulation dependent on the number of targets
            this.stimulation = feval(['stimulation_' this.settings.stimulation],this.layout.numTargets,this.settings.stimSettings);
        end
    end
    
    %% PRIVATE TCPIP METHODS
    methods(Access = private)
        function initTcpip(this,port)
        %INITTCPIP - start tcpip server
        %   INITTCPIP(port) - listen on PORT
            this.closeTcpipConnections();
            
            % draw the layout and show message
            this.setInfoText(sprintf('Waiting for tcpip connection on port %.0f',port),1);
            % create server
            this.tcpip = tcpip('0.0.0.0', port, 'NetworkRole', 'server');
            this.tcpip.OutputBufferSize = this.TCPIP_BUFFER_SIZE;
            this.tcpip.InputBufferSize = this.TCPIP_BUFFER_SIZE;
            this.tcpipMode('asynchronous');
            % open server an wait for connection
            fopen(this.tcpip);
            % send layouts and stimulations
            this.sendModes();
            % clear message
            this.layout.drawLayout();
            this.vbl = Screen('Flip', this.windowPtr, this.vbl + 1);
        end
        
        function tcpipMode(this,mode)
        %TCPIPMODE - set tcpip mode
        %   TCPIPMODE(mode) - mode can be 'synchronous' or 'asynchronous'
            if isa(this.tcpip,'tcpip') && isvalid(this.tcpip)
                switch(mode)
                    case 'synchronous'
                        this.tcpip.BytesAvailableFcn = '';
                    case 'asynchronous'
                        % read unprocessed tcpip messages
                        this.tcpipReadSynchronous();
                        this.tcpip.BytesAvailableFcn = @(~, ~) this.tcpipCallback(strtrim(fscanf(this.tcpip)));
                end
            end
        end
        
        function tcpipCallback(this,cmd)
        %TCPIPCALLBACK - evaluation of tcpip messages
            this.log('tcpipCallback',cmd);
            eval(['this.' cmd ';']);
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
        
        function tcpipReadSynchronous(this)
        %TCPIPREADSYNCHRONOUS - synchronous check and evaluation of tcpip messages
            if isa(this.tcpip,'tcpip') && isvalid(this.tcpip) && ~strcmp(this.tcpip.Status,'closed') && isempty(this.tcpip.BytesAvailableFcn)
                % evaluate tcpip messages as long as new messages are available
                while this.tcpip.BytesAvailable
                    this.tcpipCallback(strtrim(this.tcpip.fscanf));
                end
            end 
        end
        
        function closeTcpipConnections(this)
            % close and delete all tcpip connections
            if ~isempty(instrfind)
                fclose(instrfind);
                delete(instrfind);
                this.tcpip = [];
            end
        end
        
        function sendModes(this)
        %SENDMODES - get possible layouts and stimulations and send them to vep_operator
            this.send('setModes',this.LAYOUTTYPES,this.STIMULATIONTYPES);
        end
    end
    
    %% PRIVATE EXPERIMENTAL METHODS
    methods(Access = public)
        function initStartCounter(this)
        %INITSTARTCOUNTER - show experiment start counter
            for t = this.settings.startWait:-1:0
                if t == 0
                    this.setInfoText('',1);
                else
                    this.setInfoText(sprintf('Start in %.0f',t),1);
                end
            end
        end
        
        function loop(this)
        %LOOP - experiment loop
            % indicate that a new trial will start;
            this.startTrial();
            
            escapeKey = KbName('ESCAPE');
            [~,~,keyCode] = KbCheck;
            
            while ~keyCode(escapeKey)
                % read and execute recent tcpip commands
                this.tcpipReadSynchronous();
                
                % draw next frame
                if ~isempty(this.windowPtr), this.drawFrame(); end
                
                % terminate if experiment is interrupted
                if this.interrupt, break; end
                
                if this.stimulation.isTrial
                    % synchronous mode? end trial after specified trial time
                    if ~this.settings.asynchronous && toc(this.trialStart) > this.settings.trialTime
                        % indicate that the trial has ended;
                        this.endTrial();
                    end
                else
                    % check end of inter trial time
                    if this.trialEnd && toc(this.trialEnd) > this.settings.interTrialTime
                        % free mode? if not, terminate experiment after defined number of trials
                        if ~this.settings.freeMode && this.stimulation.numTrials == length(this.settings.trials)
                            break;
                        end
                        this.startTrial();
                    end
                end
                [~,~,keyCode] = KbCheck;
            end
        end
        
        function drawFrame(this)
        %DRAWFRAME - processing of each single frame
            this.frameCounter = this.frameCounter+1;
            if this.stimulation.isTrial && ~this.interrupt
                % count lost bits caused by frame drops, required to get correct upcoming stimulus
                if this.stimulation.trialPos == 0
                    lostBits = 0;
                else
                    lostBits = floor(this.recentFrameDrops/this.settings.framesPerStimulus);
                end
                % get upcoming bits for each target
                nextStimuli = this.stimulation.next(lostBits);
                % send bits through tcpip
                this.sendNextStimuli(nextStimuli);
                % stimulation only during trial
                this.layout.setStimuli(nextStimuli);
                % notify layout about inter-trial time
                this.layout.intraTrial();
            else
                if this.stimulation.interTrialStimuli
                    this.layout.setStimuli(this.stimulation.next(0));
                else
                    % targets are fully visible during inter trial time
                    this.layout.setStimuli(1);
                end
                % notify layout about inter-trial time
                this.layout.interTrial();
            end

            % draw the layout
            this.layout.drawLayout();
            % assure that trialstart time is correct at the beginning of the experiment;
            if this.stimulation.numBits == 1
                this.trialStart = tic;
            end
            % Flip to the screen
            vblank = Screen('Flip', this.windowPtr, this.vbl + (this.settings.framesPerStimulus-0.5) * this.screenSettings.ifi);
            
            % set trigger right after frame is shown
            this.setTrigger();
            % test if intra-trial frame drop occured
            if this.stimulation.isTrial && this.stimulation.trialPos ~=1
                this.recentFrameDrops = round((vblank-this.vbl)/this.screenSettings.ifi) - this.settings.framesPerStimulus;
                this.totalFrameDrops = this.totalFrameDrops + this.recentFrameDrops;
            else
                this.recentFrameDrops = 0;
            end
            this.vbl = vblank;
        end
        
        function sendNextStimuli(this,bits)
        %SENDNEXTSTIMULI - store the presented stimuli of each target and send them to the vep_operator
            this.lastbitoffirsttarget = round(bits(1));
            if ~this.settings.playbackMode
                this.send('nextStimuli',[this.frameCounter,bits]);
            end
        end
        
        function setTrigger(this)
        %SETTRIGGER - sets current experiment states
            if ~this.settings.playbackMode
                bits = [0 0 0 ...                               unused bits
                        this.stimulation.isSequenceStart()...   marks the start of a sequence
                        this.stimulation.isTrial()...           marks the trial (=1) and the pause (=0)
                        mod(this.frameCounter,2)...             switch between 1 and 0 at each presented bit
                        this.lastbitoffirsttarget...     bit sequence of the first target
                        this.isRunning...                       is experiment started?
                        ];
                bits = double(bits & this.isRunning);
                this.setParallelPort(bits);
                
                this.log('setTrigger',arrayfun(@(x) mat2str(x),bits));
            end
        end
        
        function setParallelPort(this,bits)
        %SETPARALLELPORT(bits) - sets the BITS of the paralell port
            % convert bit array to bit string
            if ~ischar(bits)
                bits = arrayfun(@(x) mat2str(x),bits);
            end
            
            this.pport.outp(bin2dec(bits));
        end
        
        function setResolutionAndRefreshRate(this)
        %SETRESOLUTIONANDREFRESHRATE - checks if modus is supported and
        %   sets the new resolution and/or refreshrate if changed
            
            % Read settings of current screen modus
            this.screenSettings = rmfield(Screen('Resolution', this.screenNumber),'pixelSize');
            % get all possible modi
            modi = rmfield(Screen('Resolutions', this.screenNumber),'pixelSize');
            % new modus
            modus = struct('width',this.settings.monitorResolution(1),...
                           'height',this.settings.monitorResolution(2),...
                           'hz',this.settings.monitorRefreshRate);
            % check if modus is supported
            if any(arrayfun(@(x) isequal(x,modus),modi))
                % check if modus has changed
                if ~isequal(this.screenSettings,modus)
                    Screen('Resolution', this.screenNumber, modus.width, modus.height, modus.hz);
                    this.screenSettings = rmfield(Screen('Resolution', this.screenNumber),'pixelSize');
                end
            else % show info text if modus not supported
                error('Resolution and/or refresh rate not supported');
            end
        end
    end

end