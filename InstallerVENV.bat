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

set "PYTHON_FOUND=0"
:: Probar comando python en PATH
python --version >nul 2>&1
if !errorlevel! equ 0 (
    set "PYTHON_CMD=python"
    set "PYTHON_FOUND=1"
) else (
    py --version >nul 2>&1
    if !errorlevel! equ 0 (
        set "PYTHON_CMD=py -3"
        set "PYTHON_FOUND=1"
    )
)

:: Buscar Python en rutas comunes
if "!PYTHON_FOUND!"=="0" (
    for %%P in (
        "%LocalAppData%\Programs\Python\Python312\python.exe"
        "%LocalAppData%\Programs\Python\Python311\python.exe"
        "%LocalAppData%\Programs\Python\Python310\python.exe"
        "%LocalAppData%\Programs\Python\Python39\python.exe"
        "%LocalAppData%\Programs\Python\Python38\python.exe"
        "%ProgramFiles%\Python312\python.exe"
        "%ProgramFiles%\Python311\python.exe"
        "%ProgramFiles%\Python310\python.exe"
        "%ProgramFiles%\Python39\python.exe"
        "%ProgramFiles%\Python38\python.exe"
        "%ProgramFiles(x86)%\Python312\python.exe"
        "%ProgramFiles(x86)%\Python311\python.exe"
        "%ProgramFiles(x86)%\Python310\python.exe"
        "%ProgramFiles(x86)%\Python39\python.exe"
        "%ProgramFiles(x86)%\Python38\python.exe"
    ) do (
        if exist %%P (
            set "PYTHON_CMD=%%P"
            set "PYTHON_FOUND=1"
            goto :check_python_version
        )
    )
)

:: Solicitar ruta manual si no se encontró
if "!PYTHON_FOUND!"=="0" (
    echo %RED%Python not found automatically.%RESET%
    echo Please enter the full path to your python.exe:
    set /p PYTHON_CMD="Python Path: "
    if exist "!PYTHON_CMD!" (
        set "PYTHON_FOUND=1"
    ) else (
        echo %RED%Provided path does not exist or is invalid.%RESET%
        pause
        exit /b 1
    )
)

:check_python_version
echo %GREEN%Using Python: "!PYTHON_CMD!"%RESET%
"!PYTHON_CMD!" --version >nul 2>&1
if !errorlevel! neq 0 (
    echo %RED%Python executable invalid or not responding.%RESET%
    pause
    exit /b 1
)

:: Verificar versión >= 3.8
for /f "tokens=2" %%a in ('"!PYTHON_CMD!" --version 2^>^&1') do set "PYTHON_VERSION=%%a"
echo %GREEN%Found Python %PYTHON_VERSION%!%RESET%
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

:: A partir de aquí, usar siempre "!PYTHON_CMD!" en lugar de python

:: Crear o reusar entorno virtual
if exist "%PYTHON_VENV%" (
    echo %GREEN%Virtual environment found!%RESET%
    goto :check_packages
)

echo %YELLOW%Creating Python virtual environment...%RESET%
"!PYTHON_CMD!" -m venv "%VENV_DIR%"
if !errorlevel! neq 0 (
    echo %RED%Failed to create virtual environment!%RESET%
    echo Make sure you have the full Python installation with venv module.
    pause
    exit /b 1
)

echo %YELLOW%Upgrading pip...%RESET%
"%PYTHON_VENV%" -m pip install --upgrade pip --no-warn-script-location

:check_packages
echo %YELLOW%Checking installed packages...%RESET%
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

echo.
echo %CYAN%Step 1/5: Installing essential packages...%RESET%
"%PIP_VENV%" install psutil pydicom nibabel --no-warn-script-location

echo.
echo %CYAN%Step 2/5: Installing SciPy...%RESET%
"%PIP_VENV%" install scipy --no-warn-script-location

echo.
echo %CYAN%Step 3/5: Installing scikit-image...%RESET%
"%PIP_VENV%" install scikit-image --no-warn-script-location

echo.
echo %CYAN%Step 4/5: Installing rt-utils...%RESET%
"%PIP_VENV%" install rt-utils --no-warn-script-location

echo.
echo %CYAN%Step 5/5: Installing MONAI...%RESET%
"%PIP_VENV%" install monai --no-warn-script-location

echo.
echo %CYAN%Step 6/6: Installing PyTorch (this will take the longest)...%RESET%
echo %YELLOW%Downloading PyTorch with CUDA support...%RESET%
"%PIP_VENV%" install torch torchvision --index-url https://download.pytorch.org/whl/cu118 --no-warn-script-location
if !errorlevel! neq 0 (
    echo.
    echo %YELLOW%CUDA version failed, installing CPU version...%RESET%
    "%PIP_VENV%" install torch torchvision --no-warn-script-location
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
    )
) else (
    echo %GREEN%TotalSegmentator already installed!%RESET%
)

:: Create launcher scripts
echo.
echo %YELLOW%Creating launcher scripts...%RESET%

(
echo @echo off
echo title AURA - Automatic Segmentation Tool
echo cd /d "%%~dp0"
echo.
echo echo Starting AURA...
echo call "%ACTIVATE_SCRIPT%" ^>nul 2^>^&1
echo if %%errorlevel%% neq 0 ^(
echo     echo Error: Could not activate virtual environment!
echo     pause
echo     exit /b 1
echo ^)
echo.
echo python "AURA VER 1.0.py"
echo.
echo if %%errorlevel%% neq 0 ^(
echo     echo An error occurred running AURA.
echo     pause
echo ^)
echo.
echo deactivate
) > "Run_AURA.bat"

(
echo @echo off
echo title AURA - Update Dependencies
echo cd /d "%%~dp0"
echo.
echo echo Updating AURA dependencies...
echo call "%ACTIVATE_SCRIPT%" ^>nul 2^>^&1
echo python -m pip install --upgrade pip
echo pip install --upgrade torch pydicom monai scipy scikit-image rt-utils nibabel psutil
echo pip install --upgrade totalsegmentatorv2
echo if %%errorlevel%% neq 0 pip install --upgrade totalsegmentator
echo.
echo echo Update completed!
echo pause
) > "Update_AURA.bat"

(
echo @echo off
echo title AURA - Diagnostic Check
echo cd /d "%%~dp0"
echo.
echo echo Running AURA diagnostic check...
echo call "%ACTIVATE_SCRIPT%" ^>nul 2^>^&1
echo echo Python version:
echo python --version
echo echo Checking installed packages:
echo python -c "import torch; print('PyTorch:', torch.__version__)"
echo python -c "import pydicom; print('PyDICOM:', pydicom.__version__)"
echo python -c "import monai; print('MONAI:', monai.__version__)"
echo python -c "import scipy; print('SciPy:', scipy.__version__)"
echo python -c "import skimage; print('scikit-image:', skimage.__version__)"
echo python -c "import rt_utils; print('rt-utils: OK')"
echo python -c "import nibabel; print('nibabel:', nibabel.__version__)"
echo python -c "import psutil; print('psutil:', psutil.__version__)"
echo echo Checking TotalSegmentator:
echo python -c "from totalsegmentatorv2.python_api import totalsegmentator; print('TotalSegmentator V2: OK')" 2^>nul ^|^| echo TotalSegmentator V2: Not found
echo python -c "from totalsegmentator.python_api import totalsegmentator; print('TotalSegmentator V1: OK')" 2^>nul ^|^| echo TotalSegmentator V1: Not found
echo echo CUDA availability:
echo python -c "import torch; print('CUDA available:', torch.cuda.is_available())"
echo.
echo deactivate
echo pause
) > "Check_AURA.bat"

:: Final verification
echo.
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
echo   Run_AURA.bat      - Start AURA application
echo   Update_AURA.bat   - Update all dependencies
echo   Check_AURA.bat    - Diagnostic information
echo.
echo %CYAN%Next steps:%RESET%
echo 1. Double-click "Run_AURA.bat" to start AURA
echo 2. If you encounter issues, run "Check_AURA.bat" for diagnostics
echo.
echo %YELLOW%Note: First run may take longer as AI models are downloaded%RESET%
echo.
pause
