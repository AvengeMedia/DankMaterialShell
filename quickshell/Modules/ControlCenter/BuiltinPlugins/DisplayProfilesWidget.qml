import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins
import qs.Modules.Settings.DisplayConfig

PluginComponent {
    id: root

    readonly property var allProfiles: DisplayConfigState.validatedProfiles || ({})
    readonly property var profiles: {
        const result = [];
        for (const id in allProfiles) {
            if (allProfiles[id].name)
                result.push({ id: id, name: allProfiles[id].name });
        }
        return result;
    }
    readonly property bool autoMode: SettingsData.displayProfileAutoSelect
    readonly property string activeProfileId: SettingsData.getActiveDisplayProfile(CompositorService.compositor)
    readonly property var activeProfile: allProfiles[activeProfileId] || null
    readonly property string activeProfileName: activeProfile?.name ?? ""
    readonly property string displayProfileLabel: {
        if (autoMode)
            return I18n.tr("Auto");
        if (activeProfileName.length > 0)
            return activeProfileName;
        if (profiles.length === 0)
            return I18n.tr("No profiles");
        return I18n.tr("None active");
    }

    ccWidgetIcon: "monitor"
    ccWidgetPrimaryText: I18n.tr("Display")
    ccWidgetSecondaryText: displayProfileLabel
    ccWidgetIsActive: autoMode || activeProfileId.length > 0

    onCcWidgetToggled: cycleNext()

    function setAutoMode(enabled) {
        SettingsData.displayProfileAutoSelect = enabled;
        if (!enabled)
            SettingsData.setActiveDisplayProfile(CompositorService.compositor, "");
        SettingsData.saveSettings();
        if (enabled)
            DisplayConfigState.applyAutoConfig();
    }

    function cycleNext() {
        if (autoMode || profiles.length < 2)
            return;
        const idx = profiles.findIndex(p => p.id === activeProfileId);
        const next = profiles[(idx + 1) % profiles.length];
        DisplayConfigState.activateProfile(next.id);
    }

    ccDetailContent: Component {
        Rectangle {
            id: detailRoot
            implicitHeight: detailColumn.implicitHeight + Theme.spacingM * 2
            radius: Theme.cornerRadius
            color: Theme.nestedSurface
            border.color: Theme.outlineMedium
            border.width: Theme.layerOutlineWidth

            Column {
                id: detailColumn
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingS

                Item {
                    width: parent.width
                    height: 32

                    StyledText {
                        text: I18n.tr("Display Profiles")
                        font.pixelSize: Theme.fontSizeLarge
                        color: Theme.surfaceText
                        font.weight: Font.Medium
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingS

                        Rectangle {
                            id: autoButton
                            width: autoLabel.implicitWidth + Theme.spacingL * 2
                            height: 28
                            radius: 14
                            color: root.autoMode ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.16) : (autoMouseArea.containsMouse ? Theme.surfaceLight : "transparent")
                            border.color: root.autoMode ? Theme.primary : Theme.outlineMedium
                            border.width: root.autoMode ? 1 : Theme.layerOutlineWidth

                            StyledText {
                                id: autoLabel
                                anchors.centerIn: parent
                                text: I18n.tr("Auto")
                                color: root.autoMode ? Theme.primary : Theme.surfaceVariantText
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                            }

                            MouseArea {
                                id: autoMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.setAutoMode(!root.autoMode)
                            }
                        }

                        DankActionButton {
                            id: settingsButton
                            anchors.verticalCenter: parent.verticalCenter
                            iconName: "settings"
                            buttonSize: 28
                            iconSize: 16
                            iconColor: Theme.surfaceVariantText
                            onClicked: {
                                PopoutService.closeControlCenter();
                                PopoutService.openSettingsWithTab("displays");
                            }
                        }
                    }
                }

                StyledText {
                    visible: root.autoMode
                    width: parent.width
                    text: I18n.tr("Auto mode is on. Manual profile selection is disabled.")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    wrapMode: Text.WordWrap
                }

                StyledText {
                    visible: root.profiles.length === 0
                    width: parent.width
                    text: I18n.tr("No display profiles found. Create them in Settings > Displays.")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    wrapMode: Text.WordWrap
                }

                Column {
                    visible: root.profiles.length > 0
                    width: parent.width
                    spacing: Theme.spacingXS
                    opacity: root.autoMode ? 0.55 : 1.0

                    Repeater {
                        model: root.profiles

                        delegate: Rectangle {
                            required property var modelData

                            readonly property bool isActive: modelData.id === root.activeProfileId && !root.autoMode

                            width: detailColumn.width
                            height: 44
                            radius: Theme.cornerRadius
                            color: {
                                if (isActive)
                                    return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12);
                                if (profileMouseArea.containsMouse)
                                    return Theme.surfaceLight;
                                return Theme.floatingSurface;
                            }
                            border.color: isActive ? Theme.primary : Theme.outlineMedium
                            border.width: isActive ? 1 : Theme.layerOutlineWidth

                            StyledText {
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.spacingM
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.name
                                color: Theme.surfaceText
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: isActive ? Font.Medium : Font.Normal
                            }

                            StyledText {
                                anchors.right: parent.right
                                anchors.rightMargin: Theme.spacingM
                                anchors.verticalCenter: parent.verticalCenter
                                visible: isActive
                                text: I18n.tr("Active")
                                color: Theme.primary
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                            }

                            MouseArea {
                                id: profileMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: !root.autoMode
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: DisplayConfigState.activateProfile(modelData.id)
                            }
                        }
                    }
                }
            }
        }
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXS
            DankIcon {
                name: "monitor"
                color: Theme.primary
                size: root.iconSize
                anchors.verticalCenter: parent.verticalCenter
            }
            StyledText {
                text: root.displayProfileLabel
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeSmall
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: 2
            DankIcon {
                name: "monitor"
                color: Theme.primary
                size: root.iconSize
                anchors.horizontalCenter: parent.horizontalCenter
            }
            StyledText {
                text: root.displayProfileLabel
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeSmall
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }
}
