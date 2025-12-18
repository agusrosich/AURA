"""
Módulo de configuración inicial para AURA.

Este módulo maneja la verificación y descarga de modelos de TotalSegmentator
en el primer arranque de la aplicación cuando se ejecuta como EXE.
"""

import os
import sys
import tkinter as tk
from tkinter import ttk, messagebox
from pathlib import Path
import threading
import subprocess


class FirstRunSetupWindow:
    """Ventana de configuración inicial para descargar modelos."""

    def __init__(self, parent=None):
        """Inicializa la ventana de configuración inicial.

        Args:
            parent: Ventana padre (opcional)
        """
        self.parent = parent

        # Siempre crear como Toplevel si hay parent, sino crear Tk
        if parent:
            self.window = tk.Toplevel(parent)
        else:
            # Si no hay parent, crear una nueva ventana raíz
            self.window = tk.Tk()

        self.window.title("AURA - Configuración Inicial")
        self.window.geometry("600x450")
        self.window.resizable(False, False)

        # Centrar ventana (con manejo de errores)
        try:
            self.window.update_idletasks()
            x = (self.window.winfo_screenwidth() // 2) - (600 // 2)
            y = (self.window.winfo_screenheight() // 2) - (450 // 2)
            self.window.geometry(f"600x450+{x}+{y}")
        except Exception:
            pass  # Si falla el centrado, no es crítico

        # Hacer la ventana modal si hay parent
        if parent:
            try:
                self.window.transient(parent)
                self.window.grab_set()
            except Exception:
                pass  # Si falla, continuar sin modal

        self.setup_completed = False
        self.download_cancelled = False

        self._create_widgets()

    def _create_widgets(self):
        """Crea los widgets de la interfaz."""
        # Frame principal
        main_frame = ttk.Frame(self.window, padding="20")
        main_frame.pack(fill=tk.BOTH, expand=True)

        # Título
        title_label = ttk.Label(
            main_frame,
            text="🚀 Bienvenido a AURA",
            font=("Segoe UI", 16, "bold")
        )
        title_label.pack(pady=(0, 10))

        # Descripción
        desc_text = (
            "Esta es la primera vez que ejecutas AURA.\n\n"
            "Para funcionar correctamente, AURA necesita descargar los modelos de "
            "inteligencia artificial de TotalSegmentator.\n\n"
            "La descarga tiene aproximadamente 2-5 GB y solo se realiza una vez.\n"
            "Los modelos se guardarán en tu carpeta de usuario y estarán disponibles "
            "para futuros usos."
        )
        desc_label = ttk.Label(
            main_frame,
            text=desc_text,
            wraplength=550,
            justify=tk.LEFT
        )
        desc_label.pack(pady=(0, 20))

        # Frame de información
        info_frame = ttk.LabelFrame(main_frame, text="Información", padding="10")
        info_frame.pack(fill=tk.X, pady=(0, 20))

        info_items = [
            ("📦 Tamaño de descarga:", "2-5 GB"),
            ("⏱️ Tiempo estimado:", "5-15 minutos (según conexión)"),
            ("💾 Ubicación:", str(Path.home() / ".totalsegmentator")),
        ]

        for i, (label, value) in enumerate(info_items):
            label_widget = ttk.Label(info_frame, text=label, font=("Segoe UI", 9, "bold"))
            label_widget.grid(row=i, column=0, sticky=tk.W, pady=2)
            value_widget = ttk.Label(info_frame, text=value)
            value_widget.grid(row=i, column=1, sticky=tk.W, padx=(10, 0), pady=2)

        # Barra de progreso
        self.progress_frame = ttk.Frame(main_frame)
        self.progress_frame.pack(fill=tk.X, pady=(0, 10))

        self.progress_label = ttk.Label(
            self.progress_frame,
            text="Esperando confirmación...",
            font=("Segoe UI", 9)
        )
        self.progress_label.pack(anchor=tk.W, pady=(0, 5))

        self.progress_bar = ttk.Progressbar(
            self.progress_frame,
            mode='indeterminate',
            length=560
        )
        self.progress_bar.pack()

        # Log de salida
        self.log_text = tk.Text(
            main_frame,
            height=6,
            wrap=tk.WORD,
            state=tk.DISABLED,
            font=("Consolas", 8)
        )
        self.log_text.pack(fill=tk.BOTH, expand=True, pady=(10, 10))

        # Scrollbar para el log
        scrollbar = ttk.Scrollbar(self.log_text)
        scrollbar.pack(side=tk.RIGHT, fill=tk.Y)
        self.log_text.config(yscrollcommand=scrollbar.set)
        scrollbar.config(command=self.log_text.yview)

        # Botones
        button_frame = ttk.Frame(main_frame)
        button_frame.pack(fill=tk.X)

        self.download_btn = ttk.Button(
            button_frame,
            text="Descargar Modelos",
            command=self._start_download
        )
        self.download_btn.pack(side=tk.LEFT, padx=(0, 10))

        self.skip_btn = ttk.Button(
            button_frame,
            text="Omitir (Descargar después)",
            command=self._skip_download
        )
        self.skip_btn.pack(side=tk.LEFT)

        self.close_btn = ttk.Button(
            button_frame,
            text="Cerrar",
            command=self._close_window,
            state=tk.DISABLED
        )
        self.close_btn.pack(side=tk.RIGHT)

    def _log(self, message):
        """Agrega un mensaje al log."""
        self.log_text.config(state=tk.NORMAL)
        self.log_text.insert(tk.END, message + "\n")
        self.log_text.see(tk.END)
        self.log_text.config(state=tk.DISABLED)
        self.window.update()

    def _start_download(self):
        """Inicia la descarga de modelos."""
        self.download_btn.config(state=tk.DISABLED)
        self.skip_btn.config(state=tk.DISABLED)
        self.progress_label.config(text="Descargando modelos...")
        self.progress_bar.start(10)

        # Ejecutar descarga en thread separado
        thread = threading.Thread(target=self._download_models, daemon=True)
        thread.start()

    def _download_models(self):
        """Descarga los modelos de TotalSegmentator."""
        try:
            self._log("🔍 Verificando instalación de TotalSegmentator...")

            # Verificar que TotalSegmentator esté instalado
            try:
                from totalsegmentatorv2.python_api import totalsegmentator
                self._log("✓ TotalSegmentator V2 encontrado")
            except ImportError:
                try:
                    from totalsegmentator.python_api import totalsegmentator
                    self._log("✓ TotalSegmentator V1 encontrado")
                except ImportError:
                    self._log("❌ ERROR: TotalSegmentator no está instalado.")
                    self._log("   Por favor, instala el paquete 'totalsegmentatorv2'")
                    self.window.after(0, self._download_failed)
                    return

            self._log("\n📥 Iniciando descarga de modelos...")
            self._log("   Esto puede tardar varios minutos dependiendo de tu conexión.")
            self._log("   Por favor, ten paciencia...\n")

            # Usar el comando CLI de TotalSegmentator para descargar modelos
            # El task 'total' es el modelo principal que funciona para la mayoría de casos
            model_dir = Path.home() / ".totalsegmentator" / "nnunet" / "results"

            if model_dir.exists() and any(model_dir.iterdir()):
                self._log("✓ Los modelos ya están descargados.")
                self._log(f"   Ubicación: {model_dir}")
                self.window.after(0, self._download_complete)
                return

            # Intentar descargar usando el script de descarga
            self._log("   Descargando modelo 'total'...")

            try:
                # Usar subprocess para ejecutar el comando de descarga
                python_exe = sys.executable

                # Script para forzar la descarga del modelo
                download_script = """
try:
    from totalsegmentatorv2.bin.totalseg_download_weights import download_pretrained_weights
except ImportError:
    try:
        from totalsegmentator.bin.totalseg_download_weights import download_pretrained_weights
    except ImportError:
        from totalsegmentator.download_pretrained_weights import download_pretrained_weights

# Descargar el modelo 'total' que es el más común
print("Descargando modelo 'total'...")
download_pretrained_weights(task_id=291)
print("¡Descarga completada!")
"""

                result = subprocess.run(
                    [python_exe, "-c", download_script],
                    capture_output=True,
                    text=True,
                    timeout=1800  # 30 minutos de timeout
                )

                if result.stdout:
                    for line in result.stdout.split('\n'):
                        if line.strip():
                            self._log(f"   {line}")

                if result.stderr:
                    for line in result.stderr.split('\n'):
                        if line.strip() and 'warning' not in line.lower():
                            self._log(f"   ⚠ {line}")

                if result.returncode == 0:
                    self._log("\n✓ ¡Modelos descargados exitosamente!")
                    self._log(f"   Ubicación: {model_dir}")
                    self.window.after(0, self._download_complete)
                else:
                    self._log("\n❌ Error durante la descarga.")
                    self._log("   Los modelos se descargarán automáticamente la primera")
                    self._log("   vez que uses la función de segmentación.")
                    self.window.after(0, self._download_failed)

            except subprocess.TimeoutExpired:
                self._log("\n⏱️ La descarga está tardando mucho tiempo.")
                self._log("   Los modelos se descargarán automáticamente la primera")
                self._log("   vez que uses la función de segmentación.")
                self.window.after(0, self._download_failed)

            except Exception as e:
                self._log(f"\n❌ Error durante la descarga: {e}")
                self._log("   Los modelos se descargarán automáticamente la primera")
                self._log("   vez que uses la función de segmentación.")
                self.window.after(0, self._download_failed)

        except Exception as e:
            self._log(f"\n❌ Error inesperado: {e}")
            self.window.after(0, self._download_failed)

    def _download_complete(self):
        """Callback cuando la descarga se completa exitosamente."""
        self.progress_bar.stop()
        self.progress_label.config(text="¡Descarga completada!")
        self.setup_completed = True
        self.close_btn.config(state=tk.NORMAL)
        messagebox.showinfo(
            "Descarga Completada",
            "Los modelos se han descargado correctamente.\n\n"
            "AURA está listo para usar."
        )

    def _download_failed(self):
        """Callback cuando la descarga falla."""
        self.progress_bar.stop()
        self.progress_label.config(text="Descarga omitida o fallida")
        self.download_btn.config(state=tk.NORMAL)
        self.skip_btn.config(state=tk.NORMAL)
        self.close_btn.config(state=tk.NORMAL)

    def _skip_download(self):
        """Omite la descarga de modelos."""
        response = messagebox.askyesno(
            "Omitir Descarga",
            "¿Estás seguro de que quieres omitir la descarga?\n\n"
            "Los modelos se descargarán automáticamente la primera vez que uses "
            "la función de segmentación, lo cual puede causar una demora inesperada."
        )

        if response:
            self._log("\n⏭️ Descarga omitida por el usuario.")
            self._log("   Los modelos se descargarán automáticamente cuando sea necesario.")
            self.setup_completed = True
            self._close_window()

    def _close_window(self):
        """Cierra la ventana."""
        if self.parent:
            self.window.grab_release()
        self.window.destroy()

    def show(self):
        """Muestra la ventana y espera a que se cierre.

        Returns:
            bool: True si se completó la configuración, False si se omitió
        """
        self.window.wait_window()
        return self.setup_completed


def check_first_run():
    """Verifica si es la primera ejecución y si los modelos están descargados.

    Returns:
        bool: True si es necesario mostrar la ventana de configuración inicial
    """
    # Verificar si existe el directorio de modelos
    model_dir = Path.home() / ".totalsegmentator" / "nnunet" / "results"

    # Si el directorio existe y tiene contenido, no es primera ejecución
    if model_dir.exists() and any(model_dir.iterdir()):
        return False

    # Si no existen los modelos, es primera ejecución
    return True


def run_first_setup(parent=None):
    """Ejecuta la configuración inicial si es necesario.

    Args:
        parent: Ventana padre (opcional)

    Returns:
        bool: True si se mostró la configuración y se completó, False si se omitió
    """
    if not check_first_run():
        return False

    setup_window = FirstRunSetupWindow(parent)
    return setup_window.show()


if __name__ == "__main__":
    # Modo de prueba standalone
    run_first_setup()
