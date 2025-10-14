from pathlib import Path
lines = Path('AURA VER 1.0.py').read_text(encoding='utf-8', errors='replace').splitlines()
for i in range(3110, 3250):
    line = lines[i].encode('ascii','backslashreplace').decode('ascii')
    print(f"{i+1:04d}: {line}")
