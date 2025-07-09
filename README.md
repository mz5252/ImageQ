# ImageQ
## Introduction
This tool is a MATLAB GUI application designed for interactive cropping, channel adjustment (brightness and contrast), shape-based ROI selection, automatic multi-channel cell labeling, and export of measurement data. It is intended for use on microscopy images such as brain slice scans.
## System Requirements
- Software: MATLAB R2022b or later
- Toolboxes: Image Processing Toolbox
- Supported Formats: .tif, .png, .jpg
## Features
- Importing Saved Parameters
- ROI Selection
- Channel Adjustment
- Auto Labeling
- Manual Labeling
- Filtering by Area
- Label Management (Undo, Clear, Hide, Adjust Font Size/Color, Remove Labels)
- Export Functions
## Instructions for Running ImageQ GUI on MATLAB Online
### Step 1: Prepare Your Files
Make sure the following files are available locally on your computer:
- crop_adjust_gui_drag.m – the main GUI script
- Sample image files (.tif, .png, .jpg)
- Optional: .xlsx parameter files for loading preset configurations

### Step 2: Log In to MATLAB Online
1. Visit https://matlab.mathworks.com
2. Click “Open MATLAB Online” button

### Step 3: Upload Files
1. In the MATLAB Online interface, go to the Home tab
2. Click Upload and select the .m, .xlsx, and image files from your computer
3. Ensure all files are placed in the same folder within MATLAB Drive for easy reference

### Step 4: Launch the GUI
1. In the MATLAB Online interface, go to the Editor tab
2. Click “Run” button 

### Notes:
- GUI elements such as sliders, drawpolygon, and uicontrol are supported in MATLAB Online.
- Avoid relying on uigetfile as file selection dialogs may not behave as expected. Use direct filenames.
- All saved output files will be stored in MATLAB Drive.

### Step 5: Download Results
To retrieve your outputs:
1. Locate the output files (e.g., adjusted_RGB.tif, adjustment_parameters.xlsx)
2. Right-click each file in MATLAB Drive
3. Select Download to save them to your local machine

## Frequently Asked Questions (FAQ)
•	Q1: GUI won't start / image doesn't load?
A1: Check that the correct MATLAB version and Image Processing Toolbox are installed.

•	Q2: Labels do not show up after clicking Auto Label?
A2: Ensure that the threshold settings are reasonable and the contrast is adequate.

•	Q3: Can I reuse a set of parameters for another image?
A3: Yes, use "Import parameters" to load a saved .xlsx file.


