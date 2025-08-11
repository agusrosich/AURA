@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
set "PYTHONUTF8=1"
set "PIP_NO_INPUT=1"
set "PIP_DISABLE_PIP_VERSION_CHECK=1"

:: ========================================================================
:: AURA - Automatic Segmentation Tool - Enhanced Auto Installer
:: This script automatically sets up Python virtual environment and dependencies
:: Enhanced with local TotalSegmentator installation from ZIP file
:: Version: 2.1 - Fixed and Enhanced
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
echo                         Enhanced Installation v2.1
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

:: Create models directory if it doesn't exist
if not exist "models" (
    echo %YELLOW%Creating models directory...%RESET%
    mkdir "models"
)

:: Check if local TotalSegmentatorV2 ZIP exists (conditional message)
set "TS_WARN=1"
for /f "delims=" %%Z in (' dir /b /a:-d "%~dp0models\TotalSegmentatorV2-*.zip" 2^>nul ') do set "TS_WARN=0"
if exist "models\TotalSegmentatorV2-master.zip" set "TS_WARN=0"

if "%TS_WARN%"=="1" (
    echo %YELLOW%Warning: No local TotalSegmentatorV2 ZIP found. You can continue; TSeg se intentara despues.%RESET%
) else (
    echo %GREEN%Found local TotalSegmentatorV2 ZIP%RESET%
)

:: Check PowerShell availability for ZIP extraction
where powershell >nul 2>&1
if errorlevel 1 (
    echo %RED%Error: PowerShell no disponible. No puedo extraer el ZIP.%RESET%
    echo Instalalo o extrae el ZIP manualmente en models\ y reejecuta.
    pause
    exit /b 1
)

:: Initialize Python path variable
set "PYTHON_CMD="

echo %YELLOW%Checking Python installation...%RESET%

:: Check if Python is installed and get version
:check_python
python --version >nul 2>&1
if errorlevel 1 (
    echo %YELLOW%Python not in PATH. Searching common installation directories...%RESET%
    if exist "C:\Python39\python.exe" (
        set "PYTHON_CMD=C:\Python39\python.exe"
    ) else if exist "C:\Python38\python.exe" (
        set "PYTHON_CMD=C:\Python38\python.exe"
    ) else if exist "%LocalAppData%\Programs\Python\Python39\python.exe" (
        set "PYTHON_CMD=%LocalAppData%\Programs\Python\Python39\python.exe"
    ) else if exist "C:\Program Files\Python39\python.exe" (
        set "PYTHON_CMD=C:\Program Files\Python39\python.exe"
    ) else (
        set "PYTHON_CMD="
    )

    if defined PYTHON_CMD (
        echo %GREEN%Python found automatically at: !PYTHON_CMD!%RESET%
        goto :python_found
    ) else (
        echo %RED%Python not found in common directories!%RESET%
        echo.
        echo %CYAN%Options:%RESET%
        echo 1. Install Python from https://www.python.org/downloads/
        echo    ^(Make sure to check "Add Python to PATH" during installation^)
        echo 2. If you have Python installed but not detected, provide the full path
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
            if errorlevel 1 (
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
) else (
    set "PYTHON_CMD=python"
    goto :python_found
)

:python_found
:: Get Python version using the determined Python command
for /f "tokens=2" %%a in ('"!PYTHON_CMD!" --version 2^>^&1') do set "PYTHON_VERSION=%%a"
echo %GREEN%Found Python !PYTHON_VERSION!%RESET%

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

:: Detect TotalSegmentator extraction directory dynamically
for /d %%D in ("%~dp0models\TotalSegmentatorV2-*") do set "TOTALSEG_EXTRACT_DIR=%%~fD"
if not defined TOTALSEG_EXTRACT_DIR (
    set "TOTALSEG_EXTRACT_DIR=%~dp0models\TotalSegmentatorV2-master"
)

:: Check if virtual environment already exists
if exist "%PYTHON_VENV%" (
    echo %GREEN%Virtual environment already exists!%RESET%
    goto :check_packages
)

echo %YELLOW%Creating Python virtual environment...%RESET%

:: Create virtual environment using the determined Python command
"!PYTHON_CMD!" -m venv "%VENV_DIR%"
if errorlevel 1 (
    echo %RED%Failed to create virtual environment!%RESET%
    echo Make sure you have the full Python installation with venv module.
    echo.
    echo %YELLOW%If you're using a custom Python installation, you might need to:%RESET%
    echo 1. Install the python-venv package
    echo 2. Or use a different Python installation
    echo [FATAL] Failed to create venv >> "%LOG%"
    pause
    goto :EOF
)

:: Upgrade pip in virtual environment
echo %YELLOW%Upgrading pip, setuptools, and wheel in virtual environment...%RESET%
"%PYTHON_VENV%" -m ensurepip --upgrade >> "%LOG%" 2>&1
"%PYTHON_VENV%" -m pip install --upgrade pip setuptools wheel --no-warn-script-location >> "%LOG%" 2>&1

:check_packages
echo %YELLOW%Checking installed packages...%RESET%

:: Initialize package status variables
set "TORCH_INSTALLED=0"
set "PYDICOM_INSTALLED=0"
set "MONAI_INSTALLED=0"
set "SCIPY_INSTALLED=0"
set "SKIMAGE_INSTALLED=0"
set "NIBABEL_INSTALLED=0"
set "PSUTIL_INSTALLED=0"
set "NNUNET_INSTALLED=0"
set "TOTALSEG_INSTALLED=0"

:: Check each package individually
echo %CYAN%Package verification:%RESET%

"%PYTHON_VENV%" -c "import torch; print('PyTorch version:', torch.__version__)" 2>nul
if errorlevel 1 (
    echo [✗] PyTorch needs installation
) else (
    echo [✓] PyTorch is installed
    set "TORCH_INSTALLED=1"
)

"%PYTHON_VENV%" -c "import pydicom; print('PyDICOM version:', pydicom.__version__)" 2>nul
if errorlevel 1 (
    echo [✗] PyDICOM needs installation
) else (
    echo [✓] PyDICOM is installed
    set "PYDICOM_INSTALLED=1"
)

"%PYTHON_VENV%" -c "import monai; print('MONAI version:', monai.__version__)" 2>nul
if errorlevel 1 (
    echo [✗] MONAI needs installation
) else (
    echo [✓] MONAI is installed
    set "MONAI_INSTALLED=1"
)

"%PYTHON_VENV%" -c "import scipy; print('SciPy version:', scipy.__version__)" 2>nul
if errorlevel 1 (
    echo [✗] SciPy needs installation
) else (
    echo [✓] SciPy is installed
    set "SCIPY_INSTALLED=1"
)

"%PYTHON_VENV%" -c "import skimage; print('scikit-image version:', skimage.__version__)" 2>nul
if errorlevel 1 (
    echo [✗] scikit-image needs installation
) else (
    echo [✓] scikit-image is installed
    set "SKIMAGE_INSTALLED=1"
)

"%PYTHON_VENV%" -c "import nibabel; print('nibabel version:', nibabel.__version__)" 2>nul
if errorlevel 1 (
    echo [✗] nibabel needs installation
) else (
    echo [✓] nibabel is installed
    set "NIBABEL_INSTALLED=1"
)

"%PYTHON_VENV%" -c "import psutil; print('psutil version:', psutil.__version__)" 2>nul
if errorlevel 1 (
    echo [✗] psutil needs installation
) else (
    echo [✓] psutil is installed
    set "PSUTIL_INSTALLED=1"
)

"%PYTHON_VENV%" -c "import nnunetv2" 2>nul
if errorlevel 1 (
    echo [✗] nnUNetv2 needs installation
) else (
    echo [✓] nnUNetv2 is installed
    set "NNUNET_INSTALLED=1"
)

:: Check TotalSegmentator installation (V2 alt, V2 direct, luego fallback a V1)
set "TOTALSEG_INSTALLED=0"
"%PYTHON_VENV%" -c "import totalsegmentatorv2 as _ts; print('TSeg V2 OK')" 2>nul
if errorlevel 1 (
    "%PYTHON_VENV%" -c "import totalsegmentator as _ts; print('TSeg V2 alt OK')" 2>nul
    if errorlevel 1 (
        "%PYTHON_VENV%" -c "from totalsegmentator.python_api import totalsegmentator; print('TSeg V1 OK')" 2>nul
        if errorlevel 1 (
            echo [✗] TotalSegmentator no instalado
        ) else (
            echo [✓] TotalSegmentator V1 detectado
            set "TOTALSEG_INSTALLED=1"
        )
    ) else (
        echo [✓] TotalSegmentator V2 alt detectado
        set "TOTALSEG_INSTALLED=1"
    )
) else (
    echo [✓] TotalSegmentator V2 detectado
    set "TOTALSEG_INSTALLED=1"
)

:: Check if all packages are installed
if "%TORCH_INSTALLED%"=="1" if "%PYDICOM_INSTALLED%"=="1" if "%MONAI_INSTALLED%"=="1" if "%SCIPY_INSTALLED%"=="1" if "%SKIMAGE_INSTALLED%"=="1" if "%NIBABEL_INSTALLED%"=="1" if "%PSUTIL_INSTALLED%"=="1" if "%NNUNET_INSTALLED%"=="1" if "%TOTALSEG_INSTALLED%"=="1" (
    echo.
    echo %GREEN%All packages are already installed and working!%RESET%
    goto :create_scripts
)

echo.
echo %YELLOW%Some packages need to be installed...%RESET%
echo.
echo %CYAN%This process will install missing packages in the following order:%RESET%
echo 1. Essential packages (scipy, psutil, pydicom, nibabel)
echo 2. Image processing (scikit-image)
echo 3. PyTorch (deep learning - largest download)
echo 4. Medical imaging frameworks (MONAI)
echo 5. nnUNet dependencies
echo 6. TotalSegmentatorV2 (extract and install from local ZIP)
echo.
echo %YELLOW%Total download size for missing packages: ~2-3 GB%RESET%
echo %YELLOW%Estimated time: 10-30 minutes depending on internet speed%RESET%
echo.
choice /C YN /M "Continue with installation"
if errorlevel 2 (
    echo Installation cancelled.
    pause
    exit /b 0
)

REM === TRACING ===
set "LOG=%~dp0install_log.txt"
echo ----- START (%DATE% %TIME%) ----- > "%LOG%"
echo After CHOICE, errorlevel=!errorlevel! >> "%LOG%"
echo ON
set >> "%LOG%" 2>&1
REM envía TODO lo que sigue al log también
call :_trace "BEGIN installs"

:: Install packages only if needed
echo.

:: Install essential packages if needed
if "%SCIPY_INSTALLED%"=="0" (
    echo %CYAN%Installing SciPy...%RESET%
    call :_trace "pip scipy"
    "%PIP_VENV%" install scipy --no-warn-script-location >> "%LOG%" 2>&1
    if errorlevel 1 (
        echo %RED%Warning: SciPy installation failed%RESET%
        echo [ERR] scipy failed >> "%LOG%"
    )
)

if "%PSUTIL_INSTALLED%"=="0" (
    echo %CYAN%Installing psutil...%RESET%
    call :_trace "pip psutil"
    "%PIP_VENV%" install psutil --no-warn-script-location >> "%LOG%" 2>&1
    if errorlevel 1 (
        echo %RED%Warning: psutil installation failed%RESET%
        echo [ERR] psutil failed >> "%LOG%"
    )
)

if "%PYDICOM_INSTALLED%"=="0" (
    echo %CYAN%Installing PyDICOM...%RESET%
    call :_trace "pip pydicom"
    "%PIP_VENV%" install pydicom --no-warn-script-location >> "%LOG%" 2>&1
    if errorlevel 1 (
        echo %RED%Warning: PyDICOM installation failed%RESET%
        echo [ERR] pydicom failed >> "%LOG%"
    )
)

if "%NIBABEL_INSTALLED%"=="0" (
    echo %CYAN%Installing nibabel...%RESET%
    call :_trace "pip nibabel"
    "%PIP_VENV%" install nibabel --no-warn-script-location >> "%LOG%" 2>&1
    if errorlevel 1 (
        echo %RED%Warning: nibabel installation failed%RESET%
        echo [ERR] nibabel failed >> "%LOG%"
    )
)

if "%SKIMAGE_INSTALLED%"=="0" (
    echo %CYAN%Installing scikit-image...%RESET%
    call :_trace "pip scikit-image"
    "%PIP_VENV%" install scikit-image --no-warn-script-location >> "%LOG%" 2>&1
    if errorlevel 1 (
        echo %RED%Warning: scikit-image installation failed%RESET%
        echo [ERR] scikit-image failed >> "%LOG%"
    )
)

if "%TORCH_INSTALLED%"=="0" (
    echo %CYAN%Installing PyTorch...%RESET%
    call :_trace "pip torch"
    if /i "%TORCH_BACKEND%"=="cpu" (
        echo %YELLOW%Installing CPU version ^(TORCH_BACKEND=cpu^)%RESET%
        "%PIP_VENV%" install torch torchvision --no-warn-script-location >> "%LOG%" 2>&1
        if errorlevel 1 (
            echo %RED%Error: PyTorch CPU installation failed!%RESET%
            echo [ERR] torch CPU failed >> "%LOG%"
        )
    ) else (
        echo %YELLOW%Attempting CUDA installation...%RESET%
        "%PIP_VENV%" install torch torchvision --index-url https://download.pytorch.org/whl/cu121 --no-warn-script-location >> "%LOG%" 2>&1
        if errorlevel 1 (
            echo %YELLOW%CUDA 12.1 installation failed, trying cu118...%RESET%
            "%PIP_VENV%" install torch torchvision --index-url https://download.pytorch.org/whl/cu118 --no-warn-script-location >> "%LOG%" 2>&1
            if errorlevel 1 (
                echo %YELLOW%CUDA installations failed, falling back to CPU version...%RESET%
                "%PIP_VENV%" install torch torchvision --no-warn-script-location >> "%LOG%" 2>&1
                if errorlevel 1 (
                    echo %RED%Error: PyTorch installation failed completely!%RESET%
                    echo [ERR] torch all failed >> "%LOG%"
                )
            ) else (
                echo %GREEN%PyTorch CUDA 11.8 version installed successfully!%RESET%
                echo [OK] torch cu118 >> "%LOG%"
            )
        ) else (
            echo %GREEN%PyTorch CUDA 12.1 version installed successfully!%RESET%
            echo [OK] torch cu121 >> "%LOG%"
        )
    )
)

if "%MONAI_INSTALLED%"=="0" (
    echo %CYAN%Installing MONAI...%RESET%
    call :_trace "pip monai"
    "%PIP_VENV%" install monai --no-warn-script-location >> "%LOG%" 2>&1
    if errorlevel 1 (
        echo %RED%Warning: MONAI installation failed%RESET%
        echo [ERR] monai failed >> "%LOG%"
    )
)

if "%NNUNET_INSTALLED%"=="0" (
    echo %CYAN%Installing nnUNet dependencies...%RESET%
    call :_trace "pip nnunet"
    echo %YELLOW%This may take several minutes... Please wait%RESET%
    echo %CYAN%Status: Installing nnUNet...%RESET%
    "%PIP_VENV%" install nnunetv2 SimpleITK batchgenerators --no-warn-script-location
    if errorlevel 1 (
        echo %RED%Warning: Some nnUNet dependencies had installation issues, continuing...%RESET%
        echo [ERR] nnunet failed >> "%LOG%"
    ) else (
        echo %GREEN%✓ nnUNet dependencies installed successfully!%RESET%
    )
)

:install_totalsegmentator_from_zip
if "%TOTALSEG_INSTALLED%"=="0" (
  echo.
  echo %CYAN%Instalando TotalSegmentatorV2 desde ZIP local...%RESET%

  set "TS_ZIP="
  if exist "%~dp0models\TotalSegmentatorV2-master.zip" (
    set "TS_ZIP=%~dp0models\TotalSegmentatorV2-master.zip"
  ) else (
    for /f "delims=" %%Z in (' dir /b /a:-d "%~dp0models\TotalSegmentatorV2-*.zip" 2^>nul ') do (
      if not defined TS_ZIP set "TS_ZIP=%~dp0models\%%Z"
    )
  )
  
  if not defined TS_ZIP (
    echo %YELLOW%No se encontro ZIP local de TotalSegmentatorV2. Saltando instalacion de TSeg.%RESET%
    call :_trace "No ZIP found, skipping TotalSegmentator"
  ) else (
    echo %CYAN%Usando ZIP: !TS_ZIP!%RESET%
    call :_trace "Using ZIP: !TS_ZIP!"
    
    if exist "%TOTALSEG_EXTRACT_DIR%" (
      echo %YELLOW%Removiendo carpeta anterior...%RESET%
      rmdir /s /q "%TOTALSEG_EXTRACT_DIR%"
    )
    
    echo %YELLOW%Extrayendo ZIP...%RESET%
    call :_trace "extracting ZIP"
    
    if not exist "!TS_ZIP!" (
      echo %RED%Error: ZIP file not found at: !TS_ZIP!%RESET%
      echo [FATAL] ZIP file not found >> "%LOG%"
      pause
      goto :EOF
    )
    
    echo %YELLOW%Extracting TotalSegmentator ZIP...%RESET%
    echo %CYAN%Status: Extracting ZIP...%RESET%
    
    REM Try PowerShell first
    powershell -command "try { Expand-Archive -Path '!TS_ZIP!' -DestinationPath '%~dp0models\' -Force; Write-Host 'PowerShell extraction successful' } catch { Write-Host 'PowerShell extraction failed:' $_.Exception.Message; exit 1 }"
    
    if errorlevel 1 (
        echo %YELLOW%PowerShell failed, trying tar...%RESET%
        echo [WARN] PowerShell extraction failed, trying tar >> "%LOG%"
        
        tar -xf "!TS_ZIP!" -C "%~dp0models\"
        
        if errorlevel 1 (
            echo %RED%Both extraction methods failed!%RESET%
            echo %YELLOW%Please manually extract !TS_ZIP! to models\ folder and run installer again%RESET%
            echo [FATAL] All extraction methods failed >> "%LOG%"
            pause
            goto :EOF
        ) else (
            echo %GREEN%✓ ZIP extracted successfully using tar%RESET%
        )
    ) else (
        echo %GREEN%✓ ZIP extracted successfully using PowerShell%RESET%
    )
    if errorlevel 1 (
      echo %RED%Error al extraer el ZIP%RESET%
      echo [FATAL] ZIP extraction failed >> "%LOG%"
      pause
      goto :EOF
    )
    
    set "TOTALSEG_EXTRACT_DIR="
    for /d %%D in ("%~dp0models\TotalSegmentatorV2-*") do set "TOTALSEG_EXTRACT_DIR=%%~fD"
    if not defined TOTALSEG_EXTRACT_DIR (
      echo %RED%No se encontró carpeta extraida%RESET%
      echo [FATAL] Extracted folder not found >> "%LOG%"
      pause
      goto :EOF
    )
    
    if not exist "%TOTALSEG_EXTRACT_DIR%\pyproject.toml" if not exist "%TOTALSEG_EXTRACT_DIR%\setup.py" (
      echo %RED%Falta pyproject.toml o setup.py en %TOTALSEG_EXTRACT_DIR%%RESET%
      echo [FATAL] No pyproject.toml or setup.py found >> "%LOG%"
      pause
      goto :EOF
    )

    echo %YELLOW%Instalando en modo editable...%RESET%
    call :_trace "pip install -e TotalSegmentator"
    echo %YELLOW%Installing TotalSegmentator in editable mode... This may take several minutes%RESET%
    echo %CYAN%Status: Installing TotalSegmentator...%RESET%
    pushd "%TOTALSEG_EXTRACT_DIR%"
    "%PIP_VENV%" install -e . --no-warn-script-location
    set "INSTALL_RESULT=!errorlevel!"
    popd

    if not "!INSTALL_RESULT!"=="0" (
        echo %RED%Fallo la instalacion de TotalSegmentatorV2%RESET%
        echo [FATAL] TotalSegmentator -e installation failed >> "%LOG%"
        pause
        goto :EOF
    ) else (
        echo %GREEN%TotalSegmentatorV2 installed successfully in editable mode!%RESET%
        echo [OK] TotalSegmentator -e installed >> "%LOG%"
    )

    :: Install additional dependencies that might be in TotalSegmentator requirements
    if exist "%TOTALSEG_EXTRACT_DIR%\requirements.txt" (
        echo %YELLOW%Installing TotalSegmentatorV2 specific requirements...%RESET%
        call :_trace "pip install -r requirements.txt"
        echo %CYAN%Status: Installing requirements...%RESET%
        "%PIP_VENV%" install -r "%TOTALSEG_EXTRACT_DIR%\requirements.txt" --no-warn-script-location
        if errorlevel 1 (
            echo %YELLOW%Warning: Some TotalSegmentatorV2 requirements had installation issues%RESET%
            echo [ERR] TotalSegmentator requirements failed >> "%LOG%"
        ) else (
            echo %GREEN%✓ TotalSegmentator requirements installed successfully%RESET%
            echo [OK] TotalSegmentator requirements installed >> "%LOG%"
        )
    )
  )
)

:verify_installation
:: Comprehensive verification
echo.
echo %YELLOW%Running comprehensive installation verification...%RESET%

:: Test TotalSegmentator import using updated detection
echo %YELLOW%Testing TotalSegmentator import...%RESET%
"%PYTHON_VENV%" -c "import totalsegmentatorv2 as _ts; print('TotalSegmentator V2 OK')" 2>nul
if errorlevel 1 (
    "%PYTHON_VENV%" -c "import totalsegmentator as _ts; print('TotalSegmentator V2 alt OK')" 2>nul
    if errorlevel 1 (
        echo %YELLOW%Testing TotalSegmentator V1 fallback...%RESET%
        "%PYTHON_VENV%" -c "from totalsegmentator.python_api import totalsegmentator" 2>nul
        if errorlevel 1 (
            echo %RED%✗ No TotalSegmentator version found%RESET%
            echo %YELLOW%Installation may have issues, but proceeding with script creation...%RESET%
        ) else (
            echo %GREEN%✓ TotalSegmentator V1 is installed and working%RESET%
        )
    ) else (
        echo %GREEN%✓ TotalSegmentator V2 alt is properly installed!%RESET%
    )
) else (
    echo %GREEN%✓ TotalSegmentator V2 is properly installed!%RESET%
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
echo "%%~dp0aura_venv\Scripts\python.exe" "AURA VER 1.0.py"
echo if errorlevel 1 ^(
echo   echo.
echo   echo Ocurrio un error ejecutando AURA.
echo   pause
echo ^)
) > "Run_AURA.bat"

:: Create enhanced update script
(
echo @echo off
echo setlocal enabledelayedexpansion
echo title AURA - Update Dependencies and TotalSegmentator
echo cd /d "%%~dp0"
echo "%%~dp0aura_venv\Scripts\python.exe" -m pip install --upgrade pip setuptools wheel
echo "%%~dp0aura_venv\Scripts\pip.exe" install --upgrade torch pydicom monai scipy scikit-image nibabel psutil
echo "%%~dp0aura_venv\Scripts\pip.exe" install --upgrade nnunetv2 SimpleITK batchgenerators
echo set "TS_DIR="
echo for /d %%%%D in ("%%~dp0models\TotalSegmentatorV2-*") do set "TS_DIR=%%%%~fD"
echo if defined TS_DIR ^(
echo   pushd "%%TS_DIR%%"
echo   "%%~dp0aura_venv\Scripts\pip.exe" install -e . --no-warn-script-location
echo   popd
echo ^)
echo echo Update completed!
echo endlocal
echo pause
) > "Update_AURA.bat"

:: Create enhanced diagnostic script
(
echo @echo off
echo title AURA - Enhanced Diagnostic Check
echo cd /d "%%~dp0"
echo set "PY=%%~dp0aura_venv\Scripts\python.exe"
echo echo ========================================
echo echo Python and Environment
echo echo ========================================
echo "%%PY%%" --version
echo echo Venv: %%~dp0aura_venv
echo echo ========================================
echo echo Packages
echo echo ========================================
echo "%%PY%%" -c "import torch; print('PyTorch:', torch.__version__)" 2^>nul ^|^| echo PyTorch: NOT INSTALLED
echo "%%PY%%" -c "import pydicom; print('PyDICOM:', pydicom.__version__)" 2^>nul ^|^| echo PyDICOM: NOT INSTALLED
echo "%%PY%%" -c "import monai; print('MONAI:', monai.__version__)" 2^>nul ^|^| echo MONAI: NOT INSTALLED
echo "%%PY%%" -c "import scipy; print('SciPy:', scipy.__version__)" 2^>nul ^|^| echo SciPy: NOT INSTALLED
echo "%%PY%%" -c "import skimage; print('scikit-image:', skimage.__version__)" 2^>nul ^|^| echo scikit-image: NOT INSTALLED
echo "%%PY%%" -c "import nibabel; print('nibabel:', nibabel.__version__)" 2^>nul ^|^| echo nibabel: NOT INSTALLED
echo "%%PY%%" -c "import psutil; print('psutil:', psutil.__version__)" 2^>nul ^|^| echo psutil: NOT INSTALLED
echo echo ========================================
echo echo TotalSegmentator
echo echo ========================================
echo "%%PY%%" -c "import totalsegmentatorv2 as _ts; print('TSegV2 OK')" 2^>nul ^^|^^| "%%PY%%" -c "import totalsegmentator as _ts; print('TSegV2 alt OK')" 2^>nul ^^|^^| "%%PY%%" -c "from totalsegmentator.python_api import totalsegmentator; print('TSegV1 OK')" 2^>nul ^^|^^| echo TotalSegmentator: NOT INSTALLED
echo echo ========================================
echo echo CUDA and GPU Information
echo echo ========================================
echo "%%PY%%" -c "import torch; print('CUDA available:', torch.cuda.is_available())"
echo "%%PY%%" -c "import torch; print('CUDA devices:', torch.cuda.device_count()) if torch.cuda.is_available() else print('CUDA devices: 0')"
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
echo if exist "%%~dp0aura_venv" ^(
echo     rmdir /s /q "%%~dp0aura_venv"
echo     echo ✓ Virtual environment removed successfully!
echo ^) else ^(
echo     echo ⚠ Virtual environment not found.
echo ^)
echo.
echo set "TS_DIR="
echo for /d %%%%D in ("%%~dp0models\TotalSegmentatorV2-*") do set "TS_DIR=%%%%~fD"
echo if defined TS_DIR ^(
echo     rmdir /s /q "%%TS_DIR%%"
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
if errorlevel 1 (
    echo %RED%Error: Virtual environment Python not working!%RESET%
    echo [FATAL] Virtual environment Python not working >> "%LOG%"
    pause
    goto :EOF
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
"%PYTHON_VENV%" -c "import totalsegmentatorv2 as _ts; print('[✓] TSegV2 import')" 2>nul || ^
"%PYTHON_VENV%" -c "import totalsegmentator as _ts; print('[✓] TSegV2 alt import')" 2>nul || ^
"%PYTHON_VENV%" -c "from totalsegmentator.python_api import totalsegmentator; print('[✓] TSegV1 import')" 2>nul || ^
echo [✗] TotalSegmentator import failed

if exist "%TOTALSEG_EXTRACT_DIR%" (
    echo %GREEN%[✓] Source: %TOTALSEG_EXTRACT_DIR%%RESET%
) else (
    echo %RED%[✗] Source folder NOT found%RESET%
)

if exist "%TOTALSEG_EXTRACT_DIR%\pyproject.toml" (
    echo %GREEN%[✓] pyproject.toml found%RESET%
) else if exist "%TOTALSEG_EXTRACT_DIR%\setup.py" (
    echo %GREEN%[✓] setup.py found%RESET%
) else (
    echo %YELLOW%[!] No pyproject.toml / setup.py detected (puede no ser editable)%RESET%
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
echo 2. If you encounter issues, run "Check_AURA.bat" for diagnostics
echo 3. Use "Update_AURA.bat" to update dependencies if needed
echo.
echo %YELLOW%Important notes:%RESET%
echo - Keep the models folder and ZIP file in place
echo - The virtual environment is located in: aura_venv\
echo - TotalSegmentator source is in: models\TotalSegmentatorV2-master\
echo.
echo %GREEN%Installation completed successfully!%RESET%
echo %YELLOW%You can now close this window and run AURA using Run_AURA.bat%RESET%
echo.
call :_trace "Installation completed successfully"
pause
exit /b 0

:_trace
echo [TRACE] %~1
echo [TRACE] %~1 >> "%LOG%"
goto :eof
