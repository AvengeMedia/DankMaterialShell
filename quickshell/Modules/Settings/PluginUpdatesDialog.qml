import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets
import qs.Modules.Settings.Widgets
import qs.Services

StyledRect {
    id: root

    property var updatesList: []
    property bool isUpdating: false
    property bool operationsBlocked: false
    property string currentUpdatingPlugin: ""
    property var updateErrors: ({})

    signal pluginUpdated(string pluginId)
    signal updatesRequested(var plugins)

    width: parent.width
    height: visible ? innerColumn.implicitHeight + Theme.spacingL * 2 : 0
    radius: Theme.cornerRadiusM
    color: Theme.floatingWindowNestedSurface
    border.color: Theme.outlineVariant
    border.width: Theme.outlineWidth
    clip: true

    visible: false

    function show(list) {
        if (isUpdating || operationsBlocked)
            return;
        updatesList = list || [];
        visible = true;
    }

    function hide() {
        if (isUpdating || operationsBlocked)
            return;
        visible = false;
        updatesList = [];
        updateErrors = ({});
    }

    function updateSingle(plugin) {
        updatesRequested([plugin]);
    }

    function updateAll() {
        updatesRequested(updatesList.slice());
    }

    function updatePlugins(list) {
        if (isUpdating || operationsBlocked || list.length === 0)
            return;
        isUpdating = true;
        updateErrors = ({});
        let index = 0;
        function updateNext() {
            if (index >= list.length) {
                isUpdating = false;
                currentUpdatingPlugin = "";
                DMSService.listInstalled();
                return;
            }
            const plugin = list[index++];
            currentUpdatingPlugin = plugin.name;
            PluginService.updatePlugin(plugin.id, response => {
                if (response.error) {
                    updateErrors = Object.assign({}, updateErrors, {
                        [plugin.id]: I18n.tr("Failed to update %1: %2", "plugin update error, %1 is the plugin name, %2 is the error message").arg(plugin.name).arg(response.error)
                    });
                    updateNext();
                    return;
                }
                root.pluginUpdated(plugin.id);
                updatesList = updatesList.filter(entry => entry.id !== plugin.id);
                updateNext();
            });
        }
        updateNext();
    }

    Column {
        id: innerColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.spacingL
        spacing: Theme.spacingM

        RowLayout {
            width: parent.width
            spacing: Theme.spacingM

            DankIcon {
                name: "download"
                size: Theme.iconSize
                color: Theme.primary
                Layout.alignment: Qt.AlignVCenter
            }

            StyledText {
                Layout.fillWidth: true
                text: I18n.tr("Available Updates (%1)", "plugin updates dialog title, %1 is a count").arg(root.updatesList.length)
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Theme.fontWeightMedium
                color: Theme.surfaceText
                wrapMode: Text.Wrap
            }

            DankActionButton {
                id: collapseBtn
                iconName: "close"
                Accessible.name: I18n.tr("Close")
                iconSize: Theme.iconSizeMedium
                iconColor: Theme.outline
                Layout.alignment: Qt.AlignVCenter
                enabled: !root.isUpdating && !root.operationsBlocked
                onClicked: root.hide()
            }
        }

        RowLayout {
            width: parent.width
            spacing: Theme.spacingS
            visible: !root.isUpdating && root.updatesList.length > 0

            DankIcon {
                name: "warning"
                size: Theme.iconSizeMedium
                color: Theme.warning
                Layout.alignment: Qt.AlignTop
            }

            StyledText {
                Layout.fillWidth: true
                text: I18n.tr("Plugin updates can change the code running in your session. Review the changes before updating.", "plugin update audit reminder")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.onSurfaceVariant
                wrapMode: Text.Wrap
            }
        }

        Item {
            width: parent.width
            height: isUpdating ? Theme.buttonHeightS : 0
            visible: isUpdating
            clip: true

            Row {
                anchors.centerIn: parent
                spacing: Theme.spacingM

                DankSpinner {
                    size: Theme.iconSize
                    running: root.isUpdating
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: root.currentUpdatingPlugin ? I18n.tr("Updating %1...", "plugin updates dialog progress, %1 is the plugin name").arg(root.currentUpdatingPlugin) : I18n.tr("Updating plugins...")
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        StyledText {
            width: parent.width
            visible: Object.keys(root.updateErrors).length > 0
            text: Object.values(root.updateErrors).join("\n")
            color: Theme.error
            wrapMode: Text.Wrap
        }

        DankFlickable {
            width: parent.width
            height: Math.min(listCol.implicitHeight, Theme.smallBreakpoint)
            clip: true
            contentHeight: listCol.implicitHeight
            visible: !isUpdating

            Column {
                id: listCol
                width: parent.width
                spacing: Theme.spacingM

                Repeater {
                    model: root.updatesList

                    delegate: SettingsRow {
                        required property var modelData
                        width: listCol.width
                        iconName: modelData.icon || "extension"
                        title: modelData.name || ""
                        subtitle: modelData.author ? I18n.tr("by %1", "author attribution").arg(modelData.author) : ""
                        DankActionButton {
                            iconName: "open_in_new"
                            tooltipText: I18n.tr("View Changes", "open plugin changes before updating")
                            visible: !!modelData.diffUrl || !!modelData.repo
                            onClicked: Qt.openUrlExternally(modelData.diffUrl || modelData.repo)
                        }
                        DankActionButton {
                            iconName: "download"
                            tooltipText: I18n.tr("Update", "verb, button installing a newer plugin version")
                            enabled: !root.isUpdating && !root.operationsBlocked
                            onClicked: root.updateSingle(modelData)
                        }
                    }
                }

                StyledText {
                    width: parent.width
                    text: I18n.tr("No updates available.")
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceVariantText
                    horizontalAlignment: Text.AlignHCenter
                    visible: root.updatesList.length === 0
                }
            }
        }

        Row {
            anchors.right: parent.right
            spacing: Theme.spacingM
            visible: !isUpdating

            DankButton {
                text: I18n.tr("Cancel")
                iconName: "close"
                backgroundColor: Theme.chipSurface
                textColor: Theme.surfaceText
                onClicked: root.hide()
            }

            DankButton {
                text: I18n.tr("Update All")
                iconName: "download"
                enabled: !root.operationsBlocked && root.updatesList.length > 0
                onClicked: root.updateAll()
            }
        }
    }
}
