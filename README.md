# AURA - Automatic Segmentation Tool for Radiotherapy

[![License: CC BY-NC-SA 4.0](https://img.shields.io/badge/License-CC%20BY--NC--SA%204.0-lightgrey.svg)](https://creativecommons.org/licenses/by-nc-sa/4.0/)
[![Python 3.8+](https://img.shields.io/badge/python-3.8+-blue.svg)](https://www.python.org/downloads/)
[![Windows](https://img.shields.io/badge/platform-Windows-blue.svg)](https://www.microsoft.com/windows/)
[![TotalSegmentator](https://img.shields.io/badge/AI-TotalSegmentator%20V2-green.svg)](https://github.com/wasserth/TotalSegmentator)

**AURA** is a user-friendly automatic segmentation tool designed for radiotherapy applications. It provides an intuitive GUI for medical professionals to automatically segment anatomical structures from CT scans using state-of-the-art AI models.

![AURA Interface](https://via.placeholder.com/800x400/1e1e2e/cdd6f4?text=AURA+Interface+Screenshot)

## ✨ Features

- 🎯 **117 Anatomical Structures** - Automatic segmentation using TotalSegmentator V2
- 🖥️ **User-Friendly GUI** - Intuitive interface designed for medical professionals
- ⚡ **Batch Processing** - Process multiple patients simultaneously
- 🎨 **Multiple Themes** - Azure, Light, and Dark theme options
- 🔧 **Flexible Installation** - Multiple installation methods to suit different environments
- 💾 **DICOM Support** - Direct processing of DICOM CT images
- 📊 **RTSTRUCT Output** - Generate radiotherapy structure files
- 🖱️ **Easy Configuration** - Point-and-click settings management

## 🚀 Quick Start

### For Users with Python Already Installed

1. **Download** the complete AURA package from [Releases](../../releases)
2. **Double-click** `InstallerVENV.bat`
3. **Wait** for installation to complete
4. **Launch** AURA by double-clicking `Run_AURA.bat`

### For Users Without Python

1. **Download** the complete AURA package from [Releases](../../releases)
2. **Double-click** `install_aura.bat`
3. **Wait** for installation (takes longer, downloads Python)
4. **Launch** AURA by double-clicking `Run_AURA.bat`

## 📋 System Requirements

- **Operating System**: Windows 10/11 (64-bit)
- **Memory**: At least 8GB RAM recommended
- **Storage**: 4GB free disk space minimum
- **Internet**: Required for initial setup and model downloads
- **GPU**: NVIDIA GPU recommended (CPU processing supported)
- **Python**: 3.8+ (optional, can be installed automatically)

## 📦 Installation Methods

AURA offers three installation methods to accommodate different user needs and system configurations:

| Method | Best For | Requirements | Pros | Cons |
|--------|----------|-------------|------|------|
| **Virtual Environment** 🎯 | Most users | Python 3.8+ installed | ✅ Isolated environment<br>✅ Faster setup<br>✅ No system conflicts | Python pre-installation required |
| **Embedded Python** 📦 | Users without Python | None | ✅ Fully self-contained<br>✅ No Python needed | Larger download, slower setup |
| **Simple System** ⚡ | Troubleshooting | Python 3.11+ installed | ✅ Quick fallback option | Less isolation |

### Method 1: Virtual Environment (Recommended)

```bash
# Prerequisites: Python 3.8+ installed with PATH enabled
1. Double-click InstallerVENV.bat
2. Double-click Run_AURA.bat to launch
```

### Method 2: Embedded Python (Standalone)

```bash
# No prerequisites required
1. Double-click install_aura.bat
2. Double-click Run_AURA.bat to launch
```

### Method 3: Simple System Installation

```bash
# Prerequisites: Python 3.11+ installed with PATH enabled
1. Double-click install_aura_simple.bat
2. Double-click Run_AURA_Simple.bat to launch
```

## 🏥 How to Use AURA

### Basic Workflow

1. **Prepare Data**: Organize patient DICOM files in separate subfolders
2. **Launch AURA**: Use the appropriate `Run_AURA.bat` file
3. **Select Input**: Choose folder containing patient DICOM subfolders
4. **Select Output**: Choose destination for RTSTRUCT files
5. **Configure**: Adjust settings as needed (optional)
6. **Process**: Click "Process ONE patient" or "Process ALL (batch)"

### Input Data Structure
```
📂 Patients/
├── 📁 Patient001/
│   ├── 📄 CT001.dcm
│   ├── 📄 CT002.dcm
│   └── 📄 ...
├── 📁 Patient002/
│   ├── 📄 CT001.dcm
│   └── 📄 ...
└── 📁 ...
```

### Output Structure
```
📂 Output/
├── 📄 Patient001_segmentation.dcm
├── 📄 Patient002_segmentation.dcm
└── 📄 ...
```

## ⚙️ Configuration Options

### Appearance Settings
- **Theme Selection**: Azure (default), Light, or Dark themes
- **UI Scaling**: Automatic scaling for different screen sizes

### Segmentation Settings
- **Organ Selection**: Choose specific anatomical structures to segment
- **Orientation Options**: Flip volume axes if needed
- **Mask Cleaning**: Enable/disable morphological cleanup operations
- **Crop Margin**: Adjust automatic body cropping margins

### Model Settings
- **Resolution**: 
  - High (1.5mm): Best quality, requires more memory and time
  - Fast (3mm): Faster processing, good quality for most applications
- **Device Selection**: Automatic GPU detection with CPU fallback
- **Auto Cropping**: Smart body boundary detection

## 🧠 AI Technology

AURA leverages **TotalSegmentator V2**, a state-of-the-art deep learning model for medical image segmentation:

- **117 Anatomical Structures** including organs, bones, vessels, and muscles
- **Automatic Model Management** - Models download automatically on first use
- **Multi-Resolution Support** - Choose between speed and accuracy
- **GPU Acceleration** - NVIDIA GPU support with automatic CPU fallback
- **Robust Processing** - Handles various CT scan protocols and qualities

### Supported Anatomical Structures
Major organ systems including brain, thorax, abdomen, pelvis, and extremities. Full list available in the application help documentation.

## 🛠️ Utility Scripts

After installation, AURA provides several utility scripts for maintenance:

| Script | Purpose | Usage |
|--------|---------|-------|
| `Run_AURA.bat` | Launch application | Daily use |
| `Update_AURA.bat` | Update dependencies | When updates available |
| `Debug_AURA.bat` | Development console | Troubleshooting |
| `Uninstall_AURA.bat` | Remove installation | Complete uninstall |

## 🚨 Troubleshooting

### Common Issues and Solutions

#### Installation Problems
- **"Python not found"**: Install Python 3.8+ with PATH enabled, or use embedded Python installer
- **"Permission denied"**: Run installer as Administrator
- **"Internet connection required"**: Ensure stable internet for initial model downloads

#### Runtime Problems
- **"CUDA out of memory"**: Switch to CPU mode or use Fast (3mm) resolution
- **"Segmentation failed"**: Verify DICOM files are valid CT images
- **"Insufficient disk space"**: Ensure 2-3GB free space available

#### Performance Issues
- **Slow processing**: Use GPU mode and Fast resolution for better speed
- **High memory usage**: Close other applications, use CPU mode if needed
- **Model download fails**: Check internet connection and firewall settings

### Getting Help

1. **Check Application Logs**: Use Help → View log in AURA
2. **Debug Mode**: Run `Debug_AURA.bat` for detailed error information
3. **Update Dependencies**: Run `Update_AURA.bat` to ensure latest versions
4. **Reinstall**: Use `Uninstall_AURA.bat` followed by fresh installation

## 🔄 Updates and Maintenance

### Updating AURA
- Run `Update_AURA.bat` to update all Python dependencies
- Download new AURA releases from the [Releases](../../releases) page
- Check for TotalSegmentator model updates automatically

### Version History
- **v1.0**: Initial release with TotalSegmentator V2 integration
- Check [Releases](../../releases) for detailed changelog

## 🤝 Contributing

We welcome contributions from the medical imaging and radiotherapy community!

### How to Contribute
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Setup
```bash
# Clone repository
git clone https://github.com/agusrosich/AURA.git
cd AURA

# Set up development environment
python -m venv dev_env
dev_env\Scripts\activate
pip install -r requirements.txt

# Run in development mode
python "AURA VER 1.0.py"
```

## 📜 License and Citation

### License
AURA is released under the [Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License](LICENSE).

- ✅ **Academic Use**: Freely available for educational and research purposes
- ✅ **Clinical Use**: Permitted under supervised clinical environments
- ❌ **Commercial Use**: Not permitted without explicit permission

### Citation
If you use AURA in your research, please cite:

```bibtex
@software{aura_segmentation_2025,
  title={AURA: Automatic Segmentation Tool for Radiotherapy},
  author={Rosich, Agustin},
  year={2025},
  url={https://github.com/agusrosich/AURA},
  license={CC BY-NC-SA 4.0}
}
```

## 📞 Support and Contact

- **Issues**: Report bugs and request features via [GitHub Issues](../../issues)
- **Discussions**: Join the community in [GitHub Discussions](../../discussions)
- **Documentation**: Complete user manual available in the application Help menu

## 🙏 Acknowledgments

- **TotalSegmentator Team** - For the exceptional segmentation models
- **Medical Imaging Community** - For feedback and testing
- **Contributors** - Thank you to all who have contributed to this project

---

**⚠️ Important Medical Disclaimer**

AURA is a research tool intended for academic and supervised clinical use. All segmentation results should be reviewed and validated by qualified medical professionals before clinical use. This software is not intended as a substitute for professional medical judgment.

---

<div align="center">

**Made with ❤️ for the Radiotherapy Community**

[⬆ Back to Top](#aura---automatic-segmentation-tool-for-radiotherapy)

</div>

