classdef helper
    
    methods(Static)
        function res = isint(x)
        %ISINT - checks if any numeric number is an integer
            res = isnumeric(x) && all(round(x) == x);
        end
        
        function paramCell = structToCell(paramStruct)
        %STRUCTTOCELL - converts a struct to a cell of keys and values
            keys = fieldnames(paramStruct);
            paramCell = cell(1,length(keys)*2);
            for ii=1:length(keys)
                paramCell{ii*2-1} = keys{ii};
                paramCell{ii*2} = paramStruct.(keys{ii});
            end
        end
        
        function paramString = paramsToString(isStructField,varargin)
        %PARAMSTOSTRING - converts all given parameter to its string representation
            paramString = '';
            for ii=1:length(varargin)
                if iscell(varargin{ii})
                    cellString = '';
                    for jj=1:length(varargin{ii})
                        cellString = [cellString helper.paramsToString(false,varargin{ii}{jj})];
                        if jj ~= length(varargin{ii}), cellString = [cellString ',']; end
                    end
                    % required to create one dimensional struct
                    if isStructField, cellString = ['{' cellString '}']; end
                    paramString = [paramString '{' cellString '}'];
                elseif ischar(varargin{ii})
                    paramString = [paramString '''' varargin{ii} ''''];
                elseif isnumeric(varargin{ii}) || islogical(varargin{ii})
                    paramString = [paramString mat2str(varargin{ii})];
                elseif isstruct(varargin{ii})
                    structParams = helper.structToCell(varargin{ii});
                    paramString = [paramString 'struct(' helper.paramsToString(true,structParams{:}) ')'];
                else
                    error('paramsToString: parametertype %s not supported',class(varargin{ii}));
                end
                if ii ~= length(varargin), paramString = [paramString ',']; end
            end
        end
        
        function [bciSettings,vepSettings] = parseBCIParams(bci_Parameters)
        %PARSEBCIPARAMS - parses bci_Parameters and returns a struct used
        %   for bci2000 and a struct used for vep_experiment/vep_operator
            % bci2000settings
            bciSettings = struct();
            bciSettings.real_eegchannels = cellfun(@str2num, bci_Parameters.TransmitChList)'; %used eeg channels
            bciSettings.trialsToStore = 96;
            bciSettings.samplingRate = str2double(regexp(bci_Parameters.SamplingRate{1},'\d*','match'));
            bciSettings.samplesPerFrame = round(bciSettings.samplingRate / str2double(bci_Parameters.monitorRefreshRate{1}));
            bciSettings.samplesPerBit = bciSettings.samplesPerFrame * str2double(bci_Parameters.framesPerStimulus{1});
            bciSettings.samplesPerTrial = str2double(bci_Parameters.trialTime{1})*bciSettings.samplingRate;
            bciSettings.samplesPerTrial = ceil(bciSettings.samplesPerTrial/bciSettings.samplesPerBit)*bciSettings.samplesPerBit;
            bciSettings.timelag = round(str2double(bci_Parameters.timelag{1})/1000*bciSettings.samplingRate);
            bciSettings.numSamples2skip = ceil(bciSettings.timelag/bciSettings.samplesPerBit)*bciSettings.samplesPerBit;
            %bciSettings.samplesPerPause = str2double(bci_Parameters.interTrialTime{1})*bciSettings.samplingRate;
            %bciSettings.samplesPerPause = ceil(bciSettings.samplesPerPause/bciSettings.samplesPerBit)*bciSettings.samplesPerBit;
            bciSettings.afterTrialSamples = str2double(bci_Parameters.afterTrialTime{1})/1000*bciSettings.samplingRate;
            bciSettings.afterTrialSamples = ceil(bciSettings.afterTrialSamples/bciSettings.samplesPerBit)*bciSettings.samplesPerBit;
            bciSettings.samplesPerBlock = str2double(bci_Parameters.SampleBlockSize{1});
            bciSettings.subjectPath = [bci_Parameters.DataDirectory{1} '\' bci_Parameters.SubjectName{1} bci_Parameters.SubjectSession{1} '\'];
            bciSettings.currentFilename = [bci_Parameters.SubjectName{1} 'S' bci_Parameters.SubjectSession{1} 'R' bci_Parameters.SubjectRun{1}];
            bciSettings.mintriallength = str2double(bci_Parameters.minTrialTime{1});
            bciSettings.minSamplesPerTrial = str2double(bci_Parameters.minTrialTime{1})*bciSettings.samplingRate;
            bciSettings.minSamplesPerTrial = ceil(bciSettings.minSamplesPerTrial/bciSettings.samplesPerBit)*bciSettings.samplesPerBit;
            bciSettings.stopthreshold = str2double(bci_Parameters.stopthreshold{1});
            bciSettings.pValueThreshold = str2double(bci_Parameters.pValueThreshold{1});
            bciSettings.asynchronous = logical(str2double(bci_Parameters.asynchronous{1}));
            switch str2double(bci_Parameters.classificationMode{1})
                case 1, bciSettings.classificationMode = 'target';
                case 2, bciSettings.classificationMode = 'bitacc';
            end
            switch str2double(bci_Parameters.targetSelection{1})
                case 1, bciSettings.targetSelection = 'hamming';
                case 2, bciSettings.targetSelection = 'euclidean';
                case 3, bciSettings.targetSelection = 'correlation';
            end
            switch (str2double(bci_Parameters.trainmode{1}))
                case 1
                    bciSettings.afterTrialSamples = 0;
                case 2
                    bciSettings.samplesPerTrial = bciSettings.samplesPerTrial + bciSettings.afterTrialSamples;
                case 3
                    bciSettings.samplesPerTrial = bciSettings.samplesPerTrial + bciSettings.afterTrialSamples;
            end
            bciSettings.debug = logical(str2double(bci_Parameters.debug{1}));
            bciSettings.numTrials = length(str2num(bci_Parameters.trials{1}));
            
            %vep settings
            vepSettings = struct();
            vepSettings.monitorResolution = str2num(bci_Parameters.monitorResolution{1});
            vepSettings.monitorRefreshRate = str2num(bci_Parameters.monitorRefreshRate{1});
            vepSettings.windowSize = str2num(bci_Parameters.windowSize{1});
            if isempty(vepSettings.windowSize)
                vepSettings.windowSize = 'fullscreen';
            end
            vepSettings.hideCursor = logical(str2double(bci_Parameters.hideCursor{1}));
            
            vepSettings.layout = str2double(bci_Parameters.layout{1});
            vepSettings.layoutSettings = struct();
            vepSettings.layoutSettings.stimulusColor = helper.hex2rgba(bci_Parameters.stimulusColor{1});
            vepSettings.layoutSettings.highlightColor = helper.hex2rgba(bci_Parameters.highlightColor{1});
            vepSettings.layoutSettings.targetColor = helper.hex2rgba(bci_Parameters.targetColor{1});
            vepSettings.layoutSettings.infoColor = helper.hex2rgba(bci_Parameters.infoColor{1});
            vepSettings.layoutSettings.target_names = eval(bci_Parameters.target_names{1});
            vepSettings.layoutSettings.boxes_x = str2double(bci_Parameters.boxes_x{1});
            vepSettings.layoutSettings.boxes_y = str2double(bci_Parameters.boxes_y{1});
            
            vepSettings.stimulation = str2double(bci_Parameters.stimulation{1});
            vepSettings.stimSettings = struct();
            vepSettings.stimSettings.mseqParams = str2num(bci_Parameters.mseqParams{1});
            vepSettings.stimSettings.mseqShift = str2double(bci_Parameters.mseqShift{1});
            vepSettings.stimSettings.randomseed = str2double(bci_Parameters.stimSeed{1});
            vepSettings.stimSettings.sequencePool = bci_Parameters.sequencePool{1};
            vepSettings.stimSettings.frequency = str2num(bci_Parameters.ssvepFrequency{1});
            vepSettings.stimSettings.phaseshift = str2num(bci_Parameters.ssvepPhaseShift{1});
            vepSettings.stimSettings.binary = logical(str2double(bci_Parameters.ssvepBinary{1}));
            
            vepSettings.framesPerStimulus = str2double(bci_Parameters.framesPerStimulus{1});
            vepSettings.trials = str2num(bci_Parameters.trials{1});
            vepSettings.freeMode = logical(str2double(bci_Parameters.freeMode{1}));
            vepSettings.startWait = str2double(bci_Parameters.startWait{1});
            vepSettings.trialTime = str2double(bci_Parameters.trialTime{1});
            vepSettings.interTrialTime = str2double(bci_Parameters.interTrialTime{1});
            vepSettings.asynchronous = logical(str2double(bci_Parameters.asynchronous{1}));
            vepSettings.playbackMode = isfield(bci_Parameters,'PlaybackFileName');
        end
        
        function rgba = hex2rgba(hex)
        %HEX2RGBA - converts a HEX color string to a RGBA array
            [rgb,~]=regexp(hex,'[0-9A-F][0-9A-F]','match','split');
            rgba = [hex2dec(rgb)/255;1];
        end
        
        function hex = rgb2hex(rgb)
        %RGB2HEX - converts a RGB color array to a HEX string
            hex = [dec2hex(rgb(1),2),dec2hex(rgb(2),2),dec2hex(rgb(3),2)];
        end
        
        function [rgb] = wavelength2rgb(wavelength)
            gamma=0.8;
            if (wavelength >= 380 && wavelength <= 440) 
                attenuation = 0.3 + 0.7 * (wavelength - 380) / (440 - 380);
                R = ((-(wavelength - 440) / (440 - 380)) * attenuation) ^ gamma;
                G = 0.0;
                B = (1.0 * attenuation) ^ gamma;
            elseif (wavelength >= 440 && wavelength <= 490)
                R = 0.0;
                G = ((wavelength - 440) / (490 - 440)) ^ gamma;
            elseif (wavelength >= 490 && wavelength <= 510)
                R = 0.0;
                G = 1.0;
                B = (-(wavelength - 510) / (510 - 490)) ^ gamma;
            elseif (wavelength >= 510 && wavelength <= 580)
                R = ((wavelength - 510) / (580 - 510)) ^ gamma;
                G = 1.0;
                B = 0.0;
            elseif (wavelength >= 580 && wavelength <= 645)
                R = 1.0;
                G = (-(wavelength - 645) / (645 - 580)) ^ gamma;
                B = 0.0;
            elseif (wavelength >= 645 && wavelength <= 750)
                attenuation = 0.3 + 0.7 * (750 - wavelength) / (750 - 645);
                R = (1.0 * attenuation) ^ gamma;
                G = 0.0;
                B = 0.0;
            else
                R = 0.0;
                G = 0.0;
                B = 0.0;
            end
            R = R * 255;
            G = G * 255;
            B = B * 255;
            rgb = round([R,G,B]);
        end
    end
end

