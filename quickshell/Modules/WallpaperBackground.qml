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

            function encodeFileUrl(path) {
                if (!path)
                    return "";
                return "file://" + path.split('/').map(s => encodeURIComponent(s)).join('/');
            }

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
                if (transitionType !== "random") {
                    actualTransitionType = transitionType;
                    return;
                }
                actualTransitionType = SessionData.includedTransitions.length === 0 ? "none" : SessionData.includedTransitions[Math.floor(Math.random() * SessionData.includedTransitions.length)];
            }

            property real transitionProgress: 0
            property real shaderFillMode: getFillMode(SessionData.getMonitorWallpaperFillMode(modelData.name))
            property vector4d fillColor: Qt.vector4d(0, 0, 0, 1)
            property real edgeSmoothness: 0.1

            property real wipeDirection: 0
            property real discCenterX: 0.5
            property real discCenterY: 0.5
            property real stripesCount: 16
            property real stripesAngle: 0

            readonly property bool transitioning: transitionAnimation.running
            property bool effectActive: false
            property bool _renderSettling: true
            property bool useNextForEffect: false
            property string pendingWallpaper: ""
            property string _deferredSource: ""

            Connections {
                target: currentWallpaper
                function onStatusChanged() {
                    if (currentWallpaper.status === Image.Ready) {
                        root._renderSettling = true;
                        renderSettleTimer.restart();
                    }
                }
            }

            function _recheckScreenScale() {
                const newScale = CompositorService.getScreenScale(modelData);
                if (newScale !== root.screenScale) {
                    console.info("WallpaperBackground: screen scale corrected for", modelData.name + ":", root.screenScale, "->", newScale);
                    root.screenScale = newScale;
                }
            }

            Connections {
                target: NiriService
                function onDisplayScalesChanged() {
                    root._recheckScreenScale();
                }
            }

            Connections {
                target: WlrOutputService
                function onWlrOutputAvailableChanged() {
                    root._recheckScreenScale();
                }
            }

            Connections {
                target: CompositorService
                function onRandrDataReady() {
                    if (root._deferredSource) {
                        const src = root._deferredSource;
                        root._deferredSource = "";
                        root.setWallpaperImmediate(src);
                    } else {
                        root._recheckScreenScale();
                    }
                }
            }

            Timer {
                id: renderSettleTimer
                interval: 100
                onTriggered: root._renderSettling = false
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
                if (typeof wallpaperWindow.updatesEnabled !== "undefined")
                    wallpaperWindow.updatesEnabled = Qt.binding(() => root.effectActive || root._renderSettling || currentWallpaper.status === Image.Loading || nextWallpaper.status === Image.Loading);

                if (!source) {
                    root._renderSettling = false;
                }
                isInitialized = true;
            }

            onSourceChanged: {
                if (!source || source.startsWith("#")) {
                    setWallpaperImmediate("");
                    return;
                }

                const formattedSource = source.startsWith("file://") ? source : encodeFileUrl(source);

                if (!isInitialized || !currentWallpaper.source) {
                    if (!CompositorService.randrReady) {
                        _deferredSource = formattedSource;
                        return;
                    }
                    setWallpaperImmediate(formattedSource);
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
                root.screenScale = CompositorService.getScreenScale(modelData);
                currentWallpaper.source = newSource;
                nextWallpaper.source = "";
            }

            function startTransition() {
                currentWallpaper.layer.enabled = true;
                nextWallpaper.layer.enabled = true;
                root.useNextForEffect = true;
                root.effectActive = true;
                if (srcCurrent.scheduleUpdate)
                    srcCurrent.scheduleUpdate();
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

            function changeWallpaper(newPath, force) {
                if (!force && newPath === currentWallpaper.source)
                    return;
                if (!newPath || newPath.startsWith("#"))
                    return;
                root.screenScale = CompositorService.getScreenScale(modelData);
                if (root.transitioning || root.effectActive) {
                    root.pendingWallpaper = newPath;
                    return;
                }
                if (!currentWallpaper.source) {
                    setWallpaperImmediate(newPath);
                    return;
                }

                if (root.transitionType === "random") {
                    root.actualTransitionType = SessionData.includedTransitions.length === 0 ? "none" : SessionData.includedTransitions[Math.floor(Math.random() * SessionData.includedTransitions.length)];
                }

                if (root.actualTransitionType === "none") {
                    setWallpaperImmediate(newPath);
                    return;
                }

                switch (root.actualTransitionType) {
                case "wipe":
                    root.wipeDirection = Math.random() * 4;
                    break;
                case "disc":
                case "pixelate":
                case "portal":
                    root.discCenterX = Math.random();
                    root.discCenterY = Math.random();
                    break;
                case "stripes":
                    root.stripesCount = Math.round(Math.random() * 20 + 4);
                    root.stripesAngle = Math.random() * 360;
                    break;
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
            property real screenScale: 1
            property int textureWidth: Math.min(Math.round(modelData.width * screenScale), maxTextureSize)
            property int textureHeight: Math.min(Math.round(modelData.height * screenScale), maxTextureSize)

            Image {
                id: currentWallpaper
                anchors.fill: parent
                visible: true
                opacity: 1
                layer.enabled: false
                asynchronous: true
                smooth: true
                cache: true
                sourceSize: Qt.size(root.textureWidth, root.textureHeight)
                fillMode: root.getFillMode(SessionData.getMonitorWallpaperFillMode(modelData.name))
            }

            Image {
                id: nextWallpaper
                anchors.fill: parent
                visible: source !== ""
                opacity: 0
                layer.enabled: false
                asynchronous: true
                smooth: true
                cache: true
                sourceSize: Qt.size(root.textureWidth, root.textureHeight)
                fillMode: root.getFillMode(SessionData.getMonitorWallpaperFillMode(modelData.name))

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
                textureSize: Qt.size(root.textureWidth, root.textureHeight)
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

            Loader {
                id: effectLoader
                anchors.fill: parent
                active: root.effectActive

                function getTransitionComponent(type) {
                    switch (type) {
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

                sourceComponent: getTransitionComponent(root.actualTransitionType)
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
                    nextWallpaper.source = "";
                    root.transitionProgress = 0.0;
                    currentWallpaper.layer.enabled = false;
                    nextWallpaper.layer.enabled = false;
                    root.effectActive = false;

                    if (!root.pendingWallpaper)
                        return;
                    var pending = root.pendingWallpaper;
                    root.pendingWallpaper = "";
                    Qt.callLater(() => root.changeWallpaper(pending, true));
                }
            }

            Loader {
                anchors.fill: parent
                active: CompositorService.isNiri && SettingsData.blurWallpaperOnOverview && NiriService.inOverview && currentWallpaper.source !== ""

                sourceComponent: MultiEffect {
                    anchors.fill: parent
                    source: effectLoader.active ? effectLoader.item : currentWallpaper
                    blurEnabled: true
                    blur: 0.8
                    blurMax: 75
                    autoPaddingEnabled: false
                }
            }
        }
    }
}
