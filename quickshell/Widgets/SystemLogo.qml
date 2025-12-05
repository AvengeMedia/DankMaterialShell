import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import qs.Common
import qs.Widgets

Item {
    id: root

    property string colorOverride: ""
    property real brightnessOverride: 0.5
    property real contrastOverride: 1

    readonly property bool hasColorOverride: colorOverride !== ""

    property bool useNerdFont: false
    property string nerdFontIcon: ""

    IconImage {
        id: iconImage
        anchors.fill: parent
        visible: !root.useNerdFont

        smooth: true
        asynchronous: true
        layer.enabled: hasColorOverride

        layer.effect: MultiEffect {
            colorization: 1
            colorizationColor: colorOverride
            brightness: brightnessOverride
            contrast: contrastOverride
        }
    }

    DankNFIcon {
        id: nfIcon
        anchors.centerIn: parent
        visible: root.useNerdFont
        name: root.nerdFontIcon
        size: Math.min(root.width, root.height)
        color: hasColorOverride ? colorOverride : Theme.surfaceText
    }

    Component.onCompleted: {
        Proc.runCommand(null, ["sh", "-c", ". /etc/os-release && echo $ID"], (output, exitCode) => {
            if (!root || exitCode !== 0 || !output) return
            const distroId = output.trim()
            if (!distroId) return

            const supportedDistroNFs = ["debian", "arch", "archcraft", "fedora", "nixos", "ubuntu", "guix", "gentoo", "endeavouros", "manjaro", "opensuse"]
            if (supportedDistroNFs.includes(distroId)) {
                if (!root) return
                root.useNerdFont = true
                root.nerdFontIcon = distroId
                return
            }

            Proc.runCommand(null, ["sh", "-c", ". /etc/os-release && echo $LOGO"], (logoOutput, logoExitCode) => {
                if (!root || !iconImage || logoExitCode !== 0 || !logoOutput) return
                const logo = logoOutput.trim()
                if (!logo) return

                if (logo === "cachyos") {
                    iconImage.source = "file:///usr/share/icons/cachyos.svg"
                    return
                }
                if (logo === "guix-icon") {
                    iconImage.source = "file:///run/current-system/profile/share/icons/hicolor/scalable/apps/guix-icon.svg"
                    return
                }
                iconImage.source = Quickshell.iconPath(logo, true)
            }, 0)
        }, 0)
    }
}
