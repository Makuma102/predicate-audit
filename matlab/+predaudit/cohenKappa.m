function out = cohenKappa(a, b, opts)
%COHENKAPPA Cohen's kappa for two annotators with binary labels.
%   out = predaudit.cohenKappa(a, b) takes two logical vectors (one label
%   per episode from each annotator) and returns a struct with
%     po     observed agreement
%     pe     chance agreement, sum over classes of the product of marginals
%     kappa  (po - pe) / (1 - pe)
%     se     Cohen's (1960) large-sample standard error
%            sqrt(po (1 - po) / (n (1 - pe)^2))
%     ci     normal interval kappa -/+ z se
%     bootCi percentile bootstrap interval over episodes (NaN if NBoot = 0)
%
%   The bootstrap interval is the one to report; the closed-form se is an
%   approximation that treats pe as fixed.
%   kappa is NaN when pe == 1 (both annotators used a single class).

    arguments
        a {mustBeVector}
        b {mustBeVector}
        opts.Alpha (1,1) double = 0.05
        opts.NBoot (1,1) double {mustBeNonnegative, mustBeInteger} = 2000
        opts.Seed (1,1) double = 0
    end
    a = logical(a(:));
    b = logical(b(:));
    if numel(a) ~= numel(b)
        error('predaudit:cohenKappa:lengthMismatch', ...
            'Annotator vectors have %d and %d elements.', numel(a), numel(b));
    end
    n = numel(a);
    if n == 0
        error('predaudit:cohenKappa:empty', 'No labelled episodes given.');
    end
    [out.kappa, out.po, out.pe] = kappaOf(a, b);
    out.n = n;
    out.se = sqrt(out.po * (1 - out.po) / (n * (1 - out.pe)^2));
    z = sqrt(2) * erfcinv(opts.Alpha);
    out.ci = [out.kappa - z * out.se, out.kappa + z * out.se];
    out.bootCi = [NaN NaN];
    if opts.NBoot > 0
        rs = RandStream('mt19937ar', 'Seed', opts.Seed);
        ks = zeros(opts.NBoot, 1);
        for i = 1:opts.NBoot
            idx = randi(rs, n, n, 1);
            ks(i) = kappaOf(a(idx), b(idx));
        end
        ks = sort(ks(~isnan(ks)));
        if ~isempty(ks)
            m = numel(ks);
            iLo = max(1, floor(opts.Alpha / 2 * m) + 1);
            iHi = min(m, ceil((1 - opts.Alpha / 2) * m));
            out.bootCi = [ks(iLo), ks(iHi)];
        end
    end
end

function [kappa, po, pe] = kappaOf(a, b)
    po = mean(a == b);
    pa = mean(a);
    pb = mean(b);
    pe = pa * pb + (1 - pa) * (1 - pb);
    if pe >= 1
        kappa = NaN;
    else
        kappa = (po - pe) / (1 - pe);
    end
end
