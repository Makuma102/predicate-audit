function out = logisticFit(X, y, opts)
%LOGISTICFIT Logistic regression by Newton / IRLS, no toolbox needed.
%   out = predaudit.logisticFit(X, y) fits P(y = 1) = 1 / (1 + exp(-eta)),
%   eta = b0 + X b, where X is n-by-p (no intercept column) and y is a
%   logical n-vector. Returns beta ((p+1)-by-1, intercept first), Wald
%   standard errors, z statistics, two-sided p-values, the log-likelihood
%   and a convergence flag.
%
%   Each Newton step solves (A' W A) d = A' (y - mu) with W = diag(mu (1 - mu));
%   the covariance of beta is inv(A' W A) at the optimum (inverse Fisher
%   information).
%
%   If the classes are perfectly separated the maximum-likelihood estimate
%   does not exist; the fit then stops with converged = false and a warning.
%   Used for RQ3: false success on predicate type, policy success rate and
%   perturbation.

    arguments
        X (:,:) double
        y
        opts.MaxIter (1,1) double = 100
        opts.Tol (1,1) double = 1e-10
    end
    y = double(logical(y(:)));
    n = numel(y);
    if size(X, 1) ~= n
        error('predaudit:logisticFit:sizeMismatch', ...
            'X has %d rows but y has %d elements.', size(X, 1), n);
    end
    A = [ones(n, 1), X];
    if rank(A) < size(A, 2)
        error('predaudit:logisticFit:rankDeficient', ...
            'The design matrix is rank deficient; drop a redundant column.');
    end
    beta = zeros(size(A, 2), 1);
    converged = false;
    for it = 1:opts.MaxIter
        mu = 1 ./ (1 + exp(-A * beta));
        w = mu .* (1 - mu);
        Hm = A' * (A .* w);
        if rcond(Hm) < 1e-14
            break
        end
        step = Hm \ (A' * (y - mu));
        beta = beta + step;
        if max(abs(step)) < opts.Tol
            converged = true;
            break
        end
    end
    if ~converged
        warning('predaudit:logisticFit:notConverged', ...
            ['Logistic fit did not converge. The usual cause is perfect or ', ...
             'near-perfect separation; the estimates are not reliable.']);
    end
    mu = 1 ./ (1 + exp(-A * beta));
    w = mu .* (1 - mu);
    C = inv(A' * (A .* w)); %#ok<MINV> covariance matrix is wanted explicitly
    out.beta = beta;
    out.se = sqrt(diag(C));
    out.z = beta ./ out.se;
    out.p = erfc(abs(out.z) / sqrt(2));
    out.cov = C;
    muc = min(max(mu, eps), 1 - eps);
    out.logLik = sum(y .* log(muc) + (1 - y) .* log(1 - muc));
    out.iterations = it;
    out.converged = converged;
end
