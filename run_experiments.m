% Recompute the experiments and verification without opening the App GUI.
mflLaunchRoot=fileparts(mfilename('fullpath'));
addpath(fullfile(mflLaunchRoot,'Report'));
run(fullfile(mflLaunchRoot,'Report','Experiment_Live_source.m'));
