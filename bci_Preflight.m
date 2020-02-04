function [ out_signal_dim ] = bci_Preflight( in_signal_dim )
%bci_Preflight checks whether the preconditions for successful operation 
%   are met. This function is called whenever parameter values are re-applied,
%   i.e., whenever the user presses "Set Config" in the operator window. If
%   Preflight does not report an error, this counts as a statement that 
%   Initialize and Process will work properly with the current parameters. 
%   The input argument to Preflight will inform you about what kind of input 
%   signal your filter is going to receive, and your filter is expected to 
%   report the properties of its output signal via the output parameter.
    global bci_Parameters bci_States;
    out_signal_dim = in_signal_dim;
    
end