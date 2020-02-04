function bci_Halt
%BCI_HALT is called before any reconfiguration of the system takes place. 
%   If your filter initiates asynchronous operations such as playing a 
%   sound file, acquiring EEG data, or executing threads, its Halt member 
%   function should terminate all such operations immediately.
    
    % BCI 2000 parameters and states
    global bci_Parameters bci_States;
    
end

