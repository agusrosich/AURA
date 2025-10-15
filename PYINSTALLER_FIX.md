# Solución al problema de apertura múltiple del ejecutable

## Problema
Cuando se ejecutaba el archivo `.exe` generado por PyInstaller, la aplicación se abría múltiples veces de forma infinita hasta crashear Windows.

## Causa
Este es un problema común en Windows cuando se empaquetan aplicaciones Python con PyInstaller que usan:
- `multiprocessing`
- `threading`
- Creación de procesos secundarios

Sin la protección adecuada, Windows interpreta cada intento de crear un nuevo proceso/thread como una señal para lanzar una nueva instancia completa del programa, creando un bucle infinito.

## Solución Implementada

### 1. En `AURA VER 1.0.py`
Se agregó la protección crítica al inicio del bloque `if __name__ == "__main__"`:

```python
import multiprocessing

if __name__ == "__main__":
    # CRITICAL: Protección para PyInstaller/multiprocessing en Windows
    multiprocessing.freeze_support()

    # resto del código...
```

### 2. En `build_exe.py`
Se mejoraron las opciones de PyInstaller para prevenir problemas:

- Se agregó `--noupx` para desactivar compresión UPX que puede causar problemas
- Se agregó exclusión del módulo `_bootlocale` que puede ser problemático
- Se incluyó explícitamente `multiprocessing` en los hidden imports

## Cómo reconstruir el ejecutable

1. Elimina las carpetas anteriores (opcional pero recomendado):
   ```bash
   python build_exe.py --clean
   ```

2. Genera el nuevo ejecutable:
   ```bash
   python build_exe.py
   ```

3. El ejecutable estará en `dist/AURA.exe`

## Verificación
El ejecutable ahora debería:
- Abrirse una sola vez
- Mostrar el splash screen correctamente
- Cargar los módulos sin problemas
- No causar múltiples instancias ni crasheos

## Notas adicionales
- `multiprocessing.freeze_support()` DEBE estar al inicio del bloque `if __name__ == "__main__"`
- Esta protección solo se ejecuta cuando el archivo se ejecuta directamente (no cuando se importa)
- Es una práctica estándar para todas las aplicaciones PyInstaller en Windows
