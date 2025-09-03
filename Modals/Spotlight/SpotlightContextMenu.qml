import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: contextMenu

    property var currentApp: null
    property bool menuVisible: false
    property var appLauncher: null
    property var parentHandler: null

    function show(x, y, app) {
        currentApp = app
        const menuWidth = 180
        const menuHeight = menuColumn.implicitHeight + Theme.spacingS * 2
        let finalX = x + 8
        let finalY = y + 8
        if (parentHandler) {
            if (finalX + menuWidth > parentHandler.width)
                finalX = x - menuWidth - 8

            if (finalY + menuHeight > parentHandler.height)
                finalY = y - menuHeight - 8

            finalX = Math.max(8, Math.min(finalX, parentHandler.width - menuWidth - 8))
            finalY = Math.max(8, Math.min(finalY, parentHandler.height - menuHeight - 8))
        }
        contextMenu.x = finalX
        contextMenu.y = finalY
        contextMenu.visible = true
        contextMenu.menuVisible = true
    }

    function close() {
        contextMenu.menuVisible = false
        Qt.callLater(() => {
                         contextMenu.visible = false
                     })
    }

    visible: false
    width: 180
    height: menuColumn.implicitHeight + Theme.spacingS * 2
    radius: Theme.cornerRadius
    color: Theme.popupBackground()
    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
    border.width: 1
    z: 1000
    opacity: menuVisible ? 1 : 0
    scale: menuVisible ? 1 : 0.85

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

        anchors.fill: parent
        anchors.margins: Theme.spacingS
        spacing: 1

        Rectangle {
            width: parent.width
            height: 32
            radius: Theme.cornerRadius
            color: pinMouseArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"

            Row {
                anchors.left: parent.left
                anchors.leftMargin: Theme.spacingS
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingS

                DankIcon {
                    name: {
                        if (!contextMenu.currentApp || !contextMenu.currentApp.desktopEntry)
                            return "push_pin"

                        const appId = contextMenu.currentApp.desktopEntry.id || contextMenu.currentApp.desktopEntry.execString || ""
                        return SessionData.isPinnedApp(appId) ? "keep_off" : "push_pin"
                    }
                    size: Theme.iconSize - 2
                    color: Theme.surfaceText
                    opacity: 0.7
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: {
                        if (!contextMenu.currentApp || !contextMenu.currentApp.desktopEntry)
                            return "Pin to Dock"

                        const appId = contextMenu.currentApp.desktopEntry.id || contextMenu.currentApp.desktopEntry.execString || ""
                        return SessionData.isPinnedApp(appId) ? "Unpin from Dock" : "Pin to Dock"
                    }
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                    font.weight: Font.Normal
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                id: pinMouseArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: () => {
                               if (!contextMenu.currentApp || !contextMenu.currentApp.desktopEntry)
                               return

                               const appId = contextMenu.currentApp.desktopEntry.id || contextMenu.currentApp.desktopEntry.execString || ""
                               if (SessionData.isPinnedApp(appId))
                               SessionData.removePinnedApp(appId)
                               else
                               SessionData.addPinnedApp(appId)
                               contextMenu.close()
                           }
            }
        }

        Rectangle {
            width: parent.width - Theme.spacingS * 2
            height: 5
            anchors.horizontalCenter: parent.horizontalCenter
            color: "transparent"

            Rectangle {
                anchors.centerIn: parent
                width: parent.width
                height: 1
                color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
            }
        }

        Rectangle {
            width: parent.width
            height: 32
            radius: Theme.cornerRadius
            color: launchMouseArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"

            Row {
                anchors.left: parent.left
                anchors.leftMargin: Theme.spacingS
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingS

                DankIcon {
                    name: "launch"
                    size: Theme.iconSize - 2
                    color: Theme.surfaceText
                    opacity: 0.7
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: "Launch"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                    font.weight: Font.Normal
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                id: launchMouseArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: () => {
                               if (contextMenu.currentApp && appLauncher)
                               appLauncher.launchApp(contextMenu.currentApp)

                               contextMenu.close()
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
