@echo off
setlocal enabledelayedexpansion

:: ========================================================================
:: AURA - Optimized Installer with Advanced Python Detection
:: ========================================================================

title AURA Installation and Setup - OPTIMIZED

:: Colores
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

:: Verificar archivo principal
if not exist "AURA VER 1.0.py" (
    echo %RED%Error: AURA VER 1.0.py no está en este directorio.%RESET%
    pause
    exit /b 1
)

:: Definir rutas
set "VENV_DIR=%~dp0aura_venv"
set "PYTHON_VENV=%VENV_DIR%\Scripts\python.exe"
set "PIP_VENV=%VENV_DIR%\Scripts\pip.exe"
set "ACTIVATE_SCRIPT=%VENV_DIR%\Scripts\activate.bat"

:: Detectar Python
set "PYTHON_FOUND=0"
echo %YELLOW%Buscando Python instalado...%RESET%

python --version >nul 2>&1 && (
    set "PYTHON_CMD=python"
    set "PYTHON_FOUND=1"
) || (
    py --version >nul 2>&1 && (
        set "PYTHON_CMD=py -3"
        set "PYTHON_FOUND=1"
    )
)

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
    ) do if exist "%%~P" (
        set "PYTHON_CMD=%%~P"
        set "PYTHON_FOUND=1"
        goto CheckPythonVersion
    )
)

if "!PYTHON_FOUND!"=="0" (
    echo %RED%No se encontró Python automáticamente.%RESET%
    set /p PYTHON_CMD="Ingrese manualmente la ruta completa de python.exe: "
    if exist "!PYTHON_CMD!" (
        set "PYTHON_FOUND=1"
    ) else (
        echo %RED%Ruta proporcionada no válida.%RESET%
        pause
        exit /b 1
    )
)

:CheckPythonVersion
"!PYTHON_CMD!" --version
if !errorlevel! neq 0 (
    echo %RED%Error ejecutando Python.%RESET%
    pause
    exit /b 1
)

for /f "tokens=2" %%v in ('"!PYTHON_CMD!" --version') do set PYTHON_VERSION=%%v
for /f "tokens=1,2 delims=." %%a in ("!PYTHON_VERSION!") do (
    set "MAJOR=%%a"
    set "MINOR=%%b"
)

if !MAJOR! lss 3 (
    echo %RED%Python debe ser versión 3.8 o superior.%RESET%
    pause
    exit /b 1
)
if !MAJOR! equ 3 if !MINOR! lss 8 (
    echo %RED%Python debe ser versión 3.8 o superior.%RESET%
    pause
    exit /b 1
)

echo %GREEN%Usando Python !PYTHON_VERSION!%RESET%

:: Crear o reusar entorno virtual
if exist "%PYTHON_VENV%" (
    echo %GREEN%Entorno virtual existente encontrado.%RESET%
) else (
    echo %YELLOW%Creando entorno virtual...%RESET%
    "!PYTHON_CMD!" -m venv "%VENV_DIR%"
    "%PYTHON_VENV%" -m pip install --upgrade pip
)

:: Instalar paquetes requeridos
echo %YELLOW%Instalando paquetes necesarios...%RESET%
"%PIP_VENV%" install psutil pydicom nibabel scipy scikit-image rt-utils monai --no-warn-script-location
"%PIP_VENV%" install torch torchvision --index-url https://download.pytorch.org/whl/cu118 || (
    echo %YELLOW%Instalando PyTorch CPU...%RESET%
    "%PIP_VENV%" install torch torchvision
)

"%PIP_VENV%" install totalsegmentatorv2 || "%PIP_VENV%" install totalsegmentator

:: Scripts auxiliares
echo %YELLOW%Creando scripts auxiliares...%RESET%

:: Run_AURA.bat
(
echo @echo off
echo call "%ACTIVATE_SCRIPT%"
echo python "AURA VER 1.0.py"
echo pause
)> "Run_AURA.bat"

:: Update_AURA.bat
(
echo @echo off
echo call "%ACTIVATE_SCRIPT%"
echo python -m pip install --upgrade pip torch torchvision pydicom monai scipy scikit-image rt-utils nibabel psutil totalsegmentatorv2 || pip install totalsegmentator
echo pause
)> "Update_AURA.bat"

:: Check_AURA.bat
(
echo @echo off
echo call "%ACTIVATE_SCRIPT%"
echo python --version
echo python -c "import torch, pydicom, monai, scipy, skimage, rt_utils, nibabel, psutil; print('Paquetes OK')"
echo python -c "import torch; print('CUDA disponible:', torch.cuda.is_available())"
echo pause
)> "Check_AURA.bat"

:: Verificación final
"%PYTHON_VENV%" --version >nul 2>&1 || (
    echo %RED%Error en el entorno virtual.%RESET%
    pause
    exit /b 1
)

echo %GREEN%
echo ========================================================================
echo                        Instalación Completa!
echo ========================================================================
echo %RESET%
echo %CYAN%Scripts disponibles:%RESET%
echo Run_AURA.bat      - Ejecutar AURA
echo Update_AURA.bat   - Actualizar paquetes
echo Check_AURA.bat    - Diagnóstico
echo %YELLOW%Primera ejecución puede tardar más por descargas adicionales.%RESET%
pause
