classdef stimulation_random < stimulation
%STIMULATION_RANDOM - assign fully random bits to each target
    
    properties
        randstream; %the random stream
    end
    
    methods
        function this = stimulation_random(numTargets,varargin)
        %STIMULATION_RANDOM - fully random stimulation
        %   STIMULATION_RANDOM(numTargets,seed) - the random SEED used for  bit generation
            this@stimulation(numTargets,varargin{:});
            
            p = inputParser;
            p.StructExpand = true;
            p.KeepUnmatched = true;
            addParameter(p,'randomseed',1,@(x) helper.isint(x) && length(x) == 1);
            parse(p,varargin{:});
            
            this.randstream = RandStream('mt19937ar','Seed',p.Results.randomseed);
        end
        
        function bits = next(this,lostBits)
        %NEXT - returns fully random bits for each target
            %call super method
            next@stimulation(this,lostBits);
            bits = this.randstream.randi(2,1,this.numTargets)-1;
        end
    end
    
end

