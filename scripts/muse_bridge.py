#!/usr/bin/env python3
"""Bridge between the Muse iNiR panel and the Muse Gadget SDK.

The panel (state/MuseState.qml) runs this script through Quickshell's
Process + SplitParser and only understands lines starting with "JSON|".
Every handled outcome -- success, missing CLI, dead service, timeout -- is
reported as exactly one such line on stdout, and handled errors exit 0 so
the QML parser always gets its line. Nothing here needs a credential: the
`musegadget` CLI talks to the paired Gadget service on this computer over
its local socket.

Subcommands:
    check   -> {"type": "status", "cli": bool,
                "service": "active" | "inactive" | "unknown", "detail": str}
    send    -> {"type": "answer", "text": str}
               or {"type": "error", "error": str}
"""

import argparse
import json
import shutil
import subprocess
import sys


def emit(payload):
    sys.stdout.write("JSON|" + json.dumps(payload) + "\n")
    sys.stdout.flush()


def service_state():
    """Best-effort `systemctl is-active musegadget`; never raises."""
    try:
        result = subprocess.run(
            ["systemctl", "is-active", "musegadget"],
            capture_output=True,
            text=True,
            timeout=5,
        )
        state = (result.stdout or "").strip()
        if state == "active":
            return "active"
        if state in ("inactive", "failed", "activating", "deactivating"):
            return "inactive"
        return "unknown"
    except Exception:
        return "unknown"


def do_check(_args):
    cli = shutil.which("musegadget") is not None
    if not cli:
        emit({
            "type": "status",
            "cli": False,
            "service": "unknown",
            "detail": "The musegadget command was not found on this computer.",
        })
        return 0
    service = service_state()
    if service == "active":
        detail = "The Muse Gadget service is running."
    elif service == "inactive":
        detail = "The musegadget service is installed but not running."
    else:
        detail = "Could not tell whether the musegadget service is running."
    emit({"type": "status", "cli": True, "service": service, "detail": detail})
    return 0


def do_send(args):
    cli = shutil.which("musegadget")
    if cli is None:
        emit({"type": "error",
              "error": "The musegadget command was not found on this computer."})
        return 0
    wait = max(1, int(args.wait))
    cmd = [cli, "send-user-msg", "--wait", str(wait)]
    if args.session_id:
        cmd += ["--session-id", args.session_id]
    cmd.append(args.message)
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=wait + 30,
        )
    except subprocess.TimeoutExpired:
        emit({"type": "error",
              "error": "Muse did not answer in time. Try again, or raise "
                       "waitSeconds in the plugin options."})
        return 0
    except Exception as exc:  # spawn failure etc.
        emit({"type": "error", "error": "Could not run musegadget: %s" % exc})
        return 0
    text = (result.stdout or "").strip()
    if result.returncode != 0:
        detail = (result.stderr or "").strip() or text
        emit({"type": "error",
              "error": "musegadget reported an error: %s" % (detail or "unknown error")})
        return 0
    if not text:
        emit({"type": "error", "error": "Muse returned an empty answer."})
        return 0
    emit({"type": "answer", "text": text})
    return 0


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("check", help="Report Gadget CLI/service status")

    send = sub.add_parser("send", help="Send a message to the user's Muse")
    send.add_argument("--message", required=True)
    send.add_argument("--wait", type=int, default=180)
    send.add_argument("--session-id", default="")

    args = parser.parse_args(argv)
    try:
        if args.command == "check":
            return do_check(args)
        return do_send(args)
    except Exception as exc:  # last resort: still one JSON| line, no traceback
        emit({"type": "error", "error": "Bridge error: %s" % exc})
        return 0


if __name__ == "__main__":
    sys.exit(main())
