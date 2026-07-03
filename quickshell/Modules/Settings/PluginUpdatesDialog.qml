import QtQuick
import qs.Common
import qs.Widgets
import qs.Services

StyledRect {
    id: root

    property var updatesList: []
    property bool isUpdating: false
    property string currentUpdatingPlugin: ""

    width: parent.width
    height: visible ? Math.max(200, innerColumn.implicitHeight + Theme.spacingL * 2) : 0
    radius: Theme.cornerRadius
    color: Theme.surfaceContainerHigh
    border.width: 0
    clip: true

    visible: false

    Behavior on height {
        enabled: Theme.currentAnimationSpeed !== SettingsData.AnimationSpeed.None
        NumberAnimation {
            duration: Theme.mediumDuration
            easing.type: Theme.standardEasing
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.shortDuration
        }
    }

    function show(list) {
        updatesList = list || [];
        visible = true;
    }

    function hide() {
        if (!isUpdating) {
            visible = false;
            updatesList = [];
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
                updatesList = updatesList.filter(p => p.id !== plugin.id);
                if (updatesList.length === 0) {
                    root.hide();
                }
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
                    updatesList = updatesList.filter(p => p.id !== plugin.id);
                }
                idx++;
                updateNext();
            });
        }

        updateNext();
    }

    Column {
        id: innerColumn
        anchors.fill: parent
        anchors.margins: Theme.spacingL
        spacing: Theme.spacingM

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
                text: I18n.tr("Available Updates (%1)").arg(root.updatesList.length)
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Font.Medium
                color: Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
            }

            Item {
                width: parent.width - parent.spacing * 2 - Theme.iconSize - parent.children[1].implicitWidth - collapseBtn.width
                height: 1
            }

            DankActionButton {
                id: collapseBtn
                iconName: "close"
                iconSize: Theme.iconSize - 2
                iconColor: Theme.outline
                anchors.verticalCenter: parent.verticalCenter
                enabled: !root.isUpdating
                onClicked: root.hide()
            }
        }

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

        DankFlickable {
            width: parent.width
            height: Math.min(listCol.implicitHeight, 300)
            clip: true
            contentHeight: listCol.implicitHeight
            visible: !isUpdating

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
                        color: Theme.surfaceContainerHighest
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
                                    backgroundColor: Theme.surfaceContainerHigh
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

        Row {
            anchors.right: parent.right
            spacing: Theme.spacingM
            visible: !isUpdating

            DankButton {
                text: I18n.tr("Cancel")
                iconName: "close"
                backgroundColor: Theme.surfaceContainerHighest
                textColor: Theme.surfaceText
                onClicked: root.hide()
            }

            DankButton {
                text: I18n.tr("Update All")
                iconName: "download"
                enabled: root.updatesList.length > 0
                onClicked: root.updateAll()
            }
        }
    }
}
