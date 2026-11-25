pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import "../state"

// The Muse chat card: header with the Gadget service status, the conversation,
// a message box, and — until the service is ready — the setup steps instead.
// Shown by Panel.qml both as a layer-shell panel and as a floating window.
Item {
    id: root

    readonly property bool ready: MuseState.status === "ready"

    function statusText(): string {
        if (MuseState.status === "ready")
            return Translation.tr("Connected");
        if (MuseState.status === "missing")
            return Translation.tr("Gadget SDK not found");
        if (MuseState.status === "unpaired-or-error")
            return Translation.tr("Gadget service is not running");
        return Translation.tr("Not checked yet");
    }

    function sendCurrent(): void {
        if (input.text.trim().length === 0)
            return;
        MuseState.send(input.text);
        input.text = "";
    }

    Component.onCompleted: MuseState.checkStatus()

    Rectangle {
        anchors.fill: parent
        color: "#211f1e"

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            // Header: name + connection status.
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: Translation.tr("Muse")
                    color: "#f5f2eb"
                    font.pixelSize: 18
                    font.bold: true
                }
                Rectangle {
                    radius: 8
                    color: root.ready ? "#274d2d" : "#4d3427"
                    Layout.preferredWidth: statusLabel.implicitWidth + 16
                    Layout.preferredHeight: statusLabel.implicitHeight + 8
                    Text {
                        id: statusLabel
                        anchors.centerIn: parent
                        text: root.statusText()
                        color: "#f5f2eb"
                        font.pixelSize: 12
                    }
                }
                Item { Layout.fillWidth: true }
            }

            // Onboarding: shown until the Gadget service answers "ready".
            Rectangle {
                visible: !root.ready
                Layout.fillWidth: true
                radius: 10
                color: "#2a2725"
                border.color: "#3a3733"
                implicitHeight: setupColumn.implicitHeight + 24

                ColumnLayout {
                    id: setupColumn
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    Text {
                        Layout.fillWidth: true
                        text: Translation.tr("Set up the Muse Gadget SDK")
                        color: "#f5f2eb"
                        font.pixelSize: 15
                        font.bold: true
                        wrapMode: Text.Wrap
                    }
                    Text {
                        Layout.fillWidth: true
                        text: Translation.tr("1. Install the Muse Gadget SDK for Linux from gadgets.muse.ai using your own SDK token.")
                        color: "#d8d2c9"
                        font.pixelSize: 13
                        wrapMode: Text.Wrap
                    }
                    Text {
                        Layout.fillWidth: true
                        text: Translation.tr("2. Pair this computer in the Muse app: Settings, Devices, Developer mode, Add Device.")
                        color: "#d8d2c9"
                        font.pixelSize: 13
                        wrapMode: Text.Wrap
                    }
                    Text {
                        Layout.fillWidth: true
                        text: Translation.tr("3. Press Check again.")
                        color: "#d8d2c9"
                        font.pixelSize: 13
                        wrapMode: Text.Wrap
                    }
                    Text {
                        visible: MuseState.statusDetail.length > 0
                        Layout.fillWidth: true
                        text: MuseState.statusDetail
                        color: "#a8a29e"
                        font.pixelSize: 12
                        wrapMode: Text.Wrap
                    }
                    RowLayout {
                        spacing: 8
                        Rectangle {
                            radius: 8
                            color: "#6da3da"
                            Layout.preferredWidth: checkLabel.implicitWidth + 20
                            Layout.preferredHeight: checkLabel.implicitHeight + 12
                            Text {
                                id: checkLabel
                                anchors.centerIn: parent
                                text: Translation.tr("Check again")
                                color: "#10151c"
                                font.pixelSize: 13
                                font.bold: true
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: MuseState.checkStatus()
                            }
                        }
                        Rectangle {
                            radius: 8
                            color: "transparent"
                            border.color: "#6da3da"
                            Layout.preferredWidth: openLabel.implicitWidth + 20
                            Layout.preferredHeight: openLabel.implicitHeight + 12
                            Text {
                                id: openLabel
                                anchors.centerIn: parent
                                text: Translation.tr("Open gadgets.muse.ai")
                                color: "#6da3da"
                                font.pixelSize: 13
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: Quickshell.execDetached(["xdg-open", "https://gadgets.muse.ai"])
                            }
                        }
                    }
                }
            }

            // Conversation.
            Text {
                visible: root.ready && MuseState.messages.length === 0
                Layout.fillWidth: true
                text: Translation.tr("No messages yet. Say hello to your Muse.")
                color: "#a8a29e"
                font.pixelSize: 13
                wrapMode: Text.Wrap
            }
            ListView {
                id: messageList
                visible: root.ready
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 8
                model: MuseState.messages
                onCountChanged: positionViewAtEnd()
                delegate: Rectangle {
                    required property var modelData
                    width: ListView.view.width
                    radius: 8
                    color: modelData.role === "user" ? "#2c3e50" : (modelData.role === "error" ? "#5a2d2d" : "#2a2725")
                    implicitHeight: body.implicitHeight + 20
                    Text {
                        id: body
                        anchors.fill: parent
                        anchors.margins: 10
                        text: parent.modelData.text
                        color: "#f5f2eb"
                        font.pixelSize: 13
                        wrapMode: Text.Wrap
                    }
                }
            }

            Text {
                visible: root.ready && MuseState.busy
                Layout.fillWidth: true
                text: Translation.tr("Muse is thinking…")
                color: "#a8a29e"
                font.pixelSize: 12
            }

            // Message box + Send.
            RowLayout {
                visible: root.ready
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 72
                    radius: 8
                    color: "#171615"
                    border.color: input.activeFocus ? "#6da3da" : "#3a3733"

                    Text {
                        visible: input.text.length === 0
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.margins: 10
                        text: Translation.tr("Message Muse")
                        color: "#a8a29e"
                        font.pixelSize: 13
                    }
                    TextEdit {
                        id: input
                        anchors.fill: parent
                        anchors.margins: 10
                        color: "#f5f2eb"
                        font.pixelSize: 13
                        wrapMode: TextEdit.Wrap
                        selectByMouse: true
                    }
                }
                Rectangle {
                    radius: 8
                    color: MuseState.busy ? "#3a3733" : "#6da3da"
                    Layout.preferredWidth: sendLabel.implicitWidth + 20
                    Layout.preferredHeight: sendLabel.implicitHeight + 12
                    Layout.alignment: Qt.AlignBottom
                    Text {
                        id: sendLabel
                        anchors.centerIn: parent
                        text: Translation.tr("Send")
                        color: "#10151c"
                        font.pixelSize: 13
                        font.bold: true
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: !MuseState.busy
                        onClicked: root.sendCurrent()
                    }
                }
            }
        }
    }
}
