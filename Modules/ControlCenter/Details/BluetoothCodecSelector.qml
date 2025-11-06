import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property var device: null
    property bool modalVisible: false
    property var parentItem
    property var availableCodecs: []
    property string currentCodec: ""
    property bool isLoading: false

    signal codecSelected(string deviceAddress, string codecName)

    function show(bluetoothDevice) {
        device = bluetoothDevice;
        isLoading = true;
        availableCodecs = [];
        currentCodec = "";
        visible = true;
        modalVisible = true;
        queryCodecs();
        Qt.callLater(() => {
            focusScope.forceActiveFocus();
        });
    }

    function hide() {
        modalVisible = false;
        Qt.callLater(() => {
            visible = false;
        });
    }

    function queryCodecs() {
        if (!device)
            return;

        BluetoothService.getAvailableCodecs(device, function(codecs, current) {
            availableCodecs = codecs;
            currentCodec = current;
            isLoading = false;
        });
    }

    function selectCodec(profileName) {
        if (!device || isLoading)
            return;

        let selectedCodec = availableCodecs.find(c => c.profile === profileName);
        if (selectedCodec && device) {
            BluetoothService.updateDeviceCodec(device.address, selectedCodec.name);
            codecSelected(device.address, selectedCodec.name);
        }

        isLoading = true;
        BluetoothService.switchCodec(device, profileName, function(success, message) {
            isLoading = false;
            if (success) {
                ToastService.showToast(message, ToastService.levelInfo);
                Qt.callLater(root.hide);
            } else {
                ToastService.showToast(message, ToastService.levelError);
            }
        });
    }

    visible: false
    anchors.fill: parent
    z: 2000

    MouseArea {
        id: modalBlocker
        anchors.fill: parent
        visible: modalVisible
        enabled: modalVisible
        hoverEnabled: true
        preventStealing: true
        propagateComposedEvents: false

        onClicked: root.hide()
        onWheel: (wheel) => { wheel.accepted = true }
        onPositionChanged: (mouse) => { mouse.accepted = true }
    }

    Rectangle {
        id: modalBackground
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.5)
        opacity: modalVisible ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.mediumDuration
                easing.type: Theme.emphasizedEasing
            }
        }
    }

    FocusScope {
        id: focusScope

        anchors.fill: parent
        focus: root.visible
        enabled: root.visible

        Keys.onEscapePressed: {
            root.hide()
            event.accepted = true
        }
    }

    Rectangle {
        id: modalContent
        anchors.centerIn: parent
        width: 320
        height: contentColumn.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainer
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
        border.width: 0
        opacity: modalVisible ? 1 : 0
        scale: modalVisible ? 1 : 0.9

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            preventStealing: true
            propagateComposedEvents: false
            onClicked: (mouse) => { mouse.accepted = true }
            onWheel: (wheel) => { wheel.accepted = true }
            onPositionChanged: (mouse) => { mouse.accepted = true }
        }

        Column {
            id: contentColumn

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            Row {
                width: parent.width
                spacing: Theme.spacingM

                DankIcon {
                    name: device ? BluetoothService.getDeviceIcon(device) : "headset"
                    size: Theme.iconSize + 4
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    StyledText {
                        text: device ? (device.name || device.deviceName) : ""
                        font.pixelSize: Theme.fontSizeLarge
                        color: Theme.surfaceText
                        font.weight: Font.Medium
                    }

                    StyledText {
                        text: I18n.tr("Audio Codec Selection")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceTextMedium
                    }

                }

            }

            Rectangle {
                width: parent.width
                height: 1
                color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.05)
            }

            StyledText {
                text: isLoading ? "Loading codecs..." : `Current: ${currentCodec}`
                font.pixelSize: Theme.fontSizeSmall
                color: isLoading ? Theme.primary : Theme.surfaceTextMedium
                font.weight: Font.Medium
            }

            Column {
                width: parent.width
                spacing: Theme.spacingXS
                visible: !isLoading

                Repeater {
                    model: availableCodecs

                    Rectangle {
                        width: parent.width
                        height: 48
                        radius: Theme.cornerRadius
                        color: {
                            if (modelData.name === currentCodec)
                                return Theme.withAlpha(Theme.surfaceContainerHighest, Theme.popupTransparency);
                            else if (codecMouseArea.containsMouse)
                                return Theme.surfaceHover;
                            else
                                return "transparent";
                        }
                        border.color: "transparent"
                        border.width: 0

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingM
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingS

                            Rectangle {
                                width: 6
                                height: 6
                                radius: 3
                                color: modelData.qualityColor
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2

                                StyledText {
                                    text: modelData.name
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: modelData.name === currentCodec ? Theme.primary : Theme.surfaceText
                                    font.weight: modelData.name === currentCodec ? Font.Medium : Font.Normal
                                }

                                StyledText {
                                    text: modelData.description
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceTextMedium
                                }

                            }

                        }

                        DankIcon {
                            name: "check"
                            size: Theme.iconSize - 4
                            color: Theme.primary
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.spacingM
                            anchors.verticalCenter: parent.verticalCenter
                            visible: modelData.name === currentCodec
                        }

                        MouseArea {
                            id: codecMouseArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: modelData.name !== currentCodec && !isLoading
                            onClicked: {
                                selectCodec(modelData.profile);
                            }
                        }


                    }

                }

            }

        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.mediumDuration
                easing.type: Theme.emphasizedEasing
            }

        }

        Behavior on scale {
            NumberAnimation {
                duration: Theme.mediumDuration
                easing.type: Theme.emphasizedEasing
            }

        }

    }
}
