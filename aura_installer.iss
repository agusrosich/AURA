; Script de Inno Setup para AURA
; Crea un instalador profesional con descarga automática de modelos

#define MyAppName "AURA"
#define MyAppVersion "1.0"
#define MyAppPublisher "AURA Team"
#define MyAppExeName "AURA.exe"

[Setup]
; Información básica de la aplicación
AppId={{A1B2C3D4-E5F6-4789-A1B2-C3D4E5F67890}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
; Deshabilitar la página de selección de idioma
DisableProgramGroupPage=yes
; Permitir al usuario elegir el directorio
DisableDirPage=no
; Archivo de salida
OutputDir=installer_output
OutputBaseFilename=AURA_Setup_{#MyAppVersion}
; Icono del instalador (comentado - agregar si existe ico.ico)
;SetupIconFile=ico.ico
; Compresión
Compression=lzma2/max
SolidCompression=yes
; Estilo visual moderno de Windows
WizardStyle=modern
; Privilegios requeridos
PrivilegesRequired=admin
; Arquitectura
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Crear un acceso directo en el {cm:Desktop}"; GroupDescription: "Accesos directos:"; Flags: unchecked

[Files]
; Ejecutable principal (debe estar en dist/ después de build_exe.py)
Source: "dist\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
; Carpeta de modelos (si existe - no marcada como requerida)
Source: "models\*"; DestDir: "{app}\models"; Flags: ignoreversion recursesubdirs createallsubdirs skipifsourcedoesntexist; Excludes: "*.pyc,__pycache__"
; Scripts auxiliares
Source: "download_models.py"; DestDir: "{app}"; Flags: ignoreversion
Source: "gpu_setup.py"; DestDir: "{app}"; Flags: ignoreversion
Source: "first_run_setup.py"; DestDir: "{app}"; Flags: ignoreversion
; Manual de usuario
Source: "README_USUARIO.md"; DestDir: "{app}"; Flags: ignoreversion isreadme skipifsourcedoesntexist

[Icons]
; Acceso directo en el menú inicio
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Desinstalar {#MyAppName}"; Filename: "{uninstallexe}"
; Acceso directo en el escritorio (si el usuario lo seleccionó)
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
; Ejecutar la aplicación al finalizar (sin descarga de modelos por ahora)
Filename: "{app}\{#MyAppExeName}"; Description: "Ejecutar {#MyAppName}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; Limpiar archivos generados durante el uso
Type: filesandordirs; Name: "{app}\logs"
Type: filesandordirs; Name: "{app}\__pycache__"
Type: files; Name: "{app}\*.log"
