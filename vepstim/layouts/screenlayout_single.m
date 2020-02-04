classdef screenlayout_single < screenlayout
%SCREENLAYOUT_SINGLE - simple layout with only one centered target
    properties
        size;   %size [x,y] of the target in pixels
        highlightColor;             %highlight color
        onColor;
        offColor;
    end
    
    methods
        function this = screenlayout_single(windowPtr,varargin)
        %SCREENLAYOUT_SINGLE - simple layout with only one centered target
        %   of size [width,height] with STIMULUSCOLOR
            this@screenlayout(windowPtr,varargin{:});
            p = inputParser;
            p.StructExpand = true;
            p.KeepUnmatched = true;
            addParameter(p,'onColor',[1;1;1;1],@(x) isfloat(x) && size(x,1) == 4 && all(x>=0 & x<=1));
            addParameter(p,'offColor',[0;0;0;1],@(x) isfloat(x) && size(x,1) == 4 && all(x>=0 & x<=1));
            addParameter(p,'width',150,@(x) helper.isint(x) && length(x) == 1);
            addParameter(p,'height',150,@(x) helper.isint(x) && length(x) == 1);
            addParameter(p,'highlightColor',[1;1;0;1],@(x) isfloat(x) && size(x,1) == 4 && all(x>=0 & x<=1));
            parse(p,varargin{:});
            
            this.onColor = p.Results.onColor;
            this.offColor = p.Results.offColor;
            this.highlightColor = p.Results.highlightColor;
            this.size = struct('width',p.Results.width,'height',p.Results.height);
            this.initLayout();
        end
        
        function initLayout(this)
        %INITLAYOUT - initializes the layout
            left = (this.windowSize.width-this.size.width)/2;
            top  = (this.windowSize.height-this.size.height)/2;
            
            this.addTarget('FillRect',[left;top;this.size.width;this.size.height],this.onColor,this.offColor);
            
            %gap = 20;
%             this.addTarget('FillRect',[left-this.size.width-gap,top-this.size.height-gap,this.size.width,this.size.height;...
%                                        left-this.size.width-gap,top,this.size.width,this.size.height;...
%                                        left-this.size.width-gap,top+this.size.height+gap,this.size.width,this.size.height;...
%                                        left,top-this.size.height-gap,this.size.width,this.size.height;...
%                                        left,top+this.size.height+gap,this.size.width,this.size.height;...
%                                        left+this.size.width+gap,top-this.size.height-gap,this.size.width,this.size.height;...
%                                        left+this.size.width+gap,top,this.size.width,this.size.height;...
%                                        left+this.size.width+gap,top+this.size.height+gap,this.size.width,this.size.height]',this.onColor,this.offColor);
        end
    end
    
    
    methods(Access = protected)
        function drawHighlight(this)
        %DRAWHIGHLIGHT - defines what to do if a target is highlighted
            this.targetColorsNext(:,this.highlightTarget) = this.highlightColor;
            this.targetToggleColorsNext(:,this.highlightTarget) = this.highlightColor;
        end
    end
    
end

