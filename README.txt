# AURA - Automatic Segmentation Tool
## Installation and Setup Guide

### 📋 Requirements
- Windows 10/11 (64-bit)
- Internet connection (for initial setup only)
- At least 4GB free disk space
- NVIDIA GPU recommended (but not required)

### 🚀 Quick Start (Recommended)

1. **Download the complete AURA package** containing:
   - `AURA VER 1.0.py` (main application)
   - `install_aura.bat` (automatic installer)
   - `install_aura_simple.bat` (alternative installer)
   - Required resource files (splashscreen.png, ico.png, etc.)

2. **Run the installer**:
   - Double-click `install_aura.bat`
   - Wait for automatic installation to complete
   - The installer will download and set up everything locally

3. **Launch AURA**:
   - Double-click `Run_AURA.bat` (created by the installer)
   - AURA will start with all dependencies ready

### 🔧 Alternative Installation (If the main installer fails)

If you encounter issues with the main installer:

1. **Install Python manually**:
   - Download Python 3.11 from [python.org](https://python.org)
   - ✅ **IMPORTANT**: Check "Add Python to PATH" during installation

2. **Run simple installer**:
   - Double-click `install_aura_simple.bat`
   - This uses your system Python to create a virtual environment

3. **Launch AURA**:
   - Double-click `Run_AURA_Simple.bat`

### 📁 What Gets Installed

The installer creates these files and folders:

```
📂 AURA/
├── 📁 aura_env/              # Local Python environment
├── 📄 AURA VER 1.0.py        # Main application
├── 📄 Run_AURA.bat           # Application launcher
├── 📄 Update_AURA.bat        # Update script
├── 📄 install_aura.bat       # Installer script
└── 📄 requirements.txt       # Package list
```

### 🔄 Updating Dependencies

To update AURA dependencies:
- Double-click `Update_AURA.bat`
- Wait for the update to complete

### 🏥 Using AURA

1. **Select Input Folder**: Choose folder containing patient DICOM subfolders
2. **Select Output Folder**: Choose where to save RTSTRUCT files
3. **Configure Settings** (optional):
   - Go to Appearance → Select theme
   - Go to Segmentation → Orientation options
   - Go to Model → Select resolution (1.5mm vs 3mm)
4. **Process**:
   - Click "Process ONE patient" for single patient
   - Click "Process ALL (batch)" for multiple patients

### ⚙️ Configuration Options

#### Appearance Menu
- **Select theme**: Choose between Azure, Light, or Dark themes

#### Segmentation Menu
- **Orientation options**: Flip volume axes if needed
- **Select organs**: Choose which organs to segment
- **Mask cleaning**: Enable/disable morphological cleanup
- **Crop margin**: Adjust body cropping margin

#### Model Menu
- **Select resolution**: Choose between 1.5mm (high quality) or 3mm (fast)
- **Select device**: Choose CPU or GPU for processing
- **Automatic body cropping**: Enable/disable smart cropping

### 🧠 AI Models

AURA uses **TotalSegmentator V2** for automatic segmentation:
- **High Resolution (1.5mm)**: Best quality, requires more memory
- **Fast (3mm)**: Faster processing, good for most cases
- **117 anatomical structures** supported
- **Automatic model download** on first use

### 🚨 Troubleshooting

#### "Python not found" error:
- Install Python from python.org
- Make sure "Add Python to PATH" was checked
- Restart your computer after Python installation

#### "CUDA out of memory" error:
- Switch to CPU mode: Model → Select device → CPU
- Or use Fast (3mm) resolution: Model → Select resolution

#### "TotalSegmentator not installed" error:
- Run `Update_AURA.bat`
- Or manually install: `pip install totalsegmentatorv2`

#### Segmentation fails:
- Check DICOM files are valid CT images
- Ensure sufficient disk space (2-3GB free)
- Try CPU mode if GPU fails

### 📧 Support

For technical support or issues:
1. Check the log window in AURA for error details
2. Use Help → View log to see full error report
3. Try updating dependencies with `Update_AURA.bat`

### 📜 License

AURA is open-source software under Creative Commons 2025.
- For academic and supervised clinical use
- Not for commercial sale

---

**🎯 Quick Summary for Non-Technical Users:**
1. Double-click `install_aura.bat`
2. Wait for installation to finish
3. Double-click `Run_AURA.bat` to start
4. Select input and output folders
5. Click "Process" to segment images