function [lo, hi, p] = clopperPearson(k, n, alpha)
%CLOPPERPEARSON Exact (Clopper-Pearson) interval for a binomial proportion.
%   [lo, hi, p] = predaudit.clopperPearson(k, n) returns the exact 95%
%   interval for k events in n trials (scalars).
%
%   Derivation: the lower limit solves P(X >= k | p) = alpha/2 and the upper
%   limit solves P(X <= k | p) = alpha/2. Because the binomial tail is a
%   regularised incomplete beta function, the solutions are beta quantiles:
%       lo = BetaInv(alpha/2;     k,     n - k + 1)   (0 if k == 0)
%       hi = BetaInv(1 - alpha/2; k + 1, n - k)       (1 if k == n)
%   Coverage is at least 1-alpha for every p, so use this one when a
%   guaranteed bound matters (for example "false success below 1%").
%   With k = 0 the upper limit is 1 - (alpha/2)^(1/n).
%   Uses only base MATLAB (betaincinv).

    arguments
        k (1,1) double {mustBeNonnegative, mustBeInteger}
        n (1,1) double {mustBeNonnegative, mustBeInteger}
        alpha (1,1) double {mustBeGreaterThan(alpha, 0), mustBeLessThan(alpha, 1)} = 0.05
    end
    if k > n
        error('predaudit:clopperPearson:badCounts', 'k must not exceed n.');
    end
    if n == 0
        lo = 0; hi = 1; p = NaN;
        return
    end
    p = k / n;
    if k == 0
        lo = 0;
    else
        lo = betaincinv(alpha / 2, k, n - k + 1);
    end
    if k == n
        hi = 1;
    else
        hi = betaincinv(1 - alpha / 2, k + 1, n - k);
    end
end
