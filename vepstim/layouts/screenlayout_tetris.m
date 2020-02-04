classdef screenlayout_tetris < screenlayout
%SCREENLAYOUT_SINGLE - simple layout with only one centered target
    properties
        size;   %size [x,y] of the target in pixels
        highlightColor;             %highlight color
        targetColor;
        onColor;
        offColor;
        showNextBlock;
        
        fields;
        boxSize;
        fieldSize;
        gameField
        boxTexture;
        
        currentBlock;
        nextBlock;
        
        target;
        
        moveTimer;
        
        gameOver;
        
        moveSpeed; % block will move down each moveSpeed seconds
        
        BLOCKS;
    end
    
    
    properties (Constant)
        %blocks
        STRAIGHT  = struct('left',4,'top',1,'color',screenlayout.CYAN   ,'fields',true(1,4));
        SQUARE    = struct('left',5,'top',1,'color',screenlayout.YELLOW ,'fields',true(2,2));
        TRIANGLE  = struct('left',4,'top',1,'color',screenlayout.MAGENTA,'fields',[false,true,false;true(1,3)]);
        RIGHTTURN = struct('left',4,'top',1,'color',screenlayout.GREEN  ,'fields',[false,true(1,2);true(1,2),false]);
        LEFTTURN  = struct('left',4,'top',1,'color',screenlayout.RED    ,'fields',[true(1,2),false;false,true(1,2)]);
        LEFTL     = struct('left',4,'top',1,'color',screenlayout.BLUE   ,'fields',[true,false(1,2);true(1,3)]);
        RIGHTL    = struct('left',4,'top',1,'color',screenlayout.ORANGE ,'fields',[false(1,2),true;true(1,3)]);
        EMPTY     = struct('left',4,'top',1,'color',screenlayout.TRANS  ,'fields',true(2,4));
    end
    
    methods
        function this = screenlayout_tetris(windowPtr,varargin)
        %SCREENLAYOUT_SINGLE - simple layout with only one centered target
        %   of size [width,height] with STIMULUSCOLOR
            this@screenlayout(windowPtr,varargin{:});
            p = inputParser;
            p.StructExpand = true;
            p.KeepUnmatched = true;
            addParameter(p,'onColor',[1;1;1;1],@(x) isfloat(x) && size(x,1) == 4 && all(x>=0 & x<=1));
            addParameter(p,'offColor',[0;0;0;1],@(x) isfloat(x) && size(x,1) == 4 && all(x>=0 & x<=1));
            addParameter(p,'moveSpeed',1,@(x) isfloat(x) && length(x) == 1);
            addParameter(p,'width',150,@(x) helper.isint(x) && length(x) == 1);
            addParameter(p,'height',150,@(x) helper.isint(x) && length(x) == 1);
            addParameter(p,'highlightColor',[1;1;0;1],@(x) isfloat(x) && size(x,1) == 4 && all(x>=0 & x<=1));
            addParameter(p,'targetColor',this.GRAY,@(x) isfloat(x) && size(x,1) == 4 && all(x>=0 & x<=1));
            addParameter(p,'showNextBlock',true,@islogical);
            parse(p,varargin{:});
            
            this.onColor = p.Results.onColor;
            this.offColor = p.Results.offColor;
            this.highlightColor = p.Results.highlightColor;
            this.moveSpeed = p.Results.moveSpeed;
            this.showNextBlock = p.Results.showNextBlock;
            
            this.target = struct('width',p.Results.width,'height',p.Results.height);
            
            this.fieldSize = struct('boxes_x',10,'boxes_y',20);
            this.gameField = zeros(this.fieldSize.boxes_y,this.fieldSize.boxes_x,4);
            this.targetColor = p.Results.targetColor;
            
            this.boxSize = this.windowSize.height/(this.fieldSize.boxes_y+4);
            
            this.boxTexture = Screen('MakeTexture', this.windowPtr, imread('box.png'));
            
            
            this.BLOCKS = {this.STRAIGHT,this.SQUARE,this.TRIANGLE,this.RIGHTTURN,this.LEFTTURN,this.LEFTL,this.RIGHTL};
            
            this.currentBlock = this.BLOCKS{randi(length(this.BLOCKS))};
            this.nextBlock = this.BLOCKS{randi(length(this.BLOCKS))};
            
            this.initLayout();
            
            this.drawBlock(this.currentBlock,false);
            this.drawBlock(this.nextBlock,true);
            
            this.gameOver = false;
        end
        
        function initLayout(this)
        %INITLAYOUT - initializes the layout
            this.initGameField();
            
            this.initNextBlockPreview();
            
            this.initTargets();
        end
        
        function chooseTarget(this,target)
        %CHOOSETARGET - chooses a TARGET
            chooseTarget@screenlayout(this,target);
            switch (target)
                case 1
                    this.moveBlock('left');
                case 2
                    this.moveBlock('rotateLeft');
                case 3
                    this.moveBlock('right');
                case 4
                    this.moveBlock('rotateRight');
            end
        end
        
        function startRun(this)
        %STARTRUN - this function is called once at the beginning of a experiment
            this.moveTimer = tic;
        end
        
        function interTrial(this)
        %INTERTRIAL - this function is called before each frame draw during the inter trial time
            this.frametick();
        end
        
        function intraTrial(this)
        %INTRATRIAL - this function is called before each frame draw during a trial
            this.frametick();
        end
    end
    
    
    methods(Access = protected)
        function drawHighlight(this)
        %DRAWHIGHLIGHT - defines what to do if a target is highlighted
            this.targetColorsNext(:,this.highlightTarget) = this.highlightColor;
            this.targetToggleColorsNext(:,this.highlightTarget) = this.highlightColor;
        end
    end
    
    
    methods(Access = public)
        function initGameField(this)
            this.fieldSize.width = this.fieldSize.boxes_x*this.boxSize;
            this.fieldSize.height = this.fieldSize.boxes_y*this.boxSize;
            this.fieldSize.left = (this.windowSize.width-this.fieldSize.width)/2;
            this.fieldSize.top = (this.windowSize.height-this.fieldSize.height)/2;
            this.fieldSize.right = this.fieldSize.left+this.fieldSize.width;
            this.fieldSize.bottom = this.fieldSize.top+this.fieldSize.height;
            
            % upper bound
            left = this.fieldSize.left-this.boxSize;
            top = this.fieldSize.top-this.boxSize;
            for x=0:this.fieldSize.boxes_x+1
                this.drawBox(left,top,this.GRAY);
                left = left+this.boxSize;
            end
            
            % bottom bound
            left = this.fieldSize.left-this.boxSize;
            top = this.fieldSize.bottom;
            for x=0:this.fieldSize.boxes_x+1
                this.drawBox(left,top,this.GRAY);
                left = left+this.boxSize;
            end
            
            % left bound
            left = this.fieldSize.left-this.boxSize;
            top = this.fieldSize.top;
            for y=1:this.fieldSize.boxes_y
                this.drawBox(left,top,this.GRAY);
                top = top+this.boxSize;
            end
            
            % right bound
            left = this.fieldSize.right;
            top = this.fieldSize.top;
            for y=1:this.fieldSize.boxes_y
                this.drawBox(left,top,this.GRAY);
                top = top+this.boxSize;
            end
        end
        
        function initNextBlockPreview(this)
            if this.showNextBlock
                % upper bound
                left = this.fieldSize.right;%+2*this.boxSize;
                top = this.fieldSize.top-this.boxSize;
                for x=1:6
                    this.drawBox(left,top,this.GRAY);
                    left = left+this.boxSize;
                end
                
                % bottom bound
                left = this.fieldSize.right;%+2*this.boxSize;
                top = this.fieldSize.top+2*this.boxSize;
                for x=1:6
                    this.drawBox(left,top,this.GRAY);
                    left = left+this.boxSize;
                end
            
                % left bound
                left = this.fieldSize.right;%+2*this.boxSize;
                top = this.fieldSize.top;
                for y=1:2
                    this.drawBox(left,top,this.GRAY);
                    top = top+this.boxSize;
                end
            
                % right bound
                left = this.fieldSize.right+5*this.boxSize;
                top = this.fieldSize.top;
                for y=1:2
                    this.drawBox(left,top,this.GRAY);
                    top = top+this.boxSize;
                end
            end
        end
        
        function initTargets(this)
            % move left
            left = this.fieldSize.left-2*this.boxSize-this.target.width;
            top = (this.windowSize.height-2*this.target.height-this.boxSize)/2;
            this.addTarget('FillRect',[left;top;this.target.width;this.target.height],this.onColor,this.offColor);
            
            % rotate left
            top = top+this.target.height+this.boxSize;
            this.addTarget('FillRect',[left;top;this.target.width;this.target.height],this.onColor,this.offColor);
            
            % move right
            left = this.fieldSize.right+2*this.boxSize;
            top = (this.windowSize.height-2*this.target.height-this.boxSize)/2;
            this.addTarget('FillRect',[left;top;this.target.width;this.target.height],this.onColor,this.offColor);
            
            % rotate right
            top = top+this.target.height+this.boxSize;
            this.addTarget('FillRect',[left;top;this.target.width;this.target.height],this.onColor,this.offColor);
            
            Screen('TextSize', this.offWindowPtr,20);
            Screen('TextFont', this.offWindowPtr, 'Arial');
            
            this.setTargetNames({char(8592),char(8630),char(8594),char(8631)},this.targetColor);
        end
        
        function drawBlock(this,block,preview)
            if ~preview || this.showNextBlock
                blockSize = size(block.fields);
                positions = zeros(sum(block.fields(:)),4);
                box = 0;
                for row = 1:blockSize(1)
                    for col = 1:blockSize(2)
                        if block.fields(row,col)
                            box = box+1;
                            if preview
                                [left,top] = this.getBlockPreviewPos(block.left+col-1,block.top+row-1);
                            else
                                [left,top] = this.getBlockPos(block.left+col-1,block.top+row-1);
                            end
                            positions(box,:) = [left,top,left+this.boxSize,top+this.boxSize];
                        end
                    end
                end
                Screen('DrawTextures', this.offWindowPtr, this.boxTexture, [], positions', 0, 1, 1, block.color);
            end
        end
        
        function frametick(this)
            if toc(this.moveTimer) > this.moveSpeed && ~this.gameOver
                this.moveTimer = tic;
                
                collision = this.moveBlock('down');
                    
                if collision
                    this.gameField(this.currentBlock.top:this.currentBlock.top+size(this.currentBlock.fields,1)-1,this.currentBlock.left:this.currentBlock.left+size(this.currentBlock.fields,2)-1,1) = ...
                        this.gameField(this.currentBlock.top:this.currentBlock.top+size(this.currentBlock.fields,1)-1,this.currentBlock.left:this.currentBlock.left+size(this.currentBlock.fields,2)-1,1) + this.currentBlock.fields*this.currentBlock.color(1);
                    this.gameField(this.currentBlock.top:this.currentBlock.top+size(this.currentBlock.fields,1)-1,this.currentBlock.left:this.currentBlock.left+size(this.currentBlock.fields,2)-1,2) = ...
                        this.gameField(this.currentBlock.top:this.currentBlock.top+size(this.currentBlock.fields,1)-1,this.currentBlock.left:this.currentBlock.left+size(this.currentBlock.fields,2)-1,2) + this.currentBlock.fields*this.currentBlock.color(2);
                    this.gameField(this.currentBlock.top:this.currentBlock.top+size(this.currentBlock.fields,1)-1,this.currentBlock.left:this.currentBlock.left+size(this.currentBlock.fields,2)-1,3) = ...
                        this.gameField(this.currentBlock.top:this.currentBlock.top+size(this.currentBlock.fields,1)-1,this.currentBlock.left:this.currentBlock.left+size(this.currentBlock.fields,2)-1,3) + this.currentBlock.fields*this.currentBlock.color(3);
                    this.gameField(this.currentBlock.top:this.currentBlock.top+size(this.currentBlock.fields,1)-1,this.currentBlock.left:this.currentBlock.left+size(this.currentBlock.fields,2)-1,4) = ...
                        this.gameField(this.currentBlock.top:this.currentBlock.top+size(this.currentBlock.fields,1)-1,this.currentBlock.left:this.currentBlock.left+size(this.currentBlock.fields,2)-1,4) + this.currentBlock.fields*this.currentBlock.color(4);
                    this.currentBlock = this.nextBlock;
                    this.nextBlock = this.BLOCKS{randi(length(this.BLOCKS))};
                    this.drawBlock(this.currentBlock,false);
                    this.drawBlock(this.EMPTY,true);
                    this.drawBlock(this.nextBlock,true);
                    this.checkFullRows();
                    
                    if this.checkCollision(this.currentBlock)
                        this.gameOver = true;
                    end
                end
                
            end
        end
        
        function checkFullRows(this)
            fullrows = sort(find(all(any(this.gameField,3),2)));
            if ~isempty(fullrows)
                for row = fullrows
                    this.gameField(2:row,:,:) = this.gameField(1:row-1,:,:);
                    this.gameField(1,:,:) = zeros(1,this.fieldSize.boxes_x,4);
                end
            
                positions = zeros(fullrows(end)*this.fieldSize.boxes_x,4);
                colors = zeros(fullrows(end)*this.fieldSize.boxes_x,4);
                box = 0;
                for row = 1:fullrows(end)
                    for col = 1:this.fieldSize.boxes_x
                        box = box+1;
                        [left,top] = this.getBlockPos(col,row);
                        positions(box,:) = [left,top,left+this.boxSize,top+this.boxSize];
                        colors(box,:) = squeeze(this.gameField(row,col,:))';
                    end
                end
                Screen('DrawTextures', this.offWindowPtr, this.boxTexture, [], positions', 0, 1, 1, colors');
            end
        end
        
        function [left,top] = getBlockPos(this,x,y)
            left = this.fieldSize.left + (x-1)*this.boxSize;
            top  = this.fieldSize.top  + (y-1)*this.boxSize;
        end
        
        function [left,top] = getBlockPreviewPos(this,x,y)
            left = this.fieldSize.right + (x-3)*this.boxSize;
            top  = this.fieldSize.top  + (y-1)*this.boxSize;
        end
        
        function drawBox(this,left,top,color)
            Screen('DrawTexture', this.offWindowPtr, this.boxTexture, [], [left,top,left+this.boxSize,top+this.boxSize], 0, 1, 1, color);
        end
        
        function result = checkCollision(this,block)
            blockInField = false(this.fieldSize.boxes_y,this.fieldSize.boxes_x);
            blockInField(block.top:block.top+size(block.fields,1)-1,block.left:block.left+size(block.fields,2)-1) = block.fields;
            result = any(any(blockInField&any(this.gameField,3)));
        end
        
        function result = outOfBorder(this,block)
            result = ~(block.left > 0 && block.left+size(block.fields,2)-1 <= this.fieldSize.boxes_x ...
                     && block.top + size(block.fields,1)-1 <= this.fieldSize.boxes_y);
        end
        
        function collision = moveBlock(this,direction)
            newBlock = this.currentBlock;
            collision = false;
            switch(direction)
                case 'right'
                    newBlock.left = newBlock.left+1;
                case 'left'
                    newBlock.left = newBlock.left-1;
                case 'down'
                    newBlock.top = newBlock.top+1;
                case 'rotateRight'
                    newBlock.fields = rot90(newBlock.fields,3);
                    newBlockSize = size(newBlock.fields);
                    if newBlockSize(1)~=newBlockSize(2)
                        sizeDiff = newBlockSize(1)-newBlockSize(2);
                        newBlock.top = max(1,newBlock.top - sizeDiff);
                        if sizeDiff > 2
                            newBlock.left = newBlock.left + 1;
                        elseif sizeDiff < -2
                            newBlock.left = newBlock.left - 1;
                        end
                    end
                case 'rotateLeft'
                    newBlock.fields = rot90(newBlock.fields,1);
                    newBlockSize = size(newBlock.fields);
                    if newBlockSize(1)~=newBlockSize(2)
                        sizeDiff = newBlockSize(1)-newBlockSize(2);
                        newBlock.top = max(1,newBlock.top - sizeDiff);
                        if sizeDiff > 2
                            newBlock.left = newBlock.left + 1;
                        elseif sizeDiff < -2
                            newBlock.left = newBlock.left - 1;
                        end
                    end
            end
            
            newBlock.left = max(1,newBlock.left);
            if newBlock.left+size(newBlock.fields,2) > this.fieldSize.boxes_x
                newBlock.left = this.fieldSize.boxes_x-size(newBlock.fields,2)+1;
            end
            
            if ~this.outOfBorder(newBlock) && ~this.checkCollision(newBlock)
                
                this.currentBlock.color = this.TRANS;
                this.drawBlock(this.currentBlock,false);
                this.currentBlock = newBlock;
                this.drawBlock(this.currentBlock,false);
            else
                collision = true;
            end
        end
    end
    
end

