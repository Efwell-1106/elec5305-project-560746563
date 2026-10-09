# From Words to Waveforms: Evaluating Acoustic Control in AI-Generated Music

## 1. Project Overview

AI music generation systems allow users to describe desired musical characteristics using natural language. However, a model producing music that appears to match a prompt does not necessarily mean that the prompt caused the intended acoustic change.

This project investigates the controllability of AI-generated music through natural-language descriptors, focusing on **timbral brightness**.

The study combines MATLAB-based acoustic analysis, deterministic digital signal processing (DSP), and controlled experiments with pretrained text-to-music models. It evaluates whether brightness-related descriptors produce measurable, consistent, and selective changes in generated audio.

## 2. Research Question

**To what extent can natural-language descriptors reliably and selectively control the acoustic brightness of AI-generated music?**

The investigation addresses three questions:

1. **Consistency:** Do dark, neutral, and bright prompts produce consistent changes in brightness-related acoustic features?
2. **Selectivity:** Does the intended brightness change occur without substantial unintended changes in other acoustic features?
3. **Reproducibility:** Do the observed effects remain consistent across repeated generations and different random seeds?

The project distinguishes measurable acoustic changes from subjective perceptual judgements. A change in a spectral feature alone is not treated as conclusive proof of a perceptual change.

## 3. Descriptor Definitions

The initial experiment uses three descriptor conditions.

| Condition | Definition | Experimental role |
|---|---|---|
| Dark | A darker-sounding timbre, expected to have relatively less high-frequency emphasis | Target condition |
| Neutral | A musical description without an explicit brightness instruction | Baseline condition |
| Bright | A brighter-sounding timbre, expected to have relatively greater high-frequency emphasis | Target condition |

The prompts should preserve the same musical context and change the brightness descriptor as the main experimental variable.

These definitions describe the intended sound rather than a guaranteed model output. The actual acoustic effects are determined through audio analysis.

## 4. Acoustic Feature Extraction

### 4.1 Brightness-Related Features

The following features are used to evaluate changes associated with brightness.

- **Spectral centroid:** The frequency-weighted centre of the spectrum. It is commonly used as an indicator of spectral brightness.
- **Spectral slope:** Describes how spectral magnitude changes with frequency.
- **High-frequency energy ratio:** Measures the proportion of spectral energy above a defined frequency threshold.

These features provide complementary measurements of spectral distribution. They are not interchangeable, and none independently captures every aspect of perceived brightness.

### 4.2 Off-Target Features

Additional features are monitored to identify unintended changes.

- **RMS level:** A measure of signal amplitude related to perceived loudness.
- **Pitch:** An estimate of fundamental frequency where the signal permits reliable estimation.
- **Spectral flux:** Measures changes in the spectrum between consecutive analysis frames.
- **Onset rate:** Estimates the number of detected note or event onsets per second.

These measurements help determine whether a brightness prompt affects other properties such as level, pitch, rhythm, or spectral activity.

Pitch and onset estimates can be unreliable for polyphonic music and percussive signals. Their limitations must be considered when interpreting results.

## 5. MATLAB Audio Analysis

MATLAB is used for audio loading, signal analysis, feature extraction, and result comparison.

The analysis includes:

- Audio loading and conversion to mono where appropriate.
- Fast Fourier transform (FFT) analysis.
- Short-time Fourier transform (STFT) analysis.
- Spectral visualisation and spectrogram analysis.
- Spectral centroid, spectral slope, and high-frequency energy ratio.
- RMS level, pitch, spectral flux, and onset-rate estimation.

The STFT uses a 20 ms analysis window and a 4 ms hop in the current analysis configuration. The same analysis settings should be used for all audio files in a matched comparison.

Custom MATLAB functions are used where necessary for features that are not directly available through the selected built-in feature extractors.

## 6. Deterministic Brightness-Control DSP

A deterministic DSP reference provides a controlled comparison for the AI-generated music experiments.

A fixed input signal is processed using a controllable high-shelf filter. The filter changes the high-frequency content while keeping the original recording and other experimental conditions fixed.

The input and processed audio can then be analysed using the same acoustic-feature extraction methods.

This reference helps establish how a known signal-processing change affects the measured features. It does not, by itself, demonstrate that an AI music generator can achieve the same degree of control.

## 7. Synthetic Validation

Synthetic test signals provide a way to check the behaviour of the acoustic-analysis implementation under controlled conditions.

Validation cases include signals with known frequency components and signals with controlled differences in high-frequency content.

The validation checks whether:

- Frequency analysis identifies the expected frequency components.
- Spectral measurements respond appropriately to changes in the signal.
- High-frequency energy measurements reflect controlled changes in high-frequency content.
- The feature-extraction implementation produces interpretable results under known input conditions.

Synthetic validation is important because it tests the measurement process independently of the variability of AI-generated music.

## 8. AI Music Generation and Experimental Design

### 8.1 Generation Models

The project considers open music-generation systems, with ACE-Step 1.5 as the primary candidate and MusicGen / AudioCraft as an alternative.

The selected pretrained model is treated as a fixed generator rather than being retrained as part of the main experiment.

- [ACE-Step 1.5 — Official repository](https://github.com/ace-step/ACE-Step-1.5)
- [MusicGen / AudioCraft — Official repository](https://github.com/facebookresearch/audiocraft)

### 8.2 Matched-Prompt Experiments

The experiment compares dark, neutral, and bright prompts within the same musical context.

The procedure is:

1. Define a common musical description.
2. Create matched prompts that differ primarily in the brightness descriptor.
3. Keep model settings consistent across conditions.
4. Use shared random seeds where supported.
5. Repeat the comparison across multiple seeds.
6. Extract the same acoustic features from each output.
7. Compare target-feature changes and off-target effects.

If a model does not support exact reproducibility, the limitation is documented rather than assuming that a repeated prompt will produce identical audio.

### 8.3 Generation Metadata

Each generation is associated with metadata to support comparison and reproducibility.

The metadata records the following fields where available:

| Field | Description |
|---|---|
| `model_name` | Model name and version |
| `prompt` | Exact prompt text |
| `condition` | Dark, neutral, or bright |
| `seed` | Random seed |
| `generation_settings` | Model parameters used during generation |
| `audio_filename` | Generated audio filename |
| `sample_rate` | Audio sample rate |
| `duration_seconds` | Audio duration |
| `generation_date` | Generation date |
| `notes` | Relevant limitations or observations |

The prompt, seed, and generation settings are important for distinguishing descriptor-driven changes from ordinary generation variability.

## 9. Evaluation and Analysis

The evaluation focuses on consistency, selectivity, and reproducibility.

### 9.1 Target-Feature Analysis

The extracted spectral features are compared across dark, neutral, and bright conditions to determine whether the expected brightness-related changes occur.

### 9.2 Off-Target Analysis

RMS level, pitch, spectral flux, and onset rate are compared across conditions to identify potential unintended effects.

### 9.3 Cross-Seed Consistency

Results are compared across repeated generations to determine whether the direction and magnitude of brightness-related changes remain consistent.

### 9.4 Interpretation

A generated clip that sounds brighter is not sufficient evidence of reliable prompt control. The conclusion should be supported by measured feature changes, matched comparisons, and consistency across repetitions.

The deterministic DSP reference provides a controlled benchmark, while the AI-generation experiment tests whether natural-language prompts produce comparable and selective changes.

## 10. Software Requirements

### MATLAB Analysis

- MATLAB.
- Signal Processing Toolbox for relevant signal-processing functions.
- Audio Toolbox when using `audioFeatureExtractor` or other Audio Toolbox functions.

The MATLAB release and toolbox dependencies should match the functions used in the analysis scripts.

### AI Music Generation

- ACE-Step 1.5 or the selected alternative model.
- The Python environment and dependencies specified by the selected model's official installation instructions.
- Sufficient computational resources for the chosen model configuration.

Refer to the official model documentation for installation requirements:

- [ACE-Step 1.5 installation guide](https://github.com/ace-step/ACE-Step-1.5)
- [AudioCraft documentation](https://github.com/facebookresearch/audiocraft)

## 11. Reproduction Instructions

### 11.1 MATLAB Analysis

1. Clone or download this repository.
2. Open MATLAB and set the working directory to the repository.
3. Ensure the required toolboxes are installed.
4. Place the input audio file in the location expected by the analysis script.
5. Run the relevant MATLAB analysis script or feature-extraction function.
6. Inspect the extracted features and spectral analysis results.

For the current analysis example, the input audio is named `test.wav`. The analysis function can be called with:

```matlab
result = analyzeAudio("test.wav");
```

The exact script and input-file paths should match the files committed to the repository.

### 11.2 Brightness-Control DSP

1. Load the fixed input audio.
2. Apply the brightness-control DSP using the configured parameter.
3. Save or inspect the processed signal.
4. Analyse the original and processed audio using consistent settings.
5. Compare the extracted brightness-related and off-target features.

### 11.3 AI Music Experiments

1. Install and configure the selected music-generation model.
2. Generate the matched prompt conditions using documented settings.
3. Save each output with its corresponding metadata.
4. Analyse the generated audio using the MATLAB feature-extraction implementation.
5. Compare the extracted features across conditions and random seeds.

## 12. Limitations

- Spectral measurements do not fully represent human timbre perception.
- Brightness descriptors may influence multiple acoustic properties simultaneously.
- Pitch and onset estimation may be unreliable for some polyphonic or percussive material.
- Random seeds do not necessarily guarantee identical results across model versions, software environments, or hardware.
- Observed differences may result from ordinary generation variability rather than the intended prompt change.
- A deterministic filter provides a controlled reference but cannot establish the controllability of a generative model by itself.

## 13. References

### 13.1 Music Generation: Methods, Evaluation, and Challenges

Duan, W., Yu, Y., & Briot, J.-P. (2026). Recent advances in music generation: methods, evaluation, and challenges. *Artificial Intelligence Review, 59*, Article 195.

[https://doi.org/10.1007/s10462-026-11582-x](https://doi.org/10.1007/s10462-026-11582-x)

This review surveys music-generation methods, evaluation metrics, datasets, and current research challenges.

### 13.2 Fine-Grained Controllable Music Generation

Tsai, F.-D., Wu, S.-L., Lee, W., Yang, S.-P., Chen, B.-R., Cheng, H.-C., & Yang, Y.-H. (2025). MuseControlLite: Multifunctional Music Generation with Lightweight Conditioners. *Proceedings of the 42nd International Conference on Machine Learning*, 267, 60266–60279.

[https://proceedings.mlr.press/v267/tsai25a.html](https://proceedings.mlr.press/v267/tsai25a.html)

This work investigates fine-grained musical control using lightweight conditioning mechanisms and provides background on controllable music generation.

### 13.3 Counterfactual Evaluation of Text-to-Music Control

Wang, Y. (2026). Do Text-to-Music Models Really Follow Instructions? A Counterfactual Evaluation of Key and Beat Grouping. *arXiv preprint arXiv:2608.11899*.

[https://arxiv.org/abs/2608.11899](https://arxiv.org/abs/2608.11899)

This study uses matched neutral and target prompts, shared seeds, and counterfactual comparisons to distinguish instruction-driven control from attributes that occur naturally in model outputs. Its experimental logic motivates controlled prompt comparisons in this project.

### 13.4 ACE-Step 1.5

ACE-Step contributors. ACE-Step 1.5: Open-source music generation model.

[Official GitHub repository](https://github.com/ace-step/ACE-Step-1.5)

ACE-Step 1.5 is considered as a candidate model for the text-to-music experiments.

### 13.5 MusicGen / AudioCraft

Copet, J., et al. (2023). Simple and controllable music generation. *Advances in Neural Information Processing Systems*.

[Paper](https://arxiv.org/abs/2306.05284)

[Official AudioCraft repository](https://github.com/facebookresearch/audiocraft)

This work introduces MusicGen, a text- and melody-conditioned music-generation model.

### 13.6 MATLAB Audio Feature Extraction

MathWorks. `audioFeatureExtractor` — Streamline audio feature extraction.

[Official MATLAB documentation](https://www.mathworks.com/help/audio/ref/audiofeatureextractor.html)

The documentation describes a configurable feature-extraction pipeline for features such as spectral centroid, pitch, spectral flux, and other audio descriptors.

### 13.7 Timbral Brightness Perception

Saitis, C., & Wallmark, Z. (2024). Timbral brightness perception investigated through multimodal interference. *Attention, Perception, & Psychophysics, 86*, 1835–1845.

[https://doi.org/10.3758/s13414-024-02934-2](https://doi.org/10.3758/s13414-024-02934-2)

This study investigates timbral brightness perception and its relationship with spectral emphasis and cross-modal perception.

---

## Project Status

This repository documents the research question, acoustic descriptors, MATLAB analysis, deterministic brightness-control reference, validation approach, generation methodology, and relevant literature for evaluating acoustic control in AI-generated music.

Implementation details and experimental conclusions should be interpreted alongside the code, audio files, metadata, and results committed to the repository.
