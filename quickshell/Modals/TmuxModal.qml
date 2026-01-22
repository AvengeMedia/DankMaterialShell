pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell
import qs.Common
import qs.Modals.Common
import qs.Services
import qs.Widgets

DankModal {
    id: tmuxModal
    
    layerNamespace: "dms:tmux"
    
    property int selectedIndex: -1
    property string terminal: "ghostty"
    property string terminalFlag: "-e"
    property Component tmuxContent
    property string searchText: ""
    property var filteredSessions: []
    
    function updateFilteredSessions() {
        if (searchText.trim().length === 0) {
            filteredSessions = TmuxService.sessions
        } else {
            var filtered = []
            var lowerSearch = searchText.toLowerCase()
            for (var i = 0; i < TmuxService.sessions.length; i++) {
                var session = TmuxService.sessions[i]
                if (session.name.toLowerCase().includes(lowerSearch)) {
                    filtered.push(session)
                }
            }
            filteredSessions = filtered
        }
        
        // Adjust selection if needed
        if (selectedIndex >= filteredSessions.length) {
            selectedIndex = Math.max(0, filteredSessions.length - 1)
        }
    }
    
    onSearchTextChanged: updateFilteredSessions()
    
    Connections {
        target: TmuxService
        function onSessionsChanged() {
            updateFilteredSessions()
        }
    }

    HyprlandFocusGrab {
        id: grab
        windows: [tmuxModal.contentWindow]
        active: CompositorService.isHyprland && tmuxModal.shouldHaveFocus
    }
    
    function toggle() {
        if (shouldBeVisible) {
            hide()
        } else {
            show()
        }
    }
    
    function show() {
        open()
        selectedIndex = -1
        searchText = ""
        TmuxService.refreshSessions()
        shouldHaveFocus = true
        
        Qt.callLater(() => {
            if (tmuxPanel && tmuxPanel.searchField) {
                tmuxPanel.searchField.forceActiveFocus();
            }
        })
    }
    
    function hide() {
        close()
        selectedIndex = -1
        searchText = ""
    }
    
    function attachToSession(name) {
        Quickshell.execDetached([terminal, terminalFlag, "tmux", "attach", "-t", name])
        hide()
    }
    
    function killSession(name) {
        Quickshell.execDetached(["tmux", "kill-session", "-t", name])
        TmuxService.refreshSessions()
    }
    
    function createNewSession() {
        // Quickshell.execDetached([terminal, terminalFlag, "tmux", "new-session"])
        // hide()
        // tmuxModal.shouldHaveFocus = false
        inputModal.show(
            "New session",
            "Please write a name for your new tmux session",
            function (name) {
                console.error(name)
            },
            function () {
                console.error("closed")
                Qt.callLater(() => {
                    tmuxPanel.searchField.forceActiveFocus();
                    shouldHaveFocus = true
                    grab = true
                })
            }
        )
    }
    
    function selectNext() {
        selectedIndex = Math.min(selectedIndex + 1, filteredSessions.length - 1)
    }
    
    function selectPrevious() {
        selectedIndex = Math.max(selectedIndex - 1, -1)
    }
    
    function activateSelected() {
        if (selectedIndex === -1) {
            createNewSession()
        } else if (selectedIndex >= 0 && selectedIndex < filteredSessions.length) {
            attachToSession(filteredSessions[selectedIndex].name)
        }
    }
    
    visible: false
    modalWidth: 600
    modalHeight: 600
    backgroundColor: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
    cornerRadius: Theme.cornerRadius
    borderColor: Theme.outlineMedium
    borderWidth: 1
    enableShadow: true
    keepContentLoaded: true
    
    onBackgroundClicked: hide()

    content: tmuxContent
    
    // Timer only runs when modal is visible
    Timer {
        interval: 3000
        running: tmuxModal.shouldBeVisible
        repeat: true
        onTriggered: TmuxService.refreshSessions()
    }
    
    IpcHandler {
        function open(): string {
            tmuxModal.show()
            return "TMUX_OPEN_SUCCESS"
        }
        
        function close(): string {
            tmuxModal.hide()
            return "TMUX_CLOSE_SUCCESS"
        }
        
        function toggle(): string {
            tmuxModal.toggle()
            return "TMUX_TOGGLE_SUCCESS"
        }
        
        target: "tmux"
    }

    InputModal {
        id: inputModal
    }
    
    directContent: Item {
        id: tmuxPanel

        clip: false
        
        property alias searchField: searchField

        Keys.onPressed: event => {
            if ((event.key === Qt.Key_J && (event.modifiers & Qt.ControlModifier)) ||
                (event.key === Qt.Key_Down)) {
                selectNext()
                event.accepted = true
            } else if ((event.key === Qt.Key_K && (event.modifiers & Qt.ControlModifier)) ||
                    (event.key === Qt.Key_Up)) {
                selectPrevious()
                event.accepted = true
            } else if (event.key === Qt.Key_N && (event.modifiers & Qt.ControlModifier)) {
                createNewSession()
                event.accepted = true
            } else if (event.key === Qt.Key_D && (event.modifiers & Qt.ControlModifier)) {
                if (selectedIndex >= 0 && selectedIndex < filteredSessions.length) {
                    killSession(filteredSessions[selectedIndex].name)
                }
                event.accepted = true
            } else if (event.key === Qt.Key_Escape) {
                hide()
                event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                activateSelected()
                event.accepted = true
            }
        }
            
        Column {
            width: parent.width - Theme.spacingM * 2
            height: parent.height - Theme.spacingM * 2
            x: Theme.spacingM
            y: Theme.spacingM
            spacing: Theme.spacingS
            
            // Header
            Item {
                width: parent.width
                height: 40
                
                StyledText {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingS
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Tmux Sessions"
                    font.pixelSize: Theme.fontSizeLarge + 4
                    font.weight: Font.Bold
                    color: Theme.surfaceText
                }
                
                StyledText {
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spacingS
                    anchors.verticalCenter: parent.verticalCenter
                    text: TmuxService.sessions.length + " active, " + tmuxModal.filteredSessions.length + " filtered"
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceVariantText
                }
            }
            
            // Search field
            DankTextField {
                id: searchField
                
                width: parent.width
                height: 48
                cornerRadius: Theme.cornerRadius
                backgroundColor: Theme.surfaceContainerHigh
                normalBorderColor: Theme.outlineMedium
                focusedBorderColor: Theme.primary
                leftIconName: "search"
                leftIconSize: Theme.iconSize
                leftIconColor: Theme.surfaceVariantText
                leftIconFocusedColor: Theme.primary
                showClearButton: true
                font.pixelSize: Theme.fontSizeMedium
                placeholderText: "Search sessions..."
                keyForwardTargets: [tmuxPanel]
                
                onTextEdited: {
                    tmuxModal.searchText = text
                    tmuxModal.selectedIndex = 0
                }
            }
            
            // New Session Button
            Rectangle {
                width: parent.width
                height: 56
                radius: Theme.cornerRadius
                color: tmuxModal.selectedIndex === -1 ? Theme.primaryContainer : 
                        (newMouse.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer)
                
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.spacingM
                    anchors.rightMargin: Theme.spacingM
                    spacing: Theme.spacingM
                    
                    Rectangle {
                        Layout.preferredWidth: 40
                        Layout.preferredHeight: 40
                        radius: 20
                        color: Theme.primaryContainer
                        
                        DankIcon {
                            anchors.centerIn: parent
                            name: "add"
                            size: Theme.iconSize
                            color: Theme.primary
                        }
                    }
                    
                    Column {
                        Layout.fillWidth: true
                        spacing: 2
                        
                        StyledText {
                            text: "New Session"
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }
                        
                        StyledText {
                            text: "Create a new tmux session (n)"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }
                    }
                }
                
                MouseArea {
                    id: newMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: tmuxModal.createNewSession()
                }
            }
            
            // Sessions List
            Rectangle {
                width: parent.width
                height: parent.height - 88 - 48 - Theme.spacingS * 2
                radius: Theme.cornerRadius
                color: "transparent"
                
                ScrollView {
                    anchors.fill: parent
                    clip: true
                    
                    Column {
                        width: parent.width
                        spacing: Theme.spacingXS
                        
                        Repeater {
                            model: tmuxModal.filteredSessions
                            
                            delegate: Rectangle {
                                required property var modelData
                                required property int index
                                
                                width: parent.width
                                height: 64
                                radius: Theme.cornerRadius
                                color: tmuxModal.selectedIndex === index ? Theme.primaryContainer :
                                        (sessionMouse.containsMouse ? Theme.surfaceContainerHigh : "transparent")
                                
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.spacingM
                                    anchors.rightMargin: Theme.spacingM
                                    spacing: Theme.spacingM
                                    
                                    // Avatar
                                    Rectangle {
                                        Layout.preferredWidth: 40
                                        Layout.preferredHeight: 40
                                        radius: 20
                                        color: modelData.attached ? Theme.primaryContainer : Theme.surfaceContainerHigh
                                        
                                        StyledText {
                                            anchors.centerIn: parent
                                            text: modelData.name.charAt(0).toUpperCase()
                                            font.pixelSize: Theme.fontSizeLarge
                                            font.weight: Font.Bold
                                            color: modelData.attached ? Theme.primary : Theme.surfaceText
                                        }
                                    }
                                    
                                    // Info
                                    Column {
                                        Layout.fillWidth: true
                                        spacing: 2
                                        
                                        StyledText {
                                            text: modelData.name
                                            font.pixelSize: Theme.fontSizeMedium
                                            font.weight: Font.Medium
                                            color: Theme.surfaceText
                                            elide: Text.ElideRight
                                        }
                                        
                                        StyledText {
                                            text: modelData.windows + " windows • " + (modelData.attached ? "attached" : "detached")
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceVariantText
                                        }
                                    }
                                    
                                    // Delete button
                                    Rectangle {
                                        Layout.preferredWidth: 36
                                        Layout.preferredHeight: 36
                                        radius: 18
                                        color: deleteMouse.containsMouse ? Theme.errorContainer : "transparent"
                                        
                                        DankIcon {
                                            anchors.centerIn: parent
                                            name: "delete"
                                            size: Theme.iconSizeSmall
                                            color: deleteMouse.containsMouse ? Theme.error : Theme.surfaceVariantText
                                        }
                                        
                                        MouseArea {
                                            id: deleteMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                mouse.accepted = true
                                                tmuxModal.killSession(modelData.name)
                                            }
                                        }
                                    }
                                }
                                
                                MouseArea {
                                    id: sessionMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: tmuxModal.attachToSession(modelData.name)
                                }
                            }
                        }
                        
                        // Empty state
                        Item {
                            width: parent.width
                            height: tmuxModal.filteredSessions.length === 0 ? 200 : 0
                            visible: tmuxModal.filteredSessions.length === 0
                            
                            Column {
                                anchors.centerIn: parent
                                spacing: Theme.spacingM
                                
                                DankIcon {
                                    name: tmuxModal.searchText.length > 0 ? "search_off" : "terminal"
                                    size: 48
                                    color: Theme.surfaceVariantText
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                                
                                StyledText {
                                    text: tmuxModal.searchText.length > 0 ? "No sessions found" : "No active tmux sessions"
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: Theme.surfaceVariantText
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                                
                                StyledText {
                                    text: tmuxModal.searchText.length > 0 ? "Try a different search" : "Press 'n' or click 'New Session' to create one"
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}