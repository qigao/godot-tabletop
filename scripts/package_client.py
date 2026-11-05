"""Build a runnable local client bundle with the verified standard Godot runtime."""
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import zipfile

project = Path(__file__).resolve().parents[1]
godot = Path(sys.argv[1]).resolve()
engine_dir = Path(sys.argv[2]).resolve()
platform_name = sys.argv[3]
output = Path(sys.argv[4]).resolve()
pack = project / "exports/client.pck"
pack.parent.mkdir(exist_ok=True)

def run(arguments):
    result = subprocess.run([str(godot), *arguments], stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, text=True, encoding="utf-8")
    print(result.stdout, end="", flush=True)
    if result.returncode or "ERROR:" in result.stdout:
        raise SystemExit("Packed client acceptance failed")

run(["--headless", "--path", str(project), "--export-pack", "Client pack", str(pack)])
# Execute the real client scenes from PCK, without the source project's resources.
run(["--headless", "--main-pack", str(pack), "--script", str(project / "tests/smoke.gd")])
run(["--headless", "--main-pack", str(pack), "--script", str(project / "tests/interaction.gd")])

with tempfile.TemporaryDirectory(prefix="tabletop-client-") as directory:
    stage = Path(directory)
    shutil.copytree(engine_dir, stage / "runtime")
    shutil.copy2(pack, stage / "client.pck")
    shutil.copy2(project / "LICENSE", stage / "LICENSE")
    shutil.copy2(project / "THIRD_PARTY.md", stage / "THIRD_PARTY.md")
    shutil.copy2(project / "addons/card-framework/LICENSE", stage / "CARD_FRAMEWORK_LICENSE")
    shutil.copy2(project / "licenses/GODOT_LICENSE.txt", stage / "GODOT_LICENSE.txt")
    shutil.copy2(project / "licenses/GODOT_COPYRIGHT.txt", stage / "GODOT_COPYRIGHT.txt")
    relative = godot.relative_to(engine_dir).as_posix()
    if platform_name == "Windows":
        executable = relative.replace("_console.exe", ".exe")
        launcher = stage / "RunTabletop.cmd"
        launcher.write_text('@echo off\r\n"%~dp0runtime\\' + executable.replace('/', '\\') +
                            '" --main-pack "%~dp0client.pck"\r\n', encoding="utf-8")
    else:
        launcher = stage / ("RunTabletop.command" if platform_name == "macOS" else "RunTabletop.sh")
        launcher.write_text('#!/bin/sh\ncd -- "$(dirname -- "$0")"\nexec "./runtime/' +
                            relative + '" --main-pack "./client.pck"\n', encoding="utf-8")
        launcher.chmod(0o755)
    (stage / "START-HERE.txt").write_text(
        "Godot Tabletop local client\n\nExtract the complete archive and run " + launcher.name +
        ".\nThe official standard Godot 4.6 runtime is included.\n"
        "Create DouDiZhu or Gomoku tables from the game picker.\n"
        "Undo/redo, replay seek, pause, save and load work locally.\n"
        "This development client bundle uses the official editor-capable runtime.\n",
        encoding="utf-8")
    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED, compresslevel=5) as archive:
        for file in sorted(stage.rglob("*")):
            if file.is_file():
                archive.write(file, file.relative_to(stage))
print(f"Client bundle: {output.name} ({output.stat().st_size} bytes)")
