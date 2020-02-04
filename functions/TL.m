function time = TL(p,c)
% TL(p,c)
%  p: Accuracy
%  c: time (in seconds) for one selection
time = inf;
if p<=0.5
    return;
end
time = c./(2.*p-1);
%(log2(N)+ p.*log2(p)+ (1-p).*log2((1-p)./(N-1)))./c;


end

