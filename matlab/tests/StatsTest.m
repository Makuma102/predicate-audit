classdef StatsTest < matlab.unittest.TestCase
    % Expected values were computed independently of this code: closed
    % forms evaluated by hand, and Clopper-Pearson limits obtained by
    % bisection on the exact binomial distribution function.

    methods (Test)
        function wilsonKnownValues(tc)
            [lo, hi, p] = predaudit.wilsonInterval(8, 10);
            tc.verifyEqual([lo hi p], [0.4901624715, 0.9433178485, 0.8], 'AbsTol', 1e-9);
            [lo, hi] = predaudit.wilsonInterval(0, 50);
            tc.verifyEqual([lo hi], [0, 0.0713475991], 'AbsTol', 1e-9);
            [lo, hi] = predaudit.wilsonInterval(490, 500);
            tc.verifyEqual([lo hi], [0.9635798168, 0.9891008164], 'AbsTol', 1e-9);
        end

        function wilsonEmptySample(tc)
            [lo, hi, p] = predaudit.wilsonInterval(0, 0);
            tc.verifyEqual([lo hi], [0 1]);
            tc.verifyTrue(isnan(p));
        end

        function wilsonRejectsBadCounts(tc)
            tc.verifyError(@() predaudit.wilsonInterval(5, 3), ...
                'predaudit:wilsonInterval:badCounts');
        end

        function clopperPearsonKnownValues(tc)
            [lo, hi] = predaudit.clopperPearson(8, 10);
            tc.verifyEqual([lo hi], [0.4439045377, 0.9747892737], 'AbsTol', 1e-8);
            [lo, hi] = predaudit.clopperPearson(3, 40);
            tc.verifyEqual([lo hi], [0.0157421799, 0.2038647487], 'AbsTol', 1e-8);
        end

        function clopperPearsonZeroEvents(tc)
            % Closed form: upper limit = 1 - (alpha/2)^(1/n).
            [lo, hi] = predaudit.clopperPearson(0, 200);
            tc.verifyEqual(lo, 0);
            tc.verifyEqual(hi, 1 - 0.025^(1/200), 'AbsTol', 1e-10);
            tc.verifyEqual(hi, 0.0182753404, 'AbsTol', 1e-9);
        end

        function exactIntervalContainsWilsonCentre(tc)
            [lo, hi] = predaudit.clopperPearson(17, 60);
            tc.verifyLessThan(lo, 17/60);
            tc.verifyGreaterThan(hi, 17/60);
        end

        function confusionCounts(tc)
            pred = logical([1 1 1 0 0 1 0 1]);
            ref  = logical([1 0 1 0 1 1 0 0]);
            c = predaudit.confusionRates(pred, ref);
            tc.verifyEqual([c.tp c.fp c.fn c.tn], [3 2 1 2]);
            tc.verifyEqual(c.falseSuccessRate.rate, 2/5);
            tc.verifyEqual(c.falseFailureRate.rate, 1/3);
            tc.verifyEqual(c.successRate.rate, 5/8);
        end

        function kappaKnownTable(tc)
            % 2x2 table [20 5; 10 15]: po = 0.7, pe = 0.5, kappa = 0.4.
            a = [true(25, 1); false(25, 1)];
            b = [true(20, 1); false(5, 1); true(10, 1); false(15, 1)];
            k = predaudit.cohenKappa(a, b, 'NBoot', 0);
            tc.verifyEqual([k.po k.pe k.kappa], [0.7 0.5 0.4], 'AbsTol', 1e-12);
            tc.verifyEqual(k.se, 0.1296148140, 'AbsTol', 1e-9);
        end

        function kappaBootstrapBrackets(tc)
            a = [true(25, 1); false(25, 1)];
            b = [true(20, 1); false(5, 1); true(10, 1); false(15, 1)];
            k = predaudit.cohenKappa(a, b, 'NBoot', 500, 'Seed', 1);
            tc.verifyLessThan(k.bootCi(1), 0.4);
            tc.verifyGreaterThan(k.bootCi(2), 0.4);
        end

        function mcnemarKnownValue(tc)
            % b = 12 (g1 right, g2 wrong), c = 3: p = 2 P(X <= 3 | 15, 1/2) = 0.03515625.
            ref = true(20, 1);
            g1 = true(20, 1); g1(1:3) = false;
            g2 = true(20, 1); g2(4:15) = false;
            m = predaudit.mcnemarExact(g1, g2, ref);
            tc.verifyEqual([m.b m.c], [12 3]);
            tc.verifyEqual(m.p, 0.03515625, 'AbsTol', 1e-12);
        end

        function stratifiedReducesToSampleRate(tc)
            % One stratum sampled completely: the estimator is the plain
            % ratio and the finite-population correction makes the se zero.
            y = [1 0 0 1 0 0].'; x = [1 1 0 1 1 0].';
            s = predaudit.stratifiedRatio(y, x, ones(6, 1), 6 * ones(6, 1));
            tc.verifyEqual(s.rate, 0.5, 'AbsTol', 1e-12);
            tc.verifyEqual(s.se, 0, 'AbsTol', 1e-12);
        end

        function stratifiedUndoesOversampling(tc)
            % Stratum A (N = 100): 4 labelled, y = [1 1 0 0], x all 1.
            % Stratum B (N = 900): 4 labelled, y all 0, x all 1.
            % R = (100 * 0.5 + 900 * 0) / 1000 = 0.05; the raw rate is 0.25.
            y = [1 1 0 0 0 0 0 0].'; x = ones(8, 1);
            st = ["A" "A" "A" "A" "B" "B" "B" "B"].';
            N = [100 100 100 100 900 900 900 900].';
            s = predaudit.stratifiedRatio(y, x, st, N);
            tc.verifyEqual(s.rate, 0.05, 'AbsTol', 1e-12);
            % Var = (1/1000^2) * 100^2 * (1 - 4/100) * (1/3) / 4
            tc.verifyEqual(s.se^2, 100^2 * 0.96 * (1/3) / 4 / 1000^2, 'RelTol', 1e-10);
            tc.verifyGreaterThan(s.ci(2), 0.05);
            tc.verifyLessThan(s.ci(1), 0.05);
        end

        function logisticKnownFit(tc)
            x = (0:7).';
            y = logical([0 0 1 0 1 1 0 1]).';
            f = predaudit.logisticFit(x, y);
            tc.verifyTrue(f.converged);
            tc.verifyEqual(f.beta, [-1.5162051683; 0.4332014767], 'AbsTol', 1e-8);
            tc.verifyEqual(f.se, [1.5295259756; 0.3748657066], 'AbsTol', 1e-8);
        end

        function topKShare(tc)
            task = ["a" "a" "a" "b" "b" "c" "c" "d"].';
            bad = logical([1 1 1 1 0 0 0 0]).';
            c = predaudit.topKConcentration(task, bad, [1 2]);
            tc.verifyEqual(c.share, [0.75 1.0]);
            tc.verifyEqual(c.uniformShare, [0.25 0.5]);
        end

        function noiseFloorMatchesScope(tc)
            n = predaudit.noiseFloor(0.98, 0.05, 0, 500);
            tc.verifyEqual(n.bias, 0.049, 'AbsTol', 1e-12);
            tc.verifyEqual(n.srHuman, 0.931, 'AbsTol', 1e-12);
            % Wilson half-width at 490/500 from the interval above.
            tc.verifyEqual(n.halfWidth, (0.9891008164 - 0.9635798168) / 2, 'AbsTol', 1e-9);
        end
    end
end
