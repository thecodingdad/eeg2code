classdef stimulation_optimal < stimulation
%STIMULATION_PREDEFINED - stimulation using predefined sequences
    
    properties
        randstream; %the random stream
        sequences;  %sequence pool
        weights;    %sequence weigths and occurances
        targetseq;  %sequences assigned to targets
    end
    
    methods
        function this = stimulation_optimal(numTargets,varargin)
        %STIMULATION_PREDEFINED - stimulation using predefined sequences
        %   STIMULATION_PREDIFINED(numTargets,csvfile,seed)
        %       CSVFILE - csv file with sequences
        %       SEED - random seed used to randomly assign sequences to targets
            this@stimulation(numTargets,varargin{:});
            p = inputParser;
            p.StructExpand = true;
            p.KeepUnmatched = true;
            addParameter(p,'sequencePool','random_seq_pool.csv',@(x) ischar(x) && exist(x, 'file') == 2);
            addParameter(p,'sequenceWeights','random_seq_weights.csv',@(x) ischar(x) && exist(x, 'file') == 2);
            addParameter(p,'randomseed',1,@(x) helper.isint(x) && length(x) == 1);
            parse(p,varargin{:});
            
            this.randstream = RandStream('mt19937ar','Seed',p.Results.randomseed);
            this.sequences = csvread(p.Results.sequencePool)';
            this.weights = csvread(p.Results.sequenceWeights)';
        end
        
        function setTargetSequences(this)
        %SETTARGETSEQUENCES - assign random sequence of the sequence pool to each target
            if size(this.sequences,2) > this.numTargets
                % get random subset if pool has more sequences as targets
%                 tmp_weights = this.weights(:,1)./size(this.weights,1);
                tmp_weights = this.weights(:,1);
                subset = zeros(1, this.numTargets);
%                 subset = randsample( size(this.sequences,2), this.numTargets, false, this.weights(1,:)./size(this.weights,2));
                for i = 1:this.numTargets
                    subnet_new_idx = randsample(this.randstream, size(this.sequences,2), 1, true, tmp_weights);
                    tmp_weights(subnet_new_idx) = 0;
                    subset(i) = subnet_new_idx;
                end
                
            elseif size(this.sequences,2) == this.numTargets
                % if number of sequences equals number of targets
                subset = 1:this.numTargets;
            else
                error('setTargetSequences: too few sequences in sequence pool');
            end
            this.weights(subset,2) = this.weights(subset, 2) + 1;
            this.targetseq = this.sequences(:,subset);
        end
        
        function updateWeights(this, bitAcc)
        %UPDATEWEIGHTS - update weights using newest bit prediction
        %accuracy
            this.weights(:, 1) = this.weights(:, 1) .* bitAcc;
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

