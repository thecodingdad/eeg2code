function seq_generator(sequence_number, bit_size, max_correlation_coef)
        
    if ~bit_size, bit_number = 60; end                          %number of bits in one sequence
    if ~sequence_number, sequence_number = 200; end             %number of sequences generated
    if ~max_correlation_coef, max_correlation_coef = 0.8; end   %maximum correlation coefficient between seqs
    
    
    randomBinaryNumbers = transpose(randi([0, 1], sequence_number, bit_size));
    R = corrcoef(randomBinaryNumbers);    
    [row, column, ]  = find(triu(R,1) > max_correlation_coef);
    
    while ~isempty(row)
        
        newRandomBinaryNumbers = transpose(randi([0, 1], size(row, 1), bit_size));        
        randomBinaryNumbers(:, row) = newRandomBinaryNumbers;
        
        R = corrcoef(randomBinaryNumbers);
        [row, column, ]  = find(triu(R,1) > max_correlation_coef);
    end       
    randomBinaryNumbers = transpose(randomBinaryNumbers);
    
    csvwrite('random_seq_pool.csv', randomBinaryNumbers);
    csvwrite('random_seq_weights.csv', cat(1,ones(1,sequence_number)./sequence_number,zeros(1,sequence_number)));  
end