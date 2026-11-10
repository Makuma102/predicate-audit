function out = confusionRates(pred, ref, alpha)
%CONFUSIONRATES Compare a grader's verdicts with reference labels.
%   out = predaudit.confusionRates(pred, ref) takes two logical vectors of
%   equal length (true = success) and returns a struct with the counts
%   tp, fp, fn, tn and three rates, each a struct with fields
%   k, n, rate, wilson (1x2) and exact (1x2, Clopper-Pearson):
%
%     successRate       (tp + fp) / n
%     falseSuccessRate  fp / (tp + fp) = P(ref = fail    | grader = success)
%     falseFailureRate  fn / (fn + tn) = P(ref = success | grader = fail)
%
%   Both error rates are conditioned on the grader's verdict, because that
%   is what the reader of a reported success rate needs to know.
%   These intervals assume simple random sampling. For a stratified label
%   sample use predaudit.stratifiedRatio instead.

    arguments
        pred {mustBeVector}
        ref {mustBeVector}
        alpha (1,1) double = 0.05
    end
    pred = logical(pred(:));
    ref = logical(ref(:));
    if numel(pred) ~= numel(ref)
        error('predaudit:confusionRates:lengthMismatch', ...
            'pred has %d elements but ref has %d.', numel(pred), numel(ref));
    end
    out.n = numel(pred);
    out.tp = sum(pred & ref);
    out.fp = sum(pred & ~ref);
    out.fn = sum(~pred & ref);
    out.tn = sum(~pred & ~ref);
    out.successRate = rate(out.tp + out.fp, out.n, alpha);
    out.falseSuccessRate = rate(out.fp, out.tp + out.fp, alpha);
    out.falseFailureRate = rate(out.fn, out.fn + out.tn, alpha);
end

function r = rate(k, n, alpha)
    [wl, wh, p] = predaudit.wilsonInterval(k, n, alpha);
    [el, eh] = predaudit.clopperPearson(k, n, alpha);
    r = struct('k', k, 'n', n, 'rate', p, 'wilson', [wl wh], 'exact', [el eh]);
end
