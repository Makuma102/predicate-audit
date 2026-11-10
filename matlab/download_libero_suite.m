function files = download_libero_suite(suite, outDir, opts)
%DOWNLOAD_LIBERO_SUITE Fetch official LIBERO demonstration files.
%   files = download_libero_suite("libero_goal") downloads every
%   <task>_demo.hdf5 of the suite from the official Hugging Face dataset
%   yifengzhu-hf/LIBERO-datasets into data/<suite>/ next to this file.
%   Suites: libero_spatial, libero_object, libero_goal, libero_10, libero_90.
%
%   download_libero_suite(suite, outDir, MaxFiles=1) limits the number of
%   files, DryRun=true only lists names and sizes.
%
%   Files are 0.5 to 1 GB each (libero_goal: 10 files). A file that already
%   exists with the size the server reports is skipped.

    arguments
        suite (1,1) string {mustBeMember(suite, ...
            ["libero_spatial", "libero_object", "libero_goal", "libero_10", "libero_90"])}
        outDir (1,1) string = fullfile(fileparts(mfilename('fullpath')), "data", suite)
        opts.MaxFiles (1,1) double {mustBePositive} = Inf
        opts.DryRun (1,1) logical = false
    end
    repo = "yifengzhu-hf/LIBERO-datasets";
    api = "https://huggingface.co/api/datasets/" + repo + "/tree/main/" + suite;
    try
        listing = webread(api, weboptions('Timeout', 60, 'ContentType', 'json'));
    catch err
        error('download_libero_suite:listing', ...
            'Could not list %s (%s). Check the network connection.', api, err.message);
    end
    if iscell(listing)
        listing = [listing{:}];
    end
    paths = string({listing.path});
    sizes = [listing.size];
    keep = endsWith(paths, ".hdf5");
    paths = paths(keep); sizes = sizes(keep);
    n = min(numel(paths), opts.MaxFiles);
    fprintf('%s: %d files, %.1f GB in total; fetching %d.\n', ...
        suite, numel(paths), sum(sizes) / 1e9, n);
    if ~opts.DryRun && ~isfolder(outDir)
        mkdir(outDir);
    end
    files = strings(n, 1);
    for i = 1:n
        [~, name, ext] = fileparts(paths(i));
        target = fullfile(outDir, name + ext);
        files(i) = target;
        fprintf('  %-70s %7.1f MB', name + ext, sizes(i) / 1e6);
        if opts.DryRun
            fprintf('\n');
            continue
        end
        d = dir(target);
        if ~isempty(d) && d.bytes == sizes(i)
            fprintf('  (already present)\n');
            continue
        end
        url = "https://huggingface.co/datasets/" + repo + "/resolve/main/" + paths(i);
        websave(target, url, weboptions('Timeout', Inf));
        d = dir(target);
        if isempty(d) || d.bytes ~= sizes(i)
            error('download_libero_suite:incomplete', ...
                '%s is incomplete (%d of %d bytes). Delete it and run again.', ...
                target, d.bytes, sizes(i));
        end
        fprintf('  done\n');
    end
end
