"""Script para crear el instalador completo de AURA.

Este script automatiza todo el proceso:
1. Compila AURA usando PyInstaller (crea el .exe)
2. Crea el instalador usando Inno Setup
3. Empaqueta todo en un archivo ZIP listo para distribuir

Uso:
    python build_installer.py

Requisitos:
    - PyInstaller (se instala automáticamente)
    - Inno Setup (debe estar instalado en el sistema)
    - Python 3.8+
"""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
import zipfile
from pathlib import Path
from typing import Optional


def print_header(message: str) -> None:
    """Imprime un encabezado formateado."""
    print()
    print("=" * 70)
    print(message)
    print("=" * 70)
    print()


def check_inno_setup() -> Optional[Path]:
    """Busca la instalación de Inno Setup en el sistema.

    Returns:
        Path al ejecutable ISCC.exe si se encuentra, None en caso contrario.
    """
    common_paths = [
        Path(r"C:\Program Files (x86)\Inno Setup 6\ISCC.exe"),
        Path(r"C:\Program Files\Inno Setup 6\ISCC.exe"),
        Path(r"C:\Program Files (x86)\Inno Setup 5\ISCC.exe"),
        Path(r"C:\Program Files\Inno Setup 5\ISCC.exe"),
    ]

    for path in common_paths:
        if path.exists():
            return path

    # Buscar en PATH
    try:
        result = subprocess.run(
            ["where", "ISCC.exe"],
            capture_output=True,
            text=True,
            check=False
        )
        if result.returncode == 0:
            return Path(result.stdout.strip().split('\n')[0])
    except Exception:
        pass

    return None


def build_executable(project_root: Path, clean: bool = True) -> bool:
    """Compila AURA usando PyInstaller.

    Args:
        project_root: Directorio raíz del proyecto
        clean: Si es True, limpia las carpetas build/dist antes de compilar

    Returns:
        True si la compilación fue exitosa, False en caso contrario
    """
    print_header("PASO 1: Compilando AURA con PyInstaller")

    build_script = project_root / "build_exe.py"
    if not build_script.exists():
        print(f"ERROR: No se encontró {build_script}")
        return False

    cmd = [sys.executable, str(build_script)]
    if clean:
        cmd.append("--clean")

    print(f"Ejecutando: {' '.join(cmd)}")
    print()

    try:
        result = subprocess.run(cmd, cwd=project_root, check=True)
        print()
        print("✓ Ejecutable compilado correctamente")
        return True
    except subprocess.CalledProcessError as e:
        print()
        print(f"✗ Error durante la compilación: {e}")
        return False


def build_installer(project_root: Path, iscc_path: Path) -> Optional[Path]:
    """Crea el instalador usando Inno Setup.

    Args:
        project_root: Directorio raíz del proyecto
        iscc_path: Path al ejecutable ISCC.exe

    Returns:
        Path al instalador generado si fue exitoso, None en caso contrario
    """
    print_header("PASO 2: Creando instalador con Inno Setup")

    iss_script = project_root / "aura_installer.iss"
    if not iss_script.exists():
        print(f"ERROR: No se encontró {iss_script}")
        return None

    # Verificar que existe el ejecutable
    exe_path = project_root / "dist" / "AURA.exe"
    if not exe_path.exists():
        print(f"ERROR: No se encontró el ejecutable en {exe_path}")
        print("Asegúrate de que la compilación con PyInstaller fue exitosa.")
        return None

    # Crear directorio de salida si no existe
    output_dir = project_root / "installer_output"
    output_dir.mkdir(exist_ok=True)

    cmd = [str(iscc_path), str(iss_script)]

    print(f"Ejecutando: {' '.join(cmd)}")
    print()

    try:
        result = subprocess.run(
            cmd,
            cwd=project_root,
            capture_output=True,
            text=True,
            check=True
        )

        # Mostrar salida
        if result.stdout:
            print(result.stdout)

        # Buscar el instalador generado
        installers = list(output_dir.glob("AURA_Setup_*.exe"))
        if installers:
            installer_path = installers[0]
            print()
            print(f"✓ Instalador creado: {installer_path.name}")
            return installer_path
        else:
            print()
            print("✗ No se encontró el instalador generado")
            return None

    except subprocess.CalledProcessError as e:
        print()
        print(f"✗ Error durante la creación del instalador: {e}")
        if e.stderr:
            print("Detalles del error:")
            print(e.stderr)
        return None


def create_distribution_zip(
    project_root: Path,
    installer_path: Path,
    output_name: str = "AURA_Distribution.zip"
) -> Optional[Path]:
    """Crea un archivo ZIP con el instalador y archivos auxiliares.

    Args:
        project_root: Directorio raíz del proyecto
        installer_path: Path al instalador .exe
        output_name: Nombre del archivo ZIP de salida

    Returns:
        Path al ZIP creado si fue exitoso, None en caso contrario
    """
    print_header("PASO 3: Empaquetando distribución en ZIP")

    output_path = project_root / output_name

    # Eliminar ZIP anterior si existe
    if output_path.exists():
        print(f"Eliminando ZIP anterior: {output_path.name}")
        output_path.unlink()

    try:
        with zipfile.ZipFile(output_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
            # Agregar el instalador
            print(f"Agregando: {installer_path.name}")
            zipf.write(installer_path, installer_path.name)

            # Agregar README si existe
            readme_files = ["README.md", "README.txt", "LEEME.txt"]
            for readme in readme_files:
                readme_path = project_root / readme
                if readme_path.exists():
                    print(f"Agregando: {readme}")
                    zipf.write(readme_path, readme)
                    break

            # Agregar instrucciones de instalación
            install_instructions = """AURA - Instrucciones de Instalación
=====================================

1. Extrae todos los archivos de este ZIP a una carpeta temporal.

2. Ejecuta el instalador: AURA_Setup_1.0.exe

3. Sigue las instrucciones del asistente de instalación:
   - Elige el directorio de instalación
   - Selecciona si deseas crear un acceso directo en el escritorio
   - Opcionalmente, permite que el instalador descargue los modelos de IA
     (esto puede tardar varios minutos)

4. Una vez instalado, AURA estará disponible en el menú de inicio
   y (si lo seleccionaste) en tu escritorio.

5. La primera vez que uses AURA, los modelos de IA se descargarán
   automáticamente si no se descargaron durante la instalación.

Requisitos del Sistema
----------------------
- Windows 10/11 (64-bit)
- 8 GB RAM mínimo (16 GB recomendado)
- 10 GB de espacio libre en disco
- Conexión a Internet (para descarga de modelos)

GPU (Opcional)
--------------
AURA puede usar GPU NVIDIA con CUDA para acelerar el procesamiento.
Si tienes una GPU compatible, AURA la detectará automáticamente.

Soporte
-------
Para reportar problemas o solicitar ayuda, visita:
[Agregar URL de soporte aquí]

¡Gracias por usar AURA!
"""
            zipf.writestr("INSTRUCCIONES.txt", install_instructions)
            print("Agregando: INSTRUCCIONES.txt")

            # Agregar licencia si existe
            license_files = ["LICENSE", "LICENSE.txt", "LICENSE.md"]
            for license_file in license_files:
                license_path = project_root / license_file
                if license_path.exists():
                    print(f"Agregando: {license_file}")
                    zipf.write(license_path, license_file)
                    break

        print()
        print(f"✓ ZIP creado exitosamente: {output_path.name}")
        print(f"  Tamaño: {output_path.stat().st_size / 1024 / 1024:.2f} MB")
        return output_path

    except Exception as e:
        print()
        print(f"✗ Error creando el ZIP: {e}")
        return None


def cleanup(project_root: Path, keep_installer: bool = True) -> None:
    """Limpia archivos temporales generados durante el build.

    Args:
        project_root: Directorio raíz del proyecto
        keep_installer: Si es True, mantiene la carpeta installer_output
    """
    print_header("Limpiando archivos temporales")

    temp_dirs = ["build", "__pycache__"]
    if not keep_installer:
        temp_dirs.append("installer_output")

    for dirname in temp_dirs:
        dir_path = project_root / dirname
        if dir_path.exists():
            print(f"Eliminando: {dirname}/")
            shutil.rmtree(dir_path)

    print()
    print("✓ Limpieza completada")


def main() -> int:
    """Función principal."""
    parser = argparse.ArgumentParser(
        description="Construir instalador completo de AURA"
    )
    parser.add_argument(
        "--no-clean",
        action="store_true",
        help="No limpiar build/dist antes de compilar"
    )
    parser.add_argument(
        "--keep-temp",
        action="store_true",
        help="Mantener archivos temporales después del build"
    )
    parser.add_argument(
        "--skip-exe",
        action="store_true",
        help="Saltar compilación del .exe (usar .exe existente)"
    )
    parser.add_argument(
        "--output",
        default="AURA_Distribution.zip",
        help="Nombre del archivo ZIP de salida"
    )

    args = parser.parse_args()

    project_root = Path(__file__).resolve().parent

    print("=" * 70)
    print("AURA - Constructor de Instalador")
    print("=" * 70)
    print(f"Directorio del proyecto: {project_root}")

    # Verificar Inno Setup
    print()
    print("Verificando Inno Setup...")
    iscc_path = check_inno_setup()
    if iscc_path is None:
        print()
        print("ERROR: Inno Setup no está instalado.")
        print()
        print("Por favor, descarga e instala Inno Setup desde:")
        print("https://jrsoftware.org/isdl.php")
        print()
        print("Después de instalar, vuelve a ejecutar este script.")
        return 1

    print(f"✓ Inno Setup encontrado: {iscc_path}")

    # PASO 1: Compilar ejecutable
    if not args.skip_exe:
        if not build_executable(project_root, clean=not args.no_clean):
            return 1
    else:
        print_header("PASO 1: Saltando compilación del ejecutable")
        # Verificar que existe
        exe_path = project_root / "dist" / "AURA.exe"
        if not exe_path.exists():
            print(f"ERROR: No se encontró {exe_path}")
            print("Ejecuta sin --skip-exe para compilar el ejecutable.")
            return 1
        print(f"✓ Usando ejecutable existente: {exe_path}")

    # PASO 2: Crear instalador
    installer_path = build_installer(project_root, iscc_path)
    if installer_path is None:
        return 1

    # PASO 3: Crear ZIP de distribución
    zip_path = create_distribution_zip(
        project_root,
        installer_path,
        args.output
    )
    if zip_path is None:
        return 1

    # Limpieza opcional
    if not args.keep_temp:
        cleanup(project_root, keep_installer=True)

    # Resumen final
    print_header("✓ BUILD COMPLETADO EXITOSAMENTE")
    print(f"Instalador: {installer_path}")
    print(f"ZIP distribución: {zip_path}")
    print()
    print("El archivo ZIP contiene:")
    print("  - Instalador de AURA (AURA_Setup_1.0.exe)")
    print("  - Instrucciones de instalación")
    print("  - Archivos README/LICENSE (si existen)")
    print()
    print("Este ZIP está listo para distribuir a los usuarios.")
    print()

    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("\n\nProceso cancelado por el usuario.")
        sys.exit(1)
    except Exception as e:
        print(f"\n\nError inesperado: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
