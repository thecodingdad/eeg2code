function [ spatialFilter ] = generateSpatialFilter( inputData, outputData, settings )
    % INPUT:
    % inputData:  [n,m,k]-Matrix
    % outputData: [n*k,1]-Matrix
    % settings.numEsnNeurons: number of inner esn neurons
    % settings.filterType: {'esn', 'reg', 'cca'}
    % settings.esnType: {'leaky_esn','plain_esn', ...}
    % (n=#trials, m=#channels, k=#samples)
    %
    % OUTPUT:
    % spatialFilter: filterType='esn': trained echo state network
    %                filterType='regression' or 'cca': [n,1]-Matrix

    if strcmp(settings.filterType,'esn')
        nForgetPoints = 0;
        inputDataShifted = shiftdim(squeeze(inputData),1);
        inputDataShifted = inputDataShifted(:,:)';
        nInputUnits = size(inputData,2)+1; nInternalUnits = settings.numEsnNeurons; nOutputUnits = size(outputData,2); 
        esn = generate_esn(nInputUnits, nInternalUnits, nOutputUnits, 'type', settings.esnType); 
        esn.internalWeights = esn.spectralRadius * esn.internalWeights_UnitSR;
        [spatialFilter, ~] = train_esn([ones(size(inputDataShifted,1),1),inputDataShifted], outputData, esn, nForgetPoints) ;
        
    elseif strcmp(settings.filterType,'reg')
        warning('off','stats:regress:RankDefDesignMat');
        inputDataShifted = shiftdim(squeeze(inputData),1);
        spatialFilter = regress(outputData,inputDataShifted(:,:)')';
        
    elseif strcmp(settings.filterType,'cca')
        warning('off','stats:canoncorr:NotFullRank');
        inputDataShifted = shiftdim(squeeze(inputData),1);
        [~,B,~,~,~] = canoncorr(outputData,inputDataShifted(:,:)');
        spatialFilter=B';
        
    end
end

