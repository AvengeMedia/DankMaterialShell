import QtQuick
import qs.Common

Item {
    id: root

    property string layerNamespacePlugin: "plugin"

    property var axis: null
    property string section: "center"
    property var parentScreen: null
    property real widgetThickness: 30
    property real barThickness: 48
    property real barSpacing: 4
    property var barConfig: null
    property string pluginId: ""
    property var pluginService: null

    property Component horizontalBarPill: null
    property Component verticalBarPill: null
    property Component popoutContent: null
    property real popoutWidth: 400
    property real popoutHeight: 0
    property var pillClickAction: null
    property var pillRightClickAction: null

    property Component controlCenterWidget: null
    property string ccWidgetIcon: ""
    property string ccWidgetPrimaryText: ""
    property string ccWidgetSecondaryText: ""
    property bool ccWidgetIsActive: false
    property bool ccWidgetIsToggle: true
    property Component ccDetailContent: null
    property real ccDetailHeight: 250

    signal ccWidgetToggled
    signal ccWidgetExpanded

    property var pluginData: ({})
    property var variants: []

    readonly property bool isVertical: axis?.isVertical ?? false
    readonly property bool hasHorizontalPill: horizontalBarPill !== null
    readonly property bool hasVerticalPill: verticalBarPill !== null
    readonly property bool hasPopout: popoutContent !== null

    readonly property int iconSize: Theme.barIconSize(barThickness, -4)
    readonly property int iconSizeLarge: Theme.barIconSize(barThickness)

    Component.onCompleted: {
        loadPluginData();
    }

    onPluginServiceChanged: {
        loadPluginData();
    }

    onPluginIdChanged: {
        loadPluginData();
    }

    Connections {
        target: pluginService
        function onPluginDataChanged(changedPluginId) {
            if (changedPluginId === pluginId) {
                loadPluginData();
            }
        }
    }

    function loadPluginData() {
        if (!pluginService || !pluginId) {
            pluginData = {};
            variants = [];
            return;
        }
        pluginData = SettingsData.getPluginSettingsForPlugin(pluginId);
        variants = pluginService.getPluginVariants(pluginId);
    }

    function createVariant(variantName, variantConfig) {
        if (!pluginService || !pluginId) {
            return null;
        }
        return pluginService.createPluginVariant(pluginId, variantName, variantConfig);
    }

    function removeVariant(variantId) {
        if (!pluginService || !pluginId) {
            return;
        }
        pluginService.removePluginVariant(pluginId, variantId);
    }

    function updateVariant(variantId, variantConfig) {
        if (!pluginService || !pluginId) {
            return;
        }
        pluginService.updatePluginVariant(pluginId, variantId, variantConfig);
    }

    width: isVertical ? (hasVerticalPill ? verticalPill.width : 0) : (hasHorizontalPill ? horizontalPill.width : 0)
    height: isVertical ? (hasVerticalPill ? verticalPill.height : 0) : (hasHorizontalPill ? horizontalPill.height : 0)

    BasePill {
        id: horizontalPill
        visible: !isVertical && hasHorizontalPill
        axis: root.axis
        section: root.section
        popoutTarget: hasPopout ? pluginPopout : null
        parentScreen: root.parentScreen
        widgetThickness: root.widgetThickness
        barThickness: root.barThickness
        barSpacing: root.barSpacing
        barConfig: root.barConfig
        content: root.horizontalBarPill
        onClicked: {
            if (pillClickAction) {
                if (pillClickAction.length === 0) {
                    pillClickAction();
                } else {
                    const globalPos = mapToGlobal(0, 0);
                    const currentScreen = parentScreen || Screen;
                    const pos = SettingsData.getPopupTriggerPosition(globalPos, currentScreen, barThickness, width);
                    pillClickAction(pos.x, pos.y, pos.width, section, currentScreen);
                }
            } else if (hasPopout) {
                pluginPopout.toggle();
            }
        }
        onRightClicked: {
            if (pillRightClickAction) {
                if (pillRightClickAction.length === 0) {
                    pillRightClickAction();
                } else {
                    const globalPos = mapToGlobal(0, 0);
                    const currentScreen = parentScreen || Screen;
                    const pos = SettingsData.getPopupTriggerPosition(globalPos, currentScreen, barThickness, width);
                    pillRightClickAction(pos.x, pos.y, pos.width, section, currentScreen);
                }
            }
        }
    }

    BasePill {
        id: verticalPill
        visible: isVertical && hasVerticalPill
        axis: root.axis
        section: root.section
        popoutTarget: hasPopout ? pluginPopout : null
        parentScreen: root.parentScreen
        widgetThickness: root.widgetThickness
        barThickness: root.barThickness
        barSpacing: root.barSpacing
        barConfig: root.barConfig
        content: root.verticalBarPill
        isVerticalOrientation: true
        onClicked: {
            if (pillClickAction) {
                if (pillClickAction.length === 0) {
                    pillClickAction();
                } else {
                    const globalPos = mapToGlobal(0, 0);
                    const currentScreen = parentScreen || Screen;
                    const pos = SettingsData.getPopupTriggerPosition(globalPos, currentScreen, barThickness, width);
                    pillClickAction(pos.x, pos.y, pos.width, section, currentScreen);
                }
            } else if (hasPopout) {
                pluginPopout.toggle();
            }
        }
        onRightClicked: {
            if (pillRightClickAction) {
                if (pillRightClickAction.length === 0) {
                    pillRightClickAction();
                } else {
                    const globalPos = mapToGlobal(0, 0);
                    const currentScreen = parentScreen || Screen;
                    const pos = SettingsData.getPopupTriggerPosition(globalPos, currentScreen, barThickness, width);
                    pillRightClickAction(pos.x, pos.y, pos.width, section, currentScreen);
                }
            }
        }
    }

    function closePopout() {
        if (pluginPopout) {
            pluginPopout.close();
        }
    }

    function triggerPopout() {
        if (pillClickAction) {
            if (pillClickAction.length === 0) {
                pillClickAction();
                return;
            }
            const pill = isVertical ? verticalPill : horizontalPill;
            const globalPos = pill.mapToGlobal(0, 0);
            const currentScreen = parentScreen || Screen;
            const pos = SettingsData.getPopupTriggerPosition(globalPos, currentScreen, barThickness, pill.width);
            pillClickAction(pos.x, pos.y, pos.width, section, currentScreen);
            return;
        }
        if (!hasPopout)
            return;

        const pill = isVertical ? verticalPill : horizontalPill;
        const globalPos = pill.visualContent.mapToGlobal(0, 0);
        const currentScreen = parentScreen || Screen;
        const barPosition = axis?.edge === "left" ? 2 : (axis?.edge === "right" ? 3 : (axis?.edge === "top" ? 0 : 1));
        const pos = SettingsData.getPopupTriggerPosition(globalPos, currentScreen, barThickness, pill.visualWidth, barSpacing, barPosition, barConfig);

        pluginPopout.setTriggerPosition(pos.x, pos.y, pos.width, section, currentScreen, barPosition, barThickness, barSpacing, barConfig);
        pluginPopout.toggle();
    }

    PluginPopout {
        id: pluginPopout
        contentWidth: root.popoutWidth
        contentHeight: root.popoutHeight
        pluginContent: root.popoutContent
    }
}
