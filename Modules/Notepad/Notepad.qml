import QtQuick
import QtQuick.Controls
import QtCore
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import qs.Common
import qs.Modals.Common
import qs.Modals.FileBrowser
import qs.Services
import qs.Widgets

pragma ComponentBehavior: Bound

Item {
    id: root

    property bool fileDialogOpen: false
    property string currentFileName: ""
    property url currentFileUrl
    property bool confirmationDialogOpen: false
    property string pendingAction: ""
    property url pendingFileUrl
    property string lastSavedFileContent: ""
    property var currentTab: NotepadStorageService.tabs.length > NotepadStorageService.currentTabIndex ? NotepadStorageService.tabs[NotepadStorageService.currentTabIndex] : null
    property bool showSettingsMenu: false
    property string pendingSaveContent: ""

    signal hideRequested()

    function hasUnsavedChanges() {
        return textEditor.hasUnsavedChanges()
    }

    function hasUnsavedTemporaryContent() {
        return hasUnsavedChanges()
    }

    function createNewTab() {
        performCreateNewTab()
    }

    function performCreateNewTab() {
        NotepadStorageService.createNewTab()
        textEditor.text = ""
        textEditor.lastSavedContent = ""
        textEditor.contentLoaded = true
        textEditor.textArea.forceActiveFocus()
    }

    function closeTab(tabIndex) {
        if (tabIndex === NotepadStorageService.currentTabIndex && hasUnsavedChanges()) {
            root.pendingAction = "close_tab_" + tabIndex
            root.confirmationDialogOpen = true
            confirmationDialog.open()
        } else {
            performCloseTab(tabIndex)
        }
    }

    function performCloseTab(tabIndex) {
        NotepadStorageService.closeTab(tabIndex)
        Qt.callLater(() => {
            textEditor.loadCurrentTabContent()
        })
    }

    function switchToTab(tabIndex) {
        if (tabIndex < 0 || tabIndex >= NotepadStorageService.tabs.length) return

        if (textEditor.contentLoaded) {
            textEditor.autoSaveToSession()
        }

        NotepadStorageService.switchToTab(tabIndex)
        Qt.callLater(() => {
            textEditor.loadCurrentTabContent()
            if (currentTab) {
                root.currentFileName = currentTab.fileName || ""
                root.currentFileUrl = currentTab.fileUrl || ""
            }
        })
    }

    function saveToFile(fileUrl) {
        if (!currentTab) return

        var content = textEditor.text
        var filePath = fileUrl.toString().replace(/^file:\/\//, '')

        saveFileView.path = ""
        pendingSaveContent = content
        saveFileView.path = filePath

        Qt.callLater(() => {
            saveFileView.setText(pendingSaveContent)
        })
    }

    function loadFromFile(fileUrl) {
        if (hasUnsavedTemporaryContent()) {
            root.pendingFileUrl = fileUrl
            root.pendingAction = "load_file"
            root.confirmationDialogOpen = true
            confirmationDialog.open()
        } else {
            performLoadFromFile(fileUrl)
        }
    }

    function performLoadFromFile(fileUrl) {
        const filePath = fileUrl.toString().replace(/^file:\/\//, '')
        const fileName = filePath.split('/').pop()

        loadFileView.path = ""
        loadFileView.path = filePath

        if (loadFileView.waitForJob()) {
            Qt.callLater(() => {
                var content = loadFileView.text()
                if (currentTab && content !== undefined && content !== null) {
                    textEditor.text = content
                    textEditor.lastSavedContent = content
                    textEditor.contentLoaded = true
                    root.lastSavedFileContent = content

                    NotepadStorageService.updateTabMetadata(NotepadStorageService.currentTabIndex, {
                        title: fileName,
                        filePath: filePath,
                        isTemporary: false
                    })

                    root.currentFileName = fileName
                    root.currentFileUrl = fileUrl
                    textEditor.saveCurrentTabContent()
                }
            })
        }
    }

    Column {
        anchors.fill: parent
        spacing: Theme.spacingM

        NotepadTabs {
            id: tabBar
            width: parent.width
            contentLoaded: textEditor.contentLoaded

            onTabSwitched: (tabIndex) => {
                switchToTab(tabIndex)
            }

            onTabClosed: (tabIndex) => {
                closeTab(tabIndex)
            }

            onNewTabRequested: {
                createNewTab()
            }
        }

        NotepadTextEditor {
            id: textEditor
            width: parent.width
            height: parent.height - tabBar.height - Theme.spacingM * 2

            onSaveRequested: {
                if (currentTab && !currentTab.isTemporary && currentTab.filePath) {
                    var fileUrl = "file://" + currentTab.filePath
                    saveToFile(fileUrl)
                } else {
                    root.fileDialogOpen = true
                    saveBrowser.open()
                }
            }

            onOpenRequested: {
                if (hasUnsavedChanges()) {
                    root.pendingAction = "open"
                    root.confirmationDialogOpen = true
                    confirmationDialog.open()
                } else {
                    root.fileDialogOpen = true
                    loadBrowser.open()
                }
            }

            onNewRequested: {
                if (hasUnsavedChanges()) {
                    root.pendingAction = "new"
                    root.confirmationDialogOpen = true
                    confirmationDialog.open()
                } else {
                    createNewTab()
                }
            }

            onEscapePressed: {
                root.hideRequested()
            }

            onSettingsRequested: {
                showSettingsMenu = !showSettingsMenu
            }
        }
    }

    NotepadSettings {
        id: notepadSettings
        anchors.fill: parent
        isVisible: showSettingsMenu
        onSettingsRequested: showSettingsMenu = !showSettingsMenu
        onFindRequested: {
            showSettingsMenu = false
            textEditor.showSearch()
        }
    }

    FileView {
        id: saveFileView
        blockWrites: true
        preload: false
        atomicWrites: true
        printErrors: true

        onSaved: {
            if (currentTab && saveFileView.path && pendingSaveContent) {
                NotepadStorageService.updateTabMetadata(NotepadStorageService.currentTabIndex, {
                    hasUnsavedChanges: false,
                    lastSavedContent: pendingSaveContent
                })
                root.lastSavedFileContent = pendingSaveContent
                pendingSaveContent = ""
            }
        }

        onSaveFailed: (error) => {
            pendingSaveContent = ""
        }
    }

    FileView {
        id: loadFileView
        blockLoading: true
        preload: true
        atomicWrites: true
        printErrors: true

        onLoadFailed: (error) => {
        }
    }

    FileBrowserModal {
        id: saveBrowser

        browserTitle: I18n.tr("Save Notepad File")
        browserIcon: "save"
        browserType: "notepad_save"
        fileExtensions: ["*.txt", "*.md", "*.*"]
        allowStacking: true
        saveMode: true
        defaultFileName: {
            if (currentTab && currentTab.title && currentTab.title !== "Untitled") {
                return currentTab.title
            } else if (currentTab && !currentTab.isTemporary && currentTab.filePath) {
                return currentTab.filePath.split('/').pop()
            } else {
                return "note.txt"
            }
        }

        WlrLayershell.layer: WlrLayershell.Overlay

        onFileSelected: (path) => {
            root.fileDialogOpen = false
            const cleanPath = path.toString().replace(/^file:\/\//, '')
            const fileName = cleanPath.split('/').pop()
            const fileUrl = "file://" + cleanPath

            root.currentFileName = fileName
            root.currentFileUrl = fileUrl

            if (currentTab) {
                NotepadStorageService.saveTabAs(
                    NotepadStorageService.currentTabIndex,
                    cleanPath
                )
            }

            saveToFile(fileUrl)

            if (root.pendingAction === "new") {
                Qt.callLater(() => {
                    createNewTab()
                })
            } else if (root.pendingAction === "open") {
                Qt.callLater(() => {
                    root.fileDialogOpen = true
                    loadBrowser.open()
                })
            } else if (root.pendingAction.startsWith("close_tab_")) {
                Qt.callLater(() => {
                    var tabIndex = parseInt(root.pendingAction.split("_")[2])
                    performCloseTab(tabIndex)
                })
            }
            root.pendingAction = ""

            close()
        }

        onDialogClosed: {
            root.fileDialogOpen = false
        }
    }

    FileBrowserModal {
        id: loadBrowser

        browserTitle: I18n.tr("Open Notepad File")
        browserIcon: "folder_open"
        browserType: "notepad_load"
        fileExtensions: ["*.txt", "*.md", "*.*"]
        allowStacking: true

        WlrLayershell.layer: WlrLayershell.Overlay

        onFileSelected: (path) => {
            root.fileDialogOpen = false
            const cleanPath = path.toString().replace(/^file:\/\//, '')
            const fileName = cleanPath.split('/').pop()
            const fileUrl = "file://" + cleanPath

            root.currentFileName = fileName
            root.currentFileUrl = fileUrl

            loadFromFile(fileUrl)
            close()
        }

        onDialogClosed: {
            root.fileDialogOpen = false
        }
    }

    DankModal {
        id: confirmationDialog

        width: 400
        height: 180
        shouldBeVisible: false
        allowStacking: true

        onBackgroundClicked: {
            close()
            root.confirmationDialogOpen = false
        }

        content: Component {
            FocusScope {
                anchors.fill: parent
                focus: true

                Keys.onEscapePressed: event => {
                    confirmationDialog.close()
                    root.confirmationDialogOpen = false
                    event.accepted = true
                }

                Column {
                    anchors.centerIn: parent
                    width: parent.width - Theme.spacingM * 2
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width

                        Column {
                            width: parent.width - 40
                            spacing: Theme.spacingXS

                            StyledText {
                                text: I18n.tr("Unsaved Changes")
                                font.pixelSize: Theme.fontSizeLarge
                                color: Theme.surfaceText
                                font.weight: Font.Medium
                            }

                            StyledText {
                                text: root.pendingAction === "new" ?
                                      I18n.tr("You have unsaved changes. Save before creating a new file?") :
                                      root.pendingAction.startsWith("close_tab_") ?
                                      I18n.tr("You have unsaved changes. Save before closing this tab?") :
                                      root.pendingAction === "load_file" || root.pendingAction === "open" ?
                                      I18n.tr("You have unsaved changes. Save before opening a file?") :
                                      I18n.tr("You have unsaved changes. Save before continuing?")
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceTextMedium
                                width: parent.width
                                wrapMode: Text.Wrap
                            }
                        }

                        DankActionButton {
                            iconName: "close"
                            iconSize: Theme.iconSize - 4
                            iconColor: Theme.surfaceText
                            onClicked: {
                                confirmationDialog.close()
                                root.confirmationDialogOpen = false
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: 40

                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingM

                            Rectangle {
                                width: Math.max(80, discardText.contentWidth + Theme.spacingM * 2)
                                height: 36
                                radius: Theme.cornerRadius
                                color: discardArea.containsMouse ? Theme.surfaceTextHover : "transparent"
                                border.color: Theme.surfaceVariantAlpha
                                border.width: 1

                                StyledText {
                                    id: discardText
                                    anchors.centerIn: parent
                                    text: I18n.tr("Don't Save")
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: Theme.surfaceText
                                    font.weight: Font.Medium
                                }

                                MouseArea {
                                    id: discardArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        confirmationDialog.close()
                                        root.confirmationDialogOpen = false
                                        if (root.pendingAction === "new") {
                                            createNewTab()
                                        } else if (root.pendingAction === "open") {
                                            root.fileDialogOpen = true
                                            loadBrowser.open()
                                        } else if (root.pendingAction === "load_file") {
                                            performLoadFromFile(root.pendingFileUrl)
                                        } else if (root.pendingAction.startsWith("close_tab_")) {
                                            var tabIndex = parseInt(root.pendingAction.split("_")[2])
                                            performCloseTab(tabIndex)
                                        }
                                        root.pendingAction = ""
                                        root.pendingFileUrl = ""
                                    }
                                }
                            }

                            Rectangle {
                                width: Math.max(70, saveAsText.contentWidth + Theme.spacingM * 2)
                                height: 36
                                radius: Theme.cornerRadius
                                color: saveAsArea.containsMouse ? Qt.darker(Theme.primary, 1.1) : Theme.primary

                                StyledText {
                                    id: saveAsText
                                    anchors.centerIn: parent
                                    text: I18n.tr("Save")
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: Theme.background
                                    font.weight: Font.Medium
                                }

                                MouseArea {
                                    id: saveAsArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        confirmationDialog.close()
                                        root.confirmationDialogOpen = false
                                        root.fileDialogOpen = true
                                        saveBrowser.open()
                                    }
                                }

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Theme.shortDuration
                                        easing.type: Theme.standardEasing
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