classdef stimulation_predefined < stimulation
%STIMULATION_PREDEFINED - stimulation using predefined sequences
    
    properties
        randstream; %the random stream
        sequences;  %sequence pool
        targetseq;  %sequences assigned to targets
    end
    
    methods
        function this = stimulation_predefined(numTargets,varargin)
        %STIMULATION_PREDEFINED - stimulation using predefined sequences
        %   STIMULATION_PREDIFINED(numTargets,csvfile,seed)
        %       CSVFILE - csv file with sequences
        %       SEED - random seed used to randomly assign sequences to targets
            this@stimulation(numTargets,varargin{:});
            p = inputParser;
            p.StructExpand = true;
            p.KeepUnmatched = true;
            addParameter(p,'sequencePool','sequencepool.csv',@(x) ischar(x) && exist(x, 'file') == 2);
            addParameter(p,'randomseed',1,@(x) helper.isint(x) && length(x) == 1);
            parse(p,varargin{:});
            
            this.randstream = RandStream('mt19937ar','Seed',p.Results.randomseed);
            this.sequences = csvread(p.Results.sequencePool)';
        end
        
        function setTargetSequences(this)
        %SETTARGETSEQUENCES - assign random sequence of the sequence pool to each target
            if size(this.sequences,2) > this.numTargets
                % get random subset if pool has more sequences as targets
                subset = this.randstream.randperm(size(this.sequences,2),this.numTargets);
            elseif size(this.sequences,2) == this.numTargets
                % if number of sequences equals number of targets
                subset = 1:this.numTargets;
            else
                error('setTargetSequences: too few sequences in sequence pool');
            end
            this.targetseq = this.sequences(:,subset);
        end
        
        function bits = next(this,lostBits)
        %NEXT - returns the next bits of the sequence pool for each target
            %call super method
            next@stimulation(this,lostBits);
            if mod(this.stimPos-1,size(this.sequences,1))+1 == 1, this.setTargetSequences(); end
            bits = this.targetseq(mod(this.stimPos-1,size(this.sequences,1))+1,:);
        end
    end
    
end

