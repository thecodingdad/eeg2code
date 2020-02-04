classdef stimulation < handle
%STIMULATION - Abstract class used to define new stimulation types
    
    properties
        numTargets;         %number of targets
        numBits;            %number of presented bits
        trialPos;           %bit position of the current trial
        stimPos;
        isTrial;            %flag that defines if it is a trial or inter-trial
        numTrials;          %counts the number of completed trials
        lostBits;
        fixFrameDrops;
        monitorRefreshRate;
        framesPerStimulus;
        interTrialStimuli;
        syncAtTrialStart;
    end
    
    methods
        function this = stimulation(numTargets,varargin)
        %STIMULATION - create stimulation dependent on the number of targets
            p = inputParser;
            p.StructExpand = true;
            p.KeepUnmatched = true;
            addRequired(p,'numTargets',@(x) helper.isint(x) && length(x) == 1);
            addParameter(p,'monitorRefreshRate',60,@(x) helper.isint(x) && length(x) == 1);
            addParameter(p,'framesPerStimulus',1,@(x) helper.isint(x) && length(x) == 1);
            addParameter(p,'interTrialStimuli',false,@islogical);
            addParameter(p,'fixFrameDrops',true,@islogical);
            addParameter(p,'syncAtTrialStart',true,@islogical);
            parse(p,numTargets,varargin{:});
            this.numTargets = p.Results.numTargets;
            this.monitorRefreshRate = p.Results.monitorRefreshRate;
            this.framesPerStimulus = p.Results.framesPerStimulus;
            this.interTrialStimuli = p.Results.interTrialStimuli;
            this.fixFrameDrops = p.Results.fixFrameDrops;
            this.syncAtTrialStart = p.Results.syncAtTrialStart;
            
            this.trialPos = 0;
            this.numBits = 0;
            this.isTrial = false;
            this.numTrials = 0;
            this.lostBits = 0;
        end
        
        function next(this,lostBits)
        %NEXT - count sequence position and return next bits for each target
        %   NEXT(lostBits) - is called with the number of lost bits due to frame drops
            this.numBits = this.numBits + 1 ;
            this.trialPos = this.trialPos + 1;
            this.lostBits = this.lostBits + lostBits;
            if lostBits > 0 && this.trialPos~=1 && this.fixFrameDrops
                this.trialPos = this.trialPos + lostBits;
                this.numBits = this.numBits + lostBits;
            end
            if this.syncAtTrialStart
                this.stimPos = this.trialPos;
            else
                this.stimPos = this.numBits;
            end
        end
        
        function startTrial(this)
        %NEWTRIAL - defines that a new trial has started
            this.trialPos = 0;
            this.numTrials = this.numTrials + 1;
            this.isTrial = true;
        end
        
        function endTrial(this)
        %ENDTRIAL - defines that a trial has ended
            this.isTrial = false;
        end
        
        function res = isSequenceStart(this)
        %ISSEQUENCESTART - flag that defines the start of a sequence, is set as bit to parallel port
            res = false;
        end
    end
    
end

