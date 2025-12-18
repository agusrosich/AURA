# -*- mode: python ; coding: utf-8 -*-


a = Analysis(
    ['C:\\Users\\agust\\Documents\\AURA\\AURA VER 1.0.py'],
    pathex=[],
    binaries=[],
    datas=[('C:\\Users\\agust\\Documents\\AURA\\models', 'models')],
    hiddenimports=['rt_utils', 'monai', 'monai.transforms', 'monai.data', 'monai.inferers', 'multiprocessing', 'first_run_setup'],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=['_bootlocale'],
    noarchive=False,
    optimize=0,
)
pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.datas,
    [],
    name='AURA',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=False,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)
