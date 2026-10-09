clear;
clc;
close all;


%% =========================================================
%  Load Audio
%  =========================================================

filename = "test.wav";

[x, Fs] = audioread(filename);

% Convert stereo to mono
if size(x,2) > 1
    x = mean(x,2);
end

duration = length(x) / Fs;

t = (0:length(x)-1) / Fs;


%% =========================================================
%  FFT
%  =========================================================

N = length(x);

X = fft(x);

f = (0:floor(N/2)) * Fs / N;

magnitude = abs(X(1:length(f)));

magnitude_dB = 20 * log10(magnitude + eps);


%% =========================================================
%  STFT
%  =========================================================

windowLength = round(0.020 * Fs);

hopLength = round(0.004 * Fs);

overlapLength = windowLength - hopLength;

[S,F,T] = spectrogram( ...
    x, ...
    hamming(windowLength), ...
    overlapLength, ...
    [], ...
    Fs);

stftMagnitude = abs(S);

S_dB = 20 * log10(stftMagnitude + eps);


%% =========================================================
%  Spectral Centroid
%  =========================================================

spectralCentroid = ...
    sum(F .* stftMagnitude, 1) ./ ...
    (sum(stftMagnitude, 1) + eps);

meanSpectralCentroid = ...
    mean(spectralCentroid);

fprintf("Mean Spectral Centroid: %.2f Hz\n", ...
    meanSpectralCentroid);


%% =========================================================
%  Spectral Slope
%  =========================================================

spectralSlope = zeros(1, length(T));

for i = 1:length(T)

    spectrum_dB = ...
        20 * log10(stftMagnitude(:,i) + eps);

    p = polyfit(F, spectrum_dB, 1);

    spectralSlope(i) = p(1);

end

meanSpectralSlope = ...
    mean(spectralSlope);

fprintf("Mean Spectral Slope: %.6f dB/Hz\n", ...
    meanSpectralSlope);


%% =========================================================
%  Spectral Bandwidth
%  =========================================================

spectralBandwidth = ...
    zeros(1, length(T));

for i = 1:length(T)

    spectrum = stftMagnitude(:,i);

    centroid = spectralCentroid(i);

    numerator = ...
        sum((F - centroid).^2 .* spectrum);

    denominator = ...
        sum(spectrum) + eps;

    spectralBandwidth(i) = ...
        sqrt(numerator / denominator);

end

meanSpectralBandwidth = ...
    mean(spectralBandwidth);

fprintf("Mean Spectral Bandwidth: %.2f Hz\n", ...
    meanSpectralBandwidth);


%% =========================================================
%  High-Frequency Energy Ratio
%  =========================================================

% Define high-frequency region
highFreqLimit = 4000;   % Hz

highFreqIndex = F >= highFreqLimit;

highFreqEnergy = ...
    sum(stftMagnitude(highFreqIndex,:).^2, 1);

totalEnergy = ...
    sum(stftMagnitude.^2, 1);

highFreqEnergyRatio = ...
    highFreqEnergy ./ ...
    (totalEnergy + eps);

meanHighFreqEnergyRatio = ...
    mean(highFreqEnergyRatio);

fprintf("Mean High-Frequency Energy Ratio: %.4f\n", ...
    meanHighFreqEnergyRatio);


%% =========================================================
%  RMS Energy
%  =========================================================

rmsEnergy = ...
    zeros(1, length(T));

for i = 1:length(T)

    frameStart = ...
        (i-1) * hopLength + 1;

    frameEnd = ...
        frameStart + windowLength - 1;

    if frameEnd <= length(x)

        frame = ...
            x(frameStart:frameEnd);

        rmsEnergy(i) = ...
            sqrt(mean(frame.^2));

    end

end

meanRMS = mean(rmsEnergy);

fprintf("Mean RMS Energy: %.4f\n", ...
    meanRMS);


%% =========================================================
%  Pitch
%  =========================================================

% Use a longer analysis window for pitch estimation
pitchWindowLength = round(0.040 * Fs);   % 40 ms

pitchOverlapLength = round(0.030 * Fs);  % 30 ms overlap

[pitchValues, pitchTime] = pitch( ...
    x, ...
    Fs, ...
    "WindowLength", pitchWindowLength, ...
    "OverlapLength", pitchOverlapLength);

% Remove unvoiced / invalid values
validPitch = ...
    pitchValues > 0 & ...
    ~isnan(pitchValues);

if any(validPitch)

    meanPitch = ...
        mean(pitchValues(validPitch));

else

    meanPitch = NaN;

end

fprintf("Mean Pitch: %.2f Hz\n", ...
    meanPitch);
%% =========================================================
%  Spectral Flux
%  =========================================================

spectralFlux = ...
    zeros(1, length(T));

for i = 2:length(T)

    currentSpectrum = ...
        stftMagnitude(:,i);

    previousSpectrum = ...
        stftMagnitude(:,i-1);

    difference = ...
        currentSpectrum - previousSpectrum;

    % Keep only positive spectral changes
    positiveDifference = ...
        max(difference, 0);

    spectralFlux(i) = ...
        sum(positiveDifference);

end

meanSpectralFlux = ...
    mean(spectralFlux);

fprintf("Mean Spectral Flux: %.4f\n", ...
    meanSpectralFlux);


%% =========================================================
%  Onset Detection
%  =========================================================

% Calculate detection threshold

onsetThreshold = ...
    mean(spectralFlux) + ...
    1.5 * std(spectralFlux);


% Detect potential onsets

onsetCandidates = ...
    spectralFlux > onsetThreshold;


% Prevent multiple detections
% within a very short period

onsetEvents = ...
    false(size(onsetCandidates));

frameRate = ...
    Fs / hopLength;

minimumDistanceSeconds = 0.05;

minimumDistanceFrames = ...
    round(minimumDistanceSeconds * frameRate);


lastOnset = -Inf;


for i = 1:length(onsetCandidates)

    if onsetCandidates(i)

        if i - lastOnset >= minimumDistanceFrames

            onsetEvents(i) = true;

            lastOnset = i;

        end

    end

end


%% =========================================================
%  Onset Rate
%  =========================================================

onsetTimes = ...
    T(onsetEvents);

numberOfOnsets = ...
    length(onsetTimes);

onsetRate = ...
    numberOfOnsets / duration;

fprintf("Number of Onsets: %d\n", ...
    numberOfOnsets);

fprintf("Onset Rate: %.2f onsets/sec\n", ...
    onsetRate);


%% =========================================================
%  Display Basic Information
%  =========================================================

fprintf("\n");
fprintf("====================================\n");
fprintf("Audio Information\n");
fprintf("====================================\n");

fprintf("Sampling Rate: %d Hz\n", ...
    Fs);

fprintf("Duration: %.2f seconds\n", ...
    duration);

fprintf("Number of Samples: %d\n", ...
    length(x));


%% =========================================================
%  Summary of Acoustic Features
%  =========================================================

fprintf("\n");
fprintf("====================================\n");
fprintf("Acoustic Feature Summary\n");
fprintf("====================================\n");

fprintf("Spectral Centroid: %.2f Hz\n", ...
    meanSpectralCentroid);

fprintf("Spectral Slope: %.6f dB/Hz\n", ...
    meanSpectralSlope);

fprintf("Spectral Bandwidth: %.2f Hz\n", ...
    meanSpectralBandwidth);

fprintf("High-Frequency Energy Ratio: %.4f\n", ...
    meanHighFreqEnergyRatio);

fprintf("RMS Energy: %.4f\n", ...
    meanRMS);

fprintf("Pitch: %.2f Hz\n", ...
    meanPitch);

fprintf("Spectral Flux: %.4f\n", ...
    meanSpectralFlux);

fprintf("Onset Rate: %.2f onsets/sec\n", ...
    onsetRate);


%% =========================================================
%  Plot Results
%  =========================================================

figure;


%% 1. Waveform

subplot(10,1,1);

plot(t,x);

xlabel("Time (s)");
ylabel("Amplitude");

title("Waveform");

grid on;


%% 2. FFT Spectrum

subplot(10,1,2);

plot(f,magnitude_dB);

xlim([0 Fs/2]);

xlabel("Frequency (Hz)");
ylabel("Magnitude (dB)");

title("FFT Spectrum");

grid on;


%% 3. STFT

subplot(10,1,3);

imagesc(T,F,S_dB);

axis xy;

ylim([0 Fs/2]);

xlabel("Time (s)");
ylabel("Frequency (Hz)");

title("STFT");

colorbar;


%% 4. Spectral Centroid

subplot(10,1,4);

plot(T,spectralCentroid);

xlabel("Time (s)");
ylabel("Frequency (Hz)");

title("Spectral Centroid");

grid on;


%% 5. Spectral Slope

subplot(10,1,5);

plot(T,spectralSlope);

xlabel("Time (s)");
ylabel("Slope (dB/Hz)");

title("Spectral Slope");

grid on;


%% 6. Spectral Bandwidth

subplot(10,1,6);

plot(T,spectralBandwidth);

xlabel("Time (s)");
ylabel("Bandwidth (Hz)");

title("Spectral Bandwidth");

grid on;


%% 7. High-Frequency Energy Ratio

subplot(10,1,7);

plot(T,highFreqEnergyRatio);

xlabel("Time (s)");
ylabel("Ratio");

title("High-Frequency Energy Ratio");

grid on;


%% 8. RMS Energy

subplot(10,1,8);

plot(T,rmsEnergy);

xlabel("Time (s)");
ylabel("RMS");

title("RMS Energy");

grid on;


%% 9. Pitch

subplot(10,1,9);

plot( ...
    pitchTime(validPitch), ...
    pitchValues(validPitch));

xlabel("Time (s)");
ylabel("Frequency (Hz)");

title("Pitch");

grid on;
%% 10. Spectral Flux + Onsets

subplot(10,1,10);

plot(T,spectralFlux);

hold on;

plot( ...
    T(onsetEvents), ...
    spectralFlux(onsetEvents), ...
    "ro");

xlabel("Time (s)");
ylabel("Flux");

title("Spectral Flux and Detected Onsets");

grid on;

hold off;