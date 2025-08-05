@echo off
setlocal enabledelayedexpansion

:: ========================================================================
:: AURA - Automatic Segmentation Tool - Auto Installer (Virtual Environment)
:: This script automatically sets up Python virtual environment and dependencies
:: AURA - Optimized Installer - Handles large packages better
:: Enhanced with manual Python path input capability
:: Modified to include TotalSegmentator from GitHub repository
:: ========================================================================

title AURA Installation and Setup - OPTIMIZED

:: Colors for better visualization
for /F %%a in ('echo prompt $E ^| cmd') do set "ESC=%%a"
set "GREEN=%ESC%[92m"
set "YELLOW=%ESC%[93m"
set "RED=%ESC%[91m"
set "BLUE=%ESC%[94m"
set "CYAN=%ESC%[96m"
set "RESET=%ESC%[0m"

echo %BLUE%
echo ========================================================================
echo                    AURA - Automatic Segmentation Tool
echo                         Installation and Setup
echo                       Optimized Installation
echo ========================================================================
echo %RESET%

:: Check if script is running from correct directory
if not exist "AURA VER 1.0.py" (
    echo %RED%Error: AURA VER 1.0.py not found in current directory!%RESET%
    echo Please make sure this batch file is in the same folder as AURA VER 1.0.py
    pause
    exit /b 1
)

:: Initialize Python path variable
set "PYTHON_CMD=python"

echo %YELLOW%Checking Python installation...%RESET%

:: Check if Python is installed and get version
:check_python
python --version >nul 2>&1
if !errorlevel! neq 0 (
    echo %RED%Python is not installed or not in PATH!%RESET%
    echo.
    echo %CYAN%Options:%RESET%
    echo 1. Install Python from https://www.python.org/downloads/
    echo    ^(Make sure to check "Add Python to PATH" during installation^)
    echo 2. If you have Python installed but not in PATH, provide the full path
    echo.
    
    :manual_python_path
    set /p "python_choice=Choose option (1 to install Python, 2 to provide path, or Q to quit): "
    
    if /i "!python_choice!"=="q" (
        echo Installation cancelled.
        pause
        exit /b 0
    )
    
    if "!python_choice!"=="1" (
        echo.
        echo %CYAN%Please follow these steps:%RESET%
        echo 1. Go to https://www.python.org/downloads/
        echo 2. Download Python 3.8 or higher
        echo 3. During installation, CHECK "Add Python to PATH"
        echo 4. Restart this installer after Python installation
        echo.
        pause
        exit /b 0
    )
    
    if "!python_choice!"=="2" (
        echo.
        echo %CYAN%Please provide the full path to your Python executable:%RESET%
        echo %YELLOW%Examples:%RESET%
        echo   C:\Python39\python.exe
        echo   C:\Users\YourName\AppData\Local\Programs\Python\Python39\python.exe
        echo   C:\Program Files\Python39\python.exe
        echo.
        set /p "manual_python_path=Enter Python path: "
        
        :: Remove quotes if present
        set "manual_python_path=!manual_python_path:"=!"
        
        :: Check if the provided path exists and works
        if not exist "!manual_python_path!" (
            echo %RED%Error: File not found at the specified path!%RESET%
            echo Path: !manual_python_path!
            echo.
            goto :manual_python_path
        )
        
        :: Test if it's actually Python
        "!manual_python_path!" --version >nul 2>&1
        if !errorlevel! neq 0 (
            echo %RED%Error: The specified file is not a valid Python executable!%RESET%
            echo Path: !manual_python_path!
            echo.
            goto :manual_python_path
        )
        
        :: Update the Python command to use the manual path
        set "PYTHON_CMD=!manual_python_path!"
        echo %GREEN%Python found at: !manual_python_path!%RESET%
        goto :python_found
    )
    
    echo %RED%Invalid option. Please choose 1, 2, or Q.%RESET%
    goto :manual_python_path
)

:python_found
:: Get Python version using the determined Python command
for /f "tokens=2" %%a in ('"!PYTHON_CMD!" --version 2^>^&1') do set "PYTHON_VERSION=%%a"
echo %GREEN%Found Python %PYTHON_VERSION%!%RESET%

:: Check if Python version is 3.8 or higher
for /f "tokens=1,2 delims=." %%a in ("!PYTHON_VERSION!") do (
    set "MAJOR=%%a"
    set "MINOR=%%b"
)

if !MAJOR! lss 3 (
    echo %RED%Python version too old. Please install Python 3.8 or higher.%RESET%
    pause
    exit /b 1
)

if !MAJOR! equ 3 if !MINOR! lss 8 (
    echo %RED%Python version too old. Please install Python 3.8 or higher.%RESET%
    pause
    exit /b 1
)

:: Define paths (update to use the determined Python command)
set "VENV_DIR=%~dp0aura_venv"
set "PYTHON_VENV=%VENV_DIR%\Scripts\python.exe"
set "PIP_VENV=%VENV_DIR%\Scripts\pip.exe"
set "ACTIVATE_SCRIPT=%VENV_DIR%\Scripts\activate.bat"

:: Check if virtual environment already exists
if exist "%PYTHON_VENV%" (
    echo %GREEN%Virtual environment already exists!%RESET%
    goto :check_packages
)

echo %YELLOW%Creating Python virtual environment...%RESET%

:: Create virtual environment using the determined Python command
"!PYTHON_CMD!" -m venv "%VENV_DIR%"
if !errorlevel! neq 0 (
    echo %RED%Failed to create virtual environment!%RESET%
    echo Make sure you have the full Python installation with venv module.
    echo.
    echo %YELLOW%If you're using a custom Python installation, you might need to:%RESET%
    echo 1. Install the python-venv package
    echo 2. Or use a different Python installation
    pause
    exit /b 1
)

:: Upgrade pip in virtual environment
echo %YELLOW%Upgrading pip in virtual environment...%RESET%
"%PYTHON_VENV%" -m pip install --upgrade pip --no-warn-script-location

:check_packages
echo %YELLOW%Checking installed packages...%RESET%

:: Quick package check - FIXED to check for totalsegmentator
set "PACKAGES_OK=1"
"%PYTHON_VENV%" -c "import torch, pydicom, monai, scipy, skimage, rt_utils, nibabel, psutil" 2>nul
if !errorlevel! neq 0 set "PACKAGES_OK=0"

:: Also check for totalsegmentator
"%PYTHON_VENV%" -c "from totalsegmentator.python_api import totalsegmentator" 2>nul
if !errorlevel! neq 0 set "PACKAGES_OK=0"

if "%PACKAGES_OK%"=="1" (
    echo %GREEN%All packages already installed!%RESET%
    goto :create_scripts
)

echo %YELLOW%Installing required packages...%RESET%
echo.
echo %CYAN%This process will install packages in the following order:%RESET%
echo 1. Essential packages (scipy, psutil, pydicom, nibabel)
echo 2. Image processing (scikit-image)
echo 3. Medical imaging (rt-utils)
echo 4. MONAI (medical AI framework)
echo 5. PyTorch (deep learning - largest download)
echo 6. TotalSegmentator and its dependencies
echo.
echo %YELLOW%Total download size: ~2-3 GB%RESET%
echo %YELLOW%Estimated time: 10-30 minutes depending on internet speed%RESET%
echo.
set /p continue="Continue with installation? (Y/n): "
if /i "%continue%"=="n" (
    echo Installation cancelled.
    pause
    exit /b 0
)

:: Install packages in optimized order (smallest first)
echo.
echo %CYAN%Step 1/7: Installing essential packages...%RESET%
"%PIP_VENV%" install psutil pydicom nibabel --no-warn-script-location
if !errorlevel! neq 0 (
    echo %RED%Warning: Some essential packages failed to install%RESET%
)

echo.
echo %CYAN%Step 2/7: Installing SciPy...%RESET%
"%PIP_VENV%" install scipy --no-warn-script-location
if !errorlevel! neq 0 (
    echo %RED%Warning: SciPy installation failed%RESET%
)

echo.
echo %CYAN%Step 3/7: Installing scikit-image...%RESET%
"%PIP_VENV%" install scikit-image --no-warn-script-location
if !errorlevel! neq 0 (
    echo %RED%Warning: scikit-image installation failed%RESET%
)

echo.
echo %CYAN%Step 4/7: Installing rt-utils...%RESET%
"%PIP_VENV%" install rt-utils --no-warn-script-location
if !errorlevel! neq 0 (
    echo %RED%Warning: rt-utils installation failed%RESET%
)

echo.
echo %CYAN%Step 5/7: Installing MONAI...%RESET%
"%PIP_VENV%" install monai --no-warn-script-location
if !errorlevel! neq 0 (
    echo %RED%Warning: MONAI installation failed%RESET%
)

echo.
echo %CYAN%Step 6/7: Installing PyTorch (this will take the longest)...%RESET%
echo %YELLOW%Downloading PyTorch with CUDA support...%RESET%
echo %YELLOW%If this fails, we'll try CPU-only version%RESET%
echo.

:: Try CUDA version first
"%PIP_VENV%" install torch torchvision --index-url https://download.pytorch.org/whl/cu118 --no-warn-script-location
if !errorlevel! neq 0 (
    echo.
    echo %YELLOW%CUDA version failed, installing CPU version...%RESET%
    echo %YELLOW%This is normal if you don't have an NVIDIA GPU%RESET%
    "%PIP_VENV%" install torch torchvision --no-warn-script-location
    if !errorlevel! neq 0 (
        echo %RED%Error: PyTorch installation failed completely!%RESET%
        echo %YELLOW%You can try running this installer again later%RESET%
        echo %YELLOW%Or install PyTorch manually from pytorch.org%RESET%
        pause
    ) else (
        echo %GREEN%PyTorch CPU version installed successfully!%RESET%
    )
) else (
    echo %GREEN%PyTorch CUDA version installed successfully!%RESET%
)

:install_totalsegmentator
echo.
echo %CYAN%Step 7/7: Installing TotalSegmentator and dependencies...%RESET%

:: First install nnUNet dependencies
echo %YELLOW%Installing nnUNet dependencies...%RESET%
"%PIP_VENV%" install nnunetv2 --no-warn-script-location
if !errorlevel! neq 0 (
    echo %YELLOW%Warning: nnUNetv2 installation had issues, continuing...%RESET%
)

:: Install additional dependencies that TotalSegmentator needs
echo %YELLOW%Installing additional dependencies for TotalSegmentator...%RESET%
"%PIP_VENV%" install SimpleITK batchgenerators --no-warn-script-location

:: Now install TotalSegmentator
echo %YELLOW%Installing TotalSegmentator...%RESET%
"%PYTHON_VENV%" -c "from totalsegmentator.python_api import totalsegmentator" 2>nul
if !errorlevel! neq 0 (
    echo %YELLOW%Checking Git availability...%RESET%
    git --version >nul 2>&1
    if !errorlevel! equ 0 (
        echo %GREEN%Git found! Installing TotalSegmentator from GitHub repository...%RESET%
        echo %CYAN%Repository: https://github.com/wasserth/TotalSegmentator%RESET%
        "%PIP_VENV%" install git+https://github.com/wasserth/TotalSegmentator.git --no-warn-script-location
        if !errorlevel! neq 0 (
            echo %YELLOW%GitHub installation failed, trying PyPI...%RESET%
            goto :install_totalseg_pypi
        ) else (
            echo %GREEN%TotalSegmentator from GitHub installed successfully!%RESET%
            goto :verify_totalseg
        )
    ) else (
        echo %YELLOW%Git not found. Installing from PyPI...%RESET%
        goto :install_totalseg_pypi
    )
) else (
    echo %GREEN%TotalSegmentator already installed!%RESET%
    goto :create_scripts
)

:install_totalseg_pypi
echo %YELLOW%Installing TotalSegmentator from PyPI...%RESET%
"%PIP_VENV%" install totalsegmentator --no-warn-script-location
if !errorlevel! neq 0 (
    echo %RED%WARNING: TotalSegmentator installation encountered issues.%RESET%
    echo %YELLOW%The application may not work correctly without it.%RESET%
    echo.
    echo %CYAN%You can try to install it manually later by running:%RESET%
    echo   %VENV_DIR%\Scripts\pip install totalsegmentator
    echo.
) else (
    echo %GREEN%TotalSegmentator installed successfully from PyPI!%RESET%
)

:verify_totalseg
:: Verify TotalSegmentator installation
echo.
echo %YELLOW%Verifying TotalSegmentator installation...%RESET%
"%PYTHON_VENV%" -c "from totalsegmentator.python_api import totalsegmentator; print('TotalSegmentator imported successfully!')" 2>nul
if !errorlevel! equ 0 (
    echo %GREEN%✓ TotalSegmentator is properly installed and can be imported!%RESET%
) else (
    echo %RED%✗ TotalSegmentator import test failed.%RESET%
    echo %YELLOW%This might be resolved when you run AURA for the first time.%RESET%
)

:create_scripts
:: Create utility scripts
echo.
echo %YELLOW%Creating launcher scripts...%RESET%

:: Create main launcher
(
echo @echo off
echo title AURA - Automatic Segmentation Tool
echo cd /d "%%~dp0"
echo.
echo :: Activate virtual environment and run AURA
echo call "%ACTIVATE_SCRIPT%" ^>nul 2^>^&1
echo if %%errorlevel%% neq 0 ^(
echo     echo Error: Could not activate virtual environment!
echo     echo Please run the installer again.
echo     pause
echo     exit /b 1
echo ^)
echo.
echo echo Starting AURA...
echo python "AURA VER 1.0.py"
echo.
echo if %%errorlevel%% neq 0 ^(
echo     echo.
echo     echo An error occurred running AURA.
echo     echo Check the error messages above.
echo     pause
echo ^)
echo.
echo :: Deactivate virtual environment
echo deactivate
) > "Run_AURA.bat"

:: Create update script
(
echo @echo off
echo title AURA - Update Dependencies
echo cd /d "%%~dp0"
echo.
echo echo Activating virtual environment...
echo call "%ACTIVATE_SCRIPT%" ^>nul 2^>^&1
echo if %%errorlevel%% neq 0 ^(
echo     echo Error: Virtual environment not found!
echo     pause
echo     exit /b 1
echo ^)
echo.
echo echo Updating AURA dependencies...
echo python -m pip install --upgrade pip
echo pip install --upgrade torch pydicom monai scipy scikit-image rt-utils nibabel psutil
echo pip install --upgrade nnunetv2 SimpleITK batchgenerators
echo echo Updating TotalSegmentator...
echo pip install --upgrade totalsegmentator
echo.
echo echo Update completed!
echo deactivate
echo pause
) > "Update_AURA.bat"

:: Create diagnostic script
(
echo @echo off
echo title AURA - Diagnostic Check
echo cd /d "%%~dp0"
echo.
echo echo Running AURA diagnostic check...
echo call "%ACTIVATE_SCRIPT%" ^>nul 2^>^&1
echo if %%errorlevel%% neq 0 ^(
echo     echo Error: Virtual environment not found!
echo     pause
echo     exit /b 1
echo ^)
echo.
echo echo Python Version:
echo python --version
echo.
echo echo Checking installed packages:
echo python -c "import torch; print('PyTorch:', torch.__version__)"
echo python -c "import pydicom; print('PyDICOM:', pydicom.__version__)"
echo python -c "import monai; print('MONAI:', monai.__version__)"
echo python -c "import scipy; print('SciPy:', scipy.__version__)"
echo python -c "import skimage; print('scikit-image:', skimage.__version__)"
echo python -c "import rt_utils; print('rt-utils: OK')"
echo python -c "import nibabel; print('nibabel:', nibabel.__version__)"
echo python -c "import psutil; print('psutil:', psutil.__version__)"
echo.
echo echo Checking TotalSegmentator:
echo python -c "from totalsegmentator.python_api import totalsegmentator; print('TotalSegmentator: OK')" 2^>nul ^|^| echo TotalSegmentator: Not found or error
echo.
echo echo CUDA availability:
echo python -c "import torch; print('CUDA available:', torch.cuda.is_available()); import torch; if torch.cuda.is_available(): print('CUDA device:', torch.cuda.get_device_name())"
echo.
echo deactivate
echo pause
) > "Check_AURA.bat"

:: Create uninstaller
(
echo @echo off
echo title AURA - Uninstaller
echo echo This will completely remove the AURA virtual environment.
echo echo The main AURA files will remain intact.
echo echo.
echo set /p confirm="Are you sure you want to continue? (y/N): "
echo if /i "%%confirm%%" neq "y" ^(
echo     echo Uninstallation cancelled.
echo     pause
echo     exit /b 0
echo ^)
echo.
echo echo Removing virtual environment...
echo if exist "%VENV_DIR%" ^(
echo     rmdir /s /q "%VENV_DIR%"
echo     echo Virtual environment removed successfully!
echo ^) else ^(
echo     echo Virtual environment not found.
echo ^)
echo.
echo echo You can run the installer again to reinstall AURA.
echo pause
) > "Uninstall_AURA.bat"

:: Create requirements file for reference
(
echo # AURA Dependencies
echo torch^>=2.0.0
echo torchvision
echo pydicom^>=2.3.0
echo monai^>=1.2.0
echo scipy^>=1.10.0
echo scikit-image^>=0.20.0
echo rt-utils^>=1.2.7
echo nibabel^>=4.0.0
echo psutil^>=5.9.0
echo nnunetv2
echo SimpleITK
echo batchgenerators
echo totalsegmentator
) > "requirements.txt"

:: Final verification
echo.
echo %YELLOW%Running final verification...%RESET%

"%PYTHON_VENV%" --version >nul 2>&1
if !errorlevel! neq 0 (
    echo %RED%Error: Virtual environment Python not working!%RESET%
    pause
    exit /b 1
)

:: Check all critical packages
echo.
echo %CYAN%Package Installation Summary:%RESET%
echo ===============================
"%PYTHON_VENV%" -c "import torch; print('[✓] PyTorch installed')" 2>nul || echo [✗] PyTorch NOT installed
"%PYTHON_VENV%" -c "import monai; print('[✓] MONAI installed')" 2>nul || echo [✗] MONAI NOT installed
"%PYTHON_VENV%" -c "from totalsegmentator.python_api import totalsegmentator; print('[✓] TotalSegmentator installed')" 2>nul || echo [✗] TotalSegmentator NOT installed
"%PYTHON_VENV%" -c "import scipy; print('[✓] SciPy installed')" 2>nul || echo [✗] SciPy NOT installed
"%PYTHON_VENV%" -c "import skimage; print('[✓] scikit-image installed')" 2>nul || echo [✗] scikit-image NOT installed
"%PYTHON_VENV%" -c "import rt_utils; print('[✓] rt-utils installed')" 2>nul || echo [✗] rt-utils NOT installed

echo.
echo %GREEN%
echo ========================================================================
echo                        Installation Complete!
echo ========================================================================
echo %RESET%
echo %GREEN%AURA has been successfully set up!%RESET%
echo.
echo %BLUE%Available scripts:%RESET%
echo   🚀 Run_AURA.bat      - Start AURA application
echo   🔄 Update_AURA.bat   - Update all dependencies  
echo   🔍 Check_AURA.bat    - Diagnostic information
echo   🗑️  Uninstall_AURA.bat - Remove installation
echo.
echo %CYAN%Virtual environment location:%RESET%
echo   %VENV_DIR%
echo.
echo %CYAN%Next steps:%RESET%
echo 1. Double-click "Run_AURA.bat" to start AURA
echo 2. If you encounter issues, run "Check_AURA.bat" for diagnostics
echo.
echo %YELLOW%Note: All dependencies are isolated in the virtual environment.%RESET%
echo %YELLOW%Your system Python installation remains unchanged.%RESET%
echo %YELLOW%Note: First run may take longer as AI models are downloaded%RESET%
echo.
pause
