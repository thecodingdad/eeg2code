function [spfilter,bestchannel] = taskSpatialFilter( data_x,data_template,settings )
% taskSpatialFilter trains the spatialfilter using a background task
    addpath('functions');
    
    % get best channel
    bestchannel = getBestcVEPChannel(data_x,data_template,20);

    % mean data of best channel
    mdata_x = squeeze(mean(data_x));
    mdata_x = repmat(mdata_x,[1, size(data_x,1)]);
    mdata_x = mdata_x(bestchannel,:);

    spfilter=generateSpatialFilter(data_x,mdata_x',settings);
end

