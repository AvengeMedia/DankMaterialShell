import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Io
import "../Common"

PanelWindow {
    id: clipboardHistory
    
    property var theme
    property bool isVisible: false
    
    // Default theme fallback
    property var defaultTheme: QtObject {
        property color primary: "#D0BCFF"
        property color background: "#10121E"
        property color surfaceContainer: "#1D1B20"
        property color surfaceText: "#E6E0E9"
        property color surfaceVariant: "#49454F"
        property color surfaceVariantText: "#CAC4D0"
        property color outline: "#938F99"
        property color error: "#F2B8B5"
        property real cornerRadius: 12
        property real cornerRadiusLarge: 16
        property real cornerRadiusXLarge: 24
        property real cornerRadiusSmall: 8
        property real spacingXS: 4
        property real spacingS: 8
        property real spacingM: 12
        property real spacingL: 16
        property real spacingXL: 24
        property real fontSizeLarge: 16
        property real fontSizeMedium: 14
        property real fontSizeSmall: 12
        property real iconSize: 24
        property real iconSizeLarge: 32
        property string iconFont: "Material Symbols Rounded"
        property int iconFontWeight: Font.Normal
        property int shortDuration: 150
        property int mediumDuration: 300
        property int standardEasing: Easing.OutCubic
        property int emphasizedEasing: Easing.OutQuart
    }
    
    property var activeTheme: theme || defaultTheme
    
    // Window properties
    color: "transparent"
    visible: isVisible
    
    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }
    
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: isVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    
    // Clipboard entries model
    property var clipboardEntries: []
    
    ListModel {
        id: clipboardModel
    }
    
    ListModel {
        id: filteredClipboardModel
    }
    
    function updateFilteredModel() {
        filteredClipboardModel.clear()
        for (let i = 0; i < clipboardModel.count; i++) {
            const entry = clipboardModel.get(i).entry
            if (searchField.text.trim().length === 0) {
                filteredClipboardModel.append({"entry": entry})
            } else {
                const content = getEntryPreview(entry).toLowerCase()
                if (content.includes(searchField.text.toLowerCase())) {
                    filteredClipboardModel.append({"entry": entry})
                }
            }
        }
    }
    
    function toggle() {
        if (isVisible) {
            hide()
        } else {
            show()
        }
    }
    
    function show() {
        clipboardHistory.isVisible = true
        searchField.focus = true
        refreshClipboard()
        console.log("ClipboardHistory: Opening and refreshing")
    }
    
    function hide() {
        clipboardHistory.isVisible = false
        searchField.focus = false
        searchField.text = ""
    }
    
    function refreshClipboard() {
        clipboardProcess.running = true
    }
    
    function copyEntry(entry) {
        const entryId = entry.split('\t')[0]
        copyProcess.command = ["sh", "-c", `cliphist decode ${entryId} | wl-copy`]
        copyProcess.running = true
        hide()
    }
    
    function deleteEntry(entry) {
        const entryId = entry.split('\t')[0]
        deleteProcess.command = ["cliphist", "delete-query", entryId]
        deleteProcess.running = true
    }
    
    function clearAll() {
        clearProcess.running = true
    }
    
    function getEntryPreview(entry) {
        // Remove cliphist ID prefix and clean up content
        let content = entry.replace(/^\s*\d+\s+/, "")
        
        // Handle different content types
        if (content.includes("image/")) {
            const match = content.match(/(\d+)x(\d+)/)
            return match ? `Image ${match[1]}×${match[2]}` : "Image"
        }
        
        // Truncate long text
        if (content.length > 100) {
            return content.substring(0, 100) + "..."
        }
        
        return content
    }
    
    function getEntryType(entry) {
        if (entry.includes("image/")) return "image"
        if (entry.length > 200) return "long_text"
        return "text"
    }
    
    // Background overlay
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.5)
        opacity: clipboardHistory.isVisible ? 1.0 : 0.0
        visible: clipboardHistory.isVisible
        
        Behavior on opacity {
            NumberAnimation {
                duration: activeTheme.mediumDuration
                easing.type: activeTheme.emphasizedEasing
            }
        }
        
        MouseArea {
            anchors.fill: parent
            enabled: clipboardHistory.isVisible
            onClicked: clipboardHistory.hide()
        }
    }
    
    // Main clipboard container
    Rectangle {
        id: clipboardContainer
        width: Math.min(600, parent.width - 200)
        height: Math.min(500, parent.height - 100)
        anchors.centerIn: parent
        
        color: activeTheme.surfaceContainer
        radius: activeTheme.cornerRadiusXLarge
        border.color: Qt.rgba(activeTheme.outline.r, activeTheme.outline.g, activeTheme.outline.b, 0.2)
        border.width: 1
        
        opacity: clipboardHistory.isVisible ? 1.0 : 0.0
        scale: clipboardHistory.isVisible ? 1.0 : 0.9
        
        Behavior on opacity {
            NumberAnimation {
                duration: activeTheme.mediumDuration
                easing.type: activeTheme.emphasizedEasing
            }
        }
        
        Behavior on scale {
            NumberAnimation {
                duration: activeTheme.mediumDuration
                easing.type: activeTheme.emphasizedEasing
            }
        }
        
        // Header section
        Column {
            id: headerSection
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: activeTheme.spacingXL
            spacing: activeTheme.spacingL
            
            // Title and actions
            Row {
                width: parent.width
                height: 40
                
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Clipboard History"
                    font.pixelSize: activeTheme.fontSizeLarge + 4
                    font.weight: Font.Bold
                    color: activeTheme.surfaceText
                }
                
                Item { 
                    width: parent.width - 180 - (clearAllButton.visible ? 48 : 0)
                    height: 1 
                }
                
                // Clear all button
                Rectangle {
                    id: clearAllButton
                    width: 40
                    height: 32
                    radius: activeTheme.cornerRadius
                    color: clearArea.containsMouse ? Qt.rgba(activeTheme.error.r, activeTheme.error.g, activeTheme.error.b, 0.12) : "transparent"
                    anchors.verticalCenter: parent.verticalCenter
                    visible: clipboardModel.count > 0
                    
                    Text {
                        anchors.centerIn: parent
                        text: "delete_sweep"
                        font.family: activeTheme.iconFont
                        font.pixelSize: activeTheme.iconSize
                        color: clearArea.containsMouse ? activeTheme.error : activeTheme.surfaceText
                    }
                    
                    MouseArea {
                        id: clearArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: clearAll()
                    }
                    
                    Behavior on color {
                        ColorAnimation { duration: activeTheme.shortDuration }
                    }
                }
                
                // Close button  
                Rectangle {
                    width: 40
                    height: 32
                    radius: activeTheme.cornerRadius
                    color: closeArea.containsMouse ? Qt.rgba(activeTheme.error.r, activeTheme.error.g, activeTheme.error.b, 0.12) : "transparent"
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.rightMargin: 4
                    
                    Text {
                        anchors.centerIn: parent
                        text: "close"
                        font.family: activeTheme.iconFont
                        font.pixelSize: activeTheme.iconSize
                        color: closeArea.containsMouse ? activeTheme.error : activeTheme.surfaceText
                    }
                    
                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: clipboardHistory.hide()
                    }
                    
                    Behavior on color {
                        ColorAnimation { duration: activeTheme.shortDuration }
                    }
                }
            }
            
            // Search field
            Rectangle {
                width: parent.width
                height: 48
                radius: activeTheme.cornerRadiusLarge
                color: Qt.rgba(activeTheme.surfaceVariant.r, activeTheme.surfaceVariant.g, activeTheme.surfaceVariant.b, 0.3)
                border.color: searchField.focus ? activeTheme.primary : Qt.rgba(activeTheme.outline.r, activeTheme.outline.g, activeTheme.outline.b, 0.2)
                border.width: searchField.focus ? 2 : 1
                
                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: activeTheme.spacingL
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: activeTheme.spacingM
                    
                    Text {
                        text: "search"
                        font.family: activeTheme.iconFont
                        font.pixelSize: activeTheme.iconSize
                        color: searchField.focus ? activeTheme.primary : Qt.rgba(activeTheme.surfaceText.r, activeTheme.surfaceText.g, activeTheme.surfaceText.b, 0.6)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    
                    TextInput {
                        id: searchField
                        width: parent.parent.width - 80
                        height: parent.parent.height
                        font.pixelSize: activeTheme.fontSizeLarge
                        color: activeTheme.surfaceText
                        verticalAlignment: TextInput.AlignVCenter
                        
                        onTextChanged: updateFilteredModel()
                        
                        Keys.onPressed: (event) => {
                            if (event.key === Qt.Key_Escape) {
                                clipboardHistory.hide()
                            }
                        }
                        
                        // Placeholder text
                        Text {
                            text: "Search clipboard entries..."
                            font: searchField.font
                            color: Qt.rgba(activeTheme.surfaceText.r, activeTheme.surfaceText.g, activeTheme.surfaceText.b, 0.6)
                            anchors.verticalCenter: parent.verticalCenter
                            visible: searchField.text.length === 0 && !searchField.focus
                        }
                    }
                }
                
                Behavior on border.color {
                    ColorAnimation { duration: activeTheme.shortDuration }
                }
            }
        }
        
        // Clipboard entries
        Rectangle {
            anchors.top: headerSection.bottom
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: activeTheme.spacingXL
            anchors.topMargin: activeTheme.spacingL
            
            color: "transparent"
            
            ScrollView {
                anchors.fill: parent
                clip: true
                
                ListView {
                    id: clipboardList
                    model: filteredClipboardModel
                    spacing: activeTheme.spacingS
                    
                    delegate: Rectangle {
                        width: clipboardList.width
                        height: Math.max(60, contentColumn.implicitHeight + activeTheme.spacingM * 2)
                        radius: activeTheme.cornerRadius
                        color: entryArea.containsMouse ? Qt.rgba(activeTheme.primary.r, activeTheme.primary.g, activeTheme.primary.b, 0.08) : 
                               Qt.rgba(activeTheme.surfaceVariant.r, activeTheme.surfaceVariant.g, activeTheme.surfaceVariant.b, 0.05)
                        border.color: Qt.rgba(activeTheme.outline.r, activeTheme.outline.g, activeTheme.outline.b, 0.1)
                        border.width: 1
                        
                        property string entryType: getEntryType(model.entry)
                        property string entryPreview: getEntryPreview(model.entry)
                        
                        Row {
                            anchors.fill: parent
                            anchors.margins: activeTheme.spacingM
                            spacing: activeTheme.spacingL
                            
                            // Entry type icon
                            Rectangle {
                                width: 36
                                height: 36
                                radius: activeTheme.cornerRadius
                                color: Qt.rgba(activeTheme.primary.r, activeTheme.primary.g, activeTheme.primary.b, 0.12)
                                anchors.verticalCenter: parent.verticalCenter
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: {
                                        switch (entryType) {
                                            case "image": return "image"
                                            case "long_text": return "subject"
                                            default: return "content_paste"
                                        }
                                    }
                                    font.family: activeTheme.iconFont
                                    font.pixelSize: activeTheme.iconSize - 4
                                    color: activeTheme.primary
                                }
                            }
                            
                            // Entry content
                            Column {
                                id: contentColumn
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 100
                                spacing: activeTheme.spacingXS
                                
                                Text {
                                    text: {
                                        switch (entryType) {
                                            case "image": return "Image • " + entryPreview
                                            case "long_text": return "Long Text"
                                            default: return "Text"
                                        }
                                    }
                                    font.pixelSize: activeTheme.fontSizeSmall
                                    color: activeTheme.primary
                                    font.weight: Font.Medium
                                    width: parent.width
                                    elide: Text.ElideRight
                                }
                                
                                Text {
                                    text: entryPreview
                                    font.pixelSize: activeTheme.fontSizeMedium
                                    color: activeTheme.surfaceText
                                    width: parent.width
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: entryType === "long_text" ? 3 : 2
                                    elide: Text.ElideRight
                                    visible: entryType !== "image"
                                }
                            }
                            
                            // Actions
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: activeTheme.spacingXS
                                
                                // Copy button
                                Rectangle {
                                    width: 28
                                    height: 28
                                    radius: activeTheme.cornerRadiusSmall
                                    color: copyArea.containsMouse ? Qt.rgba(activeTheme.primary.r, activeTheme.primary.g, activeTheme.primary.b, 0.12) : "transparent"
                                    
                                    Text {
                                        anchors.centerIn: parent
                                        text: "content_copy"
                                        font.family: activeTheme.iconFont
                                        font.pixelSize: activeTheme.iconSize - 8
                                        color: copyArea.containsMouse ? activeTheme.primary : activeTheme.surfaceText
                                    }
                                    
                                    MouseArea {
                                        id: copyArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: copyEntry(model.entry)
                                    }
                                    
                                    Behavior on color {
                                        ColorAnimation { duration: activeTheme.shortDuration }
                                    }
                                }
                                
                                // Delete button
                                Rectangle {
                                    width: 28
                                    height: 28
                                    radius: activeTheme.cornerRadiusSmall
                                    color: deleteArea.containsMouse ? Qt.rgba(activeTheme.error.r, activeTheme.error.g, activeTheme.error.b, 0.12) : "transparent"
                                    
                                    Text {
                                        anchors.centerIn: parent
                                        text: "delete"
                                        font.family: activeTheme.iconFont
                                        font.pixelSize: activeTheme.iconSize - 8
                                        color: deleteArea.containsMouse ? activeTheme.error : activeTheme.surfaceText
                                    }
                                    
                                    MouseArea {
                                        id: deleteArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: deleteEntry(model.entry)
                                    }
                                    
                                    Behavior on color {
                                        ColorAnimation { duration: activeTheme.shortDuration }
                                    }
                                }
                            }
                        }
                        
                        MouseArea {
                            id: entryArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            
                            onClicked: copyEntry(model.entry)
                        }
                        
                        Behavior on color {
                            ColorAnimation { duration: activeTheme.shortDuration }
                        }
                    }
                }
                
                // Empty state
                Column {
                    anchors.centerIn: parent
                    spacing: activeTheme.spacingL
                    visible: filteredClipboardModel.count === 0
                    
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "content_paste_off"
                        font.family: activeTheme.iconFont
                        font.pixelSize: activeTheme.iconSizeLarge + 16
                        color: Qt.rgba(activeTheme.surfaceText.r, activeTheme.surfaceText.g, activeTheme.surfaceText.b, 0.3)
                    }
                    
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "No clipboard history"
                        font.pixelSize: activeTheme.fontSizeLarge
                        color: Qt.rgba(activeTheme.surfaceText.r, activeTheme.surfaceText.g, activeTheme.surfaceText.b, 0.6)
                    }
                    
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Copy something to see it here"
                        font.pixelSize: activeTheme.fontSizeMedium
                        color: Qt.rgba(activeTheme.surfaceText.r, activeTheme.surfaceText.g, activeTheme.surfaceText.b, 0.4)
                    }
                }
            }
        }
    }
    
    // Clipboard processes
    Process {
        id: clipboardProcess
        command: ["cliphist", "list"]
        running: false
        
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                if (line.trim()) {
                    clipboardHistory.clipboardEntries.push(line)
                    clipboardModel.append({"entry": line})
                }
            }
        }
        
        onStarted: {
            clipboardHistory.clipboardEntries = []
            clipboardModel.clear()
            console.log("ClipboardHistory: Starting cliphist process...")
        }
        
        onExited: (exitCode) => {
            if (exitCode === 0) {
                updateFilteredModel()
            } else {
                console.warn("ClipboardHistory: Failed to load clipboard history")
            }
        }
    }
    
    Process {
        id: copyProcess
        running: false
        
        onExited: (exitCode) => {
            if (exitCode !== 0) {
                console.warn("ClipboardHistory: Failed to copy entry")
            }
        }
    }
    
    Process {
        id: deleteProcess
        running: false
        
        onExited: (exitCode) => {
            if (exitCode === 0) {
                refreshClipboard()
            }
        }
    }
    
    Process {
        id: clearProcess
        command: ["cliphist", "wipe"]
        running: false
        
        onExited: (exitCode) => {
            if (exitCode === 0) {
                clipboardHistory.clipboardEntries = []
                clipboardModel.clear()
            }
        }
    }
    
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape) {
            hide()
        }
    }
}