import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import qs.Common
import qs.Services
import qs.Widgets

Popup {
    id: contextMenu

    property var currentApp: null
    property var appLauncher: null
    property var parentHandler: null

    function show(x, y, app) {
        currentApp = app
        contextMenu.x = x + 4
        contextMenu.y = y + 4
        contextMenu.open()
    }

    function hide() {
        contextMenu.close()
    }

    width: Math.max(180, menuColumn.implicitWidth + Theme.spacingS * 2)
    height: menuColumn.implicitHeight + Theme.spacingS * 2
    padding: 0
    closePolicy: Popup.CloseOnPressOutside
    modal: false
    dim: false

    background: Rectangle {
        radius: Theme.cornerRadius
        color: Theme.popupBackground()
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
        border.width: 1

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
    }

    enter: Transition {
        NumberAnimation {
            property: "opacity"
            from: 0
            to: 1
            duration: Theme.shortDuration
            easing.type: Theme.emphasizedEasing
        }
    }

    exit: Transition {
        NumberAnimation {
            property: "opacity"
            from: 1
            to: 0
            duration: Theme.shortDuration
            easing.type: Theme.emphasizedEasing
        }
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
                            return I18n.tr("Pin to Dock")

                        const appId = contextMenu.currentApp.desktopEntry.id || contextMenu.currentApp.desktopEntry.execString || ""
                        return SessionData.isPinnedApp(appId) ? I18n.tr("Unpin from Dock") : I18n.tr("Pin to Dock")
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
                               contextMenu.hide()
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

        Repeater {
            model: contextMenu.currentApp && contextMenu.currentApp.desktopEntry && contextMenu.currentApp.desktopEntry.actions ? contextMenu.currentApp.desktopEntry.actions : []

            Rectangle {
                width: parent.width
                height: 32
                radius: Theme.cornerRadius
                color: actionMouseArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingS
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spacingS
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingS

                    Item {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.iconSize - 2
                        height: Theme.iconSize - 2
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
                        text: modelData.name || ""
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceText
                        font.weight: Font.Normal
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        width: parent.width - (modelData.icon && modelData.icon !== "" ? (Theme.iconSize - 2 + Theme.spacingS) : 0)
                    }
                }

                MouseArea {
                    id: actionMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (modelData && contextMenu.currentApp && contextMenu.currentApp.desktopEntry) {
                            SessionService.launchDesktopAction(contextMenu.currentApp.desktopEntry, modelData)
                            if (appLauncher) {
                                appLauncher.appLaunched(contextMenu.currentApp)
                            }
                        }
                        contextMenu.hide()
                    }
                }
            }
        }

        Rectangle {
            visible: contextMenu.currentApp && contextMenu.currentApp.desktopEntry && contextMenu.currentApp.desktopEntry.actions && contextMenu.currentApp.desktopEntry.actions.length > 0
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
                    text: I18n.tr("Launch")
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

                               contextMenu.hide()
                           }
            }
        }

        Rectangle {
            visible: SessionService.hasPrimeRun
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
            visible: SessionService.hasPrimeRun
            width: parent.width
            height: 32
            radius: Theme.cornerRadius
            color: primeRunMouseArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"

            Row {
                anchors.left: parent.left
                anchors.leftMargin: Theme.spacingS
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingS

                DankIcon {
                    name: "memory"
                    size: Theme.iconSize - 2
                    color: Theme.surfaceText
                    opacity: 0.7
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: I18n.tr("Launch on dGPU")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                    font.weight: Font.Normal
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                id: primeRunMouseArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: () => {
                               if (contextMenu.currentApp && contextMenu.currentApp.desktopEntry) {
                                   SessionService.launchDesktopEntry(contextMenu.currentApp.desktopEntry, true)
                                   if (appLauncher) {
                                       appLauncher.appLaunched(contextMenu.currentApp)
                                   }
                               }
                               contextMenu.hide()
                           }
            }
        }
    }
}
