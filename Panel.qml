pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.services
import "state"
import "views"

// Muse: chat with your own Muse from iNiR, through the Muse Gadget SDK
// service paired to this computer. The panel is a layer-shell surface docked
// to the right edge, or a floating window when the "windowed" option is on
// (same split as iNiRConnect).
Scope {
    id: root

    LazyLoader {
        active: !MuseState.windowed

        PanelWindow {
            id: panelWin
            visible: MuseState.open
            anchors {
                top: true
                right: true
                bottom: true
            }
            implicitWidth: 440
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.namespace: "quickshell:muse"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: MuseState.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

            MuseChat {
                anchors.fill: parent
            }
        }
    }

    LazyLoader {
        active: MuseState.windowed

        FloatingWindow {
            id: floatWin
            title: Translation.tr("Muse")
            Binding { target: floatWin; property: "visible"; value: MuseState.open }
            color: "#211f1e"
            implicitWidth: 440
            implicitHeight: 640
            minimumSize: Qt.size(340, 420)
            onClosed: MuseState.open = false

            MuseChat {
                anchors.fill: parent
            }
        }
    }

    /// Muse: chat with your Muse, and let it act on this iNiR install.
    ///
    /// ```kdl
    /// Mod+Shift+M { spawn "inir" "muse" "toggle"; }
    /// ```
    IpcHandler {
        target: "muse"
        /// Open the Muse panel, or close it when it is open
        function toggle(): void { MuseState.open = !MuseState.open }
        /// Open the Muse panel
        function open(): void { MuseState.open = true }
        /// Close the Muse panel
        function close(): void { MuseState.open = false }
        /// Check whether the Muse Gadget service on this computer is ready
        function check(): void { MuseState.checkStatus() }
        /// Toggle between panel surface and floating window mode
        function windowed(): void { MuseState.windowed = !MuseState.windowed }
    }
}
