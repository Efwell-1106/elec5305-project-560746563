clear;
clc;
close all;

%% Load original audio

filename = "test.wav";

[x, Fs] = audioread(filename);

% Convert stereo to mono
if size(x,2) > 1
    x = mean(x,2);
end

%% Brightness settings

brightnessValues = [0 0.25 0.50 0.75 1.00];

centroidValues = zeros(size(brightnessValues));
slopeValues = zeros(size(brightnessValues));
hfRatioValues = zeros(size(brightnessValues));

%% FFT

N = length(x);

X = fft(x);

%% Frequency vector

f = (0:N-1)' / N * Fs;

%% Create normalized frequency

normalizedFreq = zeros(N,1);

% Positive-frequency half
positiveIndex = f <= Fs/2;

normalizedFreq(positiveIndex) = f(positiveIndex) / (Fs/2);

% Negative-frequency half
negativeIndex = f > Fs/2;

normalizedFreq(negativeIndex) = ...
    (Fs - f(negativeIndex)) / (Fs/2);

%% Apply brightness control

for i = 1:length(brightnessValues)

    brightness = brightnessValues(i);

    %% Maximum high-frequency boost

    maxGain = 2;

    % Gain increases with frequency
    gain = 1 + brightness .* normalizedFreq * (maxGain - 1);

    %% Apply symmetric frequency gain

    Y = X .* gain;

    %% Convert back to time domain

    y = real(ifft(Y));

    %% Normalize

    y = y / max(abs(y) + eps);

    %% Save temporary audio

    tempFilename = "temp_dsp.wav";

    audiowrite(tempFilename, y, Fs);

    %% Analyze

    result = analyzeAudio(tempFilename);

    centroidValues(i) = result.centroid;
    slopeValues(i) = result.slope;
    hfRatioValues(i) = result.hfRatio;

end

%% Display results

results = table( ...
    brightnessValues', ...
    centroidValues', ...
    slopeValues', ...
    hfRatioValues', ...
    'VariableNames', ...
    {'Brightness','Centroid','Slope','HFRatio'});

disp("======================================");
disp("DSP Calibration Results");
disp("======================================");

disp(results);

%% Plot Spectral Centroid

figure;

plot(brightnessValues * 100, centroidValues, 'o-', ...
    'LineWidth', 1.5);

xlabel('Brightness Slider (%)');
ylabel('Spectral Centroid (Hz)');
title('DSP Calibration: Brightness vs Spectral Centroid');

grid on;

%% Plot Spectral Slope

figure;

plot(brightnessValues * 100, slopeValues, 'o-', ...
    'LineWidth', 1.5);

xlabel('Brightness Slider (%)');
ylabel('Spectral Slope');

title('DSP Calibration: Brightness vs Spectral Slope');

grid on;

%% Plot HF Ratio

figure;

plot(brightnessValues * 100, hfRatioValues, 'o-', ...
    'LineWidth', 1.5);

xlabel('Brightness Slider (%)');
ylabel('HF Ratio');

title('DSP Calibration: Brightness vs HF Ratio');

grid on;