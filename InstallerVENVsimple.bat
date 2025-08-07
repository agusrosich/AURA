@echo off
setlocal enabledelayedexpansion

:: ========================================================================
:: AURA - Automatic Segmentation Tool - Auto Installer (Virtual Environment)
:: Version 3.2 - Instalación offline de TotalSegmentatorV2 desde ZIP local
:: ========================================================================

title AURA Installation - TotalSegmentatorV2 desde ZIP local

:: --- Colores ---
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
echo              Instalación desde ZIP local (TotalSegmentatorV2)
echo ========================================================================
echo %RESET%

:: --- Verificar archivos necesarios ---
if not exist "AURA VER 1.0.py" (
    echo %RED%Error: No se encuentra "AURA VER 1.0.py" en este directorio.%RESET%
    pause
    exit /b 1
)

if not exist "models\TotalSegmentatorV2-master.zip" (
    echo %RED%Error: No se encuentra "models\TotalSegmentatorV2-master.zip".%RESET%
    echo %YELLOW%Descárgalo manualmente de:%RESET%
    echo https://github.com/StanfordMIMI/TotalSegmentatorV2/archive/master.zip
    pause
    exit /b 1
)

:: --- Verificar Python ---
set "PYTHON_CMD=python"
echo %YELLOW%Verificando Python...%RESET%
python --version >nul 2>&1 || (
    echo %RED%Python no encontrado.%RESET%
    echo %YELLOW%Descarga Python 3.8+ desde: https://www.python.org/downloads/%RESET%
    echo %YELLOW%Asegúrate de marcar "Add Python to PATH" durante la instalación.%RESET%
    pause
    exit /b 1
)

for /f "tokens=2" %%a in ('python --version 2^>^&1') do set "PYTHON_VERSION=%%a"
echo %GREEN%Python %PYTHON_VERSION% detectado.%RESET%

:: --- Crear entorno virtual ---
set "VENV_DIR=%~dp0aura_venv"
set "PYTHON_VENV=%VENV_DIR%\Scripts\python.exe"
set "PIP_VENV=%VENV_DIR%\Scripts\pip.exe"

if not exist "%PYTHON_VENV%" (
    echo %YELLOW%Creando entorno virtual...%RESET%
    python -m venv "%VENV_DIR%" || (
        echo %RED%Error al crear el entorno virtual.%RESET%
        pause
        exit /b 1
    )
)

echo %YELLOW%Actualizando pip...%RESET%
"%PYTHON_VENV%" -m pip install --upgrade pip setuptools wheel --no-warn-script-location

:: --- Instalar dependencias principales ---
echo %YELLOW%Instalando dependencias básicas...%RESET%
"%PIP_VENV%" install torch torchvision monai pydicom nibabel scikit-image psutil --no-warn-script-location || (
    echo %RED%Error al instalar dependencias básicas.%RESET%
    pause
    exit /b 1
)

:: --- Instalar TotalSegmentatorV2 desde ZIP local ---
echo %YELLOW%Instalando TotalSegmentatorV2 desde ZIP local...%RESET%

:: Descomprimir
if exist "models\TotalSegmentatorV2-master" (
    rmdir /s /q "models\TotalSegmentatorV2-master"
)
powershell -command "Expand-Archive -Path '%~dp0models\TotalSegmentatorV2-master.zip' -DestinationPath '%~dp0models\'" || (
    echo %RED%Error al descomprimir el archivo ZIP.%RESET%
    pause
    exit /b 1
)

:: Instalar en modo editable
cd "models\TotalSegmentatorV2-master"
"%PIP_VENV%" install -e . --no-warn-script-location || (
    echo %RED%Error al instalar TotalSegmentatorV2.%RESET%
    cd ..
    pause
    exit /b 1
)
cd "%~dp0"

:: --- Verificar instalación ---
echo %YELLOW%Verificando la instalación...%RESET%
"%PYTHON_VENV%" -c "from totalsegmentator.python_api import totalsegmentator; print('TotalSegmentator importado correctamente')" || (
    echo %RED%Error: TotalSegmentator no se pudo importar.%RESET%
    pause
    exit /b 1
)

:: --- Crear scripts auxiliares ---
echo %YELLOW%Creando scripts de lanzamiento...%RESET%

:: Run_AURA.bat
(
echo @echo off
echo cd /d "%%~dp0"
echo call "%VENV_DIR%\Scripts\activate.bat"
echo python "AURA VER 1.0.py"
echo pause
) > "Run_AURA.bat"

:: Check_AURA.bat
(
echo @echo off
echo cd /d "%%~dp0"
echo call "%VENV_DIR%\Scripts\activate.bat"
echo python -c "import torch; print(f'PyTorch: {torch.__version__}')"
echo python -c "import monai; print(f'MONAI: {monai.__version__}')"
echo python -c "from totalsegmentator.python_api import totalsegmentator; print('TotalSegmentator: OK')"
echo pause
) > "Check_AURA.bat"

:: --- Mensaje final ---
echo %GREEN%
echo ========================================================================
echo Instalación completada exitosamente!
echo ========================================================================
echo %RESET%
echo Ejecuta %CYAN%Run_AURA.bat%RESET% para iniciar la aplicación.
echo.
pause