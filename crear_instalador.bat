@echo off
REM Script para crear el instalador de AURA de forma automatica
REM Solo necesitas hacer doble clic en este archivo

echo ================================================================
echo AURA - Constructor de Instalador
echo ================================================================
echo.

REM Verificar Python
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Python no esta instalado o no esta en el PATH.
    echo Por favor instala Python 3.8 o superior.
    echo.
    pause
    exit /b 1
)

echo [OK] Python encontrado
echo.

REM Verificar que existe el script principal
if not exist "build_installer.py" (
    echo ERROR: No se encontro build_installer.py
    echo Asegurate de ejecutar este script desde la carpeta de AURA.
    echo.
    pause
    exit /b 1
)

echo Iniciando proceso de construccion del instalador...
echo Esto puede tardar 10-15 minutos dependiendo de tu sistema.
echo.
echo Presiona Ctrl+C para cancelar o cualquier tecla para continuar...
pause >nul

echo.
echo ================================================================
echo EJECUTANDO BUILD
echo ================================================================
echo.

REM Ejecutar el script de build
python build_installer.py

if %errorlevel% neq 0 (
    echo.
    echo ================================================================
    echo ERROR: El build fallo
    echo ================================================================
    echo.
    echo Revisa los mensajes de error arriba.
    echo Consulta BUILD_INSTRUCTIONS.md para mas informacion.
    echo.
    pause
    exit /b 1
)

echo.
echo ================================================================
echo BUILD COMPLETADO EXITOSAMENTE
echo ================================================================
echo.
echo El instalador esta listo en:
echo   - installer_output\AURA_Setup_1.0.exe
echo   - AURA_Distribution.zip (listo para distribuir)
echo.
echo Puedes distribuir el archivo AURA_Distribution.zip a los usuarios.
echo.
pause
