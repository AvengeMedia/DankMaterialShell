import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property bool isVertical: axis?.isVertical ?? false
    property var axis: null
    property string section: "left"
    property var parentScreen
    property var hoveredItem: null
    property var topBar: null
    property real widgetThickness: 30
    property real barThickness: 48
    readonly property real horizontalPadding: SettingsData.dankBarNoBackground ? 2 : Theme.spacingS
    property Item windowRoot: (Window.window ? Window.window.contentItem : null)
    property int _workspaceUpdateTrigger: 0
    property int _desktopEntriesUpdateTrigger: 0
    readonly property var sortedToplevels: {
        _workspaceUpdateTrigger
        const toplevels = CompositorService.sortedToplevels
        if (!toplevels || toplevels.length === 0)
            return []

        if (SettingsData.runningAppsCurrentWorkspace) {
            const filtered = CompositorService.filterCurrentWorkspace(toplevels, parentScreen?.name)
            return filtered || []
        }
        return toplevels
    }

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() {
            _desktopEntriesUpdateTrigger++
        }
    }
    readonly property var groupedWindows: {
        if (!SettingsData.runningAppsGroupByApp) {
            return []
        }
        try {
            if (!sortedToplevels || sortedToplevels.length === 0) {
                return []
            }
            const appGroups = new Map()
            sortedToplevels.forEach((toplevel, index) => {
                                        if (!toplevel)
                                        return
                                        const appId = toplevel?.appId || "unknown"
                                        if (!appGroups.has(appId)) {
                                            appGroups.set(appId, {
                                                              "appId": appId,
                                                              "windows": []
                                                          })
                                        }
                                        appGroups.get(appId).windows.push({
                                                                              "toplevel": toplevel,
                                                                              "windowId": index,
                                                                              "windowTitle": toplevel?.title || "(Unnamed)"
                                                                          })
                                    })
            return Array.from(appGroups.values())
        } catch (e) {
            console.error("RunningApps: groupedWindows error:", e)
            return []
        }
    }
    readonly property int windowCount: SettingsData.runningAppsGroupByApp ? (groupedWindows?.length || 0) : (sortedToplevels?.length || 0)
    readonly property int calculatedSize: {
        if (windowCount === 0) {
            return 0
        }
        if (SettingsData.runningAppsCompactMode) {
            return windowCount * 24 + (windowCount - 1) * Theme.spacingXS + horizontalPadding * 2
        } else {
            return windowCount * (24 + Theme.spacingXS + 120) + (windowCount - 1) * Theme.spacingXS + horizontalPadding * 2
        }
    }

    width: isVertical ? barThickness : calculatedSize
    height: isVertical ? calculatedSize : barThickness
    visible: windowCount > 0

    Connections {
        target: NiriService
        function onAllWorkspacesChanged() {
            _workspaceUpdateTrigger++
        }
        function onWindowsChanged() {
            _workspaceUpdateTrigger++
        }
    }

    Connections {
        target: Hyprland
        function onFocusedWorkspaceChanged() {
            _workspaceUpdateTrigger++
        }
    }

    Connections {
        target: Hyprland.workspaces
        function onValuesChanged() {
            _workspaceUpdateTrigger++
        }
    }

    Connections {
        target: Hyprland.toplevels
        function onValuesChanged() {
            _workspaceUpdateTrigger++
        }
    }

    Rectangle {
        id: visualBackground
        width: root.isVertical ? root.widgetThickness : root.calculatedSize
        height: root.isVertical ? root.calculatedSize : root.widgetThickness
        anchors.centerIn: parent
        radius: SettingsData.dankBarNoBackground ? 0 : Theme.cornerRadius
        clip: false
        color: {
            if (windowCount === 0) {
                return "transparent"
            }

            if (SettingsData.dankBarNoBackground) {
                return "transparent"
            }

            const baseColor = Theme.widgetBaseBackgroundColor
            return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a * Theme.widgetTransparency)
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton

        property real scrollAccumulator: 0
        property real touchpadThreshold: 500

        onWheel: wheel => {
                     const deltaY = wheel.angleDelta.y
                     const isMouseWheel = Math.abs(deltaY) >= 120 && (Math.abs(deltaY) % 120) === 0

                     const windows = root.sortedToplevels
                     if (windows.length < 2) {
                         return
                     }

                     if (isMouseWheel) {
                         // Direct mouse wheel action
                         let currentIndex = -1
                         for (var i = 0; i < windows.length; i++) {
                             if (windows[i].activated) {
                                 currentIndex = i
                                 break
                             }
                         }

                         let nextIndex
                         if (deltaY < 0) {
                             if (currentIndex === -1) {
                                 nextIndex = 0
                             } else {
                                 nextIndex = (currentIndex + 1) % windows.length
                             }
                         } else {
                             if (currentIndex === -1) {
                                 nextIndex = windows.length - 1
                             } else {
                                 nextIndex = (currentIndex - 1 + windows.length) % windows.length
                             }
                         }

                         const nextWindow = windows[nextIndex]
                         if (nextWindow) {
                             nextWindow.activate()
                         }
                     } else {
                         // Touchpad - accumulate small deltas
                         scrollAccumulator += deltaY

                         if (Math.abs(scrollAccumulator) >= touchpadThreshold) {
                             let currentIndex = -1
                             for (var i = 0; i < windows.length; i++) {
                                 if (windows[i].activated) {
                                     currentIndex = i
                                     break
                                 }
                             }

                             let nextIndex
                             if (scrollAccumulator < 0) {
                                 if (currentIndex === -1) {
                                     nextIndex = 0
                                 } else {
                                     nextIndex = (currentIndex + 1) % windows.length
                                 }
                             } else {
                                 if (currentIndex === -1) {
                                     nextIndex = windows.length - 1
                                 } else {
                                     nextIndex = (currentIndex - 1 + windows.length) % windows.length
                                 }
                             }

                             const nextWindow = windows[nextIndex]
                             if (nextWindow) {
                                 nextWindow.activate()
                             }

                             scrollAccumulator = 0
                         }
                     }

                     wheel.accepted = true
                 }
    }

    Loader {
        id: layoutLoader
        anchors.centerIn: parent
        sourceComponent: root.isVertical ? columnLayout : rowLayout
    }

    Component {
        id: rowLayout
        Row {
            spacing: Theme.spacingXS

            Repeater {
                id: windowRepeater
                model: SettingsData.runningAppsGroupByApp ? groupedWindows : sortedToplevels

                delegate: Item {
                    id: delegateItem

                    property bool isGrouped: SettingsData.runningAppsGroupByApp
                    property var groupData: isGrouped ? modelData : null
                    property var toplevelData: isGrouped ? (modelData.windows.length > 0 ? modelData.windows[0].toplevel : null) : modelData
                    property bool isFocused: toplevelData ? toplevelData.activated : false
                    property string appId: isGrouped ? modelData.appId : (modelData.appId || "")
                    property string windowTitle: toplevelData ? (toplevelData.title || "(Unnamed)") : "(Unnamed)"
                    property var toplevelObject: toplevelData
                    property int windowCount: isGrouped ? modelData.windows.length : 1
                    property string tooltipText: {
                        root._desktopEntriesUpdateTrigger
                        let appName = "Unknown"
                        if (appId) {
                            const desktopEntry = DesktopEntries.heuristicLookup(appId)
                            appName = desktopEntry && desktopEntry.name ? desktopEntry.name : appId
                        }
                        if (isGrouped && windowCount > 1) {
                            return appName + " (" + windowCount + " windows)"
                        }
                        return appName + (windowTitle ? " • " + windowTitle : "")
                    }
                    readonly property real visualWidth: SettingsData.runningAppsCompactMode ? 24 : (24 + Theme.spacingXS + 120)

                    width: visualWidth
                    height: root.barThickness

                    Rectangle {
                        id: visualContent
                        width: delegateItem.visualWidth
                        height: 24
                        anchors.centerIn: parent
                        radius: Theme.cornerRadius
                        color: {
                            if (isFocused) {
                                return mouseArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.3) : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2)
                            } else {
                                return mouseArea.containsMouse ? Qt.rgba(Theme.primaryHover.r, Theme.primaryHover.g, Theme.primaryHover.b, 0.1) : "transparent"
                            }
                        }

                        // App icon
                        IconImage {
                            id: iconImg
                            anchors.left: parent.left
                            anchors.leftMargin: SettingsData.runningAppsCompactMode ? (parent.width - Theme.barIconSize(root.barThickness)) / 2 : Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter
                            width: Theme.barIconSize(root.barThickness)
                            height: Theme.barIconSize(root.barThickness)
                            source: {
                                root._desktopEntriesUpdateTrigger
                                const moddedId = Paths.moddedAppId(appId)
                                if (moddedId.toLowerCase().includes("steam_app")) {
                                    return ""
                                }
                                return Quickshell.iconPath(DesktopEntries.heuristicLookup(moddedId)?.icon, true)
                            }
                            smooth: true
                            mipmap: true
                            asynchronous: true
                            visible: status === Image.Ready
                        }

                        DankIcon {
                            anchors.left: parent.left
                            anchors.leftMargin: SettingsData.runningAppsCompactMode ? (parent.width - Theme.barIconSize(root.barThickness)) / 2 : Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter
                            size: Theme.barIconSize(root.barThickness)
                            name: "sports_esports"
                            color: Theme.surfaceText
                            visible: {
                                const moddedId = Paths.moddedAppId(appId)
                                return moddedId.toLowerCase().includes("steam_app")
                            }
                        }

                        // Fallback text if no icon found
                        Text {
                            anchors.centerIn: parent
                            visible: {
                                const moddedId = Paths.moddedAppId(appId)
                                const isSteamApp = moddedId.toLowerCase().includes("steam_app")
                                return !iconImg.visible && !isSteamApp
                            }
                            text: {
                                root._desktopEntriesUpdateTrigger
                                if (!appId) {
                                    return "?"
                                }

                                const desktopEntry = DesktopEntries.heuristicLookup(appId)
                                if (desktopEntry && desktopEntry.name) {
                                    return desktopEntry.name.charAt(0).toUpperCase()
                                }

                                return appId.charAt(0).toUpperCase()
                            }
                            font.pixelSize: 10
                            color: Theme.surfaceText
                        }

                        Rectangle {
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.rightMargin: SettingsData.runningAppsCompactMode ? -2 : 2
                            anchors.bottomMargin: -2
                            width: 14
                            height: 14
                            radius: 7
                            color: Theme.primary
                            visible: isGrouped && windowCount > 1
                            z: 10

                            StyledText {
                                anchors.centerIn: parent
                                text: windowCount > 9 ? "9+" : windowCount
                                font.pixelSize: 9
                                color: Theme.surface
                            }
                        }

                        // Window title text (only visible in expanded mode)
                        StyledText {
                            anchors.left: iconImg.right
                            anchors.leftMargin: Theme.spacingXS
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !SettingsData.runningAppsCompactMode
                            text: windowTitle
                            font.pixelSize: Theme.barTextSize(barThickness)
                            color: Theme.surfaceText
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }
                    }

                    MouseArea {
                        id: mouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: mouse => {
                                       if (mouse.button === Qt.LeftButton) {
                                           if (isGrouped && windowCount > 1) {
                                               let currentIndex = -1
                                               for (var i = 0; i < groupData.windows.length; i++) {
                                                   if (groupData.windows[i].toplevel.activated) {
                                                       currentIndex = i
                                                       break
                                                   }
                                               }
                                               const nextIndex = (currentIndex + 1) % groupData.windows.length
                                               groupData.windows[nextIndex].toplevel.activate()
                                           } else if (toplevelObject) {
                                               toplevelObject.activate()
                                           }
                                       } else if (mouse.button === Qt.RightButton) {
                                           if (tooltipLoader.item) {
                                               tooltipLoader.item.hide()
                                           }
                                           tooltipLoader.active = false

                                           windowContextMenuLoader.active = true
                                           if (windowContextMenuLoader.item) {
                                               windowContextMenuLoader.item.currentWindow = toplevelObject
                                               if (root.isVertical) {
                                                   const globalPos = delegateItem.mapToGlobal(delegateItem.width / 2, delegateItem.height / 2)
                                                   const screenX = root.parentScreen ? root.parentScreen.x : 0
                                                   const screenY = root.parentScreen ? root.parentScreen.y : 0
                                                   const relativeY = globalPos.y - screenY
                                                   const xPos = root.axis?.edge === "left" ? (Theme.barHeight + SettingsData.dankBarSpacing + Theme.spacingXS) : (root.parentScreen.width - Theme.barHeight - SettingsData.dankBarSpacing - Theme.spacingXS)
                                                   windowContextMenuLoader.item.showAt(xPos, relativeY, true, root.axis?.edge)
                                               } else {
                                                   const globalPos = delegateItem.mapToGlobal(delegateItem.width / 2, 0)
                                                   const screenX = root.parentScreen ? root.parentScreen.x : 0
                                                   const relativeX = globalPos.x - screenX
                                                   const yPos = Theme.barHeight + SettingsData.dankBarSpacing - 7
                                                   windowContextMenuLoader.item.showAt(relativeX, yPos, false, "top")
                                               }
                                           }
                                       }
                                   }
                        onEntered: {
                            root.hoveredItem = delegateItem
                            tooltipLoader.active = true
                            if (tooltipLoader.item) {
                                if (root.isVertical) {
                                    const globalPos = delegateItem.mapToGlobal(delegateItem.width / 2, delegateItem.height / 2)
                                    const screenX = root.parentScreen ? root.parentScreen.x : 0
                                    const screenY = root.parentScreen ? root.parentScreen.y : 0
                                    const relativeY = globalPos.y - screenY
                                    const tooltipX = root.axis?.edge === "left" ? (Theme.barHeight + SettingsData.dankBarSpacing + Theme.spacingXS) : (root.parentScreen.width - Theme.barHeight - SettingsData.dankBarSpacing - Theme.spacingXS)
                                    const isLeft = root.axis?.edge === "left"
                                    tooltipLoader.item.show(delegateItem.tooltipText, screenX + tooltipX, relativeY, root.parentScreen, isLeft, !isLeft)
                                } else {
                                    const globalPos = delegateItem.mapToGlobal(delegateItem.width / 2, delegateItem.height)
                                    const tooltipY = Theme.barHeight + SettingsData.dankBarSpacing + Theme.spacingXS
                                    tooltipLoader.item.show(delegateItem.tooltipText, globalPos.x, tooltipY, root.parentScreen, false, false)
                                }
                            }
                        }
                        onExited: {
                            if (root.hoveredItem === delegateItem) {
                                root.hoveredItem = null
                                if (tooltipLoader.item) {
                                    tooltipLoader.item.hide()
                                }

                                tooltipLoader.active = false
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: columnLayout
        Column {
            spacing: Theme.spacingXS

            Repeater {
                id: windowRepeater
                model: SettingsData.runningAppsGroupByApp ? groupedWindows : sortedToplevels

                delegate: Item {
                    id: delegateItem

                    property bool isGrouped: SettingsData.runningAppsGroupByApp
                    property var groupData: isGrouped ? modelData : null
                    property var toplevelData: isGrouped ? (modelData.windows.length > 0 ? modelData.windows[0].toplevel : null) : modelData
                    property bool isFocused: toplevelData ? toplevelData.activated : false
                    property string appId: isGrouped ? modelData.appId : (modelData.appId || "")
                    property string windowTitle: toplevelData ? (toplevelData.title || "(Unnamed)") : "(Unnamed)"
                    property var toplevelObject: toplevelData
                    property int windowCount: isGrouped ? modelData.windows.length : 1
                    property string tooltipText: {
                        root._desktopEntriesUpdateTrigger
                        let appName = "Unknown"
                        if (appId) {
                            const desktopEntry = DesktopEntries.heuristicLookup(appId)
                            appName = desktopEntry && desktopEntry.name ? desktopEntry.name : appId
                        }
                        if (isGrouped && windowCount > 1) {
                            return appName + " (" + windowCount + " windows)"
                        }
                        return appName + (windowTitle ? " • " + windowTitle : "")
                    }
                    readonly property real visualWidth: SettingsData.runningAppsCompactMode ? 24 : (24 + Theme.spacingXS + 120)

                    width: root.barThickness
                    height: 24

                    Rectangle {
                        id: visualContent
                        width: delegateItem.visualWidth
                        height: 24
                        anchors.centerIn: parent
                        radius: Theme.cornerRadius
                        color: {
                            if (isFocused) {
                                return mouseArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.3) : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2)
                            } else {
                                return mouseArea.containsMouse ? Qt.rgba(Theme.primaryHover.r, Theme.primaryHover.g, Theme.primaryHover.b, 0.1) : "transparent"
                            }
                        }

                        IconImage {
                            id: iconImg
                            anchors.left: parent.left
                            anchors.leftMargin: SettingsData.runningAppsCompactMode ? (parent.width - Theme.barIconSize(root.barThickness)) / 2 : Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter
                            width: Theme.barIconSize(root.barThickness)
                            height: Theme.barIconSize(root.barThickness)
                            source: {
                                root._desktopEntriesUpdateTrigger
                                const moddedId = Paths.moddedAppId(appId)
                                if (moddedId.toLowerCase().includes("steam_app")) {
                                    return ""
                                }
                                return Quickshell.iconPath(DesktopEntries.heuristicLookup(moddedId)?.icon, true)
                            }
                            smooth: true
                            mipmap: true
                            asynchronous: true
                            visible: status === Image.Ready
                        }

                        DankIcon {
                            anchors.left: parent.left
                            anchors.leftMargin: SettingsData.runningAppsCompactMode ? (parent.width - Theme.barIconSize(root.barThickness)) / 2 : Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter
                            size: Theme.barIconSize(root.barThickness)
                            name: "sports_esports"
                            color: Theme.surfaceText
                            visible: {
                                const moddedId = Paths.moddedAppId(appId)
                                return moddedId.toLowerCase().includes("steam_app")
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: {
                                const moddedId = Paths.moddedAppId(appId)
                                const isSteamApp = moddedId.toLowerCase().includes("steam_app")
                                return !iconImg.visible && !isSteamApp
                            }
                            text: {
                                root._desktopEntriesUpdateTrigger
                                if (!appId) {
                                    return "?"
                                }

                                const desktopEntry = DesktopEntries.heuristicLookup(appId)
                                if (desktopEntry && desktopEntry.name) {
                                    return desktopEntry.name.charAt(0).toUpperCase()
                                }

                                return appId.charAt(0).toUpperCase()
                            }
                            font.pixelSize: 10
                            color: Theme.surfaceText
                        }

                        Rectangle {
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.rightMargin: SettingsData.runningAppsCompactMode ? -2 : 2
                            anchors.bottomMargin: -2
                            width: 14
                            height: 14
                            radius: 7
                            color: Theme.primary
                            visible: isGrouped && windowCount > 1
                            z: 10

                            StyledText {
                                anchors.centerIn: parent
                                text: windowCount > 9 ? "9+" : windowCount
                                font.pixelSize: 9
                                color: Theme.surface
                            }
                        }

                        StyledText {
                            anchors.left: iconImg.right
                            anchors.leftMargin: Theme.spacingXS
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !SettingsData.runningAppsCompactMode
                            text: windowTitle
                            font.pixelSize: Theme.barTextSize(barThickness)
                            color: Theme.surfaceText
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }
                    }

                    MouseArea {
                        id: mouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: mouse => {
                                       if (mouse.button === Qt.LeftButton) {
                                           if (isGrouped && windowCount > 1) {
                                               let currentIndex = -1
                                               for (var i = 0; i < groupData.windows.length; i++) {
                                                   if (groupData.windows[i].toplevel.activated) {
                                                       currentIndex = i
                                                       break
                                                   }
                                               }
                                               const nextIndex = (currentIndex + 1) % groupData.windows.length
                                               groupData.windows[nextIndex].toplevel.activate()
                                           } else if (toplevelObject) {
                                               toplevelObject.activate()
                                           }
                                       } else if (mouse.button === Qt.RightButton) {
                                           if (tooltipLoader.item) {
                                               tooltipLoader.item.hide()
                                           }
                                           tooltipLoader.active = false

                                           windowContextMenuLoader.active = true
                                           if (windowContextMenuLoader.item) {
                                               windowContextMenuLoader.item.currentWindow = toplevelObject
                                               if (root.isVertical) {
                                                   const globalPos = delegateItem.mapToGlobal(delegateItem.width / 2, delegateItem.height / 2)
                                                   const screenX = root.parentScreen ? root.parentScreen.x : 0
                                                   const screenY = root.parentScreen ? root.parentScreen.y : 0
                                                   const relativeY = globalPos.y - screenY
                                                   const xPos = root.axis?.edge === "left" ? (Theme.barHeight + SettingsData.dankBarSpacing + Theme.spacingXS) : (root.parentScreen.width - Theme.barHeight - SettingsData.dankBarSpacing - Theme.spacingXS)
                                                   windowContextMenuLoader.item.showAt(xPos, relativeY, true, root.axis?.edge)
                                               } else {
                                                   const globalPos = delegateItem.mapToGlobal(delegateItem.width / 2, 0)
                                                   const screenX = root.parentScreen ? root.parentScreen.x : 0
                                                   const relativeX = globalPos.x - screenX
                                                   const yPos = Theme.barHeight + SettingsData.dankBarSpacing - 7
                                                   windowContextMenuLoader.item.showAt(relativeX, yPos, false, "top")
                                               }
                                           }
                                       }
                                   }
                        onEntered: {
                            root.hoveredItem = delegateItem
                            tooltipLoader.active = true
                            if (tooltipLoader.item) {
                                if (root.isVertical) {
                                    const globalPos = delegateItem.mapToGlobal(delegateItem.width / 2, delegateItem.height / 2)
                                    const screenX = root.parentScreen ? root.parentScreen.x : 0
                                    const screenY = root.parentScreen ? root.parentScreen.y : 0
                                    const relativeY = globalPos.y - screenY
                                    const tooltipX = root.axis?.edge === "left" ? (Theme.barHeight + SettingsData.dankBarSpacing + Theme.spacingXS) : (root.parentScreen.width - Theme.barHeight - SettingsData.dankBarSpacing - Theme.spacingXS)
                                    const isLeft = root.axis?.edge === "left"
                                    tooltipLoader.item.show(delegateItem.tooltipText, screenX + tooltipX, relativeY, root.parentScreen, isLeft, !isLeft)
                                } else {
                                    const globalPos = delegateItem.mapToGlobal(delegateItem.width / 2, delegateItem.height)
                                    const tooltipY = Theme.barHeight + SettingsData.dankBarSpacing + Theme.spacingXS
                                    tooltipLoader.item.show(delegateItem.tooltipText, globalPos.x, tooltipY, root.parentScreen, false, false)
                                }
                            }
                        }
                        onExited: {
                            if (root.hoveredItem === delegateItem) {
                                root.hoveredItem = null
                                if (tooltipLoader.item) {
                                    tooltipLoader.item.hide()
                                }

                                tooltipLoader.active = false
                            }
                        }
                    }
                }
            }
        }
    }

    Loader {
        id: tooltipLoader

        active: false

        sourceComponent: DankTooltip {}
    }

    Loader {
        id: windowContextMenuLoader
        active: false
        sourceComponent: PanelWindow {
            id: contextMenuWindow

            property var currentWindow: null
            property bool isVisible: false
            property point anchorPos: Qt.point(0, 0)
            property bool isVertical: false
            property string edge: "top"

            function showAt(x, y, vertical, barEdge) {
                screen = root.parentScreen
                anchorPos = Qt.point(x, y)
                isVertical = vertical ?? false
                edge = barEdge ?? "top"
                isVisible = true
                visible = true
            }

            function close() {
                isVisible = false
                visible = false
                windowContextMenuLoader.active = false
            }

            implicitWidth: 100
            implicitHeight: 40
            visible: false
            color: "transparent"

            WlrLayershell.layer: WlrLayershell.Overlay
            WlrLayershell.exclusiveZone: -1
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            anchors {
                top: true
                left: true
                right: true
                bottom: true
            }

            MouseArea {
                anchors.fill: parent
                onClicked: contextMenuWindow.close()
            }

            Rectangle {
                x: {
                    if (contextMenuWindow.isVertical) {
                        if (contextMenuWindow.edge === "left") {
                            return Math.min(contextMenuWindow.width - width - 10, contextMenuWindow.anchorPos.x)
                        } else {
                            return Math.max(10, contextMenuWindow.anchorPos.x - width)
                        }
                    } else {
                        const left = 10
                        const right = contextMenuWindow.width - width - 10
                        const want = contextMenuWindow.anchorPos.x - width / 2
                        return Math.max(left, Math.min(right, want))
                    }
                }
                y: {
                    if (contextMenuWindow.isVertical) {
                        const top = 10
                        const bottom = contextMenuWindow.height - height - 10
                        const want = contextMenuWindow.anchorPos.y - height / 2
                        return Math.max(top, Math.min(bottom, want))
                    } else {
                        return contextMenuWindow.anchorPos.y
                    }
                }
                width: 100
                height: 32
                color: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
                radius: Theme.cornerRadius
                border.width: 1
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: closeMouseArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : "transparent"
                }

                StyledText {
                    anchors.centerIn: parent
                    text: I18n.tr("Close")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                }

                MouseArea {
                    id: closeMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (contextMenuWindow.currentWindow) {
                            contextMenuWindow.currentWindow.close()
                        }
                        contextMenuWindow.close()
                    }
                }
            }
        }
    }
}
