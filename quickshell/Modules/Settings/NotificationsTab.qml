import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Settings.Widgets

Item {
    id: root

    Component.onCompleted: {
        if (SettingsData._pendingExpandNotificationRules) {
            SettingsData._pendingExpandNotificationRules = false;
            notificationRulesCard.userToggledCollapse = true;
            notificationRulesCard.expanded = true;
            SettingsData._pendingNotificationRuleIndex = -1;
        }
    }

    readonly property var mutedRules: {
        var rules = SettingsData.notificationRules || [];
        var out = [];
        for (var i = 0; i < rules.length; i++) {
            if ((rules[i].action || "").toString().toLowerCase() === "mute")
                out.push({ rule: rules[i], index: i });
        }
        return out;
    }

    readonly property var timeoutOptions: [
        {
            text: I18n.tr("Never"),
            value: 0
        },
        {
            text: I18n.tr("1 second"),
            value: 1000
        },
        {
            text: I18n.tr("3 seconds"),
            value: 3000
        },
        {
            text: I18n.tr("5 seconds"),
            value: 5000
        },
        {
            text: I18n.tr("8 seconds"),
            value: 8000
        },
        {
            text: I18n.tr("10 seconds"),
            value: 10000
        },
        {
            text: I18n.tr("15 seconds"),
            value: 15000
        },
        {
            text: I18n.tr("30 seconds"),
            value: 30000
        },
        {
            text: I18n.tr("1 minute"),
            value: 60000
        },
        {
            text: I18n.tr("2 minutes"),
            value: 120000
        },
        {
            text: I18n.tr("5 minutes"),
            value: 300000
        },
        {
            text: I18n.tr("10 minutes"),
            value: 600000
        }
    ]

    readonly property var notificationRuleFieldOptions: [
        {
            value: "appName",
            label: I18n.tr("App Names", "notification rule match field option")
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

    function getTimeoutText(value) {
        if (value === undefined || value === null || isNaN(value))
            return I18n.tr("5 seconds");
        for (let i = 0; i < timeoutOptions.length; i++) {
            if (timeoutOptions[i].value === value)
                return timeoutOptions[i].text;
        }
        if (value === 0)
            return I18n.tr("Never");
        if (value < 1000)
            return value + "ms";
        if (value < 60000)
            return Math.round(value / 1000) + " " + I18n.tr("seconds");
        return Math.round(value / 60000) + " " + I18n.tr("minutes");
    }

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

    DankFlickable {
        anchors.fill: parent
        clip: true
        contentHeight: mainColumn.height + Theme.spacingXL
        contentWidth: width

        Column {
            id: mainColumn
            topPadding: 4
            width: Math.min(550, parent.width - Theme.spacingL * 2)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.spacingXL

            SettingsCard {
                width: parent.width
                iconName: "notifications"
                title: I18n.tr("Notification Popups")
                settingKey: "notificationPopups"

                SettingsDropdownRow {
                    settingKey: "notificationPopupPosition"
                    tags: ["notification", "popup", "position", "screen", "location"]
                    text: I18n.tr("Popup Position")
                    description: I18n.tr("Choose where notification popups appear on screen")
                    currentValue: {
                        if (SettingsData.notificationPopupPosition === -1)
                            return I18n.tr("Top Center", "screen position option");
                        switch (SettingsData.notificationPopupPosition) {
                        case SettingsData.Position.Top:
                            return I18n.tr("Top Right", "screen position option");
                        case SettingsData.Position.Bottom:
                            return I18n.tr("Bottom Left", "screen position option");
                        case SettingsData.Position.Left:
                            return I18n.tr("Top Left", "screen position option");
                        case SettingsData.Position.Right:
                            return I18n.tr("Bottom Right", "screen position option");
                        case SettingsData.Position.BottomCenter:
                            return I18n.tr("Bottom Center", "screen position option");
                        default:
                            return I18n.tr("Top Right", "screen position option");
                        }
                    }
                    options: [I18n.tr("Top Right", "screen position option"), I18n.tr("Top Left", "screen position option"), I18n.tr("Top Center", "screen position option"), I18n.tr("Bottom Center", "screen position option"), I18n.tr("Bottom Right", "screen position option"), I18n.tr("Bottom Left", "screen position option")]
                    onValueChanged: value => {
                        switch (value) {
                        case I18n.tr("Top Right", "screen position option"):
                            SettingsData.set("notificationPopupPosition", SettingsData.Position.Top);
                            break;
                        case I18n.tr("Top Left", "screen position option"):
                            SettingsData.set("notificationPopupPosition", SettingsData.Position.Left);
                            break;
                        case I18n.tr("Top Center", "screen position option"):
                            SettingsData.set("notificationPopupPosition", -1);
                            break;
                        case I18n.tr("Bottom Center", "screen position option"):
                            SettingsData.set("notificationPopupPosition", SettingsData.Position.BottomCenter);
                            break;
                        case I18n.tr("Bottom Right", "screen position option"):
                            SettingsData.set("notificationPopupPosition", SettingsData.Position.Right);
                            break;
                        case I18n.tr("Bottom Left", "screen position option"):
                            SettingsData.set("notificationPopupPosition", SettingsData.Position.Bottom);
                            break;
                        }
                        SettingsData.sendTestNotifications();
                    }
                }

                SettingsToggleRow {
                    settingKey: "notificationOverlayEnabled"
                    tags: ["notification", "overlay", "fullscreen", "priority"]
                    text: I18n.tr("Notification Overlay")
                    description: I18n.tr("Display all priorities over fullscreen apps")
                    checked: SettingsData.notificationOverlayEnabled
                    onToggled: checked => SettingsData.set("notificationOverlayEnabled", checked)
                }

                SettingsToggleRow {
                    settingKey: "notificationCompactMode"
                    tags: ["notification", "compact", "size", "display", "mode"]
                    text: I18n.tr("Compact")
                    description: I18n.tr("Use smaller notification cards")
                    checked: SettingsData.notificationCompactMode
                    onToggled: checked => SettingsData.set("notificationCompactMode", checked)
                }

                SettingsToggleRow {
                    settingKey: "notificationPopupShadowEnabled"
                    tags: ["notification", "popup", "shadow", "radius", "rounded"]
                    text: I18n.tr("Popup Shadow")
                    description: I18n.tr("Show drop shadow on notification popups")
                    checked: SettingsData.notificationPopupShadowEnabled
                    onToggled: checked => SettingsData.set("notificationPopupShadowEnabled", checked)
                }

                SettingsToggleRow {
                    settingKey: "notificationPopupPrivacyMode"
                    tags: ["notification", "popup", "privacy", "body", "content", "hide"]
                    text: I18n.tr("Privacy Mode")
                    description: I18n.tr("Hide notification content until expanded; popups show collapsed by default")
                    checked: SettingsData.notificationPopupPrivacyMode
                    onToggled: checked => SettingsData.set("notificationPopupPrivacyMode", checked)
                }

                Item {
                    width: parent.width
                    height: notificationAnimationColumn.implicitHeight + Theme.spacingM * 2

                    Column {
                        id: notificationAnimationColumn
                        width: parent.width - Theme.spacingM * 2
                        x: Theme.spacingM
                        anchors.top: parent.top
                        anchors.topMargin: Theme.spacingM
                        spacing: Theme.spacingS

                        StyledText {
                            text: I18n.tr("Animation Speed")
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            width: parent.width
                        }

                        StyledText {
                            text: I18n.tr("Control animation duration for notification popups and history")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            wrapMode: Text.WordWrap
                            width: parent.width
                        }

                        DankButtonGroup {
                            id: notificationSpeedGroup
                            anchors.horizontalCenter: parent.horizontalCenter
                            buttonPadding: parent.width < 480 ? Theme.spacingS : Theme.spacingM
                            minButtonWidth: parent.width < 480 ? 44 : 56
                            textSize: parent.width < 480 ? Theme.fontSizeSmall : Theme.fontSizeMedium
                            model: [I18n.tr("None"), I18n.tr("Short"), I18n.tr("Medium"), I18n.tr("Long"), I18n.tr("Custom")]
                            selectionMode: "single"
                            currentIndex: SettingsData.notificationAnimationSpeed
                            onSelectionChanged: (index, selected) => {
                                if (!selected)
                                    return;
                                SettingsData.set("notificationAnimationSpeed", index);
                            }

                            Connections {
                                target: SettingsData
                                function onNotificationAnimationSpeedChanged() {
                                    notificationSpeedGroup.currentIndex = SettingsData.notificationAnimationSpeed;
                                }
                            }
                        }

                        SettingsSliderRow {
                            settingKey: "notificationCustomAnimationDuration"
                            tags: ["notification", "animation", "duration", "custom", "speed"]
                            text: I18n.tr("Duration")
                            description: I18n.tr("Base duration for animations (drag to use Custom)")
                            minimum: 100
                            maximum: 800
                            value: Theme.notificationAnimationBaseDuration
                            unit: "ms"
                            defaultValue: 400
                            onSliderValueChanged: newValue => {
                                if (SettingsData.notificationAnimationSpeed !== SettingsData.AnimationSpeed.Custom) {
                                    SettingsData.set("notificationAnimationSpeed", SettingsData.AnimationSpeed.Custom);
                                }
                                SettingsData.set("notificationCustomAnimationDuration", newValue);
                            }
                        }
                    }
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "notifications_off"
                title: I18n.tr("Do Not Disturb")
                settingKey: "doNotDisturb"

                SettingsToggleRow {
                    settingKey: "doNotDisturb"
                    tags: ["notification", "dnd", "mute", "silent", "suppress"]
                    text: I18n.tr("Enable Do Not Disturb")
                    description: I18n.tr("Suppress notification popups while enabled")
                    checked: SessionData.doNotDisturb
                    onToggled: checked => SessionData.setDoNotDisturb(checked)
                }
            }

            SettingsCard {
                id: notificationRulesCard
                width: parent.width
                iconName: "rule_settings"
                title: I18n.tr("Notification Rules")
                settingKey: "notificationRules"
                tags: ["notification", "rules", "mute", "ignore", "priority", "regex", "history"]
                collapsible: true
                expanded: false

                headerActions: [
                    DankActionButton {
                        buttonSize: 36
                        iconName: "restart_alt"
                        iconSize: 20
                        visible: JSON.stringify(SettingsData.notificationRules) !== JSON.stringify(SettingsData.getDefaultNotificationRules())
                        backgroundColor: Theme.surfaceContainer
                        iconColor: Theme.surfaceVariantText
                        onClicked: SettingsData.resetNotificationRules()
                    },
                    DankActionButton {
                        buttonSize: 36
                        iconName: "add"
                        iconSize: 20
                        backgroundColor: Theme.surfaceContainer
                        iconColor: Theme.primary
                        onClicked: {
                            SettingsData.addNotificationRule();
                            notificationRulesCard.userToggledCollapse = true;
                            notificationRulesCard.expanded = true;
                        }
                    }
                ]

                Column {
                    width: parent.width
                    spacing: Theme.spacingS

                    StyledText {
                        text: I18n.tr("Create rules to mute, ignore, hide from history, or override notification priority. Default only overrides priority; notifications still show normally.")
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
                            color: Theme.withAlpha(Theme.surfaceContainer, 0.5)

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
                                        text: I18n.tr("Rule") + " " + (index + 1)
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
                                        width: 28
                                        height: 28
                                        anchors.verticalCenter: parent.verticalCenter

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: Theme.cornerRadius
                                            color: deleteArea.containsMouse ? Theme.withAlpha(Theme.error, 0.2) : "transparent"
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
                                    spacing: 2

                                    StyledText {
                                        text: I18n.tr("Pattern")
                                        font.pixelSize: Theme.fontSizeSmall - 1
                                        color: Theme.surfaceVariantText
                                    }

                                    DankTextField {
                                        width: parent.width
                                        text: modelData.pattern || ""
                                        font.pixelSize: Theme.fontSizeSmall
                                        placeholderText: I18n.tr("Pattern")
                                        onEditingFinished: SettingsData.updateNotificationRuleField(index, "pattern", text)
                                    }
                                }

                                Row {
                                    width: parent.width
                                    spacing: Theme.spacingS

                                    Column {
                                        width: (parent.width - Theme.spacingS * 3) / 4
                                        spacing: 2

                                        StyledText {
                                            text: I18n.tr("Field")
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
                                        spacing: 2

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
                                        spacing: 2

                                        StyledText {
                                            text: I18n.tr("Action")
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
                                        spacing: 2

                                        StyledText {
                                            text: I18n.tr("Priority")
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
                            }
                        }
                    }
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "volume_off"
                title: I18n.tr("Muted Apps")
                settingKey: "mutedApps"
                tags: ["notification", "mute", "unmute", "popup"]

                Column {
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
                            color: Theme.withAlpha(Theme.surfaceContainer, 0.5)

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
                                    width: Math.max(0, parent.width - parent.spacing - mutedAppLabel.width - unmuteBtn.width - deleteBtn.width - Theme.spacingS * 5)
                                    height: 1
                                }

                                DankButton {
                                    id: unmuteBtn
                                    text: I18n.tr("Unmute")
                                    backgroundColor: Theme.surfaceContainer
                                    textColor: Theme.primary
                                    onClicked: SettingsData.removeNotificationRule(modelData.index)
                                }

                                Item {
                                    id: deleteBtn
                                    width: 28
                                    height: 28
                                    anchors.verticalCenter: parent.verticalCenter

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: Theme.cornerRadius
                                        color: deleteArea.containsMouse ? Theme.withAlpha(Theme.error, 0.2) : "transparent"
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
                                        onClicked: SettingsData.removeNotificationRule(modelData.index)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "lock"
                title: I18n.tr("Lock Screen", "lock screen notifications settings card")
                settingKey: "lockScreenNotifications"

                SettingsDropdownRow {
                    settingKey: "lockScreenNotificationMode"
                    tags: ["lock", "screen", "notification", "notifications", "privacy"]
                    text: I18n.tr("Notification Display", "lock screen notification privacy setting")
                    description: I18n.tr("Control what notification information is shown on the lock screen", "lock screen notification privacy setting")
                    options: [I18n.tr("Disabled", "lock screen notification mode option"), I18n.tr("Count Only", "lock screen notification mode option"), I18n.tr("App Names", "lock screen notification mode option"), I18n.tr("Full Content", "lock screen notification mode option")]
                    currentValue: options[SettingsData.lockScreenNotificationMode] || options[0]
                    onValueChanged: value => {
                        const idx = options.indexOf(value);
                        if (idx >= 0) {
                            SettingsData.set("lockScreenNotificationMode", idx);
                        }
                    }
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "timer"
                title: I18n.tr("Notification Timeouts")
                settingKey: "notificationTimeouts"
                collapsible: true
                expanded: false

                SettingsDropdownRow {
                    settingKey: "notificationTimeoutLow"
                    tags: ["notification", "timeout", "low", "priority", "duration"]
                    text: I18n.tr("Low Priority")
                    description: I18n.tr("Timeout for low priority notifications")
                    currentValue: root.getTimeoutText(SettingsData.notificationTimeoutLow)
                    options: root.timeoutOptions.map(opt => opt.text)
                    onValueChanged: value => {
                        for (let i = 0; i < root.timeoutOptions.length; i++) {
                            if (root.timeoutOptions[i].text === value) {
                                SettingsData.set("notificationTimeoutLow", root.timeoutOptions[i].value);
                                break;
                            }
                        }
                    }
                }

                SettingsDropdownRow {
                    settingKey: "notificationTimeoutNormal"
                    tags: ["notification", "timeout", "normal", "priority", "duration"]
                    text: I18n.tr("Normal Priority")
                    description: I18n.tr("Timeout for normal priority notifications")
                    currentValue: root.getTimeoutText(SettingsData.notificationTimeoutNormal)
                    options: root.timeoutOptions.map(opt => opt.text)
                    onValueChanged: value => {
                        for (let i = 0; i < root.timeoutOptions.length; i++) {
                            if (root.timeoutOptions[i].text === value) {
                                SettingsData.set("notificationTimeoutNormal", root.timeoutOptions[i].value);
                                break;
                            }
                        }
                    }
                }

                SettingsDropdownRow {
                    settingKey: "notificationTimeoutCritical"
                    tags: ["notification", "timeout", "critical", "priority", "duration"]
                    text: I18n.tr("Critical Priority")
                    description: I18n.tr("Timeout for critical priority notifications")
                    currentValue: root.getTimeoutText(SettingsData.notificationTimeoutCritical)
                    options: root.timeoutOptions.map(opt => opt.text)
                    onValueChanged: value => {
                        for (let i = 0; i < root.timeoutOptions.length; i++) {
                            if (root.timeoutOptions[i].text === value) {
                                SettingsData.set("notificationTimeoutCritical", root.timeoutOptions[i].value);
                                break;
                            }
                        }
                    }
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "history"
                title: I18n.tr("History Settings")
                settingKey: "notificationHistory"

                SettingsToggleRow {
                    settingKey: "notificationHistoryEnabled"
                    tags: ["notification", "history", "enable", "disable", "save"]
                    text: I18n.tr("Enable History", "notification history toggle label")
                    description: I18n.tr("Save dismissed notifications to history", "notification history toggle description")
                    checked: SettingsData.notificationHistoryEnabled
                    onToggled: checked => SettingsData.set("notificationHistoryEnabled", checked)
                }

                SettingsSliderRow {
                    settingKey: "notificationHistoryMaxCount"
                    tags: ["notification", "history", "max", "count", "limit"]
                    text: I18n.tr("Maximum History")
                    description: I18n.tr("Maximum number of notifications to keep", "notification history limit")
                    value: SettingsData.notificationHistoryMaxCount
                    minimum: 10
                    maximum: 200
                    step: 10
                    unit: ""
                    defaultValue: 50
                    onSliderValueChanged: newValue => SettingsData.set("notificationHistoryMaxCount", newValue)
                }

                SettingsDropdownRow {
                    settingKey: "notificationHistoryMaxAgeDays"
                    tags: ["notification", "history", "max", "age", "days", "retention"]
                    text: I18n.tr("History Retention", "notification history retention settings label")
                    description: I18n.tr("Auto-delete notifications older than this", "notification history setting")
                    currentValue: {
                        switch (SettingsData.notificationHistoryMaxAgeDays) {
                        case 0:
                            return I18n.tr("Forever", "notification history retention option");
                        case 1:
                            return I18n.tr("1 day", "notification history retention option");
                        case 3:
                            return I18n.tr("3 days", "notification history retention option");
                        case 7:
                            return I18n.tr("7 days", "notification history retention option");
                        case 14:
                            return I18n.tr("14 days", "notification history retention option");
                        case 30:
                            return I18n.tr("30 days", "notification history retention option");
                        default:
                            return SettingsData.notificationHistoryMaxAgeDays + " " + I18n.tr("days");
                        }
                    }
                    options: [I18n.tr("Forever", "notification history retention option"), I18n.tr("1 day", "notification history retention option"), I18n.tr("3 days", "notification history retention option"), I18n.tr("7 days", "notification history retention option"), I18n.tr("14 days", "notification history retention option"), I18n.tr("30 days", "notification history retention option")]
                    onValueChanged: value => {
                        let days = 7;
                        if (value === I18n.tr("Forever", "notification history retention option"))
                            days = 0;
                        else if (value === I18n.tr("1 day", "notification history retention option"))
                            days = 1;
                        else if (value === I18n.tr("3 days", "notification history retention option"))
                            days = 3;
                        else if (value === I18n.tr("7 days", "notification history retention option"))
                            days = 7;
                        else if (value === I18n.tr("14 days", "notification history retention option"))
                            days = 14;
                        else if (value === I18n.tr("30 days", "notification history retention option"))
                            days = 30;
                        SettingsData.set("notificationHistoryMaxAgeDays", days);
                    }
                }

                SettingsToggleRow {
                    settingKey: "notificationHistorySaveLow"
                    tags: ["notification", "history", "save", "low", "priority"]
                    text: I18n.tr("Low Priority")
                    description: I18n.tr("Save low priority notifications to history", "notification history setting")
                    checked: SettingsData.notificationHistorySaveLow
                    onToggled: checked => SettingsData.set("notificationHistorySaveLow", checked)
                }

                SettingsToggleRow {
                    settingKey: "notificationHistorySaveNormal"
                    tags: ["notification", "history", "save", "normal", "priority"]
                    text: I18n.tr("Normal Priority")
                    description: I18n.tr("Save normal priority notifications to history", "notification history setting")
                    checked: SettingsData.notificationHistorySaveNormal
                    onToggled: checked => SettingsData.set("notificationHistorySaveNormal", checked)
                }

                SettingsToggleRow {
                    settingKey: "notificationHistorySaveCritical"
                    tags: ["notification", "history", "save", "critical", "priority"]
                    text: I18n.tr("Critical Priority")
                    description: I18n.tr("Save critical priority notifications to history", "notification history setting")
                    checked: SettingsData.notificationHistorySaveCritical
                    onToggled: checked => SettingsData.set("notificationHistorySaveCritical", checked)
                }
            }
        }
    }
}
