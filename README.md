# Muse for iNiR

A native [iNiR](https://github.com/snowarch/inir) Hub component that connects
iNiR to **your own Muse**, in both directions:

1. **You → Muse, from inside iNiR.** A panel (layer-shell surface, or a
   floating window if you prefer) where you chat with your Muse. It is your
   Muse — your memory, your chats, your agent — not a raw model behind an
   API key.
2. **Muse → your iNiR.** Because the connection runs through the Muse
   Gadget SDK service paired to *your* computer, your Muse can act on this
   machine when you ask it to — and an optional whitelisted gadget command,
   `inir.panel`, lets it toggle, open or close iNiR panels in a narrow,
   predictable way.

The plugin holds **no SDK token and no API key**. Pairing belongs to the
computer's owner and happens once, in the Muse app.

## Requirements

- iNiR 2.33.0 or newer, with the `iris`, `ii` or `waffle` panel family
- A Muse account
- The **Muse Gadget SDK for Linux** installed and paired on the same
  computer (see below) — this provides the `musegadget` command and service
- `python3` (already an iNiR dependency in practice)

## How it works

```
Panel.qml ── state/MuseState.qml ── Process + SplitParser ("JSON|" lines)
                                          │
                                scripts/muse_bridge.py
                                          │
                          musegadget send-user-msg --wait …
                                          │
                        the paired musegadget service ──► your Muse

your Muse ──► musegadget service ──► custom command inir.panel
                                          │
                                scripts/inir_action.py
                                          │
                                inir <target> toggle|open|close
```

`muse_bridge.py check` reports whether the `musegadget` CLI exists and
whether its service is active; the panel shows a setup card instead of the
chat until both are true. `muse_bridge.py send` delivers your message with
`musegadget send-user-msg` and prints Muse's answer back as one `JSON|`
line. Plugin options live where iNiR keeps them, in
`~/.config/inir/plugins/muse.json`:

| Option        | Default | Meaning                                             |
|---------------|---------|-----------------------------------------------------|
| `sessionId`   | `""`    | Empty = your main Muse chat. Set a UUID to keep the panel in that side chat. |
| `waitSeconds` | `180`   | How long to wait for Muse's answer.                |
| `windowed`    | `false` | Floating window instead of a layer-shell panel.     |

Toggle modes from a terminal or a keybind:

```sh
inir muse toggle     # open/close the panel
inir muse windowed   # switch panel <-> window
inir muse check      # re-check the Gadget service
```

## Install

### Via the Hub

Once this component is accepted into the iNiR Hub:

```sh
inir hub install muse
```

### Manual install

```sh
cp -r muse ~/.local/share/inir/plugins/muse
ln -s ~/.local/share/inir/plugins/muse ~/.config/quickshell/inir/modules/muse
echo "muse" >> ~/.config/quickshell/inir/plugins.list
```

Then reload the shell (or restart it). Remove any duplicate `muse` line from
`plugins.list` if you add it twice — the Hub rewrites that file when it links
plugins itself.

## Pair the Muse Gadget SDK

The panel's setup card walks you through the same steps:

1. Go to **gadgets.muse.ai** and create an **SDK token** under
   Account → SDK tokens. Every gadget needs one, including ones you build
   for yourself.
2. Install the Linux SDK on this computer with your token:

   ```sh
   bash install.sh --sdk-token mgst_…
   ```

   This installs into `/opt/musegadget` and starts the `musegadget` systemd
   service. The token is stored root-only in `/var/lib/musegadget/sdk_token`.
3. Pair in the Muse app: **Settings → Devices → Developer mode → Add
   Device**. The computer appears as `MuseGadgetXXXXXX`. Pairing stays open
   for about 10 minutes after install; re-open it later with
   `sudo musegadget pair`.
4. Open the Muse panel in iNiR and press **Check again**. When the service
   is running, the chat appears.

## Let Muse act on iNiR: the `inir.panel` gadget command

Optional, recommended. This installs one Gadget SDK custom command:

```sh
sh scripts/install-gadget-commands.sh
sudo systemctl restart musegadget
```

That writes `/etc/musegadget/commands.d/inir.panel.json`, pointing at this
plugin's `scripts/inir_action.py`. The command accepts exactly:

```json
{ "target": "muse", "function": "toggle" }
```

- `target` must match `^[a-z0-9-]+$` (a plugin/panel id)
- `function` must be one of `toggle`, `open`, `close`
- anything else is rejected with an error

and runs exactly `inir <target> <function>`. So your Muse can be asked, in
ordinary chat, to "open my notes panel" or "close the Muse panel", and this
is the narrow path it uses. To remove it, delete that one JSON file and
restart `musegadget`.

## Security, plainly

- **Pairing is the powerful step, and it belongs to the Gadget SDK, not to
  this plugin.** A paired Muse can run the Gadget SDK's own built-in
  commands on this computer — `system.run`, `file.read`, `file.write`,
  `device.health` — *as your account*. If your account can use sudo, so can
  Muse through that service. Only pair computers you mean to give that
  access, and revoke a pairing/token in the Muse app if you change your
  mind. Installing or removing this plugin neither grants nor removes any
  of that.
- **This plugin holds no token and no API key.** It never sees your SDK
  token. Its helper talks to the already-paired local service, which needs
  no credentials of its own.
- **The panel can only send messages and read answers.** Its one declared
  iNiR permission is `process`, used to run `scripts/muse_bridge.py`.
- **`inir.panel` is whitelisted** to `toggle` / `open` / `close` on
  plugin-id-shaped targets. It accepts no shell strings and no other iNiR
  actions. It is a convenience layered on top of the Gadget SDK, not a
  sandbox around it — see the first point.
- Messages you send from the panel go into your Muse chat (the main chat,
  or the side chat named by `sessionId`). Treat it like typing in Muse,
  because it is.

## Development

```sh
python3 tools/validate.py   # JSON parses, qmldir targets exist, scripts compile
python3 scripts/muse_bridge.py check   # one JSON| status line, even with no SDK installed
echo '{"target":"muse","function":"toggle"}' | python3 scripts/inir_action.py
```

Layout:

```
plugin.json            Hub manifest (id "muse", kind "component")
Panel.qml              Scope, panel/window hosts, IpcHandler "muse"
qmldir
state/MuseState.qml    Singleton: options, status, conversation, bridge processes
state/qmldir
views/MuseChat.qml     The chat card UI
views/qmldir
scripts/muse_bridge.py     Panel -> musegadget CLI
scripts/inir_action.py     Gadget command -> inir (whitelisted)
scripts/install-gadget-commands.sh
translations/en_US.json
icon.svg
tools/validate.py
```

## Submitting to the iNiR Hub

1. Fork `github.com/snowarch/inir-hub`.
2. Place this folder at `components/muse/` in the fork (the repository root
   of this project *is* the plugin root).
3. From the hub repo checkout, run what CI will run:

   ```sh
   inir hub validate
   inir hub check
   ```

4. Open a pull request (or use `inir hub submit`, which does the PR for
   you; try `inir hub submit --dry-run` first).

## License

MIT — see [LICENSE](LICENSE). Copyright (c) 2026 Gizmo
(darthgizmothepup-eng).
