import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    clip: false
    property var appData
    property var contextMenu: null
    property var dockApps: null
    property int index: -1
    property var parentDockScreen: null
    property bool longPressing: false
    property bool dragging: false
    property point dragStartPos: Qt.point(0, 0)
    property point dragOffset: Qt.point(0, 0)
    property int targetIndex: -1
    property int originalIndex: -1
    property bool showWindowTitle: false
    property string windowTitle: ""
    property bool isHovered: mouseArea.containsMouse && !dragging
    property bool showTooltip: mouseArea.containsMouse && !dragging
    property var cachedDesktopEntry: null
    property real actualIconSize: 40

    function updateDesktopEntry() {
        if (!appData || appData.appId === "__SEPARATOR__") {
            cachedDesktopEntry = null
            return
        }
        const moddedId = Paths.moddedAppId(appData.appId)
        cachedDesktopEntry = DesktopEntries.heuristicLookup(moddedId)
    }

    Component.onCompleted: updateDesktopEntry()

    onAppDataChanged: updateDesktopEntry()

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() {
            updateDesktopEntry()
        }
    }
    property bool isWindowFocused: {
        if (!appData) {
            return false
        }

        if (appData.type === "window") {
            const toplevel = getToplevelObject()
            if (!toplevel) {
                return false
            }
            return toplevel.activated
        } else if (appData.type === "grouped") {
            // For grouped apps, check if any window is focused
            const allToplevels = ToplevelManager.toplevels.values
            for (let i = 0; i < allToplevels.length; i++) {
                const toplevel = allToplevels[i]
                if (toplevel.appId === appData.appId && toplevel.activated) {
                    return true
                }
            }
        }

        return false
    }
    property string tooltipText: {
        if (!appData) {
            return ""
        }

        if ((appData.type === "window" && showWindowTitle) || (appData.type === "grouped" && appData.windowTitle)) {
            const appName = cachedDesktopEntry && cachedDesktopEntry.name ? cachedDesktopEntry.name : appData.appId
            const title = appData.type === "window" ? windowTitle : appData.windowTitle
            return appName + (title ? " • " + title : "")
        }

        if (!appData.appId) {
            return ""
        }

        return cachedDesktopEntry && cachedDesktopEntry.name ? cachedDesktopEntry.name : appData.appId
    }

    function getToplevelObject() {
        if (!appData) {
            return null
        }

        const sortedToplevels = CompositorService.sortedToplevels
        if (!sortedToplevels) {
            return null
        }

        if (appData.type === "window") {
            if (appData.uniqueId) {
                for (var i = 0; i < sortedToplevels.length; i++) {
                    const toplevel = sortedToplevels[i]
                    const checkId = toplevel.title + "|" + (toplevel.appId || "") + "|" + i
                    if (checkId === appData.uniqueId) {
                        return toplevel
                    }
                }
            }

            if (appData.windowId !== undefined && appData.windowId !== null && appData.windowId >= 0) {
                if (appData.windowId < sortedToplevels.length) {
                    return sortedToplevels[appData.windowId]
                }
            }
        } else if (appData.type === "grouped") {
            if (appData.windowId !== undefined && appData.windowId !== null && appData.windowId >= 0) {
                if (appData.windowId < sortedToplevels.length) {
                    return sortedToplevels[appData.windowId]
                }
            }
        }

        return null
    }

    function getGroupedToplevels() {
        if (!appData || appData.type !== "grouped") {
            return []
        }

        const toplevels = []
        const allToplevels = ToplevelManager.toplevels.values
        for (let i = 0; i < allToplevels.length; i++) {
            const toplevel = allToplevels[i]
            if (toplevel.appId === appData.appId) {
                toplevels.push(toplevel)
            }
        }
        return toplevels
    }
    onIsHoveredChanged: {
        if (mouseArea.pressed) return

        if (isHovered) {
            exitAnimation.stop()
            if (!bounceAnimation.running) {
                bounceAnimation.restart()
            }
        } else {
            bounceAnimation.stop()
            exitAnimation.restart()
        }
    }

    readonly property bool animateX: SettingsData.dockPosition === SettingsData.Position.Left || SettingsData.dockPosition === SettingsData.Position.Right
    readonly property real animationDistance: actualIconSize
    readonly property real animationDirection: {
        if (SettingsData.dockPosition === SettingsData.Position.Bottom) return -1
        if (SettingsData.dockPosition === SettingsData.Position.Top) return 1
        if (SettingsData.dockPosition === SettingsData.Position.Right) return -1
        if (SettingsData.dockPosition === SettingsData.Position.Left) return 1
        return -1
    }

    SequentialAnimation {
        id: bounceAnimation

        running: false

        NumberAnimation {
            target: iconTransform
            property: animateX ? "x" : "y"
            to: animationDirection * animationDistance * 0.25
            duration: Anims.durShort
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Anims.emphasizedAccel
        }

        NumberAnimation {
            target: iconTransform
            property: animateX ? "x" : "y"
            to: animationDirection * animationDistance * 0.2
            duration: Anims.durShort
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Anims.emphasizedDecel
        }
    }

    NumberAnimation {
        id: exitAnimation

        running: false
        target: iconTransform
        property: animateX ? "x" : "y"
        to: 0
        duration: Anims.durShort
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Anims.emphasizedDecel
    }

    Timer {
        id: longPressTimer

        interval: 500
        repeat: false
        onTriggered: {
            if (appData && appData.isPinned) {
                longPressing = true
            }
        }
    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: longPressing ? Qt.DragMoveCursor : Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onPressed: mouse => {
                       if (mouse.button === Qt.LeftButton && appData && appData.isPinned) {
                           dragStartPos = Qt.point(mouse.x, mouse.y)
                           longPressTimer.start()
                       }
                   }
        onReleased: mouse => {
                        longPressTimer.stop()
                        if (longPressing) {
                            if (dragging && targetIndex >= 0 && targetIndex !== originalIndex && dockApps) {
                                dockApps.movePinnedApp(originalIndex, targetIndex)
                            }

                            longPressing = false
                            dragging = false
                            dragOffset = Qt.point(0, 0)
                            targetIndex = -1
                            originalIndex = -1
                        }
                    }
        onPositionChanged: mouse => {
                               if (longPressing && !dragging) {
                                   const distance = Math.sqrt(Math.pow(mouse.x - dragStartPos.x, 2) + Math.pow(mouse.y - dragStartPos.y, 2))
                                   if (distance > 5) {
                                       dragging = true
                                       targetIndex = index
                                       originalIndex = index
                                   }
                               }
                               if (dragging) {
                                   dragOffset = Qt.point(mouse.x - dragStartPos.x, mouse.y - dragStartPos.y)
                                   if (dockApps) {
                                       const threshold = actualIconSize
                                       let newTargetIndex = targetIndex
                                       if (dragOffset.x > threshold && targetIndex < dockApps.pinnedAppCount - 1) {
                                           newTargetIndex = targetIndex + 1
                                       } else if (dragOffset.x < -threshold && targetIndex > 0) {
                                           newTargetIndex = targetIndex - 1
                                       }
                                       if (newTargetIndex !== targetIndex) {
                                           targetIndex = newTargetIndex
                                           dragStartPos = Qt.point(mouse.x, mouse.y)
                                       }
                                   }
                               }
                           }
        onClicked: mouse => {
                       if (!appData || longPressing) {
                           return
                       }

                       if (mouse.button === Qt.LeftButton) {
                           if (appData.type === "pinned") {
                               if (appData && appData.appId) {
                                   const desktopEntry = cachedDesktopEntry
                                   if (desktopEntry) {
                                       AppUsageHistoryData.addAppUsage({
                                                                           "id": appData.appId,
                                                                           "name": desktopEntry.name || appData.appId,
                                                                           "icon": desktopEntry.icon || "",
                                                                           "exec": desktopEntry.exec || "",
                                                                           "comment": desktopEntry.comment || ""
                                                                       })
                                   }
                                   SessionService.launchDesktopEntry(desktopEntry)
                               }
                           } else if (appData.type === "window") {
                               const toplevel = getToplevelObject()
                               if (toplevel) {
                                   toplevel.activate()
                               }
                           } else if (appData.type === "grouped") {
                               if (appData.windowCount === 0) {
                                   if (appData && appData.appId) {
                                       const desktopEntry = cachedDesktopEntry
                                       if (desktopEntry) {
                                           AppUsageHistoryData.addAppUsage({
                                                                               "id": appData.appId,
                                                                               "name": desktopEntry.name || appData.appId,
                                                                               "icon": desktopEntry.icon || "",
                                                                               "exec": desktopEntry.exec || "",
                                                                               "comment": desktopEntry.comment || ""
                                                                           })
                                       }
                                       SessionService.launchDesktopEntry(desktopEntry)
                                   }
                               } else if (appData.windowCount === 1) {
                                   // For single window, activate directly
                                   const toplevel = getToplevelObject()
                                   if (toplevel) {
                                       console.log("Activating grouped app window:", appData.windowTitle)
                                       toplevel.activate()
                                   } else {
                                       console.warn("No toplevel found for grouped app")
                                   }
                               } else {
                                   if (contextMenu) {
                                       contextMenu.showForButton(root, appData, root.height + 25, true, cachedDesktopEntry, parentDockScreen)
                                   }
                               }
                           }
                       } else if (mouse.button === Qt.MiddleButton) {
                           if (appData && appData.type === "window") {
                               const sortedToplevels = CompositorService.sortedToplevels
                               for (var i = 0; i < sortedToplevels.length; i++) {
                                   const toplevel = sortedToplevels[i]
                                   const checkId = toplevel.title + "|" + (toplevel.appId || "") + "|" + i
                                   if (checkId === appData.uniqueId) {
                                       toplevel.close()
                                       break
                                   }
                               }
                           } else if (appData && appData.type === "grouped") {
                               if (contextMenu) {
                                   contextMenu.showForButton(root, appData, root.height, false, cachedDesktopEntry, parentDockScreen)
                               }
                           } else if (appData && appData.appId) {
                               const desktopEntry = cachedDesktopEntry
                               if (desktopEntry) {
                                   AppUsageHistoryData.addAppUsage({
                                                                       "id": appData.appId,
                                                                       "name": desktopEntry.name || appData.appId,
                                                                       "icon": desktopEntry.icon || "",
                                                                       "exec": desktopEntry.exec || "",
                                                                       "comment": desktopEntry.comment || ""
                                                                   })
                               }
                               SessionService.launchDesktopEntry(desktopEntry)
                           }
                       } else if (mouse.button === Qt.RightButton) {
                           if (contextMenu && appData) {
                               contextMenu.showForButton(root, appData, root.height, false, cachedDesktopEntry, parentDockScreen)
                           } else {
                               console.warn("No context menu or appData available")
                           }
                       }
                   }
    }

    Item {
        id: visualContent
        anchors.fill: parent

        transform: Translate {
            id: iconTransform
            x: 0
            y: 0
        }

        Rectangle {
            anchors.fill: parent
            radius: Theme.cornerRadius
            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.3)
            border.width: 2
            border.color: Theme.primary
            visible: dragging
            z: -1
        }

        IconImage {
            id: iconImg

            anchors.centerIn: parent
            implicitSize: actualIconSize
            source: {
                if (appData.appId === "__SEPARATOR__") {
                    return ""
                }
                const moddedId = Paths.moddedAppId(appData.appId)
                if (moddedId.toLowerCase().includes("steam_app")) {
                    return ""
                }
                return cachedDesktopEntry && cachedDesktopEntry.icon ? Quickshell.iconPath(cachedDesktopEntry.icon, true) : ""
            }
            mipmap: true
            smooth: true
            asynchronous: true
            visible: status === Image.Ready
        }

        DankIcon {
            anchors.centerIn: parent
            size: actualIconSize
            name: "sports_esports"
            color: Theme.surfaceText
            visible: {
                if (!appData || !appData.appId || appData.appId === "__SEPARATOR__") {
                    return false
                }
                const moddedId = Paths.moddedAppId(appData.appId)
                return moddedId.toLowerCase().includes("steam_app")
            }
        }

        Rectangle {
            width: actualIconSize
            height: actualIconSize
            anchors.centerIn: parent
            visible: iconImg.status !== Image.Ready
            color: Theme.surfaceLight
            radius: Theme.cornerRadius
            border.width: 1
            border.color: Theme.primarySelected

            Text {
                anchors.centerIn: parent
                text: {
                    if (!appData || !appData.appId) {
                        return "?"
                    }

                    const desktopEntry = cachedDesktopEntry
                    if (desktopEntry && desktopEntry.name) {
                        return desktopEntry.name.charAt(0).toUpperCase()
                    }

                    return appData.appId.charAt(0).toUpperCase()
                }
                font.pixelSize: Math.max(8, parent.width * 0.35)
                color: Theme.primary
                font.weight: Font.Bold
            }
        }

        Loader {
            anchors.horizontalCenter: SettingsData.dockPosition === SettingsData.Position.Left || SettingsData.dockPosition === SettingsData.Position.Right ? undefined : parent.horizontalCenter
            anchors.verticalCenter: SettingsData.dockPosition === SettingsData.Position.Left || SettingsData.dockPosition === SettingsData.Position.Right ? parent.verticalCenter : undefined
            anchors.bottom: SettingsData.dockPosition === SettingsData.Position.Bottom ? parent.bottom : undefined
            anchors.top: SettingsData.dockPosition === SettingsData.Position.Top ? parent.top : undefined
            anchors.left: SettingsData.dockPosition === SettingsData.Position.Left ? parent.left : undefined
            anchors.right: SettingsData.dockPosition === SettingsData.Position.Right ? parent.right : undefined
            anchors.bottomMargin: SettingsData.dockPosition === SettingsData.Position.Bottom ? -2 : 0
            anchors.topMargin: SettingsData.dockPosition === SettingsData.Position.Top ? -2 : 0
            anchors.leftMargin: SettingsData.dockPosition === SettingsData.Position.Left ? -2 : 0
            anchors.rightMargin: SettingsData.dockPosition === SettingsData.Position.Right ? -2 : 0

            sourceComponent: SettingsData.dockPosition === SettingsData.Position.Left || SettingsData.dockPosition === SettingsData.Position.Right ? columnIndicator : rowIndicator

            visible: {
                if (!appData) return false
                if (appData.type === "window") return true
                if (appData.type === "grouped") return appData.windowCount > 0
                return appData.isRunning
            }
        }
    }

    Component {
        id: rowIndicator

        Row {
            spacing: 2

            Repeater {
                model: {
                    if (!appData) return 0
                    if (appData.type === "grouped") {
                        return Math.min(appData.windowCount, 4)
                    } else if (appData.type === "window" || appData.isRunning) {
                        return 1
                    }
                    return 0
                }

                Rectangle {
                    width: appData && appData.type === "grouped" && appData.windowCount > 1 ? Math.max(3, actualIconSize * 0.1) : Math.max(6, actualIconSize * 0.2)
                    height: Math.max(2, actualIconSize * 0.05)
                    radius: Theme.cornerRadius
                    color: {
                        if (!appData) {
                            return "transparent"
                        }

                        if (appData.type !== "grouped" || appData.windowCount === 1) {
                            if (isWindowFocused) {
                                return Theme.primary
                            }
                            return Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.6)
                        }

                        if (appData.type === "grouped" && appData.windowCount > 1) {
                            const groupToplevels = getGroupedToplevels()
                            if (index < groupToplevels.length && groupToplevels[index].activated) {
                                return Theme.primary
                            }
                        }

                        return Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.6)
                    }
                }
            }
        }
    }

    Component {
        id: columnIndicator

        Column {
            spacing: 2

            Repeater {
                model: {
                    if (!appData) return 0
                    if (appData.type === "grouped") {
                        return Math.min(appData.windowCount, 4)
                    } else if (appData.type === "window" || appData.isRunning) {
                        return 1
                    }
                    return 0
                }

                Rectangle {
                    width: Math.max(2, actualIconSize * 0.05)
                    height: appData && appData.type === "grouped" && appData.windowCount > 1 ? Math.max(3, actualIconSize * 0.1) : Math.max(6, actualIconSize * 0.2)
                    radius: Theme.cornerRadius
                    color: {
                        if (!appData) {
                            return "transparent"
                        }

                        if (appData.type !== "grouped" || appData.windowCount === 1) {
                            if (isWindowFocused) {
                                return Theme.primary
                            }
                            return Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.6)
                        }

                        if (appData.type === "grouped" && appData.windowCount > 1) {
                            const groupToplevels = getGroupedToplevels()
                            if (index < groupToplevels.length && groupToplevels[index].activated) {
                                return Theme.primary
                            }
                        }

                        return Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.6)
                    }
                }
            }
        }
    }
}
