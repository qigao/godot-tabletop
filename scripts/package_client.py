"""Build and accept a runnable local client bundle."""
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
windows = platform_name == "Windows"
preset = "Windows player" if windows else "Client pack"
pack = project / "exports/client.pck"
pack.parent.mkdir(exist_ok=True)

def run(arguments, executable=godot, cwd=None, log_file=None):
    result = subprocess.run([str(executable), *arguments], cwd=cwd, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, text=True, encoding="utf-8")
    log = result.stdout
    if log_file is not None:
        log += log_file.read_text(encoding="utf-8")
    print(log, end="", flush=True)
    if result.returncode or "ERROR:" in log:
        raise SystemExit("Packed client acceptance failed")

run(["--headless", "--path", str(project), "--export-pack", preset, str(pack)])
# Execute the real client scenes from PCK, without the source project's resources.
run(["--headless", "--main-pack", str(pack), "--script", str(project / "tests/smoke.gd")])
run(["--headless", "--main-pack", str(pack), "--script", str(project / "tests/interaction.gd")])
run(["--headless", "--main-pack", str(pack), "--script", str(project / "tests/interruptions.gd")])
run(["--headless", "--main-pack", str(pack), "--script", str(project / "tests/xiangqi.gd")])

with tempfile.TemporaryDirectory(prefix="tabletop-client-") as directory:
    stage = Path(directory) / "client"
    stage.mkdir()
    if windows:
        launcher = stage / "Tabletop.exe"
        run(["--headless", "--path", str(project), "--export-release", preset, str(launcher)])
        # Start the release executable in its package directory using its embedded game.
        startup_log = Path(directory) / "windows-startup.log"
        run(["--headless", "--quit-after", "10", "--log-file", str(startup_log)],
            executable=launcher, cwd=stage, log_file=startup_log)
        runtime_description = "Tabletop.exe includes the Godot 4.6 release runtime and all three games."
    else:
        shutil.copytree(engine_dir, stage / "runtime")
        shutil.copy2(pack, stage / "client.pck")
        relative = godot.relative_to(engine_dir).as_posix()
        launcher = stage / ("RunTabletop.command" if platform_name == "macOS" else "RunTabletop.sh")
        launcher.write_text('#!/bin/sh\ncd -- "$(dirname -- "$0")"\nexec "./runtime/' +
                            relative + '" --main-pack "./client.pck"\n', encoding="utf-8")
        launcher.chmod(0o755)
        runtime_description = "This development client includes the Godot 4.6 editor-capable runtime."
    shutil.copy2(project / "LICENSE", stage / "LICENSE")
    shutil.copy2(project / "THIRD_PARTY.md", stage / "THIRD_PARTY.md")
    shutil.copy2(project / "addons/card-framework/LICENSE", stage / "CARD_FRAMEWORK_LICENSE")
    shutil.copy2(project / "licenses/GODOT_LICENSE.txt", stage / "GODOT_LICENSE.txt")
    shutil.copy2(project / "licenses/GODOT_COPYRIGHT.txt", stage / "GODOT_COPYRIGHT.txt")
    shutil.copy2(project / "licenses/TABLETOP_BOARD_SERIF_OFL.txt", stage / "TABLETOP_BOARD_SERIF_OFL.txt")
    (stage / "START-HERE.txt").write_text(
        "Godot Tabletop local client\n\nExtract the complete archive and run " + launcher.name +
        ".\n" + runtime_description + "\n"
        "Create DouDiZhu, Gomoku or Xiangqi tables from the game picker.\n"
        "Undo/redo, replay seek, pause, save and load work locally.\n",
        encoding="utf-8")
    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED, compresslevel=5) as archive:
        for file in sorted(stage.rglob("*")):
            if file.is_file():
                archive.write(file, file.relative_to(stage))
print(f"Client bundle: {output.name} ({output.stat().st_size} bytes)")
