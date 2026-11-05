"""Capture native OpenGL client scenes on the Linux CI display."""
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
result = subprocess.run([
    "xvfb-run", "-a", str(Path(sys.argv[1]).resolve()), "--path", str(root),
    "--rendering-method", "gl_compatibility", "--audio-driver", "Dummy",
    "--script", "res://tests/render_client.gd",
], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, encoding="utf-8")
print(result.stdout, end="")
if result.returncode or "ERROR:" in result.stdout:
    raise SystemExit("Native client rendering failed")
for name in ["client-doudizhu.png", "client-gomoku.png", "client-compact.png"]:
    if (root / "docs/images" / name).stat().st_size == 0:
        raise SystemExit("Empty client capture: " + name)
