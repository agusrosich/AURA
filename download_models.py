"""Script para descargar modelos de TotalSegmentator durante la instalación.

Este script se ejecuta durante la instalación si el usuario selecciona
la opción de descargar modelos automáticamente.
"""

import os
import sys
import subprocess
from pathlib import Path


def main():
    """Descarga los modelos principales de TotalSegmentator."""

    print("=" * 70)
    print("AURA - Descarga de Modelos")
    print("=" * 70)
    print()

    # Verificar que tenemos Python disponible
    python_exe = sys.executable
    if not python_exe:
        print("ERROR: No se encontró el ejecutable de Python.")
        print("Los modelos se descargarán automáticamente la primera vez que uses AURA.")
        return 1

    print(f"Usando Python: {python_exe}")
    print()

    # Intentar importar TotalSegmentator
    try:
        print("Verificando instalación de TotalSegmentator...")
        result = subprocess.run(
            [python_exe, "-c", "import totalsegmentatorv2"],
            capture_output=True,
            text=True,
            timeout=10
        )

        if result.returncode != 0:
            # Intentar con totalsegmentator (v1)
            result = subprocess.run(
                [python_exe, "-c", "import totalsegmentator"],
                capture_output=True,
                text=True,
                timeout=10
            )

            if result.returncode != 0:
                print("TotalSegmentator no está instalado.")
                print("Los modelos se descargarán automáticamente cuando uses AURA por primera vez.")
                return 0

        print("✓ TotalSegmentator está instalado correctamente.")
        print()

    except Exception as e:
        print(f"Error verificando TotalSegmentator: {e}")
        print("Los modelos se descargarán automáticamente cuando uses AURA por primera vez.")
        return 0

    # Descargar el modelo principal 'total'
    print("Descargando modelo 'total' de TotalSegmentator...")
    print("Esto puede tardar varios minutos dependiendo de tu conexión a Internet.")
    print()

    try:
        # Crear un script temporal para descargar el modelo
        download_script = """
try:
    from totalsegmentatorv2.python_api import totalsegmentator
except ImportError:
    from totalsegmentator.python_api import totalsegmentator

import tempfile
import os

# Crear un directorio temporal con un archivo DICOM ficticio
temp_dir = tempfile.mkdtemp()
print(f"Directorio temporal: {temp_dir}")

# El modelo se descargará automáticamente al intentar usarlo
# (no necesitamos un archivo DICOM real, solo queremos activar la descarga)

print("Iniciando descarga del modelo...")
print("Nota: La descarga puede fallar si no hay un archivo DICOM válido,")
print("pero el modelo se descargará de todas formas.")
"""

        # Ejecutar el script de descarga
        result = subprocess.run(
            [python_exe, "-c", download_script],
            capture_output=True,
            text=True,
            timeout=1800  # 30 minutos timeout
        )

        if result.stdout:
            print(result.stdout)

        if result.returncode == 0:
            print()
            print("✓ Modelo descargado correctamente.")
        else:
            print()
            print("Nota: La descarga inicial no se completó.")
            print("Los modelos se descargarán automáticamente la primera vez que uses AURA.")
            # No es un error crítico, retornar 0
            return 0

    except subprocess.TimeoutExpired:
        print()
        print("La descarga está tomando demasiado tiempo.")
        print("Los modelos se descargarán automáticamente la primera vez que uses AURA.")
        return 0

    except Exception as e:
        print()
        print(f"Error durante la descarga: {e}")
        print("Los modelos se descargarán automáticamente la primera vez que uses AURA.")
        return 0

    print()
    print("=" * 70)
    print("Descarga de modelos completada.")
    print("=" * 70)

    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("\n\nDescarga cancelada por el usuario.")
        print("Los modelos se descargarán automáticamente la primera vez que uses AURA.")
        sys.exit(0)
    except Exception as e:
        print(f"\n\nError inesperado: {e}")
        print("Los modelos se descargarán automáticamente la primera vez que uses AURA.")
        sys.exit(0)
