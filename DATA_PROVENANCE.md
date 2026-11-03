# Data provenance and measurement scope

The retained library contains 15 approximately 30-second stereo recordings,
sampled at 48 kHz: Neutral, Bright and Dark, each with filename seeds 12315,
12325, 12335, 12345 and 12355. They represent one instrumental electronic-music
context. The separate demo.wav recording is the 44.1 kHz calibration source.

The author reports using ACE-Step, changing only the brightness wording,
manually entering matching seeds, keeping other settings unchanged, and
performing no selective sample removal or audio editing. This account is
author recollection: the complete per-output generation log and exact
installed software/checkpoint version were not retained. Same seeds do not
guarantee identical musical content after changing a prompt.

The current pipeline recomputes measurements from retained audio. It does
not reproduce the historical music-generation process or invoke a model.
The old feature CSV in MusicFeatureLab/data/original_AI_music_results.csv is
historical only and must not be combined with the current measurements.

Pitch is excluded from the main comparison. The exploratory pitch estimates
for seed 12315 accumulated near the configured 1000 Hz upper boundary.
The author reported 51.0%, 33.4% and 76.5% near-boundary finite estimates
for Neutral, Bright and Dark. These percentages are not accuracy scores.

In the paired figures, error bars describe +/- one sample standard deviation
of five seed-paired changes, scaled by Neutral's cross-seed SD where stated.
They are not confidence intervals. No significance test or listening study
is reported. Acoustic changes do not establish perceived brightness changes.
