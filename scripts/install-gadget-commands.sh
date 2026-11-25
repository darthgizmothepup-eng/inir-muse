#!/bin/sh
# Install the whitelisted `inir.panel` custom command for the Muse Gadget SDK.
#
# This writes one file:
#   /etc/musegadget/commands.d/inir.panel.json
# which tells the musegadget service on this computer that Muse may call
# scripts/inir_action.py. That helper accepts ONLY
#   {"target": "<plugin id>", "function": "toggle" | "open" | "close"}
# and runs `inir <target> <function>`. It is a narrow convenience.
#
# Note, plainly: the Muse Gadget SDK itself also gives the paired Muse
# its own built-in commands (system.run, file.read, file.write,
# device.health) entirely independently of this plugin. Installing or
# removing inir.panel neither grants nor removes those.
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PLUGIN_DIR=$(dirname -- "$SCRIPT_DIR")
ACTION="$PLUGIN_DIR/scripts/inir_action.py"

if [ ! -f "$ACTION" ]; then
    echo "inir_action.py not found at $ACTION" >&2
    exit 1
fi
chmod +x "$ACTION"

sudo mkdir -p /etc/musegadget/commands.d
sudo tee /etc/musegadget/commands.d/inir.panel.json >/dev/null <<EOF
{
  "description": "Open, close or toggle an iNiR panel (plugin) on this computer, for example the Muse panel itself. Whitelisted: no other iNiR action is accepted.",
  "exec": ["python3", "$ACTION"],
  "required": {
    "target": {
      "type": "string",
      "description": "The iNiR plugin/panel id, lowercase letters, digits and dashes only, e.g. muse."
    },
    "function": {
      "type": "string",
      "description": "One of toggle, open or close."
    }
  },
  "timeout_ms": 15000
}
EOF

echo "Installed /etc/musegadget/commands.d/inir.panel.json"
echo "Restart the Gadget service so it picks the command up:"
echo "  sudo systemctl restart musegadget"
echo ""
echo "Reminder: the Gadget SDK's built-in commands (system.run, file.read,"
echo "file.write, device.health) exist independently of this plugin, under"
echo "your own pairing. inir.panel is only a whitelisted convenience that"
echo "can toggle, open or close iNiR panels."
