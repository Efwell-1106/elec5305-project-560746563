classdef MusicFeatureLabApp < matlab.apps.AppBase
    % Integrated ELEC5305 workbench. Run run_app or this class to start.
    properties (Access = public)
        UIFigure
        MainGrid
        HeaderLabel
        SubtitleLabel
        Toolbar
        LoadButton
        DemoButton
        PlayOriginalButton
        PlayOutputButton
        StopButton
        SaveAudioButton
        ExportButton
        FileLabel
        Tabs
        AudioTab
        AudioGrid
        ControlsPanel
        ControlsGrid
        BrightnessLabel
        BrightnessSlider
        BrightnessValueLabel
        ResetButton
        PitchCheckBox
        AnalyzeButton
        HelpLabel
        MetricsTable
        PlotGrid
        WaveAxes
        SpectrumAxes
        SpectrogramAxes
        TrajectoryAxes
        FeatureDropDown
        CalibrationTab
        CalibrationGrid
        CalibrationToolbar
        RunCalibrationButton
        CalibrationExportButton
        CalibrationLabel
        CalibrationPlotGrid
        CentroidAxes
        SlopeAxes
        HFAxes
        CalibrationTable
        LibraryTab
        LibraryGrid
        LibraryToolbar
        ChooseLibraryButton
        RunBatchButton
        PreviewSelectedButton
        BatchExportButton
        CancelBatchButton
        LibraryPathLabel
        BatchMetricDropDown
        BatchAxes
        BatchTable
        BatchNoteLabel
        SynthTab
        SynthGrid
        SynthControls
        SynthControlGrid
        CarrierLabel
        CarrierField
        ModulatorLabel
        ModulatorField
        IndexLabel
        IndexField
        DurationLabel
        DurationField
        GenerateButton
        SynthHelpLabel
        SynthAxes
        MethodsText
        StatusLabel
    end

    % BEGIN APP LOGIC
    properties (GetAccess = public, SetAccess = private)
        OriginalAudio = []
        ProcessedAudio = []
        SampleRate = 0
        OriginalResult = struct([])
        ProcessedResult = struct([])
        CalibrationResults = table()
        BatchResults = table()
        SourceName = ''
        SourcePath = ''
        AppFolder = ''
        LibraryFolder = ''
        Brightness = 0
        PeakScale = 1
        AudioPitchEnabled = false
        BatchPitchEnabled = false
    end
    properties (Access = private)
        Player = []
        Busy = false
        CancelRequested = false
        Closing = false
        LastBatchRoot = ''
    end

    methods (Access = public)
        function loadAudio(app, filename)
            % Public workflow also supports reproducible automated checks.
            if app.Busy, return; end
            app.setBusy(true);
            guard=onCleanup(@()app.setBusy(false));
            app.stopAudio();
            app.status('Reading and analyzing audio...'); drawnow;
            info = audioinfo(filename);
            if info.TotalSamples < 1
                error('MusicFeatureLab:Empty', 'The selected file contains no audio samples.');
            end
            [x, fs] = audioread(filename);
            % Compute before committing state so a failed import is harmless.
            r = MusicAnalysis.analyze(x, fs, app.PitchCheckBox.Value);
            app.OriginalAudio = x;
            app.ProcessedAudio = x;
            app.SampleRate = fs;
            app.OriginalResult = r;
            app.ProcessedResult = r;
            app.AudioPitchEnabled = app.PitchCheckBox.Value;
            app.SourcePath = char(filename);
            [~,name,ext] = fileparts(filename);
            app.SourceName = [name ext];
            app.Brightness = 0;
            app.PeakScale = 1;
            app.BrightnessSlider.Value = 0;
            app.CalibrationResults = table();
            app.CalibrationTable.Data = table();
            cla(app.CentroidAxes); cla(app.SlopeAxes); cla(app.HFAxes);
            app.CalibrationLabel.Text = 'Run a sweep on the current source to compare nine brightness levels.';
            app.FileLabel.Text = sprintf('%s  |  %.2f s  |  %g Hz  |  %d channel(s)', ...
                app.SourceName,r.duration,fs,size(x,2));
            app.renderAudio();
            app.enableAudio(true);
            app.status(['Loaded ' app.SourceName '. ' r.note]);
        end

        function applyBrightness(app, value)
            if app.Busy || isempty(app.OriginalAudio), return; end
            app.setBusy(true);
            guard=onCleanup(@()app.setBusy(false));
            app.stopAudio();
            app.status('Applying brightness and updating analysis...'); drawnow;
            [y, info] = MusicAnalysis.brightness(app.OriginalAudio,app.SampleRate,value);
            r = MusicAnalysis.analyze(y,app.SampleRate,app.PitchCheckBox.Value);
            app.ProcessedAudio = y;
            app.ProcessedResult = r;
            app.AudioPitchEnabled = app.PitchCheckBox.Value;
            app.Brightness = value;
            app.PeakScale = info.peakScale;
            app.BrightnessSlider.Value = value;
            app.renderAudio();
            app.status(sprintf('Brightness %+.2f | Nyquist gain %+.1f dB | Peak scale %.3f. %s', ...
                value,info.gainDB,info.peakScale,r.note));
        end

        function results = runCalibration(app)
            results = table();
            if app.Busy || isempty(app.OriginalAudio), return; end
            app.stopAudio(); app.setBusy(true);
            guard = onCleanup(@()app.setBusy(false));
            app.status('Running nine brightness levels...');
            drawnow;
            results = MusicAnalysis.calibration(app.OriginalAudio,app.SampleRate);
            app.CalibrationResults = results;
            app.CalibrationTable.Data = results;
            ax = {app.CentroidAxes,app.SlopeAxes,app.HFAxes};
            vals = {results.Centroid_Hz,results.Slope_dB_Hz,results.HFRatio};
            labels = {'Centroid (Hz)','Slope (dB/Hz)','HF energy ratio'};
            for k = 1:3
                plot(ax{k},results.Brightness,vals{k},'-o','Color',[.12 .49 .68], ...
                    'LineWidth',1.7,'MarkerFaceColor',[.12 .49 .68]);
                xlabel(ax{k},'Brightness'); ylabel(ax{k},labels{k});
                title(ax{k},labels{k}); grid(ax{k},'on'); xlim(ax{k},[-1 1]);
            end
            app.CalibrationLabel.Text = sprintf('%s | nine levels | same source and analysis settings',app.SourceName);
            app.Tabs.SelectedTab = app.CalibrationTab;
            app.status('Calibration complete. Current audition brightness is preserved.');
        end

        function results = runBatch(app, root)
            results = table();
            if app.Busy, return; end
            if nargin < 2, root = app.LibraryFolder; end
            if ~isfolder(root), error('MusicFeatureLab:Folder','Select an existing music library folder.'); end
            [~,folderInfo]=fileattrib(root);
            root=folderInfo.Name;
            prefix=char(root);
            if ~endsWith(prefix,filesep), prefix=[prefix filesep]; end
            files = dir(fullfile(root,'**','*'));
            files = files(~[files.isdir]);
            keep = false(size(files));
            for k=1:numel(files)
                [~,~,ext]=fileparts(files(k).name);
                keep(k)=ismember(lower(ext),{'.wav','.flac','.mp3','.m4a','.ogg','.aif','.aiff','.au'});
            end
            files=files(keep);
            if isempty(files), error('MusicFeatureLab:NoFiles','No supported audio files were found in this folder.'); end
            app.stopAudio(); app.setBusy(true);
            guard=onCleanup(@()app.setBusy(false));
            app.CancelRequested=false;
            app.CancelBatchButton.Enable='on';
            app.LibraryFolder=char(root);
            app.LastBatchRoot=char(root);
            app.BatchPitchEnabled=app.PitchCheckBox.Value;
            app.LibraryPathLabel.Text=char(root);
            rows=cell(numel(files),1);
            count=0;
            for k=1:numel(files)
                drawnow;
                if app.CancelRequested, break; end
                app.status(sprintf('Analyzing %d / %d: %s',k,numel(files),files(k).name));
                filename=fullfile(files(k).folder,files(k).name);
                relative=extractAfter(string(filename),strlength(string(prefix)));
                parts=split(relative,filesep);
                condition="Ungrouped";
                if numel(parts)>1, condition=parts(1); end
                seedText=regexp(files(k).name,'\d+(?=\.[^.]+$)','match','once');
                seed=str2double(seedText);
                try
                    [x,fs]=audioread(filename);
                    r=MusicAnalysis.analyze(x,fs,app.PitchCheckBox.Value);
                    row=MusicAnalysis.featureTable(r,relative);
                    row.Status="OK";
                catch err
                    blank=struct('duration',NaN,'fs',NaN,'channels',NaN, ...
                        'centroid',NaN,'slope',NaN,'bandwidth',NaN,'hfRatio',NaN, ...
                        'rms',NaN,'pitch',NaN,'flux',NaN,'onsetRate',NaN);
                    row=MusicAnalysis.featureTable(blank,relative);
                    row.Status=string(err.message);
                end
                row.Condition=condition;
                row.Seed=seed;
                count=count+1; rows{count}=row;
            end
            if count>0, results=vertcat(rows{1:count}); end
            app.BatchResults=results;
            app.BatchTable.Data=results;
            app.plotBatch();
            app.Tabs.SelectedTab=app.LibraryTab;
            successful=0;
            if ~isempty(results), successful=sum(results.Status=="OK"); end
            app.status(sprintf('Library analysis finished: %d / %d files, %d successful.', ...
                count,numel(files),successful));
        end

        function exportSession(app, folder)
            if app.Busy, return; end
            app.setBusy(true);
            guard=onCleanup(@()app.setBusy(false));
            if ~isfolder(folder), mkdir(folder); end
            if ~isempty(app.OriginalAudio)
                audiowrite(fullfile(folder,'processed.wav'),app.ProcessedAudio,app.SampleRate,'BitsPerSample',24);
                features=[MusicAnalysis.featureTable(app.OriginalResult,"Original"); ...
                    MusicAnalysis.featureTable(app.ProcessedResult,"Processed")];
                writetable(features,fullfile(folder,'audio_features.csv'));
                exportgraphics(app.WaveAxes,fullfile(folder,'waveform.png'),'Resolution',180);
                exportgraphics(app.SpectrumAxes,fullfile(folder,'spectrum.png'),'Resolution',180);
                exportgraphics(app.SpectrogramAxes,fullfile(folder,'spectrogram.png'),'Resolution',180);
                exportgraphics(app.TrajectoryAxes,fullfile(folder,'feature_trajectory.png'),'Resolution',180);
            end
            if ~isempty(app.CalibrationResults)
                writetable(app.CalibrationResults,fullfile(folder,'calibration.csv'));
                exportgraphics(app.CentroidAxes,fullfile(folder,'calibration_centroid.png'),'Resolution',180);
                exportgraphics(app.SlopeAxes,fullfile(folder,'calibration_slope.png'),'Resolution',180);
                exportgraphics(app.HFAxes,fullfile(folder,'calibration_hf_ratio.png'),'Resolution',180);
            end
            summary=table();
            if ~isempty(app.BatchResults)
                writetable(app.BatchResults,fullfile(folder,'library_features.csv'));
                summary=app.groupSummary();
                if ~isempty(summary), writetable(summary,fullfile(folder,'condition_summary.csv')); end
                exportgraphics(app.BatchAxes,fullfile(folder,'library_comparison.png'),'Resolution',180);
            end
            session=struct('SourcePath',app.SourcePath,'Brightness',app.Brightness, ...
                'PeakScale',app.PeakScale,'SampleRate',app.SampleRate, ...
                'AudioIncludePitch',app.AudioPitchEnabled,'BatchIncludePitch',app.BatchPitchEnabled, ...
                'CalibrationIncludePitch',false,'LibraryRoot',app.LastBatchRoot, ...
                'ExportedAt',char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')), ...
                'Analysis','20 ms Hamming; 4 ms hop; amplitude-weighted centroid; HF >= 4000 Hz', ...
                'DSP','Symmetric whole-file FFT tilt; +/-6 dB at Nyquist; clipping protection');
            calibration=app.CalibrationResults;
            batch=app.BatchResults;
            save(fullfile(folder,'session.mat'),'session','calibration','batch','summary');
            fid=fopen(fullfile(folder,'settings.json'),'w','n','UTF-8');
            if fid<0, error('MusicFeatureLab:Export','Cannot write settings.json.'); end
            fileGuard=onCleanup(@()fclose(fid));
            fprintf(fid,'%s',jsonencode(session,'PrettyPrint',true));
            app.status(['Exported session to ' char(folder)]);
        end

        function summary=groupSummary(app)
            summary=table();
            if isempty(app.BatchResults), return; end
            data=app.BatchResults(app.BatchResults.Status=="OK",:);
            if isempty(data), return; end
            groups=unique(data.Condition,'stable');
            metrics={'Centroid_Hz','Slope_dB_Hz','Bandwidth_Hz','HFRatio','RMS','Pitch_Hz','SpectralFlux','OnsetRate_Hz'};
            summary=table(groups,zeros(numel(groups),1),'VariableNames',{'Condition','Count'});
            for m=1:numel(metrics)
                means=nan(numel(groups),1); deviations=means;
                for k=1:numel(groups)
                    values=data.(metrics{m})(data.Condition==groups(k));
                    values=values(isfinite(values));
                    if ~isempty(values), means(k)=mean(values); deviations(k)=std(values); end
                end
                summary.([metrics{m} '_Mean'])=means;
                summary.([metrics{m} '_SD'])=deviations;
            end
            for k=1:numel(groups), summary.Count(k)=sum(data.Condition==groups(k)); end
        end

        function stopAudio(app)
            if ~isempty(app.Player)
                try, stop(app.Player); catch, end
                app.Player=[];
            end
        end
    end

    methods (Access = private)
        function status(app,message)
            if isvalid(app.UIFigure), app.StatusLabel.Text=char(message); end
        end

        function enableAudio(app,enabled)
            controls={app.PlayOriginalButton,app.PlayOutputButton,app.SaveAudioButton, ...
                app.BrightnessSlider,app.ResetButton,app.AnalyzeButton,app.RunCalibrationButton};
            value=matlab.lang.OnOffSwitchState(enabled);
            for k=1:numel(controls), controls{k}.Enable=value; end
        end

        function setBusy(app,value)
            app.Busy=value;
            if app.Closing || ~isvalid(app.UIFigure), return; end
            controls={app.LoadButton,app.DemoButton,app.ExportButton,app.ChooseLibraryButton, ...
                app.RunBatchButton,app.GenerateButton,app.PitchCheckBox,app.PreviewSelectedButton, ...
                app.CalibrationExportButton,app.BatchExportButton,app.BatchMetricDropDown};
            for k=1:numel(controls), controls{k}.Enable=matlab.lang.OnOffSwitchState(~value); end
            app.enableAudio(~value && ~isempty(app.OriginalAudio));
            app.CancelBatchButton.Enable='off';
        end

        function renderAudio(app)
            a=app.OriginalResult; b=app.ProcessedResult;
            app.BrightnessValueLabel.Text=sprintf('%+.2f  |  Nyquist %+.1f dB',app.Brightness,6*app.Brightness);
            metrics={'Centroid (Hz)';'Slope (dB/Hz)';'Bandwidth (Hz)';'HF ratio >=4 kHz'; ...
                'RMS (mono)';'Pitch estimate (Hz)';'Spectral flux';'Onsets / second'};
            fields={'centroid','slope','bandwidth','hfRatio','rms','pitch','flux','onsetRate'};
            before=zeros(8,1); after=before;
            for k=1:8, before(k)=a.(fields{k}); after(k)=b.(fields{k}); end
            app.MetricsTable.Data=table(metrics,before,after,after-before, ...
                'VariableNames',{'Feature','Original','Processed','Change'});
            plot(app.WaveAxes,a.tWave,a.xWave,'Color',[.65 .7 .75]);
            hold(app.WaveAxes,'on');
            plot(app.WaveAxes,b.tWave,b.xWave,'Color',[.06 .48 .67]);
            hold(app.WaveAxes,'off');
            title(app.WaveAxes,'Waveform | mono analysis view');
            xlabel(app.WaveAxes,'Time (s)'); ylabel(app.WaveAxes,'Amplitude');
            xlim(app.WaveAxes,[0 max(b.duration,1/app.SampleRate)]);
            legend(app.WaveAxes,{'Original','Processed'},'Location','northeast');
            grid(app.WaveAxes,'on');
            plot(app.SpectrumAxes,a.fSpectrum,a.spectrumDB,'Color',[.65 .7 .75]);
            hold(app.SpectrumAxes,'on');
            plot(app.SpectrumAxes,b.fSpectrum,b.spectrumDB,'Color',[.06 .48 .67]);
            hold(app.SpectrumAxes,'off');
            title(app.SpectrumAxes,'Single-sided FFT spectrum');
            xlabel(app.SpectrumAxes,'Frequency (Hz)'); ylabel(app.SpectrumAxes,'Amplitude (dBFS)');
            xlim(app.SpectrumAxes,[0 app.SampleRate/2]); grid(app.SpectrumAxes,'on');
            legend(app.SpectrumAxes,{'Original','Processed'},'Location','northeast');
            if numel(b.tFrames)==1
                dt=max(1/app.SampleRate,b.duration/2);
                tt=[b.tFrames-dt/2 b.tFrames+dt/2];
                imageData=[b.stftDB b.stftDB];
            else
                tt=b.tFrames; imageData=b.stftDB;
            end
            imagesc(app.SpectrogramAxes,tt,b.fSTFT,imageData);
            app.SpectrogramAxes.YDir='normal';
            xlabel(app.SpectrogramAxes,'Time (s)'); ylabel(app.SpectrogramAxes,'Frequency (Hz)');
            title(app.SpectrogramAxes,'Processed STFT | dBFS');
            ylim(app.SpectrogramAxes,[0 app.SampleRate/2]);
            xlim(app.SpectrogramAxes,[0 max(b.duration,1/app.SampleRate)]);
            colormap(app.SpectrogramAxes,'turbo');
            peak=max(imageData(:)); clim(app.SpectrogramAxes,[peak-80 max(peak,peak-79)]);
            app.renderTrajectory();
        end

        function renderTrajectory(app)
            if isempty(app.OriginalResult), return; end
            % Onset markers are hidden from legends; reset removes them too
            % when changing to another feature view.
            cla(app.TrajectoryAxes,'reset');
            feature=app.FeatureDropDown.Value;
            names={'Centroid','Slope','Bandwidth','HF ratio','RMS','Spectral flux','Pitch'};
            fields={'centroidSeries','slopeSeries','bandwidthSeries','hfRatioSeries','rmsSeries','fluxSeries','pitchSeries'};
            selected=find(strcmp(names,feature),1);
            field=fields{selected};
            a=app.OriginalResult; b=app.ProcessedResult;
            if strcmp(feature,'Pitch'), ta=a.pitchTimes; tb=b.pitchTimes;
            else, ta=a.tFrames; tb=b.tFrames; end
            plot(app.TrajectoryAxes,ta,a.(field),'Color',[.65 .7 .75]);
            hold(app.TrajectoryAxes,'on');
            plot(app.TrajectoryAxes,tb,b.(field),'Color',[.06 .48 .67]);
            if strcmp(feature,'Spectral flux')
                for t=b.onsetTimes(:)'
                    xline(app.TrajectoryAxes,t,':','Color',[.85 .45 .17],'HandleVisibility','off');
                end
            end
            hold(app.TrajectoryAxes,'off');
            title(app.TrajectoryAxes,[feature ' over time']);
            xlabel(app.TrajectoryAxes,'Time (s)'); grid(app.TrajectoryAxes,'on');
            units={'Hz','dB/Hz','Hz','Ratio','Amplitude','Amplitude change','Hz'};
            ylabel(app.TrajectoryAxes,units{selected});
        end

        function plotBatch(app)
            cla(app.BatchAxes);
            if isempty(app.BatchResults), return; end
            data=app.BatchResults(app.BatchResults.Status=="OK",:);
            if isempty(data), return; end
            metric=app.BatchMetricDropDown.Value;
            summary=app.groupSummary();
            groups=summary.Condition;
            means=summary.([metric '_Mean']); sd=summary.([metric '_SD']);
            colors=lines(numel(groups));
            hold(app.BatchAxes,'on');
            for k=1:numel(groups)
                values=data.(metric)(data.Condition==groups(k));
                offsets=linspace(-.16,.16,numel(values));
                scatter(app.BatchAxes,k+offsets,values,35,colors(k,:),'filled','HandleVisibility','off');
            end
            errorbar(app.BatchAxes,1:numel(groups),means,sd,'kd','LineStyle','none', ...
                'LineWidth',1.7,'MarkerFaceColor','k','DisplayName','Mean +/- SD');
            hold(app.BatchAxes,'off');
            app.BatchAxes.XTick=1:numel(groups); app.BatchAxes.XTickLabel=cellstr(groups);
            xlim(app.BatchAxes,[.5 numel(groups)+.5]);
            title(app.BatchAxes,[strrep(metric,'_',' ') ' | individual files and group means']);
            ylabel(app.BatchAxes,strrep(metric,'_',' ')); grid(app.BatchAxes,'on');
            app.BatchNoteLabel.Text=sprintf('%d files | groups follow subfolder names | dots: files, diamonds: mean +/- SD | no significance test',height(data));
        end

        function playAudio(app,which)
            if app.Busy || isempty(app.OriginalAudio), return; end
            app.stopAudio();
            if strcmp(which,'original'), x=app.OriginalAudio; else, x=app.ProcessedAudio; end
            app.Player=audioplayer(x,app.SampleRate);
            play(app.Player);
            app.status(['Playing ' which ': ' app.SourceName]);
        end

        function reportError(app,err)
            if isvalid(app.UIFigure)
                app.status(['Error: ' err.message]);
                uialert(app.UIFigure,err.message,'Music Feature Lab');
            end
        end
    end
    % END APP LOGIC

    % BEGIN APP CALLBACKS
    methods (Access = private)
        function startupFcn(app)
            app.AppFolder=fileparts(mfilename('fullpath'));
            [~,folderName]=fileparts(app.AppFolder);
            if strcmpi(folderName,'source')
                app.AppFolder=fileparts(app.AppFolder);
            end
            addpath(app.AppFolder);
            app.LibraryFolder=fullfile(app.AppFolder,'data','music library');
            app.LibraryPathLabel.Text=app.LibraryFolder;
            app.enableAudio(false);
            demo=fullfile(app.AppFolder,'demo.wav');
            try
                if isfile(demo), app.loadAudio(demo);
                else, app.status('Import audio, or generate an FM demo to begin.'); end
            catch err, app.reportError(err); end
        end

        function onLoad(app,event)
            [file,folder]=uigetfile({'*.wav;*.flac;*.mp3;*.m4a;*.ogg;*.aif;*.aiff','Audio files';'*.*','All files'},'Import audio');
            if isequal(file,0), return; end
            try, app.loadAudio(fullfile(folder,file)); catch err, app.reportError(err); end
        end
        function onDemo(app,event)
            try, app.loadAudio(fullfile(app.AppFolder,'demo.wav')); catch err, app.reportError(err); end
        end
        function onPlayOriginal(app,event)
            try, app.playAudio('original'); catch err, app.reportError(err); end
        end
        function onPlayOutput(app,event)
            try, app.playAudio('processed'); catch err, app.reportError(err); end
        end
        function onStop(app,event)
            app.stopAudio(); app.status('Playback stopped.');
        end
        function onBrightness(app,event)
            try, app.applyBrightness(app.BrightnessSlider.Value); catch err, app.reportError(err); end
        end
        function onReset(app,event)
            try, app.applyBrightness(0); catch err, app.reportError(err); end
        end
        function onAnalyze(app,event)
            if app.Busy, return; end
            app.setBusy(true);
            guard=onCleanup(@()app.setBusy(false));
            try
                if isempty(app.OriginalAudio), return; end
                app.OriginalResult=MusicAnalysis.analyze(app.OriginalAudio,app.SampleRate,app.PitchCheckBox.Value);
                app.ProcessedResult=MusicAnalysis.analyze(app.ProcessedAudio,app.SampleRate,app.PitchCheckBox.Value);
                app.AudioPitchEnabled=app.PitchCheckBox.Value;
                app.renderAudio(); app.status(['Analysis refreshed. ' app.ProcessedResult.note]);
            catch err, app.reportError(err); end
        end
        function onFeature(app,event)
            try, app.renderTrajectory(); catch err, app.reportError(err); end
        end
        function onCalibration(app,event)
            try, app.runCalibration(); catch err, app.reportError(err); end
        end
        function onSaveAudio(app,event)
            if isempty(app.ProcessedAudio), return; end
            [file,folder]=uiputfile('*.wav','Save processed audio','processed.wav');
            if isequal(file,0), return; end
            try
                audiowrite(fullfile(folder,file),app.ProcessedAudio,app.SampleRate,'BitsPerSample',24);
                app.status(['Saved ' fullfile(folder,file)]);
            catch err, app.reportError(err); end
        end
        function onExport(app,event)
            root=uigetdir(app.AppFolder,'Choose parent folder for a new session export');
            if isequal(root,0), return; end
            folder=fullfile(root,['MusicLab_' char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))]);
            try, app.exportSession(folder); catch err, app.reportError(err); end
        end
        function onChooseLibrary(app,event)
            root=uigetdir(app.LibraryFolder,'Select a music library folder');
            if isequal(root,0), return; end
            app.LibraryFolder=root; app.LibraryPathLabel.Text=root;
        end
        function onBatch(app,event)
            try, app.runBatch(); catch err, app.reportError(err); end
        end
        function onCancelBatch(app,event)
            app.CancelRequested=true;
            app.status('Stopping after the current file...');
        end
        function onBatchMetric(app,event)
            try, app.plotBatch(); catch err, app.reportError(err); end
        end
        function onPreviewSelected(app,event)
            if isempty(app.BatchResults), return; end
            selection=app.BatchTable.Selection;
            if isempty(selection), app.status('Select a row in the library table first.'); return; end
            row=selection(1,1);
            if row>height(app.BatchResults), return; end
            try
                app.loadAudio(fullfile(app.LastBatchRoot,char(app.BatchResults.Source(row))));
                app.Tabs.SelectedTab=app.AudioTab;
            catch err, app.reportError(err); end
        end
        function onGenerate(app,event)
            if app.Busy, return; end
            try
                fs=44100;
                x=MusicAnalysis.synthesize(app.CarrierField.Value,app.ModulatorField.Value, ...
                    app.IndexField.Value,app.DurationField.Value,fs);
                r=MusicAnalysis.analyze(x,fs,app.PitchCheckBox.Value);
                app.stopAudio();
                app.OriginalAudio=x; app.ProcessedAudio=x; app.SampleRate=fs;
                app.OriginalResult=r; app.ProcessedResult=r;
                app.AudioPitchEnabled=app.PitchCheckBox.Value;
                app.SourceName='FM synthetic tone'; app.SourcePath='';
                app.Brightness=0; app.PeakScale=1; app.BrightnessSlider.Value=0;
                app.CalibrationResults=table(); app.CalibrationTable.Data=table();
                app.CalibrationLabel.Text='Run a sweep on the current source to compare nine brightness levels.';
                cla(app.CentroidAxes); cla(app.SlopeAxes); cla(app.HFAxes);
                app.FileLabel.Text=sprintf('FM tone | %.2f s | 44100 Hz | mono',r.duration);
                plot(app.SynthAxes,r.fSpectrum,r.spectrumDB,'Color',[.06 .48 .67]);
                title(app.SynthAxes,'Generated FM spectrum');
                xlabel(app.SynthAxes,'Frequency (Hz)'); ylabel(app.SynthAxes,'Amplitude (dBFS)');
                xlim(app.SynthAxes,[0 10000]); grid(app.SynthAxes,'on');
                app.enableAudio(true); app.renderAudio();
                app.status('FM tone generated. Use Audio Workbench to audition and change brightness.');
            catch err, app.reportError(err); end
        end
        function onClose(app,event)
            if app.Busy
                app.CancelRequested=true;
                app.status('Cancel requested. Close again after the current task finishes.');
                return;
            end
            app.stopAudio();
            app.Closing=true;
            delete(app);
        end
    end
    % END APP CALLBACKS

    methods (Access = private)
        function createComponents(app)
            app.UIFigure=uifigure('Visible','off','Name','Music Feature Lab | ELEC5305', ...
                'Position',[70 60 1400 880],'Color',[.96 .97 .98]);
            app.UIFigure.CloseRequestFcn=@(src,event)app.onClose(event);
            app.MainGrid=uigridlayout(app.UIFigure,[6 1]);
            app.MainGrid.RowHeight={36,24,38,24,'1x',28};
            app.MainGrid.Padding=[20 14 20 12]; app.MainGrid.RowSpacing=7;
            app.HeaderLabel=uilabel(app.MainGrid,'Text','MUSIC FEATURE LAB', ...
                'FontSize',25,'FontWeight','bold','FontColor',[.08 .20 .29]);
            app.SubtitleLabel=uilabel(app.MainGrid,'Text', ...
                'ELEC5305  /  Explore timbre, measure brightness, compare music.', ...
                'FontSize',13,'FontColor',[.35 .41 .47]);
            app.Toolbar=uigridlayout(app.MainGrid,[1 7]);
            app.Toolbar.Padding=[0 0 0 0]; app.Toolbar.ColumnWidth={'1x','1x','1x','1x',75,'1x','1x'};
            app.LoadButton=uibutton(app.Toolbar,'Text','Import audio','ButtonPushedFcn',@(src,event)app.onLoad(event));
            app.DemoButton=uibutton(app.Toolbar,'Text','Load demo','ButtonPushedFcn',@(src,event)app.onDemo(event));
            app.PlayOriginalButton=uibutton(app.Toolbar,'Text','Play original','ButtonPushedFcn',@(src,event)app.onPlayOriginal(event));
            app.PlayOutputButton=uibutton(app.Toolbar,'Text','Play processed','ButtonPushedFcn',@(src,event)app.onPlayOutput(event));
            app.StopButton=uibutton(app.Toolbar,'Text','Stop','ButtonPushedFcn',@(src,event)app.onStop(event));
            app.SaveAudioButton=uibutton(app.Toolbar,'Text','Save WAV','ButtonPushedFcn',@(src,event)app.onSaveAudio(event));
            app.ExportButton=uibutton(app.Toolbar,'Text','Export session','ButtonPushedFcn',@(src,event)app.onExport(event));
            app.LoadButton.BackgroundColor=[.10 .43 .60]; app.LoadButton.FontColor=[1 1 1];
            app.FileLabel=uilabel(app.MainGrid,'Text','Import an audio file to begin.','FontColor',[.25 .34 .40]);
            app.Tabs=uitabgroup(app.MainGrid);
            app.AudioTab=uitab(app.Tabs,'Title','Audio Workbench');
            app.AudioGrid=uigridlayout(app.AudioTab,[1 2]);
            app.AudioGrid.ColumnWidth={400,'1x'}; app.AudioGrid.Padding=[10 10 10 10];
            app.ControlsPanel=uipanel(app.AudioGrid,'Title','Brightness & measurements','BackgroundColor',[1 1 1]);
            app.ControlsGrid=uigridlayout(app.ControlsPanel,[9 1]);
            app.ControlsGrid.RowHeight={25,55,24,30,26,30,78,'1x',26};
            app.ControlsGrid.Padding=[14 10 14 10];
            app.BrightnessLabel=uilabel(app.ControlsGrid,'Text','Darker                      Neutral                      Brighter','FontWeight','bold');
            app.BrightnessSlider=uislider(app.ControlsGrid,'Limits',[-1 1],'Value',0, ...
                'MajorTicks',[-1 -.5 0 .5 1],'ValueChangedFcn',@(src,event)app.onBrightness(event));
            app.BrightnessValueLabel=uilabel(app.ControlsGrid,'Text','+0.00 | Nyquist +0.0 dB','HorizontalAlignment','center');
            app.ResetButton=uibutton(app.ControlsGrid,'Text','Reset to original (0)','ButtonPushedFcn',@(src,event)app.onReset(event));
            app.PitchCheckBox=uicheckbox(app.ControlsGrid,'Text','Include pitch estimate (Audio Toolbox)','Value',false, ...
                'ValueChangedFcn',@(src,event)app.onAnalyze(event));
            app.AnalyzeButton=uibutton(app.ControlsGrid,'Text','Refresh analysis','ButtonPushedFcn',@(src,event)app.onAnalyze(event));
            app.HelpLabel=uilabel(app.ControlsGrid,'Text',sprintf(['Release the slider to process the full clip.\n' ...
                'Stereo is preserved for playback and export.\nPlots and metrics use the mono channel average.\n' ...
                'Clipping protection may lower the output level.']),'WordWrap','on','FontColor',[.4 .44 .48]);
            app.MetricsTable=uitable(app.ControlsGrid,'RowName',{},'ColumnEditable',false, ...
                'ColumnName',{'Feature','Original','Processed','Change'},'ColumnWidth',{138,72,72,65});
            app.FeatureDropDown=uidropdown(app.ControlsGrid, ...
                'Items',{'Centroid','Slope','Bandwidth','HF ratio','RMS','Spectral flux','Pitch'}, ...
                'ValueChangedFcn',@(src,event)app.onFeature(event));
            app.PlotGrid=uigridlayout(app.AudioGrid,[2 2]);
            app.PlotGrid.Padding=[0 0 0 0];
            app.WaveAxes=uiaxes(app.PlotGrid); title(app.WaveAxes,'Waveform');
            app.SpectrumAxes=uiaxes(app.PlotGrid); title(app.SpectrumAxes,'FFT spectrum');
            app.SpectrogramAxes=uiaxes(app.PlotGrid); title(app.SpectrogramAxes,'STFT');
            app.TrajectoryAxes=uiaxes(app.PlotGrid); title(app.TrajectoryAxes,'Feature trajectory');

            app.CalibrationTab=uitab(app.Tabs,'Title','Brightness Experiment');
            app.CalibrationGrid=uigridlayout(app.CalibrationTab,[4 1]);
            app.CalibrationGrid.RowHeight={38,25,'1x',220};
            app.CalibrationToolbar=uigridlayout(app.CalibrationGrid,[1 2]);
            app.CalibrationToolbar.Padding=[0 0 0 0]; app.CalibrationToolbar.ColumnWidth={250,190};
            app.RunCalibrationButton=uibutton(app.CalibrationToolbar,'Text','Run 9-level brightness experiment', ...
                'ButtonPushedFcn',@(src,event)app.onCalibration(event));
            app.CalibrationExportButton=uibutton(app.CalibrationToolbar,'Text','Export session & figures', ...
                'ButtonPushedFcn',@(src,event)app.onExport(event));
            app.CalibrationLabel=uilabel(app.CalibrationGrid,'Text','Load audio, then run a reproducible sweep from -1 to +1.');
            app.CalibrationPlotGrid=uigridlayout(app.CalibrationGrid,[1 3]);
            app.CentroidAxes=uiaxes(app.CalibrationPlotGrid); title(app.CentroidAxes,'Centroid (Hz)');
            app.SlopeAxes=uiaxes(app.CalibrationPlotGrid); title(app.SlopeAxes,'Slope (dB/Hz)');
            app.HFAxes=uiaxes(app.CalibrationPlotGrid); title(app.HFAxes,'HF energy ratio');
            app.CalibrationTable=uitable(app.CalibrationGrid,'RowName',{},'ColumnEditable',false);

            app.LibraryTab=uitab(app.Tabs,'Title','Music Library');
            app.LibraryGrid=uigridlayout(app.LibraryTab,[6 1]);
            app.LibraryGrid.RowHeight={36,25,30,'1x',230,25};
            app.LibraryToolbar=uigridlayout(app.LibraryGrid,[1 5]);
            app.LibraryToolbar.Padding=[0 0 0 0]; app.LibraryToolbar.ColumnWidth={180,180,170,180,100};
            app.ChooseLibraryButton=uibutton(app.LibraryToolbar,'Text','Choose library folder','ButtonPushedFcn',@(src,event)app.onChooseLibrary(event));
            app.RunBatchButton=uibutton(app.LibraryToolbar,'Text','Analyze library','ButtonPushedFcn',@(src,event)app.onBatch(event));
            app.PreviewSelectedButton=uibutton(app.LibraryToolbar,'Text','Load selected file','ButtonPushedFcn',@(src,event)app.onPreviewSelected(event));
            app.BatchExportButton=uibutton(app.LibraryToolbar,'Text','Export session & tables','ButtonPushedFcn',@(src,event)app.onExport(event));
            app.CancelBatchButton=uibutton(app.LibraryToolbar,'Text','Cancel','Enable','off','ButtonPushedFcn',@(src,event)app.onCancelBatch(event));
            app.LibraryPathLabel=uilabel(app.LibraryGrid,'Text','Choose a library folder.');
            app.BatchMetricDropDown=uidropdown(app.LibraryGrid, ...
                'Items',{'Centroid (Hz)','Slope (dB/Hz)','Bandwidth (Hz)','HF ratio','RMS','Pitch (Hz)','Spectral flux','Onset rate'}, ...
                'ItemsData',{'Centroid_Hz','Slope_dB_Hz','Bandwidth_Hz','HFRatio','RMS','Pitch_Hz','SpectralFlux','OnsetRate_Hz'}, ...
                'ValueChangedFcn',@(src,event)app.onBatchMetric(event));
            app.BatchAxes=uiaxes(app.LibraryGrid); title(app.BatchAxes,'Analyze the library to compare conditions');
            app.BatchTable=uitable(app.LibraryGrid,'RowName',{},'ColumnEditable',false,'SelectionType','row');
            app.BatchNoteLabel=uilabel(app.LibraryGrid,'Text','Includes existing Dark / Neutral / Bright recordings. Audio is analyzed locally.','FontColor',[.4 .44 .48]);

            app.SynthTab=uitab(app.Tabs,'Title','FM Synth & Methods');
            app.SynthGrid=uigridlayout(app.SynthTab,[2 2]);
            app.SynthGrid.RowHeight={'1x',220}; app.SynthGrid.ColumnWidth={360,'1x'};
            app.SynthControls=uipanel(app.SynthGrid,'Title','Generate a test tone');
            app.SynthControlGrid=uigridlayout(app.SynthControls,[6 2]);
            app.SynthControlGrid.RowHeight={34,34,34,34,38,'1x'};
            app.CarrierLabel=uilabel(app.SynthControlGrid,'Text','Carrier frequency (Hz)');
            app.CarrierField=uieditfield(app.SynthControlGrid,'numeric','Limits',[20 4000],'Value',440);
            app.ModulatorLabel=uilabel(app.SynthControlGrid,'Text','Modulator frequency (Hz)');
            app.ModulatorField=uieditfield(app.SynthControlGrid,'numeric','Limits',[1 1000],'Value',110);
            app.IndexLabel=uilabel(app.SynthControlGrid,'Text','Modulation index');
            app.IndexField=uieditfield(app.SynthControlGrid,'numeric','Limits',[0 10],'Value',2);
            app.DurationLabel=uilabel(app.SynthControlGrid,'Text','Duration (seconds)');
            app.DurationField=uieditfield(app.SynthControlGrid,'numeric','Limits',[.1 30],'Value',3);
            app.GenerateButton=uibutton(app.SynthControlGrid,'Text','Generate & load tone','ButtonPushedFcn',@(src,event)app.onGenerate(event));
            app.GenerateButton.Layout.Column=[1 2];
            app.SynthHelpLabel=uilabel(app.SynthControlGrid,'WordWrap','on','Text', ...
                'Create a repeatable source, then use the Audio Workbench to hear and measure brightness changes.');
            app.SynthHelpLabel.Layout.Column=[1 2];
            app.SynthAxes=uiaxes(app.SynthGrid); title(app.SynthAxes,'FM spectrum');
            app.MethodsText=uitextarea(app.SynthGrid,'Editable','off','Value',{ ...
                'METHODS & INTERPRETATION'; ...
                'STFT: 20 ms Hamming window, 4 ms hop. Spectral means omit silent frames.'; ...
                'Centroid/bandwidth: amplitude weighted. Slope: dB per Hz. HF ratio: energy at or above 4 kHz.'; ...
                'Brightness: symmetric whole-file FFT tilt, -6 to +6 dB at Nyquist; peak protection prevents clipping.'; ...
                'Pitch: optional Audio Toolbox estimate; a music mixture has no single unambiguous fundamental.'; ...
                'Library: groups follow subfolder names; summaries are descriptive mean and sample SD.'; ...
                'This app analyzes existing music locally. Generative AI is a separate source of recordings.'; ...
                'Export: processed WAV, feature CSVs, figure PNGs, settings JSON and a MAT session.'});
            app.MethodsText.Layout.Column=[1 2];
            app.StatusLabel=uilabel(app.MainGrid,'Text','Ready','FontColor',[.15 .36 .44],'WordWrap','on');
            app.UIFigure.Visible='on';
        end
    end

    methods (Access = public)
        function app=MusicFeatureLabApp(varargin)
            app.createComponents();
            registerApp(app,app.UIFigure);
            if nargin==0 || ~strcmp(varargin{1},'DesignMode')
                runStartupFcn(app,@startupFcn);
            end
            if nargout==0, clear app; end
        end
        function delete(app)
            app.Closing=true;
            app.stopAudio();
            if ~isempty(app.UIFigure) && isvalid(app.UIFigure), delete(app.UIFigure); end
        end
    end
end
