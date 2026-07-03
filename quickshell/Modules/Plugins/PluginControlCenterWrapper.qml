import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property string pluginId: ""
    property var pluginInstance: null
    property bool isCompoundPill: false
    property bool isSmallToggle: false

    readonly property bool hasDetail: pluginInstance?.ccDetailContent !== null
    readonly property string iconName: pluginInstance?.ccWidgetIcon || "extension"
    readonly property string primaryText: pluginInstance?.ccWidgetPrimaryText || "Plugin"
    readonly property string secondaryText: pluginInstance?.ccWidgetSecondaryText || ""
    readonly property bool isActive: pluginInstance?.ccWidgetIsActive || false
    readonly property Component detailContent: pluginInstance?.ccDetailContent || null
    readonly property real detailHeight: pluginInstance?.ccDetailHeight || 250

    signal toggled
    signal expanded

    Component.onCompleted: {
        if (pluginInstance) {
            pluginInstance.ccWidgetToggled.connect(toggled);
            pluginInstance.ccWidgetExpanded.connect(expanded);
        }
    }

    function invokeToggle() {
        if (pluginInstance) {
            pluginInstance.ccWidgetToggled();
        }
    }

    function invokeExpand() {
        if (pluginInstance) {
            pluginInstance.ccWidgetExpanded();
        }
    }
}
