@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

:: Ruta base = carpeta donde está este .bat
set "BASE_DIR=%~dp0"

:: Ruta del venv de AURA
set "VENV_DIR=%BASE_DIR%aura_venv"

:: Comprobar que existe el venv
if not exist "%VENV_DIR%\Scripts\activate.bat" (
    echo ❌ No se encontró el entorno virtual en: %VENV_DIR%
    echo Asegúrate de que AURA esté instalado y el venv exista.
    pause
    exit /b 1
)

echo ===============================================
echo Activando entorno virtual de AURA...
echo ===============================================
call "%VENV_DIR%\Scripts\activate.bat"

echo ===============================================
echo Intentando instalar TotalSegmentatorV2 desde GitHub (requiere Git)...
echo ===============================================
where git >nul 2>nul
if errorlevel 1 (
    echo ⚠ Git no está instalado o no está en el PATH.
    goto install_zip
)

pip install --upgrade pip
pip install git+https://github.com/StanfordMIMI/TotalSegmentatorV2.git
if errorlevel 1 (
    echo ⚠ Falló la instalación con Git.
    goto install_zip
)

echo ===============================================
echo ✔ Instalación finalizada con Git
echo ===============================================
pause
exit /b 0

:install_zip
echo ===============================================
echo Descargando ZIP de TotalSegmentatorV2...
echo ===============================================
set "ZIP_FILE=%TEMP%\TotalSegmentatorV2-main.zip"
powershell -Command "Invoke-WebRequest -Uri https://github.com/StanfordMIMI/TotalSegmentatorV2/archive/refs/heads/main.zip -OutFile '%ZIP_FILE%'"

if not exist "%ZIP_FILE%" (
    echo ❌ No se pudo descargar el ZIP. Revisa tu conexión a internet.
    pause
    exit /b 1
)

echo ===============================================
echo Instalando desde ZIP...
echo ===============================================
pip install --upgrade pip
pip install "%ZIP_FILE%"

echo ===============================================
echo ✔ Instalación finalizada desde ZIP
echo ===============================================
pause
