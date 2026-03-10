# Recognition by Components (RBC) Framework
## Targets 1-3: Geometric Primitive Detection

### How to Run
1. Open MATLAB (R2020a+, needs Image Processing Toolbox)
2. `cd` to this folder
3. Run: `RBC_Main`

### Target 1 - Pre-Processing
- Virtual images (1, 2, 9): Grayscale -> Otsu -> Invert -> White on black
- Physical images (3-8): HSV saturation thresholding -> Morphological clean
- Output: side-by-side Original | Segmented (white shapes on black)

### Target 2 - NAPs & Concavity
- Connected-component labelling to isolate each shape
- Douglas-Peucker corner detection (cotermination)
- Boundary curvature analysis (collinearity/curvilinearity)
- Symmetry scoring via flip-overlap
- Parallel edge pair counting
- Concavity = convex hull minus actual region

### Target 3 - Primitive Equations
Five equations in a decision tree:
- Circularity = 4*pi*A / P^2
- Aspect Ratio = MajorAxis / MinorAxis
- Solidity = Area / ConvexHullArea
- Extent = Area / BoundingBoxArea
- Vertex Count (Douglas-Peucker)
