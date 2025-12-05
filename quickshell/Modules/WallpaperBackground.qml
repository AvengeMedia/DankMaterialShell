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
        id: wallpaperWindow

        required property var modelData

        screen: modelData

        WlrLayershell.layer: WlrLayer.Background
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
            property string transitionType: SessionData.wallpaperTransition
            property string actualTransitionType: transitionType
            property bool isInitialized: false

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
            onTransitionTypeChanged: {
                if (transitionType === "random") {
                    if (SessionData.includedTransitions.length === 0) {
                        actualTransitionType = "none";
                    } else {
                        actualTransitionType = SessionData.includedTransitions[Math.floor(Math.random() * SessionData.includedTransitions.length)];
                    }
                } else {
                    actualTransitionType = transitionType;
                }
            }

            property real transitionProgress: 0
            property real shaderFillMode: getFillMode(SettingsData.wallpaperFillMode)
            property vector4d fillColor: Qt.vector4d(0, 0, 0, 1)
            property real edgeSmoothness: 0.1

            property real wipeDirection: 0
            property real discCenterX: 0.5
            property real discCenterY: 0.5
            property real stripesCount: 16
            property real stripesAngle: 0

            readonly property bool transitioning: transitionAnimation.running
            property bool effectActive: false
            property bool useNextForEffect: false

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
                currentWallpaper.layer.enabled = true;
                nextWallpaper.layer.enabled = true;
                root.useNextForEffect = true;
                root.effectActive = true;
                if (srcCurrent.scheduleUpdate)
                    srcCurrent.scheduleUpdate();
                if (srcNext.scheduleUpdate)
                    srcNext.scheduleUpdate();
                Qt.callLater(() => {
                    transitionAnimation.start();
                });
            }

            function changeWallpaper(newPath, force) {
                if (!force && newPath === currentWallpaper.source)
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

                if (root.transitionType === "random") {
                    if (SessionData.includedTransitions.length === 0) {
                        root.actualTransitionType = "none";
                    } else {
                        root.actualTransitionType = SessionData.includedTransitions[Math.floor(Math.random() * SessionData.includedTransitions.length)];
                    }
                }

                if (root.actualTransitionType === "none") {
                    setWallpaperImmediate(newPath);
                    return;
                }

                if (root.actualTransitionType === "wipe") {
                    root.wipeDirection = Math.random() * 4;
                } else if (root.actualTransitionType === "disc" || root.actualTransitionType === "pixelate" || root.actualTransitionType === "portal") {
                    root.discCenterX = Math.random();
                    root.discCenterY = Math.random();
                } else if (root.actualTransitionType === "stripes") {
                    root.stripesCount = Math.round(Math.random() * 20 + 4);
                    root.stripesAngle = Math.random() * 360;
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
                visible: true
                opacity: 1
                layer.enabled: false
                asynchronous: true
                smooth: true
                cache: true
                sourceSize: Qt.size(root.physicalWidth, root.physicalHeight)
                fillMode: root.getFillMode(SettingsData.wallpaperFillMode)
            }

            Image {
                id: nextWallpaper
                anchors.fill: parent
                visible: true
                opacity: 0
                layer.enabled: false
                asynchronous: true
                smooth: true
                cache: false
                sourceSize: Qt.size(root.physicalWidth, root.physicalHeight)
                fillMode: root.getFillMode(SettingsData.wallpaperFillMode)

                onStatusChanged: {
                    if (status !== Image.Ready)
                        return;
                    if (root.actualTransitionType === "none") {
                        currentWallpaper.source = source;
                        nextWallpaper.source = "";
                        root.transitionProgress = 0.0;
                    } else if (!root.transitioning) {
                        root.startTransition();
                    }
                }
            }

            ShaderEffectSource {
                id: srcCurrent
                sourceItem: root.effectActive ? currentWallpaper : null
                hideSource: root.effectActive
                live: root.effectActive
                mipmap: false
                recursive: false
                textureSize: root.effectActive ? Qt.size(root.physicalWidth, root.physicalHeight) : Qt.size(1, 1)
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

            Loader {
                id: effectLoader
                anchors.fill: parent
                active: root.effectActive
                sourceComponent: {
                    switch (root.actualTransitionType) {
                    case "fade":
                        return fadeComp;
                    case "wipe":
                        return wipeComp;
                    case "disc":
                        return discComp;
                    case "stripes":
                        return stripesComp;
                    case "iris bloom":
                        return irisComp;
                    case "pixelate":
                        return pixelateComp;
                    case "portal":
                        return portalComp;
                    default:
                        return null;
                    }
                }
            }

            Component {
                id: fadeComp
                ShaderEffect {
                    anchors.fill: parent
                    property variant source1: srcCurrent
                    property variant source2: root.useNextForEffect ? srcNext : srcDummy
                    property real progress: root.transitionProgress
                    property real fillMode: root.shaderFillMode
                    property vector4d fillColor: root.fillColor
                    property real imageWidth1: modelData.width
                    property real imageHeight1: modelData.height
                    property real imageWidth2: modelData.width
                    property real imageHeight2: modelData.height
                    property real screenWidth: modelData.width
                    property real screenHeight: modelData.height
                    fragmentShader: Qt.resolvedUrl("../Shaders/qsb/wp_fade.frag.qsb")
                }
            }

            Component {
                id: wipeComp
                ShaderEffect {
                    anchors.fill: parent
                    property variant source1: srcCurrent
                    property variant source2: root.useNextForEffect ? srcNext : srcDummy
                    property real progress: root.transitionProgress
                    property real smoothness: root.edgeSmoothness
                    property real direction: root.wipeDirection
                    property real fillMode: root.shaderFillMode
                    property vector4d fillColor: root.fillColor
                    property real imageWidth1: modelData.width
                    property real imageHeight1: modelData.height
                    property real imageWidth2: modelData.width
                    property real imageHeight2: modelData.height
                    property real screenWidth: modelData.width
                    property real screenHeight: modelData.height
                    fragmentShader: Qt.resolvedUrl("../Shaders/qsb/wp_wipe.frag.qsb")
                }
            }

            Component {
                id: discComp
                ShaderEffect {
                    anchors.fill: parent
                    property variant source1: srcCurrent
                    property variant source2: root.useNextForEffect ? srcNext : srcDummy
                    property real progress: root.transitionProgress
                    property real smoothness: root.edgeSmoothness
                    property real aspectRatio: root.width / root.height
                    property real centerX: root.discCenterX
                    property real centerY: root.discCenterY
                    property real fillMode: root.shaderFillMode
                    property vector4d fillColor: root.fillColor
                    property real imageWidth1: modelData.width
                    property real imageHeight1: modelData.height
                    property real imageWidth2: modelData.width
                    property real imageHeight2: modelData.height
                    property real screenWidth: modelData.width
                    property real screenHeight: modelData.height
                    fragmentShader: Qt.resolvedUrl("../Shaders/qsb/wp_disc.frag.qsb")
                }
            }

            Component {
                id: stripesComp
                ShaderEffect {
                    anchors.fill: parent
                    property variant source1: srcCurrent
                    property variant source2: root.useNextForEffect ? srcNext : srcDummy
                    property real progress: root.transitionProgress
                    property real smoothness: root.edgeSmoothness
                    property real aspectRatio: root.width / root.height
                    property real stripeCount: root.stripesCount
                    property real angle: root.stripesAngle
                    property real fillMode: root.shaderFillMode
                    property vector4d fillColor: root.fillColor
                    property real imageWidth1: modelData.width
                    property real imageHeight1: modelData.height
                    property real imageWidth2: modelData.width
                    property real imageHeight2: modelData.height
                    property real screenWidth: modelData.width
                    property real screenHeight: modelData.height
                    fragmentShader: Qt.resolvedUrl("../Shaders/qsb/wp_stripes.frag.qsb")
                }
            }

            Component {
                id: irisComp
                ShaderEffect {
                    anchors.fill: parent
                    property variant source1: srcCurrent
                    property variant source2: root.useNextForEffect ? srcNext : srcDummy
                    property real progress: root.transitionProgress
                    property real smoothness: root.edgeSmoothness
                    property real centerX: 0.5
                    property real centerY: 0.5
                    property real aspectRatio: root.width / root.height
                    property real fillMode: root.shaderFillMode
                    property vector4d fillColor: root.fillColor
                    property real imageWidth1: modelData.width
                    property real imageHeight1: modelData.height
                    property real imageWidth2: modelData.width
                    property real imageHeight2: modelData.height
                    property real screenWidth: modelData.width
                    property real screenHeight: modelData.height
                    fragmentShader: Qt.resolvedUrl("../Shaders/qsb/wp_iris_bloom.frag.qsb")
                }
            }

            Component {
                id: pixelateComp
                ShaderEffect {
                    anchors.fill: parent
                    property variant source1: srcCurrent
                    property variant source2: root.useNextForEffect ? srcNext : srcDummy
                    property real progress: root.transitionProgress
                    property real smoothness: root.edgeSmoothness
                    property real fillMode: root.shaderFillMode
                    property vector4d fillColor: root.fillColor
                    property real imageWidth1: modelData.width
                    property real imageHeight1: modelData.height
                    property real imageWidth2: modelData.width
                    property real imageHeight2: modelData.height
                    property real screenWidth: modelData.width
                    property real screenHeight: modelData.height
                    property real centerX: root.discCenterX
                    property real centerY: root.discCenterY
                    property real aspectRatio: root.width / root.height
                    fragmentShader: Qt.resolvedUrl("../Shaders/qsb/wp_pixelate.frag.qsb")
                }
            }

            Component {
                id: portalComp
                ShaderEffect {
                    anchors.fill: parent
                    property variant source1: srcCurrent
                    property variant source2: root.useNextForEffect ? srcNext : srcDummy
                    property real progress: root.transitionProgress
                    property real smoothness: root.edgeSmoothness
                    property real aspectRatio: root.width / root.height
                    property real centerX: root.discCenterX
                    property real centerY: root.discCenterY
                    property real fillMode: root.shaderFillMode
                    property vector4d fillColor: root.fillColor
                    property real imageWidth1: modelData.width
                    property real imageHeight1: modelData.height
                    property real imageWidth2: modelData.width
                    property real imageHeight2: modelData.height
                    property real screenWidth: modelData.width
                    property real screenHeight: modelData.height
                    fragmentShader: Qt.resolvedUrl("../Shaders/qsb/wp_portal.frag.qsb")
                }
            }

            NumberAnimation {
                id: transitionAnimation
                target: root
                property: "transitionProgress"
                from: 0.0
                to: 1.0
                duration: root.actualTransitionType === "none" ? 0 : 1000
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
                            currentWallpaper.layer.enabled = false;
                            nextWallpaper.layer.enabled = false;
                            currentWallpaper.cache = true;
                            nextWallpaper.cache = false;
                            root.transitionProgress = 0.0;
                        });
                    });
                }
            }

            MultiEffect {
                anchors.fill: parent
                source: effectLoader.active ? effectLoader.item : (root.actualTransitionType === "none" ? currentWallpaper : null)
                visible: CompositorService.isNiri && SettingsData.blurWallpaperOnOverview && NiriService.inOverview && source !== null
                blurEnabled: true
                blur: 0.8
                blurMax: 75
            }
        }
    }
}
