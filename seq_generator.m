function seq_generator(sequence_number, bit_size, max_correlation_coef)
    
    if ~bit_size, bit_number = 20; end
    if ~sequence_number, sequence_number = 20; end
    if ~max_correlation_coef, max_correlation_coef = 0.8; end
    
    
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
    
end