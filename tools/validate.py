#!/usr/bin/env python3
"""Validate the Muse iNiR addon source tree.

Checks:
  * every *.json file in the tree parses as JSON
  * plugin.json exists and its "id" is "muse"
  * every file listed in any qmldir exists next to that qmldir
  * scripts/muse_bridge.py and scripts/inir_action.py compile

Prints one PASS/FAIL line per check and exits non-zero on any failure.
"""

import json
import py_compile
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
failures = 0


def report(ok, label, detail=""):
    global failures
    if not ok:
        failures += 1
    suffix = (" -- " + detail) if detail else ""
    print("%s %s%s" % ("PASS" if ok else "FAIL", label, suffix))


# 1. All JSON parses.
json_files = sorted(ROOT.rglob("*.json"))
if not json_files:
    report(False, "json files present", "none found")
for path in json_files:
    try:
        json.loads(path.read_text(encoding="utf-8"))
        report(True, "json parses: %s" % path.relative_to(ROOT))
    except Exception as exc:
        report(False, "json parses: %s" % path.relative_to(ROOT), str(exc))

# 2. plugin.json id.
manifest_path = ROOT / "plugin.json"
try:
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    report(manifest.get("id") == "muse", "plugin.json id is 'muse'",
           "got %r" % manifest.get("id"))
    panel = (manifest.get("parts") or {}).get("panel")
    report(bool(panel) and (ROOT / panel).is_file(),
           "plugin.json parts.panel exists", "parts.panel=%r" % panel)
except Exception as exc:
    report(False, "plugin.json readable", str(exc))

# 3. qmldir-listed files exist.
qmldirs = sorted(ROOT.rglob("qmldir"))
if not qmldirs:
    report(False, "qmldir files present", "none found")
for qmldir in qmldirs:
    for line in qmldir.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        listed = line.split()[-1]
        target = qmldir.parent / listed
        report(target.is_file(),
               "qmldir entry exists: %s -> %s" % (qmldir.relative_to(ROOT), listed))

# 4. Python scripts compile.
for script in ("scripts/muse_bridge.py", "scripts/inir_action.py"):
    path = ROOT / script
    try:
        py_compile.compile(str(path), doraise=True)
        report(True, "python compiles: %s" % script)
    except Exception as exc:
        report(False, "python compiles: %s" % script, str(exc))

print("RESULT: %s (%d failure(s))" % ("PASS" if failures == 0 else "FAIL", failures))
sys.exit(0 if failures == 0 else 1)
