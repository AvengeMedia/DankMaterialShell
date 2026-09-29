pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import qs.Common
import qs.Modules.ControlCenter
import qs.Modules.ControlCenter.Widgets
import qs.Modules.DankBar.Widgets
import qs.Modules.DankDash
import qs.Modules.Settings.Widgets
import "../utils/widgets.js" as WidgetUtils
import qs.Services
import qs.Widgets

Item {
    id: root

    property Item backdrop: null
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
    readonly property bool isUser: widgetId === "userCard"
    readonly property bool isQuickActions: widgetId === "quickActions"
    readonly property var quickActions: isQuickActions ? WidgetUtils.quickActions(widgetData) : []

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

    function toggleAction(id, enabled) {
        persistOption("actions", quickActions.map(action => action.id === id ? Object.assign({}, action, {
                "enabled": enabled
            }) : action));
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

        readonly property real preferredY: root.anchorY - height - Theme.spacingS < Theme.spacingS ? root.anchorY + root.anchorHeight + Theme.spacingS : root.anchorY - height - Theme.spacingS

        width: CcMetrics.configMenuWidth
        height: Math.min(menu.implicitHeight, root.height - Theme.spacingS * 4) + Theme.spacingS * 2
        radius: Theme.windowRadius
        color: CcMetrics.dialogColor
        border.width: Theme.layerOutlineWidth
        border.color: Theme.outlineMedium
        x: Math.max(Theme.spacingS, Math.min(root.anchorX + root.anchorWidth - width, root.width - width - Theme.spacingS))
        y: Math.max(Theme.spacingS, Math.min(preferredY, root.height - height - Theme.spacingS))
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

        // The popout is not a real subsurface, so fake compositor blur the same way the detail dialog does, but from the sheet content it covers.
        Loader {
            anchors.fill: parent
            z: -1
            active: root.visible && root.backdrop !== null && CcMetrics.hideCoveredContent

            sourceComponent: ClippingRectangle {
                id: clipArea

                // Children land in an internal content item, so `parent` never reaches this pad.
                readonly property real pad: CcMetrics.backdropBlurRadius

                radius: panel.radius
                color: "transparent"

                ShaderEffectSource {
                    id: backdropSource

                    x: -clipArea.pad
                    y: -clipArea.pad
                    width: clipArea.width + clipArea.pad * 2
                    height: clipArea.height + clipArea.pad * 2
                    visible: false
                    sourceItem: root.backdrop
                    // mapFromItem is not reactive, so the capture is rebuilt from the panel's own geometry.
                    sourceRect: {
                        const origin = root.backdrop.mapFromItem(root, panel.x - clipArea.pad, panel.y - clipArea.pad);
                        return Qt.rect(origin.x, origin.y, width, height);
                    }
                }

                MultiEffect {
                    anchors.fill: backdropSource
                    source: backdropSource
                    blurEnabled: true
                    blur: 1
                    blurMax: CcMetrics.backdropBlurRadius
                    autoPaddingEnabled: false
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onClicked: mouse => mouse.accepted = true
        }

        DankFlickable {
            anchors.fill: parent
            anchors.margins: Theme.spacingS
            clip: true
            contentWidth: width
            contentHeight: menu.implicitHeight
            interactive: contentHeight > height

            CcGroup {
                id: menu
                width: parent.width

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

                Repeater {
                    model: root.isUser ? DashRegistry.sheetOptionSpecs("user") : []

                    CcToggleRow {
                        required property var modelData

                        text: modelData.text
                        checked: DashRegistry.optionValue(modelData, root.widgetData?.[modelData.key])
                        onToggled: checked => root.persistOption(modelData.key, checked)
                    }
                }

                SettingsReorderList {
                    id: actionList

                    visible: root.isQuickActions
                    model: root.quickActions
                    onReordered: indices => root.persistOption("actions", indices.map(i => root.quickActions[i]))

                    delegate: SettingsReorderRow {
                        required property var modelData
                        readonly property bool locked: modelData.id === "edit"

                        reorderList: actionList
                        paddingH: CcMetrics.rowPaddingH
                        paddingV: CcMetrics.rowPaddingV
                        rowColor: dragging ? Theme.blend(CcMetrics.rowColor, Theme.onSurface, Theme.stateLayerDrag) : CcMetrics.rowColor
                        iconName: WidgetUtils.quickActionIcon(modelData.id)
                        title: I18n.tr(WidgetUtils.quickActionLabel(modelData.id))
                        clickable: !locked
                        onClicked: root.toggleAction(modelData.id, !modelData.enabled)

                        DankToggle {
                            hideText: true
                            text: parent.title
                            activeFocusOnTab: false
                            checked: modelData.enabled
                            enabled: !locked
                            onToggled: value => root.toggleAction(modelData.id, value)
                        }
                    }
                }

                CcToggleRow {
                    visible: root.isUser
                    text: I18n.tr("Background")
                    checked: root.widgetData?.background !== false
                    onToggled: checked => root.persistOption("background", checked)
                }

                CcToggleRow {
                    visible: root.isQuickActions
                    text: I18n.tr("Highlight power", "toggle that gives the control center power button the error color")
                    checked: root.widgetData?.powerAccent === true
                    onToggled: checked => root.persistOption("powerAccent", checked)
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
}
