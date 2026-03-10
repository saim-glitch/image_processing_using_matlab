%% ========================================================================
%  RBC_Main.m  -  Recognition by Components Framework (Master Runner)
%  ========================================================================
%  Runs all three targets in sequence:
%    Target 1 : Image reading & pre-processing (segmentation)
%    Target 2 : Non-accidental properties & concavity segmentation
%    Target 3 : Geometric primitive equations & classification
%
%  USAGE:
%    1. Place 'Image_Datasets/' folder alongside this script
%    2. In MATLAB: cd to this folder, then run:  >> RBC_Main
%    3. All outputs saved to 'preprocessed_output/'
%
%  Author : [Your Name]
%  Date   : 2025
%  ========================================================================

fprintf('\n============================================================\n');
fprintf('  RECOGNITION BY COMPONENTS (RBC) FRAMEWORK\n');
fprintf('  Cognitive Object Recognition for Geometric Primitives\n');
fprintf('============================================================\n\n');

fprintf('>>> TARGET 1: Pre-Processing & Segmentation...\n');
fprintf('------------------------------------------------------------\n');
run('Target1_Preprocessing.m');
fprintf('\n');

fprintf('>>> TARGET 2: NAPs & Concavity Segmentation...\n');
fprintf('------------------------------------------------------------\n');
run('Target2_NAPs_Concavity.m');
fprintf('\n');

fprintf('>>> TARGET 3: Primitive Equations & Classification...\n');
fprintf('------------------------------------------------------------\n');
run('Target3_PrimitiveEquations.m');
fprintf('\n');

fprintf('============================================================\n');
fprintf('  ALL TARGETS COMPLETE - see preprocessed_output/\n');
fprintf('============================================================\n');
