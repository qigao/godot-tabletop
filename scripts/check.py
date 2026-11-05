"""Run real Godot checks and reject script errors even when Godot exits zero."""
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
godot = str(Path(sys.argv[1]).resolve())
checks = [
    ("import", ["--editor", "--import"]),
    ("rules", ["--script", "res://tests/run.gd"]),
    ("ui", ["--script", "res://tests/smoke.gd"]),
]
for name, arguments in checks:
    result = subprocess.run(
        [godot, "--headless", "--path", str(root), *arguments],
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
        encoding="utf-8", errors="replace", check=False,
    )
    print(result.stdout, end="", flush=True)
    if result.returncode or "ERROR:" in result.stdout:
        raise SystemExit(f"Godot {name} check failed")
