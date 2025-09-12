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

    signal fileSelected(string path)

    function isImageFile(fileName) {
        if (!fileName) {
            return false
        }
        const ext = fileName.toLowerCase().split('.').pop()
        return ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg'].includes(ext)
    }

    function getLastPath() {
        const lastPath = browserType === "wallpaper" ? SessionData.wallpaperLastPath : browserType === "profile" ? SessionData.profileLastPath : ""
        return (lastPath && lastPath !== "") ? lastPath : homeDir
    }

    function saveLastPath(path) {
        if (browserType === "wallpaper") {
            SessionData.setWallpaperLastPath(path)
        } else if (browserType === "profile") {
            SessionData.setProfileLastPath(path)
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

    function handleSaveFile(filePath) {
        // Ensure the filePath has the correct file:// protocol format
        var normalizedPath = filePath
        if (!normalizedPath.startsWith("file://")) {
            normalizedPath = "file://" + filePath
        }
        
        // Check if file exists by looking through the folder model
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
    Component.onCompleted: {
        currentPath = getLastPath()
    }
    width: 800
    height: 600
    enableShadow: true
    visible: false
    onBackgroundClicked: close()
    onOpened: {
        modalFocusScope.forceActiveFocus()
    }
    modalFocusScope.Keys.onPressed: function (event) {
        keyboardController.handleKey(event)
    }
    onVisibleChanged: {
        if (visible) {
            currentPath = getLastPath()
            selectedIndex = -1
            keyboardNavigationActive = false
            backButtonFocused = false
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
    }

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
                if (event.key === Qt.Key_Tab || event.key === Qt.Key_Down || event.key === Qt.Key_Right) {
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

    content: Component {
        Item {
            anchors.fill: parent

            Column {
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingS

                Item {
                    width: parent.width
                    height: 40

                    Row {
                        spacing: Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter

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
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingS

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

                Row {
                    width: parent.width
                    spacing: Theme.spacingS

                    StyledRect {
                        width: 32
                        height: 32
                        radius: Theme.cornerRadius
                        color: (backButtonMouseArea.containsMouse || (backButtonFocused && keyboardNavigationActive)) && currentPath !== homeDir ? Theme.surfaceVariant : "transparent"
                        opacity: currentPath !== homeDir ? 1 : 0

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

                    StyledText {
                        text: fileBrowserModal.currentPath.replace("file://", "")
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceText
                        font.weight: Font.Medium
                        width: parent.width - 40 - Theme.spacingS
                        elide: Text.ElideMiddle
                        anchors.verticalCenter: parent.verticalCenter
                        maximumLineCount: 1
                        wrapMode: Text.NoWrap
                    }
                }

                DankGridView {
                    id: fileGrid

                    width: parent.width
                    height: parent.height - 80
                    clip: true
                    cellWidth: fileBrowserModal.browserType === "we" ? 255 : 150
                    cellHeight: fileBrowserModal.browserType === "we" ? 215 : 130
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
                        required property url fileURL
                        required property int index

                        width: fileBrowserModal.browserType === "we" ? 245 : 140
                        height: fileBrowserModal.browserType === "we" ? 205 : 120
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
                                width: fileBrowserModal.browserType === "we" ? 225 : 80
                                height: fileBrowserModal.browserType === "we" ? 165 : 60
                                anchors.horizontalCenter: parent.horizontalCenter

                                CachingImage {
                                    anchors.fill: parent
                                    property var weExtensions: [".jpg", ".png", ".webp", ".gif", ".jpeg"]
                                    property int weExtIndex: 0
                                    source: {
                                        if (fileBrowserModal.browserType === "we" && delegateRoot.fileIsDir) {
                                            return "file://" + delegateRoot.filePath + "/preview" + weExtensions[weExtIndex]
                                        }
                                        return (!delegateRoot.fileIsDir && isImageFile(delegateRoot.fileName)) ? ("file://" + delegateRoot.filePath) : ""
                                    }
                                    onStatusChanged: {
                                        if (fileBrowserModal.browserType === "we" && delegateRoot.fileIsDir && status === Image.Error) {
                                            if (weExtIndex < weExtensions.length - 1) {
                                                weExtIndex++
                                                source = "file://" + delegateRoot.filePath + "/preview" + weExtensions[weExtIndex]
                                            }
                                        }
                                    }
                                    fillMode: Image.PreserveAspectCrop
                                    visible: (!delegateRoot.fileIsDir && isImageFile(delegateRoot.fileName)) || (fileBrowserModal.browserType === "we" && delegateRoot.fileIsDir)
                                    maxCacheSize: fileBrowserModal.browserType === "we" ? 225 : 80
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
                                    visible: delegateRoot.fileIsDir && fileBrowserModal.browserType !== "we"
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
                                if (fileBrowserModal.browserType === "we" && delegateRoot.fileIsDir) {
                                    // Select this folder instead of navigating inside
                                    fileSelected(delegateRoot.filePath)
                                    fileBrowserModal.close()
                                } if (delegateRoot.fileIsDir) {
                                    navigateTo(delegateRoot.filePath)
                                } else {
                                    fileSelected(delegateRoot.filePath)
                                    fileBrowserModal.close() // Close modal after file selection
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
                                    if (delegateRoot.fileIsDir) {
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
                    placeholderText: "Enter filename..."
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
                        text: "Save"
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
                            text: qsTr("File Already Exists")
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        
                        StyledText {
                            text: qsTr("A file with this name already exists. Do you want to overwrite it?")
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
                                    text: qsTr("Cancel")
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
                                    text: qsTr("Overwrite")
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
