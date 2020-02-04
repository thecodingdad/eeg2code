classdef task_manager < handle
%TASK_MANAGER - manages matlab background tasks
    
    properties
        parpool;            %the parallel pool object
        tasks = struct();   %list of all used background tasks
    end
    
        
    %% THREADING FUNCTIONS
    methods(Access = public)
        function startParPool(this, numTasks)
        %STARTPARPOOL(numTasks) - starts a parpool using NUMTASKS workers
            if ~this.isPoolReady(numTasks)
                myCluster = parcluster('local');
                myCluster.NumWorkers = numTasks;
                saveProfile(myCluster); 
                this.parpool = parpool(numTasks);
            else
                this.parpool.IdleTimeout = 30;
            end
            %this.setTaskPriorities('realtime');
        end
        
        function ready = isPoolReady(this,numTasks)
        %ISPOOLREADY - checks if pool is already started
            currentPool = gcp('nocreate');
            ready = false;
            if ~isempty(currentPool)
                if currentPool.Cluster.NumWorkers >= numTasks
                    this.parpool = currentPool;
                    ready = true;
                else
                    delete(gcp);
                end
            end
        end
        
        function add(this,name)
        %ADD(name) - adds a task with identifier NAME
            if ~isfield(this.tasks, name)
                this.tasks.(name) = [];
            end
        end
        
        function ready = isReady(this,name)
        %ISREADY(name) - checks if task NAME is ready to run
            ready = ~this.isValid(name) || (~this.hasFailed(name) ...
                                            && this.isValid(name) ...
                                            && strcmp(this.tasks.(name).State,'finished') ...
                                            && this.tasks.(name).Read == 1);
        end
        
        function error = hasFailed(this,name)
        %HASFAILED(name) - checks if task NAME has failed
            error = this.isValid(name) && ~isempty(this.tasks.(name).Error);
        end
        
        function finished = isFinished(this,name)
        %ISFINISHED(name) - checks if task NAME is finished (to read its output)
            finished = ~this.hasFailed(name) && this.isValid(name) && strcmp(this.tasks.(name).State,'finished');
        end
        
        function valid = isValid(this,name)
        %ISVALID(name) - checks both if task NAME exists and if task is a valid object
            valid = isfield(this.tasks, name) && isa(this.tasks.(name),'parallel.FevalFuture') && this.tasks.(name).isvalid();
        end
        
        function [varargout] = getOutput(this,name)
        %GETOUTPUT(name) - returns the output of task NAME and deletes it
            if this.isFinished(name) && this.tasks.(name).NumOutputArguments > 0 && nargout <= this.tasks.(name).NumOutputArguments
                varargout = this.tasks.(name).OutputArguments;
                this.tasks.(name).fetchOutputs;
                this.cancel(name);
            else
                varargout = cell(1,nargout);
                warning('No output data.');
            end
        end
        
        function run(this,name,fun,varargin)
        %RUN(name,fun,...) - runs function fun with params (...) in a task named name 
            this.add(name);
            if this.isReady(name)
                %this.startParPool(length(fieldnames(this.tasks)));
                %this.tasks.(name)=parfeval(this.parpool,fun,nargout(fun),varargin{:});
                this.tasks.(name)=parfeval(fun,nargout(fun),varargin{:});
            else
                warning('Task not ready');
            end
        end
        
        function cancel(this,name)
        %CANCEL(name) - cancels task NAME
            if isfield(this.tasks, name) && isobject(this.tasks.(name))
                this.tasks.(name).cancel();
                delete(this.tasks.(name));
                this.tasks = rmfield(this.tasks,name);
            end
        end
        
        function cancelAll(this)
        %CANCELALL - cancels all running tasks
            taskNames = fieldnames(this.tasks);
            for ii = 1:length(taskNames)
                this.cancel(taskNames{ii});
            end
        end
        
        function task = get(this,name)
        %GET(name) - get task object of task NAME
            task = this.tasks.(name);
        end
    end
    
    methods(Static)
        function setPriorityAndAffinity(process,priority,affinity)
        %SETTASKPRIORITYANDAFFINITY(process,priority,affinity)
        %   process: process id or name
        %   priority: ["Idle", "BelowNormal", "Normal", "AboveNormal", "High", "RealTime"]
        %   affinity: 1=CPU0, 2=CPU1, 4=CPU2, 8=CPU3, 3=CPU0 and CPU1, ...
            if ischar(process)
                system(['PowerShell "$Process = Get-Process ' process '; '...
                            '$Process.ProcessorAffinity=' mat2str(affinity) '; '...
                            '$Process.priorityclass=\"' priority '\"";']);
            else
                system(['PowerShell "$Process = Get-Process -Id ' mat2str(process) '; '...
                            '$Process.ProcessorAffinity=' mat2str(affinity) '; '...
                            '$Process.priorityclass=\"' priority '\"";']);
            end
        end
    end
    
end

