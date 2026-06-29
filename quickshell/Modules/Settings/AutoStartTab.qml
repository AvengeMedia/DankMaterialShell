import QtCore
import QtQuick
import Qt.labs.folderlistmodel
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
    property string newEntryType: "desktop"
    property string newEntryName: ""
    property string newEntryExec: ""
    property string newEntryDesktopId: ""
    property string newEntryCommandWrapper: "%command%"

    readonly property string autostartDir: {
        const configHome = Paths.strip(StandardPaths.writableLocation(StandardPaths.ConfigLocation));
        return configHome + "/autostart";
    }

    function lookupDesktopIcon(name, exec, fileName) {
        const appId = fileName ? fileName.replace(/\.desktop$/, "") : "";
        let entry = appId ? DesktopEntries.heuristicLookup(appId) : null;
        if (entry && entry.icon)
            return entry.icon;
        if (exec) {
            const cmdBase = exec.split(" ")[0].split("/").pop();
            for (let i = 0; i < root.desktopApps.length; i++) {
                const app = root.desktopApps[i];
                if (app.icon) {
                    const appExec = (app.exec || app.execString || "").split(" ")[0].split("/").pop();
                    if (appExec === cmdBase)
                        return app.icon;
                }
            }
        }
        return "";
    }

    function parseDesktopFile(content, filePath) {
        if (!content || content.length === 0)
            return null;
        const lines = content.split("\n");
        let name = "";
        let execCmd = "";
        let icon = "";
        let hidden = false;
        let isDesktopEntry = false;
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim();
            if (line === "[Desktop Entry]") {
                isDesktopEntry = true;
            } else if (isDesktopEntry) {
                if (line.startsWith("["))
                    break;
                const nameMatch = line.match(/^Name=(.+)$/);
                if (nameMatch)
                    name = nameMatch[1];
                const execMatch = line.match(/^Exec=(.+)$/);
                if (execMatch)
                    execCmd = execMatch[1];
                const iconMatch = line.match(/^Icon=(.+)$/);
                if (iconMatch)
                    icon = iconMatch[1];
                const hiddenMatch = line.match(/^Hidden=(true|false)$/);
                if (hiddenMatch)
                    hidden = hiddenMatch[1] === "true";
            }
        }
        if (!isDesktopEntry || !name || !execCmd)
            return null;
        const fileName = filePath.split("/").pop();
        if (!icon)
            icon = root.lookupDesktopIcon(name, execCmd, fileName);
        return {
            name: name,
            exec: execCmd,
            icon: icon,
            hidden: hidden,
            filePath: filePath,
            fileName: fileName,
            content: content
        };
    }

    function addEntry() {
        if (newEntryType === "desktop") {
            if (!newEntryDesktopId)
                return;
            const app = desktopApps.find(a => (a.id || a.execString) === newEntryDesktopId);
            if (!app)
                return;
            const entryName = app.name || newEntryDesktopId;
            const appExec = app.exec || app.execString || "";
            const execCmd = root.newEntryCommandWrapper.replace("%command%", appExec);
            const appIcon = app.icon || "";
            const fileName = entryName.toLowerCase().replace(/[^a-z0-9]/g, "-") + ".desktop";
            writeDesktopFile(fileName, entryName, execCmd, appIcon);
        } else {
            if (!newEntryName || !newEntryExec)
                return;
            const fileName = newEntryName.toLowerCase().replace(/[^a-z0-9]/g, "-") + ".desktop";
            writeDesktopFile(fileName, newEntryName, newEntryExec, "");
        }
    }

    function writeDesktopFile(fileName, name, execCmd, icon) {
        let content = "[Desktop Entry]\nType=Application\nName=" + name + "\nExec=" + execCmd + "\n";
        if (icon)
            content += "Icon=" + icon + "\n";
        writerFileView.path = root.autostartDir + "/" + fileName;
        writerFileView.setText(content);
        root.resetNewEntry();
    }

    function setHidden(entry, hidden) {
        if (!entry || !entry.content)
            return;
        const lines = entry.content.split("\n");
        const hiddenValue = hidden ? "true" : "false";
        let found = false;
        const merged = lines.map(line => {
            const m = line.match(/^Hidden=(true|false)\s*$/);
            if (m) {
                found = true;
                return "Hidden=" + hiddenValue;
            }
            return line;
        });
        if (!found) {
            const idx = merged.findIndex(l => l.trim() === "[Desktop Entry]");
            if (idx >= 0)
                merged.splice(idx + 1, 0, "Hidden=" + hiddenValue);
            else
                merged.unshift("Hidden=" + hiddenValue);
        }
        writerFileView.path = entry.filePath;
        writerFileView.setText(merged.join("\n"));
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

    function addOrUpdateEntry(entry) {
        var list = root.entries.slice();
        for (var i = 0; i < list.length; i++) {
            if (list[i].filePath === entry.filePath) {
                list[i] = entry;
                root.entries = list;
                return;
            }
        }
        list.push(entry);
        list.sort((a, b) => a.fileName.localeCompare(b.fileName));
        root.entries = list;
    }

    function removeEntryByPath(filePath) {
        var list = root.entries.filter(e => e.filePath !== filePath);
        root.entries = list;
    }

    FileView {
        id: writerFileView
        blockLoading: true
        atomicWrites: true
        onSaveFailed: error => {
            ToastService.showError(I18n.tr("Failed to write autostart entry"));
            log.warn("Failed to write autostart entry to " + writerFileView.path + ": " + error);
        }
    }

    FolderListModel {
        id: folderModel
        nameFilters: ["*.desktop"]
        showDirs: false
        showDotAndDotDot: false
        showHidden: false
        sortField: FolderListModel.Name

        onStatusChanged: {
            if (status !== FolderListModel.Ready)
                return;
            // rebuild entries
            const validPaths = new Set();
            for (let i = 0; i < folderModel.count; i++) {
                const fp = folderModel.get(i, "filePath") || "";
                validPaths.add(fp.startsWith("file://") ? fp.substring(7) : fp);
            }
            const filtered = root.entries.filter(e => validPaths.has(e.filePath));
            if (filtered.length !== root.entries.length) {
                root.entries = filtered;
            }
        }

        onCountChanged: {
            fileReaderRepeater.model = count;
        }
    }

    Repeater {
        id: fileReaderRepeater
        model: 0

        Item {
            required property int index

            readonly property string filePath: {
                const fp = folderModel.get(index, "filePath") || "";
                return fp.startsWith("file://") ? fp.substring(7) : fp;
            }

            FileView {
                id: fileView
                path: filePath ? "file://" + filePath : ""
                watchChanges: true

                onLoaded: {
                    const entry = root.parseDesktopFile(fileView.text(), filePath);
                    if (entry) {
                        root.addOrUpdateEntry(entry);
                    } else {
                        root.removeEntryByPath(filePath);
                    }
                }

                onFileChanged: reload()

                onLoadFailed: {
                    root.removeEntryByPath(filePath);
                }
            }
        }
    }

    Component {
        id: removeFileComponent
        Process {
            property string targetPath: ""
            command: ["rm", "-f", targetPath]
            onExited: (exitCode, exitStatus) => {
                root.removeEntryByPath(targetPath);
                destroy();
            }
        }
    }

    function generateTrayIconFixSystemdOverride() {
        const configHome = Paths.strip(StandardPaths.writableLocation(StandardPaths.ConfigLocation));
        const dir = configHome + "/systemd/user/app-@autostart.service.d";
        const proc = systemdOverrideMkDirComp.createObject(root, {
            targetPath: dir,
            running: true
        });
    }

    FileView {
        id: systemdOverrideWriter
        atomicWrites: true

        // make sure we don't overwrite an existing override with a default one, in case the user has already customized it
        function buildOverrideContent(existing) {
            if (!existing)
                return "[Unit]\nAfter=dms.service\n";
            const lines = existing.split("\n");
            const hasAfter = lines.some(l => l.trim() === "After=dms.service");
            if (hasAfter)
                return existing;
            const unitIdx = lines.findIndex(l => l.trim() === "[Unit]");
            if (unitIdx >= 0) {
                lines.splice(unitIdx + 1, 0, "After=dms.service");
            } else {
                lines.push("[Unit]", "After=dms.service");
            }
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
            log.warn("Failed to write systemd override to " + systemdOverrideWriter.path + ": " + error);
        }
    }

    Component {
        id: systemdOverrideMkDirComp
        Process {
            property string targetPath: ""
            command: ["mkdir", "-p", targetPath]
            onExited: exitCode => {
                if (exitCode === 0) {
                    systemdOverrideWriter.path = targetPath + "/override.conf";
                } else {
                    ToastService.showError(I18n.tr("Failed to generate systemd override"));
                }
                destroy();
            }
        }
    }

    Component {
        id: autostartInitMkDirComp
        Process {
            command: ["mkdir", "-p", root.autostartDir]
            onExited: exitCode => {
                if (exitCode === 0) {
                    folderModel.folder = "file://" + root.autostartDir;
                }
                destroy();
            }
        }
    }

    Component.onCompleted: {
        desktopApps = AppSearchService.getVisibleApplications() || [];
        autostartInitMkDirComp.createObject(root, {
            running: true
        });
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
            visible: DesktopService.autostartAvailable

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
                                if (!root.newEntryDesktopId)
                                    return "";
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
                        if (root.newEntryType === "desktop")
                            return root.newEntryDesktopId !== "";
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
                            color: Theme.withAlpha(Theme.surfaceContainer, 0.3)
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
                                    width: parent.width - 20 - Theme.spacingM - 24 - Theme.spacingM - Theme.spacingM - 60 - Theme.spacingM - 32 - Theme.spacingS
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2

                                    StyledText {
                                        width: parent.width
                                        text: modelData.name
                                        font.pixelSize: Theme.fontSizeMedium
                                        font.weight: Font.Medium
                                        color: modelData.hidden ? Theme.surfaceVariantText : Theme.surfaceText
                                        elide: Text.ElideRight
                                        opacity: modelData.hidden ? 0.6 : 1.0
                                    }

                                    StyledText {
                                        width: parent.width
                                        text: modelData.hidden ? I18n.tr("Disabled") : modelData.exec
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                        elide: Text.ElideRight
                                    }
                                }

                                DankToggle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    checked: !modelData.hidden
                                    onToggled: checked => root.setHidden(modelData, !checked)
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
                iconName: "handyman"
                title: I18n.tr("Tray Icon Fix")
                visible: DesktopService.isSystemd

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
                        onClicked: root.generateTrayIconFixSystemdOverride()
                    }
                }
            }
        }
    }
}
