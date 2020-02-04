function bci_Resting
%bci_Resting is called instead of Process while the system is in suspended
%   state. Typically, Resting is called repeatedly for filters inside 
%   source modules; in the remaining modules, Resting is called once when 
%   the system enters suspended state. Except that it is called at least 
%   once in suspended state, you should not make any assumption how often 
%   Resting is called.
    
    % BCI 2000 parameters and states
    global bci_Parameters bci_States;
    
    
end

