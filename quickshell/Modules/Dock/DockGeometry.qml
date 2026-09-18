pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services

QtObject {
    id: root

    property var screen: null
    property string edge: "bottom"
    property bool dockVisible: false
    property bool autoHide: false
    property bool overlay: false
    property real thickness: 64
    property real reserveThickness: thickness
    property real borderThickness: 0
    property real exclusiveOffset: 0
    property real margin: 0
    property real barSpacing: 0
    property real dpr: 1

    readonly property bool frameExclusionActive: CompositorService.frameWindowVisibleForScreen(screen)
    readonly property bool usesConnectedFrameChrome: !overlay && CompositorService.usesConnectedFrameChromeForScreen(screen)

    readonly property real connectedJoinInset: {
        if (usesConnectedFrameChrome)
            return SettingsData.frameEdgeReservation(screen, edge);
        if (frameExclusionActive)
            return SettingsData.frameEdgeInsetForSide(screen, edge);
        return 0;
    }

    readonly property real frameInset: {
        if (!frameExclusionActive)
            return 0;
        if (usesConnectedFrameChrome)
            return connectedJoinInset;
        return SettingsData.frameThickness;
    }

    readonly property real effectiveMargin: usesConnectedFrameChrome ? 0 : margin + borderThickness
    readonly property real joinedEdgeMargin: usesConnectedFrameChrome ? 0 : (barSpacing + effectiveMargin)
    readonly property real bodyEdgeMargin: frameInset + joinedEdgeMargin

    readonly property real bodyThickness: thickness
    readonly property real visualThickness: bodyThickness
    readonly property real surfaceThickness: bodyEdgeMargin + bodyThickness
    readonly property real motionThickness: surfaceThickness

    // Frame and bar exclusions already reserve the edge itself; the dock reserves its own body,
    // its margin, and the user's exclusive offset beyond that.
    readonly property real reserveZone: Math.max(0, Theme.px(reserveThickness + effectiveMargin + exclusiveOffset, dpr))
    readonly property bool shouldReserveSpace: dockVisible && !autoHide && barSpacing <= 0
}
