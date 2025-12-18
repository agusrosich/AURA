"""Build a standalone Windows executable for AURA using PyInstaller.

This helper wraps ``PyInstaller`` so the user only needs to run:

    python build_exe.py

The script:
  * Ensures PyInstaller is available (installs it if missing).
  * Collects data folders (e.g. ``models``) and asset files referenced
    via ``resource_path``.
  * Invokes PyInstaller with sensible defaults (one-file, GUI mode).
  * Leaves the executable under ``dist/`` along with a staging ``build/``.

Run ``python build_exe.py --help`` to see available flags.
"""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Iterable, List, Sequence, Tuple


DEFAULT_APP_NAME = "AURA"
DEFAULT_ENTRYPOINT = "AURA VER 1.0.py"

# Paths we try to bundle (if they exist) so resource_path() works inside the EXE.
DEFAULT_DATA_DIRS = [
    "models",
    "wholeBody_ct_segmentation",
]

DEFAULT_DATA_FILES = [
    "ico.png",
    "splashscreen.png",
]


def parse_args(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Empaquetar AURA en un exe con PyInstaller.")
    parser.add_argument(
        "--entry-point",
        default=DEFAULT_ENTRYPOINT,
        help="Script principal a empaquetar (por defecto: 'AURA VER 1.0.py').",
    )
    parser.add_argument(
        "--name",
        default=DEFAULT_APP_NAME,
        help="Nombre base del ejecutable generado.",
    )
    parser.add_argument(
        "--no-onefile",
        action="store_true",
        help="Generar una carpeta en vez de un único ejecutable.",
    )
    parser.add_argument(
        "--console",
        action="store_true",
        help="Mantener la consola visible (útil para depurar).",
    )
    parser.add_argument(
        "--extra-data",
        action="append",
        default=[],
        help="Rutas adicionales a incluir como datos (formato origen=destino).",
    )
    parser.add_argument(
        "--clean",
        action="store_true",
        help="Eliminar carpetas build/dist previas antes de ejecutar PyInstaller.",
    )
    return parser.parse_args(argv)


def ensure_pyinstaller() -> None:
    try:
        import PyInstaller  # type: ignore # noqa: F401
    except ImportError:
        print("[build_exe] PyInstaller no está instalado. Instalando...")
        subprocess.check_call([sys.executable, "-m", "pip", "install", "pyinstaller"])


def collect_data_arguments(project_root: Path) -> List[str]:
    args: List[str] = []

    def add_data(src: Path, dest: str) -> None:
        target = f"{src}{os.pathsep}{dest}"
        args.extend(["--add-data", target])

    for relative in DEFAULT_DATA_DIRS:
        path = (project_root / relative).resolve()
        if path.exists() and path.is_dir():
            add_data(path, relative)
        else:
            print(f"[build_exe] Aviso: carpeta '{relative}' no encontrada, se omitirá.")

    for filename in DEFAULT_DATA_FILES:
        path = (project_root / filename).resolve()
        if path.exists():
            add_data(path, filename)
        else:
            print(f"[build_exe] Aviso: archivo '{filename}' no encontrado, se omitirá.")

    return args


def parse_extra_data(raw_values: Iterable[str], project_root: Path) -> List[str]:
    args: List[str] = []
    for raw in raw_values:
        if "=" in raw:
            src_str, dest = raw.split("=", 1)
        else:
            src_str, dest = raw, Path(raw).name
        src_path = (project_root / src_str).resolve()
        if not src_path.exists():
            print(f"[build_exe] Aviso: ruta extra '{src_str}' no existe. Omitiendo.")
            continue
        args.extend(["--add-data", f"{src_path}{os.pathsep}{dest}"])
    return args


def build_executable(args: argparse.Namespace) -> None:
    ensure_pyinstaller()
    import PyInstaller.__main__  # type: ignore

    project_root = Path(__file__).resolve().parent
    entry_point = (project_root / args.entry_point).resolve()
    if not entry_point.exists():
        raise SystemExit(f"No se encontró el entry point: {entry_point}")

    if args.clean:
        for folder in ("build", "dist", "__pycache__"):
            path = project_root / folder
            if path.exists():
                print(f"[build_exe] Eliminando {path}")
                shutil.rmtree(path)

    pyinstaller_args: List[str] = [
        str(entry_point),
        "--name",
        args.name,
        "--noconfirm",
    ]

    if not args.console:
        pyinstaller_args.append("--noconsole")

    if not args.no_onefile:
        pyinstaller_args.append("--onefile")

    pyinstaller_args.extend(["--clean"])

    # IMPORTANTE: Opciones para prevenir problemas de multiprocessing en Windows
    # Estas opciones evitan que el ejecutable se abra múltiples veces
    pyinstaller_args.extend([
        "--noupx",  # Desactiva UPX compression que puede causar problemas
        "--exclude-module", "_bootlocale",  # Excluye módulos problemáticos
    ])

    pyinstaller_args.extend(collect_data_arguments(project_root))
    pyinstaller_args.extend(parse_extra_data(args.extra_data, project_root))

    # Hidden imports that PyInstaller sometimes misses.
    hidden_imports = [
        "rt_utils",
        "monai",
        "monai.transforms",
        "monai.data",
        "monai.inferers",
        "multiprocessing",  # Asegura que multiprocessing esté incluido
        "first_run_setup",  # Módulo de configuración inicial
    ]
    for module in hidden_imports:
        pyinstaller_args.extend(["--hidden-import", module])

    icon_path = project_root / "ico.ico"
    if icon_path.exists():
        pyinstaller_args.extend(["--icon", str(icon_path)])

    print("[build_exe] Ejecutando PyInstaller con argumentos:")
    for item in pyinstaller_args:
        print("   ", item)

    PyInstaller.__main__.run(pyinstaller_args)
    print("[build_exe] Ejecutable generado en carpeta dist/")


def main(argv: Sequence[str]) -> int:
    args = parse_args(argv)
    build_executable(args)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))

