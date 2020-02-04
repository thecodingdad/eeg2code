function utr = UTR(N,p,c)
% ITR(N,A,time)
%   calculates information transfer rate (bit/s)
%  N: Number of characters in Alphabet (Alphabet size)
%  p: Accuracy
%  c: time (in seconds) for one selection
utr = 0;
if p<1/N
    return;
end
utr = (2.*p-1).*log2(N-1)./c;
%(log2(N)+ p.*log2(p)+ (1-p).*log2((1-p)./(N-1)))./c;


end

