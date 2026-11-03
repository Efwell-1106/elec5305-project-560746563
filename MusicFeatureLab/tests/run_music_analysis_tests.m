function report = run_music_analysis_tests
%RUN_MUSIC_ANALYSIS_TESTS Core numerical checks without optional toolboxes.
tests = {@testIdentityAndSymmetry,@testNormalizedOutput,@testToneAnalysis, ...
    @testSilenceAndShortInput,@testCalibration,@testDisplayDecimation, ...
    @testOptionalPitchTimebase,@testSynthesis};
names = string(cellfun(@func2str,tests,'UniformOutput',false))';
passed = false(numel(tests),1);
messages = strings(numel(tests),1);
for k = 1:numel(tests)
    try
        tests{k}();
        passed(k) = true;
        messages(k) = "Passed";
    catch exception
        messages(k) = string(getReport(exception,'basic','hyperlinks','off'));
    end
end
report = table(names,passed,messages,'VariableNames',{'Test','Passed','Message'});
disp(report);
assert(all(passed),'MusicAnalysis:TestFailure','One or more MusicAnalysis tests failed.');
end

function testIdentityAndSymmetry
fs = 16000;
for n = [2000 2001]
    t = (0:n-1)'/fs;
    f1 = 17*fs/n;
    f2 = 601*fs/n;
    low = 0.1*sin(2*pi*f1*t);
    high = 0.1*cos(2*pi*f2*t);
    x = [low+high,low-high];
    y = MusicAnalysis.brightness(x,fs,0);
    assert(isequal(y,x),'Zero brightness must be exactly identical.');
    [y,info] = MusicAnalysis.brightness(x,fs,0.75);
    expected = [low*10^(4.5*(f1/(fs/2))/20)+high*10^(4.5*(f2/(fs/2))/20), ...
        low*10^(4.5*(f1/(fs/2))/20)-high*10^(4.5*(f2/(fs/2))/20)];
    assert(isequal(size(y),size(x)),'Stereo shape changed.');
    assert(max(abs(y(:)-expected(:)))<1e-10,'Odd/even FFT gain is not symmetric.');
    assert(info.peakScale==1 && info.gainDB==4.5,'Unexpected gain metadata.');
end
row = [0.1 0.2 0.3];
assert(isequal(size(MusicAnalysis.brightness(row,fs,0)),size(row)), ...
    'Row-vector input shape changed.');
end

function testNormalizedOutput
fs = 16000;
t = (0:fs-1)'/fs;
x = 2*sin(2*pi*440*t);
[y,info] = MusicAnalysis.brightness(x,fs,0);
assert(abs(max(abs(y))-1)<1e-12,'Clipping protection failed.');
assert(abs(info.peakScale-0.5)<1e-12,'Incorrect peak scale.');
r = MusicAnalysis.analyze(y,fs);
assert(abs(r.rms-sqrt(mean(y.^2)))<1e-12,'RMS must describe actual output audio.');
end

function testToneAnalysis
% At fs=12800 the 20 ms window has 256 samples; 500 Hz is exactly
% 10 cycles/window and one STFT bin. This avoids a false assumption that
% amplitude-weighted centroids are immune to off-bin Hamming sidelobes.
fs = 12800;
t = (0:fs-1)'/fs;
x = 0.5*sin(2*pi*500*t);
r = MusicAnalysis.analyze(x,fs);
assert(abs(r.centroid-500)<5,'Bin-centred tone centroid is inaccurate.');
assert(abs(r.rms-0.5/sqrt(2))<1e-12,'Tone RMS is inaccurate.');
[~,bin] = min(abs(r.fSpectrum-500));
assert(abs(r.spectrumDB(bin)-20*log10(0.5))<1e-8,'FFT amplitude calibration failed.');
assert(r.hfRatio<1e-5,'Low-frequency tone has spurious HF energy.');
assert(isnan(r.pitch),'Pitch must be NaN when disabled.');
features = MusicAnalysis.featureTable(r,'Synthetic tone');
assert(height(features)==1 && width(features)==12,'Feature-table schema changed.');
assert(features.Channels==1 && features.Source=="Synthetic tone",'Feature metadata changed.');
end

function testSilenceAndShortInput
inputs = {zeros(1600,2),0,[0.1; -0.2; 0.3],ones(321,1)*0.1};
for k = 1:numel(inputs)
    r = MusicAnalysis.analyze(inputs{k},16000);
    values = [r.duration,r.centroid,r.slope,r.bandwidth,r.hfRatio,r.rms,r.flux,r.onsetRate];
    assert(all(isfinite(values)),'Short/silent audio generated nonfinite features.');
    assert(all(isfinite(r.stftDB(:))),'Nonfinite spectrogram.');
    assert(size(r.stftDB,2)==numel(r.tFrames),'Spectrogram and time axis differ.');
end
r = MusicAnalysis.analyze(zeros(1600,1),16000);
assert(all([r.centroid,r.slope,r.bandwidth,r.hfRatio,r.rms,r.flux,r.onsetRate]==0), ...
    'Silence must produce zero spectral features.');
t = (0:1599)'/16000;
tone = 0.2*sin(2*pi*440*t);
r = MusicAnalysis.analyze([tone,-tone],16000);
assert(r.channels==2 && r.rms==0 && contains(r.note,'cancel'), ...
    'Stereo cancellation must be explained in the mono analysis result.');
processed = MusicAnalysis.brightness([tone,-tone],16000,0.5);
assert(max(abs(processed(:,1)))>0.1 && ...
    max(abs(processed(:,1)+processed(:,2)))<1e-12, ...
    'Stereo cancellation in analysis must not erase the processed channels.');
end

function testCalibration
fs = 16000;
t = (0:fs-1)'/fs;
x = 0.15*sin(2*pi*500*t)+0.15*sin(2*pi*6000*t);
calibration = MusicAnalysis.calibration(x,fs);
assert(height(calibration)==9 && all(abs(calibration.Brightness-(-1:0.25:1)')<1e-12), ...
    'Default calibration levels changed.');
assert(all(diff(calibration.Centroid_Hz)>0),'Centroid must increase for the two-tone stimulus.');
assert(all(diff(calibration.HFRatio)>0),'HF ratio must increase for the two-tone stimulus.');
end

function testDisplayDecimation
fs = 12800;
t = (0:10*fs-1)'/fs;
r = MusicAnalysis.analyze(0.2*sin(2*pi*500*t),fs);
assert(numel(r.tFrames)<=1800,'Display frame cap failed.');
assert(numel(r.tFrames)==numel(r.centroidSeries),'Display series are not aligned.');
assert(size(r.stftDB,2)==numel(r.tFrames),'Spectrogram decimation is not aligned.');
assert(abs(r.centroid-500)<5,'Full-length summary changed during decimation.');
[~,peak] = max(r.spectrumDB);
assert(abs(r.fSpectrum(peak)-500)<1,'Spectrum display pooling lost a narrow tone.');
end

function testOptionalPitchTimebase
fs = 8000;
t = (0:fs-1)'/fs;
r = MusicAnalysis.analyze(0.2*sin(2*pi*180*t),fs,true);
if isfinite(r.pitch)
    assert(max(r.pitchTimes)<=r.duration && min(r.pitchTimes)>=0, ...
        'Pitch sample locations were not converted to seconds.');
    assert(abs(r.pitch-180)<10,'Monophonic pitch estimate is inaccurate.');
else
    assert(~isempty(r.note),'Unavailable pitch requires an explanatory note.');
end
end

function testSynthesis
y = MusicAnalysis.synthesize(440,5,3,2,44100);
assert(isequal(size(y),[88200,1]) && all(isfinite(y)),'FM synthesis output is invalid.');
assert(max(abs(y))<=0.45 && y(1)==0 && y(end)==0,'FM amplitude/fade safeguards failed.');
end
