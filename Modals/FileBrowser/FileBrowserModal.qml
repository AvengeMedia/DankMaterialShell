import Qt.labs.folderlistmodel
import QtCore
import QtQuick
import QtQuick.Controls
import Quickshell.Io
import qs.Common
import qs.Modals.Common
import qs.Widgets

DankModal {
    id: fileBrowserModal

    property string homeDir: StandardPaths.writableLocation(StandardPaths.HomeLocation)
    property string currentPath: ""
    property var fileExtensions: ["*.*"]
    property alias filterExtensions: fileBrowserModal.fileExtensions
    property string browserTitle: "Select File"
    property string browserIcon: "folder_open"
    property string browserType: "generic" // "wallpaper" or "profile" for last path memory
    property bool showHiddenFiles: false
    property int selectedIndex: -1
    property bool keyboardNavigationActive: false
    property bool backButtonFocused: false
    property bool saveMode: false // Enable save functionality
    property string defaultFileName: "" // Default filename for save mode
    property int keyboardSelectionIndex: -1
    property bool keyboardSelectionRequested: false
    property bool showKeyboardHints: false
    property bool showFileInfo: false
    property string selectedFilePath: ""
    property string selectedFileName: ""
    property bool selectedFileIsDir: false
    property bool showOverwriteConfirmation: false
    property string pendingFilePath: ""
    property bool weAvailable: false
    property string wePath: ""
    property bool weMode: false
    property var parentModal: null
    property bool showSidebar: browserType !== "wallpaper"
    property string viewMode: "grid"
    property string sortBy: "name"
    property bool sortAscending: true
    property int iconSizeIndex: 1
    property var iconSizes: [80, 120, 160, 200]
    property bool pathEditMode: false

    signal fileSelected(string path)

    function isImageFile(fileName) {
        if (!fileName) {
            return false
        }
        const ext = fileName.toLowerCase().split('.').pop()
        return ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg'].includes(ext)
    }

    function getLastPath() {
        const lastPath = browserType === "wallpaper" ? CacheData.wallpaperLastPath : browserType === "profile" ? CacheData.profileLastPath : ""
        return (lastPath && lastPath !== "") ? lastPath : homeDir
    }

    function saveLastPath(path) {
        if (browserType === "wallpaper") {
            CacheData.wallpaperLastPath = path
            CacheData.saveCache()
        } else if (browserType === "profile") {
            CacheData.profileLastPath = path
            CacheData.saveCache()
        }
    }

    function setSelectedFileData(path, name, isDir) {
        selectedFilePath = path
        selectedFileName = name
        selectedFileIsDir = isDir
    }

    function navigateUp() {
        const path = currentPath
        if (path === homeDir)
            return

        const lastSlash = path.lastIndexOf('/')
        if (lastSlash > 0) {
            const newPath = path.substring(0, lastSlash)
            if (newPath.length < homeDir.length) {
                currentPath = homeDir
                saveLastPath(homeDir)
            } else {
                currentPath = newPath
                saveLastPath(newPath)
            }
        }
    }

    function navigateTo(path) {
        currentPath = path
        saveLastPath(path)
        selectedIndex = -1
        backButtonFocused = false
    }

    function keyboardFileSelection(index) {
        if (index >= 0) {
            keyboardSelectionTimer.targetIndex = index
            keyboardSelectionTimer.start()
        }
    }

    function executeKeyboardSelection(index) {
        keyboardSelectionIndex = index
        keyboardSelectionRequested = true
    }

    function formatFileSize(size) {
        if (size < 1024)
            return size + " B"
        if (size < 1024 * 1024)
            return (size / 1024).toFixed(1) + " KB"
        if (size < 1024 * 1024 * 1024)
            return (size / (1024 * 1024)).toFixed(1) + " MB"
        return (size / (1024 * 1024 * 1024)).toFixed(1) + " GB"
    }

    function handleSaveFile(filePath) {
        var normalizedPath = filePath
        if (!normalizedPath.startsWith("file://")) {
            normalizedPath = "file://" + filePath
        }

        var exists = false
        var fileName = filePath.split('/').pop()

        for (var i = 0; i < folderModel.count; i++) {
            if (folderModel.get(i, "fileName") === fileName && !folderModel.get(i, "fileIsDir")) {
                exists = true
                break
            }
        }

        if (exists) {
            pendingFilePath = normalizedPath
            showOverwriteConfirmation = true
        } else {
            fileSelected(normalizedPath)
            fileBrowserModal.close()
        }
    }

    objectName: "fileBrowserModal"
    allowStacking: true
    closeOnEscapeKey: false
    shouldHaveFocus: shouldBeVisible
    Component.onCompleted: {
        currentPath = getLastPath()
    }

    property var steamPaths: [StandardPaths.writableLocation(StandardPaths.HomeLocation) + "/.steam/steam/steamapps/workshop/content/431960", StandardPaths.writableLocation(
            StandardPaths.HomeLocation) + "/.local/share/Steam/steamapps/workshop/content/431960", StandardPaths.writableLocation(
            StandardPaths.HomeLocation) + "/.var/app/com.valvesoftware.Steam/.local/share/Steam/steamapps/workshop/content/431960", StandardPaths.writableLocation(
            StandardPaths.HomeLocation) + "/snap/steam/common/.local/share/Steam/steamapps/workshop/content/431960"]
    property int currentPathIndex: 0

    function discoverWallpaperEngine() {
        currentPathIndex = 0
        checkNextPath()
    }

    function checkNextPath() {
        if (currentPathIndex >= steamPaths.length) {
            return
        }

        const wePath = steamPaths[currentPathIndex]
        const cleanPath = wePath.replace(/^file:\/\//, '')
        weDiscoveryProcess.command = ["test", "-d", cleanPath]
        weDiscoveryProcess.wePath = wePath
        weDiscoveryProcess.running = true
    }
    width: 800
    height: 600
    enableShadow: true
    visible: false
    onBackgroundClicked: close()
    onOpened: {
        if (parentModal) {
            parentModal.shouldHaveFocus = false
            parentModal.allowFocusOverride = true
        }
        Qt.callLater(() => {
                         if (contentLoader && contentLoader.item) {
                             contentLoader.item.forceActiveFocus()
                         }
                     })
    }
    onDialogClosed: {
        if (parentModal) {
            parentModal.allowFocusOverride = false
            parentModal.shouldHaveFocus = Qt.binding(() => {
                                                         return parentModal.shouldBeVisible
                                                     })
        }
    }
    onVisibleChanged: {
        if (visible) {
            currentPath = getLastPath()
            selectedIndex = -1
            keyboardNavigationActive = false
            backButtonFocused = false
            if (browserType === "wallpaper" && !weAvailable) {
                discoverWallpaperEngine()
            }
        }
    }
    onCurrentPathChanged: {
        selectedFilePath = ""
        selectedFileName = ""
        selectedFileIsDir = false
    }
    onSelectedIndexChanged: {
        if (selectedIndex >= 0 && folderModel && selectedIndex < folderModel.count) {
            selectedFilePath = ""
            selectedFileName = ""
            selectedFileIsDir = false
        }
    }

    FolderListModel {
        id: folderModel

        showDirsFirst: true
        showDotAndDotDot: false
        showHidden: fileBrowserModal.showHiddenFiles
        nameFilters: fileExtensions
        showFiles: true
        showDirs: true
        folder: currentPath ? "file://" + currentPath : "file://" + homeDir
        sortField: {
            switch (sortBy) {
            case "name":
                return FolderListModel.Name
            case "size":
                return FolderListModel.Size
            case "modified":
                return FolderListModel.Time
            case "type":
                return FolderListModel.Type
            default:
                return FolderListModel.Name
            }
        }
        sortReversed: !sortAscending
    }

    property var quickAccessLocations: [{
            "name": "Home",
            "path": homeDir,
            "icon": "home"
        }, {
            "name": "Documents",
            "path": homeDir + "/Documents",
            "icon": "description"
        }, {
            "name": "Downloads",
            "path": homeDir + "/Downloads",
            "icon": "download"
        }, {
            "name": "Pictures",
            "path": homeDir + "/Pictures",
            "icon": "image"
        }, {
            "name": "Music",
            "path": homeDir + "/Music",
            "icon": "music_note"
        }, {
            "name": "Videos",
            "path": homeDir + "/Videos",
            "icon": "movie"
        }, {
            "name": "Desktop",
            "path": homeDir + "/Desktop",
            "icon": "computer"
        }]

    QtObject {
        id: keyboardController

        property int totalItems: folderModel.count
        property int gridColumns: 5

        function handleKey(event) {
            if (event.key === Qt.Key_Escape) {
                close()
                event.accepted = true
                return
            }
            // F10 toggles keyboard hints
            if (event.key === Qt.Key_F10) {
                showKeyboardHints = !showKeyboardHints
                event.accepted = true
                return
            }
            // F1 or I key for file information
            if (event.key === Qt.Key_F1 || event.key === Qt.Key_I) {
                showFileInfo = !showFileInfo
                event.accepted = true
                return
            }
            // Alt+Left or Backspace to go back
            if ((event.modifiers & Qt.AltModifier && event.key === Qt.Key_Left) || event.key === Qt.Key_Backspace) {
                if (currentPath !== homeDir) {
                    navigateUp()
                    event.accepted = true
                }
                return
            }
            if (!keyboardNavigationActive) {
                const isInitKey = event.key === Qt.Key_Tab || event.key === Qt.Key_Down || event.key
                                === Qt.Key_Right || (event.key === Qt.Key_N && event.modifiers & Qt.ControlModifier) || (event.key === Qt.Key_J && event.modifiers & Qt.ControlModifier) || (event.key === Qt.Key_L && event.modifiers & Qt.ControlModifier)

                if (isInitKey) {
                    keyboardNavigationActive = true
                    if (currentPath !== homeDir) {
                        backButtonFocused = true
                        selectedIndex = -1
                    } else {
                        backButtonFocused = false
                        selectedIndex = 0
                    }
                    event.accepted = true
                }
                return
            }
            switch (event.key) {
            case Qt.Key_Tab:
                if (backButtonFocused) {
                    backButtonFocused = false
                    selectedIndex = 0
                } else if (selectedIndex < totalItems - 1) {
                    selectedIndex++
                } else if (currentPath !== homeDir) {
                    backButtonFocused = true
                    selectedIndex = -1
                } else {
                    selectedIndex = 0
                }
                event.accepted = true
                break
            case Qt.Key_Backtab:
                if (backButtonFocused) {
                    backButtonFocused = false
                    selectedIndex = totalItems - 1
                } else if (selectedIndex > 0) {
                    selectedIndex--
                } else if (currentPath !== homeDir) {
                    backButtonFocused = true
                    selectedIndex = -1
                } else {
                    selectedIndex = totalItems - 1
                }
                event.accepted = true
                break
            case Qt.Key_N:
                if (event.modifiers & Qt.ControlModifier) {
                    if (backButtonFocused) {
                        backButtonFocused = false
                        selectedIndex = 0
                    } else if (selectedIndex < totalItems - 1) {
                        selectedIndex++
                    }
                    event.accepted = true
                }
                break
            case Qt.Key_P:
                if (event.modifiers & Qt.ControlModifier) {
                    if (selectedIndex > 0) {
                        selectedIndex--
                    } else if (currentPath !== homeDir) {
                        backButtonFocused = true
                        selectedIndex = -1
                    }
                    event.accepted = true
                }
                break
            case Qt.Key_J:
                if (event.modifiers & Qt.ControlModifier) {
                    if (selectedIndex < totalItems - 1) {
                        selectedIndex++
                    }
                    event.accepted = true
                }
                break
            case Qt.Key_K:
                if (event.modifiers & Qt.ControlModifier) {
                    if (selectedIndex > 0) {
                        selectedIndex--
                    } else if (currentPath !== homeDir) {
                        backButtonFocused = true
                        selectedIndex = -1
                    }
                    event.accepted = true
                }
                break
            case Qt.Key_H:
                if (event.modifiers & Qt.ControlModifier) {
                    if (!backButtonFocused && selectedIndex > 0) {
                        selectedIndex--
                    } else if (currentPath !== homeDir) {
                        backButtonFocused = true
                        selectedIndex = -1
                    }
                    event.accepted = true
                }
                break
            case Qt.Key_L:
                if (event.modifiers & Qt.ControlModifier) {
                    if (backButtonFocused) {
                        backButtonFocused = false
                        selectedIndex = 0
                    } else if (selectedIndex < totalItems - 1) {
                        selectedIndex++
                    }
                    event.accepted = true
                }
                break
            case Qt.Key_Left:
                if (backButtonFocused)
                    return

                if (selectedIndex > 0) {
                    selectedIndex--
                } else if (currentPath !== homeDir) {
                    backButtonFocused = true
                    selectedIndex = -1
                }
                event.accepted = true
                break
            case Qt.Key_Right:
                if (backButtonFocused) {
                    backButtonFocused = false
                    selectedIndex = 0
                } else if (selectedIndex < totalItems - 1) {
                    selectedIndex++
                }
                event.accepted = true
                break
            case Qt.Key_Up:
                if (backButtonFocused) {
                    backButtonFocused = false
                    // Go to first row, appropriate column
                    var col = selectedIndex % gridColumns
                    selectedIndex = Math.min(col, totalItems - 1)
                } else if (selectedIndex >= gridColumns) {
                    // Move up one row
                    selectedIndex -= gridColumns
                } else if (currentPath !== homeDir) {
                    // At top row, go to back button
                    backButtonFocused = true
                    selectedIndex = -1
                }
                event.accepted = true
                break
            case Qt.Key_Down:
                if (backButtonFocused) {
                    backButtonFocused = false
                    selectedIndex = 0
                } else {
                    // Move down one row if possible
                    var newIndex = selectedIndex + gridColumns
                    if (newIndex < totalItems) {
                        selectedIndex = newIndex
                    } else {
                        // If can't go down a full row, go to last item in the column if exists
                        var lastRowStart = Math.floor((totalItems - 1) / gridColumns) * gridColumns
                        var col = selectedIndex % gridColumns
                        var targetIndex = lastRowStart + col
                        if (targetIndex < totalItems && targetIndex > selectedIndex) {
                            selectedIndex = targetIndex
                        }
                    }
                }
                event.accepted = true
                break
            case Qt.Key_Return:
            case Qt.Key_Enter:
            case Qt.Key_Space:
                if (backButtonFocused)
                    navigateUp()
                else if (selectedIndex >= 0 && selectedIndex < totalItems)
                    // Trigger selection by setting the grid's current index and using signal
                    fileBrowserModal.keyboardFileSelection(selectedIndex)
                event.accepted = true
                break
            }
        }
    }

    Timer {
        id: keyboardSelectionTimer

        property int targetIndex: -1

        interval: 1
        onTriggered: {
            // Access the currently selected item through model role names
            // This will work because QML models expose role data
            executeKeyboardSelection(targetIndex)
        }
    }

    Process {
        id: weDiscoveryProcess

        property string wePath: ""
        running: false

        onExited: exitCode => {
                      if (exitCode === 0) {
                          fileBrowserModal.weAvailable = true
                          fileBrowserModal.wePath = wePath
                      } else {
                          currentPathIndex++
                          checkNextPath()
                      }
                  }
    }

    content: Component {
        Item {
            anchors.fill: parent

            Keys.onPressed: event => {
                                keyboardController.handleKey(event)
                            }

            onVisibleChanged: {
                if (visible) {
                    forceActiveFocus()
                }
            }

            Row {
                anchors.fill: parent
                spacing: 0

                StyledRect {
                    id: sidebar
                    width: showSidebar ? 200 : 0
                    height: parent.height
                    color: Theme.surfaceContainer
                    visible: showSidebar
                    clip: true

                    Column {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingS
                        spacing: Theme.spacingXS

                        StyledText {
                            text: "Quick Access"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceTextMedium
                            font.weight: Font.Medium
                            leftPadding: Theme.spacingS
                        }

                        Repeater {
                            model: quickAccessLocations

                            StyledRect {
                                width: parent.width
                                height: 36
                                radius: Theme.cornerRadiusSmall
                                color: quickAccessMouseArea.containsMouse ? Theme.surfaceVariant : (currentPath === modelData.path ? Theme.surfacePressed : "transparent")

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.spacingS
                                    spacing: Theme.spacingS

                                    DankIcon {
                                        name: modelData.icon
                                        size: Theme.iconSize
                                        color: currentPath === modelData.path ? Theme.primary : Theme.surfaceText
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    StyledText {
                                        text: modelData.name
                                        font.pixelSize: Theme.fontSizeMedium
                                        color: currentPath === modelData.path ? Theme.primary : Theme.surfaceText
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                MouseArea {
                                    id: quickAccessMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: navigateTo(modelData.path)
                                }
                            }
                        }
                    }
                }

                Column {
                    width: parent.width - (showSidebar ? sidebar.width : 0)
                    height: parent.height
                    spacing: 0

                    Item {
                        width: parent.width
                        height: 40

                        Row {
                            spacing: Theme.spacingM
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingM

                            DankIcon {
                                name: browserIcon
                                size: Theme.iconSizeLarge
                                color: Theme.primary
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: browserTitle
                                font.pixelSize: Theme.fontSizeXLarge
                                color: Theme.surfaceText
                                font.weight: Font.Medium
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Row {
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.spacingM
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingS

                            DankActionButton {
                                circular: false
                                iconName: showHiddenFiles ? "visibility_off" : "visibility"
                                iconSize: Theme.iconSize - 4
                                iconColor: showHiddenFiles ? Theme.primary : Theme.surfaceText
                                visible: !weMode
                                onClicked: showHiddenFiles = !showHiddenFiles
                            }

                            DankActionButton {
                                circular: false
                                iconName: viewMode === "grid" ? "view_list" : "grid_view"
                                iconSize: Theme.iconSize - 4
                                iconColor: Theme.surfaceText
                                visible: !weMode
                                onClicked: viewMode = viewMode === "grid" ? "list" : "grid"
                            }

                            DankActionButton {
                                circular: false
                                iconName: iconSizeIndex === 0 ? "photo_size_select_small" : iconSizeIndex === 1 ? "photo_size_select_large" : iconSizeIndex === 2 ? "photo_size_select_actual" : "zoom_in"
                                iconSize: Theme.iconSize - 4
                                iconColor: Theme.surfaceText
                                visible: !weMode && viewMode === "grid"
                                onClicked: iconSizeIndex = (iconSizeIndex + 1) % iconSizes.length
                            }

                            DankActionButton {
                                circular: false
                                iconName: "movie"
                                iconSize: Theme.iconSize - 4
                                iconColor: weMode ? Theme.primary : Theme.surfaceText
                                visible: weAvailable && browserType === "wallpaper"
                                onClicked: {
                                    weMode = !weMode
                                    if (weMode) {
                                        navigateTo(wePath)
                                    } else {
                                        navigateTo(getLastPath())
                                    }
                                }
                            }

                            DankActionButton {
                                circular: false
                                iconName: "info"
                                iconSize: Theme.iconSize - 4
                                iconColor: Theme.surfaceText
                                onClicked: fileBrowserModal.showKeyboardHints = !fileBrowserModal.showKeyboardHints
                            }

                            DankActionButton {
                                circular: false
                                iconName: "close"
                                iconSize: Theme.iconSize - 4
                                iconColor: Theme.surfaceText
                                onClicked: fileBrowserModal.close()
                            }
                        }
                    }

                    StyledRect {
                        width: parent.width
                        height: 1
                        color: Theme.outline
                    }

                    Row {
                        width: parent.width
                        height: 40
                        leftPadding: Theme.spacingM
                        rightPadding: Theme.spacingM
                        spacing: Theme.spacingS

                        StyledRect {
                            width: 32
                            height: 32
                            radius: Theme.cornerRadius
                            color: (backButtonMouseArea.containsMouse || (backButtonFocused && keyboardNavigationActive)) && currentPath !== homeDir ? Theme.surfaceVariant : "transparent"
                            opacity: currentPath !== homeDir ? 1 : 0
                            anchors.verticalCenter: parent.verticalCenter

                            DankIcon {
                                anchors.centerIn: parent
                                name: "arrow_back"
                                size: Theme.iconSizeSmall
                                color: Theme.surfaceText
                            }

                            MouseArea {
                                id: backButtonMouseArea

                                anchors.fill: parent
                                hoverEnabled: currentPath !== homeDir
                                cursorShape: currentPath !== homeDir ? Qt.PointingHandCursor : Qt.ArrowCursor
                                enabled: currentPath !== homeDir
                                onClicked: navigateUp()
                            }
                        }

                        Item {
                            width: parent.width - 40 - Theme.spacingS - (showSidebar ? 0 : 80)
                            height: 32
                            anchors.verticalCenter: parent.verticalCenter

                            StyledRect {
                                anchors.fill: parent
                                radius: Theme.cornerRadiusSmall
                                color: pathEditMode ? Theme.surfaceContainer : "transparent"
                                border.color: pathEditMode ? Theme.primary : "transparent"
                                border.width: pathEditMode ? 1 : 0
                                visible: !pathEditMode

                                StyledText {
                                    id: pathDisplay
                                    text: fileBrowserModal.currentPath.replace("file://", "")
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: Theme.surfaceText
                                    font.weight: Font.Medium
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.spacingS
                                    anchors.rightMargin: Theme.spacingS
                                    elide: Text.ElideMiddle
                                    verticalAlignment: Text.AlignVCenter
                                    maximumLineCount: 1
                                    wrapMode: Text.NoWrap
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.IBeamCursor
                                    onClicked: {
                                        pathEditMode = true
                                        pathInput.text = fileBrowserModal.currentPath.replace("file://", "")
                                        Qt.callLater(() => pathInput.forceActiveFocus())
                                    }
                                }
                            }

                            DankTextField {
                                id: pathInput
                                anchors.fill: parent
                                visible: pathEditMode
                                topPadding: Theme.spacingXS
                                bottomPadding: Theme.spacingXS
                                onAccepted: {
                                    const newPath = text.trim()
                                    if (newPath !== "") {
                                        navigateTo(newPath)
                                    }
                                    pathEditMode = false
                                }
                                Keys.onEscapePressed: {
                                    pathEditMode = false
                                }
                                onActiveFocusChanged: {
                                    if (!activeFocus && pathEditMode) {
                                        pathEditMode = false
                                    }
                                }
                            }
                        }

                        Row {
                            spacing: Theme.spacingXS
                            visible: !showSidebar
                            anchors.verticalCenter: parent.verticalCenter

                            DankActionButton {
                                circular: false
                                iconName: "sort"
                                iconSize: Theme.iconSize - 6
                                iconColor: Theme.surfaceText
                                onClicked: sortMenu.visible = !sortMenu.visible
                            }
                        }
                    }

                    StyledRect {
                        width: parent.width
                        height: 1
                        color: Theme.outline
                    }

                    Item {
                        width: parent.width
                        height: parent.height - 122
                        clip: true

                        DankGridView {
                            id: fileGrid
                            anchors.fill: parent
                            visible: viewMode === "grid"
                            cellWidth: weMode ? 255 : iconSizes[iconSizeIndex] + 20
                            cellHeight: weMode ? 215 : iconSizes[iconSizeIndex] + 50
                            cacheBuffer: 260
                            model: folderModel
                            currentIndex: selectedIndex
                            onCurrentIndexChanged: {
                                if (keyboardNavigationActive && currentIndex >= 0)
                                    positionViewAtIndex(currentIndex, GridView.Contain)
                            }

                            ScrollBar.vertical: ScrollBar {
                                policy: ScrollBar.AsNeeded
                            }

                            ScrollBar.horizontal: ScrollBar {
                                policy: ScrollBar.AlwaysOff
                            }

                            delegate: StyledRect {
                                id: delegateRoot

                        required property bool fileIsDir
                        required property string filePath
                        required property string fileName
                        required property int index

                                width: weMode ? 245 : iconSizes[iconSizeIndex] + 10
                                height: weMode ? 205 : iconSizes[iconSizeIndex] + 40
                                radius: Theme.cornerRadius
                                color: {
                                    if (keyboardNavigationActive && delegateRoot.index === selectedIndex)
                                        return Theme.surfacePressed

                                    return mouseArea.containsMouse ? Theme.surfaceVariant : "transparent"
                                }
                                border.color: keyboardNavigationActive && delegateRoot.index === selectedIndex ? Theme.primary : Theme.outline
                                border.width: (mouseArea.containsMouse || (keyboardNavigationActive && delegateRoot.index === selectedIndex)) ? 1 : 0
                                // Update file info when this item gets selected via keyboard or initially
                                Component.onCompleted: {
                                    if (keyboardNavigationActive && delegateRoot.index === selectedIndex)
                                        setSelectedFileData(delegateRoot.filePath, delegateRoot.fileName, delegateRoot.fileIsDir)
                                }

                                // Watch for selectedIndex changes to update file info during keyboard navigation
                                Connections {
                                    function onSelectedIndexChanged() {
                                        if (keyboardNavigationActive && selectedIndex === delegateRoot.index)
                                            setSelectedFileData(delegateRoot.filePath, delegateRoot.fileName, delegateRoot.fileIsDir)
                                    }

                                    target: fileBrowserModal
                                }

                                Column {
                                    anchors.centerIn: parent
                                    spacing: Theme.spacingXS

                                    Item {
                                        width: weMode ? 225 : iconSizes[iconSizeIndex]
                                        height: weMode ? 165 : iconSizes[iconSizeIndex]
                                        anchors.horizontalCenter: parent.horizontalCenter

                                        CachingImage {
                                            anchors.fill: parent
                                            property var weExtensions: [".jpg", ".jpeg", ".png", ".webp", ".gif", ".bmp", ".tga"]
                                            property int weExtIndex: 0
                                            source: {
                                                if (weMode && delegateRoot.fileIsDir) {
                                                    return "file://" + delegateRoot.filePath + "/preview" + weExtensions[weExtIndex]
                                                }
                                                return (!delegateRoot.fileIsDir && isImageFile(delegateRoot.fileName)) ? ("file://" + delegateRoot.filePath) : ""
                                            }
                                            onStatusChanged: {
                                                if (weMode && delegateRoot.fileIsDir && status === Image.Error) {
                                                    if (weExtIndex < weExtensions.length - 1) {
                                                        weExtIndex++
                                                        source = "file://" + delegateRoot.filePath + "/preview" + weExtensions[weExtIndex]
                                                    } else {
                                                        source = ""
                                                    }
                                                }
                                            }
                                            fillMode: Image.PreserveAspectCrop
                                            visible: (!delegateRoot.fileIsDir && isImageFile(delegateRoot.fileName)) || (weMode && delegateRoot.fileIsDir)
                                            maxCacheSize: weMode ? 225 : iconSizes[iconSizeIndex]
                                        }

                                        DankIcon {
                                            anchors.centerIn: parent
                                            name: "description"
                                            size: Theme.iconSizeLarge
                                            color: Theme.primary
                                            visible: !delegateRoot.fileIsDir && !isImageFile(delegateRoot.fileName)
                                        }

                                        DankIcon {
                                            anchors.centerIn: parent
                                            name: "folder"
                                            size: Theme.iconSizeLarge
                                            color: Theme.primary
                                            visible: delegateRoot.fileIsDir && !weMode
                                        }
                                    }

                                    StyledText {
                                        text: delegateRoot.fileName || ""
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceText
                                        width: 120
                                        elide: Text.ElideMiddle
                                        horizontalAlignment: Text.AlignHCenter
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        maximumLineCount: 2
                                        wrapMode: Text.WordWrap
                                    }
                                }

                                MouseArea {
                                    id: mouseArea

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        // Update selected file info and index first
                                        selectedIndex = delegateRoot.index
                                        setSelectedFileData(delegateRoot.filePath, delegateRoot.fileName, delegateRoot.fileIsDir)
                                        if (weMode && delegateRoot.fileIsDir) {
                                            var sceneId = delegateRoot.filePath.split("/").pop()
                                            fileSelected("we:" + sceneId)
                                            fileBrowserModal.close()
                                        } else if (delegateRoot.fileIsDir) {
                                            navigateTo(delegateRoot.filePath)
                                        } else {
                                            fileSelected(delegateRoot.filePath)
                                            fileBrowserModal.close()
                                        }
                                    }
                                }

                                // Handle keyboard selection
                                Connections {
                                    function onKeyboardSelectionRequestedChanged() {
                                        if (fileBrowserModal.keyboardSelectionRequested && fileBrowserModal.keyboardSelectionIndex === delegateRoot.index) {
                                            fileBrowserModal.keyboardSelectionRequested = false
                                            selectedIndex = delegateRoot.index
                                            setSelectedFileData(delegateRoot.filePath, delegateRoot.fileName, delegateRoot.fileIsDir)
                                            if (weMode && delegateRoot.fileIsDir) {
                                                var sceneId = delegateRoot.filePath.split("/").pop()
                                                fileSelected("we:" + sceneId)
                                                fileBrowserModal.close()
                                            } else if (delegateRoot.fileIsDir) {
                                                navigateTo(delegateRoot.filePath)
                                            } else {
                                                fileSelected(delegateRoot.filePath)
                                                fileBrowserModal.close()
                                            }
                                        }
                                    }

                                    target: fileBrowserModal
                                }
                            }
                        }

                        DankListView {
                            id: fileList
                            anchors.fill: parent
                            visible: viewMode === "list"
                            model: folderModel
                            currentIndex: selectedIndex
                            onCurrentIndexChanged: {
                                if (keyboardNavigationActive && currentIndex >= 0)
                                    positionViewAtIndex(currentIndex, ListView.Contain)
                            }

                            ScrollBar.vertical: ScrollBar {
                                policy: ScrollBar.AsNeeded
                            }

                            delegate: StyledRect {
                                id: listDelegateRoot

                                required property bool fileIsDir
                                required property string filePath
                                required property string fileName
                                required property url fileURL
                                required property int index
                                required property var fileModified
                                required property int fileSize

                                width: fileList.width
                                height: 48
                                radius: Theme.cornerRadiusSmall
                                color: {
                                    if (keyboardNavigationActive && listDelegateRoot.index === selectedIndex)
                                        return Theme.surfacePressed
                                    return listMouseArea.containsMouse ? Theme.surfaceVariant : "transparent"
                                }
                                border.color: keyboardNavigationActive && listDelegateRoot.index === selectedIndex ? Theme.primary : "transparent"
                                border.width: (listMouseArea.containsMouse || (keyboardNavigationActive && listDelegateRoot.index === selectedIndex)) ? 1 : 0

                                Component.onCompleted: {
                                    if (keyboardNavigationActive && listDelegateRoot.index === selectedIndex)
                                        setSelectedFileData(listDelegateRoot.filePath, listDelegateRoot.fileName, listDelegateRoot.fileIsDir)
                                }

                                Connections {
                                    function onSelectedIndexChanged() {
                                        if (keyboardNavigationActive && selectedIndex === listDelegateRoot.index)
                                            setSelectedFileData(listDelegateRoot.filePath, listDelegateRoot.fileName, listDelegateRoot.fileIsDir)
                                    }

                                    target: fileBrowserModal
                                }

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.spacingM
                                    anchors.rightMargin: Theme.spacingM
                                    spacing: Theme.spacingM

                                    Item {
                                        width: 32
                                        height: 32
                                        anchors.verticalCenter: parent.verticalCenter

                                        CachingImage {
                                            anchors.fill: parent
                                            source: (!listDelegateRoot.fileIsDir && isImageFile(listDelegateRoot.fileName)) ? ("file://" + listDelegateRoot.filePath) : ""
                                            fillMode: Image.PreserveAspectCrop
                                            visible: !listDelegateRoot.fileIsDir && isImageFile(listDelegateRoot.fileName)
                                            maxCacheSize: 32
                                        }

                                        DankIcon {
                                            anchors.centerIn: parent
                                            name: listDelegateRoot.fileIsDir ? "folder" : "description"
                                            size: Theme.iconSize
                                            color: Theme.primary
                                            visible: listDelegateRoot.fileIsDir || !isImageFile(listDelegateRoot.fileName)
                                        }
                                    }

                                    StyledText {
                                        text: listDelegateRoot.fileName || ""
                                        font.pixelSize: Theme.fontSizeMedium
                                        color: Theme.surfaceText
                                        width: parent.width - 300
                                        elide: Text.ElideRight
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    StyledText {
                                        text: listDelegateRoot.fileIsDir ? "" : formatFileSize(listDelegateRoot.fileSize)
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceTextMedium
                                        width: 80
                                        horizontalAlignment: Text.AlignRight
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    StyledText {
                                        text: Qt.formatDateTime(listDelegateRoot.fileModified, "MMM d, yyyy h:mm AP")
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceTextMedium
                                        width: 150
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                MouseArea {
                                    id: listMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        selectedIndex = listDelegateRoot.index
                                        setSelectedFileData(listDelegateRoot.filePath, listDelegateRoot.fileName, listDelegateRoot.fileIsDir)
                                        if (listDelegateRoot.fileIsDir) {
                                            navigateTo(listDelegateRoot.filePath)
                                        } else {
                                            fileSelected(listDelegateRoot.filePath)
                                            fileBrowserModal.close()
                                        }
                                    }
                                }

                                Connections {
                                    function onKeyboardSelectionRequestedChanged() {
                                        if (fileBrowserModal.keyboardSelectionRequested && fileBrowserModal.keyboardSelectionIndex === listDelegateRoot.index) {
                                            fileBrowserModal.keyboardSelectionRequested = false
                                            selectedIndex = listDelegateRoot.index
                                            setSelectedFileData(listDelegateRoot.filePath, listDelegateRoot.fileName, listDelegateRoot.fileIsDir)
                                            if (listDelegateRoot.fileIsDir) {
                                                navigateTo(listDelegateRoot.filePath)
                                            } else {
                                                fileSelected(listDelegateRoot.filePath)
                                                fileBrowserModal.close()
                                            }
                                        }
                                    }

                                    target: fileBrowserModal
                                }
                            }
                        }
                    }
                }
            }

            Row {
                id: saveRow

                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: Theme.spacingL
                height: saveMode ? 40 : 0
                visible: saveMode
                spacing: Theme.spacingM

                DankTextField {
                    id: fileNameInput

                    width: parent.width - saveButton.width - Theme.spacingM
                    height: 40
                    text: defaultFileName
                    placeholderText: I18n.tr("Enter filename...")
                    ignoreLeftRightKeys: false
                    focus: saveMode
                    topPadding: Theme.spacingS
                    bottomPadding: Theme.spacingS
                    Component.onCompleted: {
                        if (saveMode)
                            Qt.callLater(() => {
                                             forceActiveFocus()
                                         })
                    }
                    onAccepted: {
                        if (text.trim() !== "") {
                            // Remove file:// protocol from currentPath if present for proper construction
                            var basePath = currentPath.replace(/^file:\/\//, '')
                            var fullPath = basePath + "/" + text.trim()
                            // Ensure consistent path format - remove any double slashes and normalize
                            fullPath = fullPath.replace(/\/+/g, '/')
                            handleSaveFile(fullPath)
                        }
                    }
                }

                StyledRect {
                    id: saveButton

                    width: 80
                    height: 40
                    color: fileNameInput.text.trim() !== "" ? Theme.primary : Theme.surfaceVariant
                    radius: Theme.cornerRadius

                    StyledText {
                        anchors.centerIn: parent
                        text: I18n.tr("Save")
                        color: fileNameInput.text.trim() !== "" ? Theme.primaryText : Theme.surfaceVariantText
                        font.pixelSize: Theme.fontSizeMedium
                    }

                    StateLayer {
                        stateColor: Theme.primary
                        cornerRadius: Theme.cornerRadius
                        enabled: fileNameInput.text.trim() !== ""
                        onClicked: {
                            if (fileNameInput.text.trim() !== "") {
                                // Remove file:// protocol from currentPath if present for proper construction
                                var basePath = currentPath.replace(/^file:\/\//, '')
                                var fullPath = basePath + "/" + fileNameInput.text.trim()
                                // Ensure consistent path format - remove any double slashes and normalize
                                fullPath = fullPath.replace(/\/+/g, '/')
                                handleSaveFile(fullPath)
                            }
                        }
                    }
                }
            }

            KeyboardHints {
                id: keyboardHints

                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: Theme.spacingL
                showHints: fileBrowserModal.showKeyboardHints
            }

            FileInfo {
                id: fileInfo

                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: Theme.spacingL
                width: 300
                showFileInfo: fileBrowserModal.showFileInfo
                selectedIndex: fileBrowserModal.selectedIndex
                sourceFolderModel: folderModel
                currentPath: fileBrowserModal.currentPath
                currentFileName: fileBrowserModal.selectedFileName
                currentFileIsDir: fileBrowserModal.selectedFileIsDir
                currentFileExtension: {
                    if (fileBrowserModal.selectedFileIsDir || !fileBrowserModal.selectedFileName)
                        return ""

                    var lastDot = fileBrowserModal.selectedFileName.lastIndexOf('.')
                    return lastDot > 0 ? fileBrowserModal.selectedFileName.substring(lastDot + 1).toLowerCase() : ""
                }
            }

            StyledRect {
                id: sortMenu
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: 120
                anchors.rightMargin: Theme.spacingL
                width: 200
                height: sortColumn.height + Theme.spacingM * 2
                color: Theme.surfaceContainer
                radius: Theme.cornerRadius
                border.color: Theme.outlineMedium
                border.width: 1
                visible: false
                z: 100

                Column {
                    id: sortColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.spacingM
                    spacing: Theme.spacingXS

                    StyledText {
                        text: "Sort By"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceTextMedium
                        font.weight: Font.Medium
                    }

                    Repeater {
                        model: [{
                                "name": "Name",
                                "value": "name"
                            }, {
                                "name": "Size",
                                "value": "size"
                            }, {
                                "name": "Modified",
                                "value": "modified"
                            }, {
                                "name": "Type",
                                "value": "type"
                            }]

                        StyledRect {
                            width: sortColumn.width
                            height: 32
                            radius: Theme.cornerRadiusSmall
                            color: sortMouseArea.containsMouse ? Theme.surfaceVariant : (sortBy === modelData.value ? Theme.surfacePressed : "transparent")

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: Theme.spacingS
                                spacing: Theme.spacingS

                                DankIcon {
                                    name: sortBy === modelData.value ? "check" : ""
                                    size: Theme.iconSizeSmall
                                    color: Theme.primary
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: sortBy === modelData.value
                                }

                                StyledText {
                                    text: modelData.name
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: sortBy === modelData.value ? Theme.primary : Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: sortMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    sortBy = modelData.value
                                    sortMenu.visible = false
                                }
                            }
                        }
                    }

                    StyledRect {
                        width: sortColumn.width
                        height: 1
                        color: Theme.outline
                    }

                    StyledText {
                        text: "Order"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceTextMedium
                        font.weight: Font.Medium
                        topPadding: Theme.spacingXS
                    }

                    StyledRect {
                        width: sortColumn.width
                        height: 32
                        radius: Theme.cornerRadiusSmall
                        color: ascMouseArea.containsMouse ? Theme.surfaceVariant : (sortAscending ? Theme.surfacePressed : "transparent")

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.spacingS
                            spacing: Theme.spacingS

                            DankIcon {
                                name: "arrow_upward"
                                size: Theme.iconSizeSmall
                                color: sortAscending ? Theme.primary : Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: "Ascending"
                                font.pixelSize: Theme.fontSizeMedium
                                color: sortAscending ? Theme.primary : Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: ascMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                sortAscending = true
                                sortMenu.visible = false
                            }
                        }
                    }

                    StyledRect {
                        width: sortColumn.width
                        height: 32
                        radius: Theme.cornerRadiusSmall
                        color: descMouseArea.containsMouse ? Theme.surfaceVariant : (!sortAscending ? Theme.surfacePressed : "transparent")

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.spacingS
                            spacing: Theme.spacingS

                            DankIcon {
                                name: "arrow_downward"
                                size: Theme.iconSizeSmall
                                color: !sortAscending ? Theme.primary : Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: "Descending"
                                font.pixelSize: Theme.fontSizeMedium
                                color: !sortAscending ? Theme.primary : Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: descMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                sortAscending = false
                                sortMenu.visible = false
                            }
                        }
                    }
                }
            }

            // Overwrite confirmation dialog
            Item {
                id: overwriteDialog
                anchors.fill: parent
                visible: showOverwriteConfirmation

                Keys.onEscapePressed: {
                    showOverwriteConfirmation = false
                    pendingFilePath = ""
                }

                Keys.onReturnPressed: {
                    showOverwriteConfirmation = false
                    fileSelected(pendingFilePath)
                    pendingFilePath = ""
                    Qt.callLater(() => fileBrowserModal.close())
                }

                focus: showOverwriteConfirmation

                Rectangle {
                    anchors.fill: parent
                    color: Theme.shadowStrong
                    opacity: 0.8

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            showOverwriteConfirmation = false
                            pendingFilePath = ""
                        }
                    }
                }

                StyledRect {
                    anchors.centerIn: parent
                    width: 400
                    height: 160
                    color: Theme.surfaceContainer
                    radius: Theme.cornerRadius
                    border.color: Theme.outlineMedium
                    border.width: 1

                    Column {
                        anchors.centerIn: parent
                        width: parent.width - Theme.spacingL * 2
                        spacing: Theme.spacingM

                        StyledText {
                            text: I18n.tr("File Already Exists")
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        StyledText {
                            text: I18n.tr("A file with this name already exists. Do you want to overwrite it?")
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceTextMedium
                            width: parent.width
                            wrapMode: Text.WordWrap
                            horizontalAlignment: Text.AlignHCenter
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: Theme.spacingM

                            StyledRect {
                                width: 80
                                height: 36
                                radius: Theme.cornerRadius
                                color: cancelArea.containsMouse ? Theme.surfaceVariantHover : Theme.surfaceVariant
                                border.color: Theme.outline
                                border.width: 1

                                StyledText {
                                    anchors.centerIn: parent
                                    text: I18n.tr("Cancel")
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: Theme.surfaceText
                                    font.weight: Font.Medium
                                }

                                MouseArea {
                                    id: cancelArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        showOverwriteConfirmation = false
                                        pendingFilePath = ""
                                    }
                                }
                            }

                            StyledRect {
                                width: 90
                                height: 36
                                radius: Theme.cornerRadius
                                color: overwriteArea.containsMouse ? Qt.darker(Theme.primary, 1.1) : Theme.primary

                                StyledText {
                                    anchors.centerIn: parent
                                    text: I18n.tr("Overwrite")
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: Theme.background
                                    font.weight: Font.Medium
                                }

                                MouseArea {
                                    id: overwriteArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        showOverwriteConfirmation = false
                                        fileSelected(pendingFilePath)
                                        pendingFilePath = ""
                                        Qt.callLater(() => fileBrowserModal.close())
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
