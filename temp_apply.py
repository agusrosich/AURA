from pathlib import Path
lines = Path('AURA VER 1.0.py').read_text(encoding='utf-8', errors='replace').splitlines()
for i in range(1270, 1310):
    print(f"{i+1:04d}: {lines[i]}")
