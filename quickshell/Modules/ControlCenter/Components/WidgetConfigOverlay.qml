import QtQuick
import qs.Common
import qs.Modules.ControlCenter
import qs.Modules.ControlCenter.Widgets
import qs.Modules.DankBar.Widgets
import qs.Services
import qs.Widgets

Item {
    id: root

    property int widgetIndex: -1
    property real anchorX: 0
    property real anchorY: 0
    property real anchorWidth: 0
    property real anchorHeight: 0

    readonly property var widgetData: {
        if (widgetIndex < 0)
            return null;
        const widgets = SettingsData.controlCenterWidgets || [];
        return widgets[widgetIndex] || null;
    }
    readonly property string widgetId: String(widgetData?.id ?? "")
    readonly property bool isPlugin: widgetId.startsWith("plugin_")
    readonly property bool isDisk: widgetId === "diskUsage"
    readonly property bool isIdleInhibitor: widgetId === "idleInhibitor"

    visible: widgetIndex >= 0
    z: CcMetrics.overlayZ

    function open(index, data, anchorItem) {
        const pos = anchorItem.mapToItem(root, 0, 0);
        anchorX = pos.x;
        anchorY = pos.y;
        anchorWidth = anchorItem.width;
        anchorHeight = anchorItem.height;
        widgetIndex = index;
        focusScope.forceActiveFocus();
    }

    function close() {
        widgetIndex = -1;
    }

    function persistOption(key, value) {
        const widgets = (SettingsData.controlCenterWidgets || []).slice();
        if (widgetIndex < 0 || widgetIndex >= widgets.length)
            return;
        widgets[widgetIndex] = Object.assign({}, widgets[widgetIndex], {
            [key]: value
        });
        SettingsData.set("controlCenterWidgets", widgets);
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.visible
        acceptedButtons: Qt.AllButtons
        onClicked: root.close()
        onWheel: wheel => wheel.accepted = true
    }

    FocusScope {
        id: focusScope
        anchors.fill: parent
        focus: root.visible

        Keys.onEscapePressed: event => {
            root.close();
            event.accepted = true;
        }
    }

    Rectangle {
        id: panel

        width: CcMetrics.configMenuWidth
        height: menu.implicitHeight + Theme.spacingS * 2
        radius: Theme.windowRadius
        color: Theme.nestedSurface
        x: Math.max(Theme.spacingS, Math.min(root.anchorX + root.anchorWidth - width, root.width - width - Theme.spacingS))
        y: root.anchorY - height - Theme.spacingS < Theme.spacingS ? root.anchorY + root.anchorHeight + Theme.spacingS : root.anchorY - height - Theme.spacingS
        opacity: root.visible ? 1 : 0
        scale: root.visible ? 1 : CcMetrics.popupEnterScale
        transformOrigin: Item.TopRight

        Behavior on opacity {
            enabled: CcMetrics.animationsEnabled
            NumberAnimation {
                duration: Theme.expressiveDurations.expressiveEffects
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.expressiveCurves.expressiveEffects
            }
        }

        Behavior on scale {
            enabled: CcMetrics.animationsEnabled
            NumberAnimation {
                duration: Theme.expressiveDurations.expressiveFastSpatial
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.expressiveCurves.expressiveFastSpatial
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onClicked: mouse => mouse.accepted = true
        }

        CcGroup {
            id: menu
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: Theme.spacingS
            width: parent.width - Theme.spacingS * 2

            CcListRow {
                visible: root.isPlugin
                iconName: "settings"
                title: I18n.tr("Plugin settings")
                clickable: true
                onClicked: {
                    PopoutService.openSettingsWithTab(SettingsTabs.pluginPrefix + root.widgetId.replace("plugin_", ""));
                    root.close();
                }
            }

            CcToggleRow {
                visible: root.isDisk
                text: I18n.tr("Show mount path", "toggle in control center disk usage widget to turn mount path display on or off")
                checked: root.widgetData?.showMountPath !== false
                onToggled: checked => root.persistOption("showMountPath", checked)
            }

            CcListRow {
                visible: root.isIdleInhibitor
                iconName: "timer"
                title: I18n.tr("Duration")
                body: DankDropdown {
                    readonly property var presets: IdleInhibitPresets.presetOptions

                    compactMode: true
                    dropdownWidth: parent.width
                    currentValue: presets.find(p => p.minutes === (root.widgetData?.durationMinutes ?? 0))?.label ?? ""
                    options: presets.map(p => p.label)
                    onValueChanged: value => {
                        const preset = presets.find(p => p.label === value);
                        if (preset)
                            root.persistOption("durationMinutes", preset.minutes);
                    }
                }
            }
        }
    }
}
