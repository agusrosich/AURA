"""Build a portable bundle of the AURA project.

This helper copies the repository (minus temporary artefacts) into a
fresh staging directory, writes a `requirements.txt` snapshot from the
current environment, and finally creates a ZIP archive that can be
shared as a portable package.

Usage:
    python build_portable.py

Optional flags let you adjust the bundle name, output directory,
whether to keep the staging folder, extensions to exclude, etc.
Run `python build_portable.py --help` for details.
"""

from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from typing import Iterable, Sequence
import zipfile


DEFAULT_BUNDLE_NAME = "AURA_portable"
DEFAULT_OUTPUT_DIR = "dist"

# Directory names to exclude anywhere in the tree.
DEFAULT_EXCLUDE_DIRS: set[str] = {
    ".git",
    ".github",
    ".idea",
    ".mypy_cache",
    ".pytest_cache",
    "__pycache__",
    "build",
    "dist",
    "logs",
    ".venv",
}

# Individual files (basenames) that should never be copied.
DEFAULT_EXCLUDE_FILES: set[str] = {
    ".DS_Store",
    "Thumbs.db",
    "build_portable.py",
    "pyproject.toml",
}


def parse_args(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Create the portable AURA bundle.")
    parser.add_argument(
        "--bundle-name",
        default=DEFAULT_BUNDLE_NAME,
        help="Nombre base del directorio/zip generado.",
    )
    parser.add_argument(
        "--output-dir",
        default=DEFAULT_OUTPUT_DIR,
        help="Carpeta donde se colocará el artefacto (se creará si no existe).",
    )
    parser.add_argument(
        "--keep-staging",
        action="store_true",
        help="No eliminar la carpeta temporal tras crear el ZIP.",
    )
    parser.add_argument(
        "--extra-exclude-dir",
        action="append",
        default=[],
        help="Nombres de directorios adicionales a excluir (puede repetirse).",
    )
    parser.add_argument(
        "--extra-exclude-file",
        action="append",
        default=[],
        help="Nombres de archivos adicionales a excluir (puede repetirse).",
    )
    parser.add_argument(
        "--include-builder",
        action="store_true",
        help="Incluir build_portable.py dentro del paquete.",
    )
    return parser.parse_args(argv)


def main(argv: Sequence[str]) -> int:
    args = parse_args(argv)
    project_root = Path(__file__).resolve().parent
    output_dir = (project_root / args.output_dir).resolve()
    output_dir.mkdir(parents=True, exist_ok=True)

    exclude_dirs = set(DEFAULT_EXCLUDE_DIRS)
    exclude_dirs.update(args.extra_exclude_dir)

    exclude_files = set(DEFAULT_EXCLUDE_FILES)
    exclude_files.update(args.extra_exclude_file)
    if args.include_builder:
        exclude_files.discard("build_portable.py")

    staging_dir = output_dir / args.bundle_name
    if staging_dir.exists():
        shutil.rmtree(staging_dir)
    staging_dir.mkdir(parents=True, exist_ok=True)

    print(f"[portable] Copiando archivos hacia {staging_dir}")
    copy_project(project_root, staging_dir, exclude_dirs, exclude_files)

    print("[portable] Generando requirements.txt")
    write_requirements(staging_dir)

    print("[portable] Añadiendo README_portable.txt")
    write_portable_readme(staging_dir)

    zip_path = output_dir / f"{args.bundle_name}.zip"
    print(f"[portable] Empaquetando ZIP en {zip_path}")
    create_zip(staging_dir, zip_path)

    if not args.keep_staging:
        print("[portable] Eliminando carpeta temporal")
        shutil.rmtree(staging_dir)
    else:
        print(f"[portable] Carpeta temporal conservada en {staging_dir}")

    print("[portable] ¡Paquete listo!")
    return 0


def copy_project(
    src_root: Path,
    dest_root: Path,
    exclude_dirs: Iterable[str],
    exclude_files: Iterable[str],
) -> None:
    exclude_dirs_set = set(exclude_dirs)
    exclude_files_set = set(exclude_files)

    for path in src_root.rglob("*"):
        relative = path.relative_to(src_root)
        parts = set(relative.parts)
        if parts & exclude_dirs_set:
            if path.is_dir():
                # Skip walking into excluded directories.
                continue
            # Files inside excluded dirs automatically skipped.
            if any(part in exclude_dirs_set for part in relative.parts):
                continue

        if path.is_file() and path.name in exclude_files_set:
            continue

        if path.is_dir():
            (dest_root / relative).mkdir(parents=True, exist_ok=True)
        else:
            dest_path = dest_root / relative
            dest_path.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, dest_path)


def write_requirements(dest_root: Path) -> None:
    """Capture the current environment's dependencies."""
    requirements_path = dest_root / "requirements.txt"
    try:
        output = subprocess.check_output(
            [sys.executable, "-m", "pip", "freeze"],
            text=True,
        )
    except subprocess.CalledProcessError as exc:
        requirements_path.write_text(
            "# No se pudieron capturar dependencias automáticamente.\n"
            f"# pip devolvió código {exc.returncode}.\n",
            encoding="utf-8",
        )
        return

    requirements_path.write_text(output, encoding="utf-8")


def write_portable_readme(dest_root: Path) -> None:
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M")
    content = (
        "AURA Portable\n"
        "==============\n\n"
        f"Generado: {timestamp}\n\n"
        "Instrucciones rápidas:\n"
        "1. Asegúrate de tener Python 3.10+ instalado en el equipo destino.\n"
        "2. (Opcional) Crea y activa un entorno virtual.\n"
        "3. Instala dependencias: `pip install -r requirements.txt`.\n"
        "4. Ejecuta la aplicación: `python \"AURA VER 1.0.py\"`.\n\n"
        "Notas:\n"
        "- Este paquete contiene los modelos y scripts necesarios.\n"
        "- Si se dispone de GPU NVIDIA, ejecuta la app y permitirá instalar\n"
        "  automáticamente el wheel de PyTorch compatible.\n"
        "- Para empaques posteriores, vuelve a ejecutar build_portable.py.\n"
    )
    (dest_root / "README_portable.txt").write_text(content, encoding="utf-8")


def create_zip(source_dir: Path, zip_path: Path) -> None:
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
        for file in source_dir.rglob("*"):
            if file.is_file():
                zf.write(file, file.relative_to(source_dir))


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))

