function bestsubset = createSequencePool( length, maxCorr )
    allDecValues = 0:2^length-1;
    allSequences = de2bi(allDecValues,length,2,'left-msb');
    bitchanges = sum(diff(allSequences,[],2)~=0,2);
    allSequences = allSequences(bitchanges==7,:);
    
    numSubsets = 1000;
    subsets = cell(1,numSubsets);
    subsetCorrs = nan(1,numSubsets);
    for ii=1:numSubsets
        tic;
        order = randperm(size(allSequences,1));
        subsets{ii} = [];
        for jj=1:size(order,2)
            if jj==1 || (~isempty(subsets{ii}) && max(corr(subsets{ii}',allSequences(order(jj),:)')) <= maxCorr)
                subsets{ii} = [subsets{ii};allSequences(order(jj),:)];
            end
        end
        corrs = corr(subsets{ii}');
        subsetCorrs(ii) = max(corrs(corrs~=1));
        fprintf('%.0f: %.0f - mean: %.3f, max: %.3f',ii,size(subsets{ii},1),mean(corrs(corrs~=1)),subsetCorrs(ii));
        toc;
    end
    [~,b]=sort(cellfun(@(x)size(x,1),subsets));
    biggestsubset=subsets{b(end)};
    corr(biggestsubset);
    [~,b]=sort(mean((corr(biggestsubset'))'));
    bestsubset=biggestsubset(b(1:100),:);
end

