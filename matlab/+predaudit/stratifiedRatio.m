function out = stratifiedRatio(y, x, stratum, popSize, alpha)
%STRATIFIEDRATIO Population rate from a stratified sample (ratio estimator).
%   out = predaudit.stratifiedRatio(y, x, stratum, popSize) estimates
%   R = (population total of y) / (population total of x) when only a
%   stratified random sample was labelled.
%
%   Inputs, one element per labelled episode:
%     y        numerator indicator, e.g. grader = success AND human = fail
%     x        denominator indicator, e.g. grader = success
%     stratum  stratum id of the episode (numeric, string or categorical)
%     popSize  N_h, number of episodes in that stratum in the full rollout
%              population (must be constant within a stratum)
%
%   With y and x as above, R is the population false-success rate. The
%   label sample oversamples disagreements, so the raw sample rate is
%   biased; this estimator undoes that.
%
%   Estimator (combined ratio estimator, Cochran 1977, sec. 6.11):
%     R_hat = sum_h N_h ybar_h / sum_h N_h xbar_h
%     e_i   = y_i - R_hat x_i
%     Var   = (1 / X_hat^2) sum_h N_h^2 (1 - n_h / N_h) s2_eh / n_h
%   where s2_eh is the sample variance of e inside stratum h. The variance
%   comes from a first-order Taylor expansion of the ratio, so it needs a
%   reasonable number of labelled episodes; every stratum needs n_h >= 2.
%   The interval is computed on the logit scale so it stays inside (0, 1);
%   when R_hat is exactly 0 or 1 the interval is NaN and an exact bound
%   per stratum should be reported instead.

    arguments
        y
        x
        stratum
        popSize {mustBeNumeric, mustBePositive}
        alpha (1,1) double = 0.05
    end
    y = double(y(:)); x = double(x(:)); popSize = double(popSize(:));
    stratum = stratum(:);
    n = numel(y);
    if numel(x) ~= n || numel(stratum) ~= n || numel(popSize) ~= n
        error('predaudit:stratifiedRatio:lengthMismatch', ...
            'y, x, stratum and popSize must have one element per labelled episode.');
    end
    [g, ids] = findgroups(stratum);
    H = max(g);
    Nh = zeros(H, 1); nh = zeros(H, 1); yb = zeros(H, 1); xb = zeros(H, 1);
    for h = 1:H
        in = (g == h);
        Ns = unique(popSize(in));
        if numel(Ns) ~= 1
            error('predaudit:stratifiedRatio:popSize', ...
                'popSize is not constant inside stratum %s.', string(ids(h)));
        end
        Nh(h) = Ns;
        nh(h) = sum(in);
        if nh(h) < 2
            error('predaudit:stratifiedRatio:tooFew', ...
                'Stratum %s has %d labelled episode(s); at least 2 are needed for a variance.', ...
                string(ids(h)), nh(h));
        end
        if nh(h) > Nh(h)
            error('predaudit:stratifiedRatio:popSize', ...
                'Stratum %s has more labelled episodes (%d) than its population size (%d).', ...
                string(ids(h)), nh(h), Nh(h));
        end
        yb(h) = mean(y(in));
        xb(h) = mean(x(in));
    end
    Yhat = sum(Nh .* yb);
    Xhat = sum(Nh .* xb);
    if Xhat == 0
        error('predaudit:stratifiedRatio:zeroDenominator', ...
            'No labelled episode has x = 1, so the rate is undefined.');
    end
    R = Yhat / Xhat;
    e = y - R * x;
    v = 0;
    for h = 1:H
        in = (g == h);
        v = v + Nh(h)^2 * (1 - nh(h) / Nh(h)) * var(e(in)) / nh(h);
    end
    v = v / Xhat^2;
    out.rate = R;
    out.se = sqrt(v);
    out.numeratorTotal = Yhat;
    out.denominatorTotal = Xhat;
    out.strata = table(ids, Nh, nh, yb, xb, ...
        'VariableNames', {'stratum', 'popSize', 'nLabelled', 'yMean', 'xMean'});
    if R > 0 && R < 1
        z = sqrt(2) * erfcinv(alpha);
        L = log(R / (1 - R));
        seL = out.se / (R * (1 - R));          % delta method for the logit
        out.ci = 1 ./ (1 + exp(-[L - z * seL, L + z * seL]));
    else
        out.ci = [NaN NaN];
    end
end
