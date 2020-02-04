function [ data_downsampled ] = downsample( data, n, dim )
%DOWNSAMPLE Summary of this function goes here
%   Detailed explanation goes here
    if n <= 1
        data_downsampled = data;
    else
        data_downsampled = [];
        if dim == 1
            data = data(1:end-mod(size(data,1),n),:);
        else
            data = data(:,1:end-mod(size(data,2),n));
        end
        for ii=1:size(data,3-dim)
            if dim == 1
                data_downsampled = [data_downsampled,mean(reshape(data(:,ii),n,[]))'];
            else
                data_downsampled = [data_downsampled;mean(reshape(data(ii,:)',n,[]))];
            end
        end
    end
end

