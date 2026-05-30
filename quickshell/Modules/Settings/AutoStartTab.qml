import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets

Item {
    id: root

    property var parentModal: null
    property var entries: []
    property var desktopApps: []
    property string newEntryType: "desktop"
    property string newEntryName: ""
    property string newEntryExec: ""
    property string newEntryDesktopId: ""
    property string newEntryCommandWrapper: "%command%"

    readonly property string autostartDir: {
        const configHome = Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config";
        return configHome + "/autostart";
    }

    readonly property string systemdUserDir: {
        const configHome = Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config";
        return configHome + "/systemd/user";
    }

    function loadEntries() {
        const proc = readDirComponent.createObject(root, {
            running: true
        });
    }

    function lookupDesktopIcon(name, exec, fileName) {
        const appId = fileName ? fileName.replace(/\.desktop$/, "") : "";
        let entry = appId ? DesktopEntries.heuristicLookup(appId) : null;
        if (entry && entry.icon) return entry.icon;
        if (exec) {
            const cmdBase = exec.split(" ")[0].split("/").pop();
            for (let i = 0; i < root.desktopApps.length; i++) {
                const app = root.desktopApps[i];
                if (app.icon) {
                    const appExec = (app.exec || app.execString || "").split(" ")[0].split("/").pop();
                    if (appExec === cmdBase) return app.icon;
                }
            }
        }
        return "";
    }

    function parseDesktopFile(content, filePath) {
        if (!content || content.length === 0) return null;
        const lines = content.split("\n");
        let name = "";
        let execCmd = "";
        let icon = "";
        let isDesktopEntry = false;
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim();
            if (line === "[Desktop Entry]") {
                isDesktopEntry = true;
            } else if (isDesktopEntry) {
                const nameMatch = line.match(/^Name=(.+)$/);
                if (nameMatch) name = nameMatch[1];
                const execMatch = line.match(/^Exec=(.+)$/);
                if (execMatch) execCmd = execMatch[1];
                const iconMatch = line.match(/^Icon=(.+)$/);
                if (iconMatch) icon = iconMatch[1];
            }
        }
        if (!isDesktopEntry || !name || !execCmd) return null;
        const fileName = filePath.split("/").pop();
        if (!icon) icon = root.lookupDesktopIcon(name, execCmd, fileName);
        return { name: name, exec: execCmd, icon: icon, filePath: filePath, fileName: fileName };
    }

    function addEntry() {
        if (newEntryType === "desktop") {
            if (!newEntryDesktopId) return;
            const app = desktopApps.find(a => (a.id || a.execString) === newEntryDesktopId);
            if (!app) return;
            const entryName = app.name || newEntryDesktopId;
            const appExec = app.exec || app.execString || "";
            const execCmd = root.newEntryCommandWrapper.replace("%command%", appExec);
            const appIcon = app.icon || "";
            const fileName = entryName.toLowerCase().replace(/[^a-z0-9]/g, "-") + ".desktop";
            writeDesktopFile(fileName, entryName, execCmd, appIcon);
        } else {
            if (!newEntryName || !newEntryExec) return;
            const fileName = newEntryName.toLowerCase().replace(/[^a-z0-9]/g, "-") + ".desktop";
            writeDesktopFile(fileName, newEntryName, newEntryExec, "");
        }
    }

    function writeDesktopFile(fileName, name, execCmd, icon) {
        let content = "[Desktop Entry]\nType=Application\nName=" + name + "\nExec=" + execCmd + "\n";
        if (icon) content += "Icon=" + icon + "\n";
        const proc = writeFileComponent.createObject(root, {
            fileName: fileName,
            fileContent: content,
            running: true
        });
    }

    function removeEntry(filePath) {
        const proc = removeFileComponent.createObject(root, {
            targetPath: filePath,
            running: true
        });
    }

    function resetNewEntry() {
        newEntryType = "desktop";
        newEntryName = "";
        newEntryExec = "";
        newEntryDesktopId = "";
        newEntryCommandWrapper = "%command%";
    }

    function generateTrayOverride() {
        const proc = writeOverrideComponent.createObject(root, { running: true });
    }

    Component {
        id: readDirComponent
        Process {
            command: ["sh", "-c", "ls -1 \"" + root.autostartDir + "\"/*.desktop 2>/dev/null || true"]
            stdout: StdioCollector {
                onStreamFinished: {
                    const fileNames = text.trim();
                    if (!fileNames) {
                        root.entries = [];
                        destroy();
                        return;
                    }
                    const files = fileNames.split("\n").filter(f => f.trim().length > 0);
                    root.entries = [];
                    for (let i = 0; i < files.length; i++) {
                        const filePath = files[i].trim();
                        const readProc = readFileComponent.createObject(root, {
                            filePath: filePath,
                            running: true
                        });
                    }
                    destroy();
                }
            }
            onExited: (exitCode, exitStatus) => {
                destroy();
            }
        }
    }

    Component {
        id: readFileComponent
        Process {
            property string filePath: ""
            command: ["sh", "-c", "cat \"" + filePath + "\""]
            stdout: StdioCollector {
                onStreamFinished: {
                    const entry = root.parseDesktopFile(text, filePath);
                    if (entry) {
                        const entries = root.entries.slice();
                        entries.push(entry);
                        root.entries = entries;
                    }
                }
            }
            onExited: (exitCode, exitStatus) => {
                destroy();
            }
        }
    }

    Component {
        id: writeFileComponent
        Process {
            property string fileName: ""
            property string fileContent: ""
            command: ["sh", "-c", "mkdir -p \"" + root.autostartDir + "\" && cat > \"" + root.autostartDir + "/" + fileName + "\" << 'DMS_EOF'\n" + fileContent + "\nDMS_EOF"]
            onExited: (exitCode, exitStatus) => {
                if (exitCode === 0) {
                    root.resetNewEntry();
                    root.loadEntries();
                }
                destroy();
            }
        }
    }

    Component {
        id: removeFileComponent
        Process {
            property string targetPath: ""
            command: ["rm", "-f", targetPath]
            onExited: (exitCode, exitStatus) => {
                if (exitCode === 0) root.loadEntries();
                destroy();
            }
        }
    }

    Component {
        id: writeOverrideComponent
        Process {
            command: ["sh", "-c", "mkdir -p \"" + root.systemdUserDir + "/app-@autostart.service.d\" && cat > \"" + root.systemdUserDir + "/app-@autostart.service.d/override.conf\" << 'DMS_EOF'\n[Unit]\nAfter=dms.service\nDMS_EOF"]
            onExited: (exitCode, exitStatus) => {
                if (exitCode === 0) {
                    ToastService.showInfo(I18n.tr("Override generated"));
                } else {
                    ToastService.showError(I18n.tr("Failed to generate override"));
                }
                destroy();
            }
        }
    }

    Component.onCompleted: {
        desktopApps = AppSearchService.getVisibleApplications() || [];
        loadEntries();
    }

    Component.onDestruction: {
        desktopApps = [];
    }

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
                iconName: "add_circle"
                title: I18n.tr("Add Entry")

                SettingsDropdownRow {
                    width: parent.width
                    text: I18n.tr("Entry Type")
                    description: I18n.tr("Choose whether to launch a desktop app or a command")
                    currentValue: root.newEntryType === "desktop" ? I18n.tr("Desktop Application") : I18n.tr("Command Line")
                    options: [I18n.tr("Desktop Application"), I18n.tr("Command Line")]
                    onValueChanged: val => {
                        root.newEntryType = val === I18n.tr("Desktop Application") ? "desktop" : "command";
                    }
                }

                Column {
                    width: parent.width
                    visible: root.newEntryType === "desktop"
                    spacing: Theme.spacingM

                    Item {
                        width: parent.width
                        height: appLabelColumn.height

                        Column {
                            id: appLabelColumn
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingXS

                            StyledText {
                                text: I18n.tr("Application")
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: I18n.tr("Select a desktop application")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        StyledRect {
                            height: 40
                            radius: Theme.cornerRadius
                            color: root.newEntryDesktopId ? Theme.surfaceContainerHigh : Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
                            LayoutMirroring.enabled: I18n.isRtl
                            LayoutMirroring.childrenInherit: true

                            readonly property string selectedName: {
                                if (!root.newEntryDesktopId) return "";
                                const app = root.desktopApps.find(a => (a.id || a.execString) === root.newEntryDesktopId);
                                return app ? (app.name || app.id || "") : root.newEntryDesktopId;
                            }

                            width: parent.width - browseButton.width - Theme.spacingM

                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.spacingM
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.spacingM
                                visible: root.newEntryDesktopId !== ""

                                Image {
                                    width: 24
                                    height: 24
                                    source: {
                                        const app = root.desktopApps.find(a => (a.id || a.execString) === root.newEntryDesktopId);
                                        return Paths.resolveIconUrl(app?.icon || "application-x-executable");
                                    }
                                    sourceSize.width: 24
                                    sourceSize.height: 24
                                    fillMode: Image.PreserveAspectFit
                                    anchors.verticalCenter: parent.verticalCenter
                                    onStatusChanged: {
                                        if (status === Image.Error)
                                            source = "image://icon/application-x-executable";
                                    }
                                }

                                StyledText {
                                    text: parent.parent.selectedName
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            StyledText {
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.spacingM
                                anchors.verticalCenter: parent.verticalCenter
                                text: I18n.tr("No application selected")
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceVariantText
                                visible: root.newEntryDesktopId === ""
                            }
                        }

                        DankButton {
                            id: browseButton
                            text: I18n.tr("Browse")
                            iconName: "search"
                            onClicked: appBrowserPopup.show()
                        }
                    }

                    Item {
                        width: parent.width
                        height: wrapperLabelColumn.height

                        Column {
                            id: wrapperLabelColumn
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingXS

                            StyledText {
                                text: I18n.tr("Command")
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: I18n.tr("Wrap the app command. %command% is replaced with the actual executable")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                            }
                        }
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

                    Item {
                        width: parent.width
                        height: labelColumn.height

                        Column {
                            id: labelColumn
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingXS

                            StyledText {
                                text: I18n.tr("Name")
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: I18n.tr("Display name for this entry")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                            }
                        }
                    }

                    DankTextField {
                        width: parent.width
                        placeholderText: I18n.tr("e.g. My Script")
                        text: root.newEntryName
                        onTextChanged: root.newEntryName = text
                    }

                    Item {
                        width: parent.width
                        height: labelColumn2.height

                        Column {
                            id: labelColumn2
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingXS

                            StyledText {
                                text: I18n.tr("Command")
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: I18n.tr("Full command to execute")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                            }
                        }
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
                    text: I18n.tr("These add entries to the XDG autostart directory (~/.config/autostart/*.desktop)")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }

                Item {
                    width: parent.width
                    height: Theme.spacingM
                }

                DankButton {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: I18n.tr("Add to Autostart")
                    iconName: "add"
                    enabled: {
                        if (root.newEntryType === "desktop") return root.newEntryDesktopId !== "";
                        return root.newEntryName !== "" && root.newEntryExec !== "";
                    }
                    onClicked: root.addEntry()
                }
            }

            SettingsCard {
                id: entriesCard
                width: parent.width
                iconName: "line_start"
                title: I18n.tr("Autostart Entries")
                settingKey: "autostartEntries"
                collapsible: true
                expanded: true

                Row {
                    width: parent.width
                    spacing: Theme.spacingM

                    StyledText {
                        width: parent.width - clearAllButton.width - Theme.spacingM
                        text: I18n.tr("Applications and commands to start automatically when you log in")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        wrapMode: Text.WordWrap
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    DankActionButton {
                        id: clearAllButton
                        iconName: "delete_sweep"
                        iconSize: Theme.iconSize - 2
                        iconColor: Theme.error
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: {
                            for (let i = 0; i < root.entries.length; i++) {
                                root.removeEntry(root.entries[i].filePath);
                            }
                        }
                    }
                }

                Column {
                    id: entriesList
                    width: parent.width
                    spacing: Theme.spacingS

                    Repeater {
                        model: root.entries

                        delegate: Rectangle {
                            width: entriesList.width
                            height: 48
                            radius: Theme.cornerRadius
                            color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.3)
                            border.width: 0

                            Row {
                                width: parent.width
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.spacingM
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.spacingM

                                StyledText {
                                    text: (index + 1).toString()
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.Medium
                                    color: Theme.primary
                                    width: 20
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Image {
                                    width: 24
                                    height: 24
                                    source: Paths.resolveIconUrl(modelData.icon || "application-x-executable")
                                    sourceSize.width: 24
                                    sourceSize.height: 24
                                    fillMode: Image.PreserveAspectFit
                                    anchors.verticalCenter: parent.verticalCenter
                                    onStatusChanged: {
                                        if (status === Image.Error)
                                            source = "image://icon/application-x-executable";
                                    }
                                }

                                Column {
                                    width: parent.width - 20 - Theme.spacingM - 24 - Theme.spacingM - Theme.spacingM - 32 - Theme.spacingS
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2

                                    StyledText {
                                        width: parent.width
                                        text: modelData.name
                                        font.pixelSize: Theme.fontSizeMedium
                                        font.weight: Font.Medium
                                        color: Theme.surfaceText
                                        elide: Text.ElideRight
                                    }

                                    StyledText {
                                        width: parent.width
                                        text: modelData.exec
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                        elide: Text.ElideRight
                                    }
                                }
                            }

                            DankActionButton {
                                anchors.right: parent.right
                                anchors.rightMargin: Theme.spacingS
                                anchors.verticalCenter: parent.verticalCenter
                                iconName: "close"
                                iconSize: 16
                                buttonSize: 32
                                circular: true
                                iconColor: Theme.error
                                onClicked: root.removeEntry(modelData.filePath)
                            }
                        }
                    }

                    StyledText {
                        width: parent.width
                        text: I18n.tr("No autostart entries")
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceVariantText
                        horizontalAlignment: Text.AlignHCenter
                        visible: root.entries.length === 0
                    }
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "system_tray"
                title: I18n.tr("Tray Icon Fix")

                Column {
                    width: parent.width
                    spacing: Theme.spacingM

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
                        onClicked: root.generateTrayOverride()
                    }
                }
            }
        }
    }
}
