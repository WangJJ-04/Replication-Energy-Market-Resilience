%%--------------------------------------------------------%%
%%                    TVP-VAR package                     %%
%%--------------------------------------------------------%%
%%
%%  mimp = impulse_girf(nl, nlen, mb, ma, mh)
%%
%%  "impulse_girf" computes time-varying generalized impulse
%%  responses following Pesaran and Shin (1998).
%%
%%  [input]
%%    nl:       # of lags
%%    nlen:     length of response to compute
%%    mb,ma,mh: time-varying parameters
%%
%%  [output]
%%    mimp:  (ns*nlen)*(nk^2) matrix
%%

function mimp = impulse_girf(nl, nlen, mb, ma, mh)

ns = size(mh, 1);
nk = size(mh, 2);

mimp = zeros(ns*nlen, nk^2);
my = zeros(nl+nlen, nk);
mbs = [mb ; (ones(nlen, 1) * mb(ns, :))];

for t = nl+1 : ns
  mAinv = finvm(fAt(ma(t, :), nk));
  mSigma = mAinv * diag(exp(mh(t, :))) * mAinv';

  for i = 1 : nk
    vshock = mSigma(:, i) ./ sqrt(mSigma(i, i));

    my(nl+1, :) = vshock';

    for j = nl+2 : nl+nlen
      my(j, :) = mbs(t+j-nl-1, :) * fXt(my(j-nl:j-1, :), 0)';
    end

    mimp((t-1)*nlen+1:t*nlen, (i-1)*nk+1:i*nk) ...
      = my(nl+1:end, :);
  end
end
