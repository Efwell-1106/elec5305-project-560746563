% Rebuild the editable App Designer archive from its source in MATLAB R2026a.
toolFolder=fileparts(mfilename('fullpath'));
appFolder=fileparts(toolFolder);
addpath(toolFolder,appFolder);
packageAppDesigner(fullfile(appFolder,'source','MusicFeatureLabApp.m'), ...
    fullfile(appFolder,'MusicFeatureLabApp.mlapp'));
