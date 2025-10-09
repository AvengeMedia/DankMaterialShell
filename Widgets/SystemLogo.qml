import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.Common

IconImage {
    property string colorOverride: ""
    property real brightnessOverride: 0.5
    property real contrastOverride: 1

    readonly property bool hasColorOverride: colorOverride !== ""

    smooth: true
    asynchronous: true
    layer.enabled: hasColorOverride

    Process {
        running: true
        command: ["sh", "-c", ". /etc/os-release && echo $LOGO"]

        stdout: StdioCollector {
            onStreamFinished: () => {
                if (text.trim() === "cachyos") {
                    source = "file:///usr/share/icons/cachyos.svg"
                    return
                }
                source = Quickshell.iconPath(text.trim(), true)
            }
        }
    }

    layer.effect: MultiEffect {
        colorization: 1
        colorizationColor: colorOverride
        brightness: brightnessOverride
        contrast: contrastOverride
    }
}
