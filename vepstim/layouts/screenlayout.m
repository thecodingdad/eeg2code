classdef screenlayout < handle
%SCREENLAYOUT - abstract class for all layouts, stores the positions/colors/etc.
%   of all targets/text fields/etc. and is responsible for drawing
    
    properties(SetAccess = private)
        windowPtr = 0;          %Psychtoolbox window pointer, required for drawing
        offWindowPtr = 0;
        offImage;
        windowSize;             %size of the window, used for scaling
                
        targetColors = [];      %RGBA values for each single target or texture IDs
        targetToggleColors = [];%RGBA values for each single target or texture IDs
        
        targetPositions = [];   %positions of the targets
        targetTypes = [];       %positions of the targets
        targetNames = [];       %labels for each single target (optional)
        targetNamesFontSize = [];
        targetNameColors = [];  %RGBA values for each target label
        targetIdxs = [];
        
        textValues = {};        %values of text fields
        textFields = [];        %position of text fields
        textFieldColors = [];   %background RGBA colors of text fields
        textColors = [];        %RGBA colors of the text field fonts
        
        infoText;               %value of the info text
        infoDuration;           %time to show the info text
        infoStartTime;          %timer for the info text
        infoFontSize;           %font size of the info text
        infoBackgroundColor;    %background color of the info text
        infoColor;              %font color if the info text
        
        highlightTarget;        %target index that should be highlighted
        highlightDuration;      %highlight duration
        highlightStartTime;     %timer for highlighting
    end
    
    properties(SetAccess = protected)
        
        fontSize = 15;          %font size of text fields
        targetColorsNext = [];  %RGBA values for each single target or texture IDs (used for next frame draw)
        targetToggleColorsNext = []; %RGBA values for each single target or texture IDs (used for next frame draw)
    end
    
    properties(SetAccess = private, Hidden = false)
        numTargets = 0;         %total number of targets
    end
    
    properties (Constant)
    %several predefined RGBA colors
        TRANS  = [0;0;0;0];
        WHITE  = [1;1;1;1];
        BLACK  = [0;0;0;1];
        GRAY   = [0.5;0.5;0.5;1];
        RED    = [1;0;0;1];
        GREEN  = [0;1;0;1];
        BLUE   = [0;0;1;1];
        YELLOW = [1;1;0;1];
        MAGENTA= [1;0;1;1];
        CYAN   = [0;1;1;1];
        ORANGE = [1;0.65;0;1];
        
        TARGETYPES = {'FillRect','FillOval','DrawTexture'};
    end
    
    methods(Access = public)
        function this = screenlayout(windowPtr,varargin)
        %SCREENLAYOUT - constructor for general layout parameters
            p = inputParser;
            p.StructExpand = true;
            p.KeepUnmatched = true;
            addRequired(p,'windowPtr',@(x) helper.isint(x) && length(x) == 1);
            addParameter(p,'infoColor',this.WHITE,@(x) isfloat(x) && size(x,1) == 4 && all(x>=0 & x<=1));
            parse(p,windowPtr,varargin{:});
            
            this.infoColor = p.Results.infoColor;
            
            this.windowPtr = windowPtr;
            [this.offWindowPtr,~]=Screen('OpenOffscreenWindow',this.windowPtr, this.TRANS);
            [width,height] = Screen('WindowSize', this.windowPtr);
            this.windowSize = struct('width',width,'height',height);
        end
        
        function addTarget(this,type,position,colorOrTexture,toggleColorOrTexture)
        %ADDTARGET - adds rectangular target(s) at POSITION with COLOR
            if size(position,1) ~= 4, error('addTarget: position dimension missmatch. Usage: position = [x;y;width;height]'); end
            
            if ischar(type), type = {type}; end
            [isType,type] = ismember(type,this.TARGETYPES);
            if ~all(isType), error('addTarget: unsupported target type'); end
            if length(type) ~= size(position,2) && length(type) ~= 1, error('addTarget: number of types (%.0f) must be 1 or number of added targets (%.0f)',length(type),size(position,2)); end
            if length(type) == 1, type = repmat(type,[1,size(position,2)]); end
            
            if any(type==3)
                if length(colorOrTexture) ~= 1, error('addTarget: texture dimension missmatch. Just use the texture index'); end
                if length(toggleColorOrTexture) ~= 1, error('addTarget: toggle texture dimension missmatch. Just use the texture index'); end
                colorOrTexture = [repmat(colorOrTexture,[3,1]);1];
                toggleColorOrTexture = [repmat(toggleColorOrTexture,[3,1]);1];
            end
            
            if size(colorOrTexture,1) ~= 4, error('addTarget: color dimension missmatch. Usage: color = [r;g;b;a]'); end
            if size(colorOrTexture,2) ~= size(position,2) && size(colorOrTexture,2) ~= 1, error('addTarget: number of colors (%.0f) must be 1 or number of added targets (%.0f)',size(colorOrTexture,2),size(position,2)); end
            if size(toggleColorOrTexture,2) ~= size(position,2) && size(toggleColorOrTexture,2) ~= 1, error('addTarget: number of toggle colors (%.0f) must be 1 or number of added targets (%.0f)',size(colorOrTexture,2),size(position,2)); end
            if size(colorOrTexture,2) < size(position,2), colorOrTexture = repmat(colorOrTexture,[1,size(position,2)]); end
            if size(toggleColorOrTexture,2) < size(position,2), toggleColorOrTexture = repmat(toggleColorOrTexture,[1,size(position,2)]); end
            
            position([3,4],:) = position([3,4],:) + position([1,2],:);
            this.targetTypes = [this.targetTypes,type];
            this.targetPositions = [this.targetPositions,position];
            this.targetColors = [this.targetColors,colorOrTexture];
            this.targetToggleColors = [this.targetToggleColors,toggleColorOrTexture];
            this.targetIdxs = [this.targetIdxs,ones(1,size(position,2))*(max([0,this.targetIdxs])+1)];
            this.numTargets = length(unique(this.targetIdxs));
        end
        
        function changeTargetPositions(this,positions)
        %CHANGETARGETPOSITIONS - rearrange targets
            if size(positions,1) ~= 4 || size(positions,2) ~= size(this.targetPositions,2), error('changeTargetPositions: positions dimension missmatch. size(positions) = [4,%.0f]',size(this.targetPositions,2)); end
            this.targetPositions = positions;
        end
        
        function setStimuli(this,nextStimuli)
        %SETSTIMULI - sets the opacity for each target
            if size(nextStimuli,2) ~= this.numTargets && size(nextStimuli,2) ~= 1, error('setStimuli: number of stimuli (%.0f) must be 1 or number of targets (%.0f)',size(nextStimuli,2),size(position,2)); end
            if size(nextStimuli,2) == 1, nextStimuli = repmat(nextStimuli,[1,this.numTargets]); end
            nextStimuli = nextStimuli(this.targetIdxs);
            this.targetColors(4,:) = nextStimuli;
            this.targetToggleColors(4,:) = 1-nextStimuli;
        end
        
        function setTargetNames(this,names,color,fontsizes)
        %SETTARGETNAMES - sets the target labels and font colors for each single target
            if ~iscell(names), error('setTargetNames: names must be of type cell'); end
            if size(color,1) ~= 4, error('setTargetNames: color dimension missmatch. Usage: color = [r;g;b;a]'); end
            if ~isempty(names) && length(names) ~= this.numTargets, error('setTargetNames: number of names (%.0f) does not match number of objects (%.0f)',length(names), this.numTargets); end
            if length(names) ~= size(color,2) && size(color,2) ~= 1, error('setTargetNames: number of colors (%.0f) must be 1 or number of names (%.0f)',size(color,2), length(names)); end
            if size(color,2) < length(names), color = repmat(color,[1,length(names)]); end
            this.targetNames = cellfun(@double,names);
            this.targetNames = this.targetNames(this.targetIdxs);
            if nargin==3
                this.targetNamesFontSize = repmat(this.fontSize,[1,length(names)]);
            else
                this.targetNamesFontSize = fontsizes;
            end
            this.targetNamesFontSize = this.targetNamesFontSize(this.targetIdxs);
            this.targetNameColors = color;
            this.targetNameColors = this.targetNameColors(:,this.targetIdxs);
            this.drawTargetNames();
        end
        
        function name = getTargetName(this,idx)
            name = char(this.targetNames(find(this.targetIdxs==idx,'first')));
        end
        
        function idx = addTextField(this,position,textcolor,backgroundcolor)
        %ADDTEXTFIELD - adds a text field at POSITION with TEXTCOLOR and BACKGROUNDCOLOR
            if size(textcolor,1) ~= 4, error('addTextField: textcolor dimension missmatch. Usage: textcolor = [r;g;b;a]'); end
            if size(backgroundcolor,1) ~= 4, error('addTextField: backgroundcolor dimension missmatch. Usage: backgroundcolor = [r;g;b;a]'); end
            if size(position,1) ~= 4, error('addTextField: position dimension missmatch. Usage: position = [x;y;width;height]'); end
            position([3,4],:) = position([3,4],:) + position([1,2],:);
            this.textFields = [this.textFields,position];
            this.textFieldColors = [this.textFieldColors,backgroundcolor];
            this.textColors = [this.textColors,textcolor];
            idx = length(this.textValues) + 1;
            this.textValues{idx} = '';
            this.drawTextFields();
        end
        
        function setText(this,idx,text)
        %SETTEXT - sets the TEXT for text field IDX
            this.textValues{idx} = text;
            this.drawTextFields();
        end
        
        function text = getText(this,idx)
        %GETTEXT - returns the text of text field IDX
            text = this.textValues{idx};
        end
        
        function setInfoText(this,text,fontSize,duration)
        %SETINFOTEXT - sets the text of the info text field for DURATION seconds,
        %   with FONTSIZE, FONTCOLOR, and BACKGROUNDCOLOR
            this.infoText = text;
            this.infoFontSize = fontSize;
            this.infoBackgroundColor = this.BLACK;
            this.infoDuration = duration;
            this.infoStartTime = tic;
        end
        
        function chooseTarget(this,target)
        %CHOOSETARGET - chooses a TARGET
            if target > this.numTargets
                error('chooseTarget: unkown target');
            end
        end
        
        function setHighlightTarget(this,target,duration)
        %SETHIGHLIGHTTARGET - highlight TARGET with COLOR for DURATION seconds
            if target > this.numTargets
                error('setHighlightTarget: unkown target');
            end
            this.highlightTarget = target;
            this.highlightDuration = duration;
            this.highlightStartTime = tic;
        end
        
        function delays = getTargetDelays(this)
        %GETTARGETDELAYS - returns the relative vertical position of each target 
        %   (can be used to calculate the presentation delay of each target)
            delays = round(mean(this.targetPositions([2,4],:)) / this.windowSize.height,3);
        end
        
        function drawLayout(this)
        %DRAWLAYOUT - draws the targets (and labels), the text fields and info text
            if ~isempty(this.targetPositions) && ~isempty(this.targetColors)
                this.drawTargets();
            end
            Screen('DrawTexture', this.windowPtr, this.offWindowPtr);
            if ~isempty(this.infoText) && toc(this.infoStartTime) < this.infoDuration
                this.drawInfoText();
            end
            Screen('DrawingFinished', this.windowPtr);
        end
        
        function startRun(this)
        %STARTRUN - this function is called once at the beginning of a experiment
        end
        
        function startTrial(this)
        %STARTTRIAL - this function is called once at the beginning of a trial
        end
        
        function interTrial(this)
        %INTERTRIAL - this function is called before each frame draw during the inter trial time
        end
        
        function intraTrial(this)
        %INTRATRIAL - this function is called before each frame draw during a trial
        end
        
        function endTrial(this)
        %ENDTRIAL - this function is called once at the end of a trial
        end
    end
    
    methods(Access = protected)
        
        function drawInfoText(this)
        %DRAWINFOTEXT - draws the info text
            Screen('TextSize', this.windowPtr, this.infoFontSize);
            Screen('TextBackgroundColor', this.windowPtr, this.infoBackgroundColor);
            Screen('Preference', 'TextAlphaBlending', 1);
            DrawFormattedText(this.windowPtr, this.infoText, 'center', 'center', this.infoColor, 0, 0, 0, 1, 0);
        end
        
        function drawTargets(this)
        %DRAWTARGETS - draws the targets
            this.targetColorsNext = this.targetColors;
            this.targetToggleColorsNext = this.targetToggleColors;
            if ~isempty(this.highlightTarget) && toc(this.highlightStartTime) < this.highlightDuration
                this.drawHighlight();
            end
            for type = unique(this.targetTypes)
                switch this.TARGETYPES{type}
                    case 'FillRect'
                        Screen('FillRect', this.windowPtr, ...
                            [this.targetToggleColorsNext(:,this.targetTypes==type),...
                                this.targetColorsNext(:,this.targetTypes==type)], ...
                            [this.targetPositions(:,this.targetTypes==type),...
                                this.targetPositions(:,this.targetTypes==type)]);
                    case 'FillOval'
                        Screen('FillOval', this.windowPtr, ...
                            [this.targetToggleColorsNext(:,this.targetTypes==type),...
                                this.targetColorsNext(:,this.targetTypes==type)], ...
                            [this.targetPositions(:,this.targetTypes==type),...
                                this.targetPositions(:,this.targetTypes==type)]);
                    case 'DrawTexture'
                        Screen('DrawTextures', this.windowPtr, ...
                            [this.targetToggleColorsNext(1,this.targetTypes==type),...
                                this.targetColorsNext(1,this.targetTypes==type)],[], ...
                            [this.targetPositions(:,this.targetTypes==type),...
                                this.targetPositions(:,this.targetTypes==type)], 0, 1, ...
                            [this.targetToggleColorsNext(4,this.targetTypes==type), ...
                                this.targetColorsNext(4,this.targetTypes==type)]);
                end
            end
        end
        
        function drawTargetNames(this)
        %DRAWTARGETNAMES - draws the labels of the targets
            Screen('TextBackgroundColor', this.windowPtr, this.TRANS);
            Screen('FillRect', this.offWindowPtr, this.TRANS, this.targetPositions);
            for ii=1:length(this.targetNames)
                if ii==1 || (ii>1 && this.targetNamesFontSize(ii-1) ~= this.targetNamesFontSize(ii))
                    Screen('TextSize', this.offWindowPtr, this.targetNamesFontSize(ii));
                end
                DrawFormattedText(this.offWindowPtr, this.targetNames(ii), 'center', 'center', this.targetNameColors(:,ii), 0, 0, 0, 1, 0, this.targetPositions(:,ii)');
            end
        end
        
        function drawTextFields(this)
        %DRAWTEXTFIELDS - draws all text fields
            Screen('TextSize', this.offWindowPtr, this.fontSize);
            Screen('FillRect', this.offWindowPtr, this.textFieldColors, this.textFields );
            for ii=1:length(this.textValues)
                DrawFormattedText(this.offWindowPtr, this.textValues{ii}, this.textFields(1,ii)+20, 'center', this.textColors(:,ii), 0, 0, 0, 1, 0, this.textFields(:,ii)');
            end
        end
        
        function drawHighlight(this)
        %DRAWHIGHLIGHT - defines what to do if a target is highlighted
        end
    end
    
end

