function [lo, hi, p] = wilsonInterval(k, n, alpha)
%WILSONINTERVAL Wilson score interval for a binomial proportion.
%   [lo, hi, p] = predaudit.wilsonInterval(k, n) returns the 95% interval
%   for k events in n trials. k and n may be arrays of the same size.
%   [...] = predaudit.wilsonInterval(k, n, alpha) uses level 1-alpha.
%
%   Derivation: invert the score test |p_hat - p| <= z*sqrt(p(1-p)/n) for p.
%   Squaring gives a quadratic in p whose roots are
%       (p_hat + z^2/(2n) -/+ z*sqrt(p_hat(1-p_hat)/n + z^2/(4n^2))) / (1 + z^2/n).
%   n = 0 returns the uninformative interval [0, 1] and p = NaN.
%   No toolbox required.

    arguments
        k {mustBeNumeric, mustBeNonnegative, mustBeInteger}
        n {mustBeNumeric, mustBeNonnegative, mustBeInteger}
        alpha (1,1) double {mustBeGreaterThan(alpha, 0), mustBeLessThan(alpha, 1)} = 0.05
    end
    if any(k(:) > n(:))
        error('predaudit:wilsonInterval:badCounts', 'k must not exceed n.');
    end
    k = double(k);
    n = double(n);
    z = sqrt(2) * erfcinv(alpha);          % two-sided normal quantile
    p = k ./ n;                            % NaN where n == 0
    d = 1 + z^2 ./ n;
    c = (p + z^2 ./ (2 * n)) ./ d;
    h = z .* sqrt(p .* (1 - p) ./ n + z^2 ./ (4 * n.^2)) ./ d;
    lo = max(0, c - h);
    hi = min(1, c + h);
    empty = (n == 0);
    lo(empty) = 0;
    hi(empty) = 1;
end
