# Music Feature Lab

This integrated MATLAB App combines audio analysis, brightness processing, DSP
calibration, music-library comparison and FM synthesis.

## Launch

Run `run_app.m` from this folder, or open `MusicFeatureLabApp.mlapp` in App
Designer and click Run. The launcher locates the data relative to its own folder.
Keep the folder structure together. MATLAB R2026a Update 4 was used for validation.
The core analysis requires no additional toolboxes. Optional pitch estimation
uses Audio Toolbox; an unavailable estimate does not block the other features.

## Workflow

1. Import an audio file or load `demo.wav`; inspect waveform, FFT, STFT and features.
2. Adjust brightness from -1 to +1, then audition the original and processed audio.
3. Run the nine-level experiment on the current source to obtain measured curves.
4. Analyze the retained Dark, Neutral and Bright library; select a row to load a clip.
5. Generate an FM demonstration and send it to the same analysis workflow.
6. Export processed WAV, CSV tables, PNG figures, MAT results and JSON settings.

## Files

- `MusicFeatureLabApp.mlapp`: editable App Designer application.
- `MusicAnalysis.m`: shared analysis and signal-processing implementation.
- `source/MusicFeatureLabApp.m`: backup application source.
- `tools/`: optional tools for rebuilding the MLAPP from the backup source.
- `tests/`: numerical checks and a recorded test report.
- `demo.wav`: copy of the original calibration recording, `test.wav`.
- `data/music library/`: the 15 retained recordings in three condition folders.
- `data/original_AI_music_results.csv`: historical results for reference only.
- `data/recomputed_*.csv`: results obtained using the integrated analysis.
- `app_preview.png` and `brightness_preview.png`: captured application views.

Rebuilding with `tools/build_app.m` overwrites the MLAPP from the backup source.
Normal use does not require the build tools. If editing in App Designer, retain
the version saved there as the primary application.

## Methods and interpretation

Analysis uses a symmetric 20 ms Hamming window and a nominal 4 ms hop. Spectral
features share the same normalized single-sided STFT. Centroid and bandwidth
use amplitude weights; slope is a dB/Hz regression; HF ratio is the fraction of
squared amplitudes at or above 4 kHz. Nearly silent frames are omitted from
spectral means. RMS describes the complete mono analysis signal. Positive
spectral flux and onset counts are descriptive and do not establish beat labels.

Channels are averaged for analysis, while playback, processing and export retain
stereo. Out-of-phase channels can cancel during analysis. All analysis frames
are measured; display reduction controls plotting memory. Optional pitch is a
single-pitch estimate and may be unreliable for polyphonic music or noise.

Brightness applies symmetric gains to positive and negative FFT frequencies.
The nominal gain is `6 * brightness * (frequency / Nyquist)` dB. Peaks above 1
cause uniform scaling; the displayed features are recomputed from that output.
Zero brightness preserves inputs already within range. Processing uses the
complete recording and updates after slider release. A/B audition does not
provide seamless filtering during playback. Long recordings require more memory.

The eight numerical test groups passed, together with workflow checks of
calibration, the 15-file library, export and the natively saved App. Exported
MAT files retain settings and results; they do not restore a complete session.
The current App analyzes existing recordings and does not invoke a music
generation model. Historical and recomputed descriptors must not be mixed.
The retained library lacks a stable Dark-Neutral-Bright ordering. No listening
study or statistical significance test is claimed.

## AI assistance statement

I selected the topic, ran the original audio generation, and wrote the original MATLAB code with AI guidance. I used AI assistance to plan the experiments, summarize and analyze the results, organize materials and references, improve language and grammar, and draft and revise the report. OpenAI Codex also helped develop, integrate and review the revised MATLAB App and code and verify results. Numerical results were computed from the retained audio using the supplied code. No missing generation records, participant responses or subjective ratings were invented.
