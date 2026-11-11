function make_figures()
%MAKE_FIGURES Draw the paper's data figures from results/pooled/.
%   Run run_pooled_summary first. Writes PNG (300 dpi) and PDF files to
%   paper/figures/:
%     fig_lost_by_task     lost successes per task, release vs hold
%     fig_flicker_by_class flicker rate per goal-predicate class with
%                          exact 95% intervals
%     fig_intervals        exact vs task-clustered interval of the pooled
%                          lost rate

    here = fileparts(mfilename('fullpath'));
    addpath(here);
    pooled = fullfile(here, '..', 'results', 'pooled');
    outDir = fullfile(here, '..', 'paper', 'figures');
    if ~isfolder(outDir)
        mkdir(outDir);
    end
    E = readtable(fullfile(pooled, 'episodes_all.csv'), 'TextType', 'string');
    blue = [0.13 0.40 0.67]; orange = [0.85 0.37 0.01]; grey = [0.35 0.35 0.35];

    % ---- Figure: lost per task -------------------------------------
    [g, key] = findgroups(E.taskKey);
    rel = accumarray(g, double(E.lost == 1 & E.protocol == "release"));
    hol = accumarray(g, double(E.lost == 1 & E.protocol == "hold"));
    keep = (rel + hol) > 0;
    key = key(keep); rel = rel(keep); hol = hol(keep);
    [~, order] = sortrows([rel hol], [1 2]);
    key = key(order); rel = rel(order); hol = hol(order);
    labels = shortLabel(key);
    f = figure('Visible', 'off', 'Units', 'centimeters', 'Position', [2 2 17 8.5], 'Color', 'w');
    b = barh([rel hol], 0.8, 'grouped');
    b(1).FaceColor = orange; b(2).FaceColor = blue;
    b(1).EdgeColor = 'none'; b(2).EdgeColor = 'none';
    set(gca, 'YTick', 1:numel(labels), 'YTickLabel', labels, 'TickLabelInterpreter', 'none', ...
        'FontSize', 8, 'Box', 'off', 'XGrid', 'on', 'TickDir', 'out');
    xlim([0 50]);
    xlabel('Accepted successes lost after 5 s (of 50 demonstrations)');
    legend({'Gripper released', 'Gripper held'}, 'Location', 'southeast', 'Box', 'off', 'FontSize', 8);
    for i = 1:numel(rel)
        text(rel(i) + 0.6, i - 0.2, sprintf('%d', rel(i)), 'FontSize', 7, 'Color', orange);
        text(hol(i) + 0.6, i + 0.2, sprintf('%d', hol(i)), 'FontSize', 7, 'Color', blue);
    end
    save2(f, fullfile(outDir, 'fig_lost_by_task'));

    % ---- Figure: flicker by predicate class -------------------------
    R = E(E.protocol == "release", :);
    [g, cls] = findgroups(R.predicateClass);
    n = accumarray(g, 1); k = accumarray(g, double(R.flicker == 1));
    lo = zeros(size(n)); hi = lo; p = lo;
    for i = 1:numel(n)
        [lo(i), hi(i), p(i)] = predaudit.clopperPearson(k(i), n(i));
    end
    [~, order] = sort(p, 'descend');
    cls = cls(order); n = n(order); p = p(order); lo = lo(order); hi = hi(order);
    f = figure('Visible', 'off', 'Units', 'centimeters', 'Position', [2 2 8.5 6.5], 'Color', 'w');
    bar(100 * p, 0.65, 'FaceColor', blue, 'EdgeColor', 'none'); hold on;
    errorbar(1:numel(p), 100 * p, 100 * (p - lo), 100 * (hi - p), 'LineStyle', 'none', ...
        'Color', grey, 'LineWidth', 0.9, 'CapSize', 4);
    lab = strings(numel(cls), 1);
    for i = 1:numel(cls)
        lab(i) = sprintf('%s (n=%d)', cls(i), n(i));
    end
    set(gca, 'XTick', 1:numel(cls), 'XTickLabel', lab, 'XTickLabelRotation', 30, ...
        'TickLabelInterpreter', 'none', 'FontSize', 8, 'Box', 'off', 'YGrid', 'on', 'TickDir', 'out');
    ylabel('Demonstrations with flicker (%)'); ylim([0 60]);
    save2(f, fullfile(outDir, 'fig_flicker_by_class'));

    % ---- Figure: exact vs clustered interval ------------------------
    O = readtable(fullfile(pooled, 'overall.csv'), 'TextType', 'string');
    f = figure('Visible', 'off', 'Units', 'centimeters', 'Position', [2 2 8.5 4.6], 'Color', 'w');
    hold on;
    yy = [4 3 2 1]; names = strings(4, 1); i = 0;
    for pr = ["release", "hold"]
        r = O(O.protocol == pr, :);
        i = i + 1;
        plot(100 * [r.lostExactLo r.lostExactHi], yy(i) * [1 1], '-', 'Color', grey, 'LineWidth', 2.2);
        plot(100 * r.lostRate, yy(i), 'o', 'MarkerFaceColor', grey, 'MarkerEdgeColor', 'w', 'MarkerSize', 5);
        names(i) = pr + ", episodes independent";
        i = i + 1;
        plot(100 * [r.lostClusterLo r.lostClusterHi], yy(i) * [1 1], '-', 'Color', orange, 'LineWidth', 2.2);
        plot(100 * r.lostRate, yy(i), 'o', 'MarkerFaceColor', orange, 'MarkerEdgeColor', 'w', 'MarkerSize', 5);
        names(i) = pr + ", tasks resampled";
    end
    set(gca, 'YTick', 1:4, 'YTickLabel', flipud(names), 'TickLabelInterpreter', 'none', ...
        'FontSize', 8, 'Box', 'off', 'XGrid', 'on', 'TickDir', 'out');
    ylim([0.4 4.6]); xlim([0 10]);
    xlabel('Pooled lost rate, 95% interval (%)');
    save2(f, fullfile(outDir, 'fig_intervals'));
    fprintf('Figures written to %s\n', outDir);
end

function labels = shortLabel(key)
    labels = strings(numel(key), 1);
    for i = 1:numel(key)
        parts = split(key(i), "/");
        t = regexprep(parts(2), '^[A-Z_]+SCENE\d+_', '');
        t = strrep(t, "_", " ");
        t = regexprep(t, '^pick up the black bowl ', 'bowl ');
        t = regexprep(t, ' and place it on the plate$', ' -> plate');
        t = regexprep(t, '^pick up the ', '');
        t = regexprep(t, '^put the ', '');
        t = regexprep(t, '^put ', '');
        if strlength(t) > 60
            t = extractBefore(t, 58) + "...";
        end
        labels(i) = t + "  [" + erase(parts(1), "libero_") + "]";
    end
end

function save2(f, base)
    set(f, 'PaperPositionMode', 'auto');
    pos = get(f, 'Position');
    set(f, 'PaperUnits', 'centimeters', 'PaperSize', pos(3:4));
    print(f, char(base + ".png"), '-dpng', '-r300');
    print(f, char(base + ".pdf"), '-dpdf', '-painters');
    close(f);
end
