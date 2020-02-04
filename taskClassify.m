function [predSamples,predAction,predAcc,predPValue,bitAcc] = taskClassify(trainmodel,data_x,data_y_pred,realTarget,actionBits,settings,targetdelays,doClassification)
% classifierThread

    predAction = 0;
    predAcc = 0;
    predPValue = 0;
    bitAcc = 0;
        
    % CHECK DIMENSIONS
    %if size(data_x,1) < size(data_x,2), data_x = data_x'; end
    
    % timelag data
    if strcmp(settings.modelType,'remote')
        if ~isempty(data_x)
            % send data to server
			%tic;
            trainmodel.write(reshape(data_x',1,numel(data_x)))

            % wait for prediction
            dataread = [];
            if size(data_x,1) == size(actionBits,2)
                while length(dataread) ~= (size(data_x,1)-settings.timelag+1)*4
                    dataread = [dataread trainmodel.read()];
                end
            else
                while length(dataread) ~= size(data_x,1)*4
                    dataread = [dataread trainmodel.read()];
                end
            end
			%reqtime = toc;
			%fileID = fopen('textfile.txt', 'a');
			%fprintf(fileID,'%.5f\n',reqtime);
			%fclose(fileID);
            predSamples = [data_y_pred,typecast(dataread,'single')];
        else
            predSamples = data_y_pred;
        end
    else
        data_x_timelag = zeros(size(data_x,1),settings.timelag);
        for t=0:(settings.timelag-1)
            data_x_timelag(:,t+1) = circshift(data_x,[-t 0])';
        end
        % skip last timelag samples
        data_x_timelag = data_x_timelag(1:end-settings.timelag+1,:);

        % PREDICT TRIAL Samples
        switch settings.modelType
            case 'reg', predSamples = [data_y_pred,trainmodel(2:end)*data_x_timelag'+trainmodel(1)];
        end
    end
    
    % classify target
    if doClassification
        actionBits = actionBits(:,1:end-settings.timelag+1);
        predData = predSamples;
        if strcmp(settings.targetSelection, 'hamming')
            predData = predData>=0.5;
        end
        
        % CLASSIFY (PREDICTED) CHOSEN ACTION
        actionACC = zeros(1,size(actionBits,1));
        pValues = zeros(1,size(actionBits,1));
        for action=1:size(actionBits,1)
            targetdelay = targetdelays(action);
            eegshift = round(targetdelay * settings.samplesPerFrame);
            if strcmp(settings.targetSelection,'correlation')
                [actionACC(action),pValues(action)] = corr(actionBits(action,:)',circshift(predData,[0 -eegshift])','tail','right');
            else
                actionACC(action) = pdist([actionBits(action,:); circshift(predData,[0 -eegshift])], settings.targetSelection);
            end
        end
        
        if realTarget > 0
            targetdelay = targetdelays(realTarget);
            eegshift = round(targetdelay * settings.samplesPerFrame);
            bitAcc = mean(actionBits(realTarget,:) == circshift(predData>=0.5,[0 -eegshift]));
        end
        
        if strcmp(settings.targetSelection,'correlation')
            [predAcc,predAction]=max(actionACC);
            predPValue = pValues(predAction);
        else
            [predAcc,predAction]=min(actionACC);
        end
    end
    
end

