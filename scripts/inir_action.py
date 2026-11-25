#!/usr/bin/env python3
"""Whitelisted Muse -> iNiR action, for the Muse Gadget SDK.

Installed as the custom Gadget command `inir.panel` (see
scripts/install-gadget-commands.sh). The Gadget service runs this script
with a JSON object on stdin and reads a JSON object back on stdout; a
non-zero exit is an error.

Only three things can be asked for, and nothing else:

    {"target": "<plugin id>", "function": "toggle" | "open" | "close"}

which runs exactly:  inir <target> <function>

Free-form shell commands are deliberately NOT accepted here. (The Gadget
SDK itself ships its own built-in commands, such as system.run, under the
computer owner's pairing -- this helper neither adds to nor limits those;
it is a narrow convenience on top.)
"""

import json
import re
import subprocess
import sys

ALLOWED_FUNCTIONS = ("toggle", "open", "close")
TARGET_RE = re.compile(r"^[a-z0-9-]+$")


def fail(message):
    sys.stdout.write(json.dumps({"ok": False, "error": message}) + "\n")
    sys.stdout.flush()
    return 1


def main():
    raw = sys.stdin.read()
    try:
        request = json.loads(raw)
    except Exception:
        return fail("Input was not a JSON object.")
    if not isinstance(request, dict):
        return fail("Input was not a JSON object.")

    target = request.get("target")
    function = request.get("function")
    if not isinstance(target, str) or not TARGET_RE.match(target):
        return fail("target must be a plugin id matching ^[a-z0-9-]+$.")
    if function not in ALLOWED_FUNCTIONS:
        return fail("function must be one of: toggle, open, close.")

    try:
        result = subprocess.run(
            ["inir", target, function],
            capture_output=True,
            text=True,
            timeout=15,
        )
    except Exception as exc:
        return fail("Could not run inir: %s" % exc)

    ok = result.returncode == 0
    payload = {
        "ok": ok,
        "target": target,
        "function": function,
        "exitCode": result.returncode,
        "output": (result.stdout or "").strip()[:512],
    }
    if not ok:
        payload["error"] = (result.stderr or "").strip()[:512] or "inir failed."
    sys.stdout.write(json.dumps(payload) + "\n")
    sys.stdout.flush()
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
