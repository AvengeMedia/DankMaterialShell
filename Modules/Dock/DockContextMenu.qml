import QtQuick
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
    property var desktopEntry: null

    function showForButton(button, data, dockHeight, hidePinOption, entry, dockScreen) {
        anchorItem = button
        appData = data
        dockVisibleHeight = dockHeight || 40
        hidePin = hidePinOption || false
        desktopEntry = entry || null

        if (dockScreen) {
            root.screen = dockScreen
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
        let actualDockWidth = dockWindow.width
        if (dockBackground) {
            actualDockHeight = dockBackground.height
            actualDockWidth = dockBackground.width
        }

        const isVertical = SettingsData.dockPosition === SettingsData.Position.Left || SettingsData.dockPosition === SettingsData.Position.Right
        const dockMargin = 16
        let buttonScreenX, buttonScreenY

        if (isVertical) {
            const dockContentHeight = dockWindow.height
            const screenHeight = root.screen.height
            const dockTopMargin = Math.round((screenHeight - dockContentHeight) / 2)
            buttonScreenY = dockTopMargin + buttonPosInDock.y + anchorItem.height / 2

            if (SettingsData.dockPosition === SettingsData.Position.Right) {
                buttonScreenX = root.screen.width - actualDockWidth - dockMargin - 20
            } else {
                buttonScreenX = actualDockWidth + dockMargin + 20
            }
        } else {
            const isDockAtBottom = SettingsData.dockPosition === SettingsData.Position.Bottom

            if (isDockAtBottom) {
                buttonScreenY = root.screen.height - actualDockHeight - dockMargin - 20
            } else {
                buttonScreenY = actualDockHeight + dockMargin + 20
            }

            const dockContentWidth = dockWindow.width
            const screenWidth = root.screen.width
            const dockLeftMargin = Math.round((screenWidth - dockContentWidth) / 2)
            buttonScreenX = dockLeftMargin + buttonPosInDock.x + anchorItem.width / 2
        }

        anchorPos = Qt.point(buttonScreenX, buttonScreenY)
    }

    Rectangle {
        id: menuContainer

        x: {
            const isVertical = SettingsData.dockPosition === SettingsData.Position.Left || SettingsData.dockPosition === SettingsData.Position.Right
            if (isVertical) {
                const isDockAtRight = SettingsData.dockPosition === SettingsData.Position.Right
                if (isDockAtRight) {
                    return Math.max(10, root.anchorPos.x - width + 30)
                } else {
                    return Math.min(root.width - width - 10, root.anchorPos.x - 30)
                }
            } else {
                const left = 10
                const right = root.width - width - 10
                const want = root.anchorPos.x - width / 2
                return Math.max(left, Math.min(right, want))
            }
        }
        y: {
            const isVertical = SettingsData.dockPosition === SettingsData.Position.Left || SettingsData.dockPosition === SettingsData.Position.Right
            if (isVertical) {
                const top = 10
                const bottom = root.height - height - 10
                const want = root.anchorPos.y - height / 2
                return Math.max(top, Math.min(bottom, want))
            } else {
                const isDockAtBottom = SettingsData.dockPosition === SettingsData.Position.Bottom
                if (isDockAtBottom) {
                    return Math.max(10, root.anchorPos.y - height + 30)
                } else {
                    return Math.min(root.height - height - 10, root.anchorPos.y - 30)
                }
            }
        }

        width: Math.min(400, Math.max(180, menuColumn.implicitWidth + Theme.spacingS * 2))
        height: Math.max(60, menuColumn.implicitHeight + Theme.spacingS * 2)
        color: Theme.popupBackground()
        radius: Theme.cornerRadius
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
        border.width: 1

        opacity: root.showContextMenu ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.shortDuration
                easing.type: Theme.emphasizedEasing
            }
        }

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 4
            anchors.leftMargin: 2
            anchors.rightMargin: -2
            anchors.bottomMargin: -4
            radius: parent.radius
            color: Qt.rgba(0, 0, 0, 0.15)
            z: -1
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
                        text: (modelData && modelData.title) ? modelData.title: I18n.tr("(Unnamed)")
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

            Repeater {
                model: root.desktopEntry && root.desktopEntry.actions ? root.desktopEntry.actions : []

                Rectangle {
                    width: parent.width
                    height: 28
                    radius: Theme.cornerRadius
                    color: actionArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingS
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingXS

                        Item {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 16
                            height: 16
                            visible: modelData.icon && modelData.icon !== ""

                            IconImage {
                                anchors.fill: parent
                                source: modelData.icon ? Quickshell.iconPath(modelData.icon, true) : ""
                                smooth: true
                                asynchronous: true
                                visible: status === Image.Ready
                            }
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.name || ""
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Normal
                            elide: Text.ElideRight
                            wrapMode: Text.NoWrap
                        }
                    }

                    MouseArea {
                        id: actionArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (modelData) {
                                SessionService.launchDesktopAction(root.desktopEntry, modelData)
                            }
                            root.close()
                        }
                    }
                }
            }

            Rectangle {
                visible: root.desktopEntry && root.desktopEntry.actions && root.desktopEntry.actions.length > 0
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
                    text: root.appData && root.appData.isPinned ? I18n.tr("Unpin from Dock") : I18n.tr("Pin to Dock")
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
                visible: (root.appData && root.appData.type === "window") || (root.desktopEntry && SessionService.hasPrimeRun)
                width: parent.width
                height: 1
                color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
            }

            Rectangle {
                visible: root.desktopEntry && SessionService.hasPrimeRun
                width: parent.width
                height: 28
                radius: Theme.cornerRadius
                color: primeRunArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"

                StyledText {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingS
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spacingS
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.tr("Launch on dGPU")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                    font.weight: Font.Normal
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                }

                MouseArea {
                    id: primeRunArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.desktopEntry) {
                            SessionService.launchDesktopEntry(root.desktopEntry, true)
                        }
                        root.close()
                    }
                }
            }

            Rectangle {
                visible: root.appData && (root.appData.type === "window" || (root.appData.type === "grouped" && root.appData.windowCount > 0))
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
                            for (var i = 0; i < sortedToplevels.length; i++) {
                                const toplevel = sortedToplevels[i]
                                const checkId = toplevel.title + "|" + (toplevel.appId || "") + "|" + i
                                if (checkId === root.appData.uniqueId) {
                                    toplevel.close()
                                    break
                                }
                            }
                        } else if (root.appData && root.appData.type === "grouped") {
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
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: root.close()
    }
}
