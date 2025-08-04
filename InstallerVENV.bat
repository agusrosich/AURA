@echo off
setlocal enabledelayedexpansion

:: ========================================================================
:: AURA - Optimized Installer - Handles large packages better
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

:: Define paths
set "VENV_DIR=%~dp0aura_venv"
set "PYTHON_VENV=%VENV_DIR%\Scripts\python.exe"
set "PIP_VENV=%VENV_DIR%\Scripts\pip.exe"
set "ACTIVATE_SCRIPT=%VENV_DIR%\Scripts\activate.bat"

echo %YELLOW%Checking Python installation...%RESET%

:: Check if Python is installed and get version
python --version >nul 2>&1
if !errorlevel! neq 0 (
    echo %RED%Python is not installed or not in PATH!%RESET%
    echo.
    echo %CYAN%Please install Python 3.8 or higher from:%RESET%
    echo https://www.python.org/downloads/
    echo.
    echo %YELLOW%Make sure to check "Add Python to PATH" during installation!%RESET%
    echo.
    pause
    exit /b 1
)

:: Get Python version
for /f "tokens=2" %%a in ('python --version 2^>^&1') do set "PYTHON_VERSION=%%a"
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

:: Check if virtual environment already exists
if exist "%PYTHON_VENV%" (
    echo %GREEN%Virtual environment found!%RESET%
    goto :check_packages
)

echo %YELLOW%Creating Python virtual environment...%RESET%

:: Create virtual environment
python -m venv "%VENV_DIR%"
if !errorlevel! neq 0 (
    echo %RED%Failed to create virtual environment!%RESET%
    echo Make sure you have the full Python installation with venv module.
    pause
    exit /b 1
)

:: Upgrade pip in virtual environment
echo %YELLOW%Upgrading pip...%RESET%
"%PYTHON_VENV%" -m pip install --upgrade pip --no-warn-script-location

:check_packages
echo %YELLOW%Checking installed packages...%RESET%

:: Quick package check
set "PACKAGES_OK=1"
"%PYTHON_VENV%" -c "import torch, pydicom, monai, scipy, skimage, rt_utils, nibabel, psutil" 2>nul
if !errorlevel! neq 0 set "PACKAGES_OK=0"

if "%PACKAGES_OK%"=="1" (
    echo %GREEN%All packages already installed!%RESET%
    goto :check_totalsegmentator
)

echo %YELLOW%Installing required packages...%RESET%
echo.
echo %CYAN%This process will install packages in the following order:%RESET%
echo 1. Essential packages (scipy, psutil, pydicom, nibabel)
echo 2. Image processing (scikit-image)
echo 3. Medical imaging (rt-utils)
echo 4. MONAI (medical AI framework)
echo 5. PyTorch (deep learning - largest download)
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
echo %CYAN%Step 1/5: Installing essential packages...%RESET%
"%PIP_VENV%" install psutil pydicom nibabel --no-warn-script-location
if !errorlevel! neq 0 (
    echo %RED%Warning: Some essential packages failed to install%RESET%
)

echo.
echo %CYAN%Step 2/5: Installing SciPy...%RESET%
"%PIP_VENV%" install scipy --no-warn-script-location
if !errorlevel! neq 0 (
    echo %RED%Warning: SciPy installation failed%RESET%
)

echo.
echo %CYAN%Step 3/5: Installing scikit-image...%RESET%
"%PIP_VENV%" install scikit-image --no-warn-script-location
if !errorlevel! neq 0 (
    echo %RED%Warning: scikit-image installation failed%RESET%
)

echo.
echo %CYAN%Step 4/5: Installing rt-utils...%RESET%
"%PIP_VENV%" install rt-utils --no-warn-script-location
if !errorlevel! neq 0 (
    echo %RED%Warning: rt-utils installation failed%RESET%
)

echo.
echo %CYAN%Step 5/5: Installing MONAI...%RESET%
"%PIP_VENV%" install monai --no-warn-script-location
if !errorlevel! neq 0 (
    echo %RED%Warning: MONAI installation failed%RESET%
)

echo.
echo %CYAN%Step 6/6: Installing PyTorch (this will take the longest)...%RESET%
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

:check_totalsegmentator
echo.
echo %CYAN%Installing TotalSegmentator...%RESET%
"%PYTHON_VENV%" -c "from totalsegmentatorv2.python_api import totalsegmentator" 2>nul
if !errorlevel! neq 0 (
    echo %YELLOW%Installing TotalSegmentator V2...%RESET%
    "%PIP_VENV%" install totalsegmentatorv2 --no-warn-script-location
    if !errorlevel! neq 0 (
        echo %YELLOW%TotalSegmentator V2 failed, trying V1...%RESET%
        "%PIP_VENV%" install totalsegmentator --no-warn-script-location
        if !errorlevel! neq 0 (
            echo %RED%Warning: TotalSegmentator installation failed%RESET%
            echo %YELLOW%You can install it later with: pip install totalsegmentatorv2%RESET%
        )
    )
) else (
    echo %GREEN%TotalSegmentator already installed!%RESET%
)

:: Create utility scripts
echo.
echo %YELLOW%Creating launcher scripts...%RESET%

:: Create main launcher
(
echo @echo off
echo title AURA - Automatic Segmentation Tool
echo cd /d "%%~dp0"
echo.
echo echo Starting AURA...
echo call "%ACTIVATE_SCRIPT%" ^>nul 2^>^&1
echo if %%errorlevel%% neq 0 ^(
echo     echo Error: Could not activate virtual environment!
echo     echo Please run the installer again.
echo     pause
echo     exit /b 1
echo ^)
echo.
echo python "AURA VER 1.0.py"
echo.
echo if %%errorlevel%% neq 0 ^(
echo     echo.
echo     echo An error occurred running AURA.
echo     echo Check the error messages above.
echo     pause
echo ^)
echo.
echo deactivate
) > "Run_AURA.bat"

:: Create update script
(
echo @echo off
echo title AURA - Update Dependencies
echo cd /d "%%~dp0"
echo.
echo echo Updating AURA dependencies...
echo call "%ACTIVATE_SCRIPT%" ^>nul 2^>^&1
echo if %%errorlevel%% neq 0 ^(
echo     echo Error: Virtual environment not found!
echo     pause
echo     exit /b 1
echo ^)
echo.
echo python -m pip install --upgrade pip
echo pip install --upgrade torch pydicom monai scipy scikit-image rt-utils nibabel psutil
echo pip install --upgrade totalsegmentatorv2
echo if %%errorlevel%% neq 0 pip install --upgrade totalsegmentator
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
echo echo Python version:
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
echo python -c "from totalsegmentatorv2.python_api import totalsegmentator; print('TotalSegmentator V2: OK')" 2^>nul ^|^| echo TotalSegmentator V2: Not found
echo python -c "from totalsegmentator.python_api import totalsegmentator; print('TotalSegmentator V1: OK')" 2^>nul ^|^| echo TotalSegmentator V1: Not found
echo.
echo echo CUDA availability:
echo python -c "import torch; print('CUDA available:', torch.cuda.is_available())"
echo if torch.cuda.is_available(): print('CUDA device:', torch.cuda.get_device_name())"
echo.
echo deactivate
echo pause
) > "Check_AURA.bat"

:: Final verification
echo.
echo %YELLOW%Running final verification...%RESET%

"%PYTHON_VENV%" --version >nul 2>&1
if !errorlevel! neq 0 (
    echo %RED%Error: Virtual environment Python not working!%RESET%
    pause
    exit /b 1
)

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
echo.
echo %CYAN%Next steps:%RESET%
echo 1. Double-click "Run_AURA.bat" to start AURA
echo 2. If you encounter issues, run "Check_AURA.bat" for diagnostics
echo.
echo %YELLOW%Note: First run may take longer as AI models are downloaded%RESET%
echo.
pause
