classdef GradingTest < matlab.unittest.TestCase
    methods (Test)
        function firstHitAndEnd(tc)
            tr = logical([0 0 1 0 0]);
            tc.verifyTrue(predaudit.firstHit(tr));
            tc.verifyFalse(predaudit.endOfEpisode(tr));
            tc.verifyFalse(predaudit.endOfEpisode([]));
            tc.verifyTrue(predaudit.endOfEpisode(logical([0 1])));
        end

        function persistenceWindow(tc)
            tr = logical([0 1 1 0 1 1 1 0]);
            tc.verifyTrue(predaudit.persistWindow(tr, 1));
            [tf, at] = predaudit.persistWindow(tr, 3);
            tc.verifyTrue(tf);
            tc.verifyEqual(at, 7);
            tc.verifyFalse(predaudit.persistWindow(tr, 4));
        end

        function windowOneEqualsFirstHit(tc)
            tr = logical([0 0 0 1 0]);
            tc.verifyEqual(predaudit.persistWindow(tr, 1), predaudit.firstHit(tr));
        end

        function extraConditionMustHoldOnSameSteps(tc)
            tr    = logical([1 1 1 1 1 1]);
            extra = logical([1 0 1 1 0 1]);
            tc.verifyTrue(predaudit.persistWindow(tr, 2, extra));
            tc.verifyFalse(predaudit.persistWindow(tr, 3, extra));
            tc.verifyError(@() predaudit.persistWindow(tr, 2, extra(1:3)), ...
                'predaudit:persistWindow:lengthMismatch');
        end
    end
end
