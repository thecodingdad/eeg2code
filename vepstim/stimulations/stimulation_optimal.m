classdef stimulation_optimal < stimulation
%STIMULATION_PREDEFINED - stimulation using predefined sequences
    
    properties
        randstream; %the random stream
        sequences;  %sequence pool
        weights;    %sequence weigths and occurances
        targetseq;  %sequences assigned to targets
        subset;     %sub sequences that points to sequences
        bit_acc_tar %bit accuracy and target
        weights_bit_acc;
        max_bitAcc;
        min_bitAcc;
        mean_bitAcc;
        trials;
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
            addParameter(p,'sequencePool','random_seq_pool.csv',...
                @(x) ischar(x) && exist(x, 'file') == 2);
            addParameter(p,'sequenceWeights','random_seq_weights.csv',...
                @(x) ischar(x) && exist(x, 'file') == 2);
            addParameter(p,'randomseed',1,@(x) helper.isint(x) && length(x) == 1);
            parse(p,varargin{:});
            
            this.randstream = RandStream('mt19937ar','Seed',p.Results.randomseed);
            this.sequences = csvread(p.Results.sequencePool)';
            this.weights = csvread(p.Results.sequenceWeights)';
            this.mean_bitAcc = 0;
            this.max_bitAcc = 0;
            this.min_bitAcc = 1;
            this.trials = varargin{1}.trials;
            this.weights_bit_acc = cell(size(this.sequences,2), 1);
            
        end
        
        function setTargetSequences(this)
        %SETTARGETSEQUENCES - assign random sequence of the sequence pool to each target
            if size(this.sequences,2) > this.numTargets
                % get random subset if pool has more sequences as targets
                
                tmp_weights = this.weights(:,1);
                this.subset = zeros(1, this.numTargets);
                
                for i = 1:this.numTargets
%                     subnet_new_idx = randsample(this.randstream, size(this.sequences,2), 1, true, tmp_weights);
                    
                    subnet_new_idx = randsample(size(this.sequences,2), 1, true, tmp_weights);
                    
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
            
            idx = this.subset(realTarget);
            prev_weight = this.weights(idx, 1);
            
            this.approach_4_7(bitAcc, realTarget);
            
            if size(this.bit_acc_tar) == 0
                this.bit_acc_tar = [];
                this.bit_acc_tar = cat(1, this.bit_acc_tar, [bitAcc idx prev_weight this.weights(idx, 1)]);
            else
                this.bit_acc_tar = cat(1, this.bit_acc_tar, [bitAcc idx prev_weight this.weights(idx, 1)]);
            end
            this.mean_bitAcc = mean(this.bit_acc_tar(:,1));                        
        end
        function save(this, run, dir)
%             run = string(1);    
            if ~exist(dir, 'dir')
               mkdir(dir)
            end
            csvwrite(strcat(dir,'/r_',run,'_tr_',string(this.trials),...
                '_bit_acc_weight.csv'), this.bit_acc_tar);
            csvwrite(strcat(dir,'/r_',run,'_tr_',string(this.trials),...
                '_new_weights.csv'), transpose(this.weights));
            this.weights_bit_acc;
            
%             T = cell2table(this.weights_bit_acc);
%             writetable(T,strcat(dir,'/r_',run,'_tr_',string(this.trials),...
%                 '_weights_bit_acc.csv'));
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
        
        function approach_1(this, bitAcc, realTarget)
            % softmax is not allowing rapid change            
            step_size = 1;
                  
            max_weights = max(this.weights(:, 1));
            min_weights = min(this.weights(:, 1));
            
            rescaled_bitAcc = bitAcc * (max_weights - min_weights) + min_weights;

            idx = this.subset(realTarget);
            this.weights(idx, 1) = this.weights(idx, 1) + rescaled_bitAcc * step_size;
            this.weights(:, 1) = softmax(this.weights(:, 1));
        end   
        function approach_2(this, bitAcc, realTarget)
            % removed softmax            
            % some weights are never used
            
            step_size = 1;       

            max_weights = 1/size(this.weights(:, 1), 1);
            min_weights = 0;
            
            rescaled_bitAcc = bitAcc * (max_weights - min_weights) + min_weights;

            idx = this.subset(realTarget);
            this.weights(idx, 1) = this.weights(idx, 1) + rescaled_bitAcc * step_size; 
        end
        function approach_3_1(this, bitAcc, realTarget)
            % make a range where the maximum weight cannot be more than the
            % minimum with certain percentage
            % increas minimum values with same step size as updated weight            
            % increased minimum value weights when there is wide range            
            % still some values are not chagned
            step_size = 1;       
                
            rescaling_value = 1/size(this.weights(:, 1), 1);
            min_weight = min(this.weights(:, 1)); 
            
            rescaled_bitAcc = bitAcc * rescaling_value;

            idx = this.subset(realTarget);
            this.weights(idx, 1) = this.weights(idx, 1) + rescaled_bitAcc * step_size; 
            if min_weight/this.weights(idx, 1) < 0.3
                indeces = find(this.weights(:,1) == min_weight);
                this.weights(indeces,1) = this.weights(indeces,1) + rescaled_bitAcc * step_size;
            end         
        end
        function approach_3_2(this, bitAcc, realTarget)
            % make a range where the maximum weight cannot be more than the
            % minimum with certain percentage
            % update all weights below certain percentage
            % still some weights are left unused
            step_size = 1;       
                
            rescaling_value = 1/size(this.weights(:, 1), 1);
            min_weight = min(this.weights(:, 1)); 
            
            rescaled_bitAcc = bitAcc * rescaling_value;

            idx = this.subset(realTarget);
            this.weights(idx, 1) = this.weights(idx, 1) + rescaled_bitAcc * step_size; 
            if min_weight/this.weights(idx, 1) < 0.4
                indeces = this.weights(:, 1)/this.weights(idx, 1) < 0.4;
                this.weights(indeces,1) = this.weights(indeces,1) + rescaled_bitAcc * step_size;
            end
        end
        function approach_4_1(this, bitAcc, realTarget, trialNum, currentTrial)
            % logarithmic increase of weights to allow the first trials to
            % choose weights freely then change it later
            % weight change is less dependent on bitAcc
            step_size = 1;       
            
            log_scale = 1-1/log10(trialNum)*log10(currentTrial);
            
            rescaling_value = 1/size(this.weights(:, 1), 1);
            
            rescaled_bitAcc = bitAcc * rescaling_value * log_scale;

            idx = this.subset(realTarget);
            this.weights(idx, 1) = this.weights(idx, 1) + rescaled_bitAcc * step_size; 
        end
        function approach_4_2(this, bitAcc, realTarget, trialNum, currentTrial)
            % logarithmic increase plus change bitAcc from 0 to 1 with
            % max_bitAcc = 1 and min_bitAcc = 0.9            
            step_size = 1;       
            
            log_scale = 1-1/log10(trialNum)*log10(currentTrial);
            
            rescaling_value = 1/size(this.weights(:, 1), 1);
            
            maximum_bitAcc = 1;
            minimum_bitAcc = 0.9;
            
            rescaled_bitAcc = (bitAcc - minimum_bitAcc)/...
                (maximum_bitAcc-minimum_bitAcc) * rescaling_value * log_scale;

            idx = this.subset(realTarget);
            this.weights(idx, 1) = this.weights(idx, 1) + rescaled_bitAcc * step_size; 

        end
        function approach_4_3(this, bitAcc, realTarget)
            % without logarithmic increase, change bitAcc from 0 to 1 with
            % max_bitAcc = 1 and min_bitAcc = 0.9
            
            step_size = 1;       
                        
            rescaling_value = 1/size(this.weights(:, 1), 1);
            
            maximum_bitAcc = 1;
            minimum_bitAcc = 0.9;
            
            rescaled_bitAcc = (bitAcc - minimum_bitAcc)/...
                (maximum_bitAcc-minimum_bitAcc) * rescaling_value;

            idx = this.subset(realTarget);
            this.weights(idx, 1) = this.weights(idx, 1) + rescaled_bitAcc * step_size; 
        end
        function approach_4_4(this, bitAcc, realTarget)
            % Automatized logarithmic increase and max min bitAcc
            % But the graph shows too much flickering            
            idx = this.subset(realTarget);
            
            currentTrial = sum(this.weights(:, 2));
            
            trialNum = 1000;
            step_size = 1;           
            log_scale = 1-1/log10(trialNum)*log10(1000-currentTrial+1);
            
            if bitAcc > this.max_bitAcc
                this.max_bitAcc = bitAcc;
            end
            if bitAcc < this.min_bitAcc
                this.min_bitAcc = bitAcc;
            end
            
            rescaling_value = 1/size(this.weights(:, 1), 1);
            
            if bitAcc ~= this.min_bitAcc
                rescaled_bitAcc = (bitAcc - this.min_bitAcc)/...
                    (this.max_bitAcc-this.min_bitAcc) * rescaling_value * log_scale;
            else
                rescaled_bitAcc = bitAcc * rescaling_value * log_scale;
            end
            this.weights(idx, 1) = this.weights(idx, 1) + rescaled_bitAcc * step_size; 
        end
        function approach_4_5(this, bitAcc, realTarget)
            % algebric scale with rejection of mean 
            % 
            idx = this.subset(realTarget);
            
            currentTrial = sum(this.weights(:, 2));
            step_size = 0.5;           
            algebric_scale = currentTrial;
            algebric_scale = (algebric_scale - 1)./(1.5 * this.trials - 1).*(0 + 6) - 6;
            algebric_scale = 1 + algebric_scale / sqrt((1+algebric_scale^2));
            
            if bitAcc > this.max_bitAcc
                this.max_bitAcc = bitAcc;
            end
            if bitAcc < this.min_bitAcc
                this.min_bitAcc = bitAcc;
            end
            
            rescaling_value = 1/size(this.weights(:, 1), 1);
            
            if bitAcc ~= this.min_bitAcc
                rescaled_bitAcc = (bitAcc - this.min_bitAcc)/...
                    (this.max_bitAcc-this.min_bitAcc) * rescaling_value * algebric_scale;
            else
                rescaled_bitAcc = bitAcc * rescaling_value * algebric_scale;
            end
            if bitAcc > this.mean_bitAcc
                this.weights(idx, 1) = this.weights(idx, 1) + rescaled_bitAcc;
            else
                this.weights(idx, 1) = this.weights(idx, 1) + rescaled_bitAcc * step_size;                
            end
            
            if (this.weights(idx, 1) < 0) || isnan(this.weights(idx, 1))            
                disp('tuuchii');    
            end
        end
        function approach_4_6(this, bitAcc, realTarget)
            % chain bit accuracy weight update
            % with median threshold
            idx = this.subset(realTarget);
            this.weights_bit_acc{idx} = [this.weights_bit_acc{idx} bitAcc];
            
            currentTrial = sum(this.weights(:, 2));
            step_size = 0;
            algebric_scale = currentTrial;
            algebric_scale = (algebric_scale - 1)./(1.5 * this.trials - 1).*(0 + 6) - 6;
            algebric_scale = 1 + algebric_scale / sqrt((1+algebric_scale^2));
            
            if bitAcc > this.max_bitAcc
                this.max_bitAcc = bitAcc;
            end
            if bitAcc < this.min_bitAcc
                this.min_bitAcc = bitAcc;
            end
                        
            rescaling_value = 1/size(this.weights(:, 1), 1);
                        
            if bitAcc ~= this.min_bitAcc
                rescaled_bitAcc = (bitAcc - this.min_bitAcc)/...
                    (this.max_bitAcc-this.min_bitAcc) * rescaling_value * algebric_scale;
            else
                rescaled_bitAcc = bitAcc * rescaling_value * algebric_scale;
            end
            
            bit_acc_median = median(this.weights_bit_acc{idx});
            
            if bit_acc_median > this.mean_bitAcc
                this.weights(idx, 1) = this.weights(idx, 1) + rescaled_bitAcc;
            else
                this.weights(idx, 1) = this.weights(idx, 1) + rescaled_bitAcc * step_size;                
            end
            
            if (this.weights(idx, 1) < 0) || isnan(this.weights(idx, 1))
                disp('tuuchii');
            end
        end
        function approach_4_7(this, bitAcc, realTarget)
            % chain bit accuracy weight update
            % with mean threshodld
            idx = this.subset(realTarget);
            this.weights_bit_acc{idx} = [this.weights_bit_acc{idx} bitAcc];
            
            currentTrial = sum(this.weights(:, 2));
            step_size = 0.5;
            algebric_scale = currentTrial;
            algebric_scale = (algebric_scale - 1)./(1.5 * this.trials - 1).*(0 + 6) - 6;
            algebric_scale = 1 + algebric_scale / sqrt((1+algebric_scale^2));
            
            if bitAcc > this.max_bitAcc
                this.max_bitAcc = bitAcc;
            end
            if bitAcc < this.min_bitAcc
                this.min_bitAcc = bitAcc;
            end
                        
            rescaling_value = 1/size(this.weights(:, 1), 1);
                        
            if bitAcc ~= this.min_bitAcc
                rescaled_bitAcc = (bitAcc - this.min_bitAcc)/...
                    (this.max_bitAcc-this.min_bitAcc) * rescaling_value * algebric_scale;
            else
                rescaled_bitAcc = bitAcc * rescaling_value * algebric_scale;
            end
            
            bit_acc_mean = mean(this.weights_bit_acc{idx});
            
            if bit_acc_mean > this.mean_bitAcc
                this.weights(idx, 1) = this.weights(idx, 1) + rescaled_bitAcc;
            else
                this.weights(idx, 1) = this.weights(idx, 1) + rescaled_bitAcc * step_size;                
            end
            
            if (this.weights(idx, 1) < 0) || isnan(this.weights(idx, 1))
                disp('tuuchii');
            end
        end
    end
    
end

