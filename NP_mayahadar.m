% Define the directories containing the files
directories = { ...
    'C:\Users\מיה\Desktop\BIU\nuerophotonics_3\ReadNoise_Gain24_expT0.021ms', ...
    'C:\Users\מיה\Desktop\BIU\nuerophotonics_3\Background_Gain24_expT15ms_Hana', ...
    'C:\Users\מיה\Desktop\BIU\nuerophotonics_3\FR20hz_Gain24_expT15ms_Hana', ...
    'C:\Users\מיה\Desktop\BIU\nuerophotonics_3\FR20hz_Gain24_expT15ms_Hana_breath' ...
};

ReadNoise = {};
Background = {};
FR20hz = {};
FR20hz_breath = {};

for dirIdx = 1:length(directories)
    directory = directories{dirIdx};
    filePattern = fullfile(directory, '*.tiff'); % This will match all TIFF files
    allFiles = dir(filePattern);
    fileData = cell(1, length(allFiles));
    for k = 1:length(allFiles)
        baseFileName = allFiles(k).name;
        fullFileName = fullfile(directory, baseFileName);
        if allFiles(k).isdir
            continue;
        end
        
        try
            img = imread(fullFileName);
            if all(mod(img(:), 16) == 0)
                img = img / 16;
            end
            fileData{k} = img;
        catch
            fileData{k} = [];
        end
    end
    fileData = fileData(~cellfun('isempty', fileData));
    switch dirIdx
        case 1
            ReadNoise = fileData;
            disp(['Loaded ', num2str(length(ReadNoise)), ' images from ReadNoise_Gain24_expT0.021ms.']);
        case 2
            Background = fileData;
            disp(['Loaded ', num2str(length(Background)), ' images from Background_Gain24_expT15ms_Hana.']);
        case 3
            FR20hz = fileData;
            disp(['Loaded ', num2str(length(FR20hz)), ' images from FR20hz_Gain24_expT15ms_Hana.']);
        case 4
            FR20hz_breath = fileData;
            disp(['Loaded ', num2str(length(FR20hz_breath)), ' images from FR20hz_Gain24_expT15ms_Hana_breath.']);
    end
end

% 0. set windowSize = 7
windowSize = 7;

% 1. Ask the user for recording path
recordingPath = uigetdir('Select the directory containing the recordings');

% 2. Determine an ROI
if ~isempty(FR20hz)
    figure;
    imshow(FR20hz{1}, []);
    title('Select ROI for Analysis');
    h = imellipse;
    position = wait(h);
    roiMask = createMask(h);
    close(gcf);
else
    error('No frames available for plotting.');
end

% 3. Calculate Read Noise
readNoisePath = directories{1};
readNoiseImages = dir(fullfile(readNoisePath, '*.tiff'));
numReadNoiseFrames = numel(readNoiseImages);
firstImage = imread(fullfile(readNoisePath, readNoiseImages(1).name));
[rows, cols] = size(firstImage);
readNoiseFrames = zeros(rows, cols, numReadNoiseFrames);
for i = 1:numReadNoiseFrames
    img = double(imread(fullfile(readNoisePath, readNoiseImages(i).name)));
    readNoiseFrames(:,:,i) = img;
end

readNoiseMatrix = std(readNoiseFrames, 0, 3);  
readNoiseFiltered = imboxfilt(readNoiseMatrix, [windowSize, windowSize]);

% 4. Calculate DarkBackground Imag
backgroundPath = directories{2}; 
backgroundImages = dir(fullfile(backgroundPath, '*.tiff'));
numBackgroundFrames = numel(backgroundImages);
firstBackgroundImage = imread(fullfile(backgroundPath, backgroundImages(1).name));
[rows, cols] = size(firstBackgroundImage);
backgroundFrames = zeros(rows, cols, numBackgroundFrames);
for i = 1:numBackgroundFrames
    img = double(imread(fullfile(backgroundPath, backgroundImages(i).name)));
    backgroundFrames(:,:,i) = img;
end

darkBackgroundImage = mean(backgroundFrames, 3);

% 5. Calculate Pixels-Non-Uniformity (𝜎𝑠𝑝) for FR20hz_Gain24_expT15ms_Hana
recordingPath = directories{3}; 
recordingImages = dir(fullfile(recordingPath, '*.tiff'));
numRecordingFrames = numel(recordingImages);
numFramesForSP = min(numRecordingFrames, 500);
recordingFramesSP = zeros(rows, cols, numFramesForSP);
for i = 1:numFramesForSP
    img = double(imread(fullfile(recordingPath, recordingImages(i).name)));
    recordingFramesSP(:,:,i) = img;
end

backgroundSubtractedFramesSP = recordingFramesSP - darkBackgroundImage;
meanFrameSP = mean(backgroundSubtractedFramesSP, 3);
varianceWindowSP = stdfilt(backgroundSubtractedFramesSP, true([windowSize, windowSize])) .^ 2;
averageVarianceWindowSP = mean(varianceWindowSP, 3);

% 6. Calculate G[DU/e] 
G = 6.18;

% 7. For every frame :
K_f_squared_ROI = zeros(numRecordingFrames, 1);
for k = 1:numRecordingFrames
    frame = double(imread(fullfile(recordingPath, recordingImages(k).name))) - darkBackgroundImage;
    meanFrame = imboxfilt(frame, [windowSize, windowSize]);
    varWindow = stdfilt(frame, true([windowSize, windowSize])).^2;
    
    % Calculate K_raw^2
    K_raw_squared = varWindow ./ (meanFrame .^ 2);
    
    % Calculate K_s^2
    K_s_squared = G ./ meanFrame;
    
    % Calculate K_q^2
    K_q_squared = 1 ./ (12 * meanFrame .^ 2);
    
    % Calculate K_f^2
    K_f_squared = K_raw_squared - K_s_squared - K_q_squared;
    
    % Calculate K_f^2 inside ROI
    K_f_squared_ROI(k) = mean(K_f_squared(roiMask));
end

save('K_f_squared_ROI.mat', 'K_f_squared_ROI');

% Calculate Pixels-Non-Uniformity (𝜎𝑠𝑝) for FR20hz_Gain24_expT15ms_Hana_breath
recordingPathBreath = directories{4};
recordingImagesBreath = dir(fullfile(recordingPathBreath, '*.tiff'));
numRecordingFramesBreath = numel(recordingImagesBreath);
numFramesForSPBreath = min(numRecordingFramesBreath, 500);
recordingFramesSPBreath = zeros(rows, cols, numFramesForSPBreath);
for i = 1:numFramesForSPBreath
    img = double(imread(fullfile(recordingPathBreath, recordingImagesBreath(i).name)));
    recordingFramesSPBreath(:,:,i) = img;
end

backgroundSubtractedFramesSPBreath = recordingFramesSPBreath - darkBackgroundImage;
meanFrameSPBreath = mean(backgroundSubtractedFramesSPBreath, 3);
varianceWindowSPBreath = stdfilt(backgroundSubtractedFramesSPBreath, true([windowSize, windowSize])) .^ 2;
averageVarianceWindowSPBreath = mean(varianceWindowSPBreath, 3);
K_f_squared_ROI_Breath = zeros(numRecordingFramesBreath, 1);
for k = 1:numRecordingFramesBreath
    frame = double(imread(fullfile(recordingPathBreath, recordingImagesBreath(k).name))) - darkBackgroundImage;
    meanFrame = imboxfilt(frame, [windowSize, windowSize]);
    varWindow = stdfilt(frame, true([windowSize, windowSize])).^2;
    
    % Calculate K_raw^2
    K_raw_squared = varWindow ./ (meanFrame .^ 2);
    
    % Calculate K_s^2
    K_s_squared = G ./ meanFrame;
    
    % Calculate K_q^2
    K_q_squared = 1 ./ (12 * meanFrame .^ 2);
    
    % Calculate K_f^2
    K_f_squared = K_raw_squared - K_s_squared - K_q_squared;
    
    % Calculate K_f^2 inside ROI
    K_f_squared_ROI_Breath(k) = mean(K_f_squared(roiMask));
end

save('K_f_squared_ROI_Breath.mat', 'K_f_squared_ROI_Breath');

% 11. Plot K_f^2 versus time for FR20hz_Gain24_expT15ms_Hana
timeFR20hz = (0:numRecordingFrames-1) / 20; % Assuming 20Hz frame rate
figure;
plot(timeFR20hz, K_f_squared_ROI, 'b', 'LineWidth', 1.5);
title('\langle K_f^2 \rangle vs Time for FR20hz_Gain24_expT15ms_Hana');
xlabel('Time (s)');
ylabel('\langle K_f^2 \rangle');
grid on;
saveas(gcf, 'K_f_squared_FR20hz_Gain24_expT15ms_Hana.png');

% Plot K_f^2 versus time for FR20hz_Gain24_expT15ms_Hana_breath
timeFR20hz_breath = (0:numRecordingFramesBreath-1) / 20; % Assuming 20Hz frame rate
figure;
plot(timeFR20hz_breath, K_f_squared_ROI_Breath, 'b', 'LineWidth', 1.5);
title('\langle K_f^2 \rangle vs Time for FR20hz_Gain24_expT15ms_Hana_breath');
xlabel('Time (s)');
ylabel('\langle K_f^2 \rangle');
grid on;
ylims = get(gca, 'YLim');
taskStart = [30, 90, 150, 210];
taskDuration = 30; 
taskColor = [1, 0, 0];

for iter_i = 1:numel(taskStart)
    patch([taskStart(iter_i), taskStart(iter_i) + taskDuration, taskStart(iter_i) + taskDuration, taskStart(iter_i)], ...
          [ylims(1), ylims(1), ylims(2), ylims(2)], taskColor, 'EdgeColor', 'none', 'FaceAlpha', 0.15);
end

set(gca, 'YLim', ylims);
legend('K_f^2', 'Breath Hold Periods');
saveas(gcf, 'K_f_squared_FR20hz_Gain24_expT15ms_Hana_breath.png');
