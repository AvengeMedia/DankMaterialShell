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
    id: muxModal

    layerNamespace: "dms:mux"

    property int selectedIndex: -1
    property string searchText: ""
    property var filteredSessions: []

    function isSessionExcluded(name) {
        var filter = SettingsData.muxSessionFilter.trim()
        if (filter.length === 0)
            return false
        var parts = filter.split(",")
        for (var i = 0; i < parts.length; i++) {
            var pattern = parts[i].trim()
            if (pattern.length === 0)
                continue
            if (pattern.startsWith("/") && pattern.endsWith("/") && pattern.length > 2) {
                try {
                    var re = new RegExp(pattern.slice(1, -1))
                    if (re.test(name))
                        return true
                } catch (e) {}
            } else {
                if (name.toLowerCase() === pattern.toLowerCase())
                    return true
            }
        }
        return false
    }

    function updateFilteredSessions() {
        var filtered = []
        var lowerSearch = searchText.trim().toLowerCase()
        for (var i = 0; i < MuxService.sessions.length; i++) {
            var session = MuxService.sessions[i]
            if (isSessionExcluded(session.name))
                continue
            if (lowerSearch.length > 0 && !session.name.toLowerCase().includes(lowerSearch))
                continue
            filtered.push(session)
        }
        filteredSessions = filtered

        if (selectedIndex >= filteredSessions.length) {
            selectedIndex = Math.max(0, filteredSessions.length - 1)
        }
    }

    onSearchTextChanged: updateFilteredSessions()

    Connections {
        target: MuxService
        function onSessionsChanged() {
            updateFilteredSessions()
        }
    }

    HyprlandFocusGrab {
        id: grab
        windows: [muxModal.contentWindow]
        active: CompositorService.isHyprland && muxModal.shouldHaveFocus
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
        MuxService.refreshSessions()
        shouldHaveFocus = true

        Qt.callLater(() => {
            if (muxPanel && muxPanel.searchField) {
                muxPanel.searchField.forceActiveFocus();
            }
        })
    }

    function hide() {
        close()
        selectedIndex = -1
        searchText = ""
    }

    function attachToSession(name) {
        MuxService.attachToSession(name)
        hide()
    }

    function renameSession(name) {
        inputModal.showWithOptions({
            title: I18n.tr("Rename Session"),
            message: I18n.tr("Enter a new name for session \"%1\"").arg(name),
            initialText: name,
            onConfirm: function (newName) {
                MuxService.renameSession(name, newName)
            }
        })
    }

    function killSession(name) {
        confirmModal.showWithOptions({
            title: I18n.tr("Kill Session"),
            message: I18n.tr("Are you sure you want to kill session \"%1\"?").arg(name),
            confirmText: I18n.tr("Kill"),
            confirmColor: Theme.primary,
            onConfirm: function () {
                MuxService.killSession(name)
            }
        })
    }

    function createNewSession() {
        inputModal.showWithOptions({
            title: I18n.tr("New Session"),
            message: I18n.tr("Please write a name for your new %1 session").arg(MuxService.displayName),
            onConfirm: function (name) {
                MuxService.createSession(name)
                hide()
            }
        })
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

    Timer {
        interval: 3000
        running: muxModal.shouldBeVisible
        repeat: true
        onTriggered: MuxService.refreshSessions()
    }

    IpcHandler {
        function open(): string {
            muxModal.show()
            return "MUX_OPEN_SUCCESS"
        }

        function close(): string {
            muxModal.hide()
            return "MUX_CLOSE_SUCCESS"
        }

        function toggle(): string {
            muxModal.toggle()
            return "MUX_TOGGLE_SUCCESS"
        }

        target: "mux"
    }

    // Backwards compatibility
    IpcHandler {
        function open(): string {
            muxModal.show()
            return "TMUX_OPEN_SUCCESS"
        }

        function close(): string {
            muxModal.hide()
            return "TMUX_CLOSE_SUCCESS"
        }

        function toggle(): string {
            muxModal.toggle()
            return "TMUX_TOGGLE_SUCCESS"
        }

        target: "tmux"
    }

    InputModal {
        id: inputModal
        onShouldBeVisibleChanged: {
            if (shouldBeVisible) {
                muxModal.shouldHaveFocus = false;
                muxModal.contentWindow.visible = false;
                return;
            }
            if (muxModal.shouldBeVisible) {
                muxModal.contentWindow.visible = true;
            }
            Qt.callLater(function () {
                if (!muxModal.shouldBeVisible) {
                    return;
                }
                muxModal.shouldHaveFocus = true;
                muxModal.modalFocusScope.forceActiveFocus();
                if (muxPanel.searchField) {
                    muxPanel.searchField.forceActiveFocus();
                }
            });
        }
    }

    ConfirmModal {
        id: confirmModal
        onShouldBeVisibleChanged: {
            if (shouldBeVisible) {
                muxModal.shouldHaveFocus = false;
                muxModal.contentWindow.visible = false;
                return;
            }
            if (muxModal.shouldBeVisible) {
                muxModal.contentWindow.visible = true;
            }
            Qt.callLater(function () {
                if (!muxModal.shouldBeVisible) {
                    return;
                }
                muxModal.shouldHaveFocus = true;
                muxModal.modalFocusScope.forceActiveFocus();
                if (muxPanel.searchField) {
                    muxPanel.searchField.forceActiveFocus();
                }
            });
        }
    }

    directContent: Item {
        id: muxPanel

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
            } else if (event.key === Qt.Key_R && (event.modifiers & Qt.ControlModifier)) {
                if (MuxService.supportsRename && selectedIndex >= 0 && selectedIndex < filteredSessions.length) {
                    renameSession(filteredSessions[selectedIndex].name)
                }
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
                    text: I18n.tr("%1 Sessions").arg(MuxService.displayName)
                    font.pixelSize: Theme.fontSizeLarge + 4
                    font.weight: Font.Bold
                    color: Theme.surfaceText
                }

                StyledText {
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spacingS
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.tr("%1 active, %2 filtered").arg(MuxService.sessions.length).arg(muxModal.filteredSessions.length)
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
                placeholderText: I18n.tr("Search sessions...")
                keyForwardTargets: [muxPanel]

                onTextEdited: {
                    muxModal.searchText = text
                    muxModal.selectedIndex = 0
                }
            }

            // New Session Button
            Rectangle {
                width: parent.width
                height: 56
                radius: Theme.cornerRadius
                color: muxModal.selectedIndex === -1 ? Theme.primaryContainer :
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
                            text: I18n.tr("New Session")
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }

                        StyledText {
                            text: I18n.tr("Create a new %1 session (n)").arg(MuxService.displayName)
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
                    onClicked: muxModal.createNewSession()
                }
            }

            // Sessions List
            Rectangle {
                width: parent.width
                height: parent.height - 88 - 48 - shortcutsBar.height - Theme.spacingS * 3
                radius: Theme.cornerRadius
                color: "transparent"

                ScrollView {
                    anchors.fill: parent
                    clip: true

                    Column {
                        width: parent.width
                        spacing: Theme.spacingXS

                        Repeater {
                            model: muxModal.filteredSessions

                            delegate: Rectangle {
                                required property var modelData
                                required property int index

                                width: parent.width
                                height: 64
                                radius: Theme.cornerRadius
                                color: muxModal.selectedIndex === index ? Theme.primaryContainer :
                                        (sessionMouse.containsMouse ? Theme.surfaceContainerHigh : "transparent")

                                MouseArea {
                                    id: sessionMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: muxModal.attachToSession(modelData.name)
                                }

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
                                            text: {
                                                var parts = []
                                                if (modelData.windows !== "N/A")
                                                    parts.push(I18n.tr("%1 windows").arg(modelData.windows))
                                                parts.push(modelData.attached ? I18n.tr("attached") : I18n.tr("detached"))
                                                return parts.join(" \u2022 ")
                                            }
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceVariantText
                                        }
                                    }

                                    // Rename button (tmux only)
                                    Rectangle {
                                        Layout.preferredWidth: 36
                                        Layout.preferredHeight: 36
                                        radius: 18
                                        visible: MuxService.supportsRename
                                        color: renameMouse.containsMouse ? Theme.surfaceContainerHighest : "transparent"

                                        DankIcon {
                                            anchors.centerIn: parent
                                            name: "edit"
                                            size: Theme.iconSizeSmall
                                            color: renameMouse.containsMouse ? Theme.primary : Theme.surfaceVariantText
                                        }

                                        MouseArea {
                                            id: renameMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: muxModal.renameSession(modelData.name)
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
                                                muxModal.killSession(modelData.name)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Empty state
                        Item {
                            width: parent.width
                            height: muxModal.filteredSessions.length === 0 ? 200 : 0
                            visible: muxModal.filteredSessions.length === 0

                            Column {
                                anchors.centerIn: parent
                                spacing: Theme.spacingM

                                DankIcon {
                                    name: muxModal.searchText.length > 0 ? "search_off" : "terminal"
                                    size: 48
                                    color: Theme.surfaceVariantText
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }

                                StyledText {
                                    text: muxModal.searchText.length > 0 ? I18n.tr("No sessions found") : I18n.tr("No active %1 sessions").arg(MuxService.displayName)
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: Theme.surfaceVariantText
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }

                                StyledText {
                                    text: muxModal.searchText.length > 0 ? I18n.tr("Try a different search") : I18n.tr("Press 'n' or click 'New Session' to create one")
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                            }
                        }
                    }
                }
            }

            // Shortcuts bar
            Row {
                id: shortcutsBar
                width: parent.width
                spacing: Theme.spacingM
                bottomPadding: Theme.spacingS

                Repeater {
                    model: {
                        var shortcuts = [
                            { key: "↑↓", label: I18n.tr("Navigate") },
                            { key: "↵", label: I18n.tr("Attach") },
                            { key: "^N", label: I18n.tr("New") },
                            { key: "^D", label: I18n.tr("Kill") },
                            { key: "Esc", label: I18n.tr("Close") }
                        ]
                        if (MuxService.supportsRename)
                            shortcuts.splice(3, 0, { key: "^R", label: I18n.tr("Rename") })
                        return shortcuts
                    }

                    delegate: Row {
                        required property var modelData
                        spacing: 4

                        Rectangle {
                            width: keyText.width + Theme.spacingS
                            height: keyText.height + 4
                            radius: 4
                            color: Theme.surfaceContainerHighest
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                id: keyText
                                anchors.centerIn: parent
                                text: modelData.key
                                font.pixelSize: Theme.fontSizeSmall - 1
                                font.weight: Font.Medium
                                color: Theme.surfaceVariantText
                            }
                        }

                        StyledText {
                            text: modelData.label
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }
        }
    }
}
