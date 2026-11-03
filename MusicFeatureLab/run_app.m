% Music Feature Lab - one entry point, independent of the current folder.
appFolder=fileparts(mfilename('fullpath'));
addpath(appFolder);
if isfile(fullfile(appFolder,'MusicFeatureLabApp.mlapp'))
    MusicFeatureLabApp;
else
    addpath(fullfile(appFolder,'source'));
    MusicFeatureLabApp;
end
