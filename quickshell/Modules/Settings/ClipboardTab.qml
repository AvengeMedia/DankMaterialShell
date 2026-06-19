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

    readonly property var maxPinnedOptions: [
        {
            text: "5",
            value: 5
        },
        {
            text: "10",
            value: 10
        },
        {
            text: "15",
            value: 15
        },
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
        }
    ]

    readonly property var entryActionKeys: ["pin", "edit", "delete"]
    readonly property var entryActionLabels: [I18n.tr("Pin"), I18n.tr("Edit"), I18n.tr("Delete")]

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

    function getMaxPinnedText(value) {
        for (let opt of maxPinnedOptions) {
            if (opt.value === value)
                return opt.text;
        }
        return value.toString();
    }

    function visibleEntryActionKeys() {
        return SettingsData.clipboardVisibleEntryActions || ["pin", "edit", "delete"];
    }

    function visibleEntryActionLabels() {
        const visibleKeys = visibleEntryActionKeys();
        return entryActionKeys.map((key, index) => visibleKeys.includes(key) ? entryActionLabels[index] : null).filter(label => label !== null);
    }

    function setVisibleEntryAction(index, selected) {
        const actionKey = entryActionKeys[index];
        if (!actionKey)
            return;

        let actions = visibleEntryActionKeys().slice();
        if (selected && !actions.includes(actionKey)) {
            actions.push(actionKey);
        } else if (!selected && actions.includes(actionKey)) {
            actions = actions.filter(action => action !== actionKey);
        }
        SettingsData.set("clipboardVisibleEntryActions", actions);
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
            const updated = JSON.parse(JSON.stringify(config));
            updated[key] = value;
            config = updated;
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
                    id: maxHistoryDropdown
                    tab: "clipboard"
                    tags: ["clipboard", "history", "max", "limit"]
                    settingKey: "maxHistory"
                    text: I18n.tr("Maximum History")
                    description: I18n.tr("Maximum number of clipboard entries to keep")
                    options: root.maxHistoryOptions.map(opt => opt.text)

                    Component.onCompleted: {
                        currentValue = root.getMaxHistoryText(root.config.maxHistory ?? 100);
                    }

                    onValueChanged: value => {
                        for (let opt of root.maxHistoryOptions) {
                            if (opt.text === value) {
                                root.saveConfig("maxHistory", opt.value);
                                return;
                            }
                        }
                    }

                    Connections {
                        target: root
                        function onConfigChanged() {
                            maxHistoryDropdown.currentValue = root.getMaxHistoryText(root.config.maxHistory ?? 100);
                        }
                    }
                }

                SettingsDropdownRow {
                    id: maxEntrySizeDropdown
                    tab: "clipboard"
                    tags: ["clipboard", "entry", "size", "limit"]
                    settingKey: "maxEntrySize"
                    text: I18n.tr("Maximum Entry Size")
                    description: I18n.tr("Maximum size per clipboard entry")
                    options: root.maxEntrySizeOptions.map(opt => opt.text)

                    Component.onCompleted: {
                        currentValue = root.getMaxEntrySizeText(root.config.maxEntrySize ?? 5242880);
                    }

                    onValueChanged: value => {
                        for (let opt of root.maxEntrySizeOptions) {
                            if (opt.text === value) {
                                root.saveConfig("maxEntrySize", opt.value);
                                return;
                            }
                        }
                    }

                    Connections {
                        target: root
                        function onConfigChanged() {
                            maxEntrySizeDropdown.currentValue = root.getMaxEntrySizeText(root.config.maxEntrySize ?? 5242880);
                        }
                    }
                }

                SettingsDropdownRow {
                    id: autoClearDaysDropdown
                    tab: "clipboard"
                    tags: ["clipboard", "auto", "clear", "days"]
                    settingKey: "autoClearDays"
                    text: I18n.tr("Auto-Clear After")
                    description: I18n.tr("Automatically delete entries older than this")
                    options: root.autoClearOptions.map(opt => opt.text)

                    Component.onCompleted: {
                        currentValue = root.getAutoClearText(root.config.autoClearDays ?? 0);
                    }

                    onValueChanged: value => {
                        for (let opt of root.autoClearOptions) {
                            if (opt.text === value) {
                                root.saveConfig("autoClearDays", opt.value);
                                return;
                            }
                        }
                    }

                    Connections {
                        target: root
                        function onConfigChanged() {
                            autoClearDaysDropdown.currentValue = root.getAutoClearText(root.config.autoClearDays ?? 0);
                        }
                    }
                }

                SettingsDropdownRow {
                    id: maxPinnedDropdown
                    tab: "clipboard"
                    tags: ["clipboard", "pinned", "max", "limit"]
                    settingKey: "maxPinned"
                    text: I18n.tr("Maximum Pinned Entries")
                    description: I18n.tr("Maximum number of entries that can be saved")
                    options: root.maxPinnedOptions.map(opt => opt.text)

                    function updateValue() {
                        if (root.configLoaded) {
                            currentValue = root.getMaxPinnedText(root.config.maxPinned ?? 25);
                        }
                    }

                    Component.onCompleted: {
                        updateValue();
                    }

                    onValueChanged: value => {
                        for (let opt of root.maxPinnedOptions) {
                            if (opt.text === value) {
                                root.saveConfig("maxPinned", opt.value);
                                return;
                            }
                        }
                    }

                    Connections {
                        target: root
                        function onConfigLoadedChanged() {
                            if (root.configLoaded) {
                                maxPinnedDropdown.updateValue();
                            }
                        }
                        function onConfigChanged() {
                            maxPinnedDropdown.updateValue();
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

                SettingsToggleRow {
                    tab: "clipboard"
                    tags: ["clipboard", "click", "paste", "behavior"]
                    settingKey: "clipboardClickToPaste"
                    text: I18n.tr("Click to Paste")
                    description: I18n.tr("Click an entry to paste directly instead of copying", "Clipboard behavior setting description")
                    checked: SettingsData.clipboardClickToPaste
                    onToggled: checked => SettingsData.set("clipboardClickToPaste", checked)
                }

                SettingsToggleRow {
                    tab: "clipboard"
                    tags: ["clipboard", "enter", "paste", "behavior"]
                    settingKey: "clipboardEnterToPaste"
                    text: I18n.tr("Enter to Paste")
                    description: I18n.tr("Press Enter to paste, Shift+Enter to copy", "Clipboard behavior setting description")
                    checked: SettingsData.clipboardEnterToPaste
                    onToggled: checked => SettingsData.set("clipboardEnterToPaste", checked)
                }

                SettingsToggleRow {
                    tab: "clipboard"
                    tags: ["clipboard", "filter", "type", "remember", "behavior"]
                    settingKey: "clipboardRememberTypeFilter"
                    text: I18n.tr("Remember Type Filter", "Clipboard behavior setting title")
                    description: I18n.tr("Keep the clipboard type filter when reopening history", "Clipboard behavior setting description")
                    checked: SettingsData.clipboardRememberTypeFilter
                    onToggled: checked => SettingsData.set("clipboardRememberTypeFilter", checked)
                }

                SettingsButtonGroupRow {
                    tab: "clipboard"
                    tags: ["clipboard", "actions", "buttons", "hide", "density", "pin", "edit", "delete"]
                    settingKey: "clipboardVisibleEntryActions"
                    text: I18n.tr("Visible Entry Actions")
                    description: I18n.tr("Choose which action buttons appear on clipboard entries")
                    selectionMode: "multi"
                    model: root.entryActionLabels
                    currentSelection: root.visibleEntryActionLabels()
                    checkEnabled: false
                    buttonHeight: 28
                    minButtonWidth: 56
                    buttonPadding: Theme.spacingS
                    textSize: Theme.fontSizeSmall
                    spacing: 1
                    onSelectionChanged: (index, selected) => root.setVisibleEntryAction(index, selected)
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
