function [samples,bits] = upsampleBits(bits,bitchanges,afterTrialBitchanges)
    samplesPerBits = diff(find([1,abs(diff(bitchanges)),1]));
    if isempty(bitchanges), samplesPerBits = []; end
    afterTrialSamplesPerBits = diff(find([1,abs(diff(afterTrialBitchanges)),1]));
    if isempty(afterTrialBitchanges), afterTrialSamplesPerBits = []; end
    numBits = length(samplesPerBits)-length(afterTrialSamplesPerBits);
    samples = zeros(size(bits,2),sum(samplesPerBits));
    samplePos = 0;
    for bit = 1:numBits
        samples(:,samplePos+1:samplePos+samplesPerBits(bit)) = repmat(bits(bit,:)',1,samplesPerBits(bit));
        samplePos = samplePos+samplesPerBits(bit);
    end
    samples(:,samplePos+1:end) = 1;
    bits = bits(numBits+1:end,:);
end

