import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets

Popup {
    id: processContextMenu

    property var processData: null

    function show(x, y) {
        if (!processContextMenu.parent && typeof Overlay !== "undefined" && Overlay.overlay) {
            processContextMenu.parent = Overlay.overlay;
        }

        const menuWidth = 180;
        const menuHeight = menuColumn.implicitHeight + Theme.spacingS * 2;
        const screenWidth = Screen.width;
        const screenHeight = Screen.height;
        let finalX = x;
        let finalY = y;
        if (x + menuWidth > screenWidth - 20) {
            finalX = x - menuWidth;
        }

        if (y + menuHeight > screenHeight - 20) {
            finalY = y - menuHeight;
        }

        processContextMenu.x = Math.max(20, finalX);
        processContextMenu.y = Math.max(20, finalY);
        open();
    }

    width: 180
    height: menuColumn.implicitHeight + Theme.spacingS * 2
    padding: 0
    modal: false
    closePolicy: Popup.CloseOnEscape
    onClosed: {
        closePolicy = Popup.CloseOnEscape;
    }
    onOpened: {
        outsideClickTimer.start();
    }

    Timer {
        id: outsideClickTimer

        interval: 100
        onTriggered: {
            processContextMenu.closePolicy = Popup.CloseOnEscape | Popup.CloseOnPressOutside;
        }
    }

    background: Rectangle {
        color: "transparent"
    }

    contentItem: Rectangle {
        id: menuContent

        color: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
        radius: Theme.cornerRadius
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
        border.width: 1

        Column {
            id: menuColumn

            anchors.fill: parent
            anchors.margins: Theme.spacingS
            spacing: 1

            Rectangle {
                width: parent.width
                height: 28
                radius: Theme.cornerRadius
                color: copyPidArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"

                StyledText {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingS
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.tr("Copy PID")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                    font.weight: Font.Normal
                }

                MouseArea {
                    id: copyPidArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (processContextMenu.processData) {
                            Quickshell.execDetached(["wl-copy", processContextMenu.processData.pid.toString()]);
                        }

                        processContextMenu.close();
                    }
                }

            }

            Rectangle {
                width: parent.width
                height: 28
                radius: Theme.cornerRadius
                color: copyNameArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"

                StyledText {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingS
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.tr("Copy Process Name")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                    font.weight: Font.Normal
                }

                MouseArea {
                    id: copyNameArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (processContextMenu.processData) {
                            const processName = processContextMenu.processData.displayName || processContextMenu.processData.command;
                            Quickshell.execDetached(["wl-copy", processName]);
                        }
                        processContextMenu.close();
                    }
                }

            }

            Rectangle {
                width: parent.width - Theme.spacingS * 2
                height: 5
                anchors.horizontalCenter: parent.horizontalCenter
                color: "transparent"

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width
                    height: 1
                    color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                }

            }

            Rectangle {
                width: parent.width
                height: 28
                radius: Theme.cornerRadius
                color: killArea.containsMouse ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.12) : "transparent"
                enabled: processContextMenu.processData
                opacity: enabled ? 1 : 0.5

                StyledText {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingS
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.tr("Kill Process")
                    font.pixelSize: Theme.fontSizeSmall
                    color: parent.enabled ? (killArea.containsMouse ? Theme.error : Theme.surfaceText) : Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.5)
                    font.weight: Font.Normal
                }

                MouseArea {
                    id: killArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    enabled: parent.enabled
                    onClicked: {
                        if (processContextMenu.processData) {
                            Quickshell.execDetached(["kill", processContextMenu.processData.pid.toString()]);
                        }

                        processContextMenu.close();
                    }
                }

            }

            Rectangle {
                width: parent.width
                height: 28
                radius: Theme.cornerRadius
                color: forceKillArea.containsMouse ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.12) : "transparent"
                enabled: processContextMenu.processData && processContextMenu.processData.pid > 1000
                opacity: enabled ? 1 : 0.5

                StyledText {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingS
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.tr("Force Kill Process")
                    font.pixelSize: Theme.fontSizeSmall
                    color: parent.enabled ? (forceKillArea.containsMouse ? Theme.error : Theme.surfaceText) : Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.5)
                    font.weight: Font.Normal
                }

                MouseArea {
                    id: forceKillArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    enabled: parent.enabled
                    onClicked: {
                        if (processContextMenu.processData) {
                            Quickshell.execDetached(["kill", "-9", processContextMenu.processData.pid.toString()]);
                        }

                        processContextMenu.close();
                    }
                }

            }

        }

    }

}
