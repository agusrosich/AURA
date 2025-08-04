@echo off
setlocal enabledelayedexpansion

:: ========================================================================
:: AURA - Automatic Segmentation Tool - Auto Installer (Virtual Environment)
:: Instalador completamente automático - Busca e instala Python si es necesario
:: ========================================================================

title AURA Installation and Setup - AUTOMATIC

:: Colors for better visualization
for /F %%a in ('echo prompt $E ^| cmd') do set "ESC=%%a"
set "GREEN=%ESC%[92m"
set "YELLOW=%ESC%[93m"
set "RED=%ESC%[91m"
set "BLUE=%ESC%[94m"
set "CYAN=%ESC%[96m"
set "MAGENTA=%ESC%[95m"
set "RESET=%ESC%[0m"

echo %BLUE%
echo ========================================================================
echo                    AURA - Automatic Segmentation Tool
echo                      INSTALADOR COMPLETAMENTE AUTOMATICO
echo                    Busca Python o lo instala automaticamente
echo ========================================================================
echo %RESET%

:: Check if script is running from correct directory
if not exist "AURA VER 1.0.py" (
    echo %RED%Error: AURA VER 1.0.py no encontrado en este directorio!%RESET%
    echo Por favor asegurate de que este archivo .bat este en la misma carpeta que AURA VER 1.0.py
    echo.
    echo %YELLOW%Presiona cualquier tecla para cerrar...%RESET%
    pause >nul
    exit /b 1
)

:: Define paths
set "VENV_DIR=%~dp0aura_venv"
set "PYTHON_VENV=%VENV_DIR%\Scripts\python.exe"
set "PIP_VENV=%VENV_DIR%\Scripts\pip.exe"
set "ACTIVATE_SCRIPT=%VENV_DIR%\Scripts\activate.bat"
set "PYTHON_INSTALLER=%~dp0python-installer.exe"

echo %CYAN%🔍 BUSCANDO PYTHON EN EL SISTEMA...%RESET%
echo.

:: Variable para almacenar la ruta de Python encontrada
set "PYTHON_PATH="
set "PYTHON_FOUND=0"

:: Función para verificar si una ruta de Python es válida
:check_python_path
set "TEST_PATH=%~1"
if not exist "%TEST_PATH%" goto :eof
"%TEST_PATH%" --version >nul 2>&1
if !errorlevel! equ 0 (
    :: Verificar que sea Python 3.8+
    for /f "tokens=2" %%a in ('"%TEST_PATH%" --version 2^>^&1') do set "TEST_VERSION=%%a"
    for /f "tokens=1,2 delims=." %%a in ("!TEST_VERSION!") do (
        set "TEST_MAJOR=%%a"
        set "TEST_MINOR=%%b"
    )
    if !TEST_MAJOR! geq 3 (
        if !TEST_MAJOR! gtr 3 (
            set "PYTHON_PATH=%TEST_PATH%"
            set "PYTHON_FOUND=1"
            set "PYTHON_VERSION=!TEST_VERSION!"
            goto :eof
        ) else if !TEST_MINOR! geq 8 (
            set "PYTHON_PATH=%TEST_PATH%"
            set "PYTHON_FOUND=1"
            set "PYTHON_VERSION=!TEST_VERSION!"
            goto :eof
        )
    )
)
goto :eof

:: 1. Buscar Python en PATH
echo %YELLOW%📁 Buscando en PATH del sistema...%RESET%
python --version >nul 2>&1
if !errorlevel! equ 0 (
    call :check_python_path "python"
    if !PYTHON_FOUND! equ 1 (
        echo %GREEN%✅ Python encontrado en PATH: !PYTHON_VERSION!%RESET%
        goto :python_found
    )
)

:: 2. Buscar en ubicaciones comunes de Windows
echo %YELLOW%📁 Buscando en ubicaciones comunes...%RESET%

:: Lista de ubicaciones comunes donde se instala Python
set "SEARCH_PATHS="
set "SEARCH_PATHS=!SEARCH_PATHS! %LOCALAPPDATA%\Programs\Python"
set "SEARCH_PATHS=!SEARCH_PATHS! %APPDATA%\Local\Programs\Python"
set "SEARCH_PATHS=!SEARCH_PATHS! C:\Python3*"
set "SEARCH_PATHS=!SEARCH_PATHS! C:\Program Files\Python3*"
set "SEARCH_PATHS=!SEARCH_PATHS! C:\Program Files (x86)\Python3*"
set "SEARCH_PATHS=!SEARCH_PATHS! %USERPROFILE%\AppData\Local\Programs\Python"
set "SEARCH_PATHS=!SEARCH_PATHS! %USERPROFILE%\Python3*"

:: Buscar en cada ubicación
for %%P in (!SEARCH_PATHS!) do (
    if exist "%%P" (
        for /d %%D in ("%%P\Python3*") do (
            if exist "%%D\python.exe" (
                echo %CYAN%   Probando: %%D\python.exe%RESET%
                call :check_python_path "%%D\python.exe"
                if !PYTHON_FOUND! equ 1 (
                    echo %GREEN%✅ Python encontrado: %%D\python.exe - Version !PYTHON_VERSION!%RESET%
                    goto :python_found
                )
            )
        )
        :: Buscar también directamente en la carpeta
        if exist "%%P\python.exe" (
            echo %CYAN%   Probando: %%P\python.exe%RESET%
            call :check_python_path "%%P\python.exe"
            if !PYTHON_FOUND! equ 1 (
                echo %GREEN%✅ Python encontrado: %%P\python.exe - Version !PYTHON_VERSION!%RESET%
                goto :python_found
            )
        )
    )
)

:: 3. Buscar usando PowerShell
echo %YELLOW%📁 Buscando con PowerShell...%RESET%
for /f "delims=" %%i in ('powershell -Command "Get-Command python -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source" 2^>nul') do (
    if not "%%i"=="" (
        echo %CYAN%   Probando: %%i%RESET%
        call :check_python_path "%%i"
        if !PYTHON_FOUND! equ 1 (
            echo %GREEN%✅ Python encontrado via PowerShell: %%i - Version !PYTHON_VERSION!%RESET%
            goto :python_found
        )
    )
)

:: 4. Buscar en Microsoft Store
echo %YELLOW%📁 Buscando instalacion de Microsoft Store...%RESET%
if exist "%USERPROFILE%\AppData\Local\Microsoft\WindowsApps\python.exe" (
    echo %CYAN%   Probando: Microsoft Store Python%RESET%
    call :check_python_path "%USERPROFILE%\AppData\Local\Microsoft\WindowsApps\python.exe"
    if !PYTHON_FOUND! equ 1 (
        echo %GREEN%✅ Python de Microsoft Store encontrado - Version !PYTHON_VERSION!%RESET%
        goto :python_found
    )
)

:: 5. Búsqueda exhaustiva en todo el sistema (solo directorios principales)
echo %YELLOW%📁 Realizando busqueda exhaustiva (esto puede tomar un momento)...%RESET%
for %%D in (C D E F) do (
    if exist "%%D:\" (
        echo %CYAN%   Buscando en unidad %%D:\...%RESET%
        for /f "delims=" %%F in ('dir "%%D:\python.exe" /s /b 2^>nul ^| findstr /i "python\.exe$"') do (
            echo %CYAN%   Probando: %%F%RESET%
            call :check_python_path "%%F"
            if !PYTHON_FOUND! equ 1 (
                echo %GREEN%✅ Python encontrado: %%F - Version !PYTHON_VERSION!%RESET%
                goto :python_found
            )
        )
    )
)

:: 6. Si no se encuentra, preguntar ruta manual
echo.
echo %RED%❌ Python no encontrado automaticamente.%RESET%
echo.
echo %YELLOW%Opciones disponibles:%RESET%
echo 1. Instalar Python automaticamente (RECOMENDADO)
echo 2. Especificar ruta manual de Python
echo 3. Salir y instalar Python manualmente
echo.
set /p "choice=Selecciona una opcion (1/2/3): "

if "%choice%"=="1" goto :install_python
if "%choice%"=="2" goto :manual_path
if "%choice%"=="3" goto :manual_install_exit

echo %RED%Opcion invalida. Instalando Python automaticamente...%RESET%
goto :install_python

:manual_path
echo.
echo %YELLOW%Por favor, ingresa la ruta completa al ejecutable de Python:%RESET%
echo %CYAN%Ejemplo: C:\Python39\python.exe%RESET%
echo %CYAN%         C:\Users\TuUsuario\AppData\Local\Programs\Python\Python39\python.exe%RESET%
echo.
set /p "manual_python_path=Ruta de Python: "

if "%manual_python_path%"=="" (
    echo %RED%No se ingreso ninguna ruta.%RESET%
    goto :manual_path
)

echo %YELLOW%Verificando ruta ingresada...%RESET%
call :check_python_path "%manual_python_path%"
if !PYTHON_FOUND! equ 1 (
    echo %GREEN%✅ Python valido encontrado: !PYTHON_VERSION!%RESET%
    goto :python_found
) else (
    echo %RED%❌ La ruta ingresada no contiene un Python valido (requiere 3.8+)%RESET%
    echo.
    set /p "retry=¿Intentar con otra ruta? (s/n): "
    if /i "!retry!"=="s" goto :manual_path
    goto :install_python
)

:install_python
echo.
echo %MAGENTA%
echo ========================================================================
echo                    INSTALACION AUTOMATICA DE PYTHON
echo ========================================================================
echo %RESET%
echo.
echo %YELLOW%Python no esta instalado o no es compatible.%RESET%
echo %YELLOW%Instalando Python automaticamente...%RESET%
echo.
echo %CYAN%Esto incluira:%RESET%
echo - Python 3.11 (version estable recomendada)
echo - pip (gestor de paquetes)
echo - Configuracion automatica del PATH
echo.

:: Descargar Python si no existe
if not exist "%PYTHON_INSTALLER%" (
    echo %YELLOW%Descargando Python 3.11...%RESET%
    echo %CYAN%Esto puede tomar varios minutos dependiendo de tu conexion...%RESET%
    
    :: Usar PowerShell para descargar
    powershell -Command "& {[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://www.python.org/ftp/python/3.11.8/python-3.11.8-amd64.exe' -OutFile '%PYTHON_INSTALLER%' -UseBasicParsing}" 2>nul
    
    if !errorlevel! neq 0 (
        echo %RED%Error descargando Python. Intentando metodo alternativo...%RESET%
        :: Método alternativo con curl si está disponible
        curl -L -o "%PYTHON_INSTALLER%" "https://www.python.org/ftp/python/3.11.8/python-3.11.8-amd64.exe" 2>nul
        
        if !errorlevel! neq 0 (
            echo %RED%No se pudo descargar Python automaticamente.%RESET%
            goto :manual_install_exit
        )
    )
    
    echo %GREEN%✅ Python descargado exitosamente!%RESET%
)

:: Instalar Python silenciosamente
echo %YELLOW%Instalando Python...%RESET%
echo %CYAN%Esto tomara unos minutos...%RESET%

"%PYTHON_INSTALLER%" /quiet InstallAllUsers=0 PrependPath=1 Include_test=0 Include_doc=0 Include_dev=0 InstallLauncherAllUsers=0

if !errorlevel! neq 0 (
    echo %RED%Error durante la instalacion de Python.%RESET%
    echo %YELLOW%Intentando instalacion interactiva...%RESET%
    "%PYTHON_INSTALLER%"
    if !errorlevel! neq 0 (
        echo %RED%Instalacion fallida.%RESET%
        goto :manual_install_exit
    )
)

:: Limpiar instalador
if exist "%PYTHON_INSTALLER%" del "%PYTHON_INSTALLER%" >nul 2>&1

echo %GREEN%✅ Python instalado exitosamente!%RESET%

:: Refrescar variables de entorno
echo %YELLOW%Actualizando variables de entorno...%RESET%
call :refresh_env

:: Buscar Python nuevamente después de la instalación
echo %YELLOW%Verificando instalacion...%RESET%
timeout /t 3 >nul

:: Buscar en las ubicaciones más probables después de la instalación
for %%P in ("%USERPROFILE%\AppData\Local\Programs\Python" "%LOCALAPPDATA%\Programs\Python") do (
    if exist "%%P" (
        for /d %%D in ("%%P\Python3*") do (
            if exist "%%D\python.exe" (
                call :check_python_path "%%D\python.exe"
                if !PYTHON_FOUND! equ 1 goto :python_found
            )
        )
    )
)

:: Probar PATH nuevamente
python --version >nul 2>&1
if !errorlevel! equ 0 (
    call :check_python_path "python"
    if !PYTHON_FOUND! equ 1 goto :python_found
)

echo %RED%Python fue instalado pero no se puede acceder automaticamente.%RESET%
echo %YELLOW%Por favor reinicia este programa o reinicia tu computadora.%RESET%
pause
exit /b 1

:manual_install_exit
echo.
echo %CYAN%
echo ========================================================================
echo                        INSTALACION MANUAL REQUERIDA
echo ========================================================================
echo %RESET%
echo.
echo %YELLOW%Para continuar, necesitas instalar Python manualmente:%RESET%
echo.
echo %CYAN%1. Ve a: https://www.python.org/downloads/%RESET%
echo %CYAN%2. Descarga Python 3.8 o superior%RESET%
echo %CYAN%3. Durante la instalacion, marca: "Add Python to PATH"%RESET%
echo %CYAN%4. Ejecuta este instalador nuevamente%RESET%
echo.
echo %YELLOW%Presiona cualquier tecla para abrir la pagina de descarga...%RESET%
pause >nul
start https://www.python.org/downloads/
exit /b 1

:refresh_env
:: Función para refrescar variables de entorno
for /f "usebackq tokens=2,*" %%A in (`reg query HKCU\Environment /v PATH 2^>nul`) do set "USER_PATH=%%B"
for /f "usebackq tokens=2,*" %%A in (`reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v PATH 2^>nul`) do set "SYSTEM_PATH=%%B"
set "PATH=%SYSTEM_PATH%;%USER_PATH%"
goto :eof

:python_found
echo.
echo %GREEN%
echo ========================================================================
echo                        PYTHON ENCONTRADO Y VERIFICADO
echo ========================================================================
echo %RESET%
echo.
echo %GREEN%✅ Python Version: !PYTHON_VERSION!%RESET%
echo %GREEN%✅ Ubicacion: !PYTHON_PATH!%RESET%
echo.

:: Definir comando Python a usar
if "!PYTHON_PATH!"=="python" (
    set "PYTHON_CMD=python"
) else (
    set "PYTHON_CMD=!PYTHON_PATH!"
)

:: Verificar pip
echo %YELLOW%Verificando pip...%RESET%
"!PYTHON_CMD!" -m pip --version >nul 2>&1
if !errorlevel! neq 0 (
    echo %YELLOW%Instalando pip...%RESET%
    "!PYTHON_CMD!" -m ensurepip --upgrade
    if !errorlevel! neq 0 (
        echo %RED%Error instalando pip. Continuando...%RESET%
    )
)

:: Continuar con el resto del proceso original...
echo %YELLOW%Verificando entorno virtual...%RESET%

if exist "%PYTHON_VENV%" (
    echo %GREEN%✅ Entorno virtual ya existe!%RESET%
    goto :check_packages
)

echo %YELLOW%Creando entorno virtual de Python...%RESET%
"!PYTHON_CMD!" -m venv "%VENV_DIR%"
if !errorlevel! neq 0 (
    echo %RED%Error creando entorno virtual!%RESET%
    echo Asegurate de tener la instalacion completa de Python con el modulo venv.
    pause
    exit /b 1
)

echo %YELLOW%Actualizando pip en entorno virtual...%RESET%
"%PYTHON_VENV%" -m pip install --upgrade pip --no-warn-script-location

:check_packages
echo %YELLOW%Verificando paquetes requeridos...%RESET%

:: Verificación rápida de paquetes
set "PACKAGES_OK=1"
"%PYTHON_VENV%" -c "import torch, pydicom, monai, scipy, skimage, rt_utils, nibabel, psutil" 2>nul
if !errorlevel! neq 0 set "PACKAGES_OK=0"

if "%PACKAGES_OK%"=="1" (
    echo %GREEN%✅ Todos los paquetes ya estan instalados!%RESET%
    goto :check_totalsegmentator
)

echo %YELLOW%Instalando paquetes requeridos...%RESET%
echo.
echo %CYAN%Este proceso instalara paquetes en el siguiente orden:%RESET%
echo 1. Paquetes esenciales (scipy, psutil, pydicom, nibabel)
echo 2. Procesamiento de imagenes (scikit-image) 
echo 3. Imagenes medicas (rt-utils)
echo 4. MONAI (framework de IA medica)
echo 5. PyTorch (aprendizaje profundo - descarga mas grande)
echo.
echo %YELLOW%Tamaño total de descarga: ~2-3 GB%RESET%
echo %YELLOW%Tiempo estimado: 10-30 minutos dependiendo de la velocidad de internet%RESET%
echo.
echo %GREEN%Instalacion automatica iniciando en 5 segundos...%RESET%
echo %CYAN%Presiona Ctrl+C para cancelar%RESET%
timeout /t 5

:: Instalar paquetes en orden optimizado (más pequeños primero)
echo.
echo %CYAN%Paso 1/6: Instalando paquetes esenciales...%RESET%
"%PIP_VENV%" install psutil pydicom nibabel --no-warn-script-location
if !errorlevel! neq 0 (
    echo %RED%Advertencia: Algunos paquetes esenciales fallaron al instalarse%RESET%
)

echo.
echo %CYAN%Paso 2/6: Instalando SciPy...%RESET%
"%PIP_VENV%" install scipy --no-warn-script-location
if !errorlevel! neq 0 (
    echo %RED%Advertencia: Instalacion de SciPy fallo%RESET%
)

echo.
echo %CYAN%Paso 3/6: Instalando scikit-image...%RESET%
"%PIP_VENV%" install scikit-image --no-warn-script-location
if !errorlevel! neq 0 (
    echo %RED%Advertencia: Instalacion de scikit-image fallo%RESET%
)

echo.
echo %CYAN%Paso 4/6: Instalando rt-utils...%RESET%
"%PIP_VENV%" install rt-utils --no-warn-script-location
if !errorlevel! neq 0 (
    echo %RED%Advertencia: Instalacion de rt-utils fallo%RESET%
)

echo.
echo %CYAN%Paso 5/6: Instalando MONAI...%RESET%
"%PIP_VENV%" install monai --no-warn-script-location
if !errorlevel! neq 0 (
    echo %RED%Advertencia: Instalacion de MONAI fallo%RESET%
)

echo.
echo %CYAN%Paso 6/6: Instalando PyTorch (esto tomara mas tiempo)...%RESET%
echo %YELLOW%Descargando PyTorch con soporte CUDA...%RESET%
echo %YELLOW%Si esto falla, probaremos la version solo CPU%RESET%
echo.

:: Probar version CUDA primero
"%PIP_VENV%" install torch torchvision --index-url https://download.pytorch.org/whl/cu118 --no-warn-script-location
if !errorlevel! neq 0 (
    echo.
    echo %YELLOW%Version CUDA fallo, instalando version CPU...%RESET%
    echo %YELLOW%Esto es normal si no tienes una GPU NVIDIA%RESET%
    "%PIP_VENV%" install torch torchvision --no-warn-script-location
    if !errorlevel! neq 0 (
        echo %RED%Error: ¡Instalacion de PyTorch fallo completamente!%RESET%
        echo %YELLOW%Puedes intentar ejecutar este instalador nuevamente mas tarde%RESET%
        echo %YELLOW%O instalar PyTorch manualmente desde pytorch.org%RESET%
        pause
    ) else (
        echo %GREEN%✅ Version CPU de PyTorch instalada exitosamente!%RESET%
    )
) else (
    echo %GREEN%✅ Version CUDA de PyTorch instalada exitosamente!%RESET%
)

:check_totalsegmentator
echo.
echo %CYAN%Instalando TotalSegmentator...%RESET%
"%PYTHON_VENV%" -c "from totalsegmentatorv2.python_api import totalsegmentator" 2>nul
if !errorlevel! neq 0 (
    echo %YELLOW%Instalando TotalSegmentator V2...%RESET%
    "%PIP_VENV%" install totalsegmentatorv2 --no-warn-script-location
    if !errorlevel! neq 0 (
        echo %YELLOW%TotalSegmentator V2 fallo, probando V1...%RESET%
        "%PIP_VENV%" install totalsegmentator --no-warn-script-location
        if !errorlevel! neq 0 (
            echo %RED%Advertencia: Instalacion de TotalSegmentator fallo%RESET%
            echo %YELLOW%Puedes instalarlo mas tarde con: pip install totalsegmentatorv2%RESET%
        )
    )
) else (
    echo %GREEN%✅ TotalSegmentator ya instalado!%RESET%
)

:: Crear scripts de utilidad
echo.
echo %YELLOW%Creando scripts de lanzamiento...%RESET%

:: Crear lanzador principal
(
echo @echo off
echo title AURA - Automatic Segmentation Tool
echo cd /d "%%~dp0"
echo.
echo :: Activar entorno virtual y ejecutar AURA
echo call "%ACTIVATE_SCRIPT%" ^>nul 2^>^&1
echo if %%errorlevel%% neq 0 ^(
echo     echo Error: ¡No se pudo activar el entorno virtual!
echo     echo Por favor ejecuta el instalador nuevamente.
echo     pause
echo     exit /b 1
echo ^)
echo.
echo echo Iniciando AURA...
echo python "AURA VER 1.0.py"
echo.
echo if %%errorlevel%% neq 0 ^(
echo     echo.
echo     echo Ocurrio un error ejecutando AURA.
echo     echo Revisa los mensajes de error anteriores.
echo     pause
echo ^)
echo.
echo :: Desactivar entorno virtual
echo deactivate
) > "Run_AURA.bat"

:: Crear script de actualización
(
echo @echo off
echo title AURA - Update Dependencies
echo cd /d "%%~dp0"
echo.
echo echo Activando entorno virtual...
echo call "%ACTIVATE_SCRIPT%" ^>nul 2^>^&1
echo if %%errorlevel%% neq 0 ^(
echo     echo Error: ¡Entorno virtual no encontrado!
echo     pause
echo     exit /b 1
echo ^)
echo.
echo echo Actualizando dependencias de AURA...
echo python -m pip install --upgrade pip
echo pip install --upgrade torch pydicom monai scipy scikit-image rt-utils nibabel psutil
echo pip install --upgrade totalsegmentatorv2
echo if %%errorlevel%% neq 0 pip install --upgrade totalsegmentator
echo.
echo echo ¡Actualizacion completada!
echo deactivate
echo pause
) > "Update_AURA.bat"

:: Crear script de diagnóstico
(
echo @echo off
echo title AURA - Diagnostic Check
echo cd /d "%%~dp0"
echo.
echo echo Ejecutando verificacion diagnostica de AURA...
echo call "%ACTIVATE_SCRIPT%" ^>nul 2^>^&1
echo if %%errorlevel%% neq 0 ^(
echo     echo Error: ¡Entorno virtual no encontrado!
echo     pause
echo     exit /b 1
echo ^)
echo.
echo echo Version de Python:
echo python --version
echo.
echo echo Verificando paquetes instalados:
echo python -c "import torch; print('PyTorch:', torch.__version__)"
echo python -c "import pydicom; print('PyDICOM:', pydicom.__version__)"
echo python -c "import monai; print('MONAI:', monai.__version__)"
echo python -c "import scipy; print('SciPy:', scipy.__version__)"
echo python -c "import skimage; print('scikit-image:', skimage.__version__)"
echo python -c "import rt_utils; print('rt-utils: OK')"
echo python -c "import nibabel; print('nibabel:', nibabel.__version__)"
echo python -c "import psutil; print('psutil:', psutil.__version__)"
echo.
echo echo Verificando TotalSegmentator:
echo python -c "from totalsegmentatorv2.python_api import totalsegmentator; print('TotalSegmentator V2: OK')" 2^>nul ^|^| echo TotalSegmentator V2: No encontrado
echo python -c "from totalsegmentator.python_api import totalsegmentator; print('TotalSegmentator V1: OK')" 2^>nul ^|^| echo TotalSegmentator V1: No encontrado
echo.
echo echo Disponibilidad CUDA:
echo python -c "import torch; print('CUDA disponible:', torch.cuda.is_available()); if torch.cuda.is_available(): print('Dispositivo CUDA:', torch.cuda.get_device_name())"
echo.
echo deactivate
echo pause
) > "Check_AURA.bat"

:: Crear desinstalador
(
echo @echo off
echo title AURA - Uninstaller
echo echo Este programa eliminara completamente el entorno virtual de AURA.
echo echo Los archivos principales de AURA permaneceran intactos.
echo echo.
echo set /p confirm="¿Estas seguro de que quieres continuar? (s/N): "
echo if /i "%%confirm%%" neq "s" ^(
echo     echo Desinstalacion cancelada.
echo     pause
echo     exit /b 0
echo ^)
echo.
echo echo Eliminando entorno virtual...
echo if exist "%VENV_DIR%" ^(
echo     rmdir /s /q "%VENV_DIR%"
echo     echo ¡Entorno virtual eliminado exitosamente!
echo ^) else ^(
echo     echo Entorno virtual no encontrado.
echo ^)
echo.
echo echo Puedes ejecutar el instalador nuevamente para reinstalar AURA.
echo pause
) > "Uninstall_AURA.bat"

:: Crear archivo de requisitos
(
echo # AURA Dependencies
echo torch^>=2.0.0
echo torchvision
echo pydicom^>=2.3.0
echo monai^>=1.2.0
echo scipy^>=1.10.0
echo scikit-image^>=0.20.0
echo rt-utils^>=1.2.7
echo nibabel^>=4.0.0
echo psutil^>=5.9.0
echo totalsegmentatorv2
) > "requirements.txt"

:: Verificación final
echo %YELLOW%Ejecutando verificacion final...%RESET%

"%PYTHON_VENV%" --version >nul 2>&1
if !errorlevel! neq 0 (
    echo %RED%Error: ¡Python del entorno virtual no funciona!%RESET%
    pause
    exit /b 1
)

echo.
echo %GREEN%
echo ========================================================================
echo                        ¡INSTALACION COMPLETADA!
echo ========================================================================
echo %RESET%
echo %GREEN%¡AURA ha sido instalado exitosamente en un entorno virtual!%RESET%
echo.
echo %BLUE%Para ejecutar AURA:%RESET%
echo   🚀 Doble-click en "Run_AURA.bat"
echo.
echo %BLUE%Scripts disponibles:%RESET%
echo   🚀 Run_AURA.bat      - Ejecutar la aplicacion
echo   🔄 Update_AURA.bat   - Actualizar dependencias  
echo   🔍 Check_AURA.bat    - Informacion de diagnostico
echo   🗑️  Uninstall_AURA.bat - Eliminar entorno virtual
echo.
echo %CYAN%Ubicacion del entorno virtual:%RESET%
echo   %VENV_DIR%
echo.
echo %CYAN%Siguientes pasos:%RESET%
echo 1. Doble-click en "Run_AURA.bat" para iniciar AURA
echo 2. Si encuentras problemas, ejecuta "Check_AURA.bat" para diagnosticos
echo.
echo %YELLOW%Nota: Todas las dependencias estan aisladas en el entorno virtual.%RESET%
echo %YELLOW%Tu instalacion de Python del sistema permanece sin cambios.%RESET%
echo %YELLOW%Nota: La primera ejecucion puede tomar mas tiempo ya que se descargan modelos de IA%RESET%
echo.
echo %GREEN%¡INSTALACION EXITOSA! AURA esta listo para usar.%RESET%
echo.
pause

