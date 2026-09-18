import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets

Item {
    id: root

    function indexedRules(predicate) {
        return (SettingsData.notificationRules || []).map((rule, index) => ({
                    rule: rule,
                    index: index
                })).filter(entry => predicate(entry.rule));
    }

    readonly property var mutedRules: indexedRules(rule => (rule.action || "").toString().toLowerCase() === "mute")

    readonly property var notificationRuleFieldOptions: [
        {
            value: "appName",
            label: I18n.tr("App names", "notification rule match field option")
        },
        {
            value: "desktopEntry",
            label: I18n.tr("Desktop Entry", "notification rule match field option")
        },
        {
            value: "summary",
            label: I18n.tr("Summary", "notification rule match field option")
        },
        {
            value: "body",
            label: I18n.tr("Body", "notification rule match field option")
        }
    ]

    readonly property var notificationRuleMatchTypeOptions: [
        {
            value: "contains",
            label: I18n.tr("Contains", "notification rule match type option")
        },
        {
            value: "exact",
            label: I18n.tr("Exact", "notification rule match type option")
        },
        {
            value: "regex",
            label: I18n.tr("Regex", "notification rule match type option")
        }
    ]

    readonly property var notificationRuleActionOptions: [
        {
            value: "default",
            label: I18n.tr("Default", "notification rule action option")
        },
        {
            value: "mute",
            label: I18n.tr("Mute Popups", "notification rule action option")
        },
        {
            value: "ignore",
            label: I18n.tr("Ignore Completely", "notification rule action option")
        },
        {
            value: "popup_only",
            label: I18n.tr("Popup Only", "notification rule action option")
        },
        {
            value: "no_history",
            label: I18n.tr("No History", "notification rule action option")
        }
    ]

    readonly property var notificationRuleUrgencyOptions: [
        {
            value: "default",
            label: I18n.tr("Default", "notification rule urgency option")
        },
        {
            value: "low",
            label: I18n.tr("Low Priority", "notification rule urgency option")
        },
        {
            value: "normal",
            label: I18n.tr("Normal Priority", "notification rule urgency option")
        },
        {
            value: "critical",
            label: I18n.tr("Critical Priority", "notification rule urgency option")
        }
    ]

    function getRuleOptionLabel(options, value, fallback) {
        for (let i = 0; i < options.length; i++) {
            if (options[i].value === value)
                return options[i].label;
        }
        return fallback;
    }

    function getRuleOptionValue(options, label, fallback) {
        for (let i = 0; i < options.length; i++) {
            if (options[i].label === label)
                return options[i].value;
        }
        return fallback;
    }

    SettingsPage {
        id: mainColumn

        SettingsCard {
            id: notificationRulesCard
            width: parent.width
            iconName: "rule_settings"
            title: I18n.tr("Rules", "noun, notification rules settings section title")
            settingKey: "notificationRules"
            tags: ["notification", "rules", "mute", "ignore", "priority", "regex", "history"]

            headerActions: [
                DankActionButton {
                    buttonSize: 36
                    iconName: "restart_alt"
                    tooltipText: I18n.tr("Reset to default")
                    iconSize: 20
                    visible: JSON.stringify(SettingsData.notificationRules) !== JSON.stringify(SettingsData.getDefaultNotificationRules())
                    iconColor: Theme.surfaceVariantText
                    onClicked: SettingsData.resetNotificationRules()
                },
                DankActionButton {
                    buttonSize: 36
                    iconName: "add"
                    Accessible.name: I18n.tr("Add")
                    iconSize: 20
                    iconColor: Theme.primary
                    onClicked: SettingsData.addNotificationRule()
                }
            ]

            SettingsRow {
                body: Column {
                    width: parent.width
                    spacing: Theme.spacingS

                    StyledText {
                        text: I18n.tr("The Default action only overrides priority")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        wrapMode: Text.WordWrap
                        width: parent.width
                        bottomPadding: Theme.spacingS
                    }

                    Repeater {
                        model: SettingsData.notificationRules

                        delegate: Rectangle {
                            id: ruleItem
                            width: parent.width
                            height: ruleColumn.implicitHeight + Theme.spacingM
                            radius: Theme.cornerRadius
                            color: Theme.floatingWindowFieldColor

                            Column {
                                id: ruleColumn
                                anchors.fill: parent
                                anchors.margins: Theme.spacingS
                                spacing: Theme.spacingS

                                Row {
                                    width: parent.width
                                    spacing: Theme.spacingS

                                    StyledText {
                                        id: ruleLabel
                                        text: I18n.tr("Rule %1", "notification rule heading, %1 is the rule number").arg(index + 1)
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Item {
                                        width: Math.max(0, parent.width - ruleLabel.implicitWidth - enableToggle.width - deleteBtn.width - Theme.spacingS * 3)
                                        height: 1
                                    }

                                    DankToggle {
                                        id: enableToggle
                                        width: 40
                                        height: 24
                                        hideText: true
                                        checked: modelData.enabled !== false
                                        onToggled: checked => SettingsData.updateNotificationRuleField(index, "enabled", checked)
                                    }

                                    Item {
                                        id: deleteBtn
                                        Accessible.role: Accessible.Button
                                        Accessible.name: I18n.tr("Remove")
                                        width: 28
                                        height: 28
                                        anchors.verticalCenter: parent.verticalCenter

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: Theme.cornerRadius
                                            color: deleteArea.containsMouse ? Theme.withAlpha(Theme.error, 0.2) : Theme.withAlpha(Theme.error, 0)
                                        }

                                        DankIcon {
                                            anchors.centerIn: parent
                                            name: "delete"
                                            size: 18
                                            color: deleteArea.containsMouse ? Theme.error : Theme.surfaceVariantText
                                        }

                                        MouseArea {
                                            id: deleteArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: SettingsData.removeNotificationRule(index)
                                        }
                                    }
                                }

                                Column {
                                    width: parent.width
                                    spacing: Theme.spacingXXS

                                    DankTextField {
                                        outlined: true
                                        leftIconName: "filter_list"
                                        labelText: I18n.tr("Pattern")
                                        width: parent.width
                                        text: modelData.pattern || ""
                                        font.pixelSize: Theme.fontSizeSmall
                                        onEditingFinished: SettingsData.updateNotificationRuleField(index, "pattern", text)
                                    }
                                }

                                Row {
                                    width: parent.width
                                    spacing: Theme.spacingS

                                    Column {
                                        width: (parent.width - Theme.spacingS * 3) / 4
                                        spacing: Theme.spacingXXS

                                        StyledText {
                                            text: I18n.tr("Field", "notification rule dropdown label, which notification field to match")
                                            font.pixelSize: Theme.fontSizeSmall - 1
                                            color: Theme.surfaceVariantText
                                        }

                                        DankDropdown {
                                            width: parent.width
                                            compactMode: true
                                            dropdownWidth: parent.width
                                            popupWidth: 165
                                            currentValue: root.getRuleOptionLabel(root.notificationRuleFieldOptions, modelData.field, root.notificationRuleFieldOptions[0].label)
                                            options: root.notificationRuleFieldOptions.map(o => o.label)
                                            onValueChanged: value => SettingsData.updateNotificationRuleField(index, "field", root.getRuleOptionValue(root.notificationRuleFieldOptions, value, "appName"))
                                        }
                                    }

                                    Column {
                                        width: (parent.width - Theme.spacingS * 3) / 4
                                        spacing: Theme.spacingXXS

                                        StyledText {
                                            text: I18n.tr("Type")
                                            font.pixelSize: Theme.fontSizeSmall - 1
                                            color: Theme.surfaceVariantText
                                        }

                                        DankDropdown {
                                            width: parent.width
                                            compactMode: true
                                            dropdownWidth: parent.width
                                            currentValue: root.getRuleOptionLabel(root.notificationRuleMatchTypeOptions, modelData.matchType, root.notificationRuleMatchTypeOptions[0].label)
                                            options: root.notificationRuleMatchTypeOptions.map(o => o.label)
                                            onValueChanged: value => SettingsData.updateNotificationRuleField(index, "matchType", root.getRuleOptionValue(root.notificationRuleMatchTypeOptions, value, "contains"))
                                        }
                                    }

                                    Column {
                                        width: (parent.width - Theme.spacingS * 3) / 4
                                        spacing: Theme.spacingXXS

                                        StyledText {
                                            text: I18n.tr("Action", "noun, dropdown label for what a notification rule or keybind does")
                                            font.pixelSize: Theme.fontSizeSmall - 1
                                            color: Theme.surfaceVariantText
                                        }

                                        DankDropdown {
                                            width: parent.width
                                            compactMode: true
                                            dropdownWidth: parent.width
                                            popupWidth: 170
                                            currentValue: root.getRuleOptionLabel(root.notificationRuleActionOptions, modelData.action, root.notificationRuleActionOptions[0].label)
                                            options: root.notificationRuleActionOptions.map(o => o.label)
                                            onValueChanged: value => SettingsData.updateNotificationRuleField(index, "action", root.getRuleOptionValue(root.notificationRuleActionOptions, value, "default"))
                                        }
                                    }

                                    Column {
                                        width: (parent.width - Theme.spacingS * 3) / 4
                                        spacing: Theme.spacingXXS

                                        StyledText {
                                            text: I18n.tr("Priority", "notification rule dropdown label, urgency assigned to matches")
                                            font.pixelSize: Theme.fontSizeSmall - 1
                                            color: Theme.surfaceVariantText
                                        }

                                        DankDropdown {
                                            width: parent.width
                                            compactMode: true
                                            dropdownWidth: parent.width
                                            popupWidth: 165
                                            currentValue: root.getRuleOptionLabel(root.notificationRuleUrgencyOptions, modelData.urgency, root.notificationRuleUrgencyOptions[0].label)
                                            options: root.notificationRuleUrgencyOptions.map(o => o.label)
                                            onValueChanged: value => SettingsData.updateNotificationRuleField(index, "urgency", root.getRuleOptionValue(root.notificationRuleUrgencyOptions, value, "default"))
                                        }
                                    }
                                }

                                Row {
                                    width: parent.width
                                    spacing: Theme.spacingS

                                    StyledText {
                                        id: bypassDndLabel
                                        text: I18n.tr("Allow in Do Not Disturb")
                                        font.pixelSize: Theme.fontSizeSmall - 1
                                        color: Theme.surfaceVariantText
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Item {
                                        width: Math.max(0, parent.width - bypassDndLabel.implicitWidth - bypassDndToggle.width - Theme.spacingS * 2)
                                        height: 1
                                    }

                                    DankToggle {
                                        id: bypassDndToggle
                                        width: 40
                                        height: 24
                                        hideText: true
                                        checked: modelData.bypassDnd === true
                                        onToggled: checked => SettingsData.updateNotificationRuleField(index, "bypassDnd", checked)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        SettingsCard {
            iconName: "volume_off"
            title: I18n.tr("Muted apps")
            settingKey: "mutedApps"
            tags: ["notification", "mute", "unmute", "popup"]

            SettingsRow {
                body: Column {
                    width: parent.width
                    spacing: Theme.spacingS

                    StyledText {
                        text: mutedRules.length > 0 ? I18n.tr("Apps with notification popups muted. Unmute or delete to remove.") : I18n.tr("No apps muted. Right-click a notification and choose \"Mute popups\" to add one here.")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        wrapMode: Text.WordWrap
                        width: parent.width
                        bottomPadding: Theme.spacingS
                    }

                    Repeater {
                        model: mutedRules

                        delegate: Rectangle {
                            width: parent.width
                            height: mutedRow.implicitHeight + Theme.spacingS * 2
                            radius: Theme.cornerRadius
                            color: Theme.floatingWindowFieldColor

                            Row {
                                id: mutedRow
                                anchors.fill: parent
                                anchors.margins: Theme.spacingS
                                spacing: Theme.spacingM

                                StyledText {
                                    id: mutedAppLabel
                                    text: (modelData.rule && modelData.rule.pattern) ? modelData.rule.pattern : I18n.tr("Unknown")
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Item {
                                    width: Math.max(0, parent.width - parent.spacing - mutedAppLabel.width - unmuteBtn.width - mutedDeleteBtn.width - Theme.spacingS * 5)
                                    height: 1
                                }

                                DankButton {
                                    id: unmuteBtn
                                    text: I18n.tr("Unmute")
                                    backgroundColor: Theme.chipSurface
                                    textColor: Theme.primary
                                    onClicked: SettingsData.removeNotificationRule(modelData.index)
                                }

                                Item {
                                    id: mutedDeleteBtn
                                    Accessible.role: Accessible.Button
                                    Accessible.name: I18n.tr("Remove")
                                    width: 28
                                    height: 28
                                    anchors.verticalCenter: parent.verticalCenter

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: Theme.cornerRadius
                                        color: mutedDeleteArea.containsMouse ? Theme.withAlpha(Theme.error, 0.2) : Theme.withAlpha(Theme.error, 0)
                                    }

                                    DankIcon {
                                        anchors.centerIn: parent
                                        name: "delete"
                                        size: 18
                                        color: mutedDeleteArea.containsMouse ? Theme.error : Theme.surfaceVariantText
                                    }

                                    MouseArea {
                                        id: mutedDeleteArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: SettingsData.removeNotificationRule(modelData.index)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
