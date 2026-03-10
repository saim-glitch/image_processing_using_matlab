%% ========================================================================
%  TARGET 3: Develop Equations to Define Geometric Primitives
%  ========================================================================
%  Recognition by Components (RBC) Framework
%  ------------------------------------------
%  This script defines the mathematical equations that characterise each
%  of the four geometric primitives and applies them to classify every
%  detected region.
%
%  Primitives:  CIRCLE, TRIANGLE, SQUARE, RECTANGLE
%
%  Five key equations:
%    1. Circularity  = (4*pi*A) / P^2        [1=circle, 0.785=square]
%    2. Aspect Ratio = MajorAxis / MinorAxis  [1=square/circle, >1=rect]
%    3. Solidity     = A / A_convex           [1=convex shape]
%    4. Extent       = A / A_boundingbox      [~0.5=triangle, ~0.78=circle]
%    5. Vertex Count from Douglas-Peucker polygon approximation
%
%  Requires : Target 1 and Target 2 to have been run first.
%
%  Author : [Your Name]
%  Date   : 2025
%  Module : Cognitive Computing / Computer Vision
%  ========================================================================

clear; clc; close all;

%% ---- 3.1  Configuration ------------------------------------------------
datasetPath = 'Image_Datasets';
outputPath  = 'preprocessed_output';
validExt    = {'.jpg','.jpeg','.png','.bmp','.tif','.tiff'};

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

fprintf('Target 3: Geometric Primitive Classification\n');
fprintf('=============================================\n\n');

%% ---- 3.2  Equations & Thresholds ----------------------------------------
%
%  EQUATION 1 - Circularity (Form Factor):
%       C = (4 * pi * A) / P^2
%       Perfect circle: C = 1.0
%       Square:         C = pi/4  ~ 0.785
%       Equilateral triangle: C ~ 0.604
%
%  EQUATION 2 - Aspect Ratio:
%       AR = MajorAxisLength / MinorAxisLength
%       Square/Circle: AR ~ 1.0
%       Rectangle:     AR > 1.25
%
%  EQUATION 3 - Solidity:
%       S = Area / ConvexHullArea
%       All primitives (convex): S ~ 1.0
%       Compound/concave shapes: S < 1.0
%
%  EQUATION 4 - Extent:
%       E = Area / BoundingBoxArea
%       Circle:    E ~ pi/4 ~ 0.785
%       Square:    E ~ 1.0 (if axis-aligned)
%       Rectangle: E ~ 1.0 (if axis-aligned)
%       Triangle:  E ~ 0.5
%
%  EQUATION 5 - Vertex Count (Douglas-Peucker):
%       Circle:    0 meaningful corners (smooth boundary)
%       Triangle:  3
%       Square:    4
%       Rectangle: 4
%
%  Decision thresholds:
CIRC_THRESH    = 0.82;    % Above = circle
AR_SQUARE_MAX  = 1.25;    % Below = square; above = rectangle
EXTENT_TRI_MAX = 0.65;    % Triangle extent ceiling
SOLIDITY_MIN   = 0.85;    % Minimum for a clean convex primitive

%% ---- 3.3  Classification Loop ------------------------------------------
allResults = {};

for idx = 1:length(imageFiles)

    imgName = imageNames{idx};
    napFile = fullfile(outputPath, [imgName '_NAPs.mat']);
    matFile = fullfile(outputPath, [imgName '_preprocessed.mat']);

    if ~exist(napFile, 'file') || ~exist(matFile, 'file')
        fprintf('[SKIP] %s - run Targets 1 & 2 first.\n', imgName);
        continue;
    end
    load(napFile);
    load(matFile, 'originalImg', 'bwImg');

    fprintf('\nImage: %s  (%d valid regions)\n', imgName, length(validRegions));
    fprintf('  %-6s  %-7s  %-5s  %-7s  %-7s  %-5s  => Result\n', ...
            'Reg', 'Circ', 'AR', 'Solid', 'Extent', '#Crn');
    fprintf('  %s\n', repmat('-', 1, 65));

    % Prepare annotated figure
    figure('Name', ['Target 3: ' imgName], 'NumberTitle', 'off', ...
           'Position', [40 40 900 700]);
    imshow(originalImg); hold on;

    for ri = 1:length(validRegions)
        r = validRegions(ri);

        A = regionProps(r).Area;
        P = regionProps(r).Perimeter;

        % --- Equation 1: Circularity ---
        circularity = (4 * pi * A) / (P^2);

        % --- Equation 2: Aspect Ratio ---
        aspectRatio = regionProps(r).MajorAxisLength / ...
                      max(regionProps(r).MinorAxisLength, 1);

        % --- Equation 3: Solidity ---
        solidity = regionProps(r).Solidity;

        % --- Equation 4: Extent ---
        bb     = regionProps(r).BoundingBox;
        bbArea = bb(3) * bb(4);
        extent = A / max(bbArea, 1);

        % --- Equation 5: Corner count ---
        numCorners = 0;
        numStraight = 0;  numCurved = 0;
        if r <= length(NAPs) && isfield(NAPs(r), 'NumCorners')
            numCorners  = NAPs(r).NumCorners;
            numStraight = NAPs(r).Collinearity;
            numCurved   = NAPs(r).CurvilinearCount;
        end

        % ---- Classification Decision Tree --------------------------------
        classification = 'Unknown';
        confidence     = 0;

        % Rule 1: CIRCLE
        %  High circularity AND boundary mostly curved
        if circularity > CIRC_THRESH && solidity > SOLIDITY_MIN
            classification = 'Circle';
            confidence = min(circularity, 1.0) * 100;

        % Rule 2: TRIANGLE
        %  ~3 corners, low extent (~0.5), convex
        elseif numCorners >= 2 && numCorners <= 4 && ...
               extent < EXTENT_TRI_MAX && solidity > SOLIDITY_MIN && ...
               circularity < 0.75
            classification = 'Triangle';
            confidence = solidity * 100;

        % Rule 3: SQUARE
        %  ~4 corners, aspect ratio near 1, not circular
        elseif numCorners >= 3 && numCorners <= 5 && ...
               aspectRatio < AR_SQUARE_MAX && solidity > SOLIDITY_MIN && ...
               circularity < CIRC_THRESH && extent >= EXTENT_TRI_MAX
            classification = 'Square';
            confidence = solidity * 100;

        % Rule 4: RECTANGLE
        %  ~4 corners, aspect ratio > 1.25, not circular
        elseif numCorners >= 3 && numCorners <= 6 && ...
               aspectRatio >= AR_SQUARE_MAX && solidity > SOLIDITY_MIN && ...
               circularity < CIRC_THRESH
            classification = 'Rectangle';
            confidence = solidity * 100;

        % Fallback rules using metric ranges only
        elseif circularity > CIRC_THRESH
            classification = 'Circle';
            confidence = circularity * 100;
        elseif extent < 0.55 && solidity > 0.85
            classification = 'Triangle';
            confidence = 70;
        elseif aspectRatio < AR_SQUARE_MAX && circularity >= 0.65
            classification = 'Square';
            confidence = 65;
        elseif aspectRatio >= AR_SQUARE_MAX && circularity >= 0.55
            classification = 'Rectangle';
            confidence = 65;
        end

        % Print row
        fprintf('  %-6d  %6.3f  %4.2f  %6.3f  %6.3f  %4d  => %s (%.0f%%)\n', ...
            r, circularity, aspectRatio, solidity, extent, numCorners, ...
            classification, confidence);

        % Annotate on image
        centroid = regionProps(r).Centroid;
        bb_r     = regionProps(r).BoundingBox;

        % Colour code by shape type
        switch classification
            case 'Circle',    boxCol = 'g';
            case 'Triangle',  boxCol = 'y';
            case 'Square',    boxCol = 'c';
            case 'Rectangle', boxCol = 'm';
            otherwise,        boxCol = 'r';
        end

        rectangle('Position', bb_r, 'EdgeColor', boxCol, 'LineWidth', 2);
        text(centroid(1), centroid(2)-15, classification, ...
             'Color', 'w', 'FontSize', 10, 'FontWeight', 'bold', ...
             'HorizontalAlignment', 'center', ...
             'BackgroundColor', boxCol);

        % Store result
        allResults{end+1} = struct( ...
            'Image', imgName, 'Region', r, ...
            'Classification', classification, 'Confidence', confidence, ...
            'Circularity', circularity, 'AspectRatio', aspectRatio, ...
            'Solidity', solidity, 'Extent', extent, ...
            'NumCorners', numCorners);
    end

    hold off;
    sgtitle(['Target 3 - Primitive Classification: Image ' imgName], ...
            'FontSize', 14, 'FontWeight', 'bold');
    saveas(gcf, fullfile(outputPath, [imgName '_T3_classification.png']));
end

%% ---- 3.4  Summary Table ------------------------------------------------
fprintf('\n\n========== CLASSIFICATION SUMMARY ==========\n');
fprintf('%-8s %-6s %-12s %6s %5s %6s %6s %5s\n', ...
    'Image', 'Reg', 'Class', 'Circ', 'AR', 'Solid', 'Ext', 'Conf');
fprintf('%s\n', repmat('=', 1, 65));

for i = 1:length(allResults)
    r = allResults{i};
    fprintf('%-8s %-6d %-12s %5.3f %4.2f %5.3f %5.3f %4.0f%%\n', ...
        r.Image, r.Region, r.Classification, ...
        r.Circularity, r.AspectRatio, r.Solidity, r.Extent, r.Confidence);
end

%% ---- 3.5  Save ----------------------------------------------------------
save(fullfile(outputPath, 'Target3_AllResults.mat'), 'allResults');

fprintf('\n========================================\n');
fprintf('  TARGET 3 COMPLETE\n');
fprintf('========================================\n');


%% ========================================================================
%  REFERENCE: Formal Mathematical Definitions
%  ========================================================================
%
%  CIRCLE:  (x - cx)^2 + (y - cy)^2 = r^2
%     Area = pi * r^2,  Perimeter = 2 * pi * r
%     Circularity = (4*pi*pi*r^2) / (2*pi*r)^2 = 1.0
%
%  TRIANGLE (vertices v1, v2, v3):
%     Area (Shoelace) = 0.5 * |x1(y2-y3) + x2(y3-y1) + x3(y1-y2)|
%     Perimeter = d(v1,v2) + d(v2,v3) + d(v3,v1)
%     Equilateral: Circularity ~ 0.604, Extent ~ 0.5
%
%  SQUARE (side s):
%     Area = s^2,  Perimeter = 4*s
%     Circularity = (4*pi*s^2) / (4s)^2 = pi/4 ~ 0.785
%     Extent ~ 1.0,  AR ~ 1.0
%
%  RECTANGLE (width w, height h, w != h):
%     Area = w*h,  Perimeter = 2*(w+h)
%     Circularity = (4*pi*w*h) / (2*(w+h))^2
%     Extent ~ 1.0,  AR = max(w,h)/min(w,h) > 1
%  ========================================================================
