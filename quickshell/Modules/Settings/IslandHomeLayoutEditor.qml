pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets

Column {
    id: root

    readonly property bool isSettingsRow: true
    readonly property bool transparentSlot: true

    property string settingKey: "islandHomeLayout"
    required property string barId
    readonly property var groupIds: SettingsData._islandHomeGroupIds
    readonly property var layout: {
        SettingsData.barConfigs;
        return SettingsData.getIslandHomeLayout(SettingsData.getBarConfig(root.barId));
    }
    readonly property bool isHighlighted: settingKey !== "" && SettingsSearchService.highlightSection === settingKey

    readonly property var presentation: ({
            "media": {
                "icon": "music_note",
                "text": I18n.tr("Media / Launcher", "island settings: media or launcher slot row"),
                "description": ""
            },
            "clock": {
                "icon": "schedule",
                "text": I18n.tr("Clock", "island settings: pinned clock row in the home layout"),
                "description": I18n.tr("Current time and date display")
            },
            "weather": {
                "icon": "wb_sunny",
                "text": I18n.tr("Weather", "island settings: weather slot row"),
                "description": SettingsData.weatherEnabled ? "" : I18n.tr("Enable weather in Time & Weather to show this shortcut", "island settings: weather slot disabled hint")
            },
            "status": {
                "icon": "settings",
                "text": I18n.tr("Control Center", "island settings: battery or control center slot row"),
                "description": ""
            },
            "volume": {
                "icon": "volume_up",
                "text": I18n.tr("Volume", "island settings: volume slot row"),
                "description": ""
            },
            "brightness": {
                "icon": "brightness_6",
                "text": I18n.tr("Brightness", "island settings: brightness slot row"),
                "description": ""
            },
            "notifications": {
                "icon": "notifications",
                "text": I18n.tr("Notifications", "island settings: notification badge slot row"),
                "description": ""
            }
        })

    readonly property var enabledGroups: layout.filter(group => group.enabled)
    readonly property var disabledGroups: layout.filter(group => !group.enabled)
    readonly property bool hasHidden: disabledGroups.length > 0
    property bool showHidden: false

    readonly property bool isFirstInGroup: parent?.isSettingsGroupHost ? parent.isEdge(root, true) : true
    readonly property bool isLastInGroup: parent?.isSettingsGroupHost ? parent.isEdge(root, false) : true
    readonly property real topRadius: isFirstInGroup ? Theme.groupedListOuterRadius : Theme.groupedListInnerRadius
    readonly property real bottomRadius: isLastInGroup ? Theme.groupedListOuterRadius : Theme.groupedListInnerRadius

    width: parent?.width ?? 0
    spacing: Theme.groupedListGap

    SettingsSearchRegistration {
        target: root
        settingKey: root.settingKey
    }

    SettingsRow {
        topRadius: root.topRadius
        bottomRadius: Theme.groupedListInnerRadius
        body: StyledText {
            width: parent.width
            text: I18n.tr("Drag groups above the clock to sit left of it, below to sit right. Click the eye to hide a group.", "island settings: home layout editor hint")
            color: Theme.surfaceVariantText
            font.pixelSize: Theme.fontSizeSmall
            wrapMode: Text.WordWrap
        }
    }

    SettingsReorderList {
        id: enabledList

        model: root.enabledGroups
        onReordered: indices => SettingsData.setIslandHomeLayoutOrder(root.barId, indices.map(i => root.enabledGroups[i].id).concat(root.disabledGroups.map(group => group.id)))

        delegate: SettingsReorderRow {
            id: groupRow

            required property var modelData

            reorderList: enabledList
            topRadius: dragging ? Theme.groupedListOuterRadius : Theme.groupedListInnerRadius
            bottomRadius: dragging ? Theme.groupedListOuterRadius : (position === enabledList.count - 1 && !root.hasHidden ? root.bottomRadius : Theme.groupedListInnerRadius)
            title: root.presentation[modelData.id].text
            subtitle: root.presentation[modelData.id].description
            iconName: root.presentation[modelData.id].icon

            DankIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: "lock"
                size: Theme.iconSizeMedium
                color: Theme.onSurfaceVariant
                visible: groupRow.modelData.id === "clock"
            }

            DankActionButton {
                anchors.verticalCenter: parent.verticalCenter
                visible: groupRow.modelData.id !== "clock"
                iconName: "visibility"
                tooltipText: I18n.tr("Hide", "island settings: hide home group")
                onClicked: SettingsData.setIslandHomeGroupEnabled(root.barId, groupRow.modelData.id, false)
            }
        }
    }

    SettingsRow {
        topRadius: Theme.groupedListInnerRadius
        bottomRadius: root.showHidden ? Theme.groupedListInnerRadius : root.bottomRadius
        title: I18n.tr("Hidden (%1)", "island settings: hidden groups divider, %1 is count").arg(root.disabledGroups.length)
        iconName: "visibility_off"
        visible: root.hasHidden
        clickable: true
        onClicked: root.showHidden = !root.showHidden

        DankIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: root.showHidden ? "expand_less" : "expand_more"
            size: Theme.iconSize
            color: Theme.onSurfaceVariant
        }
    }

    Column {
        width: parent.width
        spacing: Theme.groupedListGap
        visible: root.showHidden && root.hasHidden

        Repeater {
            model: root.disabledGroups

            SettingsRow {
                id: hiddenRow

                required property int index
                required property var modelData

                topRadius: Theme.groupedListInnerRadius
                bottomRadius: index === root.disabledGroups.length - 1 ? root.bottomRadius : Theme.groupedListInnerRadius
                title: root.presentation[modelData.id].text
                subtitle: root.presentation[modelData.id].description
                iconName: root.presentation[modelData.id].icon
                iconColor: Theme.onSurfaceVariant

                DankActionButton {
                    anchors.verticalCenter: parent.verticalCenter
                    iconName: "visibility_off"
                    tooltipText: I18n.tr("Show", "island settings: show home group")
                    onClicked: SettingsData.setIslandHomeGroupEnabled(root.barId, hiddenRow.modelData.id, true)
                }
            }
        }
    }
}
