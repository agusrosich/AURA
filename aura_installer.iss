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
; Icono del instalador (si existe)
SetupIconFile=ico.ico
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
Name: "desktopicon"; Description: "Crear un acceso directo en el {cm:Desktop}"; GroupDescription: "Accesos directos adicionales:"; Flags: unchecked
Name: "downloadmodels"; Description: "Descargar modelos de TotalSegmentator automáticamente"; GroupDescription: "Configuración inicial:"; Flags: checkedonce

[Files]
; Ejecutable principal (debe estar en dist/ después de build_exe.py)
Source: "dist\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
; Carpeta de modelos (si existe)
Source: "models\*"; DestDir: "{app}\models"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "*.pyc,__pycache__"
; Scripts auxiliares
Source: "download_models.py"; DestDir: "{app}"; Flags: ignoreversion
Source: "gpu_setup.py"; DestDir: "{app}"; Flags: ignoreversion
; Iconos
Source: "ico.png"; DestDir: "{app}"; Flags: ignoreversion; Check: FileExists('ico.png')
Source: "splashscreen.png"; DestDir: "{app}"; Flags: ignoreversion; Check: FileExists('splashscreen.png')
; README y licencia (si existen)
Source: "README.md"; DestDir: "{app}"; Flags: ignoreversion isreadme; Check: FileExists('README.md')

[Icons]
; Acceso directo en el menú inicio
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Desinstalar {#MyAppName}"; Filename: "{uninstallexe}"
; Acceso directo en el escritorio (si el usuario lo seleccionó)
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
; Descargar modelos si el usuario lo seleccionó
Filename: "{sys}\cmd.exe"; Parameters: "/c python ""{app}\download_models.py"""; WorkingDir: "{app}"; StatusMsg: "Descargando modelos de TotalSegmentator..."; Tasks: downloadmodels; Flags: runhidden waituntilterminated
; Ejecutar la aplicación al finalizar
Filename: "{app}\{#MyAppExeName}"; Description: "Ejecutar {#MyAppName}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; Limpiar archivos generados durante el uso
Type: filesandordirs; Name: "{app}\logs"
Type: filesandordirs; Name: "{app}\__pycache__"
Type: files; Name: "{app}\*.log"

[Code]
function FileExists(FileName: string): Boolean;
begin
  Result := FileExists(ExpandConstant('{src}\' + FileName));
end;

procedure InitializeWizard;
var
  WelcomePage: TWizardPage;
begin
  // Personalizar la página de bienvenida
end;
