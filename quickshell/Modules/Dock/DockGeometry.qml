pragma ComponentBehavior: Bound

import QtQuick
import qs.Common

QtObject {
    id: root

    property var screen: null
    property string edge: "bottom"
    property bool dockVisible: false
    property bool autoHide: false
    property bool hasFullscreenToplevel: false
    property real iconSize: 40
    property real spacing: 4
    property real borderThickness: 0
    property real offset: 0
    property real margin: 0
    property real barSpacing: 0
    property real dpr: 1

    function px(value) {
        return Math.round(value * dpr) / dpr;
    }

    readonly property bool frameExclusionActive: SettingsData.frameEnabled && !!screen && SettingsData.isScreenInPreferences(screen, SettingsData.frameScreenPreferences)
    readonly property bool connectedMode: Theme.isConnectedEffect
    readonly property bool connectedBarActiveOnEdge: connectedMode && !!screen && SettingsData.getActiveBarEdgesForScreen(screen).includes(edge)

    readonly property real connectedJoinInset: {
        if (connectedMode)
            return connectedBarActiveOnEdge ? SettingsData.frameBarSize : SettingsData.frameThickness;
        if (SettingsData.frameEnabled)
            return SettingsData.frameEdgeInsetForSide(screen, edge);
        return 0;
    }

    readonly property real frameInset: {
        if (!frameExclusionActive)
            return 0;
        if (connectedMode)
            return connectedJoinInset;
        return SettingsData.frameThickness;
    }

    readonly property real effectiveMargin: connectedMode ? 0 : margin
    readonly property real visualOffset: connectedMode ? 0 : offset
    readonly property real reserveOffset: offset
    readonly property real joinedEdgeMargin: connectedMode ? 0 : (barSpacing + effectiveMargin + 1 + borderThickness)
    readonly property real bodyEdgeMargin: frameInset + joinedEdgeMargin

    readonly property real bodyThickness: iconSize + spacing * 2 + borderThickness * 2
    readonly property real visualThickness: bodyThickness + 10
    readonly property real surfaceThickness: frameInset + visualThickness + spacing + effectiveMargin
    readonly property real motionThickness: surfaceThickness + visualOffset

    // Frame/bar edge exclusions already reserve the edge itself, so the dock
    // reservation covers only the dock body and user offset beyond that edge.
    readonly property real reserveZone: px(bodyThickness + reserveOffset + effectiveMargin)
    readonly property bool shouldReserveSpace: dockVisible && !hasFullscreenToplevel && !autoHide && barSpacing <= 0
}
