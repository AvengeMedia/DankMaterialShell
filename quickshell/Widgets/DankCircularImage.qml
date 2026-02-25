import QtQuick
import QtQuick.Window
import QtQuick.Effects
import qs.Common
import qs.Widgets

Rectangle {
    id: root

    property string imageSource: ""
    property string fallbackIcon: "notifications"
    property string fallbackText: ""
    property bool hasImage: imageSource !== ""
    readonly property bool shouldProbe: imageSource !== "" && !imageSource.startsWith("image://")
    // Probe with AnimatedImage first; once loaded, check frameCount to decide.
    readonly property bool isAnimated: shouldProbe && probe.status === Image.Ready && probe.frameCount > 1
    readonly property var activeImage: isAnimated ? probe : staticImage
    property int imageStatus: activeImage.status

    signal imageSaved(string filePath)

    property string _pendingSavePath: ""
    property var _attachedWindow: root.Window.window

    on_AttachedWindowChanged: {
        if (_attachedWindow && _pendingSavePath !== "") {
            Qt.callLater(function () {
                if (root._pendingSavePath !== "") {
                    let path = root._pendingSavePath;
                    root._pendingSavePath = "";
                    root.saveImageToFile(path);
                }
            });
        }
    }

    function saveImageToFile(filePath) {
        if (activeImage.status !== Image.Ready)
            return false;

        if (!activeImage.Window.window) {
            _pendingSavePath = filePath;
            return true;
        }

        activeImage.grabToImage(function (result) {
            if (result && result.saveToFile(filePath)) {
                root.imageSaved(filePath);
            }
        });
        return true;
    }

    radius: width / 2
    color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1)
    border.color: "transparent"
    border.width: 0

    // Probe: loads as AnimatedImage to detect frame count.
    AnimatedImage {
        id: probe
        anchors.fill: parent
        anchors.margins: 2
        asynchronous: true
        fillMode: Image.PreserveAspectCrop
        smooth: true
        mipmap: true
        cache: true
        visible: false
        source: root.shouldProbe ? root.imageSource : ""
    }

    // Static fallback: used once probe confirms the image is not animated.
    Image {
        id: staticImage
        anchors.fill: parent
        anchors.margins: 2
        asynchronous: true
        fillMode: Image.PreserveAspectCrop
        smooth: true
        mipmap: true
        cache: true
        visible: false
        source: !root.shouldProbe ? root.imageSource : ""
    }

    // Once the probe loads, if not animated, hand off to Image and unload probe.
    Connections {
        target: probe
        function onStatusChanged() {
            if (!root.shouldProbe)
                return;
            switch (probe.status) {
            case Image.Ready:
                if (probe.frameCount <= 1) {
                    staticImage.source = root.imageSource;
                    probe.source = "";
                }
                break;
            case Image.Error:
                staticImage.source = root.imageSource;
                probe.source = "";
                break;
            }
        }
    }

    // If imageSource changes, reset: re-probe with AnimatedImage.
    onImageSourceChanged: {
        if (root.shouldProbe) {
            staticImage.source = "";
            probe.source = root.imageSource;
        } else {
            probe.source = "";
            staticImage.source = root.imageSource;
        }
    }

    MultiEffect {
        anchors.fill: parent
        anchors.margins: 2
        source: root.activeImage
        maskEnabled: true
        maskSource: circularMask
        visible: root.activeImage.status === Image.Ready && root.imageSource !== ""
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1
    }

    Item {
        id: circularMask
        anchors.centerIn: parent
        width: parent.width - 4
        height: parent.height - 4
        layer.enabled: true
        layer.smooth: true
        visible: false

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "black"
            antialiasing: true
        }
    }

    AppIconRenderer {
        anchors.centerIn: parent
        width: Math.round(parent.width * 0.75)
        height: width
        visible: (root.activeImage.status !== Image.Ready || root.imageSource === "") && root.fallbackIcon !== ""
        iconValue: root.fallbackIcon
        iconSize: width
        iconColor: Theme.surfaceVariantText
        materialIconSizeAdjustment: 0
        fallbackText: root.fallbackText
        fallbackBackgroundColor: "transparent"
        fallbackTextColor: Theme.surfaceVariantText
    }

    StyledText {
        anchors.centerIn: parent
        visible: root.imageSource === "" && root.fallbackIcon === "" && root.fallbackText !== ""
        text: root.fallbackText
        font.pixelSize: Math.max(12, parent.width * 0.5)
        font.weight: Font.Bold
        color: Theme.surfaceVariantText
    }
}
