function bci_StartRun
%bci_StartRun is called when the system enters the running state. As opposed
%   to Initialize, which is the place for tasks that need to be performed on
%   each parameter change, StartRun is provided for tasks that need to be 
%   performed each time the user clicks "Run" or "Resume" in the operator window.

    % BCI 2000 parameters and states
    global shared;
    
    shared.data.start = 1;
    
end

