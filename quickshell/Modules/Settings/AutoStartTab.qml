import QtCore
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets

Item {
    id: root

    readonly property var log: Log.scoped("AutoStartTab")
    property var parentModal: null
    property var entries: []
    property var desktopApps: []
    property bool loading: false
    property bool refreshPending: false
    property bool showAddForm: false
    property string lastError: ""
    property string newEntryType: "desktop"
    property string newEntryName: ""
    property string newEntryExec: ""
    property string newEntryDesktopId: ""
    property string newEntryCommandWrapper: "%command%"

    function refresh() {
        if (loadProcess.running) {
            refreshPending = true;
            return;
        }
        loading = true;
        lastError = "";
        loadProcess.outputText = "";
        loadProcess.errorText = "";
        loadProcess.running = true;
    }

    function updateEntryEnabled(id, enabled) {
        const list = entries.slice();
        const index = list.findIndex(entry => entry.id === id);
        if (index < 0)
            return;
        list[index] = Object.assign({}, list[index], {
            enabled: enabled
        });
        entries = list;
    }

    function setEnabled(entry, enabled) {
        if (!entry || !entry.mutable || operationProcess.running)
            return;
        updateEntryEnabled(entry.id, enabled);
        operationProcess.operation = enabled ? "enable" : "disable";
        operationProcess.entryId = entry.id;
        operationProcess.errorText = "";
        operationProcess.command = ["dms", "startup", operationProcess.operation, entry.id];
        operationProcess.running = true;
    }

    function removeEntry(entry) {
        if (!entry || !entry.removable || operationProcess.running)
            return;
        operationProcess.operation = "remove";
        operationProcess.entryId = entry.id;
        operationProcess.errorText = "";
        operationProcess.command = ["dms", "startup", "remove", entry.id];
        operationProcess.running = true;
    }

    function selectedDesktopApp() {
        return desktopApps.find(app => (app.id || app.execString) === newEntryDesktopId);
    }

    function entryDescription(entry) {
        if (entry.description)
            return entry.description;
        const source = entry.source === "systemd" ? I18n.tr("systemd user service") : I18n.tr("XDG Autostart");
        return I18n.tr("Startup source: %1").arg(source);
    }

    function addEntry() {
        if (operationProcess.running)
            return;

        let name = newEntryName.trim();
        let execLine = newEntryExec.trim();
        let icon = "";
        if (newEntryType === "desktop") {
            const app = selectedDesktopApp();
            if (!app)
                return;
            name = app.name || newEntryDesktopId;
            execLine = newEntryCommandWrapper.replace("%command%", app.exec || app.execString || "");
            icon = app.icon || "";
        }
        if (!name || !execLine)
            return;

        const command = ["dms", "startup", "add", "--name", name, "--exec", execLine];
        if (icon)
            command.push("--icon", icon);
        operationProcess.operation = "add";
        operationProcess.entryId = "";
        operationProcess.errorText = "";
        operationProcess.command = command;
        operationProcess.running = true;
    }

    function resetNewEntry() {
        newEntryType = "desktop";
        newEntryName = "";
        newEntryExec = "";
        newEntryDesktopId = "";
        newEntryCommandWrapper = "%command%";
    }

    Process {
        id: loadProcess
        command: ["dms", "startup", "list", "--json"]
        running: false
        property string outputText: ""
        property string errorText: ""

        stdout: StdioCollector {
            onStreamFinished: loadProcess.outputText = text
        }

        stderr: StdioCollector {
            onStreamFinished: loadProcess.errorText = text.trim()
        }

        onExited: exitCode => {
            root.loading = false;
            if (exitCode === 0) {
                try {
                    const parsed = JSON.parse(outputText || "[]");
                    root.entries = parsed.filter(entry => entry.category === "application" && entry.mutable === true);
                    root.lastError = "";
                } catch (error) {
                    root.lastError = I18n.tr("Failed to read startup applications");
                    root.log.warn("Failed to parse startup application list: " + error);
                }
            } else {
                root.lastError = errorText || I18n.tr("Failed to read startup applications");
                root.log.warn("Failed to load startup applications: " + root.lastError);
            }
            if (root.refreshPending) {
                root.refreshPending = false;
                Qt.callLater(root.refresh);
            }
        }
    }

    Process {
        id: operationProcess
        running: false
        property string operation: ""
        property string entryId: ""
        property string errorText: ""

        stderr: StdioCollector {
            onStreamFinished: operationProcess.errorText = text.trim()
        }

        onExited: exitCode => {
            if (exitCode !== 0) {
                const title = operation === "add" ? I18n.tr("Failed to add startup application") : (operation === "remove" ? I18n.tr("Failed to remove startup application") : I18n.tr("Failed to update startup application"));
                ToastService.showError(title, "", errorText.split("\n")[0]);
                root.log.warn(title + ": " + errorText);
            } else if (operation === "add") {
                root.resetNewEntry();
                root.showAddForm = false;
            }
            root.refresh();
        }
    }

    Timer {
        interval: 30000
        repeat: true
        running: root.visible
        onTriggered: root.refresh()
    }

    function generateTrayIconFixSystemdOverride() {
        const configHome = Paths.strip(StandardPaths.writableLocation(StandardPaths.ConfigLocation));
        const dir = configHome + "/systemd/user/app-@autostart.service.d";
        systemdOverrideMkDirComp.createObject(root, {
            targetPath: dir,
            running: true
        });
    }

    FileView {
        id: systemdOverrideWriter
        atomicWrites: true

        function buildOverrideContent(existing) {
            if (!existing)
                return "[Unit]\nAfter=dms.service\n";
            const lines = existing.split("\n");
            if (lines.some(line => line.trim() === "After=dms.service"))
                return existing;
            const unitIndex = lines.findIndex(line => line.trim() === "[Unit]");
            if (unitIndex >= 0)
                lines.splice(unitIndex + 1, 0, "After=dms.service");
            else
                lines.push("[Unit]", "After=dms.service");
            return lines.join("\n");
        }

        onLoaded: {
            const merged = buildOverrideContent(text());
            if (merged !== text())
                setText(merged);
            ToastService.showInfo(I18n.tr("Systemd Override generated"));
        }

        onLoadFailed: {
            setText("[Unit]\nAfter=dms.service\n");
            ToastService.showInfo(I18n.tr("Systemd Override generated"));
        }

        onSaveFailed: error => {
            ToastService.showError(I18n.tr("Failed to generate systemd override"));
            root.log.warn("Failed to write systemd override to " + path + ": " + error);
        }
    }

    Component {
        id: systemdOverrideMkDirComp

        Process {
            property string targetPath: ""
            command: ["mkdir", "-p", targetPath]
            onExited: exitCode => {
                if (exitCode === 0)
                    systemdOverrideWriter.path = targetPath + "/override.conf";
                else
                    ToastService.showError(I18n.tr("Failed to generate systemd override"));
                destroy();
            }
        }
    }

    Component.onCompleted: {
        desktopApps = AppSearchService.getVisibleApplications() || [];
        refresh();
    }

    Component.onDestruction: desktopApps = []

    DankFlickable {
        anchors.fill: parent
        clip: true
        contentHeight: mainColumn.height + Theme.spacingXL
        contentWidth: width

        AppBrowserPopup {
            id: appBrowserPopup
            appsModel: root.desktopApps
            parentModal: root.parentModal
            onAppSelected: appId => root.newEntryDesktopId = appId
        }

        Column {
            id: mainColumn
            topPadding: 4
            width: Math.min(550, parent.width - Theme.spacingL * 2)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.spacingXL

            SettingsCard {
                width: parent.width
                iconName: "rocket_launch"
                title: I18n.tr("Startup Apps")
                settingKey: "autostartEntries"
                tags: ["startup", "autostart", "applications", "login"]

                headerActions: [
                    DankRefreshButton {
                        busy: root.loading
                        tooltipText: I18n.tr("Refresh")
                        onClicked: root.refresh()
                    },
                    DankActionButton {
                        iconName: root.showAddForm ? "close" : "add"
                        iconColor: Theme.primary
                        tooltipText: root.showAddForm ? I18n.tr("Close") : I18n.tr("Add Startup App")
                        onClicked: root.showAddForm = !root.showAddForm
                    }
                ]

                StyledText {
                    width: parent.width
                    text: I18n.tr("Applications that automatically start when you sign in.")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    wrapMode: Text.WordWrap
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingS
                    visible: root.entries.length > 0

                    Repeater {
                        model: root.entries

                        delegate: Rectangle {
                            id: entryRow
                            required property var modelData
                            width: parent.width
                            height: 64
                            radius: Theme.cornerRadius
                            color: Theme.floatingWindowFieldColor
                            opacity: operationProcess.running && operationProcess.entryId === modelData.id ? 0.6 : 1

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.shortDuration
                                    easing.type: Theme.standardEasing
                                }
                            }

                            Image {
                                id: entryIcon
                                width: 32
                                height: 32
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.spacingM
                                anchors.verticalCenter: parent.verticalCenter
                                source: Paths.resolveIconUrl(entryRow.modelData.icon || "application-x-executable")
                                sourceSize.width: 32
                                sourceSize.height: 32
                                fillMode: Image.PreserveAspectFit
                                onStatusChanged: {
                                    if (status === Image.Error)
                                        source = "image://icon/application-x-executable";
                                }
                            }

                            Column {
                                anchors.left: entryIcon.right
                                anchors.leftMargin: Theme.spacingM
                                anchors.right: entryToggle.left
                                anchors.rightMargin: Theme.spacingM
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.spacingXXS

                                StyledText {
                                    width: parent.width
                                    text: entryRow.modelData.name
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: Font.Medium
                                    color: entryRow.modelData.enabled ? Theme.surfaceText : Theme.surfaceVariantText
                                    maximumLineCount: 1
                                    elide: Text.ElideRight
                                    horizontalAlignment: Text.AlignLeft
                                }

                                StyledText {
                                    width: parent.width
                                    text: root.entryDescription(entryRow.modelData)
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    maximumLineCount: 1
                                    elide: Text.ElideRight
                                    horizontalAlignment: Text.AlignLeft
                                }
                            }

                            DankToggle {
                                id: entryToggle
                                anchors.right: entryRemoveButton.visible ? entryRemoveButton.left : parent.right
                                anchors.rightMargin: Theme.spacingM
                                anchors.verticalCenter: parent.verticalCenter
                                checked: entryRow.modelData.enabled
                                enabled: entryRow.modelData.mutable && !operationProcess.running
                                toggling: operationProcess.running && operationProcess.entryId === entryRow.modelData.id
                                onToggled: checked => root.setEnabled(entryRow.modelData, checked)
                            }

                            DankActionButton {
                                id: entryRemoveButton
                                anchors.right: parent.right
                                anchors.rightMargin: Theme.spacingS
                                anchors.verticalCenter: parent.verticalCenter
                                iconName: "delete"
                                iconSize: 18
                                buttonSize: 32
                                iconColor: Theme.error
                                tooltipText: I18n.tr("Remove")
                                visible: entryRow.modelData.removable === true
                                enabled: !operationProcess.running
                                onClicked: root.removeEntry(entryRow.modelData)
                            }
                        }
                    }
                }

                DankSpinner {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.loading && root.entries.length === 0
                    running: visible
                }

                StyledText {
                    width: parent.width
                    text: root.lastError
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.error
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    visible: root.lastError.length > 0
                }

                StyledText {
                    width: parent.width
                    text: I18n.tr("No startup applications found")
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceVariantText
                    horizontalAlignment: Text.AlignHCenter
                    visible: !root.loading && root.lastError.length === 0 && root.entries.length === 0
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "add_circle"
                title: I18n.tr("Add Startup App")
                settingKey: "autostartAddEntry"
                tags: ["startup", "autostart", "add", "application", "command"]
                visible: root.showAddForm

                SettingsDropdownRow {
                    width: parent.width
                    text: I18n.tr("Entry Type")
                    description: I18n.tr("Choose whether to launch a desktop app or a command")
                    currentValue: root.newEntryType === "desktop" ? I18n.tr("Desktop Application") : I18n.tr("Command Line")
                    options: [I18n.tr("Desktop Application"), I18n.tr("Command Line")]
                    onValueChanged: value => root.newEntryType = value === I18n.tr("Desktop Application") ? "desktop" : "command"
                }

                Column {
                    width: parent.width
                    visible: root.newEntryType === "desktop"
                    spacing: Theme.spacingM

                    StyledText {
                        width: parent.width
                        text: I18n.tr("Select an application")
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        StyledRect {
                            width: parent.width - browseButton.width - Theme.spacingM
                            height: 40
                            radius: Theme.cornerRadius
                            color: Theme.floatingWindowFieldColor

                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.spacingM
                                anchors.right: parent.right
                                anchors.rightMargin: Theme.spacingM
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.spacingM

                                Image {
                                    width: 24
                                    height: 24
                                    source: Paths.resolveIconUrl(root.selectedDesktopApp()?.icon || "application-x-executable")
                                    sourceSize.width: 24
                                    sourceSize.height: 24
                                    fillMode: Image.PreserveAspectFit
                                    visible: root.newEntryDesktopId !== ""
                                }

                                StyledText {
                                    width: parent.width - (root.newEntryDesktopId !== "" ? 24 + Theme.spacingM : 0)
                                    text: root.selectedDesktopApp()?.name || I18n.tr("No application selected")
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: root.newEntryDesktopId ? Theme.surfaceText : Theme.surfaceVariantText
                                    maximumLineCount: 1
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        DankButton {
                            id: browseButton
                            text: I18n.tr("Browse")
                            iconName: "search"
                            onClicked: appBrowserPopup.show()
                        }
                    }

                    StyledText {
                        width: parent.width
                        text: I18n.tr("Command")
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                    }

                    DankTextField {
                        width: parent.width
                        placeholderText: I18n.tr("%command%")
                        text: root.newEntryCommandWrapper
                        onTextChanged: root.newEntryCommandWrapper = text
                    }
                }

                Column {
                    width: parent.width
                    visible: root.newEntryType === "command"
                    spacing: Theme.spacingM

                    StyledText {
                        text: I18n.tr("Name")
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                    }

                    DankTextField {
                        width: parent.width
                        placeholderText: I18n.tr("e.g. My Script")
                        text: root.newEntryName
                        onTextChanged: root.newEntryName = text
                    }

                    StyledText {
                        text: I18n.tr("Command")
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                    }

                    DankTextField {
                        width: parent.width
                        placeholderText: I18n.tr("e.g. /usr/bin/my-script --flag")
                        text: root.newEntryExec
                        onTextChanged: root.newEntryExec = text
                    }
                }

                StyledText {
                    width: parent.width
                    text: I18n.tr("This creates an XDG startup entry for your user.")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }

                DankButton {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: I18n.tr("Add Startup App")
                    iconName: "add"
                    enabled: !operationProcess.running && (root.newEntryType === "desktop" ? root.newEntryDesktopId !== "" : root.newEntryName.trim() !== "" && root.newEntryExec.trim() !== "")
                    onClicked: root.addEntry()
                }
            }

            SettingsCard {
                settingKey: "autostartTrayIconFix"
                tags: ["tray", "icons", "fix", "systemd"]
                width: parent.width
                iconName: "handyman"
                title: I18n.tr("Tray Icon Fix")
                visible: DesktopService.isSystemd

                StyledText {
                    width: parent.width
                    text: I18n.tr("If autostart app icons don't appear in the system tray, generate a systemd override to ensure DMS starts before autostart apps")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    wrapMode: Text.WordWrap
                }

                DankButton {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: I18n.tr("Generate Override")
                    iconName: "build"
                    onClicked: root.generateTrayIconFixSystemdOverride()
                }
            }
        }
    }
}
