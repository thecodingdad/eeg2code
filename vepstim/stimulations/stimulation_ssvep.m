classdef stimulation_ssvep < stimulation
%STIMULATION_SSVEP - SSVEP stimulation
%   frequency  - stimulation frequency of each single target
%                (default: 1 Hz for each target)
%   phaseshift - phase-shift of each target, 0 means stimulation starts
%                with full illumination. Full phase is 2pi.
%                (default: 0 for each target)
%   binary     - binary stimulation if true, else sinusoidal stimulation
%                (default: false)
    
    properties
        frequency;      %stimulation frequency of each target
        phaseshift;     %phaseshift of each target
        onproportion;   %relative time of onstimulus ]0,1[, not yet implemented
        binary;         %binary stimulation
    end
    
    methods
        function this = stimulation_ssvep(numTargets,varargin)
            this@stimulation(numTargets,varargin{:});
            
            p = inputParser;
            p.StructExpand = true;
            p.KeepUnmatched = true;
            addParameter(p,'frequency',1,@(x) isnumeric(x) && (length(x) == 1 || length(x) == this.numTargets) && all(x <= this.monitorRefreshRate/2));
            addParameter(p,'phaseshift',0,@(x) isnumeric(x) && (length(x) == 1 || length(x) == this.numTargets));
            addParameter(p,'onproportion',0.5,@(x) isnumeric(x) && x>0 && x<1); 
            addParameter(p,'binary',false,@islogical);
            parse(p,varargin{:});
            
            this.frequency = p.Results.frequency;
            this.phaseshift = p.Results.phaseshift;
            this.onproportion = p.Results.onproportion;
            this.binary = p.Results.binary;
            
            % check for correct dimensions
            if length(this.frequency) == 1
                this.frequency = repmat(this.frequency,1,this.numTargets); 
            end
            if size(this.frequency,2) == 1
                this.frequency = this.frequency';
            end
            if length(this.phaseshift) == 1
                this.phaseshift = repmat(this.phaseshift,1,this.numTargets); 
            end
            if size(this.phaseshift,2) == 1
                this.phaseshift = this.phaseshift';
            end
        end
        
        function stimuli = next(this,lostBits)
        %NEXT - returns fully random bits for each target
            %call super method
            next@stimulation(this,lostBits);
            % calculate next SSVEP stimulus for each target, dependent on the monitor
            % refresh rate, the phase shift, and frames per stimulus
            angle = mod((((this.stimPos*this.framesPerStimulus)-1)/(this.monitorRefreshRate)*2*pi)*this.frequency+this.phaseshift,2*pi);
            stimuli = (cos(angle)+1)/2;
            if this.binary, stimuli = round(stimuli); end
        end
    end
    
end

