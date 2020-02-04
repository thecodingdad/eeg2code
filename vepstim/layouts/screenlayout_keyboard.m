classdef screenlayout_keyboard < screenlayout
    %SCREENLAYOUT_KEYBOARD - generates a keyboard layout with an arbitrary
    %   number of rows and columns
    
    properties (Constant)
        GAP_LEFT = 0.05;            %left gap of the layout (percentage)
        GAP_RIGHT = 0.05;           %right gap of the layout (percentage)
        GAP_BOTTOM = 0.05;          %bottom gap of the layout (percentage)
        GAP_TOP = 0.05;             %top gap of the layout (percentage)
        
        GAP_TARGETS = 0.02;         %gap between the targets (percentage)
        GAP_TEXT_TARGETS = 0.04;    %gap between the text field and the targets (percentage)
    end
    
    properties
        text_written = '';          %stores the written text
        text_target = '';           %stores the text to write
        
        highlightColor;             %highlight color
        targetColor;                %RGBA color for all targets
        stimulusColor;
        
        boxes_x = 0;                %number of target columns
        boxes_y = 0;                %number of target rows
        target_names = {};          
        
        textField_idx = 0;          %stores the index of the text field used for written text
    end
    
    methods(Access = public)
        function this = screenlayout_keyboard(windowPtr,varargin)
        %SCREENLAYOUT_KEYBORD - generates a keyboard layout of size [boxes_x,boxes_y]
        %   with predifined TARGET_NAMES, STIMULUSCOLOR, and TARGETCOLOR
            this@screenlayout(windowPtr,varargin{:});
            
            p = inputParser;
            p.StructExpand = true;
            p.KeepUnmatched = true;
            addParameter(p,'targetColor',this.GRAY,@(x) isfloat(x) && size(x,1) == 4 && all(x>=0 & x<=1));
            addParameter(p,'highlightColor',this.YELLOW,@(x) isfloat(x) && size(x,1) == 4 && all(x>=0 & x<=1));
            addParameter(p,'stimulusColor',this.WHITE,@(x) isfloat(x) && size(x,1) == 4 && all(x>=0 & x<=1));
            addParameter(p,'boxes_x',8,@(x) helper.isint(x) && length(x) == 1);
            addParameter(p,'boxes_y',4,@(x) helper.isint(x) && length(x) == 1);
            addParameter(p,'target_names',cellstr(['A':'Z','_','1':'5']'),@iscell);
            parse(p,varargin{:});
            
            if ~iscell(p.Results.target_names), error('screenlayout_keyboard: target_names must be a cell of strings, one for each target'); end
            if (p.Results.boxes_x * p.Results.boxes_y) ~= length(p.Results.target_names) && ~isempty(p.Results.target_names), error('screenlayout_keyboard: color dimension missmatch. Usage: color = [r;g;b;a]'); end

            this.targetColor = p.Results.targetColor;
            this.highlightColor = p.Results.highlightColor;
            this.stimulusColor = p.Results.stimulusColor;
            this.boxes_x = p.Results.boxes_x;
            this.boxes_y = p.Results.boxes_y;
            this.target_names = p.Results.target_names;
            this.initLayout();
        end
    
        function initLayout(this)
        %INITLAYOUT - initializes the layout
            layout_width = round((1-(this.GAP_LEFT+this.GAP_RIGHT))*this.windowSize.width);
            layout_height = round((1-(this.GAP_TOP+this.GAP_BOTTOM))*this.windowSize.height);
            layout_left = round(this.GAP_LEFT*this.windowSize.width);
            layout_top  = round(this.GAP_TOP*this.windowSize.height);
            
            
            text_height = 40;
            this.textField_idx = this.addTextField([layout_left;layout_top;layout_width; text_height],this.BLACK,this.WHITE);
            
            text_target_gap = this.GAP_TEXT_TARGETS*layout_height;
                        
            target_gap_horizontal = this.GAP_TARGETS*layout_width;
            target_gap_vertical = this.GAP_TARGETS*layout_width;
            
            keyboard_top = layout_top+text_height+text_target_gap;
            keyboard_left = layout_left;
            keyboard_width = layout_width;
            keyboard_height = layout_height-text_height-text_target_gap;
            
            target_width = (keyboard_width-((this.boxes_x-1)*target_gap_horizontal))/this.boxes_x;
            target_height = (keyboard_height-((this.boxes_y-1)*target_gap_vertical))/this.boxes_y;
            
            row_top = keyboard_top;
            for line = 1:this.boxes_y
                row_left = keyboard_left;
                for col = 1:this.boxes_x
                    this.addTarget('FillRect',[row_left;row_top;target_width;target_height],this.stimulusColor,this.BLACK);
                    row_left = row_left + target_width + target_gap_horizontal;
                end
                row_top = row_top + target_height + target_gap_vertical;
            end
            
            this.setTargetNames(this.target_names,this.targetColor);
        end
        
        function chooseTarget(this,target)
        %CHOOSETARGET - defines what to do if a target is selected
            chooseTarget@screenlayout(this,target);
            
            this.text_written = [this.text_written this.target_names{target}];
            this.setText(this.textField_idx,this.text_written);
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

