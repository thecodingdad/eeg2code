classdef screenlayout_single_texture < screenlayout
%SCREENLAYOUT_SINGLE_TEXTURE - simple layout with only one centered texture target
    properties
        size;   %size [x,y] of the target in pixels
        centerPos;
    end
    
    methods(Access = public)
        function this = screenlayout_single_texture(windowPtr,varargin)
        %SCREENLAYOUT_SINGLE_TEXTURE - simple layout with only one centered texture target
        %   of size [width,height] with STIMULUSCOLOR
            this@screenlayout(windowPtr,varargin{:});
            p = inputParser;
            p.StructExpand = true;
            p.KeepUnmatched = true;
            addParameter(p,'width',150,@(x) helper.isint(x) && length(x) == 1);
            addParameter(p,'height',150,@(x) helper.isint(x) && length(x) == 1);
            parse(p,varargin{:});
            
            this.size = struct('width',p.Results.width,'height',p.Results.height);
            this.centerPos = [round((this.windowSize.width-this.size.width)/2),...
                              round((this.windowSize.height-this.size.height)/2)];
            this.initLayout();
        end
    end
    
    methods(Access = private)
        function initLayout(this)
        %INITLAYOUT - initializes the layout
            
            % the textures 
            imageTexture = Screen('MakeTexture', this.windowPtr, imread('konijntjes1024x768.jpg'));
            imageToggleTexture = Screen('MakeTexture', this.windowPtr, imread('konijntjes1024x768_mono.jpg'));
            
            % add target
            this.addTarget('DrawTexture',[this.centerPos(1);this.centerPos(2);this.size.width;this.size.height],imageTexture,imageToggleTexture);
        end
    end
    
    methods (Access = protected)
        function drawHighlight(this)
        %DRAWHIGHLIGHT - defines what to do if a target is highlighted
            targetPosition = this.targetPositions(:,this.highlightTarget);
            Screen('DrawLine', this.windowPtr, this.RED, this.centerPos(1), this.centerPos(2), targetPosition(1),targetPosition(2));
        end
    end
    
end

