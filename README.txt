# AURA - Automatic Segmentation Tool
## Installation and Setup Guide

### 📋 Requirements
- Windows 10/11 (64-bit)
- Internet connection (for initial setup only)
- At least 4GB free disk space
- NVIDIA GPU recommended (but not required)

### 🚀 Quick Start (Recommended - Virtual Environment)

1. **Install Python first** (if not already installed):
   - Download Python 3.8+ from [python.org](https://python.org)
   - ✅ **CRITICAL**: Check "Add Python to PATH" during installation
   - Restart your computer after installation

2. **Download the complete AURA package** containing:
   - `AURA VER 1.0.py` (main application)
   - `InstallerVENV.bat` (virtual environment installer - **RECOMMENDED**)
   - `install_aura.bat` (embedded Python installer)
   - `install_aura_simple.bat` (alternative installer)
   - Required resource files (splashscreen.png, ico.png, etc.)

3. **Run the virtual environment installer**:
   - Double-click `InstallerVENV.bat`
   - The installer will verify your Python installation
   - Creates an isolated virtual environment with all dependencies
   - No impact on your system Python installation

4. **Launch AURA**:
   - Double-click `Run_AURA.bat` (created by the installer)
   - AURA will start with all dependencies ready

### 🔧 Alternative Installation Methods

#### Option 1: Embedded Python (No Python installation required)
If you don't have Python installed or prefer a standalone setup:

1. **Run the embedded installer**:
   - Double-click `install_aura.bat`
   - Downloads and sets up Python locally
   - Larger download but fully self-contained

2. **Launch AURA**:
   - Double-click `Run_AURA.bat`

#### Option 2: Simple System Installation
If you encounter issues with other installers:

1. **Install Python manually**:
   - Download Python 3.11 from [python.org](https://python.org)
   - ✅ **IMPORTANT**: Check "Add Python to PATH" during installation

2. **Run simple installer**:
   - Double-click `install_aura_simple.bat`
   - Uses your system Python to create a virtual environment

3. **Launch AURA**:
   - Double-click `Run_AURA_Simple.bat`

### 📊 Installation Method Comparison

| Method | File | Requirements | Pros | Cons |
|--------|------|-------------|------|------|
| **Virtual Environment** | `InstallerVENV.bat` | Python 3.8+ installed | ✅ Isolated environment<br>✅ Faster setup<br>✅ No system conflicts | Requires Python pre-installed |
| **Embedded Python** | `install_aura.bat` | None | ✅ Fully self-contained<br>✅ No Python needed | Larger download<br>Slower setup |
| **Simple System** | `install_aura_simple.bat` | Python 3.11+ installed | ✅ Quick fallback option | Less isolation |

### 📁 What Gets Installed

#### Virtual Environment Installation (`InstallerVENV.bat`):
```
📂 AURA/
├── 📁 aura_venv/             # Virtual environment (isolated)
├── 📄 AURA VER 1.0.py        # Main application
├── 📄 Run_AURA.bat           # Application launcher
├── 📄 Update_AURA.bat        # Update dependencies
├── 📄 Debug_AURA.bat         # Development mode
├── 📄 Uninstall_AURA.bat     # Remove virtual environment
├── 📄 InstallerVENV.bat      # Virtual environment installer
└── 📄 requirements.txt       # Package list
```

#### Embedded Python Installation (`install_aura.bat`):
```
📂 AURA/
├── 📁 aura_env/              # Local Python environment
├── 📄 AURA VER 1.0.py        # Main application
├── 📄 Run_AURA.bat           # Application launcher
├── 📄 Update_AURA.bat        # Update script
├── 📄 install_aura.bat       # Installer script
└── 📄 requirements.txt       # Package list
```

### 🛠️ Utility Scripts (Virtual Environment)

After using `InstallerVENV.bat`, you'll have these utility scripts:

| Script | Function | When to Use |
|--------|----------|-------------|
| **`Run_AURA.bat`** | 🎯 Launch AURA application | Normal daily use |
| **`Update_AURA.bat`** | 🔄 Update all dependencies | When updates are available |
| **`Debug_AURA.bat`** | 🐛 Open development console | For troubleshooting or development |
| **`Uninstall_AURA.bat`** | 🗑️ Remove virtual environment | To completely uninstall |

### 🔄 Updating Dependencies

#### For Virtual Environment installation:
- Double-click `Update_AURA.bat`
- Wait for the update to complete

#### For Embedded Python installation:
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

#### "Python not found" error (Virtual Environment installer):
- Install Python 3.8+ from python.org
- Make sure "Add Python to PATH" was checked during installation
- Restart your computer after Python installation
- Try the embedded Python installer (`install_aura.bat`) as alternative

#### "Python version too old" error:
- Install Python 3.8 or higher
- Use `python --version` in Command Prompt to check current version

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

#### Virtual Environment issues:
- Use `Debug_AURA.bat` to access the Python console
- Check if virtual environment is properly activated
- Try `Uninstall_AURA.bat` then reinstall with `InstallerVENV.bat`

### 📧 Support

For technical support or issues:
1. Check the log window in AURA for error details
2. Use Help → View log to see full error report
3. Try updating dependencies with `Update_AURA.bat`
4. For virtual environment issues, use `Debug_AURA.bat` for advanced troubleshooting

### 📜 License

AURA is open-source software under Creative Commons 2025.
- For academic and supervised clinical use
- Not for commercial sale

---

**🎯 Quick Summary for Non-Technical Users:**

### If you have Python installed:
1. Double-click `InstallerVENV.bat`
2. Wait for installation to finish
3. Double-click `Run_AURA.bat` to start

### If you don't have Python:
1. Double-click `install_aura.bat`
2. Wait for installation to finish (takes longer)
3. Double-click `Run_AURA.bat` to start

**Then:**
4. Select input and output folders
5. Click "Process" to segment images
