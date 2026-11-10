function results = run_tests()
%RUN_TESTS Run the unit tests. From the repo root: matlab -batch "cd matlab; run_tests"
    here = fileparts(mfilename('fullpath'));
    addpath(here);
    results = runtests(fullfile(here, 'tests'));
    disp(table(results));
    if any([results.Failed])
        error('run_tests:failed', '%d test(s) failed.', sum([results.Failed]));
    end
end
