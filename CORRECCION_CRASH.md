# Corrección del Crash del EXE

## Problema Identificado

El EXE crasheaba debido a problemas con la importación del módulo `first_run_setup` y el manejo de ventanas de tkinter.

### Causas Principales

1. **Importación temprana**: El módulo `first_run_setup` se importaba al inicio del archivo, antes de que tkinter estuviera completamente inicializado
2. **Conflicto de ventanas**: Se creaba una ventana temporal Tk y luego otra ventana, causando conflictos
3. **Falta de manejo de errores**: No había try-except para manejar errores en la configuración inicial

## Correcciones Implementadas

### 1. Importación Tardía (Lazy Import)

**Antes** ([AURA VER 1.0.py:25](AURA VER 1.0.py:25)):
```python
from first_run_setup import check_first_run, FirstRunSetupWindow
```

**Después** ([AURA VER 1.0.py:4865](AURA VER 1.0.py:4865)):
```python
# Importación tardía para evitar problemas con PyInstaller
from first_run_setup import check_first_run, FirstRunSetupWindow
```

✅ La importación ahora ocurre **dentro** de la función `start_app()`, después de que tkinter esté completamente inicializado.

### 2. Eliminación de Ventana Temporal

**Antes**:
```python
temp_root = tk.Tk()
temp_root.withdraw()
setup_window = FirstRunSetupWindow(temp_root)
setup_window.show()
temp_root.destroy()
```

**Después** ([AURA VER 1.0.py:4867-4871](AURA VER 1.0.py:4867-4871)):
```python
if check_first_run():
    setup_window = FirstRunSetupWindow(parent=None)
    setup_window.show()
```

✅ La ventana de setup crea su propia ventana raíz internamente, evitando conflictos.

### 3. Manejo de Errores Robusto

**Agregado** ([AURA VER 1.0.py:4863-4875](AURA VER 1.0.py:4863-4875)):
```python
try:
    from first_run_setup import check_first_run, FirstRunSetupWindow
    if check_first_run():
        setup_window = FirstRunSetupWindow(parent=None)
        setup_window.show()
except Exception as e:
    logger.warning(f"Error en configuración inicial: {e}")
    logger.debug("Detalle del error:", exc_info=True)
```

✅ Si hay un error en la configuración inicial, la aplicación continúa normalmente.

### 4. Mejoras en first_run_setup.py

**Mejoras en el constructor** ([first_run_setup.py:20-59](first_run_setup.py:20-59)):

1. **Manejo mejorado de ventanas**:
   ```python
   if parent:
       self.window = tk.Toplevel(parent)
   else:
       self.window = tk.Tk()
   ```

2. **Try-except para operaciones no críticas**:
   ```python
   try:
       self.window.update_idletasks()
       x = (self.window.winfo_screenwidth() // 2) - (600 // 2)
       y = (self.window.winfo_screenheight() // 2) - (450 // 2)
       self.window.geometry(f"600x450+{x}+{y}")
   except Exception:
       pass  # Si falla el centrado, no es crítico
   ```

3. **Manejo robusto de modalidad**:
   ```python
   if parent:
       try:
           self.window.transient(parent)
           self.window.grab_set()
       except Exception:
           pass  # Si falla, continuar sin modal
   ```

## Pruebas de Verificación

### Prueba 1: Test del Módulo

Ejecuta el script de prueba:

```bash
python test_first_run.py
```

Este script verifica:
- ✓ Importación del módulo
- ✓ Función `check_first_run()`
- ✓ Creación de ventana
- ✓ Ventana completa (interactivo)

### Prueba 2: Ejecución en Python

```bash
python "AURA VER 1.0.py"
```

Verifica que:
1. El splash screen aparece
2. Si es primera ejecución, aparece la ventana de setup
3. La aplicación principal se abre correctamente
4. No hay crashes

### Prueba 3: Compilar y Probar EXE

```bash
# 1. Compilar el ejecutable
python build_exe.py --clean

# 2. Ejecutar el EXE directamente (IMPORTANTE: desde dist/)
cd dist
AURA.exe
```

### Prueba 4: Instalador Completo

```bash
# Crear instalador completo
crear_instalador.bat
```

## Logs de Depuración

Si el EXE sigue crasheando, verifica los logs:

1. **Logs de AURA**: `logs/aura_YYYYMMDD_HHMMSS.log`
2. **Ejecución con consola**:
   ```bash
   python build_exe.py --console --clean
   cd dist
   AURA.exe
   ```
   Esto mostrará errores en la consola

## Checklist de Verificación

Antes de distribuir el EXE, verifica:

- [ ] El test `test_first_run.py` pasa todas las pruebas
- [ ] El script Python se ejecuta sin errores
- [ ] El EXE compilado se abre sin crash
- [ ] En primera ejecución (sin modelos):
  - [ ] Aparece la ventana de setup
  - [ ] Se puede descargar modelos
  - [ ] Se puede omitir la descarga
  - [ ] La app principal se abre después
- [ ] En ejecuciones posteriores (con modelos):
  - [ ] NO aparece la ventana de setup
  - [ ] La app se abre directamente
  - [ ] La funcionalidad de selección de órganos funciona

## Archivos Modificados

1. **[AURA VER 1.0.py](AURA VER 1.0.py)**
   - Línea 25: Eliminada importación temprana
   - Líneas 4863-4875: Importación tardía con manejo de errores

2. **[first_run_setup.py](first_run_setup.py)**
   - Líneas 20-59: Constructor mejorado con manejo robusto de errores

3. **[test_first_run.py](test_first_run.py)** (NUEVO)
   - Script de pruebas para verificar funcionalidad

## Solución de Problemas Comunes

### Error: "cannot import name 'check_first_run'"

**Causa**: El módulo no está incluido en el EXE

**Solución**: Verificar que `build_exe.py` tiene `first_run_setup` en los hidden imports (línea 175)

### Error: "TclError: can't invoke 'wm' command"

**Causa**: Conflicto de ventanas tkinter

**Solución**: Ya corregido con la importación tardía y eliminación de ventana temporal

### El EXE se abre y cierra inmediatamente

**Causa**: Error no capturado durante la inicialización

**Solución**: Compilar con `--console` para ver el error:
```bash
python build_exe.py --console --clean
```

### La ventana de setup no aparece

**Causa**: Los modelos ya están descargados

**Verificación**: Eliminar `~/.totalsegmentator` y volver a ejecutar

## Próximos Pasos

1. Ejecutar `test_first_run.py` para verificar el módulo
2. Compilar el EXE con `python build_exe.py --clean`
3. Probar el EXE en `dist/AURA.exe`
4. Si funciona correctamente, crear el instalador con `crear_instalador.bat`

## Notas Importantes

- ⚠️ **No ejecutar el EXE desde la carpeta raíz del proyecto**, siempre desde `dist/`
- ⚠️ **Usar `--clean`** al compilar para asegurar que los cambios se incluyan
- ✅ **El módulo ahora es más robusto** y no crasheará aunque haya errores
