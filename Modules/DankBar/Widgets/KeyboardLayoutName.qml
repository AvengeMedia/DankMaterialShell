import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Modules.ProcessList
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    property bool isVertical: axis?.isVertical ?? false
    property var axis: null
    property real widgetThickness: 30
    property real barThickness: 48
    readonly property real horizontalPadding: SettingsData.dankBarNoBackground ? 0 : Math.max(Theme.spacingXS, Theme.spacingS * (widgetThickness / 30))
    property string currentLayout: ""
    property string hyprlandKeyboard: ""

    width: isVertical ? widgetThickness : (contentRow.implicitWidth + horizontalPadding * 2)
    height: isVertical ? (contentColumn.implicitHeight + horizontalPadding * 2) : widgetThickness
    radius: SettingsData.dankBarNoBackground ? 0 : Theme.cornerRadius
    color: {
        if (SettingsData.dankBarNoBackground) {
            return "transparent";
        }

        const baseColor = mouseArea.containsMouse ? Theme.widgetBaseHoverColor : Theme.widgetBaseBackgroundColor;
        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a * Theme.widgetTransparency);
    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (CompositorService.isNiri) {
                NiriService.cycleKeyboardLayout()
            } else if (CompositorService.isHyprland) {
                Quickshell.execDetached([
                    "hyprctl",
                    "switchxkblayout",
                    root.hyprlandKeyboard,
                    "next"
                ])
                updateLayout()
            }
        }
    }

    Column {
        id: contentColumn

        anchors.centerIn: parent
        spacing: 1
        visible: root.isVertical

        DankIcon {
            name: "keyboard"
            size: Theme.barIconSize(barThickness)
            color: Theme.surfaceText
            anchors.horizontalCenter: parent.horizontalCenter
        }

        StyledText {
            text: {
                if (!currentLayout) return ""
                const parts = currentLayout.split(" ")
                if (parts.length > 0) {
                    return parts[0].substring(0, 2).toUpperCase()
                }
                return currentLayout.substring(0, 2).toUpperCase()
            }
            font.pixelSize: Theme.barTextSize(barThickness)
            font.weight: Font.Medium
            color: Theme.surfaceText
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    Row {
        id: contentRow

        anchors.centerIn: parent
        spacing: Theme.spacingS
        visible: !root.isVertical

        StyledText {
            text: currentLayout
            font.pixelSize: Theme.barTextSize(barThickness)
            color: Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
        }

    }


    Timer {
        id: updateTimer
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            updateLayout()
        }
    }

    Component.onCompleted: {
        updateLayout()
    }

    function updateLayout() {
        if (CompositorService.isNiri) {
            root.currentLayout = NiriService.getCurrentKeyboardLayoutName()
        } else if (CompositorService.isHyprland) {
            Proc.runCommand("hyprlandLayout", ["hyprctl", "-j", "devices"], (output, exitCode) => {
                if (exitCode !== 0) {
                    root.currentLayout = "Unknown"
                    return
                }
                try {
                    const data = JSON.parse(output)
                    const mainKeyboard = data.keyboards.find(kb => kb.main === true)
                    root.hyprlandKeyboard = mainKeyboard.name
                    if (mainKeyboard && mainKeyboard.active_keymap) {
                        root.currentLayout = mainKeyboard.active_keymap
                    } else {
                        root.currentLayout = "Unknown"
                    }
                } catch (e) {
                    root.currentLayout = "Unknown"
                }
            })
        }
    }
}
