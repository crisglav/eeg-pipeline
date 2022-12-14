%% Comparison of EEG features between old and young groups on the LEMON dataset
%
% This script compares the EEG features obtained after applyting the
% pipeline between old and young people on the LEMON dataset.
%
% The bayesFactor package for Bayesian statistics testing 
% and the Raincloud plots function need to be downloaded for statistical
% analysis and visualization, respectively. The code can be found in:
%
% - BayesFactor [https:/www.github.com/klabhub/bayesFactor]
% - Raincloud plots [https:/www.github.com/RainCloudPlots/RainCloudPlots]
%
% Cristina Gil, 21.11.2022, Technical University of Munich

clear all;

% Add EEGLab
eeglab_path = '/rechenmagd4/toolboxes_and_functions/eeglab';
run(fullfile(eeglab_path,'eeglab.m'));
% Add fieldtrip
addpath /rechenmagd4/toolboxes_and_functions/fieldtrip
ft_defaults
% Add raincloud plots
addpath /rechenmagd4/toolboxes_and_functions/plotting_functions/raincloudplots
% Add fdr function
addpath /rechenmagd4/toolboxes_and_functions/statistics_functions
% Add Bayes Factor package
run('/rechenmagd4/Experiments/2021_preprocessing/pipeline/external_functions/bayes_factor/installBayesFactor.m')

%% Load study with clean data
study_path = '/rechenmagd4/Experiments/2021_preprocessing/datasets/LEMON-8min-bids/derivatives_v2022_10_05';
STUDY = pop_loadstudy('filename', 'LEMON-8min-clean.study', 'filepath', study_path);

% Sort participants by age group
subject = {STUDY.datasetinfo.subject};
age_group = categorical({STUDY.datasetinfo.age_group});
summary(age_group)

% young (20-35)
mask_young = ismember(age_group,{'20-25','25-30','30-35'});
n_young = sum(mask_young);
young_ids = subject(mask_young);

% old (55-80)
mask_old = ismember(age_group,{'55-60','60-65','65-70','70-75','75-80'});
n_old = sum(mask_old);
old_ids = subject(mask_old);

freqBands = {'theta','alpha','beta','gamma'};
connMeas = {'dwpli','aec'};
%% ALPHA PEAK FREQUENCY
% Load peak frequency data from all recordings
apf_path = fullfile(study_path, 'EEG_features','power');

nSubj = length(subject);
apf_max = nan(1,nSubj);
apf_cog = nan(1,nSubj);

for i=1:nSubj
    load(fullfile(apf_path,[subject{i} '_peakfrequency.mat']));
    if ~isempty(peakfrequency.localmax)
        apf_max(i) = peakfrequency.localmax;
    end
    apf_cog(i) = peakfrequency.cog;
end

% Bayesian one-side independent samples t-test to check if the old group has lower APF than the young group
young_max = apf_max(mask_young);
old_max = apf_max(mask_old);
[bf_max,p_localmax] = bf.ttest2(old_max,young_max,'tail','left');

young_cog = apf_cog(mask_young);
old_cog = apf_cog(mask_old);
[bf_cog,p_cog] = bf.ttest2(old_cog,young_cog,'tail','left');
save('stats_apf.mat','bf_max','p_localmax','bf_cog','p_cog');

%% APF - raincloudplots
colours = lines(2);
f = figure('Units','centimeters','Position', [0 0 16 7]);
tlc = tiledlayout(1,2,'Padding','compact');
ax = nexttile;
rc_max = rm_raincloud({young_max,old_max},colours);
xlim([7.5, 13.5]);
ylim([-0.4,1]);
xlabel('Frequency (Hz)')
title('Local maximum');
nexttile
rc_cog = rm_raincloud({young_cog,old_cog},colours);
xlim([7.5, 13.5]);
ylim([-0.4,1]);
xlabel('Frequency (Hz)')
title('Center of gravity');
hold on
% fake legend
h(1) = scatter(nan,nan,10,colours(1,:),'filled');
hold on
h(2) = scatter(nan,nan,10,colours(2,:),'filled');
legend(h,'young','old');
saveas(f,'apf_rainclouds.svg');

%% CONNECTIVITY
% Path to connectivity matrices
connectivity_path = fullfile(study_path, 'EEG_features','connectivity');
% Atlas positions
atlas_path = '/rechenmagd4/Experiments/2021_preprocessing/pipeline/parcellations/Schaefer2018_400Parcels_7Networks_order_FSLMNI152_1mm.Centroid_RAS.csv';
atlas400 = readtable(atlas_path);
networks = {'Vis','SomMot','DorsAttn','SalVentAttn','Limbic','Cont','Default'};
pos = cell(1,length(networks));
axisticks = ones(1,length(networks)+1);
axistickslabelpos = ones(1,length(networks));
for i=1:length(networks)
    pos{i}  = find(cellfun(@(x) contains(x,['_' networks{i} '_']), atlas400.ROIName)); % all sources belonging to network{i}
    axisticks(i+1) = length(pos{i})+axisticks(i);
    axistickslabelpos(i) = axisticks(i)+(axisticks(i+1)-axisticks(i))/2; % set the network label in the middle
end
newpos = vertcat(pos{:});

% List matrices
meas = 'aec'; % 'dwpli' or 'aec'

conn_files = dir(fullfile(connectivity_path,['*_' meas '_*.mat']));
for iBand=1:length(freqBands)
    fBand = freqBands{iBand};
    conn_band = conn_files(contains({conn_files.name},fBand));
    % Note that there are some subjects without connectivity matrices
    subject_conn = cellfun(@(x) regexp(x,['.*(?=_' meas '_*)'],'match','lineanchors'),{conn_band.name});
    no_data = subject(~contains(subject,subject_conn));
    
    % Load connectivity matrices from the old and young group
    conn_old_ids = find(contains(subject_conn,old_ids));
    conn_young_ids = find(contains(subject_conn,young_ids));
    
    old_conn = nan(400,400,length(conn_old_ids));
    young_conn = nan(400,400,length(conn_young_ids));
    
    for i=1:length(conn_old_ids)
        try
            load(fullfile(conn_band(conn_old_ids(i)).folder,conn_band(conn_old_ids(i)).name));
        catch
            error(['cannot load data from ' conn_band(conn_old_ids(i)).name])
        end
        old_conn(:,:,i) = connMatrix;
    end
    
    for i=1:length(conn_young_ids)
        try
            load(fullfile(conn_band(conn_young_ids(i)).folder,conn_band(conn_young_ids(i)).name));
        catch
            error(['cannot load data from ' conn_band(conn_young_ids(i)).name])
        end
        young_conn(:,:,i) = connMatrix;
    end
    
    % Re-arrange matrices by atlas networks
    old_conn_r = old_conn(newpos,newpos,:);
    young_conn_r = young_conn(newpos,newpos,:);
    
    % 79800 bayesian two-sided independent sample ttests between old and young
    % connectivity matrices (one test per source pair)
    b = nan(400,400);
    pval = nan(400,400);
    tval = nan(400,400);
    for i=2:400
        for j=1:(i-1)
            o = squeeze(old_conn_r(i,j,:));
            y = squeeze(young_conn_r(i,j,:));
            [~,p,~,s] = ttest2(o,y);
            pval(i,j) = p;
            tval(i,j) = s.tstat;
            b(i,j) = bf.ttest('T',s.tstat,'N',[numel(o) numel(y)]);
            
        end
    end
    
    % Corret p-values for multiple comparisons with fdr
    [~,~,padj] = fdr(pval(:));
    padj = reshape(padj,400,400);    
    
    stats.(fBand).tval = tval;
    stats.(fBand).pval = pval;
    stats.(fBand).padj = padj;
    stats.(fBand).bf = b;

end

save(['stats_' meas '_conn.mat'],'stats');
%% Connectivity - Plot t-values and Bayes factors
% Load stats file
meas = 'aec';
statsfile = ['stats_' meas '_conn.mat'];
load(statsfile);

fig = figure('Units','centimeters','Position',[0 0 11 8], 'visible', 'on');
tcl = tiledlayout(2,2,'TileSpacing','compact','Padding','none');

% Plot matrices with t-values color coded. Shade in grey all t-values
% with low evidence (1/30 < BF < 30)
for iBand=1:length(freqBands)
    fBand = freqBands{iBand};
    
    % Bayesian statistics 
    high_evidence_cc = or(stats.(fBand).bf >= 30, stats.(fBand).bf <= 1/30);
    low_evidence = and(stats.(fBand).bf > 1/30, stats.(fBand).bf < 30);
    
%     % Frequentist statistics
%     high_evidence = stats.(fBand).padj < 0.05;
%     low_evidence = stats.(fBand).padj >= 0.05;
    
    ax = nexttile(tcl);
    imagesc(stats.(fBand).tval,'AlphaData',or(isnan(stats.(fBand).tval),low_evidence)*0.1);
    hold on
    imagesc(stats.(fBand).tval,'AlphaData',high_evidence_cc);
    colormap([1 1 1; parula(255)]);
    hold off
    
%     % Plot bayes factors - I don't like this option because you don't
%     see the direction of the effect
%     high_evidence = or(stats.(fBand).bf >= 30, stats.(fBand).bf <= 1/30);
%     low_evidence = and(stats.(fBand).bf > 1/30, stats.(fBand).bf < 30);
%     ax = nexttile(tcl);
%     imagesc(log(stats.(fBand).bf),'AlphaData',or(isnan(stats.(fBand).bf),low_evidence)*0.1);
%     hold on
%     imagesc(log(stats.(fBand).bf),'AlphaData',high_evidence);
%     caxis([log(1/30) log(30)])
%     colormap([1 1 1; parula(255)]);
%     hold off
    
    set(ax,'XTick',axistickslabelpos,'XtickLabel',[],'YTick',axistickslabelpos,'YtickLabel',[],'TickLength',[0 0],'TickDir','out','box','off')
    if iBand ==3
        set(ax,'XtickLabel',networks,'XtickLabelRotation',45,'YtickLabel',networks)
    end
    grid on
    set(ax,'GridColor','w','GridAlpha',0.5,'Layer','top');
    ax2 = copyobj(ax,ax.Parent);
    set(ax2,'Ytick',axisticks','Xtick',axisticks,'yticklabel',[],'xticklabel',[]);
    colorbar;
end
saveas(fig,[meas '_conn_bf.svg']);

%% GRAPH MEASURES
graph_path = fullfile(study_path, 'EEG_features','graph_measures');

% List matrices
meas = 'aec';
graph_files = dir(fullfile(graph_path,['*_' meas '_*.mat']));

for iBand=1:length(freqBands)
    fBand = freqBands{iBand};
    graph_files_band = graph_files(contains({graph_files.name},fBand));
    % Note that there are some subjects without connectivity matrices
    subject_graph = cellfun(@(x) regexp(x,['.*(?=_graph_' meas '_*)'],'match','lineanchors'),{graph_files_band.name});
    no_data = subject(~contains(subject,subject_graph));
    
    % Load graph measures from the old and young group
    graph_old_ids = find(contains(subject_graph,old_ids));
    graph_young_ids = find(contains(subject_graph,young_ids));
    
    old_degree = nan(length(graph_old_ids),400);
    old_cc = nan(length(graph_old_ids),400);
    old_gcc = nan(1,length(graph_old_ids));
    old_geff = nan(1,length(graph_old_ids));
    old_s = nan(1,length(graph_old_ids));
    young_degree = nan(length(graph_young_ids),400);
    young_cc = nan(length(graph_young_ids),400);
    young_gcc = nan(1,length(graph_young_ids));
    young_geff = nan(1,length(graph_young_ids));
    young_s = nan(1,length(graph_young_ids));
    
    for i=1:length(graph_old_ids)
        try
            load(fullfile(graph_files_band(graph_old_ids(i)).folder,graph_files_band(graph_old_ids(i)).name));
        catch
            error(['cannot load data from ' graph_files_band(graph_old_ids(i)).name])
        end
        old_degree(i,:) = graph_measures.degree;
        old_cc(i,:) = graph_measures.cc;
        old_gcc(i) = graph_measures.gcc;
        old_geff(i) = graph_measures.geff;
        old_s(i) = graph_measures.smallworldness;
    end
    
    for i=1:length(graph_young_ids)
        try
            load(fullfile(graph_files_band(graph_young_ids(i)).folder,graph_files_band(graph_young_ids(i)).name));
        catch
            error(['cannot load data from ' graph_files_band(graph_young_ids(i)).name])
        end
        young_degree(i,:) = graph_measures.degree;
        young_cc(i,:) = graph_measures.cc;
        young_gcc(i) = graph_measures.gcc;
        young_geff(i) = graph_measures.geff;
        young_s(i) = graph_measures.smallworldness;
    end
    
    data.gcc(iBand,:) = {young_gcc,old_gcc};
    data.geff(iBand,:) = {young_geff,old_geff};
    data.s(iBand,:) = {young_s,old_s};
    
    % Statistics - local measures
    t_degree = nan(1,400);
    b_degree = nan(1,400);
    p_degree = nan(1,400);
    
    t_cc = nan(1,400);
    b_cc = nan(1,400);
    p_cc = nan(1,400);
    % 400 two sided independent sample Bayesian ttests between old and young
    % local measures
    for i=1:400
        o_degree = old_degree(:,i);
        y_degree = young_degree(:,i);
        [~,p,~,s] = ttest2(o_degree,y_degree);
        p_degree(i) = p;
        t_degree(i) = s.tstat;
        b_degree(i) = bf.ttest('T',s.tstat,'N',[numel(o_degree) numel(y_degree)]);
            
        o_cc = old_cc(:,i);
        y_cc = young_cc(:,i);
        [~,p,~,s] = ttest2(o_cc,y_cc);
        p_cc(i) = p;
        t_cc(i) = s.tstat;
        b_cc(i) = bf.ttest('T',s.tstat,'N',[numel(o_cc) numel(y_cc)]);
    end
    % Corret p-values for multiple comparisons with fdr
    [~,~,padj_degree] = fdr(p_degree);
    [~,~,padj_cc]     = fdr(p_cc);

    stats.(fBand).degree.tval = t_degree;
    stats.(fBand).degree.pval = p_degree;
    stats.(fBand).degree.padj = padj_degree;
    stats.(fBand).degree.bf   = b_degree;
    stats.(fBand).cc.tval = t_cc;
    stats.(fBand).cc.pval = p_cc;
    stats.(fBand).cc.padj = padj_cc;
    stats.(fBand).cc.bf   = b_cc;    
    
    % Statistics - global measures    
    % Two-sided independent samples Bayesian t-tests between old and young global measures
    
    [~,p,~,s] = ttest2(old_gcc,young_gcc);
    b = bf.ttest('T',s.tstat,'N',[numel(old_gcc) numel(young_gcc)]);    
    stats.(fBand).gcc.tval = s.tstat;
    stats.(fBand).gcc.pval = p;
    stats.(fBand).gcc.bf = b;

    [~,p,~,s] = ttest2(old_geff,young_geff);
    b = bf.ttest('T',s.tstat,'N',[numel(old_geff) numel(young_geff)]);    
    stats.(fBand).geff.tval = s.tstat;
    stats.(fBand).geff.pval = p;
    stats.(fBand).geff.bf = b;
    
    [~,p,~,s] = ttest2(old_s,young_s);
    b = bf.ttest('T',s.tstat,'N',[numel(old_s) numel(young_s)]);    
    stats.(fBand).s.tval = s.tstat;
    stats.(fBand).s.pval = p;
    stats.(fBand).s.bf = b;
    
end
save(['stats_' meas '_graph.mat'],'stats');
save(['data_' meas '_graph.mat'],'data');
%% Raincloud plots - global measures
% Load stats file
meas = 'aec';
statsfile = ['stats_' meas '_graph.mat'];
load(statsfile);
datafile = ['data_' meas '_graph.mat'];
load(datafile);

colours = lines(2);
f = figure('Units','centimeters','Position', [0 0 18 5]);
tlc = tiledlayout(1,3,'Padding','compact');
ax = nexttile;
rm_raincloud(data.gcc,colours,1);
box off
ax.Color = 'none';
title('Global cc');
set(ax,'YTickLabel',flip(freqBands));
ax = nexttile;
rm_raincloud(data.geff,colours,1);
title('Global efficiency');
set(ax,'YTickLabel',flip(freqBands));
box off
ax.Color = 'none';
ax = nexttile;
rm_raincloud(data.s,colours,1);
title('Global smallworldness');
set(ax,'YTickLabel',flip(freqBands));
box off
ax.Color = 'none';
% fake legend
h(1) = scatter(nan,nan,10,colours(1,:),'filled');
hold on
h(2) = scatter(nan,nan,10,colours(2,:),'filled');
legend(h,'young','old');
saveas(f,[meas '_graph_global.svg']);

%% Brain plots - local measures
% Load surface structure
surf = ft_read_headshape('surface_white_both.mat');
% Source model: centroid positons from Schaefer atlas
cfg = [];
cfg.method = 'basedonpos';
cfg.sourcemodel.pos = [atlas400.R, atlas400.A, atlas400.S];
cfg.unit = 'mm';
sourcemodel_atlas = ft_prepare_sourcemodel(cfg);
sourcemodel_atlas.coordsys = 'mni';
    
f_degree = figure('Units','centimeters','Position',[0 0 10 9]);
f_cc = figure('Units','centimeters','Position',[0 0 10 9]);
tlc_degree = tiledlayout(f_degree,2,2,'TileSpacing','none','Padding','none');
tlc_cc = tiledlayout(f_cc,2,2,'TileSpacing','none','Padding','none');

    
for iBand=1:length(freqBands)
    
    fBand = freqBands{iBand};
    cmin = -4;
    cmax = 4;
    
    % Bayesian statistics
    high_evidence_degree = or(stats.(fBand).degree.bf >= 30, stats.(fBand).degree.bf <= 1/30);
    high_evidence_cc = or(stats.(fBand).cc.bf >= 30, stats.(fBand).cc.bf <= 1/30);

%     % Frequentist statistics
%     high_evidence_degree = stats.(fBand).degree.padj < 0.05;
%     high_evidence_cc = stats.(fBand).cc.padj < 0.05;
    
    % Plot t-values color coded, only high evidence/significant values    
    % Degree
    index = fix((stats.(fBand).degree.tval-cmin)/(cmax-cmin)*256)+1;
    rgb = squeeze(ind2rgb(index,parula(256)));
    ax1 = nexttile(tlc_degree);
    ft_plot_mesh(surf, 'edgecolor', 'none', 'vertexcolor', 'curv','facealpha',0.1);    
    ft_plot_mesh(sourcemodel_atlas.pos(high_evidence_degree,:), 'vertexsize',8, 'vertexcolor',rgb(high_evidence_degree,:));
    ax1.CLim = [cmin cmax];
    
    % Global clustering coefficient
    index = fix((stats.(fBand).cc.tval-cmin)/(cmax-cmin)*256)+1;
    rgb = squeeze(ind2rgb(index,parula(256)));
    ax2 = nexttile(tlc_cc);
    ft_plot_mesh(surf, 'edgecolor', 'none', 'vertexcolor', 'curv','facealpha',0.1);
    ft_plot_mesh(sourcemodel_atlas.pos(high_evidence_cc,:), 'vertexsize',8, 'vertexcolor',rgb(high_evidence_cc,:));
    ax2.CLim = [cmin cmax];
end
colorbar(ax1);
colorbar(ax2);
saveas(f_degree,[meas '_graph_degree.bmp']);
saveas(f_cc,[meas '_graph_cc.bmp']);

%% colorbar figure
f = figure('Units','centimeters','Position',[0 0 3 4]);
ax = axes;
c = colorbar(ax,'Location','southoutside');
caxis([-4 4]);
ax.Visible = 'off';
saveas(f,'colorbar.svg');