import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
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
        anchors.centerIn: parent
        width: layoutFlow.width
        height: layoutFlow.height

        Flow {
            id: layoutFlow
            flow: root.isVertical ? Flow.TopToBottom : Flow.LeftToRight
            spacing: 8

        Repeater {
            id: repeater
            model: ListModel {
                id: dockModel

                Component.onCompleted: updateModel()

                function updateModel() {
                    clear()

                    const items = []
                    const pinnedApps = [...(SessionData.pinnedApps || [])]
                    const sortedToplevels = CompositorService.sortedToplevels

                    if (root.groupByApp) {
                        // Group windows by appId
                        const appGroups = new Map()

                        // Add pinned apps first (even if they have no windows)
                        pinnedApps.forEach(appId => {
                            appGroups.set(appId, {
                                appId: appId,
                                isPinned: true,
                                windows: []
                            })
                        })

                        // Group all running windows by appId
                        sortedToplevels.forEach((toplevel, index) => {
                            const appId = toplevel.appId || "unknown"
                            if (!appGroups.has(appId)) {
                                appGroups.set(appId, {
                                    appId: appId,
                                    isPinned: false,
                                    windows: []
                                })
                            }
                            const title = toplevel.title || "(Unnamed)"
                            const truncatedTitle = title.length > 50 ? title.substring(0, 47) + "..." : title
                            const uniqueId = toplevel.title + "|" + (toplevel.appId || "") + "|" + index

                            appGroups.get(appId).windows.push({
                                windowId: index,
                                windowTitle: truncatedTitle,
                                uniqueId: uniqueId
                            })
                        })

                        // Sort groups: pinned first, then unpinned
                        const pinnedGroups = []
                        const unpinnedGroups = []

                        Array.from(appGroups.entries()).forEach(([appId, group]) => {
                            // For grouped apps, just show the first window info but track all windows
                            const firstWindow = group.windows.length > 0 ? group.windows[0] : null

                            const item = {
                                "type": "grouped",
                                "appId": appId,
                                "windowId": firstWindow ? firstWindow.windowId : -1,
                                "windowTitle": firstWindow ? firstWindow.windowTitle : "",
                                "workspaceId": -1,
                                "isPinned": group.isPinned,
                                "isRunning": group.windows.length > 0,
                                "windowCount": group.windows.length,
                                "uniqueId": firstWindow ? firstWindow.uniqueId : "",
                                "allWindows": group.windows
                            }

                            if (group.isPinned) {
                                pinnedGroups.push(item)
                            } else {
                                unpinnedGroups.push(item)
                            }
                        })

                        // Add items in order
                        pinnedGroups.forEach(item => items.push(item))

                        // Add separator if needed
                        if (pinnedGroups.length > 0 && unpinnedGroups.length > 0) {
                            items.push({
                                "type": "separator",
                                "appId": "__SEPARATOR__",
                                "windowId": -1,
                                "windowTitle": "",
                                "workspaceId": -1,
                                "isPinned": false,
                                "isRunning": false
                            })
                        }

                        unpinnedGroups.forEach(item => items.push(item))
                        root.pinnedAppCount = pinnedGroups.length
                    } else {
                        pinnedApps.forEach(appId => {
                            items.push({
                                "type": "pinned",
                                "appId": appId,
                                "windowId": -1,
                                "windowTitle": "",
                                "workspaceId": -1,
                                "isPinned": true,
                                "isRunning": false
                            })
                        })

                        root.pinnedAppCount = pinnedApps.length

                        if (pinnedApps.length > 0 && sortedToplevels.length > 0) {
                            items.push({
                                "type": "separator",
                                "appId": "__SEPARATOR__",
                                "windowId": -1,
                                "windowTitle": "",
                                "workspaceId": -1,
                                "isPinned": false,
                                "isRunning": false,
                                "isFocused": false
                            })
                        }

                        sortedToplevels.forEach((toplevel, index) => {
                            const title = toplevel.title || "(Unnamed)"
                            const truncatedTitle = title.length > 50 ? title.substring(0, 47) + "..." : title
                            const uniqueId = toplevel.title + "|" + (toplevel.appId || "") + "|" + index

                            items.push({
                                "type": "window",
                                "appId": toplevel.appId,
                                "windowId": index,
                                "windowTitle": truncatedTitle,
                                "workspaceId": -1,
                                "isPinned": false,
                                "isRunning": true,
                                "uniqueId": uniqueId
                            })
                        })
                    }

                    items.forEach(item => append(item))
                }
            }

            delegate: Item {
                id: delegateItem
                property alias dockButton: button

                width: model.type === "separator" ? 16 : 40
                height: 40

                Rectangle {
                    visible: model.type === "separator"
                    width: 2
                    height: 20
                    color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.3)
                    radius: 1
                    anchors.centerIn: parent
                }

                DockAppButton {
                    id: button
                    visible: model.type !== "separator"
                    anchors.centerIn: parent

                    width: 40
                    height: 40

                    appData: model
                    contextMenu: root.contextMenu
                    dockApps: root
                    index: model.index
                    parentDockScreen: root.dockScreen

                    // Override tooltip for windows to show window title
                    showWindowTitle: model.type === "window" || model.type === "grouped"
                    windowTitle: model.windowTitle || ""
                }
            }
        }
        }
    }

    Connections {
        target: CompositorService
        function onSortedToplevelsChanged() {
            dockModel.updateModel()
        }
    }

    Connections {
        target: SessionData
        function onPinnedAppsChanged() {
            dockModel.updateModel()
        }
    }

    onGroupByAppChanged: {
        dockModel.updateModel()
    }
}
