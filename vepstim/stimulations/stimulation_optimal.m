classdef stimulation_optimal < stimulation
%STIMULATION_PREDEFINED - stimulation using predefined sequences
    
    properties
        randstream; %the random stream
        sequences;  %sequence pool
        weights;    %sequence weigths and occurances
        targetseq;  %sequences assigned to targets
        subset;     %sub sequences that points to sequences
        bit_acc_tar %bit accuracy and target
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
                this.subset = zeros(1, this.numTargets);
%                 subset = randsample( size(this.sequences,2), this.numTargets, false, this.weights(1,:)./size(this.weights,2));
                for i = 1:this.numTargets
                    subnet_new_idx = randsample(this.randstream, size(this.sequences,2), 1, true, tmp_weights);
                    tmp_weights(subnet_new_idx) = 0;
                    this.subset(i) = subnet_new_idx;
                end
                
            elseif size(this.sequences,2) == this.numTargets
                % if number of sequences equals number of targets
                this.subset = 1:this.numTargets;
            else
                error('setTargetSequences: too few sequences in sequence pool');
            end
            this.weights(this.subset,2) = this.weights(this.subset, 2) + 1;
            this.targetseq = this.sequences(:,this.subset);
        end
        
        function updateWeights(this, bitAcc, realTarget)
        %UPDATEWEIGHTS - update weights using newest bit prediction
        %accuracy
%             step_size = 1;
%             
%             max_bitAcc = 1;
%             min_bitAcc = 0;            
%             
%             max_weights = max(this.weights(:, 1));
%             min_weights = min(this.weights(:, 1));
            
%             % approach 1
%             rescaled_bitAcc = (bitAcc - min_bitAcc)/(max_bitAcc - min_bitAcc) ...
%                 * (max_weights - min_weights) + min_weights;
% 
%             idx = this.subset(realTarget);
%             this.weights(idx, 1) = this.weights(idx, 1) + rescaled_bitAcc * step_size;

            
            % approach 2
            
            step_size = 1;       
            

            max_weights = 1/size(this.weights(:, 1), 1);
            min_weights = 0;
            
            rescaled_bitAcc = bitAcc * (max_weights - min_weights) + min_weights;

            idx = this.subset(realTarget);
            this.weights(idx, 1) = this.weights(idx, 1) + rescaled_bitAcc * step_size;           
            
%             this.weights = softmax(this.weights);
            
            if size(this.bit_acc_tar) == 0
                this.bit_acc_tar = [];
                this.bit_acc_tar = cat(1, this.bit_acc_tar, [bitAcc idx this.weights(idx, 1)]);
            else
                this.bit_acc_tar = cat(1, this.bit_acc_tar, [bitAcc idx this.weights(idx, 1)]);
            end
        end
        function save(this)
            run = string(10);
            csvwrite(strcat('./weight_update_data/approach_2/r_',run,'_tr_',run,'00_bit_acc_weigt.csv'), this.bit_acc_tar);
            csvwrite(strcat('./weight_update_data/approach_2/r_',run,'_tr_',run,'00_new_weights.csv'), transpose(this.weights));
        end
        function bits = next(this,lostBits)
        %NEXT - returns the next bits of the sequence pool for each target
            %call super method
            next@stimulation(this,lostBits);
            bits = this.targetseq(mod(this.stimPos-1,size(this.sequences,1))+1,:);
        end
        function startTrial(this)
        %ENDTRIAL - defines that a trial has started
            startTrial@stimulation(this);
            this.setTargetSequences();
        end
    end
    
end

