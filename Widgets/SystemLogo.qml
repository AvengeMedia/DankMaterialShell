import QtQuick
import QtQuick.Effects
import Quickshell
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

    Component.onCompleted: {
        Proc.runCommand(null, ["sh", "-c", ". /etc/os-release && echo $LOGO"], (output, exitCode) => {
            if (exitCode !== 0) return
            const logo = output.trim()
            if (logo === "cachyos") {
                source = "file:///usr/share/icons/cachyos.svg"
                return
            }
	    else if (logo === "guix-icon")
	    {
		source = "file:///run/current-system/profile/share/icons/hicolor/scalable/apps/guix-icon.svg"
		return
	    }
            source = Quickshell.iconPath(logo, true)
        }, 0)
    }

    layer.effect: MultiEffect {
        colorization: 1
        colorizationColor: colorOverride
        brightness: brightnessOverride
        contrast: contrastOverride
    }
}
