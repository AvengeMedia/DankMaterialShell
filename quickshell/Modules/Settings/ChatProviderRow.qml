import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

// One installed chat provider in Settings -> Chats.
//
// Collapsed it shows connection state and unread count; expanded it reveals the
// provider's own settings component, which is an ordinary plugin settings file
// written by whoever wrote the bridge. Nothing here knows what service the
// provider talks to.
StyledRect {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    required property var provider

    readonly property string providerId: provider?.id ?? ""
    readonly property string providerName: provider?.name || providerId
    readonly property string providerIcon: provider?.icon || "forum"
    readonly property bool enabled: provider?.enabled ?? false
    readonly property string state: provider?.state ?? "disconnected"
    readonly property int unread: provider?.unread ?? 0
    readonly property string lastError: provider?.lastError ?? ""
    readonly property string settingsPath: provider?.settingsQml ?? ""
    readonly property bool hasSettings: settingsPath !== ""

    property bool expanded: false

    readonly property bool needsLogin: state === "needsLogin"

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

    height: contentColumn.implicitHeight + Theme.spacingM * 2
    radius: Theme.cornerRadius
    color: headerArea.containsMouse ? Theme.surfacePressed : Theme.floatingWindowNestedSurface
    border.color: Theme.outlineMedium
    border.width: Theme.layerOutlineWidth

    MouseArea {
        id: headerArea
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: headerRow.implicitHeight + Theme.spacingM * 2
        hoverEnabled: true
        cursorShape: root.hasSettings ? Qt.PointingHandCursor : Qt.ArrowCursor
        enabled: root.hasSettings
        onClicked: root.expanded = !root.expanded
    }

    Column {
        id: contentColumn
        anchors.fill: parent
        anchors.margins: Theme.spacingM
        spacing: Theme.spacingM

        Row {
            id: headerRow
            width: parent.width
            spacing: Theme.spacingM

            DankIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: root.providerIcon
                size: Theme.iconSize
                color: root.enabled ? Theme.primary : Theme.surfaceVariantText
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - Theme.iconSize - toggleColumn.width - Theme.spacingM * 2
                spacing: 2

                Row {
                    width: parent.width
                    spacing: Theme.spacingS

                    StyledText {
                        text: root.providerName
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                    }

                    // Unread is the one number worth surfacing here; the rest
                    // of the detail lives in the chat window itself.
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

            Column {
                id: toggleColumn
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingXS

                DankToggle {
                    checked: root.enabled
                    // Enabling starts a bridge process; disabling stops it.
                    onToggled: checked => ChatService.setProviderEnabled(root.providerId, checked)
                }
            }
        }

        // Sign-in is only meaningful once the bridge is running, and only
        // offered when it has actually asked for it.
        Row {
            width: parent.width
            spacing: Theme.spacingS
            visible: root.enabled && (root.needsLogin || root.state === "connected")

            DankButton {
                text: root.needsLogin ? I18n.tr("Sign in") : I18n.tr("Sign out")
                iconName: root.needsLogin ? "login" : "logout"
                backgroundColor: root.needsLogin ? Theme.primary : "transparent"
                textColor: root.needsLogin ? Theme.onPrimary : Theme.surfaceText
                onClicked: {
                    if (root.needsLogin) {
                        ChatService.login(root.providerId);
                    } else {
                        ChatService.logout(root.providerId);
                    }
                }
            }
        }

        StyledText {
            width: parent.width
            text: I18n.tr("This provider has no settings.")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            visible: root.expanded && !root.hasSettings
        }

        // The provider's own settings component, written by the bridge author.
        // It is an ordinary PluginSettings file, so it persists into
        // plugin_settings.json exactly like any other plugin's settings.
        Loader {
            id: settingsLoader
            width: parent.width
            active: root.expanded && root.hasSettings
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
