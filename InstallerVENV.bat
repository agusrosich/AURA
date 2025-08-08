@echo off
setlocal enabledelayedexpansion

:: ========================================================================
:: AURA - Automatic Segmentation Tool - Enhanced Auto Installer
:: This script automatically sets up Python virtual environment and dependencies
:: Enhanced with local TotalSegmentatorV2 installation from ZIP file
:: Combines robust error handling with local package installation
:: ========================================================================

title AURA Installation and Setup - Enhanced (Local TotalSegmentator from ZIP)

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
echo                         Enhanced Installation
echo              TotalSegmentatorV2 from Local ZIP File
echo ========================================================================
echo %RESET%

:: Check if script is running from correct directory
if not exist "AURA VER 1.0.py" (
    echo %RED%Error: AURA VER 1.0.py not found in current directory!%RESET%
    echo Please make sure this batch file is in the same folder as AURA VER 1.0.py
    pause
    exit /b 1
)

:: Check if local TotalSegmentatorV2 ZIP exists
if not exist "models\TotalSegmentatorV2-master.zip" (
    echo %RED%Error: models\TotalSegmentatorV2-master.zip not found!%RESET%
    echo.
    echo %CYAN%Please download TotalSegmentatorV2 manually:%RESET%
    echo 1. Go to: https://github.com/StanfordMIMI/TotalSegmentatorV2/archive/master.zip
    echo 2. Save it as: models\TotalSegmentatorV2-master.zip
    echo 3. Run this installer again
    echo.
    echo %YELLOW%Expected file location: %~dp0models\TotalSegmentatorV2-master.zip%RESET%
    pause
    exit /b 1
)

echo %GREEN%Found TotalSegmentatorV2 ZIP file: models\TotalSegmentatorV2-master.zip%RESET%

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
set "TOTALSEG_EXTRACT_DIR=%~dp0models\TotalSegmentatorV2-master"

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
echo %YELLOW%Upgrading pip, setuptools, and wheel in virtual environment...%RESET%
"%PYTHON_VENV%" -m pip install --upgrade pip setuptools wheel --no-warn-script-location

:check_packages
echo %YELLOW%Checking installed packages...%RESET%

:: Quick package check - check for core packages
set "PACKAGES_OK=1"
"%PYTHON_VENV%" -c "import torch, pydicom, monai, scipy, skimage, nibabel, psutil" 2>nul
if !errorlevel! neq 0 set "PACKAGES_OK=0"

:: Check if TotalSegmentator is installed and can import its API
"%PYTHON_VENV%" -c "from totalsegmentator.python_api import totalsegmentator" 2>nul
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
echo 3. Medical imaging frameworks (MONAI)
echo 4. PyTorch (deep learning - largest download)
echo 5. nnUNet dependencies
echo 6. TotalSegmentatorV2 (extract and install from local ZIP)
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
echo %CYAN%Step 1/6: Installing essential packages...%RESET%
"%PIP_VENV%" install psutil pydicom nibabel --no-warn-script-location
if !errorlevel! neq 0 (
    echo %RED%Warning: Some essential packages failed to install%RESET%
)

echo.
echo %CYAN%Step 2/6: Installing SciPy...%RESET%
"%PIP_VENV%" install scipy --no-warn-script-location
if !errorlevel! neq 0 (
    echo %RED%Warning: SciPy installation failed%RESET%
)

echo.
echo %CYAN%Step 3/6: Installing scikit-image...%RESET%
"%PIP_VENV%" install scikit-image --no-warn-script-location
if !errorlevel! neq 0 (
    echo %RED%Warning: scikit-image installation failed%RESET%
)

echo.
echo %CYAN%Step 4/6: Installing MONAI...%RESET%
"%PIP_VENV%" install monai --no-warn-script-location
if !errorlevel! neq 0 (
    echo %RED%Warning: MONAI installation failed%RESET%
)

echo.
echo %CYAN%Step 5/6: Installing PyTorch (this will take the longest)...%RESET%
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

:install_nnunet_deps
echo.
echo %CYAN%Step 6a/6: Installing nnUNet dependencies...%RESET%
"%PIP_VENV%" install nnunetv2 SimpleITK batchgenerators --no-warn-script-location
if !errorlevel! neq 0 (
    echo %YELLOW%Warning: Some nnUNet dependencies had installation issues, continuing...%RESET%
)

:install_totalsegmentator_from_zip
echo.
echo %CYAN%Step 6b/6: Installing TotalSegmentatorV2 from local ZIP...%RESET%

:: Clean up any existing extraction
if exist "%TOTALSEG_EXTRACT_DIR%" (
    echo %YELLOW%Cleaning up previous extraction...%RESET%
    rmdir /s /q "%TOTALSEG_EXTRACT_DIR%"
)

:: Extract ZIP file using PowerShell
echo %YELLOW%Extracting TotalSegmentatorV2-master.zip...%RESET%
powershell -command "try { Expand-Archive -Path '%~dp0models\TotalSegmentatorV2-master.zip' -DestinationPath '%~dp0models\' -Force; Write-Host 'Extraction successful' } catch { Write-Host 'Extraction failed:' $_.Exception.Message; exit 1 }"
if !errorlevel! neq 0 (
    echo %RED%Error: Failed to extract TotalSegmentatorV2 ZIP file!%RESET%
    echo %YELLOW%Please check that:%RESET%
    echo 1. The ZIP file is not corrupted
    echo 2. You have write permissions in the models folder
    echo 3. PowerShell is available on your system
    pause
    exit /b 1
)

:: Verify extraction was successful
if not exist "%TOTALSEG_EXTRACT_DIR%" (
    echo %RED%Error: TotalSegmentatorV2 extraction failed - folder not found!%RESET%
    echo Expected: %TOTALSEG_EXTRACT_DIR%
    pause
    exit /b 1
)

:: Check if setup.py exists in extracted folder
if not exist "%TOTALSEG_EXTRACT_DIR%\setup.py" (
    echo %RED%Error: setup.py not found in extracted TotalSegmentatorV2 folder!%RESET%
    echo Please verify the ZIP file contains a valid TotalSegmentatorV2 package
    echo Expected: %TOTALSEG_EXTRACT_DIR%\setup.py
    pause
    exit /b 1
)

echo %GREEN%TotalSegmentatorV2 extracted successfully!%RESET%

:: Install TotalSegmentatorV2 in editable mode
echo %YELLOW%Installing TotalSegmentatorV2 in editable mode...%RESET%
pushd "%TOTALSEG_EXTRACT_DIR%"
"%PIP_VENV%" install -e . --no-warn-script-location
set "INSTALL_RESULT=!errorlevel!"
popd

if !INSTALL_RESULT! neq 0 (
    echo %RED%Error: TotalSegmentatorV2 installation failed!%RESET%
    echo %YELLOW%This might be due to missing dependencies or compatibility issues%RESET%
    echo %YELLOW%Check the error messages above for more details%RESET%
    pause
    exit /b 1
) else (
    echo %GREEN%TotalSegmentatorV2 installed successfully in editable mode!%RESET%
)

:: Install additional dependencies that might be in TotalSegmentator requirements
if exist "%TOTALSEG_EXTRACT_DIR%\requirements.txt" (
    echo %YELLOW%Installing TotalSegmentatorV2 specific requirements...%RESET%
    "%PIP_VENV%" install -r "%TOTALSEG_EXTRACT_DIR%\requirements.txt" --no-warn-script-location
    if !errorlevel! neq 0 (
        echo %YELLOW%Warning: Some TotalSegmentatorV2 requirements had installation issues%RESET%
    )
)

:verify_installation
:: Comprehensive verification
echo.
echo %YELLOW%Running comprehensive installation verification...%RESET%

:: Test TotalSegmentator import using its API
echo %YELLOW%Testing TotalSegmentator API import...%RESET%
"%PYTHON_VENV%" -c "from totalsegmentator.python_api import totalsegmentator; print('TotalSegmentator API imported successfully!')" 2>nul
if !errorlevel! equ 0 (
    echo %GREEN%✓ TotalSegmentator API is properly installed and can be imported!%RESET%
) else (
    echo %RED%✗ TotalSegmentator API import test failed.%RESET%
    echo %YELLOW%Testing basic module import...%RESET%
    "%PYTHON_VENV%" -c "import totalsegmentator; print('Basic TotalSegmentator module imported!')" 2>nul
    if !errorlevel! equ 0 (
        echo %GREEN%✓ Basic TotalSegmentator module can be imported!%RESET%
    ) else (
        echo %RED%✗ TotalSegmentator basic import also failed.%RESET%
        echo %YELLOW%Installation may have issues, but proceeding with script creation...%RESET%
    )
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
echo :: Ensure TotalSegmentator is in Python path
echo set PYTHONPATH=%%PYTHONPATH%%;%TOTALSEG_EXTRACT_DIR%
echo.
echo echo Starting AURA with enhanced TotalSegmentator support...
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

:: Create enhanced update script
(
echo @echo off
echo title AURA - Update Dependencies and TotalSegmentator
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
echo python -m pip install --upgrade pip setuptools wheel
echo pip install --upgrade torch pydicom monai scipy scikit-image nibabel psutil
echo pip install --upgrade nnunetv2 SimpleITK batchgenerators
echo.
echo echo Checking for TotalSegmentator updates...
echo if exist "models\TotalSegmentatorV2-master.zip" ^(
echo     echo Re-installing TotalSegmentator from local ZIP...
echo     if exist "%TOTALSEG_EXTRACT_DIR%" rmdir /s /q "%TOTALSEG_EXTRACT_DIR%"
echo     powershell -command "Expand-Archive -Path 'models\TotalSegmentatorV2-master.zip' -DestinationPath 'models\' -Force"
echo     if exist "%TOTALSEG_EXTRACT_DIR%\setup.py" ^(
echo         cd "%TOTALSEG_EXTRACT_DIR%"
echo         pip install -e . --no-warn-script-location
echo         cd "%%~dp0"
echo         echo TotalSegmentator updated from local ZIP.
echo     ^) else ^(
echo         echo Warning: setup.py not found in extracted folder.
echo     ^)
echo ^) else ^(
echo     echo Warning: TotalSegmentatorV2 ZIP file not found for update.
echo ^)
echo.
echo echo Update completed!
echo deactivate
echo pause
) > "Update_AURA.bat"

:: Create enhanced diagnostic script
(
echo @echo off
echo title AURA - Enhanced Diagnostic Check
echo cd /d "%%~dp0"
echo.
echo echo Running AURA enhanced diagnostic check...
echo call "%ACTIVATE_SCRIPT%" ^>nul 2^>^&1
echo if %%errorlevel%% neq 0 ^(
echo     echo Error: Virtual environment not found!
echo     pause
echo     exit /b 1
echo ^)
echo.
echo echo ========================================
echo echo Python and Environment Information:
echo echo ========================================
echo python --version
echo echo Virtual Environment: %VENV_DIR%
echo echo Python Path: %PYTHON_VENV%
echo.
echo echo ========================================
echo echo Package Versions:
echo echo ========================================
echo python -c "import torch; print('PyTorch:', torch.__version__)" 2^>nul ^|^| echo PyTorch: NOT INSTALLED
echo python -c "import pydicom; print('PyDICOM:', pydicom.__version__)" 2^>nul ^|^| echo PyDICOM: NOT INSTALLED
echo python -c "import monai; print('MONAI:', monai.__version__)" 2^>nul ^|^| echo MONAI: NOT INSTALLED
echo python -c "import scipy; print('SciPy:', scipy.__version__)" 2^>nul ^|^| echo SciPy: NOT INSTALLED
echo python -c "import skimage; print('scikit-image:', skimage.__version__)" 2^>nul ^|^| echo scikit-image: NOT INSTALLED
echo python -c "import nibabel; print('nibabel:', nibabel.__version__)" 2^>nul ^|^| echo nibabel: NOT INSTALLED
echo python -c "import psutil; print('psutil:', psutil.__version__)" 2^>nul ^|^| echo psutil: NOT INSTALLED
echo.
echo echo ========================================
echo echo TotalSegmentator Status:
echo echo ========================================
echo python -c "import totalsegmentator; print('TotalSegmentator: Module imported successfully')" 2^>nul ^|^| echo TotalSegmentator: Module import failed
echo python -c "from totalsegmentator.python_api import totalsegmentator; print('TotalSegmentator API: Import successful')" 2^>nul ^|^| echo TotalSegmentator API: Import failed
echo.
echo if exist "%TOTALSEG_EXTRACT_DIR%" ^(
echo     echo Local TotalSegmentator source: EXISTS at %TOTALSEG_EXTRACT_DIR%
echo     if exist "%TOTALSEG_EXTRACT_DIR%\setup.py" ^(
echo         echo setup.py: FOUND
echo     ^) else ^(
echo         echo setup.py: NOT FOUND
echo     ^)
echo ^) else ^(
echo     echo Local TotalSegmentator source: NOT FOUND
echo ^)
echo.
echo echo ========================================
echo echo CUDA and GPU Information:
echo echo ========================================
echo python -c "import torch; print('CUDA available:', torch.cuda.is_available())"
echo python -c "import torch; print('CUDA devices:', torch.cuda.device_count()) if torch.cuda.is_available() else print('CUDA devices: 0')"
echo python -c "import torch; [print(f'Device {i}: {torch.cuda.get_device_name(i)}') for i in range(torch.cuda.device_count())] if torch.cuda.is_available() else print('No CUDA devices')"
echo.
echo echo ========================================
echo echo File Structure Check:
echo echo ========================================
echo if exist "AURA VER 1.0.py" ^(echo ✓ AURA VER 1.0.py: FOUND^) else ^(echo ✗ AURA VER 1.0.py: NOT FOUND^)
echo if exist "models\TotalSegmentatorV2-master.zip" ^(echo ✓ TotalSegmentator ZIP: FOUND^) else ^(echo ✗ TotalSegmentator ZIP: NOT FOUND^)
echo if exist "%VENV_DIR%" ^(echo ✓ Virtual Environment: FOUND^) else ^(echo ✗ Virtual Environment: NOT FOUND^)
echo.
echo deactivate
echo pause
) > "Check_AURA.bat"

:: Create uninstaller
(
echo @echo off
echo title AURA - Enhanced Uninstaller
echo echo This will completely remove the AURA virtual environment and extracted files.
echo echo The main AURA files and ZIP will remain intact.
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
echo     echo ✓ Virtual environment removed successfully!
echo ^) else ^(
echo     echo ⚠ Virtual environment not found.
echo ^)
echo.
echo echo Removing extracted TotalSegmentator files...
echo if exist "%TOTALSEG_EXTRACT_DIR%" ^(
echo     rmdir /s /q "%TOTALSEG_EXTRACT_DIR%"
echo     echo ✓ Extracted TotalSegmentator files removed!
echo ^) else ^(
echo     echo ⚠ Extracted TotalSegmentator files not found.
echo ^)
echo.
echo echo Cleanup completed! You can run the installer again to reinstall AURA.
echo pause
) > "Uninstall_AURA.bat"

:: Create enhanced requirements file for reference
(
echo # AURA Enhanced Dependencies
echo # Core Dependencies
echo torch^>=2.0.0
echo torchvision
echo pydicom^>=2.3.0
echo monai^>=1.2.0
echo scipy^>=1.10.0
echo scikit-image^>=0.20.0
echo nibabel^>=4.0.0
echo psutil^>=5.9.0
echo.
echo # nnUNet Dependencies
echo nnunetv2
echo SimpleITK
echo batchgenerators
echo.
echo # Note: TotalSegmentatorV2 is installed from local ZIP file
echo # models/TotalSegmentatorV2-master.zip
echo # Installation method: pip install -e . (editable mode)
) > "requirements.txt"

:: Final comprehensive verification
echo.
echo %YELLOW%Running final comprehensive verification...%RESET%

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
"%PYTHON_VENV%" -c "import torch; print('[✓] PyTorch:', torch.__version__)" 2>nul || echo [✗] PyTorch NOT installed
"%PYTHON_VENV%" -c "import monai; print('[✓] MONAI:', monai.__version__)" 2>nul || echo [✗] MONAI NOT installed
"%PYTHON_VENV%" -c "import scipy; print('[✓] SciPy:', scipy.__version__)" 2>nul || echo [✗] SciPy NOT installed
"%PYTHON_VENV%" -c "import skimage; print('[✓] scikit-image:', skimage.__version__)" 2>nul || echo [✗] scikit-image NOT installed
"%PYTHON_VENV%" -c "import pydicom; print('[✓] PyDICOM:', pydicom.__version__)" 2>nul || echo [✗] PyDICOM NOT installed
"%PYTHON_VENV%" -c "import nibabel; print('[✓] nibabel:', nibabel.__version__)" 2>nul || echo [✗] nibabel NOT installed
"%PYTHON_VENV%" -c "import psutil; print('[✓] psutil:', psutil.__version__)" 2>nul || echo [✗] psutil NOT installed

echo.
echo %CYAN%TotalSegmentator Verification:%RESET%
echo ==============================
"%PYTHON_VENV%" -c "import totalsegmentator; print('[✓] TotalSegmentator module imported')" 2>nul || echo [✗] TotalSegmentator module import failed
"%PYTHON_VENV%" -c "from totalsegmentator.python_api import totalsegmentator; print('[✓] TotalSegmentator API imported')" 2>nul || echo [⚠] TotalSegmentator API import failed - may need manual path adjustment

echo.
if exist "%TOTALSEG_EXTRACT_DIR%" (
    echo %GREEN%[✓] TotalSegmentatorV2 source extracted: %TOTALSEG_EXTRACT_DIR%%RESET%
) else (
    echo %RED%[✗] TotalSegmentatorV2 source NOT extracted%RESET%
)

if exist "%TOTALSEG_EXTRACT_DIR%\setup.py" (
    echo %GREEN%[✓] TotalSegmentatorV2 setup.py found and installation attempted%RESET%
) else (
    echo %RED%[✗] TotalSegmentatorV2 setup.py NOT found%RESET%
)

echo.
echo %GREEN%
echo ========================================================================
echo                     Enhanced Installation Complete!
echo ========================================================================
echo %RESET%
echo %GREEN%AURA has been successfully set up with local TotalSegmentatorV2!%RESET%
echo.
echo %BLUE%Available scripts:%RESET%
echo   🚀 Run_AURA.bat      - Start AURA application
echo   🔄 Update_AURA.bat   - Update dependencies and TotalSegmentator
echo   🔍 Check_AURA.bat    - Enhanced diagnostic information
echo   🗑️  Uninstall_AURA.bat - Complete removal (keeps ZIP and main files)
echo.
echo %CYAN%Installation details:%RESET%
echo   Virtual environment: %VENV_DIR%
echo   TotalSegmentator source: %TOTALSEG_EXTRACT_DIR%
echo   Python executable: %PYTHON_VENV%
echo.
echo %CYAN%TotalSegmentator installation method:%RESET%
echo   - Extracted from: models\TotalSegmentatorV2-master.zip
echo   - Installed in editable mode using: pip install -e .
echo   - This allows for local modifications and updates
echo.
echo %CYAN%Next steps:%RESET%
echo 1. Double-click "Run_AURA.bat" to start AURA
echo 2. If you encounter issues, run "Check_
