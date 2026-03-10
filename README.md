<p align="center">
  <img src="docs/images/pipeline_overview.png" alt="RBC Pipeline" width="850"/>
</p>

<h1 align="center">Recognition by Components (RBC) Framework</h1>

<p align="center">
  <strong>A Cognitive Computer Vision Framework for Geometric Primitive Detection</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/MATLAB-R2020a+-orange?style=flat-square&logo=mathworks" alt="MATLAB"/>
  <img src="https://img.shields.io/badge/Toolbox-Image_Processing-blue?style=flat-square" alt="Toolbox"/>
  <img src="https://img.shields.io/badge/Status-Targets_1--3_Complete-brightgreen?style=flat-square" alt="Status"/>
  <img src="https://img.shields.io/badge/Shapes-Circle_%7C_Triangle_%7C_Square_%7C_Rectangle-purple?style=flat-square" alt="Shapes"/>
</p>

---

## Overview

This framework implements **Recognition by Components (RBC)** — a cognitive approach to object recognition inspired by Biederman's (1987) theory of human visual perception. Rather than relying on exhaustive training datasets, the system decomposes images into **geometric primitives** (geons) by analysing viewpoint-invariant features called **Non-Accidental Properties**.

The framework detects and classifies four primitives — **circles, triangles, squares, and rectangles** — from both synthetic (virtual) images and photographs of real-world physical objects.

<p align="center">
  <img src="docs/images/dataset_overview.png" alt="Dataset Overview" width="600"/>
</p>
<p align="center"><em>Dataset: 9 images spanning virtual shapes, physical wooden blocks, and composite objects</em></p>

---

## Results

### Target 1 — Image Segmentation

Virtual images (black-on-white) are segmented via grayscale thresholding with inversion. Physical photographs use **HSV saturation-based segmentation** to cleanly separate coloured objects from the neutral background.

<p align="center">
  <img src="docs/images/target1_virtual_demo.png" alt="Virtual Segmentation" width="750"/>
</p>
<p align="center"><em>Virtual image: Otsu threshold + inversion produces clean white-on-black output</em></p>

<p align="center">
  <img src="docs/images/target1_physical_demo.png" alt="Physical Segmentation" width="750"/>
</p>
<p align="center"><em>Physical objects: HSV saturation thresholding isolates each coloured shape</em></p>

### Target 2 — Non-Accidental Properties & Concavity

The framework extracts five **Non-Accidental Properties** per Biederman's theory, then segments **concavity regions** by comparing each shape to its convex hull.

<p align="center">
  <img src="docs/images/target2_concavity_demo.png" alt="Concavity Segmentation" width="750"/>
</p>
<p align="center"><em>Stacked blocks: segmentation → concavity analysis reveals shape boundaries</em></p>

### Target 3 — Geometric Classification

Five mathematical equations feed a hierarchical decision tree to classify each detected region:

<p align="center">
  <img src="docs/images/equations_reference.png" alt="Classification Equations" width="600"/>
</p>

---

## Project Structure

```
RBC_Framework/
├── RBC_Main.m                      # Master runner — executes all 3 targets
├── Target1_Preprocessing.m         # Image reading & binary segmentation
├── Target2_NAPs_Concavity.m        # NAP extraction & concavity analysis
├── Target3_PrimitiveEquations.m    # Equation-based classification
├── Image_Datasets/                 # Input images (1.png – 9.png)
│   ├── 1.png                       # Virtual: multiple shapes scattered
│   ├── 2.png                       # Virtual: triangle, square, circle stacked
│   ├── 3.png                       # Physical: 4 coloured wooden blocks
│   ├── 4.png                       # Physical: green circle (single)
│   ├── 5.png                       # Physical: 4 blocks stacked vertically
│   ├── 6.png                       # Physical: yellow triangle (single)
│   ├── 7.png                       # Physical: red rectangle (single)
│   ├── 8.png                       # Physical: blue square (single)
│   └── 9.png                       # Virtual: composite (person, house, car)
├── preprocessed_output/            # Auto-generated results directory
└── docs/
    └── images/                     # README screenshots and diagrams
```

---

## Quick Start

### Prerequisites

- **MATLAB R2020a** or later
- **Image Processing Toolbox** (`imgaussfilt`, `adapthisteq`, `regionprops`, `bwboundaries`, `bwconvhull`, etc.)

### Running the Framework

```matlab
% 1. Clone or download this repository
% 2. Open MATLAB and navigate to the project folder
cd('path/to/RBC_Framework')

% 3. Run all three targets in sequence
RBC_Main

% Or run each target individually:
Target1_Preprocessing
Target2_NAPs_Concavity
Target3_PrimitiveEquations
```

All output figures and `.mat` data files are saved to `preprocessed_output/`.

---

## Technical Details

### Target 1 — Pre-Processing Pipeline

The segmentation strategy adapts to the image type:

| Image Type | Strategy | Key Function |
|:-----------|:---------|:-------------|
| **Virtual** (1, 2, 9) | Grayscale → Otsu threshold → Invert → Morphological clean | `graythresh`, `imbinarize` |
| **Physical** (3–8) | RGB → HSV → Saturation threshold (S > 0.25) → Morphological clean | `rgb2hsv`, `imclose`, `imfill` |

**Why HSV saturation?** The wooden blocks are richly coloured (high saturation) while the grey/white background surface has near-zero saturation. Thresholding the S-channel cleanly separates foreground from background regardless of lighting variations.

### Target 2 — Non-Accidental Properties (Biederman, 1987)

NAPs are viewpoint-invariant features that remain stable across different viewing angles:

| Property | Description | Method |
|:---------|:------------|:-------|
| **Collinearity** | Straight edges between vertices | Curvature analysis on boundary segments |
| **Curvilinearity** | Curved edges (arcs) | Mean absolute curvature > threshold |
| **Symmetry** | Reflective symmetry axes | Flip-overlap score (horizontal & vertical) |
| **Parallelism** | Parallel edge pairs | Angular comparison between straight segments |
| **Cotermination** | Vertices where edges meet | Douglas-Peucker polygon simplification |

**Concavity segmentation** compares each region to its convex hull. The deficit (hull − region) reveals concavity regions used to decompose compound shapes into individual geons.

### Target 3 — Classification Equations

Five equations form a hierarchical decision tree:

```
                        ┌─────────────────┐
                        │  Circularity > 0.82  │
                        │  AND Solidity > 0.85  │
                        └────────┬────────┘
                           YES ──┤── NO
                                 │
                         ┌───────┘    ┌──────────────────┐
                         │            │  Corners ~ 3       │
                      CIRCLE          │  Extent < 0.65     │
                                      │  Solidity > 0.90   │
                                      └────────┬───────────┘
                                         YES ──┤── NO
                                               │
                                       ┌───────┘    ┌──────────────┐
                                       │            │  Corners ~ 4   │
                                    TRIANGLE        │  Solidity>0.90 │
                                                    └──────┬─────────┘
                                                      YES ─┤─ NO
                                                           │
                                                   ┌───────┘     → UNKNOWN
                                                   │
                                            ┌──────┴──────┐
                                            │  AR < 1.25?  │
                                            └──────┬──────┘
                                              YES ─┤─ NO
                                                   │
                                            SQUARE   RECTANGLE
```

| Equation | Formula | Circle | Triangle | Square | Rectangle |
|:---------|:--------|:------:|:--------:|:------:|:---------:|
| Circularity | `C = 4πA / P²` | ~1.0 | ~0.60 | ~0.785 | <0.785 |
| Aspect Ratio | `AR = Major / Minor` | ~1.0 | varies | ~1.0 | >1.25 |
| Solidity | `S = A / A_convex` | ~1.0 | ~1.0 | ~1.0 | ~1.0 |
| Extent | `E = A / A_bbox` | ~0.785 | ~0.5 | ~1.0 | ~1.0 |
| Vertex Count | Douglas-Peucker | 0 | 3 | 4 | 4 |

---

## Theoretical Background

This framework is grounded in Irving Biederman's **Recognition-by-Components (RBC) theory** (1987), which proposes that human object recognition works by:

1. **Decomposing** visual input at regions of concavity
2. **Extracting** viewpoint-invariant Non-Accidental Properties from each component
3. **Matching** the extracted properties to a stored vocabulary of volumetric primitives (geons)
4. **Identifying** the object by its structural description (arrangement of geons)

This cognitive approach allows the system to recognise objects it has not previously encountered, making it suitable for autonomous vehicle perception where exhaustive training data is impractical.

### Key References

- Biederman, I. (1987). *Recognition-by-Components: A Theory of Human Image Understanding*. Psychological Review, 94(2), 115–147.
- Roche, A., & Silva, E. *A Cognitive Framework for Object Recognition with Application to Autonomous Vehicles*. [Semantic Scholar](https://www.semanticscholar.org/paper/A-Cognitive-Framework-for-Object-Recognition-with-Roche-Silva/42196edafa792a33a2abca1e40e6bd91aa05de69)
- MathWorks. *Computer Vision with MATLAB*. [Documentation](https://ch.mathworks.com/videos/computer-vision-with-matlab-93068.html)

---

## Extending the Framework

To add support for new images:

1. Place new `.png` / `.jpg` images in `Image_Datasets/`
2. Update the `virtualImages` or `physicalImages` lists in `Target1_Preprocessing.m`
3. Run `RBC_Main` — the pipeline automatically processes all images in the folder

To tune classification thresholds, adjust the constants at the top of `Target3_PrimitiveEquations.m`:

```matlab
CIRC_THRESH    = 0.82;    % Circularity threshold for circle detection
AR_SQUARE_MAX  = 1.25;    % Aspect ratio boundary: square vs rectangle
EXTENT_TRI_MAX = 0.65;    % Extent ceiling for triangle detection
SOLIDITY_MIN   = 0.85;    % Minimum solidity for valid convex primitive
```

---

## License

This project was developed as part of the Cognitive Computing module. For academic use only.
