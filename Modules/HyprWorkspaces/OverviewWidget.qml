import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root
    required property var panelWindow
    required property bool overviewOpen
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(panelWindow.screen)
    readonly property int workspacesShown: SettingsData.overviewRows * SettingsData.overviewColumns

    readonly property var allWorkspaces: Hyprland.workspaces?.values || []
    readonly property var allWorkspaceIds: {
        const workspaces = allWorkspaces
        if (!workspaces || workspaces.length === 0) return []
        try {
            const ids = workspaces.map(ws => ws?.id).filter(id => id !== null && id !== undefined)
            return ids.sort((a, b) => a - b)
        } catch (e) {
            return []
        }
    }

    readonly property var thisMonitorWorkspaceIds: {
        const workspaces = allWorkspaces
        const mon = monitor
        if (!workspaces || workspaces.length === 0 || !mon) return []
        try {
            const filtered = workspaces.filter(ws => ws?.monitor?.name === mon.name)
            return filtered.map(ws => ws?.id).filter(id => id !== null && id !== undefined).sort((a, b) => a - b)
        } catch (e) {
            return []
        }
    }

    readonly property var displayedWorkspaceIds: {
        if (!allWorkspaceIds || allWorkspaceIds.length === 0) {
            const result = []
            for (let i = 1; i <= workspacesShown; i++) {
                result.push(i)
            }
            return result
        }

        try {
            const maxExisting = Math.max(...allWorkspaceIds)
            const totalNeeded = Math.max(workspacesShown, allWorkspaceIds.length)
            const result = []

            for (let i = 1; i <= maxExisting; i++) {
                result.push(i)
            }

            let nextId = maxExisting + 1
            while (result.length < totalNeeded) {
                result.push(nextId)
                nextId++
            }

            return result
        } catch (e) {
            const result = []
            for (let i = 1; i <= workspacesShown; i++) {
                result.push(i)
            }
            return result
        }
    }

    readonly property int minWorkspaceId: displayedWorkspaceIds.length > 0 ? displayedWorkspaceIds[0] : 1
    readonly property int maxWorkspaceId: displayedWorkspaceIds.length > 0 ? displayedWorkspaceIds[displayedWorkspaceIds.length - 1] : workspacesShown
    readonly property int displayWorkspaceCount: displayedWorkspaceIds.length

    function getWorkspaceMonitorName(workspaceId) {
        if (!allWorkspaces || !workspaceId) return ""
        try {
            const ws = allWorkspaces.find(w => w?.id === workspaceId)
            return ws?.monitor?.name ?? ""
        } catch (e) {
            return ""
        }
    }

    function workspaceHasWindows(workspaceId) {
        if (!workspaceId) return false
        try {
            const workspace = allWorkspaces.find(ws => ws?.id === workspaceId)
            if (!workspace) return false
            const toplevels = workspace?.toplevels?.values || []
            return toplevels.length > 0
        } catch (e) {
            return false
        }
    }

    property bool monitorIsFocused: monitor?.focused ?? false
    property real scale: SettingsData.overviewScale
    property color activeBorderColor: Theme.primary

    property real workspaceImplicitWidth: ((monitor.width / monitor.scale) * root.scale)
    property real workspaceImplicitHeight: ((monitor.height / monitor.scale) * root.scale)

    property int workspaceZ: 0
    property int windowZ: 1
    property int monitorLabelZ: 2
    property int windowDraggingZ: 99999
    property real workspaceSpacing: 5

    property int draggingFromWorkspace: -1
    property int draggingTargetWorkspace: -1

    implicitWidth: overviewBackground.implicitWidth + Theme.spacingL * 2
    implicitHeight: overviewBackground.implicitHeight + Theme.spacingL * 2

    Component.onCompleted: {
        Hyprland.refreshToplevels()
        Hyprland.refreshWorkspaces()
        Hyprland.refreshMonitors()
    }

    onOverviewOpenChanged: {
        if (overviewOpen) {
            Hyprland.refreshToplevels()
            Hyprland.refreshWorkspaces()
            Hyprland.refreshMonitors()
        }
    }

    Rectangle {
        id: overviewBackground
        property real padding: 10
        anchors.fill: parent
        anchors.margins: Theme.spacingL

        implicitWidth: workspaceColumnLayout.implicitWidth + padding * 2
        implicitHeight: workspaceColumnLayout.implicitHeight + padding * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainer

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowBlur: 0.5
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 4
            shadowColor: Theme.shadowStrong
            shadowOpacity: 1
            blurMax: 32
        }

        ColumnLayout {
            id: workspaceColumnLayout

            z: root.workspaceZ
            anchors.centerIn: parent
            spacing: workspaceSpacing

            Repeater {
                model: SettingsData.overviewRows
                delegate: RowLayout {
                    id: row
                    property int rowIndex: index
                    spacing: workspaceSpacing

                    Repeater {
                        model: SettingsData.overviewColumns
                        Rectangle {
                            id: workspace
                            property int colIndex: index
                            property int workspaceIndex: rowIndex * SettingsData.overviewColumns + colIndex
                            property int workspaceValue: (root.displayedWorkspaceIds && workspaceIndex < root.displayedWorkspaceIds.length) ? root.displayedWorkspaceIds[workspaceIndex] : -1
                            property bool workspaceExists: (root.allWorkspaceIds && workspaceValue > 0) ? root.allWorkspaceIds.includes(workspaceValue) : false
                            property var workspaceObj: (workspaceExists && Hyprland.workspaces?.values) ? Hyprland.workspaces.values.find(ws => ws?.id === workspaceValue) : null
                            property bool isActive: workspaceObj?.active ?? false
                            property bool isOnThisMonitor: (workspaceObj && root.monitor) ? (workspaceObj.monitor?.name === root.monitor.name) : true
                            property bool hasWindows: (workspaceValue > 0) ? root.workspaceHasWindows(workspaceValue) : false
                            property string workspaceMonitorName: (workspaceValue > 0) ? root.getWorkspaceMonitorName(workspaceValue) : ""
                            property color defaultWorkspaceColor: workspaceExists ? Theme.surfaceContainer : Theme.withAlpha(Theme.surfaceContainer, 0.3)
                            property color hoveredWorkspaceColor: Qt.lighter(defaultWorkspaceColor, 1.1)
                            property color hoveredBorderColor: Theme.surfaceVariant
                            property bool hoveredWhileDragging: false
                            property bool shouldShowActiveIndicator: isActive && isOnThisMonitor && hasWindows

                            visible: workspaceValue !== -1

                            implicitWidth: root.workspaceImplicitWidth
                            implicitHeight: root.workspaceImplicitHeight
                            color: hoveredWhileDragging ? hoveredWorkspaceColor : defaultWorkspaceColor
                            radius: Theme.cornerRadius
                            border.width: 2
                            border.color: hoveredWhileDragging ? hoveredBorderColor : (shouldShowActiveIndicator ? root.activeBorderColor : "transparent")

                            StyledText {
                                anchors.centerIn: parent
                                text: workspaceValue
                                font.pixelSize: Theme.fontSizeXLarge * 6
                                font.weight: Font.DemiBold
                                color: Theme.withAlpha(Theme.surfaceText, workspaceExists ? 0.2 : 0.1)
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            MouseArea {
                                id: workspaceArea
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton
                                onClicked: {
                                    if (root.draggingTargetWorkspace === -1) {
                                        root.overviewOpen = false
                                        Hyprland.dispatch(`workspace ${workspaceValue}`)
                                    }
                                }
                            }

                            DropArea {
                                anchors.fill: parent
                                onEntered: {
                                    root.draggingTargetWorkspace = workspaceValue
                                    if (root.draggingFromWorkspace == root.draggingTargetWorkspace) return
                                    hoveredWhileDragging = true
                                }
                                onExited: {
                                    hoveredWhileDragging = false
                                    if (root.draggingTargetWorkspace == workspaceValue) root.draggingTargetWorkspace = -1
                                }
                            }
                        }
                    }
                }
            }
        }

        Item {
            id: windowSpace
            anchors.centerIn: parent
            implicitWidth: workspaceColumnLayout.implicitWidth
            implicitHeight: workspaceColumnLayout.implicitHeight

            Repeater {
                model: ScriptModel {
                    values: {
                        const workspaces = root.allWorkspaces
                        const minId = root.minWorkspaceId
                        const maxId = root.maxWorkspaceId

                        if (!workspaces || workspaces.length === 0) return []

                        try {
                            const result = []
                            for (const workspace of workspaces) {
                                const wsId = workspace?.id ?? -1
                                if (wsId >= minId && wsId <= maxId) {
                                    const toplevels = workspace?.toplevels?.values || []
                                    for (const toplevel of toplevels) {
                                        result.push(toplevel)
                                    }
                                }
                            }
                            return result
                        } catch (e) {
                            console.error("OverviewWidget filter error:", e)
                            return []
                        }
                    }
                }
                delegate: OverviewWindow {
                    id: window
                    required property var modelData

                    overviewOpen: root.overviewOpen
                    readonly property int windowWorkspaceId: modelData?.workspace?.id ?? -1

                    function getWorkspaceIndex() {
                        if (!root.displayedWorkspaceIds || root.displayedWorkspaceIds.length === 0) return 0
                        if (!windowWorkspaceId || windowWorkspaceId < 0) return 0
                        try {
                            for (let i = 0; i < root.displayedWorkspaceIds.length; i++) {
                                if (root.displayedWorkspaceIds[i] === windowWorkspaceId) {
                                    return i
                                }
                            }
                            return 0
                        } catch (e) {
                            return 0
                        }
                    }

                    readonly property int workspaceIndex: getWorkspaceIndex()
                    readonly property int workspaceColIndex: workspaceIndex % SettingsData.overviewColumns
                    readonly property int workspaceRowIndex: Math.floor(workspaceIndex / SettingsData.overviewColumns)

                    toplevel: modelData
                    scale: root.scale
                    availableWorkspaceWidth: root.workspaceImplicitWidth
                    availableWorkspaceHeight: root.workspaceImplicitHeight
                    widgetMonitorId: root.monitor.id

                    xOffset: (root.workspaceImplicitWidth + workspaceSpacing) * workspaceColIndex
                    yOffset: (root.workspaceImplicitHeight + workspaceSpacing) * workspaceRowIndex

                    z: atInitPosition ? root.windowZ : root.windowDraggingZ
                    property bool atInitPosition: (initX == x && initY == y)

                    Drag.hotSpot.x: width / 2
                    Drag.hotSpot.y: height / 2

                    MouseArea {
                        id: dragArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: window.hovered = true
                        onExited: window.hovered = false
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        drag.target: parent

                        onPressed: (mouse) => {
                            root.draggingFromWorkspace = windowData?.workspace.id
                            window.pressed = true
                            window.Drag.active = true
                            window.Drag.source = window
                            window.Drag.hotSpot.x = mouse.x
                            window.Drag.hotSpot.y = mouse.y
                        }

                        onReleased: {
                            const targetWorkspace = root.draggingTargetWorkspace
                            window.pressed = false
                            window.Drag.active = false
                            root.draggingFromWorkspace = -1
                            root.draggingTargetWorkspace = -1

                            if (targetWorkspace !== -1 && targetWorkspace !== windowData?.workspace.id) {
                                Hyprland.dispatch(`movetoworkspacesilent ${targetWorkspace},address:${windowData?.address}`)
                                Qt.callLater(() => {
                                    Hyprland.refreshToplevels()
                                    Hyprland.refreshWorkspaces()
                                    Qt.callLater(() => {
                                        window.x = window.initX
                                        window.y = window.initY
                                    })
                                })
                            } else {
                                window.x = window.initX
                                window.y = window.initY
                            }
                        }

                        onClicked: (event) => {
                            if (!windowData) return

                            if (event.button === Qt.LeftButton) {
                                root.overviewOpen = false
                                Hyprland.dispatch(`focuswindow address:${windowData.address}`)
                                event.accepted = true
                            } else if (event.button === Qt.MiddleButton) {
                                Hyprland.dispatch(`closewindow address:${windowData.address}`)
                                event.accepted = true
                            }
                        }
                    }
                }
            }
        }

        Item {
            id: monitorLabelSpace
            anchors.centerIn: parent
            implicitWidth: workspaceColumnLayout.implicitWidth
            implicitHeight: workspaceColumnLayout.implicitHeight
            z: root.monitorLabelZ

            Repeater {
                model: SettingsData.overviewRows
                delegate: Item {
                    id: labelRow
                    property int rowIndex: index
                    y: (root.workspaceImplicitHeight + workspaceSpacing) * rowIndex
                    width: parent.width
                    height: root.workspaceImplicitHeight

                    Repeater {
                        model: SettingsData.overviewColumns
                        delegate: Item {
                            id: labelItem
                            property int colIndex: index
                            property int workspaceIndex: labelRow.rowIndex * SettingsData.overviewColumns + colIndex
                            property int workspaceValue: (root.displayedWorkspaceIds && workspaceIndex < root.displayedWorkspaceIds.length) ? root.displayedWorkspaceIds[workspaceIndex] : -1
                            property bool workspaceExists: (root.allWorkspaceIds && workspaceValue > 0) ? root.allWorkspaceIds.includes(workspaceValue) : false
                            property string workspaceMonitorName: (workspaceValue > 0) ? root.getWorkspaceMonitorName(workspaceValue) : ""

                            x: (root.workspaceImplicitWidth + workspaceSpacing) * colIndex
                            width: root.workspaceImplicitWidth
                            height: root.workspaceImplicitHeight

                            Rectangle {
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: Theme.spacingS
                                width: monitorNameText.contentWidth + Theme.spacingS * 2
                                height: monitorNameText.contentHeight + Theme.spacingXS * 2
                                radius: Theme.cornerRadius
                                color: Theme.surface
                                visible: labelItem.workspaceExists && labelItem.workspaceMonitorName !== ""

                                StyledText {
                                    id: monitorNameText
                                    anchors.centerIn: parent
                                    text: labelItem.workspaceMonitorName
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.Medium
                                    color: Theme.surfaceText
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
