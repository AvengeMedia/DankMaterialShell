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

    readonly property real horizontalPadding: SettingsData.topBarNoBackground ? 0 : Math.max(Theme.spacingXS, Theme.spacingS * (widgetHeight / 30))
    property string currentLayout: ""
    property string hyprlandKeyboard: ""

    width: contentRow.implicitWidth + horizontalPadding * 2
    height: widgetHeight
    radius: SettingsData.topBarNoBackground ? 0 : Theme.cornerRadius
    color: {
        if (SettingsData.topBarNoBackground) {
            return "transparent";
        }

        const baseColor = mouseArea.containsMouse ? Theme.primaryPressed : Theme.secondaryHover;
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

    Row {
        id: contentRow

        anchors.centerIn: parent
        spacing: Theme.spacingS

        StyledText {
            text: currentLayout
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
        }

    }

    Behavior on color {
        ColorAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }

    }

    Process {
        id: hyprlandLayoutProcess
        running: false
        command: ["hyprctl", "-j", "devices"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text)
                    // Find the main keyboard and get its active keymap
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
            }
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
            hyprlandLayoutProcess.running = true
        }
    }
}
