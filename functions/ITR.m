function itr = ITR(N,A,time)
% ITR(N,A,time)
%   calculates information transfer rate (bit/s)
%  N: Number of characters in Alphabet (Alphabet size)
%  A: Accuracy
%  time: time (in seconds) for one selection
itr = 0;
%if A<1/N
%    return;
%end
itr = (log2(N)+ A.*log2(A)+ (1-A).*log2((1-A)./(N-1)))./time;


end

