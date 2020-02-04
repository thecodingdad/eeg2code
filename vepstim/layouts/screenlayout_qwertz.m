classdef screenlayout_qwertz < screenlayout
    %SCREENLAYOUT_KEYBOARD - generates a keyboard layout with an arbitrary
    %   number of rows and columns
    
    properties (Constant)
        GAP_LEFT = 0.01;            %left gap of the layout (percentage)
        GAP_RIGHT = 0.01;           %right gap of the layout (percentage)
        GAP_BOTTOM = 0.01;          %bottom gap of the layout (percentage)
        GAP_TOP = 0.05;             %top gap of the layout (percentage)
        
        GAP_TARGETS = 0.005;         %gap between the targets (percentage)
        GAP_TEXT_TARGETS = 0.2;    %gap between the text field and the targets (percentage)
        
        UPPER_CASE =  {'°','!','"','§','$','%','&','/','(',')','=','?','`',char(8592),...
                      char(8633),'Q','W','E','R','T','Z','U','I','O','P','Ü','*',...
                      char(8681),'A','S','D','F','G','H','J','K','L','Ö','Ä','''',char(8626),...
                      char(8679),'>','Y','X','C','V','B','N','M',';',':','_',char(8679),...
                      ' '};
        LOWER_CASE = {char(94),'1','2','3','4','5','6','7','8','9','0','ß','´',char(8592),...
                      char(8633),'q','w','e','r','t','z','u','i','o','p','ü','+',...
                      char(8681),'a','s','d','f','g','h','j','k','l','ö','ä','#',char(8626),...
                      char(8679),'<','y','x','c','v','b','n','m',',','.','-',char(8679),...
                      ' '};
    end
    
    properties
        text_written = '';          %stores the written text
        text_target = '';           %stores the text to write
        
        highlightColor;             %highlight color
        targetColor;                %RGBA color for all targets
        stimulusColor;
        
        target_names = {};          
        is_shift = false;
        is_caps = false;
        
        labelsizes;
        
        textField_idx = 0;          %stores the index of the text field used for written text
    end
    
    methods(Access = public)
        function this = screenlayout_qwertz(windowPtr,varargin)
        %SCREENLAYOUT_KEYBORD - generates a keyboard layout of size [boxes_x,boxes_y]
        %   with predifined TARGET_NAMES, STIMULUSCOLOR, and TARGETCOLOR
            this@screenlayout(windowPtr,varargin{:});
            
            this.fontSize = 45;
            
            p = inputParser;
            p.StructExpand = true;
            p.KeepUnmatched = true;
            addParameter(p,'targetColor',this.GRAY,@(x) isfloat(x) && size(x,1) == 4 && all(x>=0 & x<=1));
            addParameter(p,'highlightColor',this.YELLOW,@(x) isfloat(x) && size(x,1) == 4 && all(x>=0 & x<=1));
            addParameter(p,'stimulusColor',this.WHITE,@(x) isfloat(x) && size(x,1) == 4 && all(x>=0 & x<=1));
            parse(p,varargin{:});
            
            this.targetColor = p.Results.targetColor;
            this.highlightColor = p.Results.highlightColor;
            this.stimulusColor = p.Results.stimulusColor;
            if ~this.is_shift && ~this.is_caps
                this.target_names = this.LOWER_CASE;
            else
                this.target_names = this.UPPER_CASE;
            end
            
            spezialchars = cellfun(@double,this.target_names)>8000;
            this.labelsizes = repmat(this.fontSize,[1,length(spezialchars)]);
            this.labelsizes(spezialchars) = this.labelsizes(spezialchars)+10;
            
            this.initLayout();
        end
    
        function initLayout(this)
        %INITLAYOUT - initializes the layout
            layout_width = round((1-(this.GAP_LEFT+this.GAP_RIGHT))*this.windowSize.width);
            layout_height = round((1-(this.GAP_TOP+this.GAP_BOTTOM))*this.windowSize.height);
            layout_left = round(this.GAP_LEFT*this.windowSize.width);
            layout_top  = round(this.GAP_TOP*this.windowSize.height);
            
            text_height = 120;
            this.textField_idx = this.addTextField([layout_left;layout_top;layout_width; text_height],this.BLACK,this.WHITE);
            
            text_target_gap = this.GAP_TEXT_TARGETS*layout_height;
                        
            target_gap_horizontal = this.GAP_TARGETS*layout_width;
            target_gap_vertical = this.GAP_TARGETS*layout_width;
            
            keyboard_top = layout_top+text_height+text_target_gap;
            keyboard_left = layout_left;
            keyboard_width = layout_width;
            keyboard_key_size = (keyboard_width-(target_gap_vertical*14))/15;
            
            % first row
            row_top = keyboard_top;
            row_left = keyboard_left;
            row_left = this.addEqualSizedTargets(13,row_left,row_top,keyboard_key_size,target_gap_vertical);
            this.addTarget('FillRect',[row_left;row_top;keyboard_width-row_left+keyboard_left;keyboard_key_size],this.stimulusColor,this.BLACK);
            % second row
            row_left = keyboard_left;
            row_top = row_top+keyboard_key_size+target_gap_horizontal;
            this.addTarget('FillRect',[row_left;row_top;1.5*keyboard_key_size+target_gap_vertical;keyboard_key_size],this.stimulusColor,this.BLACK);
            row_left = row_left+1.5*keyboard_key_size+2*target_gap_vertical;
            this.addEqualSizedTargets(12,row_left,row_top,keyboard_key_size,target_gap_vertical);
            % third row
            row_left = keyboard_left;
            row_top = row_top+keyboard_key_size+target_gap_horizontal;
            this.addTarget('FillRect',[row_left;row_top;1.7*keyboard_key_size+target_gap_vertical;keyboard_key_size],this.stimulusColor,this.BLACK);
            row_left = row_left+1.7*keyboard_key_size+2*target_gap_vertical;
            row_left = this.addEqualSizedTargets(12,row_left,row_top,keyboard_key_size,target_gap_vertical);
            this.addTarget('FillRect',[row_left;row_top-(keyboard_key_size+target_gap_horizontal);keyboard_width-row_left+keyboard_left;keyboard_key_size*2+target_gap_horizontal],this.stimulusColor,this.BLACK);
            % fourth row
            row_left = keyboard_left;
            row_top = row_top+keyboard_key_size+target_gap_horizontal;
            
            this.addTarget('FillRect',[row_left,row_top,1.2*keyboard_key_size+target_gap_vertical,keyboard_key_size]',this.stimulusColor,this.BLACK);
            row_left = row_left+1.2*keyboard_key_size+2*target_gap_vertical;
            row_left = this.addEqualSizedTargets(11,row_left,row_top,keyboard_key_size,target_gap_vertical);
            
            this.addTarget('FillRect',[row_left,row_top,keyboard_width-row_left+keyboard_left,keyboard_key_size]',this.stimulusColor,this.BLACK);
            %this.addTarget('FillRect',[row_left_shift1,row_top,1.2*keyboard_key_size+target_gap_vertical,keyboard_key_size;...
            %                           row_left,row_top,keyboard_width-row_left+keyboard_left,keyboard_key_size]',this.stimulusColor,this.BLACK);
            % fifth row
            row_left = keyboard_left + keyboard_width/4;
            row_top = row_top+keyboard_key_size+target_gap_horizontal;
            this.addTarget('FillRect',[row_left;row_top;keyboard_width/2;keyboard_key_size],this.stimulusColor,this.BLACK);
            
            Screen('TextFont', this.windowPtr,'Courier New');
            this.setTargetNames(this.target_names,this.targetColor,this.labelsizes);
        end
        
        function chooseTarget(this,target)
        %CHOOSETARGET - defines what to do if a target is selected
            chooseTarget@screenlayout(this,target);
            %this.highlightTarget(target,0.1);
            targetLabel = this.target_names{target};
            newText = this.text_written;
            switch(targetLabel)
                case char(8633)
                    newText = [newText '\t'];
                case char(8592)
                    newText = newText(1:(end-1));
                case char(8626)
                    newText = [newText '\n'];
                case char(8681)
                    this.toggleCaps();
                case char(8679)
                    this.toggleShift();
                otherwise
                    newText = [newText this.target_names{target}];
                    this.resetShift();
            end
            if ~strcmp(this.text_written,newText)
                this.text_written = newText;
                this.setText(this.textField_idx,this.text_written);
            end
        end
    end
    
    methods(Access = protected)
        function drawHighlight(this)
        %DRAWHIGHLIGHT - defines what to do if a target is highlighted
            this.targetColorsNext(:,this.highlightTarget) = this.highlightColor;
            this.targetToggleColorsNext(:,this.highlightTarget) = this.highlightColor;
        end
    end
    
    methods(Access = private)
        function toggleCaps(this)
            this.is_caps = ~this.is_caps;
            if this.is_caps
                this.target_names = this.UPPER_CASE;
            else
                this.target_names = this.LOWER_CASE;
            end
            this.setTargetNames(this.target_names,this.targetColor,this.labelsizes);
            
        end
        
        function toggleShift(this)
            this.is_shift = ~this.is_shift;
            if this.is_shift
                this.target_names = this.UPPER_CASE;
            else
                this.target_names = this.LOWER_CASE;
            end
            this.setTargetNames(this.target_names,this.targetColor,this.labelsizes);
        end
        
        function resetShift(this)
            if this.is_shift
                this.is_shift = false;
                this.target_names = this.LOWER_CASE;
                this.setTargetNames(this.target_names,this.targetColor,this.labelsizes);
            end
        end
        
        function left = addEqualSizedTargets(this,numTargets,left,top,size,gap)
            for ii=1:numTargets
                this.addTarget('FillRect',[left;top;size;size],this.stimulusColor,this.BLACK);
                left = left+size+gap;
            end
        end
    end
    
end

