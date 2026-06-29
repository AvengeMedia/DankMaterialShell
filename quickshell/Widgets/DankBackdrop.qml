import QtQuick
import QtQuick.Effects
import qs.Common

Item {
    id: root

    anchors.fill: parent

    property string screenName: ""
    property bool isColorWallpaper: {
        var currentWallpaper = SessionData.getMonitorWallpaper(screenName);
        return currentWallpaper && currentWallpaper.startsWith("#");
    }

    Rectangle {
        anchors.fill: parent
        color: isColorWallpaper ? SessionData.getMonitorWallpaper(screenName) : Theme.background
    }

    Rectangle {
        x: parent.width * 0.7
        y: -parent.height * 0.3
        width: parent.width * 0.8
        height: parent.height * 1.5
        color: Theme.primaryPressed
        rotation: 35
        visible: !isColorWallpaper
    }

    Rectangle {
        x: parent.width * 0.85
        y: -parent.height * 0.2
        width: parent.width * 0.4
        height: parent.height * 1.2
        color: Theme.secondaryHover
        rotation: 35
        visible: !isColorWallpaper
    }

    Image {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: Theme.spacingXL * 2
        anchors.bottomMargin: Theme.spacingXL * 2
        width: 200
        height: width * (569.94629 / 506.50931)
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        asynchronous: true
        source: "file://" + Theme.shellDir + "/assets/danklogonormal.svg"
        opacity: 0.25
        visible: !isColorWallpaper
        layer.enabled: true
        layer.smooth: true
        layer.mipmap: true
        layer.effect: MultiEffect {
            saturation: 0
            colorization: 1
            colorizationColor: Theme.primary
        }
    }
}
