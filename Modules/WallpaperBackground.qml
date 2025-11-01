import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.Modules
import qs.Services

Variants {
    model: {
        if (SessionData.isGreeterMode) {
            return Quickshell.screens
        }
        return SettingsData.getFilteredScreens("wallpaper")
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
                        var newSource = SessionData.getMonitorWallpaper(modelData.name) || ""
                        if (newSource !== root.source) {
                            root.source = newSource
                        }
                    }
                }
            }
            onTransitionTypeChanged: {
                if (transitionType === "random") {
                    if (SessionData.includedTransitions.length === 0) {
                        actualTransitionType = "none"
                    } else {
                        actualTransitionType = SessionData.includedTransitions[Math.floor(Math.random() * SessionData.includedTransitions.length)]
                    }
                } else {
                    actualTransitionType = transitionType
                }
            }

            onActualTransitionTypeChanged: {
                if (actualTransitionType === "none") {
                    currentWallpaper.visible = true
                    nextWallpaper.visible = false
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

            property bool hasCurrent: currentWallpaper.status === Image.Ready && !!currentWallpaper.source
            property bool booting: !hasCurrent && nextWallpaper.status === Image.Ready

            function getFillMode(modeName) {
                switch(modeName) {
                    case "Stretch": return Image.Stretch
                    case "Fit":
                    case "PreserveAspectFit": return Image.PreserveAspectFit
                    case "Fill":
                    case "PreserveAspectCrop": return Image.PreserveAspectCrop
                    case "Tile": return Image.Tile
                    case "TileVertically": return Image.TileVertically
                    case "TileHorizontally": return Image.TileHorizontally
                    case "Pad": return Image.Pad
                    default: return Image.PreserveAspectCrop
                }
            }

            Component.onCompleted: {
                if (source) {
                    const formattedSource = source.startsWith("file://") ? source : "file://" + source
                    setWallpaperImmediate(formattedSource)
                }
                isInitialized = true
            }

            onSourceChanged: {
                const isColor = source.startsWith("#")

                if (!source) {
                    setWallpaperImmediate("")
                } else if (isColor) {
                    setWallpaperImmediate("")
                } else {
                    if (!isInitialized || !currentWallpaper.source) {
                        setWallpaperImmediate(source.startsWith("file://") ? source : "file://" + source)
                        isInitialized = true
                    } else {
                        changeWallpaper(source.startsWith("file://") ? source : "file://" + source)
                    }
                }
            }

            function setWallpaperImmediate(newSource) {
                transitionAnimation.stop()
                root.transitionProgress = 0.0
                currentWallpaper.source = newSource
                nextWallpaper.source = ""
                currentWallpaper.visible = true
                nextWallpaper.visible = false
            }

            function changeWallpaper(newPath, force) {
                if (!force && newPath === currentWallpaper.source)
                    return
                if (!newPath || newPath.startsWith("#"))
                    return

                if (root.transitioning) {
                    transitionAnimation.stop()
                    root.transitionProgress = 0
                    currentWallpaper.source = nextWallpaper.source
                    nextWallpaper.source = ""
                }

                // If no current wallpaper, set immediately to avoid scaling issues
                if (!currentWallpaper.source) {
                    setWallpaperImmediate(newPath)
                    return
                }

                // If transition is "none", set immediately
                if (root.transitionType === "random") {
                    if (SessionData.includedTransitions.length === 0) {
                        root.actualTransitionType = "none"
                    } else {
                        root.actualTransitionType = SessionData.includedTransitions[Math.floor(Math.random() * SessionData.includedTransitions.length)]
                    }
                }

                if (root.actualTransitionType === "none") {
                    setWallpaperImmediate(newPath)
                    return
                }

                if (root.actualTransitionType === "wipe") {
                    root.wipeDirection = Math.random() * 4
                } else if (root.actualTransitionType === "disc") {
                    root.discCenterX = Math.random()
                    root.discCenterY = Math.random()
                } else if (root.actualTransitionType === "stripes") {
                    root.stripesCount = Math.round(Math.random() * 20 + 4)
                    root.stripesAngle = Math.random() * 360
                }

                nextWallpaper.source = newPath

                if (nextWallpaper.status === Image.Ready) {
                    transitionAnimation.start()
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

            Rectangle {
                id: transparentRect
                anchors.fill: parent
                color: "transparent"
                visible: false
            }

            ShaderEffectSource {
                id: transparentSource
                sourceItem: transparentRect
                hideSource: true
                live: false
            }

            Image {
                id: currentWallpaper
                anchors.fill: parent
                visible: root.actualTransitionType === "none"
                opacity: 1
                layer.enabled: false
                asynchronous: true
                smooth: true
                cache: true
                fillMode: root.getFillMode(SettingsData.wallpaperFillMode)
            }

            Image {
                id: nextWallpaper
                anchors.fill: parent
                visible: false
                opacity: 0
                layer.enabled: false
                asynchronous: true
                smooth: true
                cache: true
                fillMode: root.getFillMode(SettingsData.wallpaperFillMode)

                onStatusChanged: {
                    if (status !== Image.Ready)
                        return

                    if (root.actualTransitionType === "none") {
                        currentWallpaper.source = source
                        nextWallpaper.source = ""
                        root.transitionProgress = 0.0
                    } else {
                        visible = true
                        if (!root.transitioning) {
                            transitionAnimation.start()
                        }
                    }
                }
            }

            Loader {
                id: effectLoader
                anchors.fill: parent
                active: root.actualTransitionType !== "none" && (root.hasCurrent || root.booting)
                sourceComponent: {
                    switch (root.actualTransitionType) {
                    case "fade":
                        return fadeComp
                    case "wipe":
                        return wipeComp
                    case "disc":
                        return discComp
                    case "stripes":
                        return stripesComp
                    case "iris bloom":
                        return irisComp
                    case "pixelate":
                        return pixelateComp
                    case "portal":
                        return portalComp
                    default:
                        return null
                    }
                }
            }

            Component {
                id: fadeComp
                ShaderEffect {
                    anchors.fill: parent
                    property variant source1: root.hasCurrent ? currentWallpaper : transparentSource
                    property variant source2: nextWallpaper
                    property real progress: root.transitionProgress
                    property real fillMode: root.shaderFillMode
                    property vector4d fillColor: root.fillColor
                    property real imageWidth1: Math.max(1, root.hasCurrent ? source1.sourceSize.width : modelData.width)
                    property real imageHeight1: Math.max(1, root.hasCurrent ? source1.sourceSize.height : modelData.height)
                    property real imageWidth2: Math.max(1, source2.sourceSize.width)
                    property real imageHeight2: Math.max(1, source2.sourceSize.height)
                    property real screenWidth: modelData.width
                    property real screenHeight: modelData.height
                    fragmentShader: Qt.resolvedUrl("../Shaders/qsb/wp_fade.frag.qsb")
                }
            }

            Component {
                id: wipeComp
                ShaderEffect {
                    anchors.fill: parent
                    property variant source1: root.hasCurrent ? currentWallpaper : transparentSource
                    property variant source2: nextWallpaper
                    property real progress: root.transitionProgress
                    property real smoothness: root.edgeSmoothness
                    property real direction: root.wipeDirection
                    property real fillMode: root.shaderFillMode
                    property vector4d fillColor: root.fillColor
                    property real imageWidth1: Math.max(1, root.hasCurrent ? source1.sourceSize.width : modelData.width)
                    property real imageHeight1: Math.max(1, root.hasCurrent ? source1.sourceSize.height : modelData.height)
                    property real imageWidth2: Math.max(1, source2.sourceSize.width)
                    property real imageHeight2: Math.max(1, source2.sourceSize.height)
                    property real screenWidth: modelData.width
                    property real screenHeight: modelData.height
                    fragmentShader: Qt.resolvedUrl("../Shaders/qsb/wp_wipe.frag.qsb")
                }
            }

            Component {
                id: discComp
                ShaderEffect {
                    anchors.fill: parent
                    property variant source1: root.hasCurrent ? currentWallpaper : transparentSource
                    property variant source2: nextWallpaper
                    property real progress: root.transitionProgress
                    property real smoothness: root.edgeSmoothness
                    property real aspectRatio: root.width / root.height
                    property real centerX: root.discCenterX
                    property real centerY: root.discCenterY
                    property real fillMode: root.shaderFillMode
                    property vector4d fillColor: root.fillColor
                    property real imageWidth1: Math.max(1, root.hasCurrent ? source1.sourceSize.width : modelData.width)
                    property real imageHeight1: Math.max(1, root.hasCurrent ? source1.sourceSize.height : modelData.height)
                    property real imageWidth2: Math.max(1, source2.sourceSize.width)
                    property real imageHeight2: Math.max(1, source2.sourceSize.height)
                    property real screenWidth: modelData.width
                    property real screenHeight: modelData.height
                    fragmentShader: Qt.resolvedUrl("../Shaders/qsb/wp_disc.frag.qsb")
                }
            }

            Component {
                id: stripesComp
                ShaderEffect {
                    anchors.fill: parent
                    property variant source1: root.hasCurrent ? currentWallpaper : transparentSource
                    property variant source2: nextWallpaper
                    property real progress: root.transitionProgress
                    property real smoothness: root.edgeSmoothness
                    property real aspectRatio: root.width / root.height
                    property real stripeCount: root.stripesCount
                    property real angle: root.stripesAngle
                    property real fillMode: root.shaderFillMode
                    property vector4d fillColor: root.fillColor
                    property real imageWidth1: Math.max(1, root.hasCurrent ? source1.sourceSize.width : modelData.width)
                    property real imageHeight1: Math.max(1, root.hasCurrent ? source1.sourceSize.height : modelData.height)
                    property real imageWidth2: Math.max(1, source2.sourceSize.width)
                    property real imageHeight2: Math.max(1, source2.sourceSize.height)
                    property real screenWidth: modelData.width
                    property real screenHeight: modelData.height
                    fragmentShader: Qt.resolvedUrl("../Shaders/qsb/wp_stripes.frag.qsb")
                }
            }

            Component {
                id: irisComp
                ShaderEffect {
                    anchors.fill: parent
                    property variant source1: root.hasCurrent ? currentWallpaper : transparentSource
                    property variant source2: nextWallpaper
                    property real progress: root.transitionProgress
                    property real smoothness: root.edgeSmoothness
                    property real centerX: 0.5
                    property real centerY: 0.5
                    property real aspectRatio: root.width / root.height
                    property real fillMode: root.shaderFillMode
                    property vector4d fillColor: root.fillColor
                    property real imageWidth1: Math.max(1, root.hasCurrent ? source1.sourceSize.width : modelData.width)
                    property real imageHeight1: Math.max(1, root.hasCurrent ? source1.sourceSize.height : modelData.height)
                    property real imageWidth2: Math.max(1, source2.sourceSize.width)
                    property real imageHeight2: Math.max(1, source2.sourceSize.height)
                    property real screenWidth: modelData.width
                    property real screenHeight: modelData.height
                    fragmentShader: Qt.resolvedUrl("../Shaders/qsb/wp_iris_bloom.frag.qsb")
                }
            }

            Component {
                id: pixelateComp
                ShaderEffect {
                    anchors.fill: parent
                    property variant source1: root.hasCurrent ? currentWallpaper : transparentSource
                    property variant source2: nextWallpaper
                    property real progress: root.transitionProgress
                    property real smoothness: root.edgeSmoothness
                    property real fillMode: root.shaderFillMode
                    property vector4d fillColor: root.fillColor
                    property real imageWidth1: Math.max(1, root.hasCurrent ? source1.sourceSize.width : modelData.width)
                    property real imageHeight1: Math.max(1, root.hasCurrent ? source1.sourceSize.height : modelData.height)
                    property real imageWidth2: Math.max(1, source2.sourceSize.width)
                    property real imageHeight2: Math.max(1, source2.sourceSize.height)
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
                    property variant source1: root.hasCurrent ? currentWallpaper : transparentSource
                    property variant source2: nextWallpaper
                    property real progress: root.transitionProgress
                    property real smoothness: root.edgeSmoothness
                    property real aspectRatio: root.width / root.height
                    property real centerX: root.discCenterX
                    property real centerY: root.discCenterY
                    property real fillMode: root.shaderFillMode
                    property vector4d fillColor: root.fillColor
                    property real imageWidth1: Math.max(1, root.hasCurrent ? source1.sourceSize.width : modelData.width)
                    property real imageHeight1: Math.max(1, root.hasCurrent ? source1.sourceSize.height : modelData.height)
                    property real imageWidth2: Math.max(1, source2.sourceSize.width)
                    property real imageHeight2: Math.max(1, source2.sourceSize.height)
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
                    Qt.callLater(() => {
                                        if (nextWallpaper.source && nextWallpaper.status === Image.Ready && !nextWallpaper.source.toString().startsWith("#")) {
                                            currentWallpaper.source = nextWallpaper.source
                                        }
                                        nextWallpaper.source = ""
                                        nextWallpaper.visible = false
                                        currentWallpaper.visible = root.actualTransitionType === "none"
                                        root.transitionProgress = 0.0
                                    })
                }
            }

            MultiEffect {
                anchors.fill: parent
                source: effectLoader.active ? effectLoader.item : (root.actualTransitionType === "none" ? currentWallpaper : null)
                visible: CompositorService.isNiri && SettingsData.blurWallpaperOnOverview && NiriService.inOverview
                blurEnabled: true
                blur: 0.8
                blurMax: 75
            }
        }
    }
}
