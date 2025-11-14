import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property var contextMenu: null
    property bool requestDockShow: false
    property int pinnedAppCount: 0
    property bool groupByApp: false
    property bool isVertical: false
    property var dockScreen: null
    property real iconSize: 40

    clip: false
    implicitWidth: isVertical ? appLayout.height : appLayout.width
    implicitHeight: isVertical ? appLayout.width : appLayout.height

    function movePinnedApp(fromIndex, toIndex) {
        if (fromIndex === toIndex) {
            return
        }

        const currentPinned = [...(SessionData.pinnedApps || [])]
        if (fromIndex < 0 || fromIndex >= currentPinned.length || toIndex < 0 || toIndex >= currentPinned.length) {
            return
        }

        const movedApp = currentPinned.splice(fromIndex, 1)[0]
        currentPinned.splice(toIndex, 0, movedApp)

        SessionData.setPinnedApps(currentPinned)
    }

    Item {
        id: appLayout
        width: layoutFlow.width
        height: layoutFlow.height
        anchors.horizontalCenter: root.isVertical ? undefined : parent.horizontalCenter
        anchors.verticalCenter: root.isVertical ? parent.verticalCenter : undefined
        anchors.left: root.isVertical && SettingsData.dockPosition === SettingsData.Position.Left ? parent.left : undefined
        anchors.right: root.isVertical && SettingsData.dockPosition === SettingsData.Position.Right ? parent.right : undefined
        anchors.top: root.isVertical ? undefined : parent.top

        Flow {
            id: layoutFlow
            flow: root.isVertical ? Flow.TopToBottom : Flow.LeftToRight
            spacing: Math.min(8, Math.max(4, root.iconSize * 0.08))

        Repeater {
            id: repeater

            property var dockItems: []

            model: ScriptModel {
                values: repeater.dockItems
                objectProp: "uniqueKey"
            }

            Component.onCompleted: updateModel()

            function updateModel() {
                const items = []
                const pinnedApps = [...(SessionData.pinnedApps || [])]
                const sortedToplevels = CompositorService.sortedToplevels

                if (root.groupByApp) {
                    const appGroups = new Map()

                    pinnedApps.forEach(rawAppId => {
                        const appId = Paths.moddedAppId(rawAppId)
                        appGroups.set(appId, {
                            appId: appId,
                            isPinned: true,
                            windows: []
                        })
                    })

                    sortedToplevels.forEach((toplevel, index) => {
                        const rawAppId = toplevel.appId || "unknown"
                        const appId = Paths.moddedAppId(rawAppId)
                        if (!appGroups.has(appId)) {
                            appGroups.set(appId, {
                                appId: appId,
                                isPinned: false,
                                windows: []
                            })
                        }

                        appGroups.get(appId).windows.push({
                            toplevel: toplevel,
                            index: index
                        })
                    })

                    const pinnedGroups = []
                    const unpinnedGroups = []

                    Array.from(appGroups.entries()).forEach(([appId, group]) => {
                        const firstWindow = group.windows.length > 0 ? group.windows[0] : null

                        const item = {
                            uniqueKey: "grouped_" + appId,
                            type: "grouped",
                            appId: appId,
                            toplevel: firstWindow ? firstWindow.toplevel : null,
                            isPinned: group.isPinned,
                            isRunning: group.windows.length > 0,
                            windowCount: group.windows.length,
                            allWindows: group.windows
                        }

                        if (group.isPinned) {
                            pinnedGroups.push(item)
                        } else {
                            unpinnedGroups.push(item)
                        }
                    })

                    pinnedGroups.forEach(item => items.push(item))

                    if (pinnedGroups.length > 0 && unpinnedGroups.length > 0) {
                        items.push({
                            uniqueKey: "separator_grouped",
                            type: "separator",
                            appId: "__SEPARATOR__",
                            toplevel: null,
                            isPinned: false,
                            isRunning: false
                        })
                    }

                    unpinnedGroups.forEach(item => items.push(item))
                    root.pinnedAppCount = pinnedGroups.length
                } else {
                    pinnedApps.forEach(rawAppId => {
                        const appId = Paths.moddedAppId(rawAppId)
                        items.push({
                            uniqueKey: "pinned_" + appId,
                            type: "pinned",
                            appId: appId,
                            toplevel: null,
                            isPinned: true,
                            isRunning: false
                        })
                    })

                    root.pinnedAppCount = pinnedApps.length

                    if (pinnedApps.length > 0 && sortedToplevels.length > 0) {
                        items.push({
                            uniqueKey: "separator_ungrouped",
                            type: "separator",
                            appId: "__SEPARATOR__",
                            toplevel: null,
                            isPinned: false,
                            isRunning: false
                        })
                    }

                    sortedToplevels.forEach((toplevel, index) => {
                        let uniqueKey = "window_" + index
                        if (CompositorService.isHyprland && Hyprland.toplevels) {
                            const hyprlandToplevels = Array.from(Hyprland.toplevels.values)
                            for (let i = 0; i < hyprlandToplevels.length; i++) {
                                if (hyprlandToplevels[i].wayland === toplevel) {
                                    uniqueKey = "window_" + hyprlandToplevels[i].address
                                    break
                                }
                            }
                        }

                        items.push({
                            uniqueKey: uniqueKey,
                            type: "window",
                            appId: Paths.moddedAppId(toplevel.appId),
                            toplevel: toplevel,
                            isPinned: false,
                            isRunning: true
                        })
                    })
                }

                dockItems = items
            }

            delegate: Item {
                id: delegateItem
                property alias dockButton: button
                property var itemData: modelData
                clip: false

                width: itemData.type === "separator" ? (root.isVertical ? root.iconSize : 8) : (root.isVertical ? root.iconSize : root.iconSize * 1.2)
                height: itemData.type === "separator" ? (root.isVertical ? 8 : root.iconSize) : (root.isVertical ? root.iconSize * 1.2 : root.iconSize)

                Rectangle {
                    visible: itemData.type === "separator"
                    width: root.isVertical ? root.iconSize * 0.5 : 2
                    height: root.isVertical ? 2 : root.iconSize * 0.5
                    color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.3)
                    radius: 1
                    anchors.centerIn: parent
                }

                DockAppButton {
                    id: button
                    visible: itemData.type !== "separator"
                    anchors.centerIn: parent

                    width: delegateItem.width
                    height: delegateItem.height
                    actualIconSize: root.iconSize

                    appData: itemData
                    contextMenu: root.contextMenu
                    dockApps: root
                    index: model.index
                    parentDockScreen: root.dockScreen

                    showWindowTitle: itemData?.type === "window" || itemData?.type === "grouped"
                    windowTitle: {
                        const title = itemData?.toplevel?.title || "(Unnamed)"
                        return title.length > 50 ? title.substring(0, 47) + "..." : title
                    }
                }
            }
        }
        }
    }

    Connections {
        target: CompositorService
        function onToplevelsChanged() {
            repeater.updateModel()
        }
    }

    Connections {
        target: SessionData
        function onPinnedAppsChanged() {
            repeater.updateModel()
        }
    }

    onGroupByAppChanged: {
        repeater.updateModel()
    }
}
