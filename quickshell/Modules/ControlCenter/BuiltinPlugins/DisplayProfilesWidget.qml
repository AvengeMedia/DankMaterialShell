import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import qs.Modules.Settings.DisplayConfig

PluginComponent {
    id: root

    readonly property var profiles: {
        const p = DisplayConfigState.validatedProfiles;
        const result = [];
        for (const id in p) {
            if (p[id].name)
                result.push({ id: id, name: p[id].name });
        }
        return result;
    }

    readonly property string activeProfileId: SettingsData.getActiveDisplayProfile(CompositorService.compositor)
    readonly property string activeProfileName: profiles.find(p => p.id === activeProfileId)?.name ?? ""

    ccWidgetIcon: "monitor"
    ccWidgetPrimaryText: I18n.tr("Display")
    ccWidgetSecondaryText: activeProfileName || (profiles.length === 0 ? I18n.tr("No profiles") : I18n.tr("None active"))
    ccWidgetIsActive: activeProfileName.length > 0

    onPillClicked: cycleNext()

    function cycleNext() {
        if (profiles.length < 2)
            return;
        const idx = profiles.findIndex(p => p.id === activeProfileId);
        const next = profiles[(idx + 1) % profiles.length];
        DisplayConfigState.activateProfile(next.id);
    }

    ccDetailContent: Component {
        Column {
            width: parent.width
            spacing: Theme.spacingS

            StyledText {
                visible: root.profiles.length === 0
                width: parent.width
                text: I18n.tr("No display profiles found. Create them in Settings → Displays.")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
            }

            DankButtonGroup {
                visible: root.profiles.length > 0
                width: parent.width
                model: root.profiles.map(p => p.name)
                currentIndex: root.profiles.findIndex(p => p.id === root.activeProfileId)
                onSelectionChanged: (index, selected) => {
                    if (selected)
                        DisplayConfigState.activateProfile(root.profiles[index].id);
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
                text: root.activeProfileName || I18n.tr("Display")
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
                text: root.activeProfileName || "—"
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeSmall
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }
}
