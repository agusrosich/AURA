@echo off
echo ================================================================
echo AURA - Prueba de Creacion de Instalador
echo ================================================================
echo.

REM Verificar que existe el ejecutable
if not exist "dist\AURA.exe" (
    echo ERROR: No se encuentra dist\AURA.exe
    echo Por favor ejecuta primero: python build_exe.py
    echo.
    pause
    exit /b 1
)

echo [OK] Ejecutable encontrado: dist\AURA.exe
echo.

REM Verificar Inno Setup
set INNO_PATH=C:\Program Files (x86)\Inno Setup 6\ISCC.exe
if not exist "%INNO_PATH%" (
    echo ERROR: No se encuentra Inno Setup en: %INNO_PATH%
    echo.
    echo Verifica la ruta de instalacion de Inno Setup.
    pause
    exit /b 1
)

echo [OK] Inno Setup encontrado: %INNO_PATH%
echo.

REM Crear directorio de salida si no existe
if not exist "installer_output" mkdir installer_output

echo Compilando instalador con Inno Setup...
echo.

REM Ejecutar Inno Setup
"%INNO_PATH%" "aura_installer.iss"

if %errorlevel% neq 0 (
    echo.
    echo ERROR: Fallo la compilacion del instalador
    echo Codigo de error: %errorlevel%
    echo.
    echo Revisa el archivo aura_installer.iss para mas detalles.
    pause
    exit /b 1
)

echo.
echo ================================================================
echo INSTALADOR CREADO EXITOSAMENTE
echo ================================================================
echo.

dir installer_output\*.exe

echo.
echo El instalador esta en: installer_output\
echo.
pause
