%% ========================================================================
%  TARGET 2: Identify Non-Accidental Properties & Segment Regions of
%            Concavity
%  ========================================================================
%  Recognition by Components (RBC) Framework
%  ------------------------------------------
%  This script takes the binary segmented images from Target 1 and:
%
%    1. Labels connected components (individual shape regions)
%    2. Extracts boundary contours for each region
%    3. Computes Non-Accidental Properties (NAPs) per Biederman (1987):
%         - Collinearity   : straight edges between vertices
%         - Curvilinearity  : curved edges (arcs)
%         - Symmetry        : reflective symmetry score
%         - Parallelism     : parallel edge-pair count
%         - Cotermination   : vertices / corners where edges meet
%    4. Segments concavity regions by comparing each shape to its
%       convex hull (deficit = concave area)
%
%  Output figures:
%    - Labelled regions with boundary overlays
%    - Convex hulls and concavity deficit regions
%    - Individual shape isolation (white on black, per region)
%
%  Requires : Target1_Preprocessing.m to have been run first.
%
%  Author : [Your Name]
%  Date   : 2025
%  Module : Cognitive Computing / Computer Vision
%  ========================================================================

clear; clc; close all;

%% ---- 2.1  Configuration ------------------------------------------------
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

fprintf('Target 2: NAPs & Concavity Segmentation\n');
fprintf('=========================================\n\n');

%% ---- 2.2  Main Processing Loop -----------------------------------------
for idx = 1:length(imageFiles)

    imgName = imageNames{idx};
    matFile = fullfile(outputPath, [imgName '_preprocessed.mat']);

    if ~exist(matFile, 'file')
        fprintf('  [SKIP] %s - run Target 1 first.\n', imgName);
        continue;
    end
    load(matFile, 'originalImg', 'bwImg');
    fprintf('Processing: %s\n', imgName);

    % ==================================================================
    %  STEP 1: Connected-Component Labelling
    %  Separate individual shapes in the binary image.
    % ==================================================================
    [labelledImg, numRegions] = bwlabel(bwImg, 8);
    regionProps = regionprops(labelledImg, 'BoundingBox', 'Area', ...
                  'Centroid', 'Perimeter', 'Solidity', 'Eccentricity', ...
                  'MajorAxisLength', 'MinorAxisLength', 'Orientation', ...
                  'ConvexHull', 'PixelIdxList');

    % Filter out tiny noise regions
    minArea = 500;
    validRegions = find([regionProps.Area] >= minArea);
    fprintf('  Found %d valid region(s) (of %d total)\n', ...
            length(validRegions), numRegions);

    % ==================================================================
    %  STEP 2: Boundary Tracing
    % ==================================================================
    boundaries = bwboundaries(bwImg, 'noholes');

    % ==================================================================
    %  STEP 3: Compute Non-Accidental Properties (NAPs)
    % ==================================================================
    NAPs = struct();

    for ri = 1:length(validRegions)
        r = validRegions(ri);

        % Get boundary for this region
        regionMask = (labelledImg == r);
        regBounds  = bwboundaries(regionMask, 'noholes');
        if isempty(regBounds)
            continue;
        end
        bnd = regBounds{1};   % Nx2 [row, col]

        % ---- 3a. Cotermination: Corner / Vertex Detection ----------------
        %  Douglas-Peucker polygon approximation to find vertices.
        epsilon   = 0.03 * regionProps(r).Perimeter;
        approxPoly = douglasPeucker(bnd, epsilon);
        numCorners = size(approxPoly, 1);

        % Remove duplicate start/end point if closed polygon
        if numCorners > 1 && isequal(approxPoly(1,:), approxPoly(end,:))
            approxPoly = approxPoly(1:end-1,:);
            numCorners = numCorners - 1;
        end

        NAPs(r).Corners    = approxPoly;
        NAPs(r).NumCorners = numCorners;

        % ---- 3b. Curvature along boundary --------------------------------
        k = computeBoundaryCurvature(bnd, 15);
        NAPs(r).Curvature = k;

        % ---- 3c. Collinearity & Curvilinearity ---------------------------
        [straightSegs, curvedSegs] = classifyEdgeSegments(bnd, approxPoly, k);
        NAPs(r).StraightSegments  = straightSegs;
        NAPs(r).CurvedSegments    = curvedSegs;
        NAPs(r).Collinearity      = length(straightSegs);
        NAPs(r).CurvilinearCount  = length(curvedSegs);

        % ---- 3d. Symmetry ------------------------------------------------
        NAPs(r).SymmetryScore = computeSymmetryScore(regionMask);

        % ---- 3e. Parallelism ---------------------------------------------
        NAPs(r).ParallelPairs = countParallelPairs(straightSegs);

        % ---- 3f. Summary features ----------------------------------------
        NAPs(r).Eccentricity = regionProps(r).Eccentricity;
        NAPs(r).Solidity     = regionProps(r).Solidity;
        NAPs(r).Area         = regionProps(r).Area;
        NAPs(r).Perimeter    = regionProps(r).Perimeter;

        fprintf('    Region %d: Corners=%d, Straight=%d, Curved=%d, Sym=%.2f, Parallel=%d\n', ...
            r, numCorners, NAPs(r).Collinearity, NAPs(r).CurvilinearCount, ...
            NAPs(r).SymmetryScore, NAPs(r).ParallelPairs);
    end

    % ==================================================================
    %  STEP 4: Concavity Segmentation
    %  Compare each region's actual area to its convex hull.
    %  Deficit = convex hull area - region area = concavity.
    % ==================================================================
    concavityData = struct();

    for ri = 1:length(validRegions)
        r = validRegions(ri);

        regionMask = (labelledImg == r);
        convexMask = bwconvhull(regionMask);
        concaveMask = convexMask & ~regionMask;

        [concLabel, numConc] = bwlabel(concaveMask);

        concavityData(r).ConcaveMask     = concaveMask;
        concavityData(r).ConvexHull      = regionProps(r).ConvexHull;
        concavityData(r).DeficitArea     = sum(concaveMask(:));
        concavityData(r).SolidityRatio   = regionProps(r).Solidity;
        concavityData(r).NumConcavities  = numConc;
        concavityData(r).ConcavityLabel  = concLabel;

        fprintf('    Region %d: Concavities=%d, Solidity=%.3f, Deficit=%d px\n', ...
            r, numConc, regionProps(r).Solidity, concavityData(r).DeficitArea);
    end

    % ==================================================================
    %  STEP 5: Visualisation
    % ==================================================================

    % --- Figure A: Individual region isolation (white on black) -----------
    %  Show each detected region as a separate sub-image, matching the
    %  lecturer's expected output format.
    nValid = length(validRegions);
    if nValid > 0
        cols = min(nValid, 4);
        rows = ceil(nValid / cols);

        figure('Name', ['Target 2 - Regions: ' imgName], ...
               'NumberTitle', 'off', 'Position', [30 30 300*cols 300*rows]);

        for ri = 1:nValid
            r = validRegions(ri);
            regionMask = (labelledImg == r);

            subplot(rows, cols, ri);
            imshow(regionMask);
            title(sprintf('Region %d (A=%d)', r, regionProps(r).Area), ...
                  'FontSize', 10);
        end

        sgtitle(['Target 2 - Segmented Regions: Image ' imgName], ...
                'FontSize', 13, 'FontWeight', 'bold');
        saveas(gcf, fullfile(outputPath, [imgName '_T2_regions.png']));
    end

    % --- Figure B: Boundaries, corners, and convex hulls ------------------
    figure('Name', ['Target 2 - NAPs: ' imgName], 'NumberTitle', 'off', ...
           'Position', [50 50 1100 500]);

    % Left: labelled regions with boundaries and corners
    subplot(1,2,1);
    imshow(label2rgb(labelledImg, 'jet', 'k', 'shuffle'));
    hold on;
    for ri = 1:length(validRegions)
        r = validRegions(ri);
        if r <= length(NAPs) && isfield(NAPs(r), 'Corners') && ~isempty(NAPs(r).Corners)
            crnrs = NAPs(r).Corners;
            plot(crnrs(:,2), crnrs(:,1), 'r*', 'MarkerSize', 12, 'LineWidth', 2);
        end
    end
    for b = 1:length(boundaries)
        bnd = boundaries{b};
        plot(bnd(:,2), bnd(:,1), 'w-', 'LineWidth', 1);
    end
    title('Regions, Boundaries & Corners', 'FontSize', 11);
    hold off;

    % Right: convex hulls and concavity regions
    subplot(1,2,2);
    % Build composite concavity visualisation
    concavityVis = zeros(size(bwImg));
    for ri = 1:length(validRegions)
        r = validRegions(ri);
        if r <= length(concavityData) && isfield(concavityData(r), 'ConcaveMask')
            concavityVis = concavityVis | concavityData(r).ConcaveMask;
        end
    end
    % Show binary shapes in grey, concavity regions in white
    composite = double(bwImg) * 0.4 + double(concavityVis) * 0.6;
    imshow(composite, []);
    hold on;
    for ri = 1:length(validRegions)
        r = validRegions(ri);
        hull = regionProps(r).ConvexHull;
        plot(hull(:,1), hull(:,2), 'r-', 'LineWidth', 2);
    end
    title('Convex Hulls (red) & Concavity Regions (bright)', 'FontSize', 11);
    hold off;

    sgtitle(['Target 2 - Non-Accidental Properties: Image ' imgName], ...
            'FontSize', 13, 'FontWeight', 'bold');
    saveas(gcf, fullfile(outputPath, [imgName '_T2_NAPs.png']));

    % --- Save data for Target 3 -------------------------------------------
    save(fullfile(outputPath, [imgName '_NAPs.mat']), ...
         'NAPs', 'concavityData', 'regionProps', 'boundaries', ...
         'labelledImg', 'numRegions', 'validRegions');

    fprintf('  -> Saved Target 2 data for %s\n\n', imgName);
end

fprintf('========================================\n');
fprintf('  TARGET 2 COMPLETE\n');
fprintf('========================================\n');


%% ========================================================================
%  HELPER FUNCTIONS
%  ========================================================================

function approxPoly = douglasPeucker(points, epsilon)
% DOUGLASPEUCKER  Simplify polyline using Douglas-Peucker algorithm.
%  Returns the reduced set of vertices that approximate the boundary
%  within tolerance epsilon. These are the detected corners.
    if size(points,1) < 3
        approxPoly = points;
        return;
    end
    dMax  = 0;
    index = 0;
    pStart = points(1,:);
    pEnd   = points(end,:);

    for i = 2:(size(points,1)-1)
        d = pointToLineDistance(points(i,:), pStart, pEnd);
        if d > dMax
            dMax  = d;
            index = i;
        end
    end

    if dMax > epsilon
        rec1 = douglasPeucker(points(1:index,:), epsilon);
        rec2 = douglasPeucker(points(index:end,:), epsilon);
        approxPoly = [rec1(1:end-1,:); rec2];
    else
        approxPoly = [pStart; pEnd];
    end
end

function d = pointToLineDistance(pt, lineStart, lineEnd)
    num = abs((lineEnd(2)-lineStart(2))*pt(1) - ...
              (lineEnd(1)-lineStart(1))*pt(2) + ...
               lineEnd(1)*lineStart(2) - lineEnd(2)*lineStart(1));
    den = sqrt((lineEnd(2)-lineStart(2))^2 + (lineEnd(1)-lineStart(1))^2);
    if den == 0
        d = norm(pt - lineStart);
    else
        d = num / den;
    end
end

function k = computeBoundaryCurvature(bnd, winSize)
% COMPUTEBOUNDARYCURVATURE  Discrete curvature at each boundary point.
    N = size(bnd, 1);
    k = zeros(N, 1);
    half = floor(winSize/2);
    for i = 1:N
        idxPrev = mod(i - half - 1, N) + 1;
        idxNext = mod(i + half - 1, N) + 1;
        v1 = bnd(i,:)       - bnd(idxPrev,:);
        v2 = bnd(idxNext,:) - bnd(i,:);
        crossVal = v1(1)*v2(2) - v1(2)*v2(1);
        dotVal   = dot(v1, v2);
        k(i) = atan2(crossVal, dotVal);
    end
end

function [straightSegs, curvedSegs] = classifyEdgeSegments(bnd, corners, curvature)
% CLASSIFYEDGESEGMENTS  Split boundary into straight / curved segments.
    straightSegs = {};
    curvedSegs   = {};
    numCorners   = size(corners, 1);

    if numCorners < 2
        if mean(abs(curvature)) < 0.15
            straightSegs{1}.Points = bnd;
            straightSegs{1}.Angle = 0;
        else
            curvedSegs{1}.Points = bnd;
        end
        return;
    end

    % Map corner points to boundary indices
    cornerIdx = zeros(numCorners, 1);
    for c = 1:numCorners
        dists = sum((bnd - corners(c,:)).^2, 2);
        [~, cornerIdx(c)] = min(dists);
    end
    cornerIdx = sort(cornerIdx);

    for c = 1:length(cornerIdx)
        if c < length(cornerIdx)
            segIdx = cornerIdx(c):cornerIdx(c+1);
        else
            segIdx = [cornerIdx(c):size(bnd,1), 1:cornerIdx(1)];
        end
        if length(segIdx) < 3, continue; end

        segCurv     = curvature(segIdx);
        meanAbsCurv = mean(abs(segCurv));

        seg.Points = bnd(segIdx,:);
        vec = bnd(segIdx(end),:) - bnd(segIdx(1),:);
        seg.Angle = atan2d(vec(1), vec(2));

        if meanAbsCurv < 0.15
            straightSegs{end+1} = seg;
        else
            curvedSegs{end+1} = seg;
        end
    end
end

function score = computeSymmetryScore(regionMask)
% COMPUTESYMMETRYSCORE  Reflective symmetry via flip-overlap.
    lr_flip = fliplr(regionMask);
    tb_flip = flipud(regionMask);
    total   = max(sum(regionMask(:)), 1);
    overlap_lr = sum(regionMask(:) & lr_flip(:)) / total;
    overlap_tb = sum(regionMask(:) & tb_flip(:)) / total;
    score = max(overlap_lr, overlap_tb);
end

function numPairs = countParallelPairs(straightSegs)
% COUNTPARALLELPAIRS  Count approx-parallel straight segment pairs.
    numPairs = 0;
    n = length(straightSegs);
    for i = 1:n
        for j = (i+1):n
            angleDiff = abs(straightSegs{i}.Angle - straightSegs{j}.Angle);
            angleDiff = min(angleDiff, 180 - angleDiff);
            if angleDiff < 12
                numPairs = numPairs + 1;
            end
        end
    end
end
