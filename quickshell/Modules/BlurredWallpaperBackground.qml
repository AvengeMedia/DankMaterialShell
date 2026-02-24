import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Widgets
import qs.Services

Variants {
    model: {
        if (SessionData.isGreeterMode) {
            return Quickshell.screens;
        }
        return SettingsData.getFilteredScreens("wallpaper");
    }

    PanelWindow {
        id: blurWallpaperWindow

        required property var modelData

        screen: modelData

        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "dms:blurwallpaper"
        WlrLayershell.exclusionMode: ExclusionMode.Ignore

        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true

        color: "transparent"

        mask: Region {
            item: Item {}
        }

        Item {
            id: root
            anchors.fill: parent

            function encodeFileUrl(path) {
                if (!path)
                    return "";
                return "file://" + path.split('/').map(s => encodeURIComponent(s)).join('/');
            }

            property string source: SessionData.getMonitorWallpaper(modelData.name) || ""
            property bool isColorSource: source.startsWith("#")

            Connections {
                target: SessionData
                function onIsLightModeChanged() {
                    if (SessionData.perModeWallpaper) {
                        var newSource = SessionData.getMonitorWallpaper(modelData.name) || "";
                        if (newSource !== root.source) {
                            root.source = newSource;
                        }
                    }
                }
            }

            function getFillMode(modeName) {
                switch (modeName) {
                case "Stretch":
                    return Image.Stretch;
                case "Fit":
                case "PreserveAspectFit":
                    return Image.PreserveAspectFit;
                case "Fill":
                case "PreserveAspectCrop":
                    return Image.PreserveAspectCrop;
                case "Tile":
                    return Image.Tile;
                case "TileVertically":
                    return Image.TileVertically;
                case "TileHorizontally":
                    return Image.TileHorizontally;
                case "Pad":
                    return Image.Pad;
                default:
                    return Image.PreserveAspectCrop;
                }
            }

            Component.onCompleted: {
                if (typeof blurWallpaperWindow.updatesEnabled !== "undefined")
                    blurWallpaperWindow.updatesEnabled = Qt.binding(() => root.effectActive || root._renderSettling || currentWallpaper.status === Image.Loading || nextWallpaper.status === Image.Loading);

                if (!source) {
                    root._renderSettling = false;
                }
                isInitialized = true;
            }

            property bool isInitialized: false
            property real transitionProgress: 0
            readonly property bool transitioning: transitionAnimation.running
            property bool effectActive: false
            property bool _renderSettling: true
            property bool useNextForEffect: false

            Connections {
                target: currentWallpaper
                function onStatusChanged() {
                    if (currentWallpaper.status === Image.Ready) {
                        root._renderSettling = true;
                        renderSettleTimer.restart();
                    }
                }
            }

            Timer {
                id: renderSettleTimer
                interval: 100
                onTriggered: root._renderSettling = false
            }

            onSourceChanged: {
                if (!source || source.startsWith("#")) {
                    setWallpaperImmediate("");
                    return;
                }

                const formattedSource = source.startsWith("file://") ? source : encodeFileUrl(source);

                if (!isInitialized || !currentWallpaper.source) {
                    setWallpaperImmediate(formattedSource);
                    isInitialized = true;
                    return;
                }
                if (CompositorService.isNiri && SessionData.isSwitchingMode) {
                    setWallpaperImmediate(formattedSource);
                    return;
                }
                changeWallpaper(formattedSource);
            }

            function setWallpaperImmediate(newSource) {
                transitionAnimation.stop();
                root.transitionProgress = 0.0;
                root.effectActive = false;
                root._renderSettling = true;
                renderSettleTimer.restart();
                currentWallpaper.source = newSource;
                nextWallpaper.source = "";
            }

            function startTransition() {
                root.useNextForEffect = true;
                root.effectActive = true;
                if (srcNext.scheduleUpdate)
                    srcNext.scheduleUpdate();
                transitionDelayTimer.start();
            }

            Timer {
                id: transitionDelayTimer
                interval: 16
                repeat: false
                onTriggered: transitionAnimation.start()
            }

            function changeWallpaper(newPath) {
                if (newPath === currentWallpaper.source)
                    return;
                if (!newPath || newPath.startsWith("#"))
                    return;
                if (root.transitioning) {
                    transitionAnimation.stop();
                    root.transitionProgress = 0;
                    root.effectActive = false;
                    currentWallpaper.source = nextWallpaper.source;
                    nextWallpaper.source = "";
                }
                if (!currentWallpaper.source) {
                    setWallpaperImmediate(newPath);
                    return;
                }

                nextWallpaper.source = newPath;

                if (nextWallpaper.status === Image.Ready)
                    root.startTransition();
            }

            Loader {
                anchors.fill: parent
                active: !root.source || root.isColorSource
                asynchronous: true

                sourceComponent: DankBackdrop {
                    screenName: modelData.name
                }
            }

            readonly property int maxTextureSize: 8192
            property int textureWidth: Math.min(modelData.width, maxTextureSize)
            property int textureHeight: Math.min(modelData.height, maxTextureSize)

            Image {
                id: currentWallpaper
                anchors.fill: parent
                visible: false
                opacity: 1
                asynchronous: true
                smooth: true
                cache: true
                sourceSize: Qt.size(root.textureWidth, root.textureHeight)
                fillMode: root.getFillMode(SessionData.isGreeterMode ? GreetdSettings.wallpaperFillMode : SessionData.getMonitorWallpaperFillMode(modelData.name))
            }

            Image {
                id: nextWallpaper
                anchors.fill: parent
                visible: false
                opacity: 0
                asynchronous: true
                smooth: true
                cache: true
                sourceSize: Qt.size(root.textureWidth, root.textureHeight)
                fillMode: root.getFillMode(SessionData.isGreeterMode ? GreetdSettings.wallpaperFillMode : SessionData.getMonitorWallpaperFillMode(modelData.name))

                onStatusChanged: {
                    if (status !== Image.Ready)
                        return;
                    if (!root.transitioning) {
                        root.startTransition();
                    }
                }
            }

            ShaderEffectSource {
                id: srcNext
                sourceItem: root.effectActive ? nextWallpaper : null
                hideSource: root.effectActive
                live: root.effectActive
                mipmap: false
                recursive: false
                textureSize: Qt.size(root.textureWidth, root.textureHeight)
            }

            Rectangle {
                id: dummyRect
                width: 1
                height: 1
                visible: false
                color: "transparent"
            }

            ShaderEffectSource {
                id: srcDummy
                sourceItem: dummyRect
                hideSource: true
                live: false
                mipmap: false
                recursive: false
            }

            Item {
                id: blurredLayer
                anchors.fill: parent

                MultiEffect {
                    anchors.fill: parent
                    source: currentWallpaper
                    visible: currentWallpaper.source !== ""
                    blurEnabled: true
                    blur: 0.8
                    blurMax: 75
                    opacity: 1 - root.transitionProgress
                    autoPaddingEnabled: false
                }

                MultiEffect {
                    anchors.fill: parent
                    source: root.useNextForEffect ? srcNext : srcDummy
                    visible: nextWallpaper.source !== "" && root.useNextForEffect
                    blurEnabled: true
                    blur: 0.8
                    blurMax: 75
                    opacity: root.transitionProgress
                    autoPaddingEnabled: false
                }
            }

            NumberAnimation {
                id: transitionAnimation
                target: root
                property: "transitionProgress"
                from: 0.0
                to: 1.0
                duration: 1000
                easing.type: Easing.InOutCubic
                onFinished: {
                    if (nextWallpaper.source && nextWallpaper.status === Image.Ready)
                        currentWallpaper.source = nextWallpaper.source;
                    root.useNextForEffect = false;
                    nextWallpaper.source = "";
                    root.transitionProgress = 0.0;
                    root.effectActive = false;
                }
            }
        }
    }
}
