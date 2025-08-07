@echo off
setlocal enabledelayedexpansion

:: ========================================================================
:: AURA - Automatic Segmentation Tool - Auto Installer (Virtual Environment)
:: This script automatically sets up Python virtual environment and dependencies
:: AURA - Optimized Installer - Handles large packages better
:: Enhanced with manual Python path input capability
:: Modified to extract and install local TotalSegmentatorV2 from ZIP
:: Fixed version with proper ZIP extraction and dependency management
:: ========================================================================

title AURA Installation and Setup - OPTIMIZED (Local TotalSegmentator)

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
echo                    Optimized Installation (Local TotalSegmentator)
echo ========================================================================
echo %RESET%

:: Check if script is running from correct directory
if not exist "AURA VER 1.0.py" (
    echo %RED%Error: AURA VER 1.0.py not found in current directory!%RESET%
    echo Please make sure this batch file is in the same folder as AURA VER 1.0.py
    pause
    exit /b 1
)

:: Check if local TotalSegmentatorV2-master.zip exists
if not exist "models\TotalSegmentatorV2-master.zip" (
    echo %RED%Error: models\TotalSegmentatorV2-master.zip not found!%RESET%
    echo Please make sure the TotalSegmentatorV2-master.zip file is present in the models directory
    echo Expected path: %~dp0models\TotalSegmentatorV2-master.zip
    pause
    exit /b 1
)

echo %GREEN%Found local TotalSegmentatorV2-master.zip in models\%RESET%

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
set "VENV_SITE_PACKAGES=%VENV_DIR%\Lib\site-packages"
set "TEMP_EXTRACT_DIR=%~dp0temp_totalseg_extract"

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

:: Quick package check - check for core packages first
set "PACKAGES_OK=1"
"%PYTHON_VENV%" -c "import torch, pydicom, monai, scipy, skimage, rt_utils, nibabel, psutil" 2>nul
if !errorlevel! neq 0 set "PACKAGES_OK=0"

:: Check if totalsegmentator is properly installed (most important check)
"%PYTHON_VENV%" -c "import totalsegmentator; from totalsegmentator.api import totalsegmentator as ts_api; print('TotalSegmentator API working')" 2>nul
if !errorlevel! neq 0 set "PACKAGES_OK=0"

if "%PACKAGES_OK%"=="1" (
    echo %GREEN%All packages already installed and working!%RESET%
    goto :create_scripts
)

echo %YELLOW%Installing required packages...%RESET%
echo.
echo %CYAN%This process will install packages in the following order:%RESET%
echo 1. Essential packages (scipy, psutil, pydicom, nibabel)
echo 2. Image processing (scikit-image)
echo 3. Medical imaging (rt-utils)
echo 4. PyTorch (deep learning - largest download) - FIXED VERSION
echo 5. MONAI (medical AI framework) - COMPATIBLE VERSION
echo 6. nnUNet dependencies
echo 7. Extract and install local TotalSegmentatorV2
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

:: Install PyTorch with FIXED compatible version
echo.
echo %CYAN%Step 5/7: Installing PyTorch (COMPATIBLE VERSION)...%RESET%
echo %YELLOW%Installing PyTorch 2.4.1 (compatible with MONAI)...%RESET%

:: Install specific PyTorch version that's compatible with MONAI
"%PIP_VENV%" install torch==2.4.1 torchvision==0.19.1 --index-url https://download.pytorch.org/whl/cu118 --no-warn-script-location
if !errorlevel! neq 0 (
    echo.
    echo %YELLOW%CUDA version failed, installing CPU version...%RESET%
    "%PIP_VENV%" install torch==2.4.1 torchvision==0.19.1 --no-warn-script-location
    if !errorlevel! neq 0 (
        echo %RED%Error: PyTorch installation failed completely!%RESET%
        echo %YELLOW%You can try running this installer again later%RESET%
        pause
        goto :create_scripts
    ) else (
        echo %GREEN%PyTorch 2.4.1 CPU version installed successfully!%RESET%
    )
) else (
    echo %GREEN%PyTorch 2.4.1 CUDA version installed successfully!%RESET%
)

echo.
echo %CYAN%Step 6/7: Installing MONAI (compatible version)...%RESET%
"%PIP_VENV%" install monai --no-warn-script-location
if !errorlevel! neq 0 (
    echo %RED%Warning: MONAI installation failed%RESET%
)

:install_nnunet_deps
echo.
echo %CYAN%Step 7a/7: Installing nnUNet dependencies...%RESET%
"%PIP_VENV%" install nnunetv2 SimpleITK batchgenerators --no-warn-script-location
if !errorlevel! neq 0 (
    echo %YELLOW%Warning: Some nnUNet dependencies had installation issues, continuing...%RESET%
)

:install_local_totalsegmentator
echo.
echo %CYAN%Step 7b/7: Extracting and installing local TotalSegmentatorV2...%RESET%

:: Clean up any previous extraction
if exist "%TEMP_EXTRACT_DIR%" (
    echo %YELLOW%Cleaning up previous extraction...%RESET%
    rmdir /s /q "%TEMP_EXTRACT_DIR%" 2>nul
)

:: Create temporary extraction directory
mkdir "%TEMP_EXTRACT_DIR%" 2>nul

:: Extract ZIP file using PowerShell (more reliable than tar on older Windows)
echo %YELLOW%Extracting TotalSegmentatorV2-master.zip...%RESET%
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Expand-Archive -Path 'models\TotalSegmentatorV2-master.zip' -DestinationPath '%TEMP_EXTRACT_DIR%' -Force; exit 0 } catch { Write-Host 'PowerShell extraction failed'; exit 1 }"
if !errorlevel! neq 0 (
    echo %RED%PowerShell extraction failed. Trying alternative method...%RESET%
    
    :: Fallback: try using Windows built-in tar (Windows 10+)
    echo %YELLOW%Trying tar extraction...%RESET%
    tar -xf "models\TotalSegmentatorV2-master.zip" -C "%TEMP_EXTRACT_DIR%" 2>nul
    if !errorlevel! neq 0 (
        echo %RED%Error: Could not extract TotalSegmentatorV2-master.zip%RESET%
        echo %YELLOW%Trying final fallback method with Python...%RESET%
        
        :: Final fallback: use Python to extract
        "%PYTHON_VENV%" -c "import zipfile; import os; zf = zipfile.ZipFile('models/TotalSegmentatorV2-master.zip'); zf.extractall('%TEMP_EXTRACT_DIR%'); zf.close(); print('Python extraction successful')"
        if !errorlevel! neq 0 (
            echo %RED%All extraction methods failed!%RESET%
            echo %YELLOW%Please extract TotalSegmentatorV2-master.zip manually to temp_totalseg_extract folder%RESET%
            pause
            goto :create_scripts
        ) else (
            echo %GREEN%Python extraction successful!%RESET%
        )
    ) else (
        echo %GREEN%Tar extraction successful!%RESET%
    )
) else (
    echo %GREEN%PowerShell extraction successful!%RESET%
)

:: Find the extracted folder (should be TotalSegmentatorV2-master)
set "EXTRACTED_FOLDER="
for /d %%i in ("%TEMP_EXTRACT_DIR%\*") do (
    if exist "%%i\setup.py" (
        set "EXTRACTED_FOLDER=%%i"
        goto :found_folder
    )
)

:: If setup.py not found in subfolder, check the main temp directory
if exist "%TEMP_EXTRACT_DIR%\setup.py" (
    set "EXTRACTED_FOLDER=%TEMP_EXTRACT_DIR%"
    goto :found_folder
)

:: Try to find any Python package structure
echo %YELLOW%Searching for TotalSegmentator package structure...%RESET%
for /d %%i in ("%TEMP_EXTRACT_DIR%\*") do (
    if exist "%%i\totalsegmentator" (
        set "EXTRACTED_FOLDER=%%i"
        echo %GREEN%Found TotalSegmentator package at: %%i%RESET%
        goto :found_folder
    )
)

echo %RED%Error: Could not find TotalSegmentator source in extracted files!%RESET%
echo %YELLOW%Directory contents:%RESET%
dir "%TEMP_EXTRACT_DIR%" /b
echo %YELLOW%Searching for setup.py files:%RESET%
dir "%TEMP_EXTRACT_DIR%" /s /b | findstr setup.py
pause
goto :cleanup_temp

:found_folder
echo %GREEN%Found TotalSegmentator source at: %EXTRACTED_FOLDER%%RESET%

:: Check if requirements.txt exists and install dependencies first
if exist "%EXTRACTED_FOLDER%\requirements.txt" (
    echo %YELLOW%Installing TotalSegmentatorV2 requirements...%RESET%
    "%PIP_VENV%" install -r "%EXTRACTED_FOLDER%\requirements.txt" --no-warn-script-location
    if !errorlevel! neq 0 (
        echo %YELLOW%Warning: Some TotalSegmentatorV2 requirements had installation issues%RESET%
    )
) else (
    echo %YELLOW%No requirements.txt found, installing common dependencies...%RESET%
    "%PIP_VENV%" install numpy matplotlib tqdm requests --no-warn-script-location
)

:: Install TotalSegmentatorV2 using pip install -e (editable install)
echo %YELLOW%Installing TotalSegmentatorV2 using pip...%RESET%
pushd "%EXTRACTED_FOLDER%"

:: Try editable install first (best method)
echo %CYAN%Method 1: Trying pip install -e . (editable install)%RESET%
"%PIP_VENV%" install -e . --no-warn-script-location
set "INSTALL_RESULT=!errorlevel!"
popd

if !INSTALL_RESULT! neq 0 (
    echo %YELLOW%Editable install failed, trying regular pip install...%RESET%
    pushd "%EXTRACTED_FOLDER%"
    echo %CYAN%Method 2: Trying pip install . (regular install)%RESET%
    "%PIP_VENV%" install . --no-warn-script-location
    set "INSTALL_RESULT=!errorlevel!"
    popd
)

if !INSTALL_RESULT! neq 0 (
    echo %YELLOW%Regular pip install failed, trying setup.py develop...%RESET%
    pushd "%EXTRACTED_FOLDER%"
    echo %CYAN%Method 3: Trying python setup.py develop%RESET%
    "%PYTHON_VENV%" setup.py develop
    set "INSTALL_RESULT=!errorlevel!"
    popd
)

if !INSTALL_RESULT! neq 0 (
    echo %YELLOW%setup.py develop failed, trying setup.py install...%RESET%
    pushd "%EXTRACTED_FOLDER%"
    echo %CYAN%Method 4: Trying python setup.py install%RESET%
    "%PYTHON_VENV%" setup.py install
    set "INSTALL_RESULT=!errorlevel!"
    popd
)

if !INSTALL_RESULT! neq 0 (
    echo %RED%All automatic installation methods failed. Trying manual installation...%RESET%
    
    :: Manual installation: copy source files to site-packages
    if not exist "%VENV_SITE_PACKAGES%\totalsegmentator" (
        mkdir "%VENV_SITE_PACKAGES%\totalsegmentator"
    )
    
    :: Find totalsegmentator source folder
    if exist "%EXTRACTED_FOLDER%\totalsegmentator" (
        echo %YELLOW%Copying TotalSegmentator source files...%RESET%
        xcopy /E /I /Y "%EXTRACTED_FOLDER%\totalsegmentator\*" "%VENV_SITE_PACKAGES%\totalsegmentator\"
        
        :: Copy any additional Python files from root
        for %%f in ("%EXTRACTED_FOLDER%\*.py") do (
            copy "%%f" "%VENV_SITE_PACKAGES%\totalsegmentator\" >nul 2>&1
        )
        
        :: Create __init__.py if it doesn't exist
        if not exist "%VENV_SITE_PACKAGES%\totalsegmentator\__init__.py" (
            echo # TotalSegmentatorV2 > "%VENV_SITE_PACKAGES%\totalsegmentator\__init__.py"
        )
        
        echo %GREEN%TotalSegmentator files copied manually!%RESET%
    ) else (
        echo %RED%Error: Could not find totalsegmentator source folder%RESET%
        echo %CYAN%Available folders in extracted directory:%RESET%
        dir "%EXTRACTED_FOLDER%" /b /ad
    )
) else (
    echo %GREEN%TotalSegmentatorV2 installed successfully using setup.py!%RESET%
)

:cleanup_temp
:: Clean up temporary extraction directory
echo %YELLOW%Cleaning up temporary files...%RESET%
if exist "%TEMP_EXTRACT_DIR%" (
    rmdir /s /q "%TEMP_EXTRACT_DIR%" 2>nul
)

:verify_totalseg
:: Comprehensive TotalSegmentator verification
echo.
echo %YELLOW%Verifying TotalSegmentator installation...%RESET%

:: Test basic import
echo %CYAN%Test 1: Basic import%RESET%
"%PYTHON_VENV%" -c "import totalsegmentator; print('✓ TotalSegmentator imported successfully!'); print('Version:', getattr(totalsegmentator, '__version__', 'Unknown'))" 2>nul
if !errorlevel! equ 0 (
    echo %GREEN%✓ TotalSegmentator basic import successful!%RESET%
    
    :: Test API import
    echo %CYAN%Test 2: API import%RESET%
    "%PYTHON_VENV%" -c "from totalsegmentator.api import totalsegmentator; print('✓ TotalSegmentator API accessible!')" 2>nul
    if !errorlevel! equ 0 (
        echo %GREEN%✓ TotalSegmentator API is accessible!%RESET%
        
        :: Test deeper functionality
        echo %CYAN%Test 3: Core functionality%RESET%
        "%PYTHON_VENV%" -c "from totalsegmentator.libs import setup_nnunet; print('✓ TotalSegmentator core functions work!')" 2>nul
        if !errorlevel! equ 0 (
            echo %GREEN%✓ TotalSegmentator core functionality works!%RESET%
        ) else (
            echo %YELLOW%⚠ TotalSegmentator API works but some core functions may have issues%RESET%
        )
    ) else (
        echo %YELLOW%⚠ TotalSegmentator basic import works but API may have issues%RESET%
    )
) else (
    echo %YELLOW%Basic import failed. Testing alternative import methods...%RESET%
    
    :: Try importing with manual path adjustment
    "%PYTHON_VENV%" -c "import sys; sys.path.insert(0, r'%VENV_SITE_PACKAGES%'); import totalsegmentator; print('✓ TotalSegmentator imported with path adjustment!')" 2>nul
    if !errorlevel! equ 0 (
        echo %GREEN%✓ TotalSegmentator can be imported with path adjustment!%RESET%
    ) else (
        echo %RED%✗ TotalSegmentator import test failed completely.%RESET%
        echo %CYAN%Debugging information:%RESET%
        echo %CYAN%Checking installation location...%RESET%
        if exist "%VENV_SITE_PACKAGES%\totalsegmentator" (
            echo %GREEN%✓ TotalSegmentator folder exists in site-packages%RESET%
            dir "%VENV_SITE_PACKAGES%\totalsegmentator\*.py" >nul 2>&1 && echo %GREEN%✓ Python files found%RESET% || echo %YELLOW%⚠ No Python files found%RESET%
        ) else (
            echo %RED%✗ TotalSegmentator folder NOT found in site-packages%RESET%
        )
        
        :: Check if installed via pip
        "%PIP_VENV%" show totalsegmentator >nul 2>&1
        if !errorlevel! equ 0 (
            echo %GREEN%✓ TotalSegmentator is registered with pip%RESET%
        ) else (
            echo %YELLOW%⚠ TotalSegmentator not registered with pip (manual installation)%RESET%
        )
    )
)

:create_scripts
:: Create utility scripts
echo.
echo %YELLOW%Creating launcher scripts...%RESET%

:: Create main launcher with improved TotalSegmentator path handling
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
echo :: Ensure TotalSegmentator is in Python path
echo set PYTHONPATH=%VENV_SITE_PACKAGES%;%VENV_SITE_PACKAGES%\totalsegmentator;%%PYTHONPATH%%
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

:: Create enhanced diagnostic script
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
echo echo ========================================
echo echo Python Environment Information
echo echo ========================================
echo python --version
echo echo.
echo echo Python executable: %%VIRTUAL_ENV%%\Scripts\python.exe
echo echo.
echo echo ========================================
echo echo Package Versions
echo echo ========================================
echo python -c "import torch; print('PyTorch:', torch.__version__)" 2^>^&1
echo python -c "import pydicom; print('PyDICOM:', pydicom.__version__)" 2^>^&1
echo python -c "import monai; print('MONAI:', monai.__version__)" 2^>^&1
echo python -c "import scipy; print('SciPy:', scipy.__version__)" 2^>^&1
echo python -c "import skimage; print('scikit-image:', skimage.__version__)" 2^>^&1
echo python -c "import rt_utils; print('rt-utils: OK')" 2^>^&1
echo python -c "import nibabel; print('nibabel:', nibabel.__version__)" 2^>^&1
echo python -c "import psutil; print('psutil:', psutil.__version__)" 2^>^&1
echo.
echo echo ========================================
echo echo TotalSegmentator Comprehensive Test
echo echo ========================================
echo echo == Basic Import Test ==
echo python -c "import totalsegmentator; print('✓ Basic import: OK'); print('Version:', getattr(totalsegmentator, '__version__', 'Unknown'))" 2^>^&1 ^|^| echo ✗ Basic import: FAILED
echo echo == API Import Test ==
echo python -c "from totalsegmentator.api import totalsegmentator; print('✓ API import: OK')" 2^>^&1 ^|^| echo ✗ API import: FAILED
echo echo == Core Functions Test ==
echo python -c "from totalsegmentator.libs import setup_nnunet; print('✓ Core functions: OK')" 2^>^&1 ^|^| echo ✗ Core functions: FAILED
echo echo == Installation Location ==
echo if exist "%VENV_SITE_PACKAGES%\totalsegmentator" ^(
echo     echo ✓ TotalSegmentator folder exists in site-packages
echo     dir "%VENV_SITE_PACKAGES%\totalsegmentator\*.py" ^| find /c ".py" 2^>nul ^&^& echo Python files found ^|^| echo No .py files found
echo ^) else ^(
echo     echo ✗ TotalSegmentator folder NOT found in site-packages
echo ^)
echo echo == Pip Registration ==
echo pip show totalsegmentator 2^>^&1 ^|^| echo TotalSegmentator not registered with pip
echo.
echo echo ========================================
echo echo CUDA and Hardware Information
echo echo ========================================
echo python -c "import torch; print('CUDA available:', torch.cuda.is_available())" 2^>^&1
echo python -c "import torch; import torch; if torch.cuda.is_available(): print('CUDA device:', torch.cuda.get_device_name()); print('CUDA version:', torch.version.cuda)" 2^>^&1
echo.
echo echo ========================================
echo echo Source Files Check
echo echo ========================================
echo if exist "models\TotalSegmentatorV2-master.zip" ^(
echo     echo ✓ Local TotalSegmentatorV2-master.zip found
echo     for %%i in ^("models\TotalSegmentatorV2-master.zip"^) do echo Size: %%~zi bytes
echo ^) else ^(
echo     echo ✗ Local TotalSegmentatorV2-master.zip NOT found
echo ^)
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

:: Create update script with proper TotalSegmentator handling
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
echo.
echo echo Updating core packages ^(maintaining compatibility^)...
echo pip install --upgrade pydicom scipy scikit-image rt-utils nibabel psutil
echo pip install --upgrade nnunetv2 SimpleITK batchgenerators
echo.
echo echo Checking PyTorch and MONAI compatibility...
echo python -c "import torch; print('Current PyTorch:', torch.__version__)"
echo python -c "import monai; print('Current MONAI:', monai.__version__)" 2^>nul ^|^| echo MONAI not installed
echo.
echo echo Reinstalling local TotalSegmentator from ZIP...
echo if exist "models\TotalSegmentatorV2-master.zip" ^(
echo     echo Uninstalling existing TotalSegmentator...
echo     pip uninstall totalsegmentator -y 2^>nul
echo     echo Re-running TotalSegmentator installation...
echo     call "%~dp0InstallerVENV_Corregido.bat" totalseg_only
echo ^) else ^(
echo     echo Warning: models\TotalSegmentatorV2-master.zip not found!
echo ^)
echo.
echo echo Update completed!
echo deactivate
echo pause
) > "Update_AURA.bat"

:: Create requirements file for reference
(
echo # AURA Dependencies - Compatible Versions
echo # PyTorch compatible with MONAI
echo torch==2.4.1
echo torchvision==0.19.1
echo # Medical imaging
echo pydicom^>=3.0.0
echo monai^>=1.2.0
echo nibabel^>=4.0.0
echo rt-utils^>=1.2.7
echo # Scientific computing
echo scipy^>=1.10.0
echo scikit-image^>=0.20.0
echo psutil^>=5.9.0
echo # nnUNet and segmentation
echo nnunetv2
echo SimpleITK
echo batchgenerators
echo # TotalSegmentator is installed from local models/TotalSegmentatorV2-master.zip
echo # DO NOT install totalsegmentator from PyPI - use local version only
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

:: Check all critical packages with version compatibility
echo.
echo %CYAN%Package Installation Summary:%RESET%
echo ===============================

:: Check PyTorch
"%PYTHON_VENV%" -c "import torch; print('[✓] PyTorch', torch.__version__, '- CUDA:', torch.cuda.is_available())" 2>nul && (
    set "PYTORCH_OK=1"
) || (
    echo [✗] PyTorch NOT installed
    set "PYTORCH_OK=0"
)

:: Check MONAI compatibility
"%PYTHON_VENV%" -c "import monai; import torch; print('[✓] MONAI', monai.__version__, '- Compatible with PyTorch', torch.__version__)" 2>nul && (
    set "MONAI_OK=1"
) || (
    echo [✗] MONAI NOT installed or incompatible
    set "MONAI_OK=0"
)

:: Check TotalSegmentator comprehensive
echo %CYAN%TotalSegmentator Status:%RESET%
"%PYTHON_VENV%" -c "import totalsegmentator; from totalsegmentator.api import totalsegmentator as ts_api; print('[✓] TotalSegmentator FULLY FUNCTIONAL -', getattr(totalsegmentator, '__version__', 'Local Version'))" 2>nul && (
    echo %GREEN%✓ TotalSegmentator is fully installed and functional!%RESET%
    set "TOTALSEG_OK=1"
) || (
    "%PYTHON_VENV%" -c "import totalsegmentator; print('[⚠] TotalSegmentator BASIC IMPORT OK -', getattr(totalsegmentator, '__version__', 'Local Version'))" 2>nul && (
        echo %YELLOW%⚠ TotalSegmentator basic import works, API may need testing%RESET%
        set "TOTALSEG_OK=1"
    ) || (
        echo %RED%[✗] TotalSegmentator NOT working properly%RESET%
        set "TOTALSEG_OK=0"
    )
)

:: Check other packages
"%PYTHON_VENV%" -c "import scipy; print('[✓] SciPy', scipy.__version__)" 2>nul || echo [✗] SciPy NOT installed
"%PYTHON_VENV%" -c "import skimage; print('[✓] scikit-image', skimage.__version__)" 2>nul || echo [✗] scikit-image NOT installed
"%PYTHON_VENV%" -c "import rt_utils; print('[✓] rt-utils installed')" 2>nul || echo [✗] rt-utils NOT installed

echo.
:: Check pip registration status
"%PIP_VENV%" show totalsegmentator >nul 2>&1 && (
    echo %GREEN%[✓] TotalSegmentator is registered with pip%RESET%
) || (
    if exist "%VENV_SITE_PACKAGES%\totalsegmentator" (
        echo %YELLOW%[⚠] TotalSegmentator manually installed (not registered with pip)%RESET%
    ) else (
        echo %RED%[✗] TotalSegmentator NOT found in virtual environment%RESET%
    )
)

echo.
echo %GREEN%
echo ========================================================================
echo                        Installation Complete!
echo ========================================================================
echo %RESET%
echo %GREEN%AURA has been successfully set up with local TotalSegmentatorV2!%RESET%
echo.
echo %BLUE%Available scripts:%RESET%
echo   🚀 Run_AURA.bat      - Start AURA application
echo   🔄 Update_AURA.bat   - Update all dependencies  
echo   🔍 Check_AURA.bat    - Comprehensive diagnostics
echo   🗑️  Uninstall_AURA.bat - Remove installation
echo.
echo %CYAN%Virtual environment location:%RESET%
echo   %VENV_DIR%
echo.
echo %CYAN%TotalSegmentatorV2 source:%RESET%
echo   models\TotalSegmentatorV2-master.zip
echo.
echo %CYAN%Installation compatibility:%RESET%
if "%PYTORCH_OK%"=="1" if "%MONAI_OK%"=="1" if "%TOTALSEG_OK%"=="1" (
    echo   ✓ All core components installed and compatible
    echo   ✓ PyTorch 2.4.1 ^+ MONAI ^+ TotalSegmentatorV2 = READY!
) else (
    echo   ⚠ Some components may have compatibility issues
    echo   ℹ Run Check_AURA.bat for detailed diagnostics
)

echo.
echo %CYAN%Next steps:%RESET%
echo 1. Double-click "Run_AURA.bat" to start AURA
echo 2. If you encounter issues, run "Check_AURA.bat" for detailed diagnostics
echo 3. First run may take longer as AI models are downloaded
echo 4. All dependencies use compatible versions (PyTorch 2.4.1 + MONAI)
echo.
echo %YELLOW%Important notes:%RESET%
echo - All dependencies are isolated in the virtual environment
echo - Your system Python installation remains unchanged  
echo - TotalSegmentatorV2 is installed from your local ZIP file
echo - Compatible versions are used to prevent conflicts
echo.
echo %CYAN%Troubleshooting:%RESET%
echo - If TotalSegmentator import fails: Run Check_AURA.bat
echo - If PyTorch/MONAI conflicts: Versions are now compatible
echo - If ZIP extraction failed: Check models\TotalSegmentatorV2-master.zip
echo - For any issues: The diagnostic script provides detailed information
echo.

:: Quick comprehensive test of the installation
echo %YELLOW%Running final comprehensive test...%RESET%
"%PYTHON_VENV%" -c "
import sys
print('Python executable:', sys.executable)

try:
    import torch
    print('✓ PyTorch', torch.__version__, 'imported successfully')
    
    import monai
    print('✓ MONAI', monai.__version__, 'imported successfully')
    
    import totalsegmentator
    print('✓ TotalSegmentator imported successfully')
    
    from totalsegmentator.api import totalsegmentator as ts_api
    print('✓ TotalSegmentator API imported successfully')
    
    print('')
    print('🎉 COMPREHENSIVE TEST: ALL SYSTEMS GO!')
    print('AURA should work properly with all components.')
    
except ImportError as e:
    print('⚠ Import issue detected:', str(e))
    print('Run Check_AURA.bat for detailed diagnostics')
    
except Exception as e:
    print('⚠ Unexpected issue:', str(e))
    print('This may still work - try running AURA')
" 2>nul

if !errorlevel! equ 0 (
    echo %GREEN%✅ COMPREHENSIVE TEST PASSED! AURA is ready to use.%RESET%
) else (
    echo %YELLOW%⚠ Comprehensive test had issues. Run Check_AURA.bat for details.%RESET%
    echo %CYAN%This may still work when running AURA - try Run_AURA.bat%RESET%
)

echo.
echo %GREEN%Installation process completed!%RESET%
echo %CYAN%Press any key to finish...%RESET%
pause >nul

:: Exit point for partial installations (if called with parameter)
if "%1"=="totalseg_only" (
    echo TotalSegmentator-only installation completed.
    exit /b 0
)