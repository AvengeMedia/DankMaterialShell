import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets

Item {
    id: root

    property var config: ({})
    property bool configLoaded: false
    property bool configError: false
    property bool saving: false

    readonly property var maxHistoryOptions: [
        {
            text: "25",
            value: 25
        },
        {
            text: "50",
            value: 50
        },
        {
            text: "100",
            value: 100
        },
        {
            text: "200",
            value: 200
        },
        {
            text: "500",
            value: 500
        },
        {
            text: "1,000",
            value: 1000
        },
        {
            text: "10,000",
            value: 10000
        },
        {
            text: "15,000",
            value: 15000
        },
        {
            text: "20,000",
            value: 20000
        },
        {
            text: "30,000",
            value: 30000
        },
        {
            text: "50,000",
            value: 50000
        },
        {
            text: "100,000",
            value: 100000
        },
        {
            text: "∞",
            value: -1
        }
    ]

    readonly property var maxEntrySizeOptions: [
        {
            text: "1 MB",
            value: 1048576
        },
        {
            text: "2 MB",
            value: 2097152
        },
        {
            text: "5 MB",
            value: 5242880
        },
        {
            text: "10 MB",
            value: 10485760
        },
        {
            text: "20 MB",
            value: 20971520
        },
        {
            text: "50 MB",
            value: 52428800
        }
    ]

    readonly property var autoClearOptions: [
        {
            text: I18n.tr("Never"),
            value: 0
        },
        {
            text: I18n.tr("1 day"),
            value: 1
        },
        {
            text: I18n.tr("3 days"),
            value: 3
        },
        {
            text: I18n.tr("7 days"),
            value: 7
        },
        {
            text: I18n.tr("14 days"),
            value: 14
        },
        {
            text: I18n.tr("30 days"),
            value: 30
        },
        {
            text: I18n.tr("90 days"),
            value: 90
        }
    ]

    function getMaxHistoryText(value) {
        if (value <= 0)
            return "∞";
        for (let opt of maxHistoryOptions) {
            if (opt.value === value)
                return opt.text;
        }
        return value.toLocaleString();
    }

    function getMaxEntrySizeText(value) {
        for (let opt of maxEntrySizeOptions) {
            if (opt.value === value)
                return opt.text;
        }
        const mb = Math.round(value / 1048576);
        return mb + " MB";
    }

    function getAutoClearText(value) {
        for (let opt of autoClearOptions) {
            if (opt.value === value)
                return opt.text;
        }
        return value + " " + I18n.tr("days");
    }

    function loadConfig() {
        configLoaded = false;
        configError = false;
        DMSService.sendRequest("clipboard.getConfig", null, response => {
            if (response.error) {
                configError = true;
                return;
            }
            config = response.result || {};
            configLoaded = true;
        });
    }

    function saveConfig(key, value) {
        const params = {};
        params[key] = value;
        saving = true;
        DMSService.sendRequest("clipboard.setConfig", params, response => {
            saving = false;
            if (response.error) {
                ToastService.showError(I18n.tr("Failed to save clipboard setting"), response.error);
                return;
            }
            loadConfig();
        });
    }

    Component.onCompleted: {
        if (DMSService.isConnected)
            loadConfig();
    }

    Connections {
        target: DMSService
        function onIsConnectedChanged() {
            if (DMSService.isConnected)
                loadConfig();
        }
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

            Rectangle {
                width: parent.width
                height: warningContent.implicitHeight + Theme.spacingM * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.12)
                visible: !DMSService.isConnected || configError

                Row {
                    id: warningContent
                    anchors.fill: parent
                    anchors.margins: Theme.spacingM
                    spacing: Theme.spacingM

                    DankIcon {
                        name: "info"
                        size: Theme.iconSizeSmall
                        color: Theme.warning
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        font.pixelSize: Theme.fontSizeSmall
                        text: !DMSService.isConnected ? I18n.tr("DMS service is not connected. Clipboard settings are unavailable.") : I18n.tr("Failed to load clipboard configuration.")
                        wrapMode: Text.WordWrap
                        width: parent.width - Theme.iconSizeSmall - Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            SettingsCard {
                tab: "clipboard"
                tags: ["clipboard", "history", "limit"]
                title: I18n.tr("History Settings")
                iconName: "history"
                visible: configLoaded

                SettingsDropdownRow {
                    tab: "clipboard"
                    tags: ["clipboard", "history", "max", "limit"]
                    settingKey: "maxHistory"
                    text: I18n.tr("Maximum History")
                    description: I18n.tr("Maximum number of clipboard entries to keep")
                    currentValue: root.getMaxHistoryText(root.config.maxHistory ?? 100)
                    options: root.maxHistoryOptions.map(opt => opt.text)
                    onValueChanged: value => {
                        for (let opt of root.maxHistoryOptions) {
                            if (opt.text === value) {
                                root.saveConfig("maxHistory", opt.value);
                                return;
                            }
                        }
                    }
                }

                SettingsDropdownRow {
                    tab: "clipboard"
                    tags: ["clipboard", "entry", "size", "limit"]
                    settingKey: "maxEntrySize"
                    text: I18n.tr("Maximum Entry Size")
                    description: I18n.tr("Maximum size per clipboard entry")
                    currentValue: root.getMaxEntrySizeText(root.config.maxEntrySize ?? 5242880)
                    options: root.maxEntrySizeOptions.map(opt => opt.text)
                    onValueChanged: value => {
                        for (let opt of root.maxEntrySizeOptions) {
                            if (opt.text === value) {
                                root.saveConfig("maxEntrySize", opt.value);
                                return;
                            }
                        }
                    }
                }

                SettingsDropdownRow {
                    tab: "clipboard"
                    tags: ["clipboard", "auto", "clear", "days"]
                    settingKey: "autoClearDays"
                    text: I18n.tr("Auto-Clear After")
                    description: I18n.tr("Automatically delete entries older than this")
                    currentValue: root.getAutoClearText(root.config.autoClearDays ?? 0)
                    options: root.autoClearOptions.map(opt => opt.text)
                    onValueChanged: value => {
                        for (let opt of root.autoClearOptions) {
                            if (opt.text === value) {
                                root.saveConfig("autoClearDays", opt.value);
                                return;
                            }
                        }
                    }
                }
            }

            SettingsCard {
                tab: "clipboard"
                tags: ["clipboard", "behavior"]
                title: I18n.tr("Behavior")
                iconName: "settings"
                visible: configLoaded

                SettingsToggleRow {
                    tab: "clipboard"
                    tags: ["clipboard", "clear", "startup"]
                    settingKey: "clearAtStartup"
                    text: I18n.tr("Clear at Startup")
                    description: I18n.tr("Clear all history when server starts")
                    checked: root.config.clearAtStartup ?? false
                    onToggled: checked => root.saveConfig("clearAtStartup", checked)
                }
            }

            SettingsCard {
                tab: "clipboard"
                tags: ["clipboard", "advanced", "disable"]
                title: I18n.tr("Advanced")
                iconName: "tune"
                collapsible: true
                expanded: false
                visible: configLoaded

                SettingsToggleRow {
                    tab: "clipboard"
                    tags: ["clipboard", "disable", "history"]
                    settingKey: "disabled"
                    text: I18n.tr("Disable History Persistence")
                    description: I18n.tr("Clipboard works but nothing saved to disk")
                    checked: root.config.disabled ?? false
                    onToggled: checked => root.saveConfig("disabled", checked)
                }
            }
        }
    }
}
