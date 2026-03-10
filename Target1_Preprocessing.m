%% ========================================================================
%  TARGET 1: Reading Images and Pre-Processing to a Workable Level
%  ========================================================================
%  Recognition by Components (RBC) Framework
%  ------------------------------------------
%  This script reads all images from 'Image_Datasets' and produces a clean
%  binary segmentation: WHITE shapes on a BLACK background.
%
%  Two segmentation strategies are used depending on the image type:
%
%    VIRTUAL images  (1, 2, 9):  Black shapes on white background
%       -> Grayscale -> Otsu threshold -> Invert -> Morphological clean
%
%    PHYSICAL images (3-8):  Coloured wooden blocks on grey/white surface
%       -> Convert to HSV -> Threshold on Saturation channel (coloured
%          objects have high saturation, grey background has low) ->
%          Morphological clean -> Fill holes
%
%  Output: For each image, a side-by-side figure showing:
%            Original Image  |  Segmented Binary (white on black)
%
%  Author : [Your Name]
%  Date   : 2025
%  Module : Cognitive Computing / Computer Vision
%  ========================================================================

clear; clc; close all;

%% ---- 1.1  Configuration ------------------------------------------------
datasetPath = 'Image_Datasets';
outputPath  = 'preprocessed_output';
validExt    = {'.jpg','.jpeg','.png','.bmp','.tif','.tiff'};

if ~exist(outputPath, 'dir')
    mkdir(outputPath);
end

%% ---- 1.2  Build Image File List -----------------------------------------
fileList   = dir(datasetPath);
imageFiles = {};
imageNames = {};
for i = 1:length(fileList)
    [~, name, ext] = fileparts(fileList(i).name);
    if any(strcmpi(ext, validExt))
        imageFiles{end+1} = fullfile(datasetPath, fileList(i).name);
        imageNames{end+1} = name;
    end
end
fprintf('Found %d images in "%s"\n\n', length(imageFiles), datasetPath);

%% ---- 1.3  Define which images are virtual vs physical -------------------
%  Virtual images (black shapes on white): need inversion
%  Physical images (coloured objects on grey): need colour segmentation
%
%  You can adjust these lists if your dataset differs.
virtualImages  = {'1', '2', '9'};       % synthetic / computer-generated
physicalImages = {'3', '4', '5', '6', '7', '8'};  % photographs of objects

%% ---- 1.4  Pre-Processing Loop ------------------------------------------
for idx = 1:length(imageFiles)

    originalImg = imread(imageFiles{idx});
    imgName     = imageNames{idx};
    fprintf('Processing image %d/%d : %s\n', idx, length(imageFiles), imgName);

    % Handle RGBA (drop alpha channel)
    if size(originalImg, 3) == 4
        originalImg = originalImg(:,:,1:3);
    end

    % ------------------------------------------------------------------
    %  Determine image type and apply appropriate segmentation
    % ------------------------------------------------------------------
    if ismember(imgName, virtualImages)
        % ==============================================================
        %  VIRTUAL IMAGE: Black shapes on white background
        %  Strategy: Grayscale -> Threshold -> Invert -> Clean
        % ==============================================================

        % Convert to grayscale
        if size(originalImg, 3) == 3
            grayImg = rgb2gray(originalImg);
        else
            grayImg = originalImg;
        end

        % Gaussian smoothing to reduce noise
        grayImg = imgaussfilt(grayImg, 1.5);

        % Otsu binarisation
        level   = graythresh(grayImg);
        bwImg   = imbinarize(grayImg, level);

        % Invert: shapes were black (0), we want white (1) on black (0)
        bwImg = ~bwImg;

        % Morphological clean-up
        se    = strel('disk', 3);
        bwImg = imclose(bwImg, se);          % bridge small gaps
        bwImg = imfill(bwImg, 'holes');      % fill interior holes
        bwImg = imopen(bwImg, strel('disk', 2));  % remove small noise
        bwImg = bwareaopen(bwImg, 300);      % remove tiny blobs

    elseif ismember(imgName, physicalImages)
        % ==============================================================
        %  PHYSICAL IMAGE: Coloured objects on grey/white background
        %  Strategy: HSV Saturation threshold -> Clean -> Fill
        %
        %  The wooden blocks (green, yellow, red, blue) are SATURATED in
        %  colour while the background surface is neutral grey/white
        %  (very low saturation). Thresholding on the S channel cleanly
        %  separates foreground objects from the background.
        % ==============================================================

        % Convert RGB to HSV colour space
        hsvImg = rgb2hsv(originalImg);
        satChannel = hsvImg(:,:,2);   % Saturation channel
        valChannel = hsvImg(:,:,3);   % Value (brightness) channel

        % Threshold on saturation: objects have S > 0.25
        satThresh = 0.25;
        bwImg = satChannel > satThresh;

        % Also exclude very dark pixels (shadows)
        bwImg = bwImg & (valChannel > 0.20);

        % Morphological clean-up
        se    = strel('disk', 7);
        bwImg = imclose(bwImg, se);          % close gaps
        bwImg = imfill(bwImg, 'holes');      % fill shape interiors
        bwImg = imopen(bwImg, strel('disk', 5));   % smooth edges
        bwImg = bwareaopen(bwImg, 2000);     % remove small noise

        % Additional smoothing pass for cleaner edges
        se2   = strel('disk', 3);
        bwImg = imerode(bwImg, se2);
        bwImg = imdilate(bwImg, se2);

    else
        % Default: treat as virtual
        if size(originalImg, 3) == 3
            grayImg = rgb2gray(originalImg);
        else
            grayImg = originalImg;
        end
        level = graythresh(grayImg);
        bwImg = ~imbinarize(grayImg, level);
        bwImg = imfill(bwImg, 'holes');
        bwImg = bwareaopen(bwImg, 300);
    end

    % ------------------------------------------------------------------
    %  Display: Original  |  Segmented (white on black)
    % ------------------------------------------------------------------
    figure('Name', ['Target 1: ' imgName], 'NumberTitle', 'off', ...
           'Position', [50 100 1000 450]);

    subplot(1,2,1);
    imshow(originalImg);
    title(['Original: ' imgName], 'FontSize', 12);

    subplot(1,2,2);
    imshow(bwImg);
    title(['Segmented: ' imgName], 'FontSize', 12);

    sgtitle(['Target 1 - Pre-Processing: Image ' imgName], ...
            'FontSize', 14, 'FontWeight', 'bold');

    % Save figure
    saveas(gcf, fullfile(outputPath, [imgName '_T1_result.png']));

    % Save binary result for Target 2
    save(fullfile(outputPath, [imgName '_preprocessed.mat']), ...
         'originalImg', 'bwImg');

    fprintf('  -> Saved: %s_T1_result.png\n', imgName);
end

%% ---- 1.5  Create combined grid for single-object physical images --------
%  This matches the lecturer's layout: row of originals above row of
%  segmented images for the individual object photos (4, 5, 6, 7, 8).
singleObjects = {'4', '6', '7', '8'};   % circle, triangle, rectangle, square
validSingles  = {};

for i = 1:length(singleObjects)
    matFile = fullfile(outputPath, [singleObjects{i} '_preprocessed.mat']);
    if exist(matFile, 'file')
        validSingles{end+1} = singleObjects{i};
    end
end

if ~isempty(validSingles)
    n = length(validSingles);
    figure('Name', 'Target 1: Individual Shapes', 'NumberTitle', 'off', ...
           'Position', [30 30 250*n 500]);

    for i = 1:n
        data = load(fullfile(outputPath, [validSingles{i} '_preprocessed.mat']));

        subplot(2, n, i);
        imshow(data.originalImg);
        title(['Image ' validSingles{i}], 'FontSize', 10);

        subplot(2, n, n+i);
        imshow(data.bwImg);
        title(['Segmented ' validSingles{i}], 'FontSize', 10);
    end

    sgtitle('Target 1 - Individual Shape Segmentation', ...
            'FontSize', 13, 'FontWeight', 'bold');
    saveas(gcf, fullfile(outputPath, 'T1_individual_shapes_grid.png'));
end

fprintf('\n========================================\n');
fprintf('  TARGET 1 COMPLETE - %d images processed\n', length(imageFiles));
fprintf('  Outputs saved to: %s/\n', outputPath);
fprintf('========================================\n');
