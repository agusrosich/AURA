"""
Utilities to detect GPU hardware and ensure CUDA dependencies are ready.

The application relies on PyTorch for GPU acceleration.  On Windows
systems, PyTorch wheels installed from PyPI are typically CPU-only.
This module detects NVIDIA GPUs and, when found, attempts to install a
CUDA-enabled PyTorch build so the rest of the application can use it.
"""

from __future__ import annotations

import importlib
import importlib.util
import os
import subprocess
import sys
from typing import Callable, Iterable, List, Optional, Sequence, Tuple

# Preferred CUDA wheels in order of priority. Users can override the index
# via the AURA_TORCH_CUDA_INDEX environment variable if they need a custom build.
_CUDA_INDEXES: Sequence[Tuple[str, str]] = (
    ("cu121", "https://download.pytorch.org/whl/cu121"),
    ("cu118", "https://download.pytorch.org/whl/cu118"),
)


def _default_log(message: str) -> None:
    """Fallback logger when the main application logger is not yet ready."""
    print(f"[GPU setup] {message}")


def prepare_gpu_environment(log: Optional[Callable[[str], None]] = None) -> None:
    """Detect NVIDIA GPUs and ensure PyTorch has CUDA support.

    Parameters
    ----------
    log:
        Optional logging callback.  When omitted, messages are printed to stdout.
    """
    logger = log or _default_log

    gpu_names, diagnostics = _detect_gpu_names()
    if diagnostics:
        for line in diagnostics:
            logger(line)

    if not gpu_names:
        logger("No se detectaron GPUs. Se continuará en modo CPU.")
        return

    nvidia_gpus = [name for name in gpu_names if "nvidia" in name.lower()]
    if not nvidia_gpus:
        logger(
            "Se detectaron GPUs pero no NVIDIA: "
            + ", ".join(sorted(set(gpu_names)))
            + ". La aceleración CUDA no estará disponible."
        )
        return

    logger("GPU NVIDIA detectada: " + ", ".join(sorted(set(nvidia_gpus))))
    _ensure_torch_cuda(logger)


def _detect_gpu_names(timeout: float = 5.0) -> Tuple[List[str], List[str]]:
    """Return GPU adapter names and diagnostics collected during probing."""
    names: List[str] = []
    diagnostics: List[str] = []

    def _append_from_output(raw: str) -> None:
        for line in raw.splitlines():
            stripped = line.strip()
            if stripped and stripped.lower() not in {"name"}:
                names.append(stripped)

    probes: Iterable[Tuple[Sequence[str], str]] = (
        (("nvidia-smi", "--query-gpu=name", "--format=csv,noheader"), "nvidia-smi"),
        (
            (
                "powershell",
                "-NoProfile",
                "-Command",
                "Get-CimInstance Win32_VideoController | Select-Object -ExpandProperty Name",
            ),
            "powershell",
        ),
        (("wmic", "path", "win32_VideoController", "get", "Name"), "wmic"),
    )

    for command, label in probes:
        rc, stdout, stderr = _run_command(command, timeout=timeout)
        if rc == 0 and stdout:
            _append_from_output(stdout)
            diagnostics.append(f"{label}: detectó {len(stdout.splitlines())} entradas.")
        else:
            msg = f"{label}: no disponible (código {rc})."
            if stderr.strip():
                msg += f" Detalle: {stderr.strip()}"
            diagnostics.append(msg)

        if names:
            break

    # Remove duplicates while preserving order.
    seen = set()
    unique_names = []
    for item in names:
        key = item.lower()
        if key not in seen:
            seen.add(key)
            unique_names.append(item)

    return unique_names, diagnostics


def _run_command(command: Sequence[str], timeout: float) -> Tuple[int, str, str]:
    """Execute a command and capture its output."""
    try:
        completed = subprocess.run(
            command,
            capture_output=True,
            text=True,
            timeout=timeout,
            check=False,
        )
        return completed.returncode, completed.stdout.strip(), completed.stderr.strip()
    except FileNotFoundError:
        return 127, "", ""
    except Exception as exc:  # pragma: no cover - defensive
        return 1, "", str(exc)


def _ensure_torch_cuda(log: Callable[[str], None]) -> None:
    """Install or upgrade PyTorch so that CUDA support is available."""
    torch_spec = importlib.util.find_spec("torch")
    if torch_spec is None:
        log("PyTorch no está instalado. Intentando instalar build con soporte CUDA...")
        if _install_torch_cuda(log):
            _reload_torch(log)
        else:
            log("Instalación automática falló. Continúa con modo CPU.")
        return

    torch = importlib.import_module("torch")
    cuda_version = getattr(torch.version, "cuda", None)

    try:
        cuda_available = bool(torch.cuda.is_available())
    except Exception as exc:  # pragma: no cover - defensive
        log(f"No fue posible consultar torch.cuda.is_available(): {exc}")
        cuda_available = False

    if cuda_version and cuda_available:
        log(f"PyTorch ya dispone de soporte CUDA ({cuda_version}).")
        return

    if cuda_version and not cuda_available:
        log(
            "PyTorch posee un build con CUDA pero no se pudo activar. "
            "Revisa la instalación de drivers."
        )
        return

    log("La instalación actual de PyTorch es sólo CPU. Intentando instalar build CUDA...")
    if _install_torch_cuda(log):
        module = _reload_torch(log)
        if module is None:
            log("No se pudo recargar PyTorch tras la instalación.")
            return

        cuda_version = getattr(module.version, "cuda", None)
        try:
            cuda_available = bool(module.cuda.is_available())
        except Exception as exc:  # pragma: no cover - defensive
            log(f"No fue posible verificar CUDA tras la instalación: {exc}")
            cuda_available = False

        if cuda_version and cuda_available:
            log(f"PyTorch ahora tiene soporte CUDA ({cuda_version}).")
        else:
            log("La instalación CUDA se completó pero no se pudo habilitar. Verifica manualmente.")
    else:
        log("No se pudo instalar el build CUDA automáticamente.")


def _install_torch_cuda(log: Callable[[str], None]) -> bool:
    """Try to install a CUDA-enabled PyTorch build using pip."""
    indexes: List[Tuple[str, str]] = []
    custom_index = os.environ.get("AURA_TORCH_CUDA_INDEX")
    if custom_index:
        indexes.append(("custom", custom_index))
    indexes.extend(_CUDA_INDEXES)

    attempted = set()
    for label, index_url in indexes:
        if index_url in attempted:
            continue
        attempted.add(index_url)
        log(f"Instalando PyTorch con CUDA ({label}) desde {index_url} ...")
        command = [
            sys.executable,
            "-m",
            "pip",
            "install",
            "--upgrade",
            "torch",
            "--index-url",
            index_url,
        ]
        try:
            subprocess.check_call(command)
            log("Instalación de PyTorch CUDA finalizada.")
            return True
        except subprocess.CalledProcessError as exc:
            log(f"pip devolvió código {exc.returncode} para la instalación ({label}).")
        except Exception as exc:  # pragma: no cover - defensive
            log(f"Error inesperado instalando PyTorch CUDA ({label}): {exc}")

    return False


def _reload_torch(log: Callable[[str], None]) -> Optional["module"]:
    """Reload the torch module after installing a new wheel."""
    try:
        if "torch" in sys.modules:
            del sys.modules["torch"]
        importlib.invalidate_caches()
        module = importlib.import_module("torch")
        return module
    except Exception as exc:  # pragma: no cover - defensive
        log(f"Error recargando PyTorch tras la instalación: {exc}")
        return None

