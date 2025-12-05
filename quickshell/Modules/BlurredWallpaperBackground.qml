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
                if (source) {
                    const formattedSource = source.startsWith("file://") ? source : "file://" + source;
                    setWallpaperImmediate(formattedSource);
                }
                isInitialized = true;
            }

            property bool isInitialized: false
            property real transitionProgress: 0
            readonly property bool transitioning: transitionAnimation.running
            property bool effectActive: false
            property bool useNextForEffect: false

            onSourceChanged: {
                const isColor = source.startsWith("#");

                if (!source) {
                    setWallpaperImmediate("");
                } else if (isColor) {
                    setWallpaperImmediate("");
                } else {
                    if (!isInitialized || !currentWallpaper.source) {
                        setWallpaperImmediate(source.startsWith("file://") ? source : "file://" + source);
                        isInitialized = true;
                    } else if (CompositorService.isNiri && SessionData.isSwitchingMode) {
                        setWallpaperImmediate(source.startsWith("file://") ? source : "file://" + source);
                    } else {
                        changeWallpaper(source.startsWith("file://") ? source : "file://" + source);
                    }
                }
            }

            function setWallpaperImmediate(newSource) {
                transitionAnimation.stop();
                root.transitionProgress = 0.0;
                root.effectActive = false;
                currentWallpaper.source = newSource;
                nextWallpaper.source = "";
            }

            function startTransition() {
                currentWallpaper.cache = true;
                nextWallpaper.cache = true;
                root.useNextForEffect = true;
                root.effectActive = true;
                if (srcNext.scheduleUpdate)
                    srcNext.scheduleUpdate();
                Qt.callLater(() => {
                    transitionAnimation.start();
                });
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

                if (nextWallpaper.status === Image.Ready) {
                    root.startTransition();
                }
            }

            Loader {
                anchors.fill: parent
                active: !root.source || root.isColorSource
                asynchronous: true

                sourceComponent: DankBackdrop {
                    screenName: modelData.name
                }
            }

            property real screenScale: CompositorService.getScreenScale(modelData)
            property int physicalWidth: Math.round(modelData.width * screenScale)
            property int physicalHeight: Math.round(modelData.height * screenScale)

            Image {
                id: currentWallpaper
                anchors.fill: parent
                visible: false
                opacity: 1
                asynchronous: true
                smooth: true
                cache: true
                sourceSize: Qt.size(root.physicalWidth, root.physicalHeight)
                fillMode: root.getFillMode(SessionData.isGreeterMode ? GreetdSettings.wallpaperFillMode : SettingsData.wallpaperFillMode)
            }

            Image {
                id: nextWallpaper
                anchors.fill: parent
                visible: false
                opacity: 0
                asynchronous: true
                smooth: true
                cache: false
                sourceSize: Qt.size(root.physicalWidth, root.physicalHeight)
                fillMode: root.getFillMode(SessionData.isGreeterMode ? GreetdSettings.wallpaperFillMode : SettingsData.wallpaperFillMode)

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
                textureSize: root.effectActive ? Qt.size(root.physicalWidth, root.physicalHeight) : Qt.size(1, 1)
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
                    if (nextWallpaper.source && nextWallpaper.status === Image.Ready) {
                        currentWallpaper.source = nextWallpaper.source;
                    }
                    root.useNextForEffect = false;
                    Qt.callLater(() => {
                        nextWallpaper.source = "";
                        Qt.callLater(() => {
                            root.effectActive = false;
                            currentWallpaper.cache = true;
                            nextWallpaper.cache = false;
                            root.transitionProgress = 0.0;
                        });
                    });
                }
            }
        }
    }
}
