function out_signal = bci_Process( in_signal )
%bci_Process is called once for each block of EEG data. It receives an 
%   input in its input argument, and sets its output signal to values 
%   resulting from filter operation. A filter which does not perform any 
%   modification to the signal (e.g., a statistics filter) needs to copy
%   its input signal into the output signal

    %copy input signal to output signal
    out_signal = in_signal;

    % BCI 2000 parameters
    global shared bci_StateSamples;
    if ~shared.data.runComplete && ~shared.data.isError
        while true
            if shared.data.isSave2
                shared.data.isSave2 = 0;
                if shared.data.isSave1
                    shared.data.isSave1 = 0;
                    nextBlock = shared.data.block_counter+1;
                    if nextBlock <= size(shared.data.in_signal,1)
                        try
                            pportChannel = bi2de([bci_StateSamples.DigitalInput1;...
                                                  bci_StateSamples.DigitalInput2;...
                                                  bci_StateSamples.DigitalInput3;...
                                                  bci_StateSamples.DigitalInput4;...
                                                  bci_StateSamples.DigitalInput5;...
                                                  bci_StateSamples.DigitalInput6;...
                                                  bci_StateSamples.DigitalInput7;...
                                                  bci_StateSamples.DigitalInput8]','right-msb')';
                            shared.data.in_signal(nextBlock,:,:) = [in_signal;pportChannel];
                        catch ME
                            save;
                            rethrow(ME);
                        end
                        shared.data.block_counter = nextBlock;
                        shared.data.block_counter_main = shared.data.block_counter_main + 1;
                        shared.data.isSave2 = 1;
                        shared.data.isSave1 = 1;
                    else
                        shared.data.isError = 1;
                        shared.data.stop = 1;
                    end
                    break;
                else
                    shared.data.isSave2 = 1;
                end
            end
            pause(0.01);
        end
    end
end

