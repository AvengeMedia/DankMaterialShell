pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
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
    readonly property real rowInset: Theme.snap(Math.max(0, (root.controller.compactFaceHeight - root.barThickness) / 2), root.screenScale)
    readonly property real rowY: root.bottomEdge ? root.height - root.outerGap - root.rowInset - root.barThickness : root.outerGap + root.rowInset
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
        }
        function unregisterBlurWidget(item) {
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

        x: root.motionRunning ? Math.min(root.islandStartX, root.islandTargetX) - SettingsData.dankIslandSatelliteGap - leftInput.width : leftInput.x
        y: leftInput.y
        width: leftInput.width + root.leftEdgeSpread
        height: leftInput.height
    }

    Item {
        id: rightInputEnvelope

        x: root.motionRunning ? Math.min(root.islandStartRight, root.islandTargetRight) + SettingsData.dankIslandSatelliteGap : rightInput.x
        y: rightInput.y
        width: rightInput.width + root.rightEdgeSpread
        height: rightInput.height
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
        }
    }
}
