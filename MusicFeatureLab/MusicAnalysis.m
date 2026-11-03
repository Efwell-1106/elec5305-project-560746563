classdef MusicAnalysis
    %MUSICANALYSIS Shared, toolbox-independent analysis and brightness DSP.
    % All summaries and plots use the same 20 ms symmetric Hamming window,
    % 4 ms hop and single-sided amplitude spectrum. Analysis averages stereo
    % to mono; brightness processing preserves every original channel.
    methods (Static)
        function result = analyze(x, fs, includePitch)
            if nargin < 3
                includePitch = false;
            end
            [x, fs] = MusicAnalysis.validateAudio(x, fs);
            validateattributes(includePitch, {'logical','numeric'}, ...
                {'scalar','real','finite'}, mfilename, 'includePitch');
            channels = size(x, 2);
            mono = mean(x, 2);
            n = size(x, 1);
            notes = {};
            if channels > 1 && max(abs(x(:))) > 1e-12 && ...
                    max(abs(mono)) < max(abs(x(:)))*1e-6
                notes{end+1} = ['The channels cancel in the mono analysis mix. ' ...
                    'Brightness processing and playback preserve the original channels.'];
            end

            windowLength = max(2, round(0.020 * fs));
            hopLength = max(1, round(0.004 * fs));
            window = 0.54 - 0.46 * cos(2*pi*(0:windowLength-1)' / (windowLength-1));
            nfft = 2^nextpow2(windowLength);
            frequencies = (0:floor(nfft/2))' * fs / nfft;
            if n < windowLength
                analysisAudio = [mono; zeros(windowLength-n,1)];
                starts = 1;
                notes{end+1} = 'The short clip was zero-padded for one analysis frame.';
            else
                analysisAudio = mono;
                starts = 1:hopLength:(n-windowLength+1);
            end
            frameCount = numel(starts);
            times = ((starts-1) + (windowLength-1)/2) / fs;
            if n < windowLength
                times = (n-1) / (2*fs);
            end
            % Full summaries use every frame. Only plot arrays are sampled.
            displayFrames = unique(round(linspace(1, frameCount, min(1800, frameCount))));
            displayLookup = zeros(1,frameCount);
            displayLookup(displayFrames) = 1:numel(displayFrames);
            stftDB = zeros(numel(frequencies), numel(displayFrames));
            centroid = zeros(1,frameCount);
            slope = zeros(1,frameCount);
            bandwidth = zeros(1,frameCount);
            hfRatio = zeros(1,frameCount);
            frameRMS = zeros(1,frameCount);
            flux = zeros(1,frameCount);
            previousMagnitude = [];
            highFrequencyBins = frequencies >= 4000;
            centredFrequency = frequencies - mean(frequencies);
            slopeDenominator = sum(centredFrequency.^2);
            amplitudeScale = ones(numel(frequencies),1) / sum(window);
            if numel(amplitudeScale) > 2
                amplitudeScale(2:end-1) = 2*amplitudeScale(2:end-1);
            end

            for first = 1:256:frameCount
                indices = first:min(first+255,frameCount);
                sampleIndices = (0:windowLength-1)' + starts(indices);
                frames = analysisAudio(sampleIndices);
                frameRMS(indices) = sqrt(mean(frames.^2,1));
                transformed = fft(frames .* window,nfft,1);
                magnitude = abs(transformed(1:numel(frequencies),:)) .* amplitudeScale;
                totalMagnitude = sum(magnitude,1);
                safeMagnitude = max(totalMagnitude,realmin);
                centroid(indices) = sum(frequencies .* magnitude,1) ./ safeMagnitude;
                offsets = frequencies - centroid(indices);
                bandwidth(indices) = sqrt(sum(offsets.^2 .* magnitude,1) ./ safeMagnitude);
                power = magnitude.^2;
                hfRatio(indices) = sum(power(highFrequencyBins,:),1) ./ max(sum(power,1),realmin);
                % A relative floor keeps the slope invariant to overall gain.
                floorValue = max(max(magnitude,[],1)*1e-12,realmin);
                db = 20*log10(max(magnitude,floorValue));
                slope(indices) = sum(centredFrequency .* db,1) / slopeDenominator;
                if isempty(previousMagnitude)
                    differences = [zeros(size(magnitude,1),1), diff(magnitude,1,2)];
                else
                    differences = diff([previousMagnitude,magnitude],1,2);
                end
                flux(indices) = sum(max(differences,0),1);
                previousMagnitude = magnitude(:,end);
                selected = displayLookup(indices) > 0;
                stftDB(:,displayLookup(indices(selected))) = ...
                    20*log10(max(magnitude(:,selected),1e-12));
            end

            active = frameRMS > max(1e-12, max(frameRMS)*1e-6);
            centroid(~active) = 0;
            slope(~active) = 0;
            bandwidth(~active) = 0;
            hfRatio(~active) = 0;
            if any(active)
                meanCentroid = mean(centroid(active));
                meanSlope = mean(slope(active));
                meanBandwidth = mean(bandwidth(active));
                meanHFRatio = mean(hfRatio(active));
            else
                meanCentroid = 0;
                meanSlope = 0;
                meanBandwidth = 0;
                meanHFRatio = 0;
                notes{end+1} = 'No active audio frames; spectral summary values are zero.';
            end
            if fs/2 < 4000
                notes{end+1} = 'The 4 kHz HF boundary is above Nyquist; HF ratio is zero.';
            end

            onsetThreshold = mean(flux) + 1.5*std(flux);
            candidates = find(flux > onsetThreshold);
            onsetEvents = false(1,frameCount);
            minimumDistance = max(1,round(0.05*fs/hopLength));
            lastOnset = -Inf;
            for k = candidates
                left = max(1,k-1);
                right = min(frameCount,k+1);
                if flux(k) >= max(flux(left:right)) && k-lastOnset >= minimumDistance
                    onsetEvents(k) = true;
                    lastOnset = k;
                end
            end

            pitchValue = NaN;
            pitchTimes = zeros(0,1);
            pitchSeries = zeros(0,1);
            if logical(includePitch) && any(active)
                if exist('pitch','file') ~= 0 && fs > 120
                    pitchWindow = max(2,round(0.080*fs));
                    if n >= pitchWindow
                        try
                            [pitchSeries,pitchLocations] = pitch(mono,fs, ...
                                'Method','NCF','Range',[50 min(1000,fs/2-1)], ...
                                'WindowLength',pitchWindow, ...
                                'OverlapLength',round(0.060*fs));
                            pitchSeries = pitchSeries(:);
                            % pitch() returns sample locations at window ends.
                            % Convert them to frame-centre times in seconds.
                            pitchTimes = (pitchLocations(:)-(pitchWindow+1)/2)/fs;
                            if numel(times) > 1
                                pitchActivity = interp1(times,frameRMS,pitchTimes,'nearest','extrap');
                            else
                                pitchActivity = repmat(frameRMS(1),size(pitchTimes));
                            end
                            valid = isfinite(pitchSeries) & pitchSeries>0 & ...
                                pitchActivity>max(1e-12,max(frameRMS)*1e-6);
                            pitchSeries(~valid) = NaN;
                            if any(valid)
                                pitchValue = mean(pitchSeries(valid));
                            end
                            notes{end+1} = 'Pitch is a monophonic estimate and can be unreliable for polyphonic music.';
                        catch exception
                            pitchTimes = zeros(0,1);
                            pitchSeries = zeros(0,1);
                            notes{end+1} = ['Pitch unavailable: ' exception.message];
                        end
                    else
                        notes{end+1} = 'Pitch unavailable: the clip is shorter than the 80 ms pitch window.';
                    end
                else
                    notes{end+1} = 'Pitch unavailable: Audio Toolbox pitch() is missing or the sample rate is too low.';
                end
            elseif ~logical(includePitch)
                notes{end+1} = 'Pitch estimation is disabled (enable it to use Audio Toolbox pitch).';
            else
                notes{end+1} = 'Pitch is undefined for silent audio.';
            end

            transformed = fft(mono);
            spectrum = abs(transformed(1:floor(n/2)+1))/n;
            if rem(n,2) == 0
                spectrum(2:end-1) = 2*spectrum(2:end-1);
            else
                spectrum(2:end) = 2*spectrum(2:end);
            end
            % Pool spectral peaks instead of skipping FFT bins: simple
            % subsampling can make narrow tones disappear from long clips.
            if numel(spectrum) > 10000
                groupSize = ceil(numel(spectrum)/10000);
                groupCount = ceil(numel(spectrum)/groupSize);
                padded = [spectrum; -Inf(groupSize*groupCount-numel(spectrum),1)];
                [~,localIndices] = max(reshape(padded,groupSize,groupCount),[],1);
                spectrumIndices = localIndices + (0:groupCount-1)*groupSize;
            else
                spectrumIndices = 1:numel(spectrum);
            end
            waveIndices = unique(round(linspace(1,n,min(20000,n))));

            result = struct('duration',n/fs,'fs',fs,'channels',channels, ...
                'centroid',meanCentroid,'slope',meanSlope,'bandwidth',meanBandwidth, ...
                'hfRatio',meanHFRatio,'rms',sqrt(mean(mono.^2)),'pitch',pitchValue, ...
                'flux',mean(flux),'onsetRate',sum(onsetEvents)/(n/fs), ...
                'tWave',(waveIndices(:)-1)/fs,'xWave',mono(waveIndices), ...
                'fSpectrum',(spectrumIndices(:)-1)*fs/n, ...
                'spectrumDB',20*log10(max(spectrum(spectrumIndices),1e-12)), ...
                'tFrames',times(displayFrames),'fSTFT',frequencies,'stftDB',stftDB, ...
                'centroidSeries',centroid(displayFrames),'slopeSeries',slope(displayFrames), ...
                'bandwidthSeries',bandwidth(displayFrames),'hfRatioSeries',hfRatio(displayFrames), ...
                'rmsSeries',frameRMS(displayFrames),'fluxSeries',flux(displayFrames), ...
                'onsetTimes',times(onsetEvents),'pitchTimes',pitchTimes, ...
                'pitchSeries',pitchSeries,'note',strjoin(notes,newline));
        end

        function [y,info] = brightness(x,fs,b)
            wasRow = isrow(x);
            [x,fs] = MusicAnalysis.validateAudio(x,fs); %#ok<ASGLU>
            validateattributes(b,{'numeric'},{'scalar','real','finite','>=',-1,'<=',1}, ...
                mfilename,'b');
            if b == 0
                y = x;
            else
                n = size(x,1);
                bins = (0:n-1)';
                foldedFrequency = min(bins,n-bins)/(n/2);
                gain = 10.^((6*b*foldedFrequency)/20);
                % Mirrored gains preserve conjugate symmetry for odd/even N.
                y = real(ifft(fft(x,[],1).*gain,[],1));
            end
            peak = max(abs(y(:)));
            peakScale = 1;
            if peak > 1
                peakScale = 1/peak;
                y = y*peakScale;
            end
            info = struct('gainDB',6*b,'peakScale',peakScale, ...
                'inputPeak',max(abs(x(:))),'outputPeak',max(abs(y(:))));
            if wasRow
                y = y.';
            end
        end

        function output = featureTable(result,label)
            if nargin < 2
                label = "Audio";
            end
            output = table(string(label),result.duration,result.fs,result.channels, ...
                result.centroid,result.slope,result.bandwidth,result.hfRatio, ...
                result.rms,result.pitch,result.flux,result.onsetRate, ...
                'VariableNames',{'Source','Duration_s','SampleRate_Hz','Channels', ...
                'Centroid_Hz','Slope_dB_Hz','Bandwidth_Hz','HFRatio','RMS', ...
                'Pitch_Hz','SpectralFlux','OnsetRate_Hz'});
        end

        function y = synthesize(fc,fm,index,duration,fs)
            validateattributes(fs,{'numeric'},{'scalar','real','finite','positive'},mfilename,'fs');
            validateattributes(fc,{'numeric'},{'scalar','real','finite','positive','<',fs/2},mfilename,'fc');
            validateattributes(fm,{'numeric'},{'scalar','real','finite','nonnegative','<',fs/2},mfilename,'fm');
            validateattributes(index,{'numeric'},{'scalar','real','finite','nonnegative'},mfilename,'index');
            validateattributes(duration,{'numeric'},{'scalar','real','finite','positive','<=',30},mfilename,'duration');
            n = max(1,round(duration*fs));
            t = (0:n-1)'/fs;
            y = 0.45*exp(-3*t/duration).*sin(2*pi*fc*t+index*sin(2*pi*fm*t));
            fadeLength = min(floor(n/2),round(0.010*fs));
            if fadeLength > 1
                fade = linspace(0,1,fadeLength)';
                y(1:fadeLength) = y(1:fadeLength).*fade;
                y(end-fadeLength+1:end) = y(end-fadeLength+1:end).*flipud(fade);
            end
        end

        function output = calibration(x,fs,levels)
            [x,fs] = MusicAnalysis.validateAudio(x,fs);
            if nargin < 3
                levels = -1:0.25:1;
            end
            validateattributes(levels,{'numeric'},{'vector','nonempty','real','finite','>=',-1,'<=',1}, ...
                mfilename,'levels');
            rows = cell(numel(levels),1);
            for k = 1:numel(levels)
                y = MusicAnalysis.brightness(x,fs,levels(k));
                result = MusicAnalysis.analyze(y,fs,false);
                rows{k} = [table(levels(k),'VariableNames',{'Brightness'}), ...
                    MusicAnalysis.featureTable(result,sprintf('Brightness %+.2f',levels(k)))];
            end
            output = vertcat(rows{:});
        end
    end

    methods (Static, Access = private)
        function [x,fs] = validateAudio(x,fs)
            validateattributes(x,{'numeric'},{'2d','nonempty','real','finite'},mfilename,'x');
            validateattributes(fs,{'numeric'},{'scalar','real','finite','positive'},mfilename,'fs');
            if isvector(x)
                x = x(:);
            end
            x = double(x);
            fs = double(fs);
        end
    end
end
