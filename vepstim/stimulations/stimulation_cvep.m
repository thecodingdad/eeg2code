classdef stimulation_cvep < stimulation
%STIMULATION_CVEP - cVEP stimulation with an m-sequence
    
    properties
        mseq;       %the used m-sequence
        targetseq;  %store shifted m-sequence for each target
    end
    
    methods
        function this = stimulation_cvep(numTargets,varargin)
        %STIMULATION_CVEP - cVEP stimulation with an m-sequence
        %   STIMULATION_CVEP(numTargets,shift,mseqParams) - shift the sequence by SHIFT bits for each successive target
            this@stimulation(numTargets,varargin{:});
            p = inputParser;
            p.StructExpand = true;
            p.KeepUnmatched = true;
            addParameter(p,'mseqParams',[2,6,1,1],@(x) helper.isint(x) && length(x) == 4);
            addParameter(p,'mseqShift',2,@(x) helper.isint(x) && length(x) == 1);
            parse(p,varargin{:});
            
            this.initMseq(p.Results.mseqShift,p.Results.mseqParams);
        end
        
        function initMseq(this,shift,mseqParams)
        %INITMSEQ - initialize the m-sequence to use
        %   INITMSEQ(shift) - shift the sequence by SHIFT bits for each successive target
            this.mseq = mseq(mseqParams(1),mseqParams(2),mseqParams(3),mseqParams(4)) == 1;
            this.targetseq = zeros(length(this.mseq),this.numTargets);
            for target = 1:this.numTargets
                this.targetseq(:,target) = circshift(this.mseq,-(target-1)*shift,1)';
            end
        end
        
        function bits = next(this,lostBits)
        %NEXT - returns the next bits of the m-sequence for each target
            %call super method
            next@stimulation(this,lostBits);
            bits = this.targetseq(mod(this.stimPos-1,length(this.mseq))+1,:);
        end
        
        function res = isSequenceStart(this)
        %ISSEQUENCESTART - defines the start of the m-sequence
            res = mod(this.stimPos-1,length(this.mseq))+1 == 1;
        end
    end
    
end

