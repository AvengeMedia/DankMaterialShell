import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets

Item {
    id: root

    readonly property var appCategory: ({
            WebBrowser: 0,
            FileManager: 1,
            TextEditor: 2,
            ImageViewer: 3,
            VideoPlayer: 4,
            MusicPlayer: 5,
            PDFReader: 6,
            Mail: 7,
            Terminal: 8,
            Calendar: 9
        })

    property string currentWebBrowserAppId: ""
    property string currentFileManagerAppId: ""
    property string currentTextEditorAppId: ""
    property string currentImageViewerAppId: ""
    property string currentVideoPlayerAppId: ""
    property string currentMusicPlayerAppId: ""
    property string currentPDFReaderAppId: ""
    property string currentMailAppId: ""
    property string currentTerminalAppId: ""
    property string currentCalendarAppId: ""

    property var categoryModels: ({})

    // A curated list of MIME types for each category.
    // The first one is used for fetching the apps list and current default,
    // the rest are for setting the default app.
    readonly property var mimeMapping: ({
            [root.appCategory.WebBrowser]: ["x-scheme-handler/https", "x-scheme-handler/http", "text/html", "application/xhtml+xml"],
            [root.appCategory.FileManager]: ["inode/directory", "x-scheme-handler/file"],
            [root.appCategory.TextEditor]: ["text/plain", "application/x-zerosize", "text/x-c++src", "text/x-csrc", "text/x-python", "text/x-shellscript", "application/json"],
            [root.appCategory.ImageViewer]: ["image/png", "image/jpeg", "image/gif", "image/bmp", "image/webp", "image/avif", "image/svg+xml"],
            [root.appCategory.VideoPlayer]: ["video/mp4", "video/x-matroska", "video/webm", "video/avi", "video/mpeg", "video/quicktime", "video/x-msvideo"],
            [root.appCategory.MusicPlayer]: ["audio/mpeg", "audio/x-flac", "audio/wav", "audio/ogg", "audio/aac", "audio/webm"],
            [root.appCategory.PDFReader]: ["application/pdf", "application/x-ext-pdf", "application/x-bzpdf", "application/x-gzpdf", "application/vnd.comicbook-rar", "application/vnd.comicbook+zip"],
            [root.appCategory.Mail]: ["x-scheme-handler/mailto"],
            [root.appCategory.Calendar]: ["x-scheme-handler/calendar"],
            [root.appCategory.Terminal]: ["terminal"] // Special
        })

    function propertyName(type) {
        const names = Object.keys(root.appCategory);
        return "current" + names[type] + "AppId";
    }

    function loadAppSearchCategory(categoryName) {
        const apps = AppSearchService.getVisibleApplications() || [];
        return apps.filter(app => {
            const categories = app.categories || [];
            return categories.includes(categoryName);
        });
    }

    function getAppDisplayName(appId) {
        if (appId === root.dmsChooserId || appId === "dms-open") {
            return root.dmsChooserLabel;
        }
        let entry = DesktopEntries.heuristicLookup(appId);
        if (entry && entry.name) {
            return entry.name;
        }
        const withoutSuffix = appId.replace(/\.desktop$/, "");
        if (withoutSuffix !== appId) {
            entry = DesktopEntries.heuristicLookup(withoutSuffix);
            if (entry && entry.name) {
                return entry.name;
            }
        }
        return appId;
    }

    readonly property string dmsChooserId: "dms-open.desktop"
    readonly property string dmsChooserLabel: I18n.tr("DMS Chooser")

    function withDmsChooser(entries) {
        const filtered = (entries || []).filter(e => e.value !== root.dmsChooserId && e.value !== "dms-open");
        return [
            {
                text: root.dmsChooserLabel,
                value: root.dmsChooserId
            }
        ].concat(filtered);
    }

    function loadCategoryModel(categoryKey, categorySearchName) {
        const apps = loadAppSearchCategory(categorySearchName);
        const appIds = apps.map(app => app.id || app.execString || "").filter(id => id);
        let models = Object.assign({}, root.categoryModels);
        const entries = appIds.map(id => ({
                    text: root.getAppDisplayName(id),
                    value: id
                }));
        models[categoryKey] = categoryKey === root.appCategory.Terminal ? entries : root.withDmsChooser(entries);
        root.categoryModels = models;
    }

    Component.onCompleted: {
        const categories = Object.values(root.appCategory);

        categories.forEach(category => {
            switch (category) {
            case root.appCategory.Terminal:
                // Terminals don't have a MIME type
                loadCategoryModel(root.appCategory.Terminal, "TerminalEmulator");
                getDefaultTerminal();
                break;
            case root.appCategory.WebBrowser:
                // When using the MIME type, stuff like dms-run shows up.
                // It's probably better to use the category.
                loadCategoryModel(root.appCategory.WebBrowser, "WebBrowser");
                DesktopService.getDefaultApp(mimeMapping[category][0], category.toString());
                break;
            case root.appCategory.FileManager:
                // Use categories for file managers instead,
                // you don't want Kate as your file manager just because it can open folders
                loadCategoryModel(root.appCategory.FileManager, "FileManager");
                DesktopService.getDefaultApp(mimeMapping[category][0], category.toString());
                break;
            default:
                const mimeType = mimeMapping[category][0];
                DesktopService.getDefaultApp(mimeType, category.toString());
                DesktopService.getAppsForMimeType(mimeType, category.toString());
                break;
            }
        });
    }

    function getDefaultTerminal() {
        // Run xdg-terminal-exec to get the default terminal
        const proc = xdgGetDefaultTerminal.createObject(root, {
            running: true
        });
    }

    function setDefaultTerminal(terminalId) {
        // Write to xdg-terminals.list
        const proc = xdgSetDefaultTerminal.createObject(root, {
            terminalId: terminalId,
            running: true
        });
    }

    Component {
        id: xdgSetDefaultTerminal
        Process {
            property string terminalId: ""
            property string configPath: Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")
            command: ["sh", "-c", `echo "${terminalId}.desktop" > "${configPath}/xdg-terminals.list"`]
            onExited: (exitCode, exitStatus) => {
                if (exitCode != 0) {
                    log.error("Failed to write xdg-terminals.list, exit code:", exitCode);
                }
                destroy();
            }
        }
    }

    Component {
        id: xdgGetDefaultTerminal
        Process {
            property string configPath: Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")

            command: ["sh", "-c", `cat '${configPath}/xdg-terminals.list'`]
            stdout: StdioCollector {
                onStreamFinished: {
                    const defaultTerminal = text.trim();
                    if (defaultTerminal) {
                        root.currentTerminalAppId = defaultTerminal;
                    } else {
                        log.warn("No default terminal found");
                    }
                }
            }
            stderr: StdioCollector {
                onStreamFinished: {
                    if (text.trim().length > 0) {
                        log.error("Error getting default terminal:", text);
                    }
                }
            }
            onExited: (exitCode, exitStatus) => {
                destroy();
            }
        }
    }

    Connections {
        target: DesktopService

        function onGetAppsForMimeResult(mimeType, appIds, callbackId) {
            let categoryIndex = parseInt(callbackId);
            let models = Object.assign({}, root.categoryModels);

            const entries = (appIds || []).map(id => ({
                        text: root.getAppDisplayName(id),
                        value: id
                    }));

            models[categoryIndex] = root.withDmsChooser(entries);
            root.categoryModels = models;
        }

        function onGetDefaultAppResult(mimeType, desktopFileId, callbackId) {
            if (!desktopFileId) {
                log.info("No default app found for MIME type:", mimeType);
                return;
            }
            root[propertyName(parseInt(callbackId))] = desktopFileId;
        }
    }

    component AppSelector: SettingsDropdownRow {
        property int category: -1
        options: (root.categoryModels[category] || []).map(opt => opt.text)
        enabled: options.length > 0
        emptyText: options.length > 0 ? I18n.tr("Unset", "Unset") : ""
        opacity: options.length > 0 ? 1 : 0.5
        currentValue: {
            let id = root[propertyName(category)];
            if (!id || id.length === 0) {
                return "";
            }
            return root.getAppDisplayName(id);
        }
        onValueChanged: val => {
            let model = root.categoryModels[category] || [];
            let found = model.find(opt => opt.text === val);
            if (found) {
                if (category === root.appCategory.Terminal) {
                    root.setDefaultTerminal(found.value);
                } else {
                    DesktopService.setDefaultAppForMimes(root.mimeMapping[category], found.value, category.toString());
                }
            }
        }
    }

    // Dropdowns

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
                title: I18n.tr("Internet", "Internet")
                iconName: "public"

                AppSelector {
                    text: I18n.tr("Web Browser", "Web Browser")
                    tags: ["web", "browser", "internet"]
                    category: root.appCategory.WebBrowser
                    description: I18n.tr("Handles links and opens HTML files", "Handles links and opens HTML files")
                }

                AppSelector {
                    text: I18n.tr("Mail", "Mail")
                    category: root.appCategory.Mail
                    tags: ["mail", "email"]
                    description: I18n.tr("Handles mailto links", "Handles mailto links")
                }
            }

            SettingsCard {
                title: I18n.tr("Utilities", "Utilities")
                iconName: "terminal"

                AppSelector {
                    text: I18n.tr("File Manager", "File Manager")
                    tags: ["file", "manager"]
                    category: root.appCategory.FileManager
                    description: I18n.tr("Manages files and directories", "Manages files and directories")
                }
                AppSelector {
                    text: I18n.tr("Terminal", "Terminal")
                    category: root.appCategory.Terminal
                    tags: ["terminal", "console"]
                    description: I18n.tr("Used for xdg-terminal-exec", "Used for xdg-terminal-exec")
                }
                AppSelector {
                    text: I18n.tr("Calendar", "Calendar")
                    category: root.appCategory.Calendar
                    tags: ["calendar", "events"]
                    description: I18n.tr("Manages calendar events", "Manages calendar events")
                }
            }

            SettingsCard {
                title: I18n.tr("Documents", "Documents")
                iconName: "edit_document"

                AppSelector {
                    text: I18n.tr("Text Editor", "Text Editor")
                    category: root.appCategory.TextEditor
                    tags: ["text", "editor"]
                    description: I18n.tr("For editing plain text files", "For editing plain text files")
                }
                AppSelector {
                    text: I18n.tr("PDF Reader", "PDF Reader")
                    category: root.appCategory.PDFReader
                    tags: ["pdf", "reader"]
                    description: I18n.tr("For reading PDF files", "For reading PDF files")
                }
            }

            SettingsCard {
                title: I18n.tr("Multimedia", "Multimedia")
                iconName: "movie"
                AppSelector {
                    text: I18n.tr("Image Viewer", "Image Viewer")
                    category: root.appCategory.ImageViewer
                    tags: ["image", "viewer"]
                    description: I18n.tr("Opens image files", "Opens image files")
                }
                AppSelector {
                    text: I18n.tr("Video Player", "Video Player")
                    category: root.appCategory.VideoPlayer
                    tags: ["video", "player"]
                    description: I18n.tr("Plays video files", "Plays video files")
                }
                AppSelector {
                    text: I18n.tr("Music Player", "Music Player")
                    category: root.appCategory.MusicPlayer
                    tags: ["music", "player"]
                    description: I18n.tr("Plays audio files", "Plays audio files")
                }
            }
        }
    }
}
