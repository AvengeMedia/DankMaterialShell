import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.Common

Item {
    id: root

    property string source: ""
    property int glyphSize: 14
    property bool badgeVisible: true

    readonly property var sourceAsset: ({
            "flatpak": "../../assets/package-sources/flatpak.svg",
            "snap": "../../assets/package-sources/snap.svg",
            "appimage": "../../assets/package-sources/appimage.svg",
            "nix": "../../assets/package-sources/nix.svg",
            "steam": "steam",
            "waydroid": "waydroid"
        })

    readonly property string assetPath: sourceAsset[source] || ""

    visible: badgeVisible && SettingsData.dankLauncherV2ShowSourceBadges && assetPath.length > 0
    implicitWidth: glyphSize
    implicitHeight: glyphSize

    IconImage {
        anchors.fill: parent
        source: {
            if (!root.assetPath) {
                return "";
            }
            if (root.assetPath.indexOf("/") !== -1) {
                return Qt.resolvedUrl(root.assetPath);
            } else {
                return Quickshell.iconPath(root.assetPath);
            }
        }
        implicitSize: root.glyphSize * 2
        backer.sourceSize: Qt.size(root.glyphSize * 2, root.glyphSize * 2)
        smooth: true
        mipmap: true
        asynchronous: true
    }
}
