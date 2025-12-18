# Solución: Pantalla de Descarga de Modelos en Primer Inicio

## Problema Resuelto

Cuando se ejecutaba el EXE de AURA y se hacía clic en "Seleccionar órganos", la aplicación fallaba porque los modelos de TotalSegmentator no estaban descargados. En la versión Python esto no era problema porque se descargaban automáticamente, pero en el EXE causaba errores.

## Solución Implementada

Se ha implementado un sistema de configuración inicial que detecta automáticamente si es la primera vez que se ejecuta AURA y muestra una ventana para descargar los modelos necesarios.

### Archivos Modificados/Creados

1. **`first_run_setup.py`** (NUEVO)
   - Módulo que maneja la verificación y descarga de modelos
   - Contiene la clase `FirstRunSetupWindow` para la interfaz gráfica
   - Función `check_first_run()` para detectar si es el primer inicio
   - Función `run_first_setup()` para ejecutar el proceso

2. **`AURA VER 1.0.py`** (MODIFICADO)
   - Línea 25: Importación del módulo `first_run_setup`
   - Líneas 4864-4874: Verificación de primer inicio antes de abrir la aplicación principal

3. **`build_exe.py`** (MODIFICADO)
   - Línea 175: Agregado `first_run_setup` como módulo oculto para PyInstaller

4. **`aura_installer.iss`** (MODIFICADO)
   - Línea 52: Agregado `first_run_setup.py` a los archivos del instalador

## Funcionamiento

### Primera Ejecución

1. El usuario ejecuta AURA.exe por primera vez
2. El splash screen se muestra mientras se cargan las dependencias
3. Se verifica si existe el directorio `~/.totalsegmentator/nnunet/results`
4. Si NO existe o está vacío:
   - Se muestra la ventana de "Configuración Inicial"
   - El usuario puede:
     - **Descargar Modelos**: Descarga los modelos (2-5 GB) inmediatamente
     - **Omitir**: Continúa sin descargar (se descargarán al hacer la primera segmentación)
5. Una vez completado o omitido, se abre la aplicación principal

### Ejecuciones Posteriores

Si los modelos ya están descargados, la ventana de configuración inicial no se muestra y la aplicación se abre directamente.

## Ventana de Configuración Inicial

La ventana incluye:

- **Título**: "Bienvenido a AURA"
- **Descripción**: Explica que es necesario descargar modelos
- **Información**:
  - Tamaño de descarga: 2-5 GB
  - Tiempo estimado: 5-15 minutos
  - Ubicación: `~/.totalsegmentator`
- **Barra de progreso**: Muestra el estado de la descarga
- **Log de salida**: Muestra mensajes detallados del proceso
- **Botones**:
  - "Descargar Modelos": Inicia la descarga
  - "Omitir (Descargar después)": Continúa sin descargar
  - "Cerrar": Se habilita al completar

## Proceso de Descarga

La descarga se realiza utilizando el sistema interno de TotalSegmentator:

```python
from totalsegmentatorv2.bin.totalseg_download_weights import download_pretrained_weights
download_pretrained_weights(task_id=291)  # Modelo 'total'
```

## Ventajas de Esta Solución

1. **Experiencia mejorada**: El usuario sabe qué esperar desde el inicio
2. **Sin errores inesperados**: No hay fallos al seleccionar órganos
3. **Flexibilidad**: El usuario puede decidir cuándo descargar
4. **Información clara**: Muestra tamaño, tiempo y ubicación de descarga
5. **Feedback visual**: Barra de progreso y log detallado
6. **Manejo de errores**: Si la descarga falla, informa al usuario que se descargará después

## Compilación del Nuevo Instalador

Para crear el instalador con la nueva funcionalidad:

```batch
# Ejecutar desde la raíz del proyecto
crear_instalador.bat
```

O manualmente:

```batch
# 1. Compilar el ejecutable
python build_exe.py --clean

# 2. Crear el instalador
python build_installer.py
```

## Pruebas Recomendadas

### Caso 1: Primera Ejecución (Sin Modelos)

1. Eliminar el directorio `~/.totalsegmentator` (si existe)
2. Ejecutar AURA.exe
3. Verificar que aparece la ventana de configuración inicial
4. Probar el botón "Descargar Modelos"
5. Verificar que la descarga se completa correctamente
6. Verificar que la aplicación principal se abre después

### Caso 2: Primera Ejecución (Omitir Descarga)

1. Eliminar el directorio `~/.totalsegmentator` (si existe)
2. Ejecutar AURA.exe
3. Hacer clic en "Omitir (Descargar después)"
4. Verificar que la aplicación principal se abre
5. Intentar seleccionar órganos (debería funcionar)
6. Al hacer la primera segmentación, verificar que descarga los modelos

### Caso 3: Ejecución con Modelos Existentes

1. Asegurar que existe `~/.totalsegmentator/nnunet/results` con modelos
2. Ejecutar AURA.exe
3. Verificar que NO aparece la ventana de configuración inicial
4. Verificar que la aplicación principal se abre directamente

## Notas Técnicas

### Detección de Primer Inicio

```python
def check_first_run():
    model_dir = Path.home() / ".totalsegmentator" / "nnunet" / "results"
    if model_dir.exists() and any(model_dir.iterdir()):
        return False  # No es primer inicio
    return True  # Es primer inicio
```

### Threading

La descarga se ejecuta en un thread separado para no bloquear la interfaz:

```python
thread = threading.Thread(target=self._download_models, daemon=True)
thread.start()
```

### Integración con PyInstaller

El módulo se agrega como importación oculta para asegurar que se incluya en el EXE:

```python
--hidden-import first_run_setup
```

## Solución de Problemas

### La ventana no aparece en el primer inicio

- Verificar que `first_run_setup.py` está en la misma carpeta que el EXE
- Verificar los logs de la aplicación

### Error al importar first_run_setup

- Asegurar que el módulo está incluido en el build de PyInstaller
- Verificar la línea 175 de `build_exe.py`

### La descarga falla

- Verificar conexión a Internet
- Verificar que TotalSegmentator está correctamente instalado
- Los modelos se descargarán automáticamente al hacer la primera segmentación

## Archivos de Referencia

- [first_run_setup.py](first_run_setup.py:1) - Módulo principal
- [AURA VER 1.0.py](AURA VER 1.0.py:25) - Importación
- [AURA VER 1.0.py](AURA VER 1.0.py:4864-4874) - Integración
- [build_exe.py](build_exe.py:175) - Configuración PyInstaller
- [aura_installer.iss](aura_installer.iss:52) - Configuración instalador
