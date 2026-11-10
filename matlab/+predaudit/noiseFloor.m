function out = noiseFloor(srGrader, fsRate, ffRate, nEpisodes, alpha)
%NOISEFLOOR Compare predicate bias with sampling noise (RQ4).
%   out = predaudit.noiseFloor(srGrader, fsRate, ffRate, nEpisodes)
%
%   Let G be the grader's verdict and H the human label. With
%     s  = P(G = 1)             reported success rate
%     FS = P(H = 0 | G = 1)     false-success rate
%     FF = P(H = 1 | G = 0)     false-failure rate
%   the law of total probability gives the human-referenced success rate
%     P(H = 1) = s (1 - FS) + (1 - s) FF,
%   so the bias of the reported number is
%     bias = s - P(H = 1) = s FS - (1 - s) FF.
%   The sampling half-width of a success rate s measured on n episodes is
%   taken from the Wilson interval. The ratio |bias| / halfWidth says
%   whether the predicate error is visible above evaluation noise.
%
%   Check from the scope: s = 0.98, n = 500 gives a half-width of about
%   1.2 points.

    arguments
        srGrader (1,1) double {mustBeInRange(srGrader, 0, 1)}
        fsRate (1,1) double {mustBeInRange(fsRate, 0, 1)}
        ffRate (1,1) double {mustBeInRange(ffRate, 0, 1)}
        nEpisodes (1,1) double {mustBePositive, mustBeInteger}
        alpha (1,1) double = 0.05
    end
    out.srHuman = srGrader * (1 - fsRate) + (1 - srGrader) * ffRate;
    out.bias = srGrader * fsRate - (1 - srGrader) * ffRate;
    z = sqrt(2) * erfcinv(alpha);
    n = nEpisodes;
    out.halfWidth = z * sqrt(srGrader * (1 - srGrader) / n + z^2 / (4 * n^2)) / (1 + z^2 / n);
    out.ratio = abs(out.bias) / out.halfWidth;
end
