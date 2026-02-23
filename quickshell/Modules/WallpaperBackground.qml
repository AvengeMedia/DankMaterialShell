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

            property string scrollMode: SettingsData.wallpaperFillMode
            property bool scrollingEnabled: scrollMode === "Scrolling"
            property bool isVerticalScrolling: CompositorService.isNiri
            property int currentWorkspaceIndex: 0
            property int totalWorkspaces: 1
            property bool effectiveScrolling: scrollingEnabled && totalWorkspaces > 1

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

            Connections {
                target: NiriService
                enabled: CompositorService.isNiri && root.scrollingEnabled

                function onAllWorkspacesChanged() {
                    root.updateWorkspaceData();
                }
            }

            Connections {
                target: CompositorService.isHyprland ? Hyprland : null
                enabled: CompositorService.isHyprland && root.scrollingEnabled

                function onRawEvent(event) {
                    if (event.name === "workspace" || event.name === "workspacev2") {
                        root.updateWorkspaceData();
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
            property bool useNextForEffect: false
            property string pendingWallpaper: ""

            function getFillMode(modeName) {
                switch (modeName) {
                case "Scrolling":
                    return Image.Pad;
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

            function updateWorkspaceData() {
                if (!scrollingEnabled) return;

                let newTargetX = 50.0;
                let newTargetY = 50.0;

                if (CompositorService.isNiri) {
                    const outputWorkspaces = NiriService.allWorkspaces.filter(
                        ws => ws.output === modelData.name
                    );
                    totalWorkspaces = outputWorkspaces.length;

                    const activeWs = outputWorkspaces.find(ws => ws.is_active);
                    currentWorkspaceIndex = activeWs ? activeWs.idx : 0;

                    const scrollPercent = totalWorkspaces > 1
                        ? ((currentWorkspaceIndex - 1) / (totalWorkspaces - 1)) * 100.0
                        : 0.0;

                    newTargetY = scrollPercent;
                } else if (CompositorService.isHyprland) {
                    const workspaces = Hyprland.workspaces?.values || [];
                    const monitorWorkspaces = workspaces.filter(
                        ws => ws.monitor?.name === modelData.name
                    ).sort((a, b) => a.id - b.id);

                    totalWorkspaces = monitorWorkspaces.length;
                    const focusedId = Hyprland.focusedWorkspace?.id;
                    currentWorkspaceIndex = monitorWorkspaces.findIndex(ws => ws.id === focusedId);

                    if (currentWorkspaceIndex < 0) currentWorkspaceIndex = 0;

                    const scrollPercent = totalWorkspaces > 1
                        ? ((currentWorkspaceIndex - 1) / (totalWorkspaces - 1)) * 100.0
                        : 0.0;

                    newTargetX = scrollPercent;
                }

                scrollAnim.startAnimation(newTargetX, newTargetY);
            }

            QtObject {
                id: scrollAnim
                property real startTime: 0
                property real startX: 50.0
                property real startY: 50.0
                property real targetX: 50.0
                property real targetY: 50.0

                property real damping: CompositorService.isNiri ? 63.25 : 89.44
                property real stiffness: CompositorService.isNiri ? 1000.0 : 2000.0
                property real mass: 1.0

                function springPositionJS(t, from, to) {
                    if (t <= 0) return from;
                    const beta = damping / (2 * mass);
                    const omega0 = Math.sqrt(stiffness / mass);
                    const x0 = from - to;
                    const envelope = Math.exp(-beta * t);
                    if (Math.abs(x0 * envelope) < 0.01) return to;

                    if (Math.abs(beta - omega0) < 0.0001) {
                        return to + envelope * (x0 + beta * x0 * t);
                    } else if (beta < omega0) {
                        const omega1 = Math.sqrt(omega0 * omega0 - beta * beta);
                        return to + envelope * (x0 * Math.cos(omega1 * t) + (beta * x0 / omega1) * Math.sin(omega1 * t));
                    } else {
                        const omega2 = Math.sqrt(beta * beta - omega0 * omega0);
                        const cosh = (x) => (Math.exp(x) + Math.exp(-x)) / 2;
                        const sinh = (x) => (Math.exp(x) - Math.exp(-x)) / 2;
                        return to + envelope * (x0 * cosh(omega2 * t) + (beta * x0 / omega2) * sinh(omega2 * t));
                    }
                }

                function startAnimation(newTargetX, newTargetY) {
                    const now = Date.now() / 1000.0;
                    const t = Math.max(0, frameAnim.currentTime - startTime);
                    const currentX = springPositionJS(t, startX, targetX);
                    const currentY = springPositionJS(t, startY, targetY);

                    if (Math.abs(newTargetX - currentX) < 0.01 && Math.abs(newTargetY - currentY) < 0.01) {
                        return;
                    }

                    startX = currentX;
                    startY = currentY;
                    targetX = newTargetX;
                    targetY = newTargetY;
                    startTime = frameAnim.running ? frameAnim.currentTime : now;
                    if (!frameAnim.running) {
                        frameAnim.currentTime = now;
                        frameAnim.running = true;
                    }
                }
            }

            // CPU-side scroll position - computed once per frame instead of per-pixel in shader
            property real currentScrollX: 50.0
            property real currentScrollY: 50.0

            function publishScrollPosition() {
                if (effectiveScrolling) {
                    SessionData.setMonitorScrollPosition(modelData.name, currentScrollX, currentScrollY);
                } else {
                    // Not scrolling - publish centered (50, 50)
                    SessionData.setMonitorScrollPosition(modelData.name, 50, 50);
                }
            }

            FrameAnimation {
                id: frameAnim
                running: false

                property real currentTime: 0

                onRunningChanged: {
                    if (running) {
                        currentTime = Date.now() / 1000.0;
                    } else {
                        root.publishScrollPosition();  // Animation settled
                    }
                }

                onTriggered: {
                    currentTime += frameTime;

                    const t = currentTime - scrollAnim.startTime;
                    root.currentScrollX = scrollAnim.springPositionJS(t, scrollAnim.startX, scrollAnim.targetX);
                    root.currentScrollY = scrollAnim.springPositionJS(t, scrollAnim.startY, scrollAnim.targetY);

                    const settledX = Math.abs(scrollAnim.targetX - root.currentScrollX) < 0.01;
                    const settledY = Math.abs(scrollAnim.targetY - root.currentScrollY) < 0.01;

                    if (settledX && settledY) {
                        running = false;
                    }
                }
            }

            Component.onCompleted: {
                if (!source) {
                    isInitialized = true;
                    return;
                }
                const formattedSource = source.startsWith("file://") ? source : encodeFileUrl(source);
                setWallpaperImmediate(formattedSource);
                isInitialized = true;

                if (scrollingEnabled) {
                    updateWorkspaceData();
                }

                Qt.callLater(publishScrollPosition);
            }

            Component.onDestruction: {
                SessionData.clearMonitorScrollPosition(modelData.name);
            }

            onScrollingEnabledChanged: {
                if (scrollingEnabled) {
                    updateWorkspaceData();
                } else {
                    frameAnim.stop();
                }
            }

            onEffectiveScrollingChanged: {
                publishScrollPosition();
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
                if (root.transitioning || root.effectActive) {
                    root.pendingWallpaper = newPath;
                    return;
                }
                if (!currentWallpaper.source) {
                    setWallpaperImmediate(newPath);
                    return;
                }

                if (root.effectiveScrolling) {
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
            property real screenScale: CompositorService.getScreenScale(modelData)
            property int textureWidth: Math.min(Math.round(modelData.width * screenScale), maxTextureSize)
            property int textureHeight: Math.min(Math.round(modelData.height * screenScale), maxTextureSize)

            QtObject {
                id: imageMetrics
                property real nativeWidth: 0
                property real nativeHeight: 0
                property bool ready: nativeWidth > 0 && nativeHeight > 0

                function capture(w, h) {
                    if (nativeWidth === 0 && w > 0) {
                        nativeWidth = w;
                        nativeHeight = h;
                    }
                }

                function reset() {
                    nativeWidth = 0;
                    nativeHeight = 0;
                }

                readonly property real canvasWidth: {
                    if (!ready || !root.effectiveScrolling) return root.textureWidth;
                    const imageAspect = nativeWidth / nativeHeight;
                    const screenAspect = root.textureWidth / root.textureHeight;
                    if (imageAspect < screenAspect) {
                        return root.textureWidth;
                    } else {
                        return root.textureHeight * imageAspect;
                    }
                }

                readonly property real canvasHeight: {
                    if (!ready || !root.effectiveScrolling) return root.textureHeight;
                    const imageAspect = nativeWidth / nativeHeight;
                    const screenAspect = root.textureWidth / root.textureHeight;
                    if (imageAspect < screenAspect) {
                        return root.textureWidth / imageAspect;
                    } else {
                        return root.textureHeight;
                    }
                }
            }

            QtObject {
                id: nextImageMetrics
                property real nativeWidth: 0
                property real nativeHeight: 0
                property bool ready: nativeWidth > 0 && nativeHeight > 0

                function capture(w, h) {
                    if (nativeWidth === 0 && w > 0) {
                        nativeWidth = w;
                        nativeHeight = h;
                    }
                }

                function reset() {
                    nativeWidth = 0;
                    nativeHeight = 0;
                }

                readonly property real canvasWidth: {
                    if (!ready || !root.effectiveScrolling) return root.textureWidth;
                    const imageAspect = nativeWidth / nativeHeight;
                    const screenAspect = root.textureWidth / root.textureHeight;
                    if (imageAspect < screenAspect) {
                        return root.textureWidth;
                    } else {
                        return root.textureHeight * imageAspect;
                    }
                }

                readonly property real canvasHeight: {
                    if (!ready || !root.effectiveScrolling) return root.textureHeight;
                    const imageAspect = nativeWidth / nativeHeight;
                    const screenAspect = root.textureWidth / root.textureHeight;
                    if (imageAspect < screenAspect) {
                        return root.textureWidth / imageAspect;
                    } else {
                        return root.textureHeight;
                    }
                }
            }

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

                onStatusChanged: {
                    if (status === Image.Ready) {
                        imageMetrics.capture(implicitWidth, implicitHeight);
                    }
                }

                onSourceChanged: {
                    imageMetrics.reset();
                }
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
                    if (status === Image.Ready) {
                        nextImageMetrics.capture(implicitWidth, implicitHeight);
                    }
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

                onSourceChanged: {
                    nextImageMetrics.reset();
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

            // ============================================================
            // ISOLATED PARALLAX SCROLLING - for performance debugging
            // Bypasses transition effect machinery entirely
            // ============================================================

            Image {
                id: parallaxImage
                visible: false
                width: imageMetrics.canvasWidth
                height: imageMetrics.canvasHeight
                source: root.effectiveScrolling ? currentWallpaper.source : ""
                asynchronous: true
                smooth: true
                cache: true
                sourceSize: Qt.size(imageMetrics.canvasWidth, imageMetrics.canvasHeight)
                fillMode: Image.Stretch
            }

            ShaderEffectSource {
                id: srcParallax
                sourceItem: root.effectiveScrolling && imageMetrics.ready && parallaxImage.status === Image.Ready ? parallaxImage : null
                hideSource: false
                live: false
                mipmap: false
                recursive: false
                textureSize: Qt.size(imageMetrics.canvasWidth, imageMetrics.canvasHeight)
            }

            // Pre-computed UV parameters for shader
            QtObject {
                id: parallaxUV
                readonly property real imageAspect: imageMetrics.ready ? imageMetrics.canvasWidth / imageMetrics.canvasHeight : 1.0
                readonly property real screenAspect: root.textureWidth / root.textureHeight

                // Scale factor to fit image to screen (preserving aspect, cropping excess)
                readonly property real scale: Math.max(root.textureWidth / imageMetrics.canvasWidth, root.textureHeight / imageMetrics.canvasHeight)
                readonly property real scaledWidth: imageMetrics.canvasWidth * scale
                readonly property real scaledHeight: imageMetrics.canvasHeight * scale

                // UV scale: portion of texture visible on screen
                readonly property real uvScaleX: root.textureWidth / scaledWidth
                readonly property real uvScaleY: root.textureHeight / scaledHeight

                // Scroll range: how much UV space we can scroll through
                // Only allow scrolling in the dimension where image exceeds screen
                readonly property real scrollRangeX: imageAspect > screenAspect + 0.01 ? (1.0 - uvScaleX) : (1.0 - uvScaleX) * 0.5
                readonly property real scrollRangeY: imageAspect < screenAspect - 0.01 ? (1.0 - uvScaleY) : (1.0 - uvScaleY) * 0.5
                readonly property bool scrollsHorizontal: imageAspect > screenAspect + 0.01
                readonly property bool scrollsVertical: imageAspect < screenAspect - 0.01
            }

            Loader {
                id: parallaxLoader
                anchors.fill: parent
                active: root.effectiveScrolling && !root.effectActive && imageMetrics.ready && parallaxImage.status === Image.Ready
                sourceComponent: parallaxScrollComp
            }

            Component {
                id: parallaxScrollComp
                ShaderEffect {
                    anchors.fill: parent

                    property variant source: srcParallax.sourceItem ? srcParallax : srcDummy

                    property real scrollX: root.currentScrollX
                    property real scrollY: root.currentScrollY
                    property real uvScaleX: parallaxUV.uvScaleX
                    property real uvScaleY: parallaxUV.uvScaleY
                    property real scrollRangeX: parallaxUV.scrollsHorizontal ? parallaxUV.scrollRangeX : 0.0
                    property real scrollRangeY: parallaxUV.scrollsVertical ? parallaxUV.scrollRangeY : 0.0

                    fragmentShader: Qt.resolvedUrl("../Shaders/qsb/wp_parallax_scroll.frag.qsb")
                }
            }

            // ============================================================
            // Legacy parallax components (kept for transition effects)
            // TODO: Remove once isolated parallax is validated
            // ============================================================

            Image {
                id: parallaxCurrentImage
                visible: false
                width: imageMetrics.canvasWidth
                height: imageMetrics.canvasHeight
                source: "" // Disabled - using parallaxImage instead
                asynchronous: true
                smooth: true
                cache: true
                sourceSize: Qt.size(imageMetrics.canvasWidth, imageMetrics.canvasHeight)
                fillMode: Image.Stretch
            }

            Image {
                id: parallaxNextImage
                visible: false
                width: nextImageMetrics.canvasWidth
                height: nextImageMetrics.canvasHeight
                source: root.effectiveScrolling && nextWallpaper.source ? nextWallpaper.source : ""
                asynchronous: true
                smooth: true
                cache: true
                sourceSize: Qt.size(nextImageMetrics.canvasWidth, nextImageMetrics.canvasHeight)
                fillMode: Image.Stretch
            }

            ShaderEffectSource {
                id: srcParallaxCurrent
                sourceItem: null // Disabled
                hideSource: false
                live: false
                mipmap: false
                recursive: false
                textureSize: Qt.size(imageMetrics.canvasWidth, imageMetrics.canvasHeight)
            }

            ShaderEffectSource {
                id: srcParallaxNext
                sourceItem: null // Disabled
                hideSource: false
                live: false
                mipmap: false
                recursive: false
                textureSize: Qt.size(nextImageMetrics.canvasWidth, nextImageMetrics.canvasHeight)
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
