pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common
import qs.Modules.ControlCenter
import qs.Modules.ControlCenter.Widgets
import qs.Modules.DankBar.Widgets
import qs.Modules.DankDash
import "../utils/widgets.js" as WidgetUtils
import qs.Services
import qs.Widgets

Item {
    id: root

    property int widgetIndex: -1
    property var model: null
    property int columns: CcMetrics.gridColumns
    property var transientSurfaceTracker: null
    property Item _anchor: null

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
    readonly property bool isUser: widgetId === "user"
    readonly property bool isRunningApps: widgetId === "runningApps"
    readonly property var cardActions: WidgetUtils.cardActions(widgetData)

    visible: widgetIndex >= 0 || contextMenu.renderActive

    function open(index, data, anchorItem) {
        widgetIndex = index;
        _anchor = anchorItem;
        // Placement needs the final menu height, which settles after widgetIndex propagates.
        Qt.callLater(() => {
            const window = root.QsWindow.window;
            const screen = window?.screen;
            if (root.widgetIndex !== index || !anchorItem || !screen)
                return;
            const pos = anchorItem.mapToGlobal(0, 0);
            const x = pos.x - screen.x;
            const y = pos.y - screen.y;
            const menuX = I18n.isRtl ? x : x + anchorItem.width - contextMenu.effectiveMenuWidth;
            const aboveY = () => y - contextMenu.effectiveMenuHeight - Theme.spacingS;
            if (aboveY() < Theme.spacingS) {
                contextMenu.open(screen, menuX, y + anchorItem.height + Theme.spacingS, false);
                return;
            }
            contextMenu.open(screen, menuX, aboveY(), false);
            contextMenu.anchorY = Qt.binding(aboveY);
        });
    }

    function close() {
        if (!contextMenu.renderActive) {
            widgetIndex = -1;
            _anchor = null;
            return;
        }
        contextMenu.hide();
    }

    function persistOption(key, value) {
        WidgetUtils.setOption(widgetIndex, key, value);
    }

    DankContextMenu {
        id: contextMenu
        layerNamespace: "dms:control-center-widget-options"
        minMenuWidth: CcMetrics.configMenuWidth
        customContentWidth: CcMetrics.configMenuWidth
        keyboardNavigable: true
        transientSurfaceTracker: root.transientSurfaceTracker

        onOpenStateChanged: {
            if (openState)
                return;
            root.widgetIndex = -1;
            if (root._anchor?.visible && root._anchor.enabled)
                root._anchor.forceActiveFocus();
            root._anchor = null;
        }

        customContent: Component {
            Column {
                width: parent?.width ?? 0

                CcGroup {
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

                    CcToggleRow {
                        visible: root.isUser
                        text: I18n.tr("Background")
                        checked: root.widgetData?.background === true
                        onToggled: checked => root.persistOption("background", checked)
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

                    CcToggleRow {
                        visible: root.isRunningApps
                        text: I18n.tr("Show window count", "toggle in control center running apps widget options")
                        checked: root.widgetData?.showCount !== false
                        onToggled: checked => root.persistOption("showCount", checked)
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
                            transientSurfaceTracker: contextMenu.transientSurfaceTracker
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

                CcSectionLabel {
                    width: parent.width
                    visible: root.isUser
                    text: I18n.tr("Actions")
                }

                CcGroup {
                    width: parent.width
                    visible: root.isUser

                    Repeater {
                        model: root.isUser ? WidgetUtils.BUTTON_IDS : []

                        CcToggleRow {
                            required property string modelData

                            text: root.model?.getWidgetForId(modelData)?.text ?? modelData
                            checked: root.cardActions.includes(modelData)
                            onToggled: checked => root.widgetIndex = WidgetUtils.setCardAction(root.widgetIndex, modelData, checked, root.columns)
                        }
                    }
                }
            }
        }
    }
}
