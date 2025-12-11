# AURA - Instrucciones para Crear el Instalador

Este documento explica cómo crear el instalador completo de AURA con todos los modelos.

## Requisitos Previos

### 1. Python 3.8 o superior
Verifica que tienes Python instalado:
```bash
python --version
```

### 2. Dependencias de Python
Instala todas las dependencias necesarias:
```bash
pip install -r requirements.txt
```

Si no existe `requirements.txt`, instala manualmente:
```bash
pip install pyinstaller pydicom numpy monai torch rt-utils nibabel scipy scikit-image psutil
pip install totalsegmentatorv2
```

### 3. Inno Setup
Descarga e instala Inno Setup desde:
https://jrsoftware.org/isdl.php

**Importante:** Usa la versión 6.x o superior.

## Proceso de Construcción

### Opción 1: Script Automático (Recomendado)

Simplemente ejecuta el script principal que automatiza todo:

```bash
python build_installer.py
```

Este script:
1. ✅ Compila AURA usando PyInstaller (crea AURA.exe)
2. ✅ Crea el instalador usando Inno Setup (AURA_Setup_1.0.exe)
3. ✅ Empaqueta todo en un ZIP (AURA_Distribution.zip)

El proceso completo puede tardar 10-15 minutos dependiendo de tu sistema.

### Opción 2: Usando el Archivo Batch (Windows)

Si prefieres un doble clic:

```bash
crear_instalador.bat
```

### Opción 3: Paso a Paso Manual

Si prefieres hacer cada paso manualmente:

#### Paso 1: Compilar el Ejecutable
```bash
python build_exe.py --clean
```

Esto crea `dist/AURA.exe` (puede tardar 5-10 minutos).

#### Paso 2: Crear el Instalador
Abre Inno Setup y compila el script `aura_installer.iss`, o desde línea de comandos:
```bash
"C:\Program Files (x86)\Inno Setup 6\ISCC.exe" aura_installer.iss
```

Esto crea `installer_output/AURA_Setup_1.0.exe`.

#### Paso 3: Empaquetar en ZIP
Crea manualmente un ZIP con:
- AURA_Setup_1.0.exe
- INSTRUCCIONES.txt (instrucciones de instalación)
- README.md (si existe)
- LICENSE (si existe)

## Verificación del Build

Después de ejecutar `build_installer.py`, deberías tener:

```
AURA/
├── dist/
│   └── AURA.exe                    ← Ejecutable compilado
├── installer_output/
│   └── AURA_Setup_1.0.exe          ← Instalador
└── AURA_Distribution.zip           ← ZIP listo para distribuir
```

## Pruebas del Instalador

### 1. Verificar el Ejecutable
Antes de crear el instalador, prueba el ejecutable:
```bash
cd dist
AURA.exe
```

### 2. Probar el Instalador
Instala AURA en una máquina de prueba o VM:
1. Extrae `AURA_Distribution.zip`
2. Ejecuta `AURA_Setup_1.0.exe`
3. Sigue el asistente de instalación
4. Verifica que AURA funciona correctamente

### 3. Verificar Descarga de Modelos
Durante la instalación, si seleccionas "Descargar modelos automáticamente":
- Los modelos de TotalSegmentator se descargarán (~2-5 GB)
- Esto puede tardar 10-30 minutos dependiendo de tu conexión

Si no descargas durante la instalación, AURA los descargará automáticamente la primera vez que lo uses.

## Solución de Problemas

### Error: "PyInstaller no encontrado"
```bash
pip install pyinstaller
```

### Error: "Inno Setup no encontrado"
- Verifica que Inno Setup está instalado en:
  - `C:\Program Files (x86)\Inno Setup 6\`
  - `C:\Program Files\Inno Setup 6\`
- O agrega ISCC.exe al PATH del sistema

### Error: "AURA.exe no encontrado"
- Asegúrate de ejecutar `python build_exe.py` primero
- Verifica que `dist/AURA.exe` existe

### El ejecutable no inicia
- Verifica que todas las dependencias están instaladas
- Prueba compilar con consola visible: `python build_exe.py --console`
- Revisa los logs en `logs/app.log`

### Instalador no incluye archivos
- Verifica que los archivos existen en la ubicación correcta
- Revisa la sección `[Files]` en `aura_installer.iss`
- Asegúrate de que `dist/AURA.exe` existe antes de crear el instalador

## Personalización

### Cambiar el Icono
Reemplaza `ico.ico` con tu propio icono (32x32 o 256x256 pixels).

### Modificar la Versión
Edita `aura_installer.iss` y cambia:
```ini
#define MyAppVersion "1.0"
```

### Agregar Archivos al Instalador
Edita la sección `[Files]` en `aura_installer.iss`:
```ini
Source: "tu_archivo.txt"; DestDir: "{app}"; Flags: ignoreversion
```

### Cambiar el Nombre del Instalador
Edita `aura_installer.iss`:
```ini
OutputBaseFilename=AURA_Setup_{#MyAppVersion}
```

## Distribución

El archivo `AURA_Distribution.zip` contiene todo lo necesario:
- ✅ Instalador ejecutable
- ✅ Instrucciones de instalación
- ✅ README y licencias

Sube este ZIP a:
- Tu sitio web
- GitHub Releases
- Google Drive / Dropbox
- Servidor FTP

## Tamaño del Instalador

Aproximadamente:
- **AURA.exe:** ~200-400 MB (incluye Python y todas las dependencias)
- **Instalador:** ~200-400 MB
- **ZIP completo:** ~200-400 MB

Los modelos de IA (~2-5 GB) se descargan por separado durante o después de la instalación.

## Notas Importantes

1. **Antivirus:** Algunos antivirus pueden marcar el ejecutable como sospechoso.
   - Esto es normal para ejecutables empaquetados con PyInstaller
   - Considera firmar digitalmente el ejecutable para evitar falsas alarmas

2. **Actualizaciones:** Para distribuir actualizaciones:
   - Incrementa el número de versión en `aura_installer.iss`
   - Recompila siguiendo estos pasos
   - El instalador puede actualizar sobre versiones anteriores

3. **Primera Ejecución:** La primera vez que un usuario ejecuta AURA:
   - Puede tardar 30-60 segundos en iniciar
   - Los modelos de IA se descargarán si no están presentes
   - Esto es normal y solo ocurre una vez

## Soporte

Si encuentras problemas durante el build:
1. Verifica que todos los requisitos previos están instalados
2. Revisa los mensajes de error en la consola
3. Consulta la sección "Solución de Problemas" arriba
4. Revisa los logs en `logs/app.log`

¡Gracias por usar AURA!
