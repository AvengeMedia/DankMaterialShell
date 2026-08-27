pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Modules.DankBar
import qs.Services

Item {
    id: root

    required property var hostWindow
    required property var targetScreen
    required property IslandController controller
    required property var islandSurface
    property real outerGap: 8

    readonly property alias leftInputItem: leftInputEnvelope
    readonly property alias rightInputItem: rightInputEnvelope
    readonly property var referenceBarConfig: {
        SettingsData.barConfigs;
        return SettingsData.islandBarConfig ?? ({});
    }
    readonly property var satelliteConfig: {
        const base = SettingsData.effectiveBarConfigForRender(root.referenceBarConfig, false) ?? root.referenceBarConfig ?? ({});
        if (!root.hostWindow?.usesOverlayLayer)
            return base;
        const next = Object.assign({}, base);
        next.useOverlayLayer = true;
        return next;
    }
    readonly property bool scrollEnabled: satelliteConfig?.scrollEnabled ?? true
    readonly property string scrollXBehavior: satelliteConfig?.scrollXBehavior ?? "column"
    readonly property string scrollYBehavior: satelliteConfig?.scrollYBehavior ?? "workspace"
    readonly property real screenScale: CompositorService.getScreenScale(root.targetScreen)
    readonly property real innerPadding: root.satelliteConfig?.innerPadding ?? 4
    readonly property real widgetThickness: Theme.snap(Math.max(20, 26 + root.innerPadding * 0.6), root.screenScale)
    readonly property real barThickness: Theme.snap(Math.max(root.widgetThickness + root.innerPadding + 4, Theme.barHeight - 4 - (8 - root.innerPadding)), root.screenScale)
    readonly property real satelliteSpacing: root.satelliteConfig?.spacing ?? 4
    readonly property bool edgeAligned: SettingsData.dankIslandSatellitePosition === "edges"
    readonly property real edgeBaseMargin: Math.max(Theme.spacingXS, root.innerPadding * 0.8)
    readonly property real edgeInsetRaw: SettingsData.barInsetPaddingSyncAll ? SettingsData.barInsetPaddingShared : (root.satelliteConfig?.barInsetPadding ?? -1)
    readonly property real edgeInset: Theme.snap(Math.max(0, root.edgeInsetRaw < 0 ? root.edgeBaseMargin : root.edgeInsetRaw), root.screenScale)

    readonly property bool bottomEdge: SettingsData.dankIslandEdge === "bottom"
    readonly property real stripHeight: root.hostWindow?.reservedStripHeight ?? (root.outerGap + root.barThickness)
    readonly property real rowY: {
        const centered = Theme.snap((root.stripHeight - root.barThickness) / 2, root.screenScale);
        return root.bottomEdge ? root.height - root.stripHeight + centered : centered;
    }
    readonly property bool backgroundEnabled: SettingsData.dankIslandSatelliteBackground
    readonly property bool spanEdges: root.edgeAligned
    readonly property real chromePad: Theme.snap(root.innerPadding + Theme.spacingXS, root.screenScale)
    readonly property real chromeInset: root.backgroundEnabled ? root.chromePad : 0
    readonly property real chromeY: root.bottomEdge ? root.height - root.stripHeight : 0
    readonly property real chromeHeight: root.stripHeight
    readonly property real crossEdgeExtension: root.spanEdges ? (root.bottomEdge ? root.height - root.rowY - root.barThickness : root.rowY) : 0
    readonly property bool gothCorners: SettingsData.dankIslandSatelliteGothCorners
    readonly property real chromeOpacity: Math.max(0, Math.min(1, SettingsData.dankIslandSatelliteTransparency))
    readonly property real sweepRadius: Math.max(4, Math.min(64, SettingsData.dankIslandSatelliteSwoopRadius))
    readonly property color chromeBase: {
        if (SettingsData.dankIslandHighContrast)
            return Theme.surfaceContainerHighest;
        switch (SettingsData.dankIslandPalette) {
        case "bright":
            return Theme.surfaceBright;
        case "dim":
            return Theme.surfaceDim;
        }
        return Theme.surfaceContainerHigh;
    }
    readonly property color chromeColor: Theme.withAlpha(root.chromeBase, root.chromeOpacity)
    readonly property bool chromeTranslucent: root.backgroundEnabled && root.chromeOpacity > 0 && root.chromeOpacity < 1
    readonly property real islandOpacity: root.islandSurface?.surfaceOpacity ?? 1
    readonly property bool islandTranslucent: root.islandOpacity > 0 && root.islandOpacity < 1
    readonly property bool tracksIsland: !root.edgeAligned && root.visible
    readonly property bool motionRunning: root.tracksIsland && (root.islandSurface?.motionRunning ?? false)
    readonly property real islandStartX: root.islandSurface?.motionStartBounds.x ?? 0
    readonly property real islandStartRight: root.islandStartX + (root.islandSurface?.motionStartBounds.width ?? 0)
    readonly property real islandTargetX: root.islandSurface?.targetVisualX ?? 0
    readonly property real islandTargetRight: root.islandTargetX + (root.islandSurface?.targetVisualWidth ?? 0)

    readonly property real leftEdgeSpread: root.motionRunning ? Math.abs(root.islandStartX - root.islandTargetX) : 0
    readonly property real rightEdgeSpread: root.motionRunning ? Math.abs(root.islandStartRight - root.islandTargetRight) : 0

    function normalizedWidgets(widgets) {
        return (widgets || []).map((widget, index) => {
            if (typeof widget === "string") {
                return {
                    "widgetId": widget,
                    "id": widget + "_" + index,
                    "enabled": true
                };
            }
            const normalized = Object.assign({}, widget);
            normalized.widgetId = widget.widgetId || widget.id;
            normalized.id = normalized.widgetId + "_" + index;
            normalized.enabled = widget.enabled !== false;
            return normalized;
        });
    }

    visible: SettingsData.dankIslandSatellitesEnabled

    function switchWorkspace(direction) {
        componentProvider.switchWorkspace(direction);
    }

    AxisContext {
        id: satelliteAxis

        edge: SettingsData.dankIslandEdge
    }

    ScriptModel {
        id: emptyWidgetsModel

        values: []
    }

    ScriptModel {
        id: leftWidgetsModel

        values: root.normalizedWidgets(root.referenceBarConfig?.leftWidgets)
    }

    ScriptModel {
        id: rightWidgetsModel

        values: root.normalizedWidgets(root.referenceBarConfig?.rightWidgets)
    }

    QtObject {
        id: satelliteBarWindow

        property var axis: satelliteAxis
        property var screen: root.targetScreen
        property string screenName: root.targetScreen?.name ?? ""
        property real widgetThickness: root.widgetThickness
        property real effectiveBarThickness: root.barThickness
        property bool isVertical: false
        property bool usesFrameBarChrome: false
        property bool hasAdjacentTopBar: false
        property bool hasAdjacentBottomBar: false
        property bool hasAdjacentLeftBar: false
        property bool hasAdjacentRightBar: false
        property var hyprlandOverviewLoader: null
        property var controlCenterButtonRef: null
        property var clockButtonRef: null
        property var systemUpdateButtonRef: null
        property int notificationCount: 0

        signal colorPickerRequested

        function registerBlurWidget(item) {
            root.registerBlurWidget(item);
        }
        function unregisterBlurWidget(item) {
            root.unregisterBlurWidget(item);
        }
    }

    property var _blurWidgetItems: []
    property var _blurRegion: null

    function registerBlurWidget(item) {
        if (root._blurWidgetItems.indexOf(item) >= 0)
            return;
        root._blurWidgetItems = root._blurWidgetItems.concat([item]);
        blurRebuildTimer.restart();
    }

    function unregisterBlurWidget(item) {
        const idx = root._blurWidgetItems.indexOf(item);
        if (idx < 0)
            return;
        const arr = root._blurWidgetItems.slice();
        arr.splice(idx, 1);
        root._blurWidgetItems = arr;
        blurRebuildTimer.restart();
    }

    function rebuildBlur() {
        const old = root._blurRegion;
        if (old) {
            root.hostWindow.BackgroundEffect.blurRegion = null;
            root._blurRegion = null;
            old.destroy();
        }
        if (!BlurService.enabled)
            return;
        const widgets = root._blurWidgetItems.filter(w => w && w.visible && w.width > 0 && w.height > 0);
        const chromes = [leftChrome, rightChrome].filter(c => root.chromeTranslucent && c.visible);
        if (chromes.length === 0 && widgets.length === 0 && !root.islandTranslucent)
            return;
        const region = blurRegionComp.createObject(root.hostWindow);
        if (!region)
            return;
        const subRegions = [];
        if (root.islandTranslucent) {
            const islandSub = blurIslandRegionComp.createObject(region);
            if (islandSub)
                subRegions.push(islandSub);
        }
        for (const chrome of chromes) {
            const body = blurItemRegionComp.createObject(region, {
                w: chrome
            });
            if (body)
                subRegions.push(body);
            if (!root.gothCorners)
                continue;
            for (const isWing of [true, false]) {
                const piece = blurSweepRegionComp.createObject(region, {
                    chrome: chrome,
                    isWing: isWing
                });
                if (piece)
                    subRegions.push(piece);
            }
        }
        for (const w of widgets) {
            const sub = blurItemRegionComp.createObject(region, {
                w: w
            });
            if (sub)
                subRegions.push(sub);
        }
        region.regions = subRegions;
        root._blurRegion = region;
        root.hostWindow.BackgroundEffect.blurRegion = region;
    }

    onChromeTranslucentChanged: blurRebuildTimer.restart()
    onGothCornersChanged: blurRebuildTimer.restart()
    onIslandTranslucentChanged: blurRebuildTimer.restart()
    Component.onCompleted: blurRebuildTimer.restart()

    Connections {
        target: BlurService

        function onEnabledChanged() {
            blurRebuildTimer.restart();
        }
    }

    // Blur regions need republishing after geometry settles, same as WindowBlur's settle kicks
    Connections {
        target: root.islandSurface ?? null

        function onMotionRunningChanged() {
            if (root.islandSurface.motionRunning)
                return;
            blurRebuildTimer.restart();
            blurTrailTimer.restart();
        }
    }

    Timer {
        id: blurTrailTimer

        interval: 96
        onTriggered: root.rebuildBlur()
    }

    Component.onDestruction: {
        if (root._blurRegion && root.hostWindow)
            root.hostWindow.BackgroundEffect.blurRegion = null;
    }

    Timer {
        id: blurRebuildTimer

        interval: 1
        onTriggered: root.rebuildBlur()
    }

    Component {
        id: blurRegionComp

        Region {}
    }

    Component {
        id: blurItemRegionComp

        Region {
            property Item w

            item: w
            radius: Theme.cornerRadius
        }
    }

    Component {
        id: blurIslandRegionComp

        Region {
            x: root.islandSurface?.currentVisualX ?? 0
            y: root.islandSurface?.currentVisualY ?? 0
            width: root.islandSurface?.currentVisualWidth ?? 0
            height: root.islandSurface?.currentVisualHeight ?? 0
            radius: root.islandSurface?.currentSurfaceRadius ?? 0
        }
    }

    Component {
        id: blurSweepRegionComp

        // s×s square at a chrome corner minus a quarter-disc — the fillet the chrome paints
        Region {
            id: piece

            property Item chrome
            property bool isWing

            readonly property real s: piece.chrome.sweepR

            readonly property bool leadsIn: piece.chrome.floating ? piece.isWing : piece.chrome.rightSide

            x: {
                if (piece.chrome.floating)
                    return piece.isWing ? piece.chrome.x - piece.s : piece.chrome.x + piece.chrome.width;
                if (piece.isWing)
                    return piece.chrome.rightSide ? piece.chrome.x + piece.chrome.width - piece.s : piece.chrome.x;
                return piece.chrome.rightSide ? piece.chrome.x - piece.s : piece.chrome.x + piece.chrome.width;
            }
            y: {
                if (piece.isWing && !piece.chrome.floating)
                    return piece.chrome.bottomEdge ? piece.chrome.y - piece.s : piece.chrome.y + piece.chrome.height;
                return piece.chrome.bottomEdge ? piece.chrome.y + piece.chrome.height - piece.s : piece.chrome.y;
            }
            width: piece.s
            height: piece.s

            Region {
                intersection: Intersection.Subtract
                radius: piece.s
                width: piece.s * 2
                height: piece.s * 2
                x: piece.x - (piece.leadsIn ? piece.s : 0)
                y: piece.y - (piece.chrome.bottomEdge ? piece.s : 0)
            }
        }
    }

    DankBarContent {
        id: componentProvider

        width: 0
        height: 0
        visible: false
        barWindow: satelliteBarWindow
        rootWindow: root.hostWindow
        barConfig: root.satelliteConfig
        leftWidgetsModel: emptyWidgetsModel
        centerWidgetsModel: emptyWidgetsModel
        rightWidgetsModel: emptyWidgetsModel
    }

    Item {
        id: leftInputEnvelope

        x: (root.spanEdges ? 0 : (root.motionRunning ? Math.min(root.islandStartX, root.islandTargetX) - SettingsData.dankIslandSatelliteGap - leftInput.width : leftInput.x)) - (root.spanEdges ? 0 : root.chromeInset)
        y: root.spanEdges ? root.chromeY : leftInput.y
        width: root.spanEdges ? (leftInput.width > 0 ? Math.max(0, leftInput.x + leftInput.width + root.chromeInset) : 0) : leftInput.width + root.leftEdgeSpread + root.chromeInset * 2
        height: root.spanEdges ? (leftInput.width > 0 ? root.chromeHeight : 0) : leftInput.height
    }

    Item {
        id: rightInputEnvelope

        readonly property real edgeX: rightInput.width > 0 ? rightInput.x - root.chromeInset : root.width

        x: (root.spanEdges ? edgeX : (root.motionRunning ? Math.min(root.islandStartRight, root.islandTargetRight) + SettingsData.dankIslandSatelliteGap : rightInput.x)) - (root.spanEdges ? 0 : root.chromeInset)
        y: root.spanEdges ? root.chromeY : rightInput.y
        width: root.spanEdges ? Math.max(0, root.width - edgeX) : rightInput.width + root.rightEdgeSpread + root.chromeInset * 2
        height: root.spanEdges ? (rightInput.width > 0 ? root.chromeHeight : 0) : rightInput.height
    }

    IslandSatelliteChrome {
        id: leftChrome

        floating: !root.edgeAligned
        x: root.edgeAligned ? 0 : leftInput.x - root.chromePad
        y: root.chromeY
        width: leftInput.width > 0 ? (root.edgeAligned ? leftInput.x + leftInput.width + root.chromePad : leftInput.width + root.chromePad * 2) : 0
        height: root.chromeHeight
        visible: root.backgroundEnabled && leftInput.width > 0
        fillColor: root.chromeColor
        gothEnabled: root.gothCorners
        sweep: root.sweepRadius
        bottomEdge: root.bottomEdge
        parentScreen: root.targetScreen
        onVisibleChanged: blurRebuildTimer.restart()
    }

    IslandSatelliteChrome {
        id: rightChrome

        rightSide: true
        floating: !root.edgeAligned
        x: rightInput.x - root.chromePad
        y: root.chromeY
        width: rightInput.width > 0 ? (root.edgeAligned ? Math.max(0, root.width - x) : rightInput.width + root.chromePad * 2) : 0
        height: root.chromeHeight
        visible: root.backgroundEnabled && rightInput.width > 0
        fillColor: root.chromeColor
        gothEnabled: root.gothCorners
        sweep: root.sweepRadius
        bottomEdge: root.bottomEdge
        parentScreen: root.targetScreen
        onVisibleChanged: blurRebuildTimer.restart()
    }

    Item {
        id: leftInput

        x: root.edgeAligned ? root.edgeInset : Math.round(root.islandSurface.currentVisualX - SettingsData.dankIslandSatelliteGap - width)
        y: root.rowY
        width: root.visible ? leftWidgetSection.implicitWidth : 0
        height: root.visible ? root.barThickness : 0

        LeftSection {
            id: leftWidgetSection

            anchors.fill: parent
            objectName: "leftSection"
            axis: satelliteAxis
            widgetsModel: leftWidgetsModel
            components: componentProvider.allComponents
            noBackground: root.satelliteConfig?.noBackground ?? false
            parentScreen: root.targetScreen
            widgetThickness: root.widgetThickness
            barThickness: root.barThickness
            barSpacing: root.satelliteSpacing
            barConfig: root.satelliteConfig
            blurBarWindow: satelliteBarWindow
            crossEdgeExtension: root.crossEdgeExtension
        }
    }

    Item {
        id: rightInput

        x: root.edgeAligned ? root.width - root.edgeInset - width : Math.round(root.islandSurface.currentVisualX + root.islandSurface.currentVisualWidth + SettingsData.dankIslandSatelliteGap)
        y: root.rowY
        width: root.visible ? rightWidgetSection.implicitWidth : 0
        height: root.visible ? root.barThickness : 0

        RightSection {
            id: rightWidgetSection

            anchors.fill: parent
            objectName: "rightSection"
            axis: satelliteAxis
            widgetsModel: rightWidgetsModel
            components: componentProvider.allComponents
            noBackground: root.satelliteConfig?.noBackground ?? false
            parentScreen: root.targetScreen
            widgetThickness: root.widgetThickness
            barThickness: root.barThickness
            barSpacing: root.satelliteSpacing
            barConfig: root.satelliteConfig
            blurBarWindow: satelliteBarWindow
            crossEdgeExtension: root.crossEdgeExtension
        }
    }
}
