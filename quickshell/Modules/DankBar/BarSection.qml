import QtQuick
import qs.Common
import qs.Services
import "SegmentRoles.js" as SegmentRoles

Item {
    id: root

    property var barContent: null
    property var surfaceContext: barContent?.surfaceContext ?? null
    property var widgetsModel: barContent?.[section + "WidgetsModel"] ?? null
    property var components: barContent?.allComponents ?? null
    property bool noBackground: barConfig?.noBackground ?? false
    required property var axis
    property string section: "center"
    property var parentScreen: barContent?.barWindow?.screen ?? null
    property real widgetThickness: barContent?.barWindow?.widgetThickness ?? 30
    property real barThickness: barContent?.barWindow?.effectiveBarThickness ?? 48
    property real barSpacing: barConfig?.spacing ?? 4
    property var barConfig: barContent?.barConfig ?? null
    property var blurBarWindow: barContent?.blurBarWindow ?? null
    property real sectionAvailablePrimarySize: 0
    property bool overrideAxisLayout: false
    property bool forceVerticalLayout: false
    property bool edgeIsScreenEdge: true
    property real crossEdgeExtension: 0
    property string widgetStyle: BarMetrics.widgetStyle(barConfig)
    property var roles: []

    readonly property bool isVertical: overrideAxisLayout ? forceVerticalLayout : (axis?.isVertical ?? false)
    readonly property bool segmented: widgetStyle === "segments" && !noBackground
    readonly property real outlineThickness: (barConfig?.widgetOutlineEnabled ?? false) ? (barConfig?.widgetOutlineThickness ?? Theme.outlineWidth) : 0
    readonly property real widgetSpacing: (segmented ? BarMetrics.segmentGap : noBackground ? BarMetrics.bareGap : BarMetrics.pillGap) + outlineThickness * 2

    function refreshBlur() {
        blurBarWindow?.refreshBlurRegion?.();
    }

    function roleAt(index) {
        if (!segmented)
            return "solo";
        return roles[index] ?? "solo";
    }

    function participation(wrapper, visible, item) {
        if (!wrapper || !visible || wrapper.width <= 0 || wrapper.height <= 0)
            return null;
        return !!item && "segmentRole" in item;
    }

    function applyRoles(entries, participating) {
        const next = SegmentRoles.resolve(entries, participating);
        if (next.join() !== roles.join())
            roles = next;
    }
}
