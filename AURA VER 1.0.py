import os
import re  # Added for sanitizing filenames
import json
import threading
import traceback
import tkinter as tk
import shutil
from tkinter import filedialog, messagebox, ttk
from tkinter.scrolledtext import ScrolledText
from datetime import datetime
from collections import defaultdict
from pydicom.uid import ExplicitVRLittleEndian
import sys
import io  # For redirecting stdout/stderr when packaged as an executable
torch = None  # type: ignore  # deferred import; loaded in load_heavy_modules
import pydicom
import numpy as np
import hashlib
import urllib.request  # For downloading TotalSegmentator ZIP when needed
import tempfile  # For creating temporary files for ZIP downloads
from copy import deepcopy
from gpu_setup import prepare_gpu_environment

# Additional imports for splash screen timing and theme management
import time

# Introduce psutil to inspect system memory.  We will use this to
# automatically suggest a suitable model resolution based on the RAM
# available on the host.  psutil is lightweight and widely used.
try:
    import psutil  # type: ignore
except ImportError:
    psutil = None  # fallback if psutil is not installed; auto mode disabled

# Heavy dependencies such as MONAI, Torch and others are loaded lazily
# to allow the splash screen to appear immediately.  We define placeholders
# here that will be populated by the `load_heavy_modules` function later.
Compose = None  # type: ignore
LoadImaged = None  # type: ignore
EnsureChannelFirstd = None  # type: ignore
Orientationd = None  # type: ignore
ScaleIntensityRanged = None  # type: ignore
Spacingd = None  # type: ignore
ToTensord = None  # type: ignore
Invertd = None  # type: ignore
CropForegroundd = None  # type: ignore
Spacing = None  # type: ignore
EnsureTyped = None  # type: ignore
Activationsd = None  # type: ignore
AsDiscreted = None  # type: ignore
ToNumpyd = None  # type: ignore
MetaTensor = None  # type: ignore
SegResNet = None  # type: ignore
sliding_window_inference = None  # type: ignore
RTStructBuilder = None  # type: ignore

import logging

# Importaciones para redimensionado adaptativo
try:
    from scipy.ndimage import zoom
    SCIPY_AVAILABLE = True
except ImportError:
    SCIPY_AVAILABLE = False

try:
    from skimage.transform import resize as sk_resize
    SKIMAGE_AVAILABLE = True
except ImportError:
    SKIMAGE_AVAILABLE = False

try:
    import nibabel as nib  # noqa: F401
except ImportError:  # pragma: no cover
    nib = None

# -------------------------------------------------------------------------
# Lazy loader for heavy dependencies
#
# The original version of this file imported heavy libraries like MONAI and
# nibabel at module load time.  This caused a long delay before the splash
# screen appeared, because Python must import and initialize those modules
# (which in turn may download models) before any UI is shown.  To improve
# responsiveness, we defer these imports until just before the main
# application starts.  The `load_heavy_modules` function performs these
# imports and assigns them to the global names defined above.  It should be
# called once during application start-up, ideally while the splash screen
# is displayed.

def load_heavy_modules() -> None:
    """Import heavy modules (MONAI, rt_utils, nibabel) and update globals.

    This function is idempotent; subsequent calls have no effect once the
    modules are loaded.  If an import fails, the exception will be raised
    normally so that it can be handled by the caller.
    """
    global Compose, LoadImaged, EnsureChannelFirstd, Orientationd
    global ScaleIntensityRanged, Spacingd, ToTensord, Invertd
    global CropForegroundd, Spacing, EnsureTyped, Activationsd
    global AsDiscreted, ToNumpyd, MetaTensor
    global SegResNet, sliding_window_inference, RTStructBuilder, nib, torch

    # Only load if not already loaded
    if Compose is not None:
        return

    # Import MONAI transforms and other components lazily
    from monai.transforms import (
        Compose as _Compose,
        LoadImaged as _LoadImaged,
        EnsureChannelFirstd as _EnsureChannelFirstd,
        Orientationd as _Orientationd,
        ScaleIntensityRanged as _ScaleIntensityRanged,
        Spacingd as _Spacingd,
        ToTensord as _ToTensord,
        Invertd as _Invertd,
        CropForegroundd as _CropForegroundd,
        Spacing as _Spacing,
        EnsureTyped as _EnsureTyped,
        Activationsd as _Activationsd,
        AsDiscreted as _AsDiscreted,
        ToNumpyd as _ToNumpyd,
    )
    from monai.data import MetaTensor as _MetaTensor
    from monai.networks.nets import SegResNet as _SegResNet
    from monai.inferers import sliding_window_inference as _sliding_window_inference
    from rt_utils import RTStructBuilder as _RTStructBuilder

    # Import torch lazily as well
    import torch as _torch

    # Assign to globals
    Compose = _Compose
    LoadImaged = _LoadImaged
    EnsureChannelFirstd = _EnsureChannelFirstd
    Orientationd = _Orientationd
    ScaleIntensityRanged = _ScaleIntensityRanged
    Spacingd = _Spacingd
    ToTensord = _ToTensord
    Invertd = _Invertd
    CropForegroundd = _CropForegroundd
    Spacing = _Spacing
    EnsureTyped = _EnsureTyped
    Activationsd = _Activationsd
    AsDiscreted = _AsDiscreted
    ToNumpyd = _ToNumpyd
    MetaTensor = _MetaTensor
    SegResNet = _SegResNet
    sliding_window_inference = _sliding_window_inference
    RTStructBuilder = _RTStructBuilder

    # Assign torch
    torch = _torch

    # Optional nibabel
    try:
        import nibabel as _nib  # type: ignore
    except ImportError:
        _nib = None
    nib = _nib

# -------------------------------------------------------------------------
# Utility functions
# -------------------------------------------------------------------------
def looks_like_dicom(path: str) -> bool:
    """Return True if the file at ``path`` appears to be a DICOM file.

    Many DICOM files use the `.dcm` extension, but this is not a strict
    requirement.  To support datasets that omit the extension (for example
    files named simply ``IM1``), AURA uses this helper to detect DICOM
    files by inspecting their byte contents.  A valid DICOM file typically
    contains the ASCII string ``'DICM'`` at byte offset 128.  We attempt
    to read the first 132 bytes and look for this marker.  If the marker
    is not found, the function returns ``False`` without raising an
    exception.  Any I/O error also results in ``False``.  This quick
    heuristic avoids the overhead of a full ``pydicom.dcmread`` on every
    file while still enabling support for extensionless DICOM datasets.
    """
    try:
        with open(path, 'rb') as fp:
            header = fp.read(132)
            # If the file is at least 132 bytes long and contains the DICM
            # marker at the standard offset, we consider it a DICOM file.
            return len(header) >= 132 and header[128:132] == b'DICM'
    except Exception:
        return False


# -------------------------------------------------------------------------
# Logging
# -------------------------------------------------------------------------
# Configuración del registro
# Creamos nuestro propio logger para evitar la creación de un manejador de
# consola predeterminado que podría no soportar caracteres Unicode en
# Windows.  El registro se dirige únicamente a archivo y a la GUI mediante
# nuestro TextHandler.  Las rutas de logs se guardan en una carpeta local.
log_directory = os.path.join(os.path.abspath('.'), 'logs')
os.makedirs(log_directory, exist_ok=True)
logger = logging.getLogger("AutoSeg")
logger.setLevel(logging.INFO)
logger.propagate = False  # evitar propagación al logger raíz

# Manejador de archivo con codificación UTF-8 para soportar caracteres especiales
file_handler = logging.FileHandler(
    os.path.join(log_directory, 'app.log'),
    encoding='utf-8'
)
file_handler.setLevel(logging.INFO)
formatter = logging.Formatter('%(asctime)s [%(levelname)s] %(message)s')
file_handler.setFormatter(formatter)
logger.addHandler(file_handler)

# -------------------------------------------------------------------------
# Paleta de colores (ICRU / fallback)
# -------------------------------------------------------------------------
ICRU_COLORS = {
    "spleen": (255, 0, 0),
    "right kidney": (0, 255, 0),
    "left kidney": (0, 200, 0),
    "gallbladder": (255, 255, 0),
    "esophagus": (255, 0, 255),
    "liver": (0, 255, 255),
    "stomach": (255, 128, 0),
    "aorta": (255, 0, 128),
    "inferior_vena_cava": (128, 0, 255),
    "portal_vein_and_splenic_vein": (0, 128, 255),
    "pancreas": (128, 255, 0),
    "right_adrenal_gland": (255, 0, 64),
    "left_adrenal_gland": (255, 0, 192),
}

# Etiquetas de respaldo (por si falla metadata.json)
FALLBACK_LABELS = {
    "spleen": 1, "right kidney": 2, "left kidney": 3, "gallbladder": 4,
    "esophagus": 42, "liver": 5, "stomach": 6, "aorta": 7,
    "inferior_vena_cava": 8, "portal_vein_and_splenic_vein": 9,
    "pancreas": 10, "right_adrenal_gland": 11, "left_adrenal_gland": 12,
}

# -------------------------------------------------------------------------
# Etiquetas completas para el modelo WholeBody CT (provenientes del metadata de MONAI)
# Este mapeo permite que la aplicación reconozca órganos adicionales como la
# vejiga o los fémures cuando el archivo metadata.json no está disponible.
# Las claves son los nombres de los órganos y los valores son los índices de
# canal de salida del modelo.  Si no se encuentra un órgano durante la
# segmentación, este diccionario proporciona un valor predeterminado.
FULL_LABELS = {
    "spleen": 1,
    "kidney_right": 2,
    "kidney_left": 3,
    "gallbladder": 4,
    "liver": 5,
    "stomach": 6,
    "aorta": 7,
    "inferior_vena_cava": 8,
    "portal_vein_and_splenic_vein": 9,
    "pancreas": 10,
    "adrenal_gland_right": 11,
    "adrenal_gland_left": 12,
    "lung_upper_lobe_left": 13,
    "lung_lower_lobe_left": 14,
    "lung_upper_lobe_right": 15,
    "lung_middle_lobe_right": 16,
    "lung_lower_lobe_right": 17,
    "vertebrae_L5": 18,
    "vertebrae_L4": 19,
    "vertebrae_L3": 20,
    "vertebrae_L2": 21,
    "vertebrae_L1": 22,
    "vertebrae_T12": 23,
    "vertebrae_T11": 24,
    "vertebrae_T10": 25,
    "vertebrae_T9": 26,
    "vertebrae_T8": 27,
    "vertebrae_T7": 28,
    "vertebrae_T6": 29,
    "vertebrae_T5": 30,
    "vertebrae_T4": 31,
    "vertebrae_T3": 32,
    "vertebrae_T2": 33,
    "vertebrae_T1": 34,
    "vertebrae_C7": 35,
    "vertebrae_C6": 36,
    "vertebrae_C5": 37,
    "vertebrae_C4": 38,
    "vertebrae_C3": 39,
    "vertebrae_C2": 40,
    "vertebrae_C1": 41,
    "esophagus": 42,
    "trachea": 43,
    "heart_myocardium": 44,
    "heart_atrium_left": 45,
    "heart_ventricle_left": 46,
    "heart_atrium_right": 47,
    "heart_ventricle_right": 48,
    "pulmonary_artery": 49,
    "brain": 50,
    "iliac_artery_left": 51,
    "iliac_artery_right": 52,
    "iliac_vena_left": 53,
    "iliac_vena_right": 54,
    "small_bowel": 55,
    "duodenum": 56,
    "colon": 57,
    "rib_left_1": 58,
    "rib_left_2": 59,
    "rib_left_3": 60,
    "rib_left_4": 61,
    "rib_left_5": 62,
    "rib_left_6": 63,
    "rib_left_7": 64,
    "rib_left_8": 65,
    "rib_left_9": 66,
    "rib_left_10": 67,
    "rib_left_11": 68,
    "rib_left_12": 69,
    "rib_right_1": 70,
    "rib_right_2": 71,
    "rib_right_3": 72,
    "rib_right_4": 73,
    "rib_right_5": 74,
    "rib_right_6": 75,
    "rib_right_7": 76,
    "rib_right_8": 77,
    "rib_right_9": 78,
    "rib_right_10": 79,
    "rib_right_11": 80,
    "rib_right_12": 81,
    "humerus_left": 82,
    "humerus_right": 83,
    "scapula_left": 84,
    "scapula_right": 85,
    "clavicula_left": 86,
    "clavicula_right": 87,
    "femur_left": 88,
    "femur_right": 89,
    "hip_left": 90,
    "hip_right": 91,
    "sacrum": 92,
    "face": 93,
    "gluteus_maximus_left": 94,
    "gluteus_maximus_right": 95,
    "gluteus_medius_left": 96,
    "gluteus_medius_right": 97,
    "gluteus_minimus_left": 98,
    "gluteus_minimus_right": 99,
    "autochthon_left": 100,
    "autochthon_right": 101,
    "iliopsoas_left": 102,
    "iliopsoas_right": 103,
    "urinary_bladder": 104,
}

# -------------------------------------------------------------------------
# Etiquetas para TotalSegmentator V2
# -------------------------------------------------------------------------
#
# TotalSegmentator V2 devuelve un volumen de etiquetas multicapa con
# índices de 1 a 117 que corresponden a los nombres de estructuras
# anatómicas.  Este mapeo se extrae del README oficial de
# TotalSegmentator (v2)【907556107239607†L488-L605】.  Se utiliza cuando
# se selecciona el modo de modelo "TotalSegmentator" para asociar
# correctamente cada índice a su nombre.  Si se añaden nuevas clases
# en versiones futuras del modelo, este diccionario deberá
# actualizarse en consecuencia.
FALLBACK_TOTALSEG_TOTAL: dict[str, int] = {

    "spleen": 1,

    "kidney_right": 2,

    "kidney_left": 3,

    "gallbladder": 4,

    "liver": 5,

    "stomach": 6,

    "pancreas": 7,

    "adrenal_gland_right": 8,

    "adrenal_gland_left": 9,

    "lung_upper_lobe_left": 10,

    "lung_lower_lobe_left": 11,

    "lung_upper_lobe_right": 12,

    "lung_middle_lobe_right": 13,

    "lung_lower_lobe_right": 14,

    "esophagus": 15,

    "trachea": 16,

    "thyroid_gland": 17,

    "small_bowel": 18,

    "duodenum": 19,

    "colon": 20,

    "urinary_bladder": 21,

    "prostate": 22,

    "kidney_cyst_left": 23,

    "kidney_cyst_right": 24,

    "sacrum": 25,

    "vertebrae_S1": 26,

    "vertebrae_L5": 27,

    "vertebrae_L4": 28,

    "vertebrae_L3": 29,

    "vertebrae_L2": 30,

    "vertebrae_L1": 31,

    "vertebrae_T12": 32,

    "vertebrae_T11": 33,

    "vertebrae_T10": 34,

    "vertebrae_T9": 35,

    "vertebrae_T8": 36,

    "vertebrae_T7": 37,

    "vertebrae_T6": 38,

    "vertebrae_T5": 39,

    "vertebrae_T4": 40,

    "vertebrae_T3": 41,

    "vertebrae_T2": 42,

    "vertebrae_T1": 43,

    "vertebrae_C7": 44,

    "vertebrae_C6": 45,

    "vertebrae_C5": 46,

    "vertebrae_C4": 47,

    "vertebrae_C3": 48,

    "vertebrae_C2": 49,

    "vertebrae_C1": 50,

    "heart": 51,

    "aorta": 52,

    "pulmonary_vein": 53,

    "brachiocephalic_trunk": 54,

    "subclavian_artery_right": 55,

    "subclavian_artery_left": 56,

    "common_carotid_artery_right": 57,

    "common_carotid_artery_left": 58,

    "brachiocephalic_vein_left": 59,

    "brachiocephalic_vein_right": 60,

    "atrial_appendage_left": 61,

    "superior_vena_cava": 62,

    "inferior_vena_cava": 63,

    "portal_vein_and_splenic_vein": 64,

    "iliac_artery_left": 65,

    "iliac_artery_right": 66,

    "iliac_vena_left": 67,

    "iliac_vena_right": 68,

    "humerus_left": 69,

    "humerus_right": 70,

    "scapula_left": 71,

    "scapula_right": 72,

    "clavicula_left": 73,

    "clavicula_right": 74,

    "femur_left": 75,

    "femur_right": 76,

    "hip_left": 77,

    "hip_right": 78,

    "spinal_cord": 79,

    "gluteus_maximus_left": 80,

    "gluteus_maximus_right": 81,

    "gluteus_medius_left": 82,

    "gluteus_medius_right": 83,

    "gluteus_minimus_left": 84,

    "gluteus_minimus_right": 85,

    "autochthon_left": 86,

    "autochthon_right": 87,

    "iliopsoas_left": 88,

    "iliopsoas_right": 89,

    "brain": 90,

    "skull": 91,

    "rib_left_1": 92,

    "rib_left_2": 93,

    "rib_left_3": 94,

    "rib_left_4": 95,

    "rib_left_5": 96,

    "rib_left_6": 97,

    "rib_left_7": 98,

    "rib_left_8": 99,

    "rib_left_9": 100,

    "rib_left_10": 101,

    "rib_left_11": 102,

    "rib_left_12": 103,

    "rib_right_1": 104,

    "rib_right_2": 105,

    "rib_right_3": 106,

    "rib_right_4": 107,

    "rib_right_5": 108,

    "rib_right_6": 109,

    "rib_right_7": 110,

    "rib_right_8": 111,

    "rib_right_9": 112,

    "rib_right_10": 113,

    "rib_right_11": 114,

    "rib_right_12": 115,

    "sternum": 116,

    "costal_cartilages": 117,

}



FALLBACK_TOTALSEG_EXTRA_TASKS = {

    "body": ["body", "body_trunc", "body_extremities", "skin"],

    "body_mr": ["body_trunc", "body_extremities"],

    "vertebrae_mr": [

        "sacrum", "vertebrae_L5", "vertebrae_L4", "vertebrae_L3", "vertebrae_L2",

        "vertebrae_L1", "vertebrae_T12", "vertebrae_T11", "vertebrae_T10", "vertebrae_T9",

        "vertebrae_T8", "vertebrae_T7", "vertebrae_T6", "vertebrae_T5", "vertebrae_T4",

        "vertebrae_T3", "vertebrae_T2", "vertebrae_T1", "vertebrae_C7", "vertebrae_C6",

        "vertebrae_C5", "vertebrae_C4", "vertebrae_C3", "vertebrae_C2", "vertebrae_C1"

    ],

    "cerebral_bleed": ["intracerebral_hemorrhage"],

    "hip_implant": ["hip_implant"],

    "pleural_pericard_effusion": ["pleural_effusion", "pericardial_effusion"],

    "head_glands_cavities": [

        "eye_left", "eye_right", "eye_lens_left", "eye_lens_right", "optic_nerve_left", "optic_nerve_right",

        "parotid_gland_left", "parotid_gland_right", "submandibular_gland_right", "submandibular_gland_left",

        "nasopharynx", "oropharynx", "hypopharynx", "nasal_cavity_right", "nasal_cavity_left",

        "auditory_canal_right", "auditory_canal_left", "soft_palate", "hard_palate"

    ],

    "head_muscles": [

        "masseter_right", "masseter_left", "temporalis_right", "temporalis_left",

        "lateral_pterygoid_right", "lateral_pterygoid_left", "medial_pterygoid_right", "medial_pterygoid_left",

        "tongue", "digastric_right", "digastric_left"

    ],

    "headneck_bones_vessels": [

        "larynx_air", "thyroid_cartilage", "hyoid", "cricoid_cartilage", "zygomatic_arch_right",

        "zygomatic_arch_left", "styloid_process_right", "styloid_process_left", "internal_carotid_artery_right",

        "internal_carotid_artery_left", "internal_jugular_vein_right", "internal_jugular_vein_left"

    ],

    "headneck_muscles": [

        "sternocleidomastoid_right", "sternocleidomastoid_left", "superior_pharyngeal_constrictor",

        "middle_pharyngeal_constrictor", "inferior_pharyngeal_constrictor", "trapezius_right", "trapezius_left",

        "platysma_right", "platysma_left", "levator_scapulae_right", "levator_scapulae_left",

        "anterior_scalene_right", "anterior_scalene_left", "middle_scalene_right", "middle_scalene_left",

        "posterior_scalene_right", "posterior_scalene_left", "sterno_thyroid_right", "sterno_thyroid_left",

        "thyrohyoid_right", "thyrohyoid_left", "prevertebral_right", "prevertebral_left"

    ],

    "liver_vessels": ["liver_vessels", "liver_tumor"],

    "oculomotor_muscles": [

        "skull", "eyeball_right", "lateral_rectus_muscle_right", "superior_oblique_muscle_right",

        "levator_palpebrae_superioris_right", "superior_rectus_muscle_right", "medial_rectus_muscle_left",

        "inferior_oblique_muscle_right", "inferior_rectus_muscle_right", "optic_nerve_left", "eyeball_left",

        "lateral_rectus_muscle_left", "superior_oblique_muscle_left", "levator_palpebrae_superioris_left",

        "superior_rectus_muscle_left", "medial_rectus_muscle_right", "inferior_oblique_muscle_left",

        "inferior_rectus_muscle_left", "optic_nerve_right"

    ],

    "lung_nodules": ["lung", "lung_nodules"],

    "kidney_cysts": ["kidney_cyst_left", "kidney_cyst_right"],

    "breasts": ["breast"],

    "liver_segments": [

        "liver_segment_1", "liver_segment_2", "liver_segment_3", "liver_segment_4",

        "liver_segment_5", "liver_segment_6", "liver_segment_7", "liver_segment_8"

    ],

    "liver_segments_mr": [

        "liver_segment_1", "liver_segment_2", "liver_segment_3", "liver_segment_4",

        "liver_segment_5", "liver_segment_6", "liver_segment_7", "liver_segment_8"

    ],

    "craniofacial_structures": [

        "mandible", "teeth_lower", "skull", "head", "sinus_maxillary", "sinus_frontal", "teeth_upper"

    ]

}



_TOTALSEG_CLASS_MAP: dict[str, dict[int, str]] = {}

try:

    from totalsegmentator.map_to_binary import class_map as _TS_CLASS_MAP  # type: ignore

except Exception:

    _TOTALSEG_CLASS_MAP = {}

else:

    if isinstance(_TS_CLASS_MAP, dict):

        _TOTALSEG_CLASS_MAP = {k: v for k, v in _TS_CLASS_MAP.items() if isinstance(v, dict)}



def _invert_totalseg_map(raw: dict[int, str]) -> dict[str, int]:

    return {name: idx for idx, name in raw.items()}



TOTALSEG_TASK_KEYS = (

    "complete",

    "total",

    "body",

    "body_mr",

    "vertebrae_mr",

    "cerebral_bleed",

    "hip_implant",

    "pleural_pericard_effusion",

    "head_glands_cavities",

    "head_muscles",

    "headneck_bones_vessels",

    "headneck_muscles",

    "liver_vessels",

    "oculomotor_muscles",

    "lung_nodules",

    "kidney_cysts",

    "breasts",

    "liver_segments",

    "liver_segments_mr",

    "craniofacial_structures",

)



TOTALSEG_TASK_LABELS: dict[str, dict[str, int]] = {}



if _TOTALSEG_CLASS_MAP:

    for key in TOTALSEG_TASK_KEYS:

        mapping = _TOTALSEG_CLASS_MAP.get(key)

        if isinstance(mapping, dict):

            TOTALSEG_TASK_LABELS[key] = _invert_totalseg_map(mapping)



if not TOTALSEG_TASK_LABELS:

    TOTALSEG_TASK_LABELS["total"] = FALLBACK_TOTALSEG_TOTAL.copy()

    for key, names in FALLBACK_TOTALSEG_EXTRA_TASKS.items():

        TOTALSEG_TASK_LABELS[key] = {name: idx + 1 for idx, name in enumerate(names)}

else:

    for key, names in FALLBACK_TOTALSEG_EXTRA_TASKS.items():

        if key not in TOTALSEG_TASK_LABELS and names:

            TOTALSEG_TASK_LABELS[key] = {name: idx + 1 for idx, name in enumerate(names)}



def _build_complete_totalseg_map() -> dict[str, int]:

    combined: dict[str, int] = {}

    for key, labels in TOTALSEG_TASK_LABELS.items():

        if key == "complete":

            continue

        for organ, idx in labels.items():

            combined.setdefault(organ, idx)

    return combined



if TOTALSEG_TASK_LABELS:

    complete_labels = _build_complete_totalseg_map()

    if complete_labels and "complete" not in TOTALSEG_TASK_LABELS:

        TOTALSEG_TASK_LABELS["complete"] = complete_labels






if "total" not in TOTALSEG_TASK_LABELS:

    TOTALSEG_TASK_LABELS["total"] = FALLBACK_TOTALSEG_TOTAL.copy()



TOTALSEG_LABELS: dict[str, int] = TOTALSEG_TASK_LABELS["total"]

# -------------------------------------------------------------------------
# Temas de interfaz
# Cada tema define colores base para fondo, texto, acento, botones y la barra
# de progreso.  El usuario puede seleccionar el tema deseado desde el menú
# Configuración.  'azure' es el tema predeterminado inspirado en la
# identidad visual de la aplicación.
THEME_OPTIONS = {
    "azure": {
        "bg": "#EEF5FF",
        "fg": "#1F2937",
        "accent": "#0078D4",
        "button_bg": "#0078D4",
        "button_fg": "#FFFFFF",
        "progress_fg": "#0078D4",
    },
    "light": {
        "bg": "#F5F5F5",
        "fg": "#1F2937",
        "accent": "#4F46E5",
        "button_bg": "#4F46E5",
        "button_fg": "#FFFFFF",
        "progress_fg": "#4F46E5",
    },
    "dark": {
        "bg": "#1F2937",
        "fg": "#E5E7EB",
        "accent": "#2D6CDF",
        "button_bg": "#2D6CDF",
        "button_fg": "#FFFFFF",
        "progress_fg": "#2D6CDF",
    },
}


# -------------------------------------------------------------------------
# Utilidades de rutas
# -------------------------------------------------------------------------
def resource_path(relative_path: str) -> str:
    """Ruta absoluta usable con PyInstaller y modo desarrollo."""
    try:
        base_path = sys._MEIPASS  # PyInstaller crea carpeta temporal
    except AttributeError:  # Modo desarrollo
        base_path = os.path.abspath(".")
    return os.path.join(base_path, relative_path)


BUNDLE_DIR = resource_path("wholeBody_ct_segmentation")
WEIGHTS_HIGHRES = os.path.join(BUNDLE_DIR, "models", "model.pt")
WEIGHTS_LOWRES = os.path.join(BUNDLE_DIR, "models", "model_lowres.pt")
META_JSON = os.path.join(BUNDLE_DIR, "configs", "metadata.json")


# -------------------------------------------------------------------------
# Helpers de nombres / colores
# -------------------------------------------------------------------------
def dicom_safe_name(lbl: str) -> str:
    """Normaliza nombres para compatibilidad DICOM RTSTRUCT (<=32 chars)."""
    return lbl.replace("_", " ")[:32]


def get_organ_color(organ_name: str) -> tuple[int, int, int]:
    """Color preferido o generado determinísticamente."""
    lower_name = organ_name.lower()
    for name, color in ICRU_COLORS.items():
        if name.lower() in lower_name:
            return color

    h = int(hashlib.md5(organ_name.encode()).hexdigest()[:6], 16)
    r = (h >> 16) & 0xFF
    g = (h >> 8) & 0xFF
    b = h & 0xFF
    if (r + g + b) < 60:  # evitar casi-negro
        r, g, b = (r | 0x40, g | 0x40, b | 0x40)
    return (r, g, b)


# -------------------------------------------------------------------------
# Sanitización de nombres de archivo
# -------------------------------------------------------------------------
def sanitize_filename(name: str) -> str:
    r"""
    Reemplaza caracteres inválidos en nombres de directorios/archivos por guiones bajos.

    En Windows no se permiten los caracteres  < > : \" / \\ | ? * y también pueden causar
    problemas en otros sistemas de archivos.  Además se eliminan espacios
    iniciales/finales y se colapsan múltiples guiones bajos consecutivos.

    Parámetros
    ----------
    name : str
        Nombre original extraído de los metadatos DICOM.

    Devuelve
    -------
    str
        Versión segura para usar en rutas de archivos. Si el resultado queda
        vacío, devuelve "Patient".
    """
    # Sustituir caracteres prohibidos por guión bajo
    sanitized = re.sub(r'[<>:"/\\|?*]', '_', name)
    # Colapsar múltiples guiones bajos
    sanitized = re.sub(r'_+', '_', sanitized)
    # Recortar espacios y guiones bajos al principio y al final
    sanitized = sanitized.strip(' _')
    return sanitized or "Patient"


# -------------------------------------------------------------------------
# Utilidades de redimensionado adaptativo
# -------------------------------------------------------------------------
def smart_resize_prediction(pred_array, target_shape, max_distortion=0.3):
    """
    Redimensiona predicción de forma inteligente, evitando distorsiones excesivas.
    
    Args:
        pred_array: Array de predicción (Z, Y, X)
        target_shape: Forma objetivo (Z, Y, X)
        max_distortion: Máxima distorsión permitida (0.3 = 30%)
    
    Returns:
        Array redimensionado o el original si la distorsión es excesiva
    """
    current_shape = pred_array.shape
    
    # Calcular factores de escala
    scale_factors = [target_shape[i] / current_shape[i] for i in range(3)]
    
    # Verificar distorsión
    min_scale = min(scale_factors)
    max_scale = max(scale_factors)
    distortion = abs(max_scale - min_scale) / min_scale
    
    if distortion > max_distortion:
        # If the scaling factors differ too much, avoid resizing to prevent distortions
        logger.warning(
            f"Excessive distortion detected ({distortion:.2f} > {max_distortion}), keeping original shape {current_shape}"
        )
        return pred_array
    
    # Intentar redimensionado con diferentes métodos
    methods = []
    
    if SCIPY_AVAILABLE:
        methods.append(("scipy_zoom", lambda: _resize_with_scipy(pred_array, target_shape)))
    
    if SKIMAGE_AVAILABLE:
        methods.append(("skimage", lambda: _resize_with_skimage(pred_array, target_shape)))
    
    methods.append(("numpy_simple", lambda: _resize_with_numpy(pred_array, target_shape)))
    
    for method_name, method_func in methods:
        try:
            logger.info(f"Attempting resizing with {method_name}")
            resized = method_func()
            if resized.shape == target_shape:
                logger.info(f"✔ Resizing successful with {method_name}: {current_shape} → {target_shape}")
                return resized
        except Exception as e:
            logger.warning(f"Method {method_name} failed: {e}")
    
    logger.warning(
        f"All resizing methods failed, keeping original shape {current_shape}"
    )
    return pred_array


def _resize_with_scipy(pred_array, target_shape):
    """Redimensiona usando scipy.ndimage.zoom"""
    zoom_factors = [target_shape[i] / pred_array.shape[i] for i in range(3)]
    
    # Redimensionar cada clase por separado para mantener integridad
    unique_labels = np.unique(pred_array)
    pred_resized = np.zeros(target_shape, dtype=pred_array.dtype)
    
    for label in unique_labels:
        if label == 0:  # background
            continue
        mask = (pred_array == label).astype(np.float32)
        mask_resized = zoom(mask, zoom_factors, order=0)  # nearest neighbor
        pred_resized[mask_resized > 0.5] = label
    
    return pred_resized


def _resize_with_skimage(pred_array, target_shape):
    """Redimensiona usando skimage.transform.resize"""
    resized = sk_resize(pred_array.astype(np.float32), target_shape, 
                       order=0, preserve_range=True, anti_aliasing=False)
    return resized.astype(pred_array.dtype)


def _resize_with_numpy(pred_array, target_shape):
    """Redimensiona usando interpolación simple con numpy"""
    z_old, y_old, x_old = pred_array.shape
    z_new, y_new, x_new = target_shape
    
    # Crear mapeo de índices
    z_indices = np.linspace(0, z_old-1, z_new).round().astype(int)
    y_indices = np.linspace(0, y_old-1, y_new).round().astype(int)
    x_indices = np.linspace(0, x_old-1, x_new).round().astype(int)
    
    # Aplicar mapeo
    resized = pred_array[np.ix_(z_indices, y_indices, x_indices)]
    return resized


# -------------------------------------------------------------------------
# App principal
# -------------------------------------------------------------------------
class AutoSegApp(tk.Tk):
    """
    Ventana principal de la aplicación AURA. Esta versión se ha simplificado
    para utilizar exclusivamente el modelo TotalSegmentator V2. Se eliminan
    completamente las opciones de selección de modelo y resolución de la red
    SegResNet original. Además, se incorpora un mecanismo de persistencia
    de configuración (tema, orientación, rutas de entrada/salida, etc.) y
    una comprobación inicial de CUDA y de la disponibilidad de la librería
    totalsegmentator. Si totalsegmentator no está instalado y se detecta
    soporte CUDA, se intentará instalar automáticamente mediante pip. Si
    falla la instalación automática, se notificará al usuario mediante el
    registro de la aplicación.
    """

    def _log_cuda_diagnostics(self):
        """Log extended Torch/CUDA diagnostics to help troubleshoot GPU issues."""
        try:
            import torch as _t
            ver = getattr(_t, '__version__', 'unknown')
            cuda_built = getattr(_t.version, 'cuda', None) if hasattr(_t, 'version') else None
            avail = _t.cuda.is_available() if hasattr(_t, 'cuda') else False
            dev_count = _t.cuda.device_count() if avail else 0
            cudnn_avail = _t.backends.cudnn.is_available() if hasattr(_t, 'backends') and hasattr(_t.backends, 'cudnn') else False
            self._log(f"Torch version: {ver}")
            self._log(f"Torch CUDA build: {cuda_built}")
            self._log(f"CUDA available: {avail}; device_count: {dev_count}; cuDNN: {cudnn_avail}")
            if 'CUDA_VISIBLE_DEVICES' in os.environ:
                self._log(f"CUDA_VISIBLE_DEVICES={os.environ['CUDA_VISIBLE_DEVICES']}")
            if avail:
                for i in range(dev_count):
                    try:
                        name = _t.cuda.get_device_name(i)
                        cap = _t.cuda.get_device_capability(i)
                        self._log(f"GPU {i}: {name}; capability: {cap}")
                    except Exception as e:
                        self._log(f"GPU {i} info error: {e}")
        except Exception as e:
            self._log(f"CUDA diagnostics failed: {e}")

    def __init__(self):
        super().__init__()
        # Window title and initial size
        # Use an English title for consistency throughout the UI
        self.title("AURA – Automatic Segmentation")
        self.geometry("800x650")

        # -----------------------------------------------------------------
        # Asignar un icono a la aplicación
        # -----------------------------------------------------------------
        # Cuando se genera un instalador con PyInstaller, los recursos como
        # imágenes y archivos de icono se empaquetan junto con el ejecutable.
        # Utilizamos la función resource_path para localizar correctamente
        # el archivo ico.png tanto en modo desarrollo como en el ejecutable
        # empaquetado.  El método iconphoto acepta objetos PhotoImage y
        # funciona en Windows, macOS y Linux.  Si el archivo no está
        # disponible o no es compatible, la asignación del icono se
        # ignora silenciosamente.
        try:
            icon_png_path = resource_path("ico.png")
            icon_image = tk.PhotoImage(file=icon_png_path)
            # El primer argumento (False) indica que el icono aplica a la
            # ventana principal y a todas las subventanas.
            self.iconphoto(False, icon_image)
        except Exception:
            # No interrumpir la inicialización si no se puede cargar el icono
            pass

        # Detectar dispositivo disponible
        self.device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        # Para totalsegmentator usamos un string simple ('gpu' o 'cpu')
        self.device_preference: str = 'gpu' if torch.cuda.is_available() else 'cpu'

        # Referencia al modelo segresnet ya no se utiliza, pero se mantiene
        # para compatibilidad de atributos.  Se inicializa a None.
        self.model = None
        self.labels_map: dict[str, int] = {}
        self.organ_preferences: dict[str, list[str]] = {}
        self.organs: list[str] = []
        self.ready = False

        # Tipo de modelo fijo: siempre 'totalseg'
        self.model_type: str = "totalseg"
        self.totalseg_task: str = "complete"

        # Transformaciones previas y posteriores (no usadas con TotalSegmentator)
        self.pre_transforms = None
        self.post_transforms = None

        # Resolution for TotalSegmentator: 'highres' controls the 'fast'
        # parameter (False for 1.5 mm and True for 3 mm).  The default is
        # selected automatically based on whether a CUDA–capable GPU is
        # available.  This value is persisted in the configuration and can
        # still be changed by the user via the menu.
        self.highres = True
        self._auto_select_resolution()

        # Tema y orientación por defecto.  flip_ap se establece a True para
        # invertir el eje antero–posterior de forma predeterminada según
        # indicación del usuario.  Estos valores pueden ser sobrescritos por
        # la configuración cargada al iniciar.
        self.style_name: str = "azure"
        self.flip_lr: bool = False  # invertir eje X (izquierda-derecha)
        self.flip_ap: bool = True   # invertir eje Y (anterior-posterior)
        self.flip_si: bool = False  # invertir eje Z (superior-inferior)

        # Control de recorte de foreground (actualmente no usado por
        # totalsegmentator, pero se mantiene por compatibilidad).  Se
        # persiste en la configuración.
        self.use_crop: bool = True
        # Margen de recorte (voxeles)
        self.crop_margin: int = 10

        # Gestor de estilos para ttk
        self.style = ttk.Style()

        # Activación de limpieza morfológica de máscaras
        self.clean_masks: bool = True

        # Ruta del fichero de configuración en el directorio de usuario
        self.config_path = os.path.join(os.path.expanduser("~"), ".autoseg_config.json")

        # Marcar si ya se mostró el diálogo para instalar TotalSegmentator.  Se
        # usa para evitar preguntar en cada inicio.  Se persiste en la
        # configuración.
        self.totalseg_prompted: bool = False

        # Logging hacia GUI
        self.log_handler = TextHandler(self)
        logger.addHandler(self.log_handler)

        # Construir interfaz
        self._build_ui()

        # Cargar configuración (si existe) para sobrescribir valores
        self._load_config()

        # Aplicar tema tras cargar configuración
        self.apply_theme()

        # Mensajes iniciales de registro
        self._log("👷 Application started")
        self._log(f"💻 Using {'GPU' if torch.cuda.is_available() else 'CPU'}")
        if torch.cuda.is_available():
            try:
                self._log(f"🔧 GPU detected: {torch.cuda.get_device_name(0)}")
            except Exception:
                self._log("🔧 GPU detected but the name could not be retrieved")

        # Log de librerías disponibles
        resize_libs = []
        if SCIPY_AVAILABLE:
            resize_libs.append("scipy")
        if SKIMAGE_AVAILABLE:
            resize_libs.append("skimage")
        resize_libs.append("numpy")
        self._log(f"🔧 Available resizing libraries: {', '.join(resize_libs)}")

        # CUDA/Torch diagnostics to aid troubleshooting
        try:
            self._log_cuda_diagnostics()
        except Exception:
            pass

        # Check and install TotalSegmentator if necessary
        self._ensure_totalseg()

        # Initial instruction message
        self._log("Select the input and output folders and then press 'Process' to start")

        # Capturar el cierre de la ventana para guardar la configuración
        self.protocol("WM_DELETE_WINDOW", self._on_close)

        # Track whether TotalSegmentator weights have been downloaded yet.  The
        # first time a segmentation is run the models will be downloaded and
        # cached; we inform the user about this process.
        self.totalseg_downloaded: bool = False

        # Automatically prepare the TotalSegmentator model.  In the original
        # application this was triggered via a menu item, but since the
        # application now always uses TotalSegmentator we load it on start.
        # Running this in a thread prevents blocking the UI during import.
        try:
            # Start the model loading process in the background
            self._load_model_thread()
        except Exception:
            # If loading fails, the user will be informed via the log
            pass

    def _selection_key(self, model=None, task=None) -> str:
        model_name = model or self.model_type
        if model_name == 'totalseg':
            task_name = task if task is not None else self.totalseg_task
            return f'totalseg:{task_name}'
        return model_name

    def _store_current_selection(self) -> None:
        self.organ_preferences[self._selection_key()] = list(self.organs)

    def _apply_saved_organs(self) -> None:
        if not self.labels_map:
            self.organs = []
            return
        key = self._selection_key()
        saved = self.organ_preferences.get(key, [])
        filtered = [org for org in saved if org in self.labels_map]
        if not filtered:
            if self.totalseg_task == "complete":
                filtered = []
            else:
                filtered = list(self.labels_map.keys())
        self.organs = filtered
        self.organ_preferences[key] = list(filtered)

    def _update_totalseg_labels(self) -> None:
        task_labels = TOTALSEG_TASK_LABELS.get(self.totalseg_task)
        if not task_labels:
            self._log(f"Warning: TotalSegmentator task '{self.totalseg_task}' not available. Using 'total'.")
            self.totalseg_task = 'total'
            task_labels = TOTALSEG_TASK_LABELS['total']
        self.labels_map = task_labels.copy()
        self._apply_saved_organs()

    # ------------------------------------------------------------------
    # Selección automática de resolución
    # ------------------------------------------------------------------
    def _auto_select_resolution(self):
        """Select a default resolution based on GPU availability.

        In the original application this method attempted to choose
        between the 1.5 mm (high‑resolution) and 3 mm (fast) variants of
        the TotalSegmentator model by inspecting available system RAM.  In
        practice the choice is more closely tied to whether a CUDA
        capable GPU is present: GPUs handle the high‑resolution model
        efficiently, while CPU‑only systems benefit from the smaller
        fast model.  Therefore this method now simply checks for GPU
        availability and assigns the resolution accordingly.  An
        informational log entry is also written.
        """
        try:
            # Use high resolution (1.5 mm) when a CUDA device is available; otherwise use the fast 3 mm model
            self.highres = bool(torch.cuda.is_available())
            logger.info(
                f"Default model resolution set to {'1.5 mm' if self.highres else '3 mm'} based on GPU availability"
            )
        except Exception as e:
            # If any error occurs, fall back to high resolution as a safe default
            self.highres = True
            logger.warning(f"Could not determine GPU availability: {e}")

    # ------------------------------------------------------------------
    # GUI
    # ------------------------------------------------------------------
    def _build_ui(self):
        """
        Construye la interfaz de usuario principal, incluyendo la barra de menús
        reorganizada. Además de las secciones de "Configuración" y "Ayuda"
        originales, ahora se incluyen nuevos menús "Aspecto", "Segmentación"
        y "Modelo".  Cada sección agrupa opciones de forma más coherente con
        su función. Por ejemplo, la selección del tema se mueve a "Aspecto",
        las opciones de orientación y selección de órganos se agrupan bajo
        "Segmentación", y la resolución, el dispositivo de cómputo y el
        recorte automático se encuentran en "Modelo".  Se introducen
        variables de control adicionales para las nuevas opciones.
        """
        # Create the main menu bar
        menubar = tk.Menu(self)

        # Appearance menu: visual options for the application
        appearance_menu = tk.Menu(menubar, tearoff=0)
        appearance_menu.add_command(label="Select theme", command=self._choose_theme)
        menubar.add_cascade(label="Appearance", menu=appearance_menu)

        # Segmentation menu: groups options related to segmentation and
        # post‑processing of masks
        segment_menu = tk.Menu(menubar, tearoff=0)
        segment_menu.add_command(label="Orientation options", command=self._choose_orientation)
        segment_menu.add_command(label="Select organs", command=self._select_organs)
        # Variable for controlling morphological cleaning of masks
        self.clean_masks_var = tk.BooleanVar(value=self.clean_masks)
        segment_menu.add_checkbutton(
            label="Mask cleaning", onvalue=True, offvalue=False,
            variable=self.clean_masks_var, command=self._toggle_clean
        )
        # Allow the user to adjust the cropping margin
        segment_menu.add_command(label="Crop margin", command=self._choose_crop_margin)
        menubar.add_cascade(label="Segmentation", menu=segment_menu)

        # Model menu: contains options relevant to TotalSegmentator
        model_menu = tk.Menu(menubar, tearoff=0)
        # Allow the user to change the resolution (1.5 mm vs 3 mm)
        model_menu.add_command(label="Select resolution", command=self._choose_resolution)
        # Allow the user to select the computation device (CPU/GPU)
        model_menu.add_command(label="Select device", command=self._choose_device)
        # Variable for enabling/disabling automatic body cropping
        self.use_crop_var = tk.BooleanVar(value=self.use_crop)
        model_menu.add_checkbutton(
            label="Automatic body cropping", onvalue=True, offvalue=False,
            variable=self.use_crop_var, command=self._toggle_crop
        )
        menubar.add_cascade(label="Model", menu=model_menu)

        # Help menu: general information and access to the error report
        help_menu = tk.Menu(menubar, tearoff=0)
        help_menu.add_command(label="About", command=self._show_about)
        help_menu.add_command(label="View log", command=self._show_log)
        menubar.add_cascade(label="Help", menu=help_menu)

        self.config(menu=menubar)

        # Input
        input_frame = tk.LabelFrame(self, text="Input", padx=5, pady=5)
        input_frame.pack(fill="x", padx=10, pady=5)

        tk.Label(input_frame, text="Patients folder (DICOM subfolders):").pack(anchor="w")
        self.in_entry = tk.Entry(input_frame, width=80)
        self.in_entry.pack(fill="x", padx=5, pady=(0, 5))
        tk.Button(input_frame, text="Browse...", command=lambda: self._browse(self.in_entry)).pack(pady=(0, 5))

        # Output
        output_frame = tk.LabelFrame(self, text="Output", padx=5, pady=5)
        output_frame.pack(fill="x", padx=10, pady=5)

        tk.Label(output_frame, text="Destination folder (RTSTRUCT):").pack(anchor="w")
        self.out_entry = tk.Entry(output_frame, width=80)
        self.out_entry.pack(fill="x", padx=5, pady=(0, 5))
        tk.Button(output_frame, text="Browse...", command=lambda: self._browse(self.out_entry)).pack(pady=(0, 5))

        # Controls
        control_frame = tk.Frame(self)
        control_frame.pack(pady=10)

        self.btn_one = tk.Button(control_frame, text="Process ONE patient",
                                 state="disabled", command=self._run_one_thread)
        self.btn_one.pack(side="left", padx=5)

        self.btn_all = tk.Button(control_frame, text="Process ALL (batch)",
                                 state="disabled", command=self._run_all_thread)
        self.btn_all.pack(side="left", padx=5)

        # Progress bar
        self.progress = ttk.Progressbar(self, length=780, mode="determinate")
        self.progress.pack(padx=10, pady=(0, 10))

        # Log
        log_frame = tk.LabelFrame(self, text="Activity log", padx=5, pady=5)
        log_frame.pack(fill="both", expand=True, padx=10, pady=(0, 10))

        self.log = ScrolledText(log_frame, state="disabled", height=18, wrap="word")
        self.log.pack(fill="both", expand=True, padx=5, pady=5)

        # Credits: small text at the bottom of the window
        self.footer_label = tk.Label(
            self,
            text="by Agustin Rosich creative commons 2025 – open source, all rights reserved. This program may not be sold.",
            font=("Arial", 8),
            anchor="e"
        )
        self.footer_label.pack(fill="x", side="bottom", padx=10, pady=(0, 5))

    # ------------------------------------------------------------------
    # Visualizar log en ventana
    # ------------------------------------------------------------------
    def _show_log(self):
        """
        Open a window displaying the contents of the application log for review.

        This method creates a new top‑level window and populates it with the
        contents of the `app.log` file located in the logging directory.  If
        the log file cannot be read, an error message is shown instead.  The
        text is placed into a read‑only `ScrolledText` widget for easy
        navigation.
        """
        win = tk.Toplevel(self)
        # Use an English title for the log window
        win.title("Error and activity report")
        win.geometry("600x400")
        text = ScrolledText(win, state="normal", wrap="word")
        text.pack(fill="both", expand=True)
        try:
            with open(os.path.join(log_directory, 'app.log'), 'r', encoding='utf-8') as f:
                content = f.read()
        except Exception as e:
            # Fall back to a meaningful message if the log cannot be read
            content = f"Could not read the log: {e}"
        text.insert("1.0", content)
        text.configure(state="disabled")

    # ------------------------------------------------------------------
    # Logging a GUI
    # ------------------------------------------------------------------
    def _log(self, msg: str):
        ts = datetime.now().strftime("%H:%M:%S")
        self.after(0, lambda: self._append_log_from_main(f"[{ts}] {msg}\n"))

    def _append_log_from_main(self, msg: str):
        self.log.configure(state="normal")
        self.log.insert(tk.END, msg)
        self.log.see(tk.END)
        self.log.configure(state="disabled")
        self.update_idletasks()

    # ------------------------------------------------------------------
    # About
    # ------------------------------------------------------------------
    def _show_about(self):
        about = tk.Toplevel(self)
        about.title("About AURA")
        about.geometry("430x320")

        tk.Label(
            about,
            text="AURA Ver 1.0",
            font=("Arial", 14, "bold"),
        ).pack(pady=10)

        tk.Label(
            about,
            text=(
                "Application for automatic segmentation of anatomical structures\n"
                "in CT images and the generation of RTSTRUCT files.\n"
                "Includes intelligent adaptive transformations and advanced options."
            ),
            wraplength=400,
        ).pack(pady=5)

        tk.Label(about, text="Version 1.1").pack(pady=5)
        tk.Label(
            about,
            text="© 2025 Agustin Rosich – Open source software under MIT license.\n"
                 "Automatic DICOM segmentation tool powered by AI. For academic and supervised clinical use.",
            font=("Arial", 8),
            justify="center",
        ).pack(pady=5)

        # Provide a clear Close button in English
        ttk.Button(about, text="Close", command=about.destroy).pack(pady=10)

    # ------------------------------------------------------------------
    # Menu para seleccionar resolución
    # ------------------------------------------------------------------
    def _choose_resolution(self):
        """Allow the user to change the model resolution."""
        win = tk.Toplevel(self)
        win.title("Choose model resolution")
        win.geometry("300x200")

        var = tk.StringVar(value='1.5' if self.highres else '3')
        tk.Label(win, text="Select model resolution:").pack(pady=10)
        tk.Radiobutton(win, text="High (1.5 mm)", variable=var, value='1.5').pack(anchor="w", padx=20)
        tk.Radiobutton(win, text="Low (3 mm)", variable=var, value='3').pack(anchor="w", padx=20)
        tk.Button(win, text="Confirm", command=lambda: self._set_resolution(var.get(), win)).pack(pady=10)

    def _set_resolution(self, value: str, window: tk.Toplevel):
        self.highres = (value == '1.5')
        self._log(f"🔧 Resolution selected: {'1.5 mm' if self.highres else '3 mm'}")
        window.destroy()

    # ------------------------------------------------------------------
    # Tema de la aplicación
    # ------------------------------------------------------------------
    def apply_theme(self):
        """
        Aplica los colores definidos en el tema actual a los widgets principales.
        Cambia los colores de fondo y primer plano de los elementos de la
        interfaz.  Este método puede invocarse después de cambiar
        `self.style_name` para actualizar dinámicamente la apariencia.
        """
        theme = THEME_OPTIONS.get(self.style_name, THEME_OPTIONS["azure"])
        bg = theme["bg"]
        fg = theme["fg"]
        accent = theme["accent"]

        # Configurar raíz
        self.configure(bg=bg)

        # Configurar ttk estilos
        try:
            self.style.theme_use('default')
        except Exception:
            pass
        # Asignar colores genéricos a todos los widgets
        self.style.configure('.', background=bg, foreground=fg, font=("Segoe UI", 10))
        self.style.configure('TButton', background=theme['button_bg'], foreground=theme['button_fg'], borderwidth=1)
        self.style.map('TButton', background=[('active', theme['accent'])], foreground=[('active', theme['button_fg'])])
        self.style.configure('TLabel', background=bg, foreground=fg)
        self.style.configure('TLabelframe', background=bg, foreground=fg)
        self.style.configure('TLabelframe.Label', background=bg, foreground=fg)
        self.style.configure('TFrame', background=bg, foreground=fg)
        self.style.configure('TCheckbutton', background=bg, foreground=fg)
        self.style.configure('TMenubutton', background=bg, foreground=fg)
        self.style.configure('TProgressbar', troughcolor=bg, background=theme['progress_fg'])

        # Configurar widgets Tk (no ttk) manualmente
        # Entradas, botones y texto
        for widget in [self.in_entry, self.out_entry, self.btn_one, self.btn_all, self.footer_label, self.log]:
            try:
                widget.configure(bg=bg, fg=fg, insertbackground=fg)
            except Exception:
                pass

        # Log específico: cambiar color de fondo y texto
        self.log.configure(background=bg, foreground=fg)

        # Actualizar recursivamente contenedores
        def update_children(w):
            for child in w.winfo_children():
                try:
                    # Cambiar color de fondo de widgets Tk heredados
                    if isinstance(child, (tk.Frame, tk.LabelFrame)):
                        child.configure(bg=bg)
                    elif isinstance(child, tk.Label):
                        child.configure(bg=bg, fg=fg)
                    elif isinstance(child, tk.Button):
                        child.configure(bg=theme['button_bg'], fg=theme['button_fg'], activebackground=accent)
                except Exception:
                    pass
                update_children(child)
        update_children(self)

    def _choose_theme(self):
        """Display a window to select the UI theme."""
        win = tk.Toplevel(self)
        win.title("Select theme")
        win.geometry("250x200")
        win.configure(bg=THEME_OPTIONS[self.style_name]['bg'])

        var = tk.StringVar(value=self.style_name)
        tk.Label(
            win,
            text="Interface theme:",
            bg=THEME_OPTIONS[self.style_name]['bg'],
            fg=THEME_OPTIONS[self.style_name]['fg'],
        ).pack(pady=10)
        for name in THEME_OPTIONS.keys():
            ttk.Radiobutton(win, text=name.capitalize(), variable=var, value=name).pack(anchor="w", padx=20, pady=2)
        ttk.Button(win, text="Confirm", command=lambda: self._set_theme(var.get(), win)).pack(pady=10)

    def _set_theme(self, value: str, window: tk.Toplevel):
        """Establece el tema actual y actualiza la interfaz."""
        self.style_name = value
        self.apply_theme()
        window.destroy()
        self._log(f"🎨 Theme selected: {value}")

        # Guardar configuración actualizada
        self._save_config()

    # ------------------------------------------------------------------
    # Opciones de orientación (flip) de la tomografía
    # ------------------------------------------------------------------
    def _choose_orientation(self):
        """Window to select axis inversions for the CT volume."""
        win = tk.Toplevel(self)
        win.title("Orientation options")
        win.geometry("300x220")
        win.configure(bg=THEME_OPTIONS[self.style_name]['bg'])

        tk.Label(
            win,
            text="Flip volume axes (select those that apply)",
            bg=THEME_OPTIONS[self.style_name]['bg'],
            fg=THEME_OPTIONS[self.style_name]['fg'],
        ).pack(pady=10)

        var_lr = tk.BooleanVar(value=self.flip_lr)
        var_ap = tk.BooleanVar(value=self.flip_ap)
        var_si = tk.BooleanVar(value=self.flip_si)

        ttk.Checkbutton(win, text="Left/right axis (X)", variable=var_lr).pack(anchor="w", padx=20, pady=2)
        ttk.Checkbutton(win, text="Anterior/posterior axis (Y)", variable=var_ap).pack(anchor="w", padx=20, pady=2)
        ttk.Checkbutton(win, text="Superior/inferior axis (Z)", variable=var_si).pack(anchor="w", padx=20, pady=2)

        ttk.Button(
            win,
            text="Confirm",
            command=lambda: self._set_orientation(var_lr.get(), var_ap.get(), var_si.get(), win),
        ).pack(pady=10)

    def _set_orientation(self, lr: bool, ap: bool, si: bool, window: tk.Toplevel):
        """Guarda las preferencias de orientación."""
        self.flip_lr = lr
        self.flip_ap = ap
        self.flip_si = si
        window.destroy()
        axes = []
        if lr:
            axes.append('X')
        if ap:
            axes.append('Y')
        if si:
            axes.append('Z')
        self._log(f"🧭 Axis inversions enabled: {', '.join(axes) if axes else 'none'}")

        # Guardar configuración actualizada
        self._save_config()

    # ------------------------------------------------------------------
    # Alternar el uso del recorte foreground
    # ------------------------------------------------------------------
    def _toggle_crop(self):
        """Toggle the flag to enable or disable automatic body cropping."""
        self.use_crop = bool(self.use_crop_var.get())
        state = 'enabled' if self.use_crop else 'disabled'
        self._log(f"🔧 Automatic body cropping {state}")

        # Guardar configuración actualizada
        self._save_config()

    # ------------------------------------------------------------------
    # Alternar limpieza de máscaras
    # ------------------------------------------------------------------
    def _toggle_clean(self):
        """Toggle application of morphological operations on the output masks."""
        self.clean_masks = bool(self.clean_masks_var.get())
        state = 'enabled' if self.clean_masks else 'disabled'
        self._log(f"🧹 Mask cleaning {state}")

        # Guardar configuración actualizada
        self._save_config()

    # ------------------------------------------------------------------
    # Seleccionar dispositivo (CPU/GPU)
    # ------------------------------------------------------------------
    def _choose_device(self):
        """Allow the user to select between the CPU and any available GPUs."""
        win = tk.Toplevel(self)
        win.title("Select device")
        win.geometry("350x250")
        win.configure(bg=THEME_OPTIONS[self.style_name]['bg'])

        tk.Label(
            win,
            text="Select the device for inference:",
            bg=THEME_OPTIONS[self.style_name]['bg'],
            fg=THEME_OPTIONS[self.style_name]['fg'],
        ).pack(pady=10)

        # StringVar que almacena la selección actual.  Usamos nombres como
        # 'cpu' o 'cuda:0', 'cuda:1', etc.  Si ya hay un dispositivo
        # seleccionado, lo preseleccionamos.
        current = 'cpu'
        if isinstance(self.device, torch.device):
            current = str(self.device)
        elif isinstance(self.device, str):
            current = self.device

        var = tk.StringVar(value=current)

        # Opción para CPU siempre disponible
        ttk.Radiobutton(win, text="CPU", variable=var, value='cpu').pack(anchor="w", padx=20, pady=2)

        # Opciones para GPUs, si están disponibles
        if torch.cuda.is_available():
            count = torch.cuda.device_count()
            for i in range(count):
                try:
                    name = torch.cuda.get_device_name(i)
                except Exception:
                    name = f"GPU {i}"
                value = f"cuda:{i}"
                ttk.Radiobutton(
                    win,
                    text=f"GPU {i}: {name}",
                    variable=var,
                    value=value
                ).pack(anchor="w", padx=20, pady=2)
        else:
            # Indicate that no GPU is available
            tk.Label(
                win,
                text="No GPUs detected.",
                bg=THEME_OPTIONS[self.style_name]['bg'],
                fg=THEME_OPTIONS[self.style_name]['fg'],
            ).pack(pady=5)

        ttk.Button(
            win,
            text="Confirm",
            command=lambda: self._set_device(var.get(), win),
        ).pack(pady=15)

    def _set_device(self, value: str, window: tk.Toplevel):
        """Establece el dispositivo seleccionado y mueve el modelo si es necesario."""
        try:
            # Crear objeto torch.device a partir de la selección
            new_device = torch.device(value)
            # Si el dispositivo no está disponible, se mantendrá el actual
            if new_device.type == 'cuda' and not torch.cuda.is_available():
                messagebox.showerror("Error", "No GPU is available for selection.")
                window.destroy()
                return
            self.device = new_device
            # Mover el modelo cargado, si existe
            if self.model is not None:
                try:
                    self.model = self.model.to(self.device)
                except Exception as e:
                    # Warn if the model could not be moved to the selected device
                    self._log(f"⚠ Could not move the model to the new device: {e}")
            # Registrar selección y establecer device_preference para TotalSegmentator
            if self.device.type == 'cuda':
                # Extract index and report
                idx = 0
                try:
                    idx = int(str(self.device).split(':')[1])
                    name = torch.cuda.get_device_name(idx)
                    self._log(f"🔧 Device selected: GPU {idx} ({name})")
                except Exception:
                    self._log(f"🔧 Device selected: {self.device}")
                # For TotalSegmentator use 'gpu' if at least one GPU is present
                self.device_preference = 'gpu'
            else:
                self._log("🔧 Device selected: CPU")
                self.device_preference = 'cpu'

            # Save the updated configuration
            self._save_config()
        except Exception as e:
            # Catch any error that occurs during device selection
            self._log(f"❌ Error selecting device: {e}")
        finally:
            # Always destroy the selection window
            window.destroy()

    # ------------------------------------------------------------------
    # Ajustar margen de recorte
    # ------------------------------------------------------------------
    def _choose_crop_margin(self):
        """Display a window to adjust the crop margin in voxels."""
        win = tk.Toplevel(self)
        win.title("Adjust crop margin")
        win.geometry("300x180")
        win.configure(bg=THEME_OPTIONS[self.style_name]['bg'])
        tk.Label(
            win,
            text="Specify the crop margin (voxels):",
            bg=THEME_OPTIONS[self.style_name]['bg'],
            fg=THEME_OPTIONS[self.style_name]['fg'],
        ).pack(pady=10)
        # Utilizamos un IntVar para el margen
        margin_var = tk.IntVar(value=self.crop_margin)
        spin = tk.Spinbox(win, from_=0, to=100, textvariable=margin_var, width=5)
        spin.pack(pady=5)
        ttk.Button(
            win,
            text="Confirm",
            command=lambda: self._set_crop_margin(margin_var.get(), win),
        ).pack(pady=10)

    def _set_crop_margin(self, value: int, window: tk.Toplevel):
        """Establece un nuevo margen de recorte para el foreground."""
        try:
            v = int(value)
            if v < 0:
                raise ValueError("The margin must be a non‑negative number")
            self.crop_margin = v
            self._log(f"🔧 Crop margin adjusted to {v} voxels")
            # Guardar configuración actualizada
            self._save_config()
        except Exception as e:
            messagebox.showerror("Error", f"Could not adjust the margin: {e}")
        finally:
            window.destroy()

    # ------------------------------------------------------------------
    # Seleccionar tipo de modelo
    # ------------------------------------------------------------------
    def _choose_model_type(self):
        """Muestra una ventana para seleccionar entre SegResNet y TotalSegmentator.

        Al cambiar el tipo de modelo se actualiza ``self.model_type``, se
        invalidan los pesos actuales y se lanza la carga del nuevo
        modelo (o la preparación de TotalSegmentator) en un hilo
        separado.
        """
        win = tk.Toplevel(self)
        win.title("Tipo de modelo")
        win.geometry("350x180")

        var = tk.StringVar(value=self.model_type)
        options = [
            ("SegResNet (MONAI)", "segresnet"),
            ("TotalSegmentator V2", "totalseg"),
        ]

        ttk.Label(win, text="Selecciona el tipo de modelo:").pack(anchor="w", padx=10, pady=(10, 5))
        for text, value in options:
            ttk.Radiobutton(win, text=text, variable=var, value=value).pack(anchor="w", padx=20, pady=2)

        def confirm():
            new_type = var.get()
            if new_type != self.model_type:
                self.model_type = new_type
                # Registrar en el log
                if self.model_type == "segresnet":
                    self._log("🔧 Tipo de modelo seleccionado: SegResNet (MONAI)")
                else:
                    self._log("🔧 Tipo de modelo seleccionado: TotalSegmentator V2")
                # Reiniciar estado del modelo
                self.ready = False
                self.model = None
                # Cargar o preparar el modelo en nuevo hilo
                self._load_model_thread()
            win.destroy()

        ttk.Button(win, text="Confirmar", command=confirm).pack(pady=15)

    # ------------------------------------------------------------------
    # Browse
    # ------------------------------------------------------------------
    def _browse(self, entry: tk.Entry):
        path = filedialog.askdirectory()
        if path:
            entry.delete(0, tk.END)
            entry.insert(0, path)
            # Guardar configuración actualizada
            self._save_config()

    # ------------------------------------------------------------------
    # Transforms bundle con parámetros adaptativos
    # ------------------------------------------------------------------
    def _build_transforms_adaptive(self, reader: str, original_spacing=None, target_pixdim=None):
        """
        Construye transformaciones adaptativas que intentan diferentes parámetros
        hasta encontrar una configuración que funcione correctamente.
        """
        if target_pixdim is None:
            target_pixdim = (1.5, 1.5, 1.5) if self.highres else (3.0, 3.0, 3.0)
        
        # Lista de configuraciones a probar, de más conservadora a más agresiva
        spacing_configs = [
            # Configuración original
            {"pixdim": target_pixdim, "mode": "bilinear"},
            # Sin resampling espacial si el original está cerca
            {"pixdim": None, "mode": None},
            # Resampling más conservador
            {"pixdim": (2.0, 2.0, 2.0), "mode": "bilinear"},
            # Solo resamplear en plano axial
            {"pixdim": (original_spacing[0] if original_spacing else 2.0, 2.0, 2.0), "mode": "bilinear"},
        ]
        
        for i, config in enumerate(spacing_configs):
            try:
                # Report which spacing configuration is being tested
                self._log(f"🔄 Trying spacing configuration {i+1}/{len(spacing_configs)}: {config}")
                
                transforms_list = [
                    LoadImaged(keys="image", reader=reader, meta=True),
                    EnsureTyped(keys="image"),
                ]
                
                # Orientación siempre necesaria
                transforms_list.append(Orientationd(keys="image", axcodes="RAS"))
                
                # Crop foreground opcional para reducir el volumen.  Añadimos
                # margen para asegurar que se mantenga contexto alrededor del
                # cuerpo, y permitimos que el recorte sea menor que el
                # volumen original si es necesario.
                if self.use_crop:
                    transforms_list.append(
                        CropForegroundd(
                            keys="image", source_key="image",
                            margin=self.crop_margin, allow_smaller=True
                        )
                    )
                
                # Spacing solo si está configurado.  Aplicamos límites mínimos y máximos
                # al tamaño de voxel para evitar sobre/submuestreo excesivo.  Los
                # valores de min_pixdim y max_pixdim son ±25 % del valor de pixdim,
                # siguiendo la práctica de MONAI Auto3DSeg.
                if config["pixdim"] is not None:
                    pixdim = config["pixdim"]
                    # calcular límites para spacing
                    try:
                        min_pixdim = tuple(float(p) * 0.75 for p in pixdim)
                        max_pixdim = tuple(float(p) * 1.25 for p in pixdim)
                    except Exception:
                        # en caso de que pixdim no sea iterable (ninguno o float)
                        min_pixdim = None
                        max_pixdim = None
                    transforms_list.append(
                        Spacingd(
                            keys="image",
                            pixdim=pixdim,
                            mode=config["mode"],
                            min_pixdim=min_pixdim,
                            max_pixdim=max_pixdim,
                        )
                    )
                
                # Normalización de intensidad.  Para CT es habitual recortar a
                # [-1000, 2000] para cubrir desde el aire hasta el hueso,
                # mapeando luego a [0, 1].  Esto proporciona un rango más
                # amplio que el uso anterior de [-1000, 1000] y puede ayudar
                # a preservar estructuras óseas.
                transforms_list.extend([
                    ScaleIntensityRanged(
                        keys="image",
                        a_min=-1000.0,
                        a_max=2000.0,
                        b_min=0.0,
                        b_max=1.0,
                        clip=True,
                    ),
                    ToTensord(keys="image"),
                ])
                
                self.pre_transforms = Compose(transforms_list)
                
                # Post-transforms correspondientes
                if config["pixdim"] is not None:
                    # Siempre usar Invertd para revertir orientación y recorte,
                    # además de las transformaciones espaciales.
                    self.post_transforms = Compose(
                        [
                            Activationsd(keys="pred", sigmoid=True),
                            AsDiscreted(keys="pred", threshold=0.5),
                            Invertd(
                                keys="pred",
                                transform=self.pre_transforms,
                                orig_keys="image",
                                nearest_interp=True,
                                to_tensor=False,
                            ),
                            EnsureTyped(keys="pred"),
                            ToNumpyd(keys="pred"),
                        ]
                    )
                else:
                    # Aunque no haya resampling, se debe invertir para
                    # restaurar la orientación y deshacer el recorte del
                    # foreground.  Se omite la activación porque el modelo
                    # retorna índices de clase directamente.
                    self.post_transforms = Compose(
                        [
                            Invertd(
                                keys="pred",
                                transform=self.pre_transforms,
                                orig_keys="image",
                                nearest_interp=True,
                                to_tensor=False,
                            ),
                            EnsureTyped(keys="pred"),
                            ToNumpyd(keys="pred"),
                        ]
                    )
                
                self._log(f"✔ Configuration {i+1} prepared successfully")
                return self.pre_transforms, config
                
            except Exception as e:
                self._log(f"⚠ Configuration {i+1} failed: {e}")
                continue
        
        # If all configurations fail, use minimal transforms
        self._log("⚠ All configurations failed, using minimal transforms")
        self.pre_transforms = Compose([
            LoadImaged(keys="image", reader=reader, meta=True),
            EnsureTyped(keys="image"),
            ScaleIntensityRanged(keys="image", a_min=-1000, a_max=1000,
                                b_min=0.0, b_max=1.0, clip=True),
            ToTensord(keys="image"),
        ])
        self.post_transforms = None
        return self.pre_transforms, {"pixdim": None, "mode": None}

    # ------------------------------------------------------------------
    # Carga de modelo
    # ------------------------------------------------------------------
    def _load_model_thread(self):
        self._indeterminate(True)
        threading.Thread(target=self._load_model, daemon=True).start()

    def _load_model(self):
        # Restablecer estado y deshabilitar botones durante la carga
        self.ready = False
        self.btn_one["state"] = self.btn_all["state"] = "disabled"

        # Show an appropriate message
        if self.model_type == "segresnet":
            self._log("⏳ Loading network and weights (SegResNet)...")
        else:
            self._log("⏳ Preparing TotalSegmentator V2...")

        # ----- TotalSegmentator -----
        if self.model_type == "totalseg":
            # Asignar etiquetas y órganos desde el diccionario de TOTALSEG
            self._update_totalseg_labels()
            self.model = None
            # Verificar que la biblioteca esté disponible.  Preferir la versión v2.
            success = False
            try:
                try:
                    # Attempt to import v2 first
                    from totalsegmentatorv2.python_api import totalsegmentator  # noqa: F401, type: ignore
                except ImportError:
                    # Fall back to legacy package name
                    from totalsegmentator.python_api import totalsegmentator  # noqa: F401, type: ignore
                success = True
            except Exception as e:
                self._log(
                    f"❌ TotalSegmentator not available: {e}. Install 'totalsegmentatorv2' or 'totalsegmentator' with pip."
                )

            if success:
                self._log("✔ TotalSegmentator imported successfully")
                self._log(
                    "ℹ The weights will be downloaded automatically the first time segmentation runs"
                )
                self.ready = True
                self.btn_one["state"] = self.btn_all["state"] = "normal"
            else:
                self.ready = False

            # Finalizar barra de progreso
            self._indeterminate(False)
            return

        # ----- SegResNet -----
        try:
            # Cargar metadatos para mapear canales a órganos
            try:
                with open(META_JSON) as f:
                    meta = json.load(f)
                chdef = (
                    meta.get("network_data_format", {})
                    .get("outputs", {})
                    .get("pred", {})
                    .get("channel_def", {})
                )
                labels = {v: int(k) for k, v in chdef.items() if k != "0"}
                self._log(f" ✔ {len(labels)} organs loaded from metadata.json")
            except Exception as e:
                self._log(f"⚠ Could not read metadata ({e}); using default values")
                labels = FULL_LABELS.copy()

            # Asegurar que todas las etiquetas posibles estén presentes
            for k, v in FULL_LABELS.items():
                labels.setdefault(k, v)
            self.labels_map = labels
            self._apply_saved_organs()
            num_classes = max(labels.values()) + 1

            # Seleccionar pesos según la resolución
            weights_path = WEIGHTS_HIGHRES if self.highres else WEIGHTS_LOWRES
            if not os.path.exists(weights_path):
                raise FileNotFoundError(f"Weights file not found: {weights_path}")

            self._log(
                f"🔄 Loading weights for {'1.5 mm' if self.highres else '3 mm'}: {os.path.basename(weights_path)}"
            )
            obj = torch.load(weights_path, map_location=self.device)
            if isinstance(obj, torch.nn.Module):
                self.model = obj.to(self.device).eval()
            else:
                state_dict = obj.get("state_dict", obj)
                self.model = SegResNet(
                    spatial_dims=3,
                    in_channels=1,
                    out_channels=num_classes,
                    init_filters=32,
                    blocks_down=(1, 2, 2, 4),
                    blocks_up=(1, 1, 1),
                ).to(self.device)
                self.model.load_state_dict(state_dict)

            self.model.eval()
            self._log(f" ✔ SegResNet model loaded correctly on {self.device}")
            self.ready = True
            self.btn_one["state"] = self.btn_all["state"] = "normal"

        except Exception as e:
            # Translate error when loading the SegResNet model
            self._log(f"❌ Error loading model: {e}")
            self._log(traceback.format_exc())
            self.ready = False
        finally:
            # Stop the indeterminate progress bar when loading completes
            self._indeterminate(False)
    
    # ------------------------------------------------------------------
    # Selección de órganos
    # ------------------------------------------------------------------
    def _select_organs(self):
        if not self.ready:
            messagebox.showerror("Error", "Please load the model first.")
            return

        win = tk.Toplevel(self)
        win.title("Select organs")
        win.geometry("400x500")

        control_frame = ttk.Frame(win)
        control_frame.pack(fill="x", padx=10, pady=10)

        control_frame.columnconfigure(0, weight=0)
        control_frame.columnconfigure(1, weight=1)

        vars_chk: dict[str, tk.BooleanVar] = {}
        available_tasks: list[str] = []
        task_var = tk.StringVar(value=self.totalseg_task)

        def select_all() -> None:
            for var in vars_chk.values():
                var.set(True)

        def clear_all() -> None:
            for var in vars_chk.values():
                var.set(False)

        def rebuild_checkboxes() -> None:
            nonlocal vars_chk
            for child in frame.winfo_children():
                child.destroy()
            vars_chk = {}
            for organ in sorted(self.labels_map):
                var = tk.BooleanVar(value=(organ in self.organs))
                vars_chk[organ] = var
                ttk.Checkbutton(frame, text=organ, variable=var).pack(anchor="w", padx=10, pady=2)
            ttk.Button(
                frame,
                text="Confirm",
                command=lambda: (self._set_organs(vars_chk), win.destroy()),
            ).pack(pady=10)

        def handle_task_change(new_task: str) -> None:
            if not new_task or new_task == self.totalseg_task:
                return
            if new_task not in TOTALSEG_TASK_LABELS:
                messagebox.showwarning("Warning", f"Task '{new_task}' is not available.")
                return
            self._store_current_selection()
            self.totalseg_task = new_task
            self._update_totalseg_labels()
            rebuild_checkboxes()
            task_var.set(self.totalseg_task)
            self._save_config()

        if self.model_type == "totalseg":
            ordered_tasks = [k for k in TOTALSEG_TASK_KEYS if TOTALSEG_TASK_LABELS.get(k)]
            extra_tasks = [k for k in TOTALSEG_TASK_LABELS.keys() if TOTALSEG_TASK_LABELS.get(k) and k not in ordered_tasks]
            available_tasks = ordered_tasks + extra_tasks
            if task_var.get() not in available_tasks:
                if "complete" in available_tasks:
                    fallback_task = "complete"
                elif "total" in available_tasks:
                    fallback_task = "total"
                elif available_tasks:
                    fallback_task = available_tasks[0]
                else:
                    fallback_task = "total"
                task_var.set(fallback_task)
                self.totalseg_task = fallback_task
                self._update_totalseg_labels()
            ttk.Label(control_frame, text="Task:").grid(row=0, column=0, sticky="w")
            task_combo = ttk.Combobox(
                control_frame,
                textvariable=task_var,
                values=available_tasks,
                state="readonly",
                width=22,
            )
            task_combo.grid(row=0, column=1, sticky="ew", padx=(5, 10))
            task_combo.bind("<<ComboboxSelected>>", lambda _event: handle_task_change(task_var.get()))
        ttk.Button(control_frame, text="Select all", command=select_all).grid(row=1, column=0, pady=5, sticky="w")
        ttk.Button(control_frame, text="Clear all", command=clear_all).grid(row=1, column=1, pady=5, sticky="w")

        canvas = tk.Canvas(win)
        scrollbar = ttk.Scrollbar(win, orient="vertical", command=canvas.yview)
        canvas.configure(yscrollcommand=scrollbar.set)
        scrollbar.pack(side="right", fill="y")
        canvas.pack(side="left", fill="both", expand=True, padx=(10, 0), pady=(0, 10))

        frame = ttk.Frame(canvas)
        canvas.create_window((0, 0), window=frame, anchor="nw")

        frame.bind("<Configure>", lambda _event: canvas.configure(scrollregion=canvas.bbox("all")))

        def _on_mousewheel(event):
            delta = 0
            if getattr(event, 'delta', 0):
                delta = -int(event.delta / 120)
            elif getattr(event, 'num', None) == 4:
                delta = -1
            elif getattr(event, 'num', None) == 5:
                delta = 1
            if delta:
                canvas.yview_scroll(delta, "units")

        def _bind_mousewheel(_event):
            canvas.bind_all("<MouseWheel>", _on_mousewheel)
            canvas.bind_all("<Button-4>", _on_mousewheel)
            canvas.bind_all("<Button-5>", _on_mousewheel)

        def _unbind_mousewheel(_event):
            canvas.unbind_all("<MouseWheel>")
            canvas.unbind_all("<Button-4>")
            canvas.unbind_all("<Button-5>")

        canvas.bind("<Enter>", _bind_mousewheel)
        canvas.bind("<Leave>", _unbind_mousewheel)
        win.bind("<Destroy>", _unbind_mousewheel)

        rebuild_checkboxes()

    def _set_organs(self, vars_chk):
        self.organs = [o for o, v in vars_chk.items() if v.get()]
        self._store_current_selection()
        self._save_config()
        self._log(f"🔖 Selected organs: {', '.join(self.organs)}")

    # ------------------------------------------------------------------
    # Thread wrappers
    # ------------------------------------------------------------------
    def _run_all_thread(self):
        if not self._validate_paths():
            return
        self._indeterminate(True)
        threading.Thread(target=self._thread_wrapper, args=(self._process_all,), daemon=True).start()

    def _run_one_thread(self):
        if not self._validate_paths():
            return
        self._indeterminate(True)
        threading.Thread(target=self._thread_wrapper, args=(self._process_one,), daemon=True).start()

    def _thread_wrapper(self, func):
        try:
            func()
        except Exception as e:  # pragma: no cover
            self._log(f"❌ Error en hilo de procesamiento: {str(e)}")
            self._log(traceback.format_exc())
        finally:
            self.after(0, self._indeterminate, False)

    # ------------------------------------------------------------------
    # Validación de paths
    # ------------------------------------------------------------------
    def _validate_paths(self):
        folder = self.in_entry.get().strip()
        outdir = self.out_entry.get().strip()

        if not folder or not outdir:
            messagebox.showerror("Error", "Please select input and output folders.")
            return False

        if not os.path.isdir(folder):
            messagebox.showerror("Error", f"The input folder does not exist:\n{folder}")
            return False

        if not os.path.isdir(outdir):
            try:
                os.makedirs(outdir, exist_ok=True)
            except Exception as e:
                messagebox.showerror("Error", f"Could not create the output folder:\n{outdir}\nError: {e}")
                return False
        return True

    # ------------------------------------------------------------------
    # Progreso
    # ------------------------------------------------------------------
    def _indeterminate(self, start: bool):
        """
        Start or stop the indeterminate progress bar.

        This helper wraps calls to the Tk progress widget in a try/except
        to avoid crashing if the underlying Tk widgets have already been
        destroyed (for example, after the user closes the main window).
        """
        try:
            if start:
                # Switch to indeterminate mode and start the animation
                self.progress.configure(mode="indeterminate")
                self.progress.start()
            else:
                # Stop the animation and reset back to determinate mode
                self.progress.stop()
                self.progress.configure(mode="determinate", value=0)
        except tk.TclError:
            # If the widget no longer exists (application has been closed),
            # silently ignore the error instead of crashing.  This prevents
            # the "can't invoke winfo" exception seen in crash logs.
            pass

    # ------------------------------------------------------------------
    # Leer nombre paciente
    # ------------------------------------------------------------------
    def _dicom_name(self, folder: str) -> str:
        """Attempt to extract a human–readable patient name from DICOM files.

        This method walks the input folder looking for a DICOM slice.  In
        earlier versions only files ending in ``.dcm`` were considered,
        which excluded valid DICOM files with non‑standard or missing
        extensions (for example files named ``IM1``).  To improve
        robustness the search now also includes any file that appears to
        be a DICOM according to :func:`looks_like_dicom`.  Once a valid
        file is found we read its header with ``pydicom.dcmread`` and
        return the patient family name, if present, or the raw value of
        the ``PatientName`` tag.  If no valid slice is found the
        string ``"Patient"`` is returned.
        """
        for root, _, files in os.walk(folder):
            for f in files:
                # Only consider files that either use the standard .dcm
                # extension or appear to be DICOM when inspected.  Using
                # looks_like_dicom allows us to handle datasets like
                # Siemens where slices are named IM0, IM1, etc.
                full_path = os.path.join(root, f)
                if not (f.lower().endswith(".dcm") or looks_like_dicom(full_path)):
                    continue
                try:
                    ds = pydicom.dcmread(full_path, stop_before_pixels=True)
                    pn = ds.get("PatientName", "")
                    # Prefer the family name attribute when available
                    return str(getattr(pn, "family_name", pn)) or "Paciente"
                except Exception:
                    continue
        return "Patient"

    # ------------------------------------------------------------------
    # Recolectar serie CT
    # ------------------------------------------------------------------
    def _collect_ct_series(self, folder: str):
        """Collect a continuous CT series from a directory of DICOM files.

        Only slices belonging to the largest CT series (identified by
        ``SeriesInstanceUID``) are returned.  Historically this method
        filtered exclusively on filenames ending in ``.dcm``.  To allow
        processing of DICOM datasets without a file extension we now
        inspect every file and skip it only when it neither ends with
        ``.dcm`` nor looks like a DICOM slice according to
        :func:`looks_like_dicom`.  For each candidate file we read a
        minimal header (Modality, SeriesInstanceUID, InstanceNumber) to
        identify CT modality and grouping.  If no CT slices are found an
        exception is raised.  The returned list is sorted by the
        instance number.
        """
        series = defaultdict(list)
        for root, _, files in os.walk(folder):
            for f in files:
                full_path = os.path.join(root, f)
                # Skip non‑DICOM files quickly by checking extension and
                # heuristic; this avoids attempting to read arbitrary data
                # with pydicom.
                if not (f.lower().endswith(".dcm") or looks_like_dicom(full_path)):
                    continue
                try:
                    ds = pydicom.dcmread(full_path, stop_before_pixels=True,
                                         specific_tags=["Modality", "SeriesInstanceUID", "InstanceNumber"])
                    if getattr(ds, 'Modality', None) != "CT":
                        continue
                    # Use instance number to sort slices; missing values
                    # default to zero.
                    inst_num = int(ds.get("InstanceNumber", 0))
                    series[str(ds.SeriesInstanceUID)].append((inst_num, full_path))
                except Exception as e:
                    # Warn if reading a file believed to be DICOM fails; this
                    # may indicate a corrupt slice but should not abort
                    self._log(f"⚠ Error reading {full_path}: {e}")
                    continue

        if not series:
            raise RuntimeError("No CT images were found in the folder")

        best_uid = max(series, key=lambda k: len(series[k]))
        files = [path for (inst, path) in sorted(series[best_uid], key=lambda x: x[0])]
        self._log(f"ℹ Selected CT series: {best_uid} ({len(files)} slices)")
        return files

    # ------------------------------------------------------------------
    # Lectura manual mejorada (fallback)
    # ------------------------------------------------------------------
    def _manual_volume(self, files):
        """Construye volumen y meta dict manual cuando fallan lectores MONAI."""
        self._log(f"⚙ Starting manual reading of {len(files)} slices...")
        good_slices = []
        headers = []

        for i, pth in enumerate(files, 1):
            try:
                ds = pydicom.dcmread(pth)
                if not hasattr(ds, "PixelData"):
                    self._log(f"   ⚠ Slice {i}/{len(files)} has no PixelData, skipping")
                    continue

                arr = ds.pixel_array.astype(np.int16)

                slope = float(ds.get("RescaleSlope", 1))
                intercept = float(ds.get("RescaleIntercept", 0))
                hu = arr * slope + intercept

                good_slices.append(hu)
                headers.append(ds)

                if i % 20 == 0 or i == len(files):
                    self._log(f"   ✔ Processed {i}/{len(files)} slices")
            except Exception as e:
                self._log(f"   ⚠ Error in slice {i}/{len(files)}: {e}")

        if len(good_slices) < 10:
            raise RuntimeError("Too many damaged slices to build volume")

        # Volumen numpy (Z, Y, X)
        vol = np.stack(good_slices, axis=0).astype(np.float32)

        # Canal (C, Z, Y, X)
        vol = vol[np.newaxis, ...]  # C=1
        tensor_vol = torch.from_numpy(vol)

        # Matriz afín aproximada
        first_ds = headers[0]
        last_ds = headers[-1]

        pixel_spacing = [float(x) for x in first_ds.PixelSpacing]  # [row, col] = [Y, X]
        
        # Espacio entre cortes: usar SliceThickness si está; si no, derivar de ImagePositionPatient
        try:
            slice_thickness = float(first_ds.SliceThickness)
        except Exception:
            try:
                pos_first = np.array(first_ds.ImagePositionPatient, dtype=float)
                pos_last = np.array(last_ds.ImagePositionPatient, dtype=float)
                slice_thickness = np.linalg.norm(pos_last - pos_first) / max(len(headers) - 1, 1)
            except Exception:
                slice_thickness = 5.0  # fallback por defecto

        row_vec = np.array(first_ds.ImageOrientationPatient[0:3], dtype=float)
        col_vec = np.array(first_ds.ImageOrientationPatient[3:6], dtype=float)
        slice_vec = np.cross(row_vec, col_vec)

        affine = np.eye(4, dtype=float)
        # columnas del afín: X, Y, Z en espacio físico
        affine[0:3, 0] = row_vec * pixel_spacing[1]  # X
        affine[0:3, 1] = col_vec * pixel_spacing[0]  # Y
        affine[0:3, 2] = slice_vec * slice_thickness  # Z
        affine[0:3, 3] = np.array(first_ds.ImagePositionPatient, dtype=float)  # origen

        spacing = [slice_thickness, pixel_spacing[0], pixel_spacing[1]]  # (Z, Y, X) como data

        meta_dict = {
            "original_affine": affine.copy(),
            "affine": affine.copy(),
            "spatial_shape": vol.shape[1:],  # (Z, Y, X)
            "original_channel_dim": "no_channel",
            "filename_or_obj": files[0],
            "space": "physical",
            "original_spacing": spacing,
            "spacing": spacing,
            "original_orientation": first_ds.ImageOrientationPatient,
        }

        # Summarize manual volume reading results in English
        self._log(f"✔ Manual volume reading complete: {len(good_slices)} slices, volume {vol.shape}")
        self._log(f"✔ Detected spacing: {spacing}")
        self._log("✔ Affine matrix manually reconstructed")

        meta_tensor_vol = MetaTensor(vol, affine=affine, meta=meta_dict)
        return tensor_vol, meta_dict, meta_tensor_vol, spacing

    # ------------------------------------------------------------------
    def _should_append_body_task(self) -> bool:
        """Return True when the current TotalSegmentator task should include body masks."""
        task = getattr(self, "totalseg_task", "")
        if not task:
            return False
        if task in {"complete", "total", "body", "body_mr"}:
            return False
        if task.endswith("_mr"):
            return False
        return "body" in TOTALSEG_TASK_LABELS and bool(TOTALSEG_TASK_LABELS.get("body"))

    # Segmentación con transformaciones adaptativas
    # ------------------------------------------------------------------
    def _segment_from_files(self, series_files):
        # Si el tipo de modelo es TotalSegmentator, delegamos en el método
        # especializado y omitimos las transformaciones adaptativas.  Esto
        # simplifica el flujo, ya que TotalSegmentator gestiona su propio
        # preprocesamiento y no utiliza Sliding-Window.  La función
        # devuelve un diccionario con máscaras binarias por órgano.
        if self.model_type == "totalseg":
            return self._segment_totalseg(series_files)

        using_pre = False
        sample = None
        meta = None
        original_spacing = None
        applied_config = None

        # Detect the original spacing of the first DICOM slice
        try:
            first_ds = pydicom.dcmread(series_files[0], stop_before_pixels=True)
            pixel_spacing = [float(x) for x in first_ds.PixelSpacing]
            try:
                slice_thickness = float(first_ds.SliceThickness)
            except:
                slice_thickness = 5.0
            original_spacing = [slice_thickness, pixel_spacing[0], pixel_spacing[1]]
            # Log the detected original spacing (Z, Y, X)
            self._log(f"📏 Detected original spacing: {original_spacing}")
        except Exception as e:
            # Warn if we could not detect the original spacing
            self._log(f"⚠ Could not detect original spacing: {e}")

        # Try standard readers with adaptive configurations
        for reader in ("PydicomReader", "ITKReader"):
            try:
                self._log(f"🔄 Trying {reader}...")
                transforms, config = self._build_transforms_adaptive(reader, original_spacing)
                applied_config = config
                
                sample = transforms({"image": series_files})
                img = sample["image"].unsqueeze(0).to(self.device)  # añadir batch
                meta = sample["image_meta_dict"]
                
                self._log(f"✔ {reader} successful with configuration: {config}")
                using_pre = True
                break
                
            except Exception as e:
                self._log(f"⚠ {reader} failed: {e}")
                continue

        # Fallback to improved manual mode if all readers fail
        if not using_pre:
            self._log("⚠ All readers failed; starting adaptive manual mode...")
            tensor_vol, meta_dict, meta_tensor_vol, detected_spacing = self._manual_volume(series_files)
            original_spacing = detected_spacing

            # Diccionario inicial para modo manual
            sample = {
                "image": meta_tensor_vol,
                "image_meta_dict": meta_dict,
            }

            # Probar diferentes configuraciones para el modo manual
            manual_configs = [
                # Sin resampling espacial - mantener original
                {"apply_spacing": False, "pixdim": None},
                # Resampling conservador
                {"apply_spacing": True, "pixdim": (3.0, 3.0, 3.0)},
                # Solo si la diferencia es muy grande
                {"apply_spacing": True, "pixdim": (2.0, 2.0, 2.0)},
            ]

            for i, config in enumerate(manual_configs):
                try:
                    # Report which manual configuration is being tested
                    self._log(f"🔄 Trying manual configuration {i+1}/{len(manual_configs)}: {config}")
                    
                    transforms_list = []
                    
                    # Orientación básica
                    transforms_list.append(Orientationd(keys="image", axcodes="RAS"))

                    # Crop foreground opcional.  Aplicamos margen para conservar
                    # contexto y permitimos que el recorte sea más pequeño que
                    # el volumen original si es necesario.
                    if self.use_crop:
                        transforms_list.append(
                            CropForegroundd(
                                keys="image",
                                source_key="image",
                                margin=self.crop_margin,
                                allow_smaller=True,
                            )
                        )
                    
                    # Spacing solo si está habilitado.  Cuando se aplica
                    # resampling, establecemos límites min/max alrededor del
                    # target_spacing para evitar sobre/submuestreo excesivo
                    if config["apply_spacing"] and config["pixdim"]:
                        # Verificar si realmente necesitamos cambiar el spacing
                        current_spacing = original_spacing
                        target_spacing = config["pixdim"]

                        spacing_diff = max(
                            [abs(current_spacing[i] - target_spacing[i]) / current_spacing[i] for i in range(3)]
                        )

                        if spacing_diff > 0.5:  # Solo si la diferencia es >50%
                            # calcular límites min/max
                            try:
                                min_pixdim = tuple(float(p) * 0.75 for p in target_spacing)
                                max_pixdim = tuple(float(p) * 1.25 for p in target_spacing)
                            except Exception:
                                min_pixdim = None
                                max_pixdim = None
                            transforms_list.append(
                                Spacingd(
                                    keys="image",
                                    pixdim=target_spacing,
                                    mode="bilinear",
                                    min_pixdim=min_pixdim,
                                    max_pixdim=max_pixdim,
                                )
                            )
                            self._log(
                                f"   📏 Applying resampling: {current_spacing} → {target_spacing} (min={min_pixdim}, max={max_pixdim})"
                            )
                        else:
                            self._log(
                                f"   📏 Spacing similar, skipping resampling (diff: {spacing_diff:.2f})"
                            )
                    
                    # Normalización de intensidad.  Para CT utilizamos un
                    # rango amplio [-1000, 2000] para capturar tejidos blandos
                    # y óseos.  Ajustamos a [0, 1] y limitamos valores fuera
                    # del rango.
                    transforms_list.extend(
                        [
                            ScaleIntensityRanged(
                                keys="image",
                                a_min=-1000.0,
                                a_max=2000.0,
                                b_min=0.0,
                                b_max=1.0,
                                clip=True,
                            ),
                            ToTensord(keys="image"),
                        ]
                    )

                    self.pre_transforms = Compose(transforms_list)
                    
                    # Siempre aplicamos Invertd para revertir orientación y
                    # recorte; si además hay resampling, Invertd también
                    # restaurará el spacing original.  Usamos los mismos
                    # argumentos independientemente de apply_spacing.
                    self.post_transforms = Invertd(
                        keys="pred",
                        transform=self.pre_transforms,
                        orig_keys="image",
                        meta_key_postfix="meta_dict",
                        nearest_interp=True,
                        to_tensor=False,
                    )
                    
                    # Aplicar transformaciones
                    sample = self.pre_transforms(sample)
                    img = sample["image"].unsqueeze(0).to(self.device)
                    meta = sample["image_meta_dict"]
                    
                    self._log(f"✔ Manual configuration {i+1} successful")
                    applied_config = config
                    break
                    
                except Exception as e:
                    self._log(f"⚠ Manual configuration {i+1} failed: {e}")
                    continue
            
            if applied_config is None:
                raise RuntimeError("Todas las configuraciones de transformación fallaron")

        # Inference
        self._log("⏳ Running sliding-window inference...")
        self._log(f"📊 Input tensor shape: {img.shape}")
        
        with torch.no_grad():
            # Utilizamos un tamaño de ventana deslizante más grande (64^3) para
            # capturar estructuras anatómicas de mayor tamaño.  Esto se alinea
            # con las recetas de Auto3DSeg donde se emplean ventanas de 96x96x96
            # o mayores para volumetrías de cuerpo entero.  Ajusta este valor
            # según la memoria disponible.  El superposición se mantiene al
            # 50 % para suavizar las transiciones.
            logits = sliding_window_inference(
                img,
                roi_size=(64, 64, 64),
                sw_batch_size=1,
                predictor=self.model,
                overlap=0.5,
            )
        self._log("✔ Inference completed")

        pred = torch.argmax(logits, dim=1).cpu().numpy()[0]
        self._log(f"📊 Initial prediction shape: {pred.shape}")

        # Almacenar forma original del volumen para referencia
        if using_pre:
            # Recuperar forma original de la metadata
            try:
                original_shape = meta.get("spatial_shape", tensor_vol.shape[1:] if 'tensor_vol' in locals() else None)
            except:
                original_shape = None
        else:
            original_shape = tensor_vol.shape[1:]  # (Z, Y, X)

        # Apply inverse transformation and smart resizing if necessary
        if self.post_transforms is not None:
            try:
                self._log("🔄 Applying inverse transformation...")
                d_in = {
                    "pred": pred[np.newaxis, ...],        # (C=1, Z, Y, X)
                    "image": sample["image"],             # tensor post-pre
                    "image_meta_dict": meta,              # meta post-pre
                    "pred_meta_dict": deepcopy(meta),     # requerido por Invertd
                }
                inv = self.post_transforms(d_in)
                pred = np.asarray(inv["pred"][0])  # quitar canal
                self._log(f"✔ Inverse transformation applied, new shape: {pred.shape}")
            except Exception as e:
                self._log(f"⚠ Inverse transformation failed: {e}")
                self._log("🔧 Trying smart resizing...")
                
                if original_shape is not None:
                    pred = smart_resize_prediction(pred, original_shape)
                    self._log(f"✔ Smart resizing applied: {pred.shape}")
        else:
            # No inverse transformation, check if smart resizing is needed
            if original_shape is not None and pred.shape != original_shape:
                self._log(f"🔧 No inverse transformation, applying smart resizing...")
                pred = smart_resize_prediction(pred, original_shape)

        # Apply axis inversions according to user configuration
        try:
            if self.flip_si:
                pred = np.flip(pred, axis=0)
            if self.flip_ap:
                pred = np.flip(pred, axis=1)
            if self.flip_lr:
                pred = np.flip(pred, axis=2)
            if self.flip_lr or self.flip_ap or self.flip_si:
                self._log("🔁 Axis inversions applied to the segmentation")
        except Exception as e:
            self._log(f"⚠ Error applying axis inversions: {e}")

        # Construir máscaras solo para órganos presentes
        unique_idxs = set(np.unique(pred))
        masks: dict[str, np.ndarray] = {}
        
        self._log(f"📊 Unique indices found: {sorted(unique_idxs)}")
        
        for name, idx in self.labels_map.items():
            # Omite órganos no seleccionados por el usuario
            if self.organs and name not in self.organs:
                continue
            
            # Si el índice no aparece en la predicción, saltamos
            if idx not in unique_idxs:
                continue
                
            try:
                mask = (pred == idx)  # booleano
                pixel_count = int(mask.sum())

                # Opcionalmente aplicar operaciones morfológicas para
                # eliminar agujeros y pequeñas componentes desconectadas.
                if self.clean_masks and pixel_count > 0:
                    try:
                        # Importar scipy.ndimage solo cuando sea necesario
                        import scipy.ndimage as _ndi  # type: ignore
                        # Rellenar agujeros dentro del órgano
                        filled = _ndi.binary_fill_holes(mask)
                        # Etiquetar componentes conectados
                        labels, num = _ndi.label(filled)
                        if num > 0:
                            # Seleccionar la mayor componente
                            counts = np.bincount(labels.flatten())
                            # La etiqueta 0 es fondo; ignorarla
                            if counts.size > 1:
                                largest_label = int(np.argmax(counts[1:]) + 1)
                                mask = (labels == largest_label)
                                pixel_count = int(mask.sum())
                            else:
                                mask = filled
                                pixel_count = int(mask.sum())
                    except Exception:
                        # Si scipy no está disponible o falla, se usa la máscara original
                        pass

                    if pixel_count > 0:
                        masks[name] = mask
                        # Report mask details in English
                        self._log(
                            f"✔ Mask for {name}: {mask.shape}, {pixel_count} pixels"
                        )

            except Exception as e:
                self._log(f"⚠ Error building mask for {name}: {e}")
                continue
        
        self._log(f"📋 Total masks generated: {len(masks)}")
        return masks

    # ------------------------------------------------------------------
    # Segmentación con TotalSegmentator V2
    # ------------------------------------------------------------------
    def _segment_totalseg(self, series_files):
        """Realiza la segmentación usando TotalSegmentator V2.

        Esta función se activa cuando `self.model_type` es 'totalseg'.  Se
        intenta importar la API de TotalSegmentator y se ejecuta la
        segmentación en la carpeta que contiene los cortes DICOM.  La
        salida es un diccionario de máscaras binarias indexado por nombre
        de órgano.  En caso de cualquier error (por ejemplo si la
        biblioteca no está instalada) se devuelve un diccionario vacío.
        """
        if not series_files:
            self._log("?? No files were provided for segmentation")
            return {}

        input_dir = os.path.dirname(series_files[0])

        try:
            try:
                from totalsegmentatorv2.python_api import totalsegmentator  # type: ignore
            except ImportError:
                from totalsegmentator.python_api import totalsegmentator  # type: ignore
        except Exception as e:
            self._log(
                f"!! Could not import TotalSegmentator: {e}. Make sure to install the package via pip."
            )
            return {}

        self._ensure_custom_trainer()

        fast = not self.highres
        device_param = 'gpu' if (self.device_preference == 'gpu' and torch.cuda.is_available()) else 'cpu'

        progress_started = False

        def run_task(task_name: str, label_map: dict[str, int], selected_organs, allow_roi_subset: bool = True) -> dict[str, np.ndarray]:
            nonlocal progress_started
            if not label_map:
                self._log(f"?? Task '{task_name}' has no labels; skipping.")
                return {}

            roi_subset = None
            if allow_roi_subset and task_name == 'total' and selected_organs:
                candidates = [o for o in selected_organs if o in label_map]
                roi_subset = candidates if candidates else None

            try:
                if not self.totalseg_downloaded and not progress_started:
                    self._log("?? Downloading TotalSegmentator models. This will happen only once.")
                    self.after(0, self._indeterminate, True)
                    progress_started = True

                self._log(f"?? Running TotalSegmentator V2 task '{task_name}'...")
                orig_stdout = sys.stdout
                orig_stderr = sys.stderr
                dummy_stream = io.StringIO()
                try:
                    if orig_stdout is None:
                        sys.stdout = dummy_stream
                    if orig_stderr is None:
                        sys.stderr = dummy_stream
                    seg_img = totalsegmentator(
                        input_dir,
                        None,
                        ml=True,
                        fast=fast,
                        roi_subset=roi_subset,
                        device=device_param,
                        task=task_name,
                        quiet=True,
                    )
                finally:
                    sys.stdout = orig_stdout
                    sys.stderr = orig_stderr
            except Exception as e:
                msg = str(e)
                if 'Unable to locate trainer class' in msg or 'nnUNetTrainer_4000epochs_NoMirroring' in msg:
                    self._log(
                        "?? TotalSegmentator failed due to a missing nnUNet trainer class. "
                        "This may indicate that your installation of nnunetv2 or TotalSegmentator is outdated. "
                        "Please upgrade TotalSegmentator and nnunetv2 using pip (for example, `pip install --upgrade totalsegmentatorv2 nnunetv2`) "
                        "or ensure that the fallback trainer file could be created in your Python environment."
                    )
                else:
                    self._log(f"!! Error running TotalSegmentator task '{task_name}': {e}")
                self._log(traceback.format_exc())
                return {}

            self.totalseg_downloaded = True

            try:
                seg_data = seg_img.get_fdata().astype(np.uint16)  # type: ignore
            except Exception:
                try:
                    seg_data = np.asarray(seg_img).astype(np.uint16)  # type: ignore
                except Exception as ex:
                    self._log(f"!! Could not convert the result of TotalSegmentator to numpy: {ex}")
                    return {}

            if seg_data.ndim == 3:
                pred = np.transpose(seg_data, (2, 1, 0))
            else:
                pred = seg_data

            try:
                if self.flip_si:
                    pred = np.flip(pred, axis=0)
                if self.flip_ap:
                    pred = np.flip(pred, axis=1)
                if self.flip_lr:
                    pred = np.flip(pred, axis=2)
                if self.flip_lr or self.flip_ap or self.flip_si:
                    self._log("?? Axis inversions applied to the segmentation")
            except Exception as axis_error:
                self._log(f"?? Error applying axis inversions: {axis_error}")

            unique_idxs = set(np.unique(pred))
            self._log(f"?? Unique indices found (task '{task_name}'): {sorted(unique_idxs)}")

            masks: dict[str, np.ndarray] = {}
            selected_set = None if selected_organs is None else set(selected_organs)
            for name, idx in label_map.items():
                if selected_set is not None and name not in selected_set:
                    continue
                if idx not in unique_idxs:
                    continue
                try:
                    mask = (pred == idx)
                    pixel_count = int(mask.sum())
                    if pixel_count <= 0:
                        continue
                    if self.clean_masks:
                        try:
                            import scipy.ndimage as _ndi  # type: ignore
                            filled = _ndi.binary_fill_holes(mask)
                            labels_, num = _ndi.label(filled)
                            if num > 0:
                                counts = np.bincount(labels_.flatten())
                                if counts.size > 1:
                                    largest_label = int(np.argmax(counts[1:]) + 1)
                                    mask = (labels_ == largest_label)
                                    pixel_count = int(mask.sum())
                                else:
                                    mask = filled
                                    pixel_count = int(mask.sum())
                        except Exception:
                            pass
                    masks[name] = mask
                    self._log(f"?? Mask for {name} (task '{task_name}'): {mask.shape}, {pixel_count} pixels")
                except Exception as build_error:
                    self._log(f"?? Error building mask for {name} (task '{task_name}'): {build_error}")
                    continue

            return masks

        selection = list(self.organs)
        masks: dict[str, np.ndarray] = {}

        if self.totalseg_task == 'complete':
            if not selection:
                self._log("?? No organs selected for Complete task; skipping segmentation.")
            else:
                ordered = [k for k in TOTALSEG_TASK_KEYS if k != 'complete' and TOTALSEG_TASK_LABELS.get(k)]
                extras = [k for k in TOTALSEG_TASK_LABELS.keys() if k not in ordered and k != 'complete' and TOTALSEG_TASK_LABELS.get(k)]
                missing_organs = set(selection)
                for task_name in ordered + extras:
                    label_map = TOTALSEG_TASK_LABELS.get(task_name, {})
                    if not label_map:
                        continue
                    relevant = [org for org in selection if org in label_map]
                    if not relevant:
                        continue
                    task_masks = run_task(task_name, label_map, relevant)
                    for organ, mask in task_masks.items():
                        if organ not in masks:
                            masks[organ] = mask
                            missing_organs.discard(organ)
                if missing_organs:
                    self._log("?? The following organs are not available in TotalSegmentator tasks: " + ', '.join(sorted(missing_organs)))
        else:
            selection_arg = selection if selection else None
            masks = run_task(self.totalseg_task, self.labels_map, selection_arg)

        if self.totalseg_task != 'complete' and self._should_append_body_task():
            body_map = TOTALSEG_TASK_LABELS.get('body', {})
            if body_map:
                self._log("?? Appending body segmentation results to the current task output")
                body_masks = run_task('body', body_map, None, allow_roi_subset=False)
                for name, mask in body_masks.items():
                    if name not in masks:
                        masks[name] = mask
            else:
                self._log("?? Body task labels are not available; skipping body task")

        if progress_started:
            self.after(0, self._indeterminate, False)

        self._log(f"?? Total masks generated: {len(masks)}")
        return masks
    # ------------------------------------------------------------------
    # Guardar RTSTRUCT mejorado
    # ------------------------------------------------------------------
    def _save_rt(self, folder: str, masks: dict, name: str, series_files=None):
        try:
            # Sanitizar el nombre para evitar caracteres ilegales en rutas
            safe_name = sanitize_filename(name)
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            odir = os.path.join(self.out_entry.get(), f"{safe_name}_{timestamp}")
            os.makedirs(odir, exist_ok=True)
            # Log the output directory so the user knows where files will be written
            self._log(f"📂 Output directory: {odir}")

            # Copiar CTs
            ct_dst = os.path.join(odir, "CT")
            os.makedirs(ct_dst, exist_ok=True)
            # Inform the user that we are copying the DICOM CT files into the RTSTRUCT folder
            self._log(f"📥 Copying CT slices from {folder} to {ct_dst}...")

            if series_files is None:
                series_files = self._collect_ct_series(folder)

            for src in series_files:
                fname = os.path.basename(src)
                dst = os.path.join(ct_dst, fname)
                shutil.copy2(src, dst)

            if not os.listdir(ct_dst):
                # Abort if no slices were copied
                self._log("❌ Error: No DICOM slices were copied. Aborting RTSTRUCT.")
                return False

            self._log(f"✔ {len(series_files)} CT slices copied to {ct_dst}")

            # Create an RTSTRUCT on top of the newly copied series
            self._log("🛠 Creating RTSTRUCT...")
            try:
                rtstruct = RTStructBuilder.create_new(dicom_series_path=ct_dst)
                self._log("✔ RTStructBuilder initialized successfully")
            except Exception as e:
                # Report failure to create the RTSTRUCT
                self._log(f"❌ Error creating RTStructBuilder: {str(e)}")
                return False

            # Determinar forma esperada para máscaras
            sample_ds = pydicom.dcmread(series_files[0], stop_before_pixels=True)
            num_slices = len(series_files)
            rows = int(sample_ds.Rows)
            cols = int(sample_ds.Columns)
            expected_rt_shape = (rows, cols, num_slices)
            # Log the expected mask shape used by RTSTRUCT (Rows, Cols, Slices)
            self._log(f"📐 Expected shape for RT masks (Rows,Cols,Slices): {expected_rt_shape}")

            rois_added = 0
            MIN_PIXELS = 5

            for lbl, mask in masks.items():
                if mask.sum() < MIN_PIXELS:
                    # Skip masks that are too small to be meaningful
                    self._log(f"⚠ {lbl}: mask too small ({mask.sum()} < {MIN_PIXELS}), skipping")
                    continue

                # Intentar diferentes estrategias de conversión de forma
                mask_for_rt = None
                conversion_successful = False

                # Estrategia 1: Formas estándar conocidas
                if mask.shape == (num_slices, rows, cols):
                    mask_for_rt = np.transpose(mask, (1, 2, 0))  # (Z,Y,X) -> (Y,X,Z)
                    self._log(f"  - {lbl}: Standard transpose {mask.shape} → {mask_for_rt.shape}")
                    conversion_successful = True
                elif mask.shape == expected_rt_shape:
                    mask_for_rt = mask
                    self._log(f"  - {lbl}: Correct shape {mask.shape}")
                    conversion_successful = True
                elif mask.ndim == 3:
                    # Estrategia 2: Intentar diferentes transposiciones
                    possible_transposes = [
                        (0, 1, 2),  # sin cambio
                        (1, 2, 0),  # (Z,Y,X) -> (Y,X,Z)
                        (2, 1, 0),  # (Z,Y,X) -> (X,Y,Z)
                        (0, 2, 1),  # (Z,Y,X) -> (Z,X,Y)
                        (1, 0, 2),  # (Z,Y,X) -> (Y,Z,X)
                        (2, 0, 1),  # (Z,Y,X) -> (X,Z,Y)
                    ]
                    
                    for perm in possible_transposes:
                        try:
                            test_shape = tuple(mask.shape[i] for i in perm)
                            if test_shape == expected_rt_shape:
                                mask_for_rt = np.transpose(mask, perm)
                                self._log(f"  - {lbl}: Successful transpose {mask.shape} → {mask_for_rt.shape} (perm: {perm})")
                                conversion_successful = True
                                break
                        except Exception:
                            continue
                
                # Estrategia 3: Redimensionado inteligente si no coincide
                if not conversion_successful and mask.ndim == 3:
                    self._log(f"  - {lbl}: Trying smart resizing {mask.shape} → {expected_rt_shape}")
                    try:
                        mask_for_rt = smart_resize_prediction(mask.astype(np.uint8), expected_rt_shape)
                        if mask_for_rt.shape == expected_rt_shape:
                            conversion_successful = True
                            self._log(f"  - {lbl}: Resizing successful")
                        else:
                            self._log(f"  - {lbl}: Resizing failed, resulting shape: {mask_for_rt.shape}")
                    except Exception as e:
                        self._log(f"  - {lbl}: Error during resizing: {e}")

                if not conversion_successful:
                    self._log(f"❌ {lbl}: Could not convert shape {mask.shape} to {expected_rt_shape}, skipping")
                    continue

                # Verificar que la máscara convertida tenga contenido
                if mask_for_rt.sum() < MIN_PIXELS:
                    self._log(f"⚠ {lbl}: converted mask too small ({mask_for_rt.sum()} < {MIN_PIXELS}), skipping")
                    continue

                # Preparar máscara para rt_utils
                mask_bool = np.ascontiguousarray(mask_for_rt.astype(np.bool_))
                rgb = get_organ_color(lbl)
                color = [int(c) for c in rgb]

                try:
                    rtstruct.add_roi(
                        mask=mask_bool,
                        name=dicom_safe_name(lbl),
                        color=color,
                    )
                    rois_added += 1
                    self._log(f"✔ ROI {lbl} added successfully ({mask_bool.sum()} pixels)")
                except Exception as e:
                    self._log(f"❌ Error adding ROI {lbl}: {str(e)}")
                    # No mostrar traceback completo para errores de ROI individual

            if rois_added == 0:
                self._log("⚠ No valid ROIs were added")
                return False

            output_path = os.path.join(ct_dst, "rtss.dcm")
            self._log(f"💾 Attempting to save RTSTRUCT to {output_path}...")
            try:
                from pydicom.uid import ExplicitVRLittleEndian
                rtstruct.ds.file_meta.TransferSyntaxUID = ExplicitVRLittleEndian

                rtstruct.ds.file_meta.TransferSyntaxUID = ExplicitVRLittleEndian
                rtstruct.ds.is_implicit_VR = False
                rtstruct.ds.is_little_endian = True

                rtstruct.save(output_path)
                self._log(f"✅ RTSTRUCT saved successfully with {rois_added} ROIs")
                
                if os.path.exists(output_path):
                    file_size = os.path.getsize(output_path) / 1024
                    self._log(f"📏 RTSTRUCT file size: {file_size:.2f} KB")
                    if file_size < 10:
                        self._log("⚠ Warning: The RTSTRUCT file is very small; it may be empty.")
                    return True
                else:
                    self._log("❌ Error: The RTSTRUCT file was not created")
                    return False
                    
            except Exception as e:
                self._log(f"❌ Error saving RTSTRUCT: {str(e)}")
                return False

        except Exception as e:
            # Manejar cualquier excepción no contemplada en _save_rt
            self._log(f"‼ Error inesperado en _save_rt: {str(e)}")
            self._log(traceback.format_exc())
            return False

    # ------------------------------------------------------------------
    # Configuración persistente
    # ------------------------------------------------------------------
    def _load_config(self):
        """
        Carga la configuración desde un archivo JSON en el directorio de usuario.
        Si el archivo no existe o está corrupto, se utilizan valores por defecto.
        Tras cargar, actualiza atributos de la aplicación y widgets.
        """
        try:
            if os.path.exists(self.config_path):
                with open(self.config_path, 'r', encoding='utf-8') as f:
                    cfg = json.load(f)
                # Tema
                self.style_name = cfg.get('theme', self.style_name)
                # Orientaciones
                self.flip_lr = bool(cfg.get('flip_lr', self.flip_lr))
                self.flip_ap = bool(cfg.get('flip_ap', self.flip_ap))
                self.flip_si = bool(cfg.get('flip_si', self.flip_si))
                # Uso de recorte
                self.use_crop = bool(cfg.get('use_crop', self.use_crop))
                # Limpieza de máscaras
                self.clean_masks = bool(cfg.get('clean_masks', self.clean_masks))
                # Margen de recorte
                self.crop_margin = int(cfg.get('crop_margin', self.crop_margin))
                # Directorios
                in_dir = cfg.get('in_entry', '')
                out_dir = cfg.get('out_entry', '')
                if in_dir:
                    self.in_entry.delete(0, tk.END)
                    self.in_entry.insert(0, in_dir)
                if out_dir:
                    self.out_entry.delete(0, tk.END)
                    self.out_entry.insert(0, out_dir)
                # Dispositivo
                device_str = cfg.get('device', str(self.device))
                try:
                    new_dev = torch.device(device_str)
                    if new_dev.type == 'cuda' and torch.cuda.is_available():
                        self.device = new_dev
                        self.device_preference = 'gpu'
                    else:
                        self.device = torch.device('cpu')
                        self.device_preference = 'cpu'
                except Exception:
                    pass
                # Resolución para TotalSegmentator (highres indica que se utiliza
                # el modelo de alta resolución; fast=False)
                self.highres = bool(cfg.get('highres', self.highres))
                # Indicar si ya se mostró el diálogo de instalación de TotalSegmentator
                self.totalseg_prompted = bool(cfg.get('totalseg_prompted', self.totalseg_prompted))
                self.totalseg_task = cfg.get('totalseg_task', self.totalseg_task)
                prefs = cfg.get('organs_by_task', {})
                if isinstance(prefs, dict):
                    cleaned: dict[str, list[str]] = {}
                    for key, organs in prefs.items():
                        if isinstance(key, str) and isinstance(organs, list):
                            valid = [str(o) for o in organs if isinstance(o, str)]
                            if valid:
                                cleaned[key] = valid
                    if cleaned:
                        self.organ_preferences.update(cleaned)
                else:
                    legacy_organs = cfg.get('organs')
                    if isinstance(legacy_organs, list):
                        key = self._selection_key(model='totalseg', task='total')
                        self.organ_preferences[key] = [str(o) for o in legacy_organs if isinstance(o, str)]
                # Actualizar variables de checkbuttons
                try:
                    self.use_crop_var.set(self.use_crop)
                    self.clean_masks_var.set(self.clean_masks)
                except Exception:
                    pass
            else:
                # Si no existe configuración previa, no hacer nada
                pass
        except Exception as e:
            # Warn if the configuration could not be loaded
            self._log(f"⚠ Could not load the configuration: {e}")

    def _save_config(self):
        """
        Guarda el estado actual en un archivo JSON. Captura tema, orientación,
        recorte, limpieza de máscaras, márgenes y rutas. Se usa al cerrar
        la aplicación y tras cambios en la configuración.
        """
        try:
            self._store_current_selection()
            data = {
                'theme': self.style_name,
                'flip_lr': bool(self.flip_lr),
                'flip_ap': bool(self.flip_ap),
                'flip_si': bool(self.flip_si),
                'use_crop': bool(self.use_crop),
                'clean_masks': bool(self.clean_masks),
                'crop_margin': int(self.crop_margin),
                'in_entry': self.in_entry.get(),
                'out_entry': self.out_entry.get(),
                'device': str(self.device),
                'highres': bool(self.highres),
                'totalseg_prompted': bool(self.totalseg_prompted),
                'totalseg_task': self.totalseg_task,
                'organs_by_task': self.organ_preferences,
            }
            with open(self.config_path, 'w', encoding='utf-8') as f:
                json.dump(data, f, indent=2)
        except Exception as e:
            # Warn if the configuration could not be saved
            self._log(f"⚠ Could not save the configuration: {e}")

    def _on_close(self):
        """
        Llamada cuando la ventana se cierra. Guarda la configuración y
        destruye la ventana.
        """
        try:
            self._save_config()
        finally:
            self.destroy()

    def _ensure_totalseg(self) -> None:
        """
        Ensure that the TotalSegmentator library is available.  This method
        attempts to import the v2 API (preferred).  If the import fails,
        the user is asked whether they would like to install TotalSegmentator.
        On consent, the method will try several strategies:

        1. Install the `totalsegmentatorv2` package from PyPI via pip.
        2. Install from a local ZIP file in the `models` directory if one is present.
        3. Download the source ZIP from GitHub and install it via pip.

        The user will only be prompted once per session; the flag
        ``self.totalseg_prompted`` records that the question has been shown.
        All progress and errors are logged.
        """
        # Try to import TotalSegmentator V2 API. If successful, nothing else to do.
        try:
            from totalsegmentatorv2.python_api import totalsegmentator  # type: ignore
            return
        except Exception:
            pass

        # If the library is missing and the user has not yet been asked, log a message
        # instead of opening a dialog.  AURA previously prompted the user
        # via a modal message box to confirm installation of the
        # `totalsegmentatorv2` package.  Opening such a dialog creates an
        # unwanted window, which can be disruptive when the application is
        # running in a non‑interactive environment or when the user has
        # already taken care of installing the dependency.  We now log
        # guidance and avoid any blocking UI prompts.  Users who wish to
        # install TotalSegmentator may run `pip install totalsegmentatorv2` manually.
        try:
            if not self.totalseg_prompted:
                self.totalseg_prompted = True
                self._save_config()
                self._log(
                    "⚠ TotalSegmentator is not installed. This library is required for segmentation. "
                    "Please install it manually with 'pip install totalsegmentatorv2' to enable this feature."
                )
            else:
                # The user has already been informed about the missing library
                self._log(
                    "⚠ TotalSegmentator remains unavailable. Install it with 'pip install totalsegmentatorv2' to run segmentation."
                )
        except Exception as e:
            # Log any unexpected error during this check
            self._log(f"⚠ Error checking TotalSegmentator availability: {e}")

    def _ensure_custom_trainer(self) -> None:
        """
        Ensure that the custom nnUNet trainer required by some TotalSegmentator
        models exists. TotalSegmentator v2 models reference a class named
        ``nnUNetTrainer_4000epochs_NoMirroring`` which is not part of the
        standard nnunetv2 distribution. When this class cannot be imported,
        this method attempts to create a fallback implementation in the
        nnunetv2 package directory. If the directory is not writable or
        nnunetv2 is unavailable, a warning is logged and the method returns.
        """
        try:
            from importlib.util import find_spec  # type: ignore
            # If the module already exists, nothing to do
            if find_spec('nnunetv2.training.nnUNetTrainer.nnUNetTrainer_4000epochs_NoMirroring'):
                return
            import nnunetv2.training.nnUNetTrainer as trainer_mod  # type: ignore
            import os
            trainer_dir = os.path.dirname(trainer_mod.__file__)
            custom_path = os.path.join(trainer_dir, 'nnUNetTrainer_4000epochs_NoMirroring.py')
            # Only create the file if it does not already exist
            if not os.path.exists(custom_path):
                try:
                    with open(custom_path, 'w', encoding='utf-8') as f:
                        f.write('from .nnUNetTrainer import nnUNetTrainer\n\n')
                        f.write('class nnUNetTrainer_4000epochs_NoMirroring(nnUNetTrainer):\n')
                        f.write('    """Fallback trainer created by AURA.\n')
                        f.write('\n')
                        f.write('    This class exists solely to satisfy TotalSegmentator\n')
                        f.write('    references during inference and derives behaviour from\n')
                        f.write('    the default nnUNetTrainer. It disables mirroring and\n')
                        f.write('    increases the epoch count. These settings are irrelevant\n')
                        f.write('    for inference but match the original TotalSegmentator\n')
                        f.write('    training configuration.\n')
                        f.write('    """\n')
                        f.write('    def __init__(self, *args, **kwargs):\n')
                        f.write('        super().__init__(*args, **kwargs)\n')
                        f.write('        # Do not use mirroring during training/inference\n')
                        f.write('        self.allowed_mirroring_axes = None\n')
                        f.write('        # Increase maximum number of epochs\n')
                        f.write('        self.max_num_epochs = 4000\n')
                except Exception as exc:
                    # If writing fails, inform the user via the log
                    self._log(f"⚠ Could not create fallback nnUNet trainer: {exc}")
        except Exception as exc:
            # If nnunetv2 is not installed or another error occurs, log and return
            self._log(f"⚠ Could not ensure custom trainer class: {exc}")


    # ------------------------------------------------------------------
    # Procesar UN paciente
    # ------------------------------------------------------------------
    def _process_one(self):
        try:
            folder = self.in_entry.get().strip()
            if not os.path.isdir(folder):
                messagebox.showerror("Error", "Select a valid folder.")
                return

            name = self._dicom_name(folder)
            self._log(f"🚀 Processing patient: {name}")

            series_files = self._collect_ct_series(folder)
            masks = self._segment_from_files(series_files)
            success = self._save_rt(folder, masks, name, series_files=series_files)

            if success:
                self._log(f"✅ Processing completed for {name}")
            else:
                self._log(f"⚠ Processing completed with errors for {name}")

        except Exception as e:
            self._log(f"❌ Error processing patient: {e}")
            self._log(traceback.format_exc())
        finally:
            self._indeterminate(False)

    # ------------------------------------------------------------------
    # Procesar TODOS los pacientes (batch)
    # ------------------------------------------------------------------
    def _process_all(self):
        try:
            root = self.in_entry.get().strip()
            if not os.path.isdir(root):
                messagebox.showerror("Error", "Select a valid folder.")
                return

            subs = [d for d in os.listdir(root) if os.path.isdir(os.path.join(root, d))]
            total = len(subs)
            if total == 0:
                self._log("ℹ No subfolders found to process")
                return

            self.progress.configure(mode="determinate", maximum=total, value=0)

            for i, folder_name in enumerate(subs, 1):
                folder_path = os.path.join(root, folder_name)
                name = self._dicom_name(folder_path)
                self._log(f"{i}/{total} ➡ Processing {name}...")

                try:
                    series_files = self._collect_ct_series(folder_path)
                    masks = self._segment_from_files(series_files)
                    success = self._save_rt(folder_path, masks, name, series_files=series_files)
                    if success:
                        self._log(f"✅ {name} completed")
                    else:
                        self._log(f"⚠ {name} completed with errors")
                except Exception as e:
                    self._log(f"❌ Error processing {name}: {e}")
                    # Do not log full traceback in batch to avoid cluttering the log

                self.progress["value"] = i
                self.update_idletasks()

            self._log("🟢 Batch processing completed")

        except Exception as e:
            self._log(f"❌ Error in batch processing: {e}")
            self._log(traceback.format_exc())
        finally:
            self.progress["value"] = 0
            self._indeterminate(False)


# -------------------------------------------------------------------------
# Handler de logging hacia Tkinter
# -------------------------------------------------------------------------
class TextHandler(logging.Handler):
    def __init__(self, app: AutoSegApp):
        super().__init__()
        self.app = app

    def emit(self, record: logging.LogRecord):
        msg = self.format(record)
        self.app._log(msg)


# -------------------------------------------------------------------------
# Main
# -------------------------------------------------------------------------
if __name__ == "__main__":
    def _print_optional_dependencies() -> None:
        print("Dependencias opcionales (recomendadas): pip install scipy scikit-image")

    # Dependencias minimas: aseguramos que pydicom este disponible
    try:
        import pydicom  # noqa: F401
    except ImportError as e:
        print(f"Error: Falta dependencia - {e}")
        print("Instala las dependencias con: pip install pydicom torch psutil")
        _print_optional_dependencies()
        sys.exit(1)

    # Preparar entorno GPU (detecta tarjetas y trata de instalar el wheel correspondiente)
    try:
        prepare_gpu_environment(logger.info)
    except Exception as exc:
        logger.warning(f"No se pudo preparar automaticamente el entorno GPU: {exc}")
        logger.debug("Detalle del fallo preparando entorno GPU", exc_info=exc)

    # Verificamos torch tras la preparacion (puede haber sido instalado en el paso anterior)
    try:
        import torch  # noqa: F401
    except ImportError as e:
        print(f"Error: Falta dependencia - {e}")
        print("Instala las dependencias con: pip install torch psutil")
        print(
            "Para GPUs NVIDIA ejecuta: pip install torch --index-url "
            "https://download.pytorch.org/whl/cu121"
        )
        _print_optional_dependencies()
        sys.exit(1)

    def show_splash_and_start():
        """
        Muestra una ventana de presentación mientras se cargan las dependencias pesadas.

        Al iniciarse la aplicación se crea una pequeña ventana con el logotipo y una
        barra de progreso indeterminada.  En un hilo de fondo se importan las
        bibliotecas pesadas (MONAI, rt_utils, nibabel, etc.) mediante
        ``load_heavy_modules``.  Cuando la carga termina, la función destruye la
        ventana de presentación y lanza la ventana principal ``AutoSegApp`` en el
        hilo principal.
        """
        splash = tk.Tk()
        splash.overrideredirect(True)
        screen_w = splash.winfo_screenwidth()
        screen_h = splash.winfo_screenheight()
        w, h = 500, 350
        x = (screen_w // 2) - (w // 2)
        y = (screen_h // 2) - (h // 2)
        splash.geometry(f"{w}x{h}+{x}+{y}")
        # Fondo
        bg_img_path = resource_path("splashscreen.png")
        try:
            splash_img = tk.PhotoImage(file=bg_img_path)
            splash.canvas = tk.Canvas(splash, width=w, height=h, highlightthickness=0)
            splash.canvas.pack(fill="both", expand=True)
            splash.canvas.create_image(0, 0, image=splash_img, anchor="nw")
            splash.canvas.image = splash_img
        except Exception:
            splash.configure(bg="#EEF5FF")
        # Texto
        title = tk.Label(
            splash,
            text="AURA",
            font=("Arial", 32, "bold"),
            fg="#0078D4",
            bg="#EEF5FF",
        )
        title.place(relx=0.5, rely=0.3, anchor="center")
        subtitle = tk.Label(
            splash,
            text="Automated Utility for Radiotherapy Anatomy",
            font=("Arial", 12),
            fg="#1F2937",
            bg="#EEF5FF",
        )
        subtitle.place(relx=0.5, rely=0.4, anchor="center")
        # Barra de progreso
        progress = ttk.Progressbar(splash, mode="indeterminate", length=300)
        progress.place(relx=0.5, rely=0.75, anchor="center")
        progress.start(10)

        def load_and_launch():
            """Hilo que carga las dependencias y lanza la app principal."""
            try:
                load_heavy_modules()
            except Exception as exc:
                # Registrar el error y mostrarlo al usuario en una ventana emergente
                logger.error(f"Error cargando módulos pesados: {exc}")
                # Usamos messagebox solo después de que Tk esté inicializado
                splash.after(0, lambda: messagebox.showerror(
                    "Error", f"Error cargando dependencias: {exc}"
                ))
                # Cerramos la aplicación porque no puede continuar sin estas dependencias
                splash.after(0, splash.destroy)
                return
            # Una vez cargado todo, iniciamos la app principal en el hilo principal
            def start_app():
                splash.destroy()
                app = AutoSegApp()
                app.mainloop()
            splash.after(0, start_app)

        # Lanzamos la carga en un hilo de fondo
        threading.Thread(target=load_and_launch, daemon=True).start()
        splash.mainloop()

    # Arrancar la aplicación con splash y carga diferida
    show_splash_and_start()
