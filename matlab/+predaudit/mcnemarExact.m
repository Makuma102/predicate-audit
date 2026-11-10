function out = mcnemarExact(g1, g2, ref)
%MCNEMAREXACT Exact McNemar test: is grader 1 more accurate than grader 2?
%   out = predaudit.mcnemarExact(g1, g2, ref) compares two graders that
%   judged the same episodes against the same reference labels (all logical
%   vectors, true = success). Only discordant episodes carry information:
%     b = episodes where g1 is correct and g2 is wrong
%     c = episodes where g1 is wrong and g2 is correct
%   Under H0 (equal accuracy), b ~ Binomial(b + c, 1/2), so the two-sided
%   exact p-value is min(1, 2 P(X <= min(b, c))).
%   The binomial tail is computed with base MATLAB:
%     P(X <= k | m, 1/2) = betainc(1/2, m - k, k + 1)   for k < m.
%
%   This is the right test for RQ5 (strict grader vs built-in grader),
%   because both graders see the same episodes and a two-sample test would
%   ignore that pairing.

    arguments
        g1
        g2
        ref
    end
    g1 = logical(g1(:)); g2 = logical(g2(:)); ref = logical(ref(:));
    if numel(g1) ~= numel(ref) || numel(g2) ~= numel(ref)
        error('predaudit:mcnemarExact:lengthMismatch', ...
            'g1, g2 and ref must have the same number of episodes.');
    end
    ok1 = (g1 == ref);
    ok2 = (g2 == ref);
    out.b = sum(ok1 & ~ok2);
    out.c = sum(~ok1 & ok2);
    m = out.b + out.c;
    k = min(out.b, out.c);
    if m == 0
        out.p = 1;
    elseif k == m
        out.p = 1;
    else
        out.p = min(1, 2 * betainc(0.5, m - k, k + 1));
    end
    out.accuracy1 = mean(ok1);
    out.accuracy2 = mean(ok2);
end
