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

PanelWindow {
    id: root

    property bool notepadVisible: false
    property bool shouldBeVisible: false
    property bool fileDialogOpen: false
    property string currentFileName: ""
    property bool hasUnsavedChanges: false
    property url currentFileUrl
    property var targetScreen: null
    property var modelData: null
    property bool animatingOut: false
    property bool confirmationDialogOpen: false
    property string pendingAction: ""
    property string lastSavedFileContent: ""
    property bool expandedWidth: false
    
    function hasFileChanges() {
        if (!root.currentFileUrl.toString()) {
            return root.hasUnsavedChanges || SessionData.notepadContent.length > 0
        }
        return SessionData.notepadContent !== root.lastSavedFileContent
    }

    function show() {
        shouldBeVisible = true
        visible = true
        Qt.callLater(() => {
            notepadVisible = true
            textArea.forceActiveFocus()
        })
    }

    function hide() {
        animatingOut = true
        shouldBeVisible = false
        notepadVisible = false
        hideTimer.start()
    }

    function toggle() {
        if (shouldBeVisible) {
            hide()
        } else {
            show()
        }
    }

    visible: shouldBeVisible || animatingOut
    screen: modelData
    
    anchors.top: true
    anchors.bottom: true
    anchors.right: true
    
    implicitWidth: 960
    implicitHeight: modelData ? modelData.height : 800
    
    color: "transparent"
    
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.exclusiveZone: 0
    WlrLayershell.keyboardFocus: (notepadVisible && !animatingOut) ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    

    // Background click to close
    MouseArea {
        anchors.fill: parent
        enabled: notepadVisible && !animatingOut
        onClicked: mouse => {
            var localPos = mapToItem(contentRect, mouse.x, mouse.y)
            if (localPos.x < 0 || localPos.x > contentRect.width || localPos.y < 0 || localPos.y > contentRect.height) {
                hide()
            }
        }
    }

    StyledRect {
        id: contentRect
        
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        width: expandedWidth ? 960 : 480
        color: Theme.surfaceContainer
        border.color: Theme.outlineMedium
        border.width: 1
        
        transform: Translate {
            x: shouldBeVisible ? 0 : width
            
            Behavior on x {
                NumberAnimation {
                    duration: Theme.longDuration
                    easing.type: Theme.emphasizedEasing
                }
            }
        }
        
        
        Behavior on width {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }

        Column {
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            // Header
            Row {
                width: parent.width
                height: 40

                Column {
                    width: parent.width - buttonRow.width
                    spacing: Theme.spacingXS
                    anchors.verticalCenter: parent.verticalCenter
                    
                    StyledText {
                        text: qsTr("Notepad")
                        font.pixelSize: Theme.fontSizeLarge
                        color: Theme.surfaceText
                        font.weight: Font.Medium
                    }
                    
                    StyledText {
                        text: (hasFileChanges() ? "● " : "") + (root.currentFileName || qsTr("Untitled"))
                        font.pixelSize: Theme.fontSizeSmall
                        color: hasFileChanges() ? Theme.primary : Theme.surfaceTextMedium
                        visible: root.currentFileName !== "" || hasFileChanges()
                        elide: Text.ElideMiddle
                        maximumLineCount: 1
                        width: parent.width - Theme.spacingM
                    }
                }

                Row {
                    id: buttonRow
                    spacing: Theme.spacingXS
                    
                    DankActionButton {
                        id: expandButton
                        iconName: root.expandedWidth ? "unfold_less" : "unfold_more"
                        iconSize: Theme.iconSize - 4
                        iconColor: Theme.surfaceText
                        onClicked: root.expandedWidth = !root.expandedWidth
                        
                        transform: Rotation {
                            angle: 90
                            origin.x: expandButton.width / 2
                            origin.y: expandButton.height / 2
                        }
                    }
                    
                    DankActionButton {
                        id: closeButton
                        iconName: "close"
                        iconSize: Theme.iconSize - 4
                        iconColor: Theme.surfaceText
                        onClicked: root.hide()
                    }
                }
            }

            // Text area
            StyledRect {
                width: parent.width
                height: parent.height - 140
                color: Theme.surface
                border.color: Theme.outlineMedium
                border.width: 1
                radius: Theme.cornerRadius

                ScrollView {
                    anchors.fill: parent
                    anchors.margins: 1
                    clip: true

                    TextArea {
                        id: textArea
                        placeholderText: qsTr("Start typing your notes here...")
                        font.family: SettingsData.monoFontFamily
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceText
                        selectByMouse: true
                        selectByKeyboard: true
                        wrapMode: TextArea.Wrap
                        focus: root.notepadVisible
                        activeFocusOnTab: true
                        textFormat: TextEdit.PlainText
                        persistentSelection: true
                        tabStopDistance: 40
                        leftPadding: Theme.spacingM
                        topPadding: Theme.spacingM
                        rightPadding: Theme.spacingM
                        bottomPadding: Theme.spacingM
                        
                        Component.onCompleted: {
                            text = SessionData.notepadContent
                            root.currentFileName = SessionData.notepadCurrentFileName
                            root.currentFileUrl = SessionData.notepadCurrentFileUrl
                            root.lastSavedFileContent = SessionData.notepadLastSavedContent
                        }
                        
                        Connections {
                            target: SessionData
                            function onNotepadContentChanged() {
                                if (textArea.text !== SessionData.notepadContent) {
                                    textArea.text = SessionData.notepadContent
                                }
                            }
                        }
                        
                        onTextChanged: {
                            if (text !== SessionData.notepadContent) {
                                SessionData.notepadContent = text
                                root.hasUnsavedChanges = true
                                saveTimer.restart()
                            }
                        }
                        
                        Keys.onEscapePressed: (event) => {
                            root.hide()
                            event.accepted = true
                        }
                        
                        Keys.onPressed: (event) => {
                            if (event.modifiers & Qt.ControlModifier) {
                                switch (event.key) {
                                case Qt.Key_S:
                                    event.accepted = true
                                    if (root.currentFileUrl.toString()) {
                                        saveToFile(root.currentFileUrl)
                                    } else {
                                        root.fileDialogOpen = true
                                        saveBrowser.open()
                                    }
                                    break
                                case Qt.Key_O:
                                    event.accepted = true
                                    if (hasFileChanges()) {
                                        root.pendingAction = "open"
                                        root.confirmationDialogOpen = true
                                        confirmationDialog.open()
                                    } else {
                                        root.fileDialogOpen = true
                                        loadBrowser.open()
                                    }
                                    break
                                case Qt.Key_N:
                                    event.accepted = true
                                    if (hasFileChanges()) {
                                        root.pendingAction = "new"
                                        root.confirmationDialogOpen = true
                                        confirmationDialog.open()
                                    } else {
                                        textArea.text = ""
                                        SessionData.notepadContent = ""
                                        root.currentFileName = ""
                                        root.currentFileUrl = ""
                                        root.hasUnsavedChanges = false
                                        root.lastSavedFileContent = ""
                                        SessionData.notepadCurrentFileName = ""
                                        SessionData.notepadCurrentFileUrl = ""
                                        SessionData.notepadLastSavedContent = ""
                                        SessionData.saveSettings()
                                    }
                                    break
                                case Qt.Key_A:
                                    event.accepted = true
                                    selectAll()
                                    break
                                }
                            }
                        }

                        background: Rectangle {
                            color: "transparent"
                        }
                    }
                }
            }

            // Bottom controls
            Column {
                width: parent.width
                spacing: Theme.spacingS

                Row {
                    width: parent.width
                    spacing: Theme.spacingL

                    Row {
                        spacing: Theme.spacingS
                        DankActionButton {
                            iconName: "save"
                            iconSize: Theme.iconSize - 2
                            iconColor: Theme.primary
                            enabled: hasFileChanges() || SessionData.notepadContent.length > 0
                            onClicked: {
                                root.fileDialogOpen = true
                                saveBrowser.open()
                            }
                        }
                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("Save")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceTextMedium
                        }
                    }

                    Row {
                        spacing: Theme.spacingS
                        DankActionButton {
                            iconName: "folder_open"
                            iconSize: Theme.iconSize - 2
                            iconColor: Theme.secondary
                            onClicked: {
                                if (hasFileChanges()) {
                                    root.pendingAction = "open"
                                    root.confirmationDialogOpen = true
                                    confirmationDialog.open()
                                } else {
                                    root.fileDialogOpen = true
                                    loadBrowser.open()
                                }
                            }
                        }
                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("Open")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceTextMedium
                        }
                    }

                    Row {
                        spacing: Theme.spacingS
                        DankActionButton {
                            iconName: "note_add"
                            iconSize: Theme.iconSize - 2
                            iconColor: Theme.surfaceText
                            onClicked: {
                                if (hasFileChanges()) {
                                    root.pendingAction = "new"
                                    root.confirmationDialogOpen = true
                                    confirmationDialog.open()
                                } else {
                                    textArea.text = ""
                                    SessionData.notepadContent = ""
                                    root.currentFileName = ""
                                    root.currentFileUrl = ""
                                    root.hasUnsavedChanges = false
                                    root.lastSavedFileContent = ""
                                    SessionData.notepadCurrentFileName = ""
                                    SessionData.notepadCurrentFileUrl = ""
                                    SessionData.notepadLastSavedContent = ""
                                    SessionData.saveSettings()
                                }
                            }
                        }
                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("New")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceTextMedium
                        }
                    }
                }

                Row {
                    width: parent.width
                    spacing: Theme.spacingL

                    StyledText {
                        text: SessionData.notepadContent.length > 0 ? qsTr("%1 characters").arg(SessionData.notepadContent.length) : qsTr("Empty")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceTextMedium
                    }
                    
                    StyledText {
                        text: qsTr("Lines: %1").arg(textArea.lineCount)
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceTextMedium
                        visible: SessionData.notepadContent.length > 0
                    }

                    StyledText {
                        text: saveTimer.running ? qsTr("Auto-saving...") : (hasFileChanges() ? qsTr("Unsaved changes") : qsTr("Auto-saved"))
                        font.pixelSize: Theme.fontSizeSmall
                        color: hasFileChanges() ? Theme.warning : (saveTimer.running ? Theme.primary : Theme.surfaceTextMedium)
                        opacity: SessionData.notepadContent.length > 0 ? 1 : 0
                    }
                }
            }
        }
    }

    Timer {
        id: saveTimer
        interval: 1000
        repeat: false
        onTriggered: {
            SessionData.saveSettings()
            root.hasUnsavedChanges = false
        }
    }

    Timer {
        id: hideTimer
        interval: Theme.longDuration + 50
        repeat: false
        onTriggered: {
            visible = false
            animatingOut = false
        }
    }

    // File save/load functionality
    function saveToFile(fileUrl) {
        const content = SessionData.notepadContent
        const cleanPath = fileUrl.toString().replace(/^file:\/\//, '')
        const escapedContent = content.replace(/'/g, "'\\''")
        saveProcess.command = ["sh", "-c", "printf '%s' '" + escapedContent + "' > '" + cleanPath + "'"]
        saveProcess.running = true
    }
    
    function loadFromFile(fileUrl) {
        const cleanPath = fileUrl.toString().replace(/^file:\/\//, '')
        
        loadProcess.command = ["cat", cleanPath]
        loadProcess.running = true
    }

    Process {
        id: saveProcess
        
        onExited: (exitCode) => {
            if (exitCode === 0) {
                root.hasUnsavedChanges = false
                root.lastSavedFileContent = SessionData.notepadContent
                SessionData.notepadCurrentFileName = root.currentFileName
                SessionData.notepadCurrentFileUrl = root.currentFileUrl.toString()
                SessionData.notepadLastSavedContent = root.lastSavedFileContent
                SessionData.saveSettings()
            } else {
                console.warn("Notepad: Failed to save file, exit code:", exitCode)
            }
        }
    }

    Process {
        id: loadProcess
        
        stdout: StdioCollector {
            onStreamFinished: {
                SessionData.notepadContent = text
                root.hasUnsavedChanges = false
                root.lastSavedFileContent = text
                SessionData.notepadCurrentFileName = root.currentFileName
                SessionData.notepadCurrentFileUrl = root.currentFileUrl.toString()
                SessionData.notepadLastSavedContent = text
                SessionData.saveSettings()
            }
        }
        
        onExited: (exitCode) => {
            if (exitCode !== 0) {
                console.warn("Notepad: Failed to load file, exit code:", exitCode)
            }
        }
    }

    FileBrowserModal {
        id: saveBrowser

        browserTitle: qsTr("Save Notepad File")
        browserIcon: "save"
        browserType: "notepad_save"
        fileExtensions: ["*.txt", "*.md", "*.*"]
        allowStacking: true
        saveMode: true
        defaultFileName: root.currentFileName || "note.txt"
        
        WlrLayershell.layer: WlrLayershell.Overlay
        
        onFileSelected: (path) => {
            root.fileDialogOpen = false
            const cleanPath = path.toString().replace(/^file:\/\//, '')
            const fileName = cleanPath.split('/').pop()
            const fileUrl = "file://" + cleanPath
            
            root.currentFileName = fileName
            root.currentFileUrl = fileUrl
            
            saveToFile(fileUrl)
            
            // Handle pending action after save
            if (root.pendingAction === "new") {
                Qt.callLater(() => {
                    textArea.text = ""
                    SessionData.notepadContent = ""
                    root.currentFileName = ""
                    root.currentFileUrl = ""
                    root.hasUnsavedChanges = false
                    root.lastSavedFileContent = ""
                    SessionData.notepadCurrentFileName = ""
                    SessionData.notepadCurrentFileUrl = ""
                    SessionData.notepadLastSavedContent = ""
                    SessionData.saveSettings()
                })
            } else if (root.pendingAction === "open") {
                Qt.callLater(() => {
                    root.fileDialogOpen = true
                    loadBrowser.open()
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

        browserTitle: qsTr("Open Notepad File")
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
                                text: qsTr("Unsaved Changes")
                                font.pixelSize: Theme.fontSizeLarge
                                color: Theme.surfaceText
                                font.weight: Font.Medium
                            }

                            StyledText {
                                text: root.pendingAction === "new" ? 
                                      qsTr("You have unsaved changes. Save before creating a new file?") :
                                      qsTr("You have unsaved changes. Save before opening a file?")
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
                                    text: qsTr("Don't Save")
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
                                            textArea.text = ""
                                            SessionData.notepadContent = ""
                                            root.currentFileName = ""
                                            root.currentFileUrl = ""
                                            root.hasUnsavedChanges = false
                                            root.lastSavedFileContent = ""
                                            SessionData.notepadCurrentFileName = ""
                                            SessionData.notepadCurrentFileUrl = ""
                                            SessionData.notepadLastSavedContent = ""
                                            SessionData.saveSettings()
                                        } else if (root.pendingAction === "open") {
                                            root.fileDialogOpen = true
                                            loadBrowser.open()
                                        }
                                        root.pendingAction = ""
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
                                    text: qsTr("Save")
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