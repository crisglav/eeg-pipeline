function [power_fig, topoplot_fig] = plot_power(params,bidsID)

% Load power
load(fullfile(params.power_folder,[bidsID '_power.mat']),'power');

% Average power across channels
avgpow = mean(power.powspctrm,1);

freqNames = fields(params.freq_band)';    
% Plot average power spectrum across channels
power_fig = figure('Position',[506 844 1131 509], 'visible', 'off');
plot(power.freq,avgpow,'k');
hold on
box off
title(['Average PSD of ' bidsID],'Interpreter','None');
ylabel('Power (uV^2/Hz)');
xlabel('Frequency (Hz)');
c = lines(length(freqNames));
for iFreq =1:length(freqNames)
    freqRange = find(power.freq >= params.freq_band.(freqNames{iFreq})(1) & power.freq <= params.freq_band.(freqNames{iFreq})(2));
    a(iFreq) = area(power.freq(freqRange),avgpow(freqRange),'FaceColor',c(iFreq,:)); % Color the area
    relpow = sum(avgpow(freqRange))/sum(avgpow);
    l{iFreq} = [freqNames{iFreq} ' (' num2str(relpow*100,'%.1f') '%)'];
    hold on;
end
legend(a,l)

% Topoplots of different frequency bands
topoplot_fig = figure('Position',[492 459 1019 894], 'visible', 'off');
tcl = tiledlayout(2,2);
tcl.TileSpacing = 'compact';
tcl.Padding = 'compact';
for iFreq=1:length(freqNames)
    cfg = [];
    cfg.xlim = params.freq_band.(freqNames{iFreq});
%     cfg.marker = 'labels'; % Uncomment if you want the electrode names
    cfg.comment = 'xlim';
    cfg.commentpos = 'middlebottom';
    ft_topoplotER(cfg,power)
    title(freqNames{iFreq});
    cb = colorbar;
    ax = gca;
    ax.Parent = tcl;
    ax.Layout.Tile = iFreq;
    cb.Parent = tcl;
    close;
end
title(tcl,{'Spatial distribution of power of ', bidsID},'Interpreter','None');

end