function [ filteredData ] = applySpatialFilter( inputData, spatialFilter, settings )
    % INPUT:
    % inputData:  [n,m]-Matrix
    % settings.filterType: {'esn', 'reg', 'cca'}
    % spatialFilter: filterType='esn': trained echo state network
    %                filterType='regression' or 'cca': [n,1]-Matrix
    % (n=#samples, m=#channels)
    %
    % OUTPUT:
    % filteredData: [n,1]-Matrix
    
    if strcmp(settings.filterType,'esn')
            filteredData = test_esn([ones(size(inputData,1),1),inputData],spatialFilter,0)';
        
    elseif strcmp(settings.filterType,'reg')
            filteredData=spatialFilter*inputData';
        
    elseif strcmp(settings.filterType,'cca')
            filteredData=spatialFilter*inputData';
        
    end
end

