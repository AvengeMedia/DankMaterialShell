import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Common
import qs.Services
import qs.Widgets

PanelWindow {
    id: root

    property bool showContextMenu: false
    property var appData: null
    property var anchorItem: null
    property real dockVisibleHeight: 40
    property int margin: 10
    property bool hidePin: false

    function showForButton(button, data, dockHeight, hidePinOption) {
        anchorItem = button
        appData = data
        dockVisibleHeight = dockHeight || 40
        hidePin = hidePinOption || false

        const dockWindow = button.Window.window
        if (dockWindow) {
            for (var i = 0; i < Quickshell.screens.length; i++) {
                const s = Quickshell.screens[i]
                if (dockWindow.x >= s.x && dockWindow.x < s.x + s.width) {
                    root.screen = s
                    break
                }
            }
        }

        showContextMenu = true
    }
    function close() {
        showContextMenu = false
    }

    screen: Quickshell.screens[0]

    visible: showContextMenu
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    color: "transparent"
    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    property point anchorPos: Qt.point(screen.width / 2, screen.height - 100)

    onAnchorItemChanged: updatePosition()
    onVisibleChanged: {
        if (visible) {
            updatePosition()
        }
    }

    function updatePosition() {
        if (!anchorItem) {
            anchorPos = Qt.point(screen.width / 2, screen.height - 100)
            return
        }

        const dockWindow = anchorItem.Window.window
        if (!dockWindow) {
            anchorPos = Qt.point(screen.width / 2, screen.height - 100)
            return
        }

        const buttonPosInDock = anchorItem.mapToItem(dockWindow.contentItem, 0, 0)
        let actualDockHeight = root.dockVisibleHeight

        function findDockBackground(item) {
            if (item.objectName === "dockBackground") {
                return item
            }
            for (var i = 0; i < item.children.length; i++) {
                const found = findDockBackground(item.children[i])
                if (found) {
                    return found
                }
            }
            return null
        }

        const dockBackground = findDockBackground(dockWindow.contentItem)
        if (dockBackground) {
            actualDockHeight = dockBackground.height
        }

        const isDockAtBottom = SettingsData.dockPosition === SettingsData.Position.Bottom
        const dockBottomMargin = 16
        let buttonScreenY

        if (isDockAtBottom) {
            buttonScreenY = root.screen.height - actualDockHeight - dockBottomMargin - 20
        } else {
            buttonScreenY = actualDockHeight + dockBottomMargin + 20
        }

        const dockContentWidth = dockWindow.width
        const screenWidth = root.screen.width
        const dockLeftMargin = Math.round((screenWidth - dockContentWidth) / 2)
        const buttonScreenX = dockLeftMargin + buttonPosInDock.x + anchorItem.width / 2

        anchorPos = Qt.point(buttonScreenX, buttonScreenY)
    }

    Rectangle {
        id: menuContainer

        width: Math.min(400, Math.max(200, menuColumn.implicitWidth + Theme.spacingS * 2))
        height: Math.max(60, menuColumn.implicitHeight + Theme.spacingS * 2)

        x: {
            const left = 10
            const right = root.width - width - 10
            const want = root.anchorPos.x - width / 2
            return Math.max(left, Math.min(right, want))
        }
        y: {
            const isDockAtBottom = SettingsData.dockPosition === SettingsData.Position.Bottom
            if (isDockAtBottom) {
                return Math.max(10, root.anchorPos.y - height + 30)
            } else {
                return Math.min(root.height - height - 10, root.anchorPos.y - 30)
            }
        }
        color: Theme.popupBackground()
        radius: Theme.cornerRadius
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
        border.width: 1
        opacity: showContextMenu ? 1 : 0
        scale: showContextMenu ? 1 : 0.85

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 4
            anchors.leftMargin: 2
            anchors.rightMargin: -2
            anchors.bottomMargin: -4
            radius: parent.radius
            color: Qt.rgba(0, 0, 0, 0.15)
            z: parent.z - 1
        }

        Column {
            id: menuColumn
            width: parent.width - Theme.spacingS * 2
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: Theme.spacingS
            spacing: 1

            // Window list for grouped apps
            Repeater {
                model: {
                    if (!root.appData || root.appData.type !== "grouped") return []

                    const toplevels = []
                    const allToplevels = ToplevelManager.toplevels.values
                    for (let i = 0; i < allToplevels.length; i++) {
                        const toplevel = allToplevels[i]
                        if (toplevel.appId === root.appData.appId) {
                            toplevels.push(toplevel)
                        }
                    }
                    return toplevels
                }

                Rectangle {
                    width: parent.width
                    height: 28
                    radius: Theme.cornerRadius
                    color: windowArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"

                    StyledText {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingS
                        anchors.right: closeButton.left
                        anchors.rightMargin: Theme.spacingXS
                        anchors.verticalCenter: parent.verticalCenter
                        text: (modelData && modelData.title) ? modelData.title : "(Unnamed)"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceText
                        font.weight: Font.Normal
                        elide: Text.ElideRight
                        wrapMode: Text.NoWrap
                    }

                    Rectangle {
                        id: closeButton
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingXS
                        anchors.verticalCenter: parent.verticalCenter
                        width: 20
                        height: 20
                        radius: 10
                        color: closeMouseArea.containsMouse ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.2) : "transparent"

                        DankIcon {
                            anchors.centerIn: parent
                            name: "close"
                            size: 12
                            color: closeMouseArea.containsMouse ? Theme.error : Theme.surfaceText
                        }

                        MouseArea {
                            id: closeMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (modelData && modelData.close) {
                                    modelData.close()
                                }
                                root.close()
                            }
                        }
                    }

                    MouseArea {
                        id: windowArea
                        anchors.fill: parent
                        anchors.rightMargin: 24
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (modelData && modelData.activate) {
                                modelData.activate()
                            }
                            root.close()
                        }
                    }
                }
            }

            Rectangle {
                visible: {
                    if (!root.appData) return false
                    if (root.appData.type !== "grouped") return false
                    return root.appData.windowCount > 0
                }
                width: parent.width
                height: 1
                color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
            }

            Rectangle {
                visible: !root.hidePin
                width: parent.width
                height: 28
                radius: Theme.cornerRadius
                color: pinArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"

                StyledText {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingS
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spacingS
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.appData && root.appData.isPinned ? "Unpin from Dock" : "Pin to Dock"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                    font.weight: Font.Normal
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                }

                MouseArea {
                    id: pinArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!root.appData) {
                            return
                        }
                        if (root.appData.isPinned) {
                            SessionData.removePinnedApp(root.appData.appId)
                        } else {
                            SessionData.addPinnedApp(root.appData.appId)
                        }
                        root.close()
                    }
                }
            }

            Rectangle {
                visible: root.appData && root.appData.type === "window"
                width: parent.width
                height: 1
                color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
            }

            Rectangle {
                visible: root.appData && root.appData.type === "window"
                width: parent.width
                height: 1
                color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
            }

            Rectangle {
                visible: root.appData && (root.appData.type === "window" || (root.appData.type === "grouped" && root.appData.windowCount > 0))
                width: parent.width
                height: 28
                radius: Theme.cornerRadius
                color: closeArea.containsMouse ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.12) : "transparent"

                StyledText {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingS
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spacingS
                    anchors.verticalCenter: parent.verticalCenter
                    text: {
                        if (root.appData && root.appData.type === "grouped") {
                            return "Close All Windows"
                        }
                        return "Close Window"
                    }
                    font.pixelSize: Theme.fontSizeSmall
                    color: closeArea.containsMouse ? Theme.error : Theme.surfaceText
                    font.weight: Font.Normal
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                }

                MouseArea {
                    id: closeArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        const sortedToplevels = CompositorService.sortedToplevels
                        if (root.appData && root.appData.type === "window") {
                            // Find and close the specific window
                            for (var i = 0; i < sortedToplevels.length; i++) {
                                const toplevel = sortedToplevels[i]
                                const checkId = toplevel.title + "|" + (toplevel.appId || "") + "|" + i
                                if (checkId === root.appData.uniqueId) {
                                    toplevel.close()
                                    break
                                }
                            }
                        } else if (root.appData && root.appData.type === "grouped") {
                            // Close all windows for this app
                            const allToplevels = ToplevelManager.toplevels.values
                            for (let i = 0; i < allToplevels.length; i++) {
                                const toplevel = allToplevels[i]
                                if (toplevel.appId === root.appData.appId) {
                                    toplevel.close()
                                }
                            }
                        }
                        root.close()
                    }
                }
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.mediumDuration
                easing.type: Theme.emphasizedEasing
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: Theme.mediumDuration
                easing.type: Theme.emphasizedEasing
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: {
            root.close()
        }
    }
}
