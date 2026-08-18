import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets

// One installed chat provider, as its own container in Settings -> Chats.
//
// Everything provider-specific is declared by the plugin -- its name, icon,
// warning and settings component -- so nothing here knows what WhatsApp or
// Signal is. Adding a provider means installing a plugin, not editing this file.
StyledRect {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    required property var provider

    readonly property string providerId: provider?.id ?? ""
    readonly property string providerName: provider?.name || providerId
    readonly property string providerIcon: provider?.icon || "forum"
    readonly property string description: provider?.description ?? ""
    readonly property string warning: provider?.warning ?? ""
    readonly property bool enabled: provider?.enabled ?? false
    readonly property string state: provider?.state ?? "disconnected"
    readonly property int unread: provider?.unread ?? 0
    readonly property string lastError: provider?.lastError ?? ""
    readonly property string settingsPath: provider?.settingsQml ?? ""
    readonly property bool hasSettings: settingsPath !== ""
    readonly property var notifications: provider?.notifications ?? ({})

    readonly property bool needsLogin: state === "needsLogin"
    readonly property bool connected: state === "connected"

    readonly property string stateLabel: {
        switch (root.state) {
        case "connected":
            return I18n.tr("Connected");
        case "connecting":
            return I18n.tr("Connecting...");
        case "needsLogin":
            return I18n.tr("Sign-in required");
        default:
            return root.enabled ? I18n.tr("Disconnected") : I18n.tr("Off");
        }
    }

    readonly property color stateColor: {
        switch (root.state) {
        case "connected":
            return Theme.success;
        case "connecting":
            return Theme.surfaceVariantText;
        case "needsLogin":
            return Theme.warning;
        default:
            return root.enabled ? Theme.error : Theme.surfaceVariantText;
        }
    }

    // Tags the host works out for itself. Excluded from the per-tag toggles
    // because each already has a named setting above -- listing them twice gave
    // two controls with almost the same label doing the same thing.
    readonly property var derivedTags: ["archived", "muted", "unread", "group", "direct"]

    // The provider's own categories: WhatsApp's statuses and channels, a mail
    // account's labels. These are the ones with no named setting of their own.
    readonly property var providerTags: {
        const seen = {};
        const out = [];
        for (let i = 0; i < ChatService.chats.length; i++) {
            const chat = ChatService.chats[i];
            if (chat.provider !== root.providerId)
                continue;
            const tags = chat.tags || [];
            for (let t = 0; t < tags.length; t++) {
                const tag = tags[t];
                if (seen[tag] || root.derivedTags.indexOf(tag) !== -1)
                    continue;
                seen[tag] = true;
                out.push(tag);
            }
        }
        out.sort();
        return out;
    }

    function setTagNotify(tag, notify) {
        const current = (root.notifications?.mutedTags ?? []).slice();
        const at = current.indexOf(tag);

        if (!notify && at === -1)
            current.push(tag);
        else if (notify && at !== -1)
            current.splice(at, 1);
        else
            return;

        ChatService.setProviderNotifications(root.providerId, {
            "mutedTags": current
        });
    }

    function setNotification(key, value) {
        const params = {};
        params[key] = value;
        ChatService.setProviderNotifications(root.providerId, params);
    }

    width: parent.width
    height: contentColumn.implicitHeight + Theme.spacingL * 2
    radius: Theme.cornerRadius
    color: Theme.floatingWindowNestedSurface
    border.color: Theme.outlineMedium
    border.width: Theme.layerOutlineWidth

    Column {
        id: contentColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.spacingL
        spacing: Theme.spacingM

        // ------------------------------------------------------------ header

        Row {
            width: parent.width
            spacing: Theme.spacingM

            DankIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: root.providerIcon
                size: Theme.iconSizeLarge
                color: root.enabled ? Theme.primary : Theme.surfaceVariantText
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - Theme.iconSizeLarge - enableToggle.width - Theme.spacingM * 2
                spacing: 2

                Row {
                    width: parent.width
                    spacing: Theme.spacingS

                    StyledText {
                        text: root.providerName
                        font.pixelSize: Theme.fontSizeLarge
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                    }

                    StyledRect {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.unread > 0
                        width: unreadText.implicitWidth + Theme.spacingS * 2
                        height: unreadText.implicitHeight + 2
                        radius: height / 2
                        color: Theme.primary

                        StyledText {
                            id: unreadText
                            anchors.centerIn: parent
                            text: root.unread > 99 ? "99+" : root.unread
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.onPrimary
                        }
                    }
                }

                Row {
                    width: parent.width
                    spacing: Theme.spacingXS

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 6
                        height: 6
                        radius: 3
                        color: root.stateColor
                    }

                    StyledText {
                        width: parent.width - 6 - Theme.spacingXS
                        text: root.lastError !== "" ? root.lastError : root.stateLabel
                        font.pixelSize: Theme.fontSizeSmall
                        color: root.lastError !== "" ? Theme.error : Theme.surfaceVariantText
                        elide: Text.ElideRight
                    }
                }
            }

            DankToggle {
                id: enableToggle
                anchors.verticalCenter: parent.verticalCenter
                checked: root.enabled
                // Enabling starts the provider's bridge process; disabling stops it.
                onToggled: checked => ChatService.setProviderEnabled(root.providerId, checked)
            }
        }

        StyledText {
            width: parent.width
            text: root.description
            visible: root.description !== ""
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
        }

        // ----------------------------------------------------------- warning

        // Declared by the plugin, not the shell. A provider that carries a real
        // caveat says so itself, and it is shown before the user turns it on.
        StyledRect {
            width: parent.width
            visible: root.warning !== ""
            height: warningRow.implicitHeight + Theme.spacingM * 2
            radius: Theme.cornerRadius / 2
            color: Theme.withAlpha(Theme.warning, 0.12)
            border.color: Theme.withAlpha(Theme.warning, 0.35)
            border.width: 1

            Row {
                id: warningRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingS

                DankIcon {
                    name: "warning"
                    size: Theme.iconSize
                    color: Theme.warning
                }

                StyledText {
                    width: parent.width - Theme.iconSize - Theme.spacingS
                    text: root.warning
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                    wrapMode: Text.WordWrap
                }
            }
        }

        // ------------------------------------------------------------- auth

        ChatProviderAuth {
            width: parent.width
            visible: root.enabled && root.needsLogin
            providerId: root.providerId
        }

        // ---------------------------------------------------- notifications

        SettingsDivider {
            width: parent.width
            visible: root.enabled
        }

        StyledText {
            width: parent.width
            visible: root.enabled
            text: I18n.tr("Notifications")
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Medium
            color: Theme.surfaceText
        }

        // Per provider rather than global: a work account and a family one
        // rarely want the same answer, and one global setting lets the noisiest
        // provider decide for all of them.
        Column {
            width: parent.width
            visible: root.enabled
            spacing: Theme.spacingM

            SettingsToggleRow {
                width: parent.width
                text: I18n.tr("Do Not Disturb")
                description: I18n.tr("Silence this provider without losing the settings below")
                checked: root.notifications?.doNotDisturb ?? false
                onToggled: checked => root.setNotification("doNotDisturb", checked)
            }

            SettingsToggleRow {
                width: parent.width
                text: I18n.tr("Notify for new messages")
                checked: root.notifications?.enabled ?? true
                enabled: !(root.notifications?.doNotDisturb ?? false)
                onToggled: checked => root.setNotification("notificationsEnabled", checked)
            }

            SettingsToggleRow {
                width: parent.width
                text: I18n.tr("Show message preview")
                description: I18n.tr("Include the message text rather than only that something arrived")
                checked: root.notifications?.preview ?? true
                enabled: (root.notifications?.enabled ?? true) && !(root.notifications?.doNotDisturb ?? false)
                onToggled: checked => root.setNotification("notificationPreview", checked)
            }

            SettingsToggleRow {
                width: parent.width
                text: I18n.tr("Notify for group conversations")
                checked: root.notifications?.groups ?? true
                enabled: (root.notifications?.enabled ?? true) && !(root.notifications?.doNotDisturb ?? false)
                onToggled: checked => root.setNotification("notifyGroups", checked)
            }

            // Per tag, so a provider's own categories -- WhatsApp's statuses
            // and channels, a mail account's labels -- can each be silenced
            // without silencing the provider.
            Repeater {
                model: root.providerTags

                SettingsToggleRow {
                    required property var modelData

                    width: parent.width
                    text: I18n.tr("Notify for %1").arg(modelData)
                    checked: (root.notifications?.mutedTags ?? []).indexOf(modelData) === -1
                    enabled: (root.notifications?.enabled ?? true) && !(root.notifications?.doNotDisturb ?? false)
                    onToggled: checked => root.setTagNotify(modelData, checked)
                }
            }

            SettingsToggleRow {
                width: parent.width
                text: I18n.tr("Notify for archived conversations")
                description: I18n.tr("Archiving normally means keeping a conversation out of the way")
                checked: root.notifications?.archived ?? false
                enabled: (root.notifications?.enabled ?? true) && !(root.notifications?.doNotDisturb ?? false)
                onToggled: checked => root.setNotification("notifyArchived", checked)
            }
        }

        // -------------------------------------------------- plugin settings

        SettingsDivider {
            width: parent.width
            visible: root.enabled && root.hasSettings
        }

        StyledText {
            width: parent.width
            visible: root.enabled && root.hasSettings
            text: I18n.tr("%1 settings").arg(root.providerName)
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Medium
            color: Theme.surfaceText
        }

        // The provider's own settings component, written by whoever wrote the
        // bridge. An ordinary PluginSettings file, persisted like any other
        // plugin's and pushed down to the running bridge on change.
        Loader {
            id: settingsLoader
            width: parent.width
            active: root.enabled && root.hasSettings
            visible: active
            asynchronous: true

            source: {
                if (!active)
                    return "";
                var path = root.settingsPath;
                if (!path.startsWith("file://"))
                    path = "file://" + path;
                return path;
            }

            onLoaded: {
                if (item && typeof PluginService !== "undefined")
                    item.pluginService = PluginService;
            }
        }

        StyledText {
            width: parent.width
            text: I18n.tr("Could not load this provider's settings.")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.error
            visible: settingsLoader.status === Loader.Error
        }

        // ------------------------------------------------------- account

        SettingsDivider {
            width: parent.width
            visible: root.enabled && root.connected
        }

        Row {
            width: parent.width
            visible: root.enabled && root.connected
            spacing: Theme.spacingS

            DankButton {
                text: I18n.tr("Sign out")
                iconName: "logout"
                backgroundColor: "transparent"
                textColor: Theme.surfaceText
                onClicked: ChatService.logout(root.providerId)
            }

            DankButton {
                text: I18n.tr("Delete all messages")
                iconName: "delete_sweep"
                backgroundColor: "transparent"
                textColor: Theme.error
                onClicked: ChatService.purge(root.providerId)
            }
        }
    }

    // A settings change has to reach the running bridge, which receives its
    // configuration over the socket rather than reading any file itself.
    Connections {
        target: PluginService

        function onPluginDataChanged(pluginId) {
            if (pluginId === root.providerId)
                ChatService.pushProviderSettings(root.providerId);
        }
    }
}
