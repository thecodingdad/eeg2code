function [ data_skipped ] = skipSamples( data, trialLength, skip )
%SKIPSAMPLES Summary of this function goes here
%   Detailed explanation goes here

    % CHECK DIMENSIONS
    switched = false;
    if size(data,1) < size(data,2)
        data = data';
        switched = true;
    end
    
    if mod(size(data,1)/trialLength,1) ~= 0
        error ('wrong trial length');
    else
        numTrials = size(data,1)/trialLength;
        skippedIdxs = false(size(data,1),1);
        for ii=1:numTrials
            skippedIdxs((ii-1)*trialLength+skip)=true;
        end
        data_skipped = data(~skippedIdxs,:);
        if switched, data_skipped = data_skipped'; end
    end
end

