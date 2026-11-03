% Recreate paired summary figures from the supplied measurement tables.
summaryRoot=fileparts(mfilename('fullpath'));
addpath(fullfile(summaryRoot,'Analysis'));
run(fullfile(summaryRoot,'Analysis','Video_Walkthrough_source.m'));
