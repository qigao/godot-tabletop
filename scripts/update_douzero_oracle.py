"""Regenerate action-set fixtures from the pinned, unmodified upstream generator.

Usage: python scripts/update_douzero_oracle.py /path/to/pinned/DouZero
No torch or numpy is needed: import only the inspected pure-Python generator.
"""
from pathlib import Path
import hashlib
import importlib
import json
import sys
import types

COMMIT = "718a5c920bf3361e34178a38f3b80458e176b351"
source = Path(sys.argv[1]).resolve()
expected = {
    "utils.py": "c4dab1343fa9e189c0f66a24363c5fa80f5bc3f1517dc0e45ef419367be5d48c",
    "move_generator.py": "157cb79cccc89110b6b6c49700e4860bf09b287b5356811ea7a1f81552649685",
}
for name, digest in expected.items():
    if hashlib.sha256((source / "douzero/env" / name).read_bytes()).hexdigest() != digest:
        raise SystemExit("Source does not match pinned DouZero: " + name)

# Import the generator with namespace packages; upstream env/__init__.py imports
# the complete training environment, which is outside this oracle's scope.
for name, relative in [("douzero", "douzero"), ("douzero.env", "douzero/env")]:
    package = types.ModuleType(name)
    package.__path__ = [str(source / relative)]
    sys.modules[name] = package
MovesGener = importlib.import_module("douzero.env.move_generator").MovesGener

cases = [
    ("single-chain", list(range(3, 15)) + [17, 17, 20, 30], []),
    ("pair-chain", [r for r in range(3, 10) for _ in range(2)] + [14, 14, 17, 17, 20, 30], []),
    ("three-body-airplane", [3]*3 + [4]*3 + [5]*3 + [8]*2 + [10, 14, 17], []),
    ("airplane-pairs", [3]*3 + [4]*3 + [5]*2 + [6]*2 + [7]*2 + [8]*2 + [9]*2 + [17]*2, []),
    ("four-pair-wings", [3]*4 + [4]*4 + [5]*2 + [6]*2 + [7]*2 + [14], []),
    ("twenty-card-mixed", [3]*3 + [4]*3 + [5]*3 + [8]*2 + [9]*2 + [10]*2 + [11]*2 + [12, 14, 17], []),
    ("bomb-and-chain", [3]*4 + [4]*3 + [6]*2 + [8, 9, 10, 11, 12, 13, 14, 17, 20], []),
    ("joker-wings-profile-difference", [3]*4 + [4]*3 + [20, 30],
        [[3]*4 + [20, 30], [3]*3 + [4]*3 + [20, 30]]),
    ("triple-wing-profile-difference", [3]*3 + [4]*3 + [5]*3 + [9]*3,
        [[3]*3 + [4]*3 + [5]*3 + [9]*3]),
    ("quad-wing-profile-difference", [3]*3 + [4]*3 + [5]*3 + [6]*3 + [9]*4,
        [[3]*3 + [4]*3 + [5]*3 + [9]*3,
         [4]*3 + [5]*3 + [6]*3 + [9]*3,
         [3]*3 + [4]*3 + [5]*3 + [6]*3 + [9]*4]),
]
fixtures = []
for name, hand, excluded in cases:
    actions = sorted({tuple(sorted(move)) for move in MovesGener(sorted(hand)).gen_moves()})
    excluded = sorted({tuple(sorted(move)) for move in excluded})
    if not set(excluded).issubset(actions):
        raise SystemExit("Documented difference absent from upstream output: " + name)
    fixtures.append({"name": name, "hand": sorted(hand), "actions": actions,
                     "excluded_by_profile": excluded})

output = Path(__file__).resolve().parents[1] / "tests/fixtures/douzero_actions.json"
output.write_text(json.dumps({
    "source": "https://github.com/kwai/DouZero", "commit": COMMIT,
    "source_sha256": expected, "profile": "ddz-classic-v1", "cases": fixtures,
}, separators=(",", ":")) + "\n", encoding="utf-8")
print(f"Wrote {len(fixtures)} cases, {sum(len(x['actions']) for x in fixtures)} upstream rank actions")
