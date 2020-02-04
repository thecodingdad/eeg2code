function bci_StopRun
%bci_StopRun is called each time the system leaves the running state, 
%   entering the suspended state. Typically, this happens whenever the user
%   clicks "Suspend" in the operator window.
%   StopRun is also the only function from which a filter may change a 
%   parameter value. Any parameter changes inside StopRun will propagate to
%   the other modules without any explicit request from your side.

    % BCI 2000 parameters and states
    global shared;
    
    shared.data.stop = 1;
    
end