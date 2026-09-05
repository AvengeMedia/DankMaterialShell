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
    required property var barConfig
    required property IslandController controller
    required property var islandSurface
    property real outerGap: 8

    function setting(key) {
        return SettingsData.islandSetting(root.barConfig, key);
    }

    readonly property alias leadingInputItem: leadingInputEnvelope
    readonly property alias trailingInputItem: trailingInputEnvelope
    readonly property var referenceBarConfig: root.barConfig ?? ({})
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
    readonly property real widgetThickness: Theme.barWidgetThickness(root.innerPadding, root.screenScale)
    readonly property real barThickness: Theme.barThickness(root.innerPadding, root.screenScale)
    readonly property real satelliteSpacing: root.satelliteConfig?.spacing ?? 4
    readonly property bool edgeAligned: root.setting("islandSatellitePosition") === "edges"
    readonly property real edgeBaseMargin: Math.max(Theme.spacingXS, root.innerPadding * 0.8)
    readonly property real edgeInsetRaw: SettingsData.barInsetPaddingSyncAll ? SettingsData.barInsetPaddingShared : (root.satelliteConfig?.barInsetPadding ?? -1)
    readonly property real edgeInset: Theme.snap(Math.max(0, root.edgeInsetRaw < 0 ? root.edgeBaseMargin : root.edgeInsetRaw), root.screenScale)

    readonly property bool isVertical: root.controller.isVertical
    readonly property bool crossFar: root.controller.edge === "bottom" || root.controller.edge === "right"
    readonly property real alongExtent: root.isVertical ? root.height : root.width
    readonly property real crossExtent: root.isVertical ? root.width : root.height
    readonly property real stripThickness: root.hostWindow?.reservedStripThickness ?? (root.outerGap + root.barThickness)
    readonly property real stripStart: root.crossFar ? root.crossExtent - root.stripThickness : 0
    readonly property real rowCross: root.stripStart + Theme.snap((root.stripThickness - root.barThickness) / 2, root.screenScale)
    readonly property bool backgroundEnabled: root.setting("islandSatelliteBackground")
    readonly property bool spanEdges: root.edgeAligned
    readonly property real chromePad: Theme.snap(root.innerPadding + Theme.spacingXS, root.screenScale)
    readonly property real chromeInset: root.backgroundEnabled ? root.chromePad : 0
    readonly property real crossEdgeExtension: root.spanEdges ? (root.crossFar ? root.crossExtent - root.rowCross - root.barThickness : root.rowCross) : 0
    readonly property bool gothCorners: root.setting("islandSatelliteGothCorners")
    readonly property real chromeOpacity: Math.max(0, Math.min(1, root.setting("islandSatelliteTransparency")))
    readonly property real sweepRadius: Math.max(4, Math.min(64, root.setting("islandSatelliteSwoopRadius")))
    readonly property color chromeBase: {
        if (root.setting("islandHighContrast"))
            return Theme.surfaceContainerHighest;
        switch (root.setting("islandPalette")) {
        case "bright":
            return Theme.surfaceBright;
        case "dim":
            return Theme.surfaceDim;
        }
        return Theme.surfaceContainerHigh;
    }
    readonly property color chromeColor: Theme.withAlpha(root.chromeBase, root.chromeOpacity)
    readonly property bool chromeTranslucent: root.backgroundEnabled && root.chromeOpacity > 0 && root.chromeOpacity < 1
    readonly property bool chromeCoversWidgets: root.backgroundEnabled && root.chromeOpacity > 0
    readonly property real islandOpacity: root.islandSurface?.surfaceOpacity ?? 1
    readonly property bool islandTranslucent: root.islandOpacity > 0 && root.islandOpacity < 1
    readonly property bool tracksIsland: !root.edgeAligned && root.visible
    readonly property bool motionRunning: root.tracksIsland && (root.islandSurface?.motionRunning ?? false)
    readonly property rect islandStartBounds: root.islandSurface?.motionStartBounds ?? Qt.rect(0, 0, 0, 0)
    readonly property real islandStartAlong: root.isVertical ? root.islandStartBounds.y : root.islandStartBounds.x
    readonly property real islandStartAlongEnd: root.islandStartAlong + (root.isVertical ? root.islandStartBounds.height : root.islandStartBounds.width)
    readonly property real islandTargetAlong: root.islandSurface?.targetAlongPos ?? 0
    readonly property real islandTargetAlongEnd: root.islandTargetAlong + (root.islandSurface?.targetVisualAlong ?? 0)
    readonly property real islandCurrentAlong: root.islandSurface?.currentAlongPos ?? 0
    readonly property real islandCurrentAlongEnd: root.islandCurrentAlong + (root.islandSurface?.currentVisualAlong ?? 0)
    readonly property real satelliteGap: root.setting("islandSatelliteGap")

    readonly property real leadingEdgeSpread: root.motionRunning ? Math.abs(root.islandStartAlong - root.islandTargetAlong) : 0
    readonly property real trailingEdgeSpread: root.motionRunning ? Math.abs(root.islandStartAlongEnd - root.islandTargetAlongEnd) : 0

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

    visible: root.setting("islandSatellitesEnabled")

    function switchWorkspace(direction) {
        componentProvider.switchWorkspace(direction);
    }

    AxisContext {
        id: satelliteAxis

        edge: root.controller.edge
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
        property bool isVertical: root.isVertical
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
        const widgets = root.chromeCoversWidgets ? [] : root._blurWidgetItems.filter(w => w && w.visible && w.width > 0 && w.height > 0);
        const chromes = [leadingChrome, trailingChrome].filter(c => root.chromeTranslucent && c.visible);
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
            const body = blurChromeRegionComp.createObject(region, {
                chrome: chrome
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
    onChromeCoversWidgetsChanged: blurRebuildTimer.restart()
    onEdgeAlignedChanged: {
        blurRebuildTimer.restart();
        blurTrailTimer.restart();
    }
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

    function kickBlur() {
        if (root.motionRunning)
            return;
        blurKickTimer.restart();
    }

    Timer {
        id: blurKickTimer

        interval: 1
        onTriggered: {
            if (root._blurRegion)
                root._blurRegion.changed();
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
        id: blurChromeRegionComp

        // The chrome paints square corners at the attached edge (and above the sweep in edge mode); square those blur corners too
        Region {
            id: body

            property Item chrome

            x: body.chrome.x
            y: body.chrome.y
            width: body.chrome.width
            height: body.chrome.height
            radius: body.chrome.cornerR

            Region {
                x: body.x + body.chrome.leadCornerSquare.x
                y: body.y + body.chrome.leadCornerSquare.y
                width: body.chrome.leadCornerSquare.width
                height: body.chrome.leadCornerSquare.height
            }

            Region {
                x: body.x + body.chrome.trailCornerSquare.x
                y: body.y + body.chrome.trailCornerSquare.y
                width: body.chrome.trailCornerSquare.width
                height: body.chrome.trailCornerSquare.height
            }

            Region {
                x: body.x + body.chrome.sweepCornerSquare.x
                y: body.y + body.chrome.sweepCornerSquare.y
                width: body.chrome.sweepCornerSquare.width
                height: body.chrome.sweepCornerSquare.height
            }
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

            readonly property rect body: piece.isWing ? piece.chrome.sweepWingRect : piece.chrome.sweepBodyRect
            readonly property rect disc: piece.isWing ? piece.chrome.sweepWingDisc : piece.chrome.sweepBodyDisc

            x: piece.chrome.x + piece.body.x
            y: piece.chrome.y + piece.body.y
            width: piece.body.width
            height: piece.body.height

            Region {
                intersection: Intersection.Subtract
                radius: piece.chrome.sweepR
                x: piece.chrome.x + piece.disc.x
                y: piece.chrome.y + piece.disc.y
                width: piece.disc.width
                height: piece.disc.height
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
        id: leadingInputEnvelope

        readonly property real alongPos: (root.spanEdges ? 0 : (root.motionRunning ? Math.min(root.islandStartAlong, root.islandTargetAlong) - root.satelliteGap - leadingInput.alongSize : leadingInput.alongPos)) - (root.spanEdges ? 0 : root.chromeInset)
        readonly property real alongSize: root.spanEdges ? (leadingInput.alongSize > 0 ? Math.max(0, leadingInput.alongPos + leadingInput.alongSize + root.chromeInset) : 0) : leadingInput.alongSize + root.leadingEdgeSpread + root.chromeInset * 2
        readonly property real crossPos: root.spanEdges ? root.stripStart : root.rowCross
        readonly property real crossSize: root.spanEdges ? (leadingInput.alongSize > 0 ? root.stripThickness : 0) : leadingInput.crossSize

        x: root.isVertical ? crossPos : alongPos
        y: root.isVertical ? alongPos : crossPos
        width: root.isVertical ? crossSize : alongSize
        height: root.isVertical ? alongSize : crossSize
    }

    Item {
        id: trailingInputEnvelope

        readonly property real edgeAlong: trailingInput.alongSize > 0 ? trailingInput.alongPos - root.chromeInset : root.alongExtent
        readonly property real alongPos: (root.spanEdges ? edgeAlong : (root.motionRunning ? Math.min(root.islandStartAlongEnd, root.islandTargetAlongEnd) + root.satelliteGap : trailingInput.alongPos)) - (root.spanEdges ? 0 : root.chromeInset)
        readonly property real alongSize: root.spanEdges ? Math.max(0, root.alongExtent - edgeAlong) : trailingInput.alongSize + root.trailingEdgeSpread + root.chromeInset * 2
        readonly property real crossPos: root.spanEdges ? root.stripStart : root.rowCross
        readonly property real crossSize: root.spanEdges ? (trailingInput.alongSize > 0 ? root.stripThickness : 0) : trailingInput.crossSize

        x: root.isVertical ? crossPos : alongPos
        y: root.isVertical ? alongPos : crossPos
        width: root.isVertical ? crossSize : alongSize
        height: root.isVertical ? alongSize : crossSize
    }

    IslandSatelliteChrome {
        id: leadingChrome

        readonly property real alongPos: root.edgeAligned ? 0 : leadingInput.alongPos - root.chromePad
        readonly property real alongSize: leadingInput.alongSize > 0 ? (root.edgeAligned ? leadingInput.alongPos + leadingInput.alongSize + root.chromePad : leadingInput.alongSize + root.chromePad * 2) : 0

        floating: !root.edgeAligned
        x: root.isVertical ? root.stripStart : alongPos
        y: root.isVertical ? alongPos : root.stripStart
        width: root.isVertical ? root.stripThickness : alongSize
        height: root.isVertical ? alongSize : root.stripThickness
        visible: root.backgroundEnabled && leadingInput.alongSize > 0
        fillColor: root.chromeColor
        gothEnabled: root.gothCorners
        sweep: root.sweepRadius
        isVertical: root.isVertical
        crossFar: root.crossFar
        parentScreen: root.targetScreen
        onVisibleChanged: blurRebuildTimer.restart()
    }

    IslandSatelliteChrome {
        id: trailingChrome

        readonly property real alongPos: trailingInput.alongPos - root.chromePad
        readonly property real alongSize: trailingInput.alongSize > 0 ? (root.edgeAligned ? Math.max(0, root.alongExtent - alongPos) : trailingInput.alongSize + root.chromePad * 2) : 0

        rightSide: true
        floating: !root.edgeAligned
        x: root.isVertical ? root.stripStart : alongPos
        y: root.isVertical ? alongPos : root.stripStart
        width: root.isVertical ? root.stripThickness : alongSize
        height: root.isVertical ? alongSize : root.stripThickness
        visible: root.backgroundEnabled && trailingInput.alongSize > 0
        fillColor: root.chromeColor
        gothEnabled: root.gothCorners
        sweep: root.sweepRadius
        isVertical: root.isVertical
        crossFar: root.crossFar
        parentScreen: root.targetScreen
        onVisibleChanged: blurRebuildTimer.restart()
    }

    Item {
        id: leadingInput

        readonly property real alongPos: root.edgeAligned ? root.edgeInset : Math.round(root.islandCurrentAlong - root.satelliteGap - alongSize)
        readonly property real alongSize: root.visible ? (root.isVertical ? leadingWidgetSection.implicitHeight : leadingWidgetSection.implicitWidth) : 0
        readonly property real crossSize: root.visible ? root.barThickness : 0

        x: root.isVertical ? root.rowCross : alongPos
        y: root.isVertical ? alongPos : root.rowCross
        width: root.isVertical ? crossSize : alongSize
        height: root.isVertical ? alongSize : crossSize
        onAlongPosChanged: root.kickBlur()
        onAlongSizeChanged: root.kickBlur()

        LeftSection {
            id: leadingWidgetSection

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
            edgeIsScreenEdge: root.edgeAligned
        }
    }

    Item {
        id: trailingInput

        readonly property real alongPos: root.edgeAligned ? root.alongExtent - root.edgeInset - alongSize : Math.round(root.islandCurrentAlongEnd + root.satelliteGap)
        readonly property real alongSize: root.visible ? (root.isVertical ? trailingWidgetSection.implicitHeight : trailingWidgetSection.implicitWidth) : 0
        readonly property real crossSize: root.visible ? root.barThickness : 0

        x: root.isVertical ? root.rowCross : alongPos
        y: root.isVertical ? alongPos : root.rowCross
        width: root.isVertical ? crossSize : alongSize
        height: root.isVertical ? alongSize : crossSize
        onAlongPosChanged: root.kickBlur()
        onAlongSizeChanged: root.kickBlur()

        RightSection {
            id: trailingWidgetSection

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
            edgeIsScreenEdge: root.edgeAligned
        }
    }
}
