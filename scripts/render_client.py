"""Capture native OpenGL client scenes on the Linux CI display."""
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
captures = ["client-doudizhu.png", "client-gomoku.png", "client-compact.png", "client-doudizhu-compact.png", "client-doudizhu-result.png"]
for file in (root / "build/interaction-frames").glob("*.png"):
    file.unlink()
for file in (root / "docs/images").glob("client-*.png"):
    file.unlink()
result = subprocess.run([
    "xvfb-run", "-a", str(Path(sys.argv[1]).resolve()), "--path", str(root),
    "--rendering-method", "gl_compatibility", "--audio-driver", "Dummy",
    "--script", "res://tests/render_client.gd",
], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, encoding="utf-8")
print(result.stdout, end="")
if result.returncode or "ERROR:" in result.stdout:
    raise SystemExit("Native client rendering failed")
for name in captures:
    if (root / "docs/images" / name).stat().st_size == 0:
        raise SystemExit("Empty client capture: " + name)

subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-framerate", "10",
                "-i", str(root / "build/interaction-frames/%03d.png"),
                "-filter_complex", "scale=960:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=128[p];[b][p]paletteuse=dither=bayer:bayer_scale=4",
                str(root / "docs/images/client-interactions.gif")], check=True)
