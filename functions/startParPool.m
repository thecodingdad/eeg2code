function startParPool(numCores)
    if isempty(gcp('nocreate'))
        myCluster = parcluster('local');
        myCluster.NumWorkers = numCores;
        saveProfile(myCluster); 
        parpool(numCores);
    end
end

