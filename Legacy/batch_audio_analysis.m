clear;
clc;
close all;

%% =========================
%  Batch Audio Analysis
%  =========================

% Root folder
dataFolder = "data";

% Conditions
conditions = ["dark", "neutral", "bright"];

% Store all results
allResults = table();

%% =========================
%  Process each condition
%  =========================

for c = 1:length(conditions)

    condition = conditions(c);

    % Current condition folder
    conditionFolder = fullfile(dataFolder, condition);

    % Find all WAV files
    files = dir(fullfile(conditionFolder, "*.wav"));

    if isempty(files)
        warning("No WAV files found in folder: %s", conditionFolder);
        continue;
    end

    fprintf("\nProcessing %s...\n", upper(condition));

    %% Process every audio file

    for k = 1:length(files)

        filename = files(k).name;
        filepath = fullfile(conditionFolder, filename);

        fprintf("  Analyzing: %s\n", filename);

        % Analyze audio
        result = analyzeAudio(filepath);

        %% Extract seed number from filename

        seedToken = regexp(filename, "_(\d+)", "tokens");

        if ~isempty(seedToken)
            seed = str2double(seedToken{1}{1});
        else
            seed = k;
        end

        %% Create one row of results

        newRow = table( ...
            string(condition), ...
            seed, ...
            string(filename), ...
            result.centroid, ...
            result.slope, ...
            result.bandwidth, ...
            result.hfRatio, ...
            result.rms, ...
            result.pitch, ...
            result.spectralFlux, ...
            result.onsetRate, ...
            'VariableNames', { ...
            'Condition', ...
            'Seed', ...
            'Filename', ...
            'Centroid', ...
            'Slope', ...
            'Bandwidth', ...
            'HFRatio', ...
            'RMS', ...
            'Pitch', ...
            'SpectralFlux', ...
            'OnsetRate' ...
            });

        %% Add to complete results table

        allResults = [allResults; newRow];

    end
end

%% =========================
%  Display results
%  =========================

disp("========================================");
disp("Batch analysis completed.");
disp("========================================");

disp(allResults);

%% =========================
%  Save results
%  =========================

writetable(allResults, "batch_results.csv");

save("batch_results.mat", "allResults");

fprintf("\nResults saved as:\n");
fprintf("  batch_results.csv\n");
fprintf("  batch_results.mat\n");