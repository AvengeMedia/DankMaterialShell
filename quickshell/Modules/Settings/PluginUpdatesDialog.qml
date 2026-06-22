import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Widgets
import qs.Services

FloatingWindow {
    id: root

    property bool disablePopupTransparency: true
    property var updatesList: []
    property bool isUpdating: false
    property string currentUpdatingPlugin: ""
    property var parentModal: null
    parentWindow: parentModal

    title: I18n.tr("Plugin Updates")
    implicitWidth: 520
    implicitHeight: 400
    minimumSize: Qt.size(480, 300)
    maximumSize: Qt.size(600, 600)
    color: Theme.surfaceContainer
    visible: false

    function show(list) {
        updatesList = list || [];
        visible = true;
    }

    function hide() {
        if (!isUpdating) {
            visible = false;
        }
    }

    function updateSingle(plugin) {
        if (isUpdating) return;
        isUpdating = true;
        currentUpdatingPlugin = plugin.name;

        DMSService.update(plugin.name, response => {
            isUpdating = false;
            currentUpdatingPlugin = "";
            if (response.error) {
                ToastService.showError(I18n.tr("Failed to update %1: %2").arg(plugin.name).arg(response.error));
            } else {
                ToastService.showInfo(I18n.tr("Plugin updated: %1").arg(plugin.name));
                PluginService.forceRescanPlugin(plugin.id);
                DMSService.listInstalled();
            }
        });
    }

    function updateAll() {
        if (isUpdating) return;
        isUpdating = true;

        var list = updatesList.slice();
        var idx = 0;

        function updateNext() {
            if (idx >= list.length) {
                isUpdating = false;
                currentUpdatingPlugin = "";
                ToastService.showInfo(I18n.tr("All plugins updated successfully"));
                DMSService.listInstalled();
                root.hide();
                return;
            }

            var plugin = list[idx];
            currentUpdatingPlugin = plugin.name;

            DMSService.update(plugin.name, response => {
                if (response.error) {
                    ToastService.showError(I18n.tr("Failed to update %1: %2").arg(plugin.name).arg(response.error));
                } else {
                    PluginService.forceRescanPlugin(plugin.id);
                }
                idx++;
                updateNext();
            });
        }

        updateNext();
    }

    FocusScope {
        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                root.hide();
                event.accepted = true;
            }
        }

        Column {
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingL

            // Header
            Row {
                width: parent.width
                spacing: Theme.spacingM

                DankIcon {
                    name: "download"
                    size: Theme.iconSize
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: I18n.tr("Available Updates")
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }

                Item {
                    width: parent.width - parent.spacing * 2 - Theme.iconSize - parent.children[1].implicitWidth - closeBtn.width
                    height: 1
                }

                DankActionButton {
                    id: closeBtn
                    iconName: "close"
                    iconSize: Theme.iconSize - 2
                    iconColor: Theme.outline
                    anchors.verticalCenter: parent.verticalCenter
                    enabled: !root.isUpdating
                    onClicked: root.hide()
                }
            }

            // Spinner / Loading state
            Item {
                width: parent.width
                height: isUpdating ? 40 : 0
                visible: isUpdating
                clip: true

                Behavior on height {
                    NumberAnimation { duration: Theme.shortDuration }
                }

                Row {
                    anchors.centerIn: parent
                    spacing: Theme.spacingM

                    DankSpinner {
                        running: root.isUpdating
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        text: root.currentUpdatingPlugin ? I18n.tr("Updating %1...").arg(root.currentUpdatingPlugin) : I18n.tr("Updating plugins...")
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            // Scrollable Content
            DankFlickable {
                width: parent.width
                height: parent.height - parent.spacing * 3 - parent.children[0].height - (isUpdating ? 40 : 0) - bottomRow.height - Theme.spacingL
                clip: true
                contentHeight: listCol.implicitHeight

                Column {
                    id: listCol
                    width: parent.width
                    spacing: Theme.spacingM

                    Repeater {
                        model: root.updatesList

                        delegate: StyledRect {
                            width: parent.width
                            height: 64
                            radius: Theme.cornerRadius
                            color: Theme.surfaceContainerHigh
                            border.width: 0

                            Row {
                                anchors.fill: parent
                                anchors.margins: Theme.spacingM
                                spacing: Theme.spacingM

                                DankIcon {
                                    name: modelData.icon || "extension"
                                    size: Theme.iconSize
                                    color: Theme.primary
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: Theme.spacingXS
                                    width: parent.width - Theme.iconSize - Theme.spacingM - actionButtonsRow.width - Theme.spacingM

                                    StyledText {
                                        text: modelData.name || ""
                                        font.pixelSize: Theme.fontSizeMedium
                                        font.weight: Font.Medium
                                        color: Theme.surfaceText
                                        elide: Text.ElideRight
                                        width: parent.width
                                        horizontalAlignment: Text.AlignLeft
                                    }

                                    StyledText {
                                        text: modelData.author ? I18n.tr("By %1").arg(modelData.author) : ""
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                        elide: Text.ElideRight
                                        width: parent.width
                                        horizontalAlignment: Text.AlignLeft
                                    }
                                }

                                Row {
                                    id: actionButtonsRow
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: Theme.spacingS

                                    DankButton {
                                        text: I18n.tr("Diff")
                                        iconName: "open_in_new"
                                        visible: !!modelData.diffUrl || !!modelData.repo
                                        backgroundColor: Theme.surfaceContainerHighest
                                        textColor: Theme.surfaceText
                                        onClicked: {
                                            Qt.openUrlExternally(modelData.diffUrl || modelData.repo);
                                        }
                                    }

                                    DankButton {
                                        text: I18n.tr("Update")
                                        iconName: "download"
                                        enabled: !root.isUpdating
                                        onClicked: {
                                            root.updateSingle(modelData);
                                        }
                                    }
                                }
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

            // Bottom bar
            Row {
                id: bottomRow
                anchors.right: parent.right
                spacing: Theme.spacingM

                DankButton {
                    text: I18n.tr("Cancel")
                    iconName: "close"
                    enabled: !root.isUpdating
                    backgroundColor: Theme.surfaceContainerHighest
                    textColor: Theme.surfaceText
                    onClicked: root.hide()
                }

                DankButton {
                    text: I18n.tr("Update All")
                    iconName: "download"
                    enabled: !root.isUpdating && root.updatesList.length > 0
                    onClicked: root.updateAll()
                }
            }
        }
    }

    FloatingWindowControls {
        id: windowControls
        targetWindow: root
    }
}
