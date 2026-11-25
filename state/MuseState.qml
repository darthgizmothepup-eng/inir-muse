pragma Singleton
pragma ComponentBehavior: Bound

// Muse's own state: the panel's open flag, this plugin's options in
// ~/.config/inir/plugins/muse.json, and the conversation with the user's Muse.
// Talking to Muse goes through scripts/muse_bridge.py, which wraps the Muse
// Gadget SDK's local CLI (`musegadget send-user-msg`). That CLI needs no
// credentials of its own: it rides the paired musegadget service on this
// computer. This plugin never sees the user's SDK token.

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common

Singleton {
    id: root

    property bool open: false

    property alias sessionId: adapter.sessionId
    property alias waitSeconds: adapter.waitSeconds
    property alias windowed: adapter.windowed

    // The conversation, oldest first: { role: "user" | "muse" | "error", text: string }
    property var messages: []
    property bool busy: false
    // "unknown" | "ready" | "missing" | "unpaired-or-error"
    property string status: "unknown"
    property string statusDetail: ""

    property bool _sendAnswered: false

    FileView {
        id: optionsFile
        path: Directories.pluginFile("muse")
        watchChanges: true
        atomicWrites: false
        onFileChanged: optionsFile.reload()
        onAdapterUpdated: optionsFile.writeAdapter()
        onLoadFailed: error => { if (error === FileViewError.FileNotFound) optionsFile.writeAdapter() }
        JsonAdapter {
            id: adapter
            // Empty sessionId: the bridge lets the Gadget service use the
            // user's main Muse chat. Set one to keep this panel in a side chat.
            property string sessionId: ""
            property int waitSeconds: 180
            property bool windowed: false
        }
    }

    function _append(role: string, text: string): void {
        root.messages = root.messages.concat([{ "role": role, "text": text }]);
    }

    function _applyStatus(parsed: var): void {
        const cli = parsed.cli ?? false;
        const service = parsed.service ?? "unknown";
        root.statusDetail = parsed.detail ?? "";
        if (!cli) {
            root.status = "missing";
        } else if (service === "active") {
            root.status = "ready";
        } else {
            root.status = "unpaired-or-error";
        }
    }

    function checkStatus(): void {
        if (checkProc.running)
            return;
        checkProc.running = true;
    }

    function send(text: string): void {
        const trimmed = text.trim();
        if (trimmed.length === 0 || root.busy || sendProc.running)
            return;
        root._append("user", trimmed);
        root.busy = true;
        root._sendAnswered = false;
        const argv = ["python3", Plugins.path("muse", "scripts/muse_bridge.py"),
            "send", "--message", trimmed, "--wait", String(root.waitSeconds)];
        if (root.sessionId.length > 0)
            argv.push("--session-id", root.sessionId);
        sendProc.command = argv;
        sendProc.running = true;
    }

    Process {
        id: checkProc
        command: ["python3", Plugins.path("muse", "scripts/muse_bridge.py"), "check"]
        stdout: SplitParser {
            onRead: data => {
                const line = data.trim();
                if (!line.startsWith("JSON|"))
                    return;
                try {
                    const parsed = JSON.parse(line.slice(5));
                    if (parsed.type === "status")
                        root._applyStatus(parsed);
                } catch (e) {}
            }
        }
        onExited: code => {
            if (root.status === "unknown" && code !== 0) {
                root.status = "unpaired-or-error";
                root.statusDetail = Translation.tr("Could not check the Muse Gadget service.");
            }
        }
    }

    Process {
        id: sendProc
        stdout: SplitParser {
            onRead: data => {
                const line = data.trim();
                if (!line.startsWith("JSON|"))
                    return;
                try {
                    const parsed = JSON.parse(line.slice(5));
                    if (parsed.type === "answer") {
                        root._sendAnswered = true;
                        root._append("muse", parsed.text ?? "");
                    } else if (parsed.type === "error") {
                        root._sendAnswered = true;
                        root._append("error", parsed.error ?? Translation.tr("Muse could not be reached."));
                    }
                } catch (e) {}
            }
        }
        onExited: {
            if (root.busy && !root._sendAnswered)
                root._append("error", Translation.tr("Muse could not be reached."));
            root.busy = false;
        }
    }
}
