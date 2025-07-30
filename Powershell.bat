@echo off
setlocal enabledelayedexpansion

:: ========================================================================
:: AURA - Simple Installer (No PowerShell Required)
:: This version uses system Python and creates a virtual environment
:: ========================================================================

title AURA Simple Installation

echo ========================================================================
echo                    AURA - Automatic Segmentation Tool
echo                         Simple Installation
echo ========================================================================

:: Check if AURA script exists
if not exist "AURA VER 1.0.py" (
    echo ERROR: AURA VER 1.0.py not found in current directory!
    echo Please make sure this batch file is in the same folder as AURA VER 1.0.py
    pause
    exit /b 1
)

:: Check if Python is installed
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Python is not installed or not in PATH.
    echo Please install Python 3.8+ from https://python.org
    echo Make sure to check "Add Python to PATH" during installation.
    pause
    exit /b 1
)

echo Python found! Creating virtual environment...

:: Create virtual environment
python -m venv aura_env
if %errorlevel% neq 0 (
    echo ERROR: Failed to create virtual environment.
    echo Make sure you have Python 3.8+ installed.
    pause
    exit /b 1
)

:: Activate virtual environment
call aura_env\Scripts\activate.bat

:: Upgrade pip
echo Upgrading pip...
python -m pip install --upgrade pip

:: Install dependencies
echo Installing core dependencies...
pip install torch torchvision --index-url https://download.pytorch.org/whl/cu118

echo Installing medical imaging libraries...
pip install pydicom monai nibabel rt-utils

echo Installing scientific computing libraries...
pip install scipy scikit-image psutil

echo Installing TotalSegmentator...
pip install totalsegmentatorv2
if %errorlevel% neq 0 (
    echo Trying TotalSegmentator V1...
    pip install totalsegmentator
)

:: Create launcher
echo Creating launcher script...
(
echo @echo off
echo title AURA - Automatic Segmentation Tool
echo cd /d "%%~dp0"
echo call aura_env\Scripts\activate.bat
echo python "AURA VER 1.0.py"
echo if %%errorlevel%% neq 0 ^(
echo     echo.
echo     echo An error occurred. Press any key to close...
echo     pause ^>nul
echo ^)
) > "Run_AURA_Simple.bat"

:: Create update script
(
echo @echo off
echo title AURA - Update Dependencies
echo call aura_env\Scripts\activate.bat
echo echo Updating dependencies...
echo pip install --upgrade torch pydicom monai scipy scikit-image rt-utils nibabel psutil
echo pip install --upgrade totalsegmentatorv2
echo if %%errorlevel%% neq 0 pip install --upgrade totalsegmentator
echo echo Update completed!
echo pause
) > "Update_AURA_Simple.bat"

echo.
echo ========================================================================
echo                        Installation Complete!
echo ========================================================================
echo.
echo AURA has been successfully installed!
echo.
echo To run AURA: Double-click "Run_AURA_Simple.bat"
echo To update: Double-click "Update_AURA_Simple.bat"
echo.
pause