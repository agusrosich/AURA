@echo off
setlocal enabledelayedexpansion

:: ========================================================================
:: AURA - Automatic Segmentation Tool - Auto Installer
:: This script automatically sets up Python environment and dependencies
:: ========================================================================

title AURA Installation and Setup

:: Colors for better visualization
for /F %%a in ('echo prompt $E ^| cmd') do set "ESC=%%a"
set "GREEN=%ESC%[92m"
set "YELLOW=%ESC%[93m"
set "RED=%ESC%[91m"
set "BLUE=%ESC%[94m"
set "RESET=%ESC%[0m"

echo %BLUE%
echo ========================================================================
echo                    AURA - Automatic Segmentation Tool
echo                         Installation and Setup
echo ========================================================================
echo %RESET%

:: Check if script is running from correct directory
if not exist "AURA VER 1.0.py" (
    echo %RED%Error: AURA VER 1.0.py not found in current directory!%RESET%
    echo Please make sure this batch file is in the same folder as AURA VER 1.0.py
    pause
    exit /b 1
)

:: Create local environment directory
set "AURA_ENV=%~dp0aura_env"
set "PYTHON_PATH=%AURA_ENV%\python.exe"
set "PIP_PATH=%AURA_ENV%\Scripts\pip.exe"

echo %YELLOW%Checking installation status...%RESET%

:: Check if Python environment already exists
if exist "%PYTHON_PATH%" (
    echo %GREEN%Local Python environment found!%RESET%
    goto :check_packages
)

echo %YELLOW%Setting up local Python environment...%RESET%

:: Download Python embeddable if not exists
set "PYTHON_ZIP=python-3.11.9-embed-amd64.zip"
set "PYTHON_URL=https://www.python.org/ftp/python/3.11.9/python-3.11.9-embed-amd64.zip"

if not exist "%PYTHON_ZIP%" (
    echo %YELLOW%Downloading Python 3.11.9 embeddable...%RESET%
    powershell -Command "& {Invoke-WebRequest -Uri '%PYTHON_URL%' -OutFile '%PYTHON_ZIP%' -UseBasicParsing}"
    if !errorlevel! neq 0 (
        echo %RED%Failed to download Python. Please check your internet connection.%RESET%
        pause
        exit /b 1
    )
)

:: Extract Python
echo %YELLOW%Extracting Python environment...%RESET%
powershell -Command "& {Expand-Archive -Path '%PYTHON_ZIP%' -DestinationPath '%AURA_ENV%' -Force}"

:: Download get-pip.py
echo %YELLOW%Setting up pip...%RESET%
powershell -Command "& {Invoke-WebRequest -Uri 'https://bootstrap.pypa.io/get-pip.py' -OutFile '%AURA_ENV%\get-pip.py' -UseBasicParsing}"

:: Enable pip in Python embeddable
echo import site >> "%AURA_ENV%\python311._pth"

:: Install pip
"%PYTHON_PATH%" "%AURA_ENV%\get-pip.py" --no-warn-script-location

:check_packages
echo %YELLOW%Checking required packages...%RESET%

:: Check if packages are installed
"%PYTHON_PATH%" -c "import torch" 2>nul
if !errorlevel! neq 0 set "NEED_TORCH=1"

"%PYTHON_PATH%" -c "import pydicom" 2>nul
if !errorlevel! neq 0 set "NEED_PYDICOM=1"

"%PYTHON_PATH%" -c "import monai" 2>nul
if !errorlevel! neq 0 set "NEED_MONAI=1"

"%PYTHON_PATH%" -c "import scipy" 2>nul
if !errorlevel! neq 0 set "NEED_SCIPY=1"

"%PYTHON_PATH%" -c "import skimage" 2>nul
if !errorlevel! neq 0 set "NEED_SKIMAGE=1"

"%PYTHON_PATH%" -c "import rt_utils" 2>nul
if !errorlevel! neq 0 set "NEED_RTUTILS=1"

"%PYTHON_PATH%" -c "import nibabel" 2>nul
if !errorlevel! neq 0 set "NEED_NIBABEL=1"

"%PYTHON_PATH%" -c "import psutil" 2>nul
if !errorlevel! neq 0 set "NEED_PSUTIL=1"

:: Install missing packages
if defined NEED_TORCH (
    echo %YELLOW%Installing PyTorch...%RESET%
    "%PIP_PATH%" install torch torchvision --index-url https://download.pytorch.org/whl/cu118 --no-warn-script-location
)

if defined NEED_PYDICOM (
    echo %YELLOW%Installing PyDICOM...%RESET%
    "%PIP_PATH%" install pydicom --no-warn-script-location
)

if defined NEED_MONAI (
    echo %YELLOW%Installing MONAI...%RESET%
    "%PIP_PATH%" install monai --no-warn-script-location
)

if defined NEED_SCIPY (
    echo %YELLOW%Installing SciPy...%RESET%
    "%PIP_PATH%" install scipy --no-warn-script-location
)

if defined NEED_SKIMAGE (
    echo %YELLOW%Installing scikit-image...%RESET%
    "%PIP_PATH%" install scikit-image --no-warn-script-location
)

if defined NEED_RTUTILS (
    echo %YELLOW%Installing rt-utils...%RESET%
    "%PIP_PATH%" install rt-utils --no-warn-script-location
)

if defined NEED_NIBABEL (
    echo %YELLOW%Installing nibabel...%RESET%
    "%PIP_PATH%" install nibabel --no-warn-script-location
)

if defined NEED_PSUTIL (
    echo %YELLOW%Installing psutil...%RESET%
    "%PIP_PATH%" install psutil --no-warn-script-location
)

:: Install TotalSegmentator
echo %YELLOW%Checking TotalSegmentator...%RESET%
"%PYTHON_PATH%" -c "from totalsegmentatorv2.python_api import totalsegmentator" 2>nul
if !errorlevel! neq 0 (
    echo %YELLOW%Installing TotalSegmentator V2...%RESET%
    "%PIP_PATH%" install totalsegmentatorv2 --no-warn-script-location
    if !errorlevel! neq 0 (
        echo %YELLOW%Trying TotalSegmentator V1...%RESET%
        "%PIP_PATH%" install totalsegmentator --no-warn-script-location
    )
)

:: Create launcher batch file
echo %YELLOW%Creating AURA launcher...%RESET%
(
echo @echo off
echo title AURA - Automatic Segmentation Tool
echo cd /d "%~dp0"
echo "%PYTHON_PATH%" "AURA VER 1.0.py"
echo if %%errorlevel%% neq 0 ^(
echo     echo.
echo     echo %RED%An error occurred. Press any key to close...%RESET%
echo     pause ^>nul
echo ^)
) > "Run_AURA.bat"

:: Create update script
echo %YELLOW%Creating update script...%RESET%
(
echo @echo off
echo title AURA - Update Dependencies
echo echo Updating AURA dependencies...
echo "%PIP_PATH%" install --upgrade torch pydicom monai scipy scikit-image rt-utils nibabel psutil
echo "%PIP_PATH%" install --upgrade totalsegmentatorv2
echo if %%errorlevel%% neq 0 "%PIP_PATH%" install --upgrade totalsegmentator
echo echo Update completed!
echo pause
) > "Update_AURA.bat"

:: Create requirements file for reference
echo %YELLOW%Creating requirements file...%RESET%
(
echo # AURA Dependencies
echo torch>=2.0.0
echo torchvision
echo pydicom>=2.3.0
echo monai>=1.2.0
echo scipy>=1.10.0
echo scikit-image>=0.20.0
echo rt-utils>=1.2.7
echo nibabel>=4.0.0
echo psutil>=5.9.0
echo totalsegmentatorv2
) > "requirements.txt"

echo %GREEN%
echo ========================================================================
echo                        Installation Complete!
echo ========================================================================
echo %RESET%
echo %GREEN%AURA has been successfully installed with all dependencies!%RESET%
echo.
echo %BLUE%To run AURA:%RESET%
echo   - Double-click "Run_AURA.bat"
echo   - Or run: "%PYTHON_PATH%" "AURA VER 1.0.py"
echo.
echo %BLUE%To update dependencies:%RESET%
echo   - Double-click "Update_AURA.bat"
echo.
echo %BLUE%Files created:%RESET%
echo   - aura_env\          (Local Python environment)
echo   - Run_AURA.bat       (Application launcher)
echo   - Update_AURA.bat    (Dependency updater)
echo   - requirements.txt   (Package list for reference)
echo.
echo %YELLOW%Note: All dependencies are installed locally and won't affect your system Python.%RESET%
echo.
pause