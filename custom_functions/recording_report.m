function recording_report(params,bidsID)

import mlreportgen.report.*
import mlreportgen.dom.*

f = strcat(bidsID, '_report');
rpt = Report(fullfile(params.reports_folder, f), 'pdf');

% Title page
tp = TitlePage;
tp.Title = ['Report of ' bidsID];
append(rpt,tp);

%% Preprocessing report
ch1 = Chapter;
ch1.Title = 'Preprocessing report';

sec1 = Section;
sec1.Title = 'Bad channel rejection';
append(ch1,sec1);
para = Paragraph('Bad channels were automatically detected with clean_rawdata. By default flat channels, channels with high frequency noise and channels with poor predictability are rejected. In the following plot,  bad channels are marked in blue.');
% Add here figure of bad channels

bc_plot = plot_badchannels_singlestudy(params, bidsID);
bc_f = Figure(bc_plot);
append(ch1,para);
add(ch1, bc_f);

sec2 = Section;
sec2.Title = 'ICA. Independent component classification';
append(ch1,sec2);
[IC_plot, ic_kept, ic_kept_pc] = plot_ICs_singlestudy(params, bidsID);
para = Paragraph('Artefactual independent components were detected automatically with ICLabel. By default, components whose probability of being ''Muscle'' or ''Eye'' are higher than 80% are marked as artifactual and substracted from the data.');
append(ch1,para);
para1 = Paragraph(['In the current run, the threshold used was ' num2str(params.IClabel(2,1)*100, '%.2f') '% for Muscle and ' num2str(params.IClabel(3,1)*100, '%.2f') '% for Eye components.']);
append(ch1,para1);
f_ic = Figure(IC_plot);
add(ch1, f_ic);
para = Paragraph([num2str(ic_kept_pc*100, '%.2f') '% IC components were kept.']);
append(ch1,para);

sec3 = Section;
sec3.Title = 'Bad time segments rejection';
append(ch1,sec3);
[bs_plot, bs_secs, bs_pc] = plot_badtimesegments_singlestudy(params, bidsID);
para = Paragraph(['Bad time segments were detected automatically with ASR. In total ' num2str(bs_secs, '%.2f') '/' num2str(bs_secs/bs_pc*100, '%.2f') ' seconds of the data (' num2str(bs_pc, '%.2f') '%) were rejected']);

f_bs = Figure(bs_plot);
add(ch1, f_bs);
append(ch1,para);

append(rpt,ch1)
%% EEG features
ch2 = Chapter;
ch2.Title = 'EEG features report';

sec1 = Section;
sec1.Title = 'Power';
append(ch2,sec1);
[power_fig, topoplot_fig] = plot_power(params,bidsID);
f1 = Figure(power_fig);
add(ch2,f1);
f2 = Figure(topoplot_fig);
add(ch2,f2);

sec2 = Section;
sec2.Title = 'Peak frequency';
append(ch2,sec2);
pf_fig = plot_peakfrequency(params,bidsID);
f3 = Figure(pf_fig);
add(ch2,f3);

sec3 = Section;
sec3.Title = 'Connectivity';
append(ch2,sec3);
aec_plot = plot_connectivity(params,bidsID, 'aec');
f_aec = Figure(aec_plot);
dwpli_plot = plot_connectivity(params,bidsID, 'dwpli');
f_dwpli = Figure(dwpli_plot);
add(ch2,f_aec);
add(ch2,f_dwpli);

append(rpt,ch2);
close(rpt);
rptview(rpt);
end